-- J_PoliceNat server/main.lua
local ESX = exports["es_extended"]:getSharedObject()

-- =============================================
-- Variables locales et tables
-- =============================================
local onDutyPlayers = {}
local pendingWeaponLicenses = {}

-- =============================================
-- Fonctions utilitaires de formatage de date
-- =============================================
function FormatDateForDisplay(timestamp)
    if type(timestamp) == "number" then
        return os.date('%d/%m/%Y %H:%M', timestamp)
    elseif timestamp then
        return timestamp
    else
        return "N/A"
    end
end

function FormatDateForDatabase(dateStr)
    if not dateStr then return nil end
    
    -- Format JJ/MM/AAAA vers timestamp
    local day, month, year = dateStr:match("^(%d%d)/(%d%d)/(%d%d%d%d)$")
    if day and month and year then
        local time = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day)})
        return time
    end
    
    return nil
end

-- =============================================
-- Fonctions de vérification des permissions
-- =============================================

-- Vérification du job police
function IsPolice(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    return xPlayer and xPlayer.job.name == 'police'
end

-- Vérification du grade
function HasMinimumGrade(source, minGrade)
    local xPlayer = ESX.GetPlayerFromId(source)
    return xPlayer and xPlayer.job.name == 'police' and xPlayer.job.grade >= minGrade
end

-- =============================================
-- Fonction standardisée pour les notifications serveur
-- =============================================
function SendNotificationToPlayer(playerId, type, title, message)
    if not playerId then return end
    
    exports['jl_notifications']:SendNotificationToPlayer(playerId, {
        type = type,
        message = message,
        title = title,
        image = 'img/policenat.png',
        duration = 5000
    })
end

-- =============================================
-- Initialisation et configuration
-- =============================================

-- Configuration du prix du PPA (doit correspondre à celui dans rp-identity)
Config.WeaponLicensePrice = 1500

-- Enregistrement de la société pour esx_society
CreateThread(function()
    Wait(1000) -- On attend que tout soit chargé
    TriggerEvent('esx_society:registerSociety', 'police', 'Police', 'society_police', 'society_police', 'society_police')
end)

-- =============================================
-- Gestion du service
-- =============================================

-- Fonction pour obtenir le nom du grade
function GetGradeName(grade)
    local gradeNames = {
        [0] = "Gardien de la Paix Stagiaire",
        [1] = "Gardien de la Paix",
        [2] = "Sous-Brigadier",
        [3] = "Brigadier",
        [4] = "Brigadier-Chef",
        [5] = "Brigadier-Major",
        [6] = "Lieutenant",
        [7] = "Capitaine",
        [8] = "Commandant",
        [9] = "Commissaire",
        [10] = "Commissaire Divisionnaire"
    }
    
    return gradeNames[grade] or "Gardien de la Paix"
end

RegisterServerEvent('police:toggleDuty')
AddEventHandler('police:toggleDuty', function(newStatus)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer or xPlayer.job.name ~= 'police' then return end
    
    -- Mise à jour du statut
    onDutyPlayers[xPlayer.identifier] = newStatus

    -- Mise à jour dans la base de données
    MySQL.update('UPDATE users SET onduty = ? WHERE identifier = ?', {
        newStatus and 1 or 0,
        xPlayer.identifier
    })
    
    -- Notification au client
    TriggerClientEvent('police:setDuty', source, newStatus)
    
    -- Informer tous les agents de police du changement
    local officers = GetOnDutyPolice()
    for _, officer in ipairs(officers) do
        TriggerClientEvent('police:updateOfficersList', officer.source)
    end
    
    -- Log Discord
    exports['J_PoliceNat']:NotifyDutyChange(xPlayer.getName(), newStatus)
end)

RegisterServerEvent('police:getDutyStatus')
AddEventHandler('police:getDutyStatus', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer or xPlayer.job.name ~= 'police' then return end
    
    -- Récupération du statut dans la base de données
    MySQL.query('SELECT onduty FROM users WHERE identifier = ?', {
        xPlayer.identifier
    }, function(result)
        if result[1] then
            local isOnDuty = result[1].onduty == 1
            onDutyPlayers[xPlayer.identifier] = isOnDuty
            TriggerClientEvent('police:setDuty', source, isOnDuty)
        end
    end)
end)

-- Récupérer la liste des agents en service
ESX.RegisterServerCallback('police:getOnDutyOfficers', function(source, cb)
   local onDutyOfficers = {}
   local xPlayers = ESX.GetPlayers()
   
   for _, playerId in ipairs(xPlayers) do
       local xPlayer = ESX.GetPlayerFromId(playerId)
       if xPlayer.job.name == 'police' and onDutyPlayers[xPlayer.identifier] then
           table.insert(onDutyOfficers, {
               id = playerId,
               name = xPlayer.getName(),
               grade = xPlayer.job.grade,
               gradeName = GetGradeName(xPlayer.job.grade)
           })
       end
   end
   
   cb(onDutyOfficers)
end)

-- =============================================
-- Gestion des amendes
-- =============================================

-- Système d'amendes avec intégration à esx_billing
RegisterServerEvent('police:finePlayer')
AddEventHandler('police:finePlayer', function(target, amount, reason)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    if not IsPolice(source) or not onDutyPlayers[xPlayer.identifier] then return end
    
    local xTarget = ESX.GetPlayerFromId(target)
    if not xTarget then return end
    
    -- Vérification du montant
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end
    
    -- Ajouter directement à la base de données
    MySQL.insert('INSERT INTO billing (identifier, sender, target_type, target, label, amount) VALUES (?, ?, ?, ?, ?, ?)', {
        xTarget.identifier,
        'Police',
        'society',
        'society_police',
        reason,
        amount
    }, function(id)
        if id > 0 then
            -- Notification aux joueurs
            SendNotificationToPlayer(target, 'warning', 'Amende', ('Vous avez reçu une amende de €%s'):format(ESX.Math.GroupDigits(amount)))
            SendNotificationToPlayer(source, 'success', 'Amende', ('Vous avez donné une amende de €%s'):format(ESX.Math.GroupDigits(amount)))
            
            -- Log Discord
            exports['J_PoliceNat']:NotifyFine(
                xPlayer.getName(),
                xTarget.getName(),
                ESX.Math.GroupDigits(amount),
                reason
            )
        else
            SendNotificationToPlayer(source, 'error', 'Amende', 'Erreur lors de l\'enregistrement de l\'amende')
        end
    end)
end)
-- =============================================
-- Gestion des permis d'armes
-- =============================================

-- Étape 1: Vérification initiale avant de demander confirmation
RegisterServerEvent('police:requestWeaponLicense')
AddEventHandler('police:requestWeaponLicense', function(targetId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(targetId)
    
    if not xPlayer or not xTarget then return end
    
    -- Vérifier que c'est un policier avec un grade suffisant
    if xPlayer.job.name ~= 'police' or xPlayer.job.grade < 2 then
        SendNotificationToPlayer(source, 'error', 'Police', 'Vous n\'êtes pas autorisé à faire cela')
        return
    end
    
    -- Vérifier si le joueur a déjà un PPA
    MySQL.query('SELECT id FROM user_documents WHERE owner = ? AND type = "Weapon" AND expiration_date > ?', {
        xTarget.identifier, 
        os.time()
    }, function(result)
        if result and #result > 0 then        
            SendNotificationToPlayer(source, 'info', 'Permis', 'Cette personne possède déjà un permis de port d\'arme valide')
            return
        end
        
        -- Si tout est OK, demander confirmation au policier
        TriggerClientEvent('police:confirmWeaponLicense', source, targetId)
    end)
end)

-- Étape 2: Traitement final après confirmation
RegisterServerEvent('police:confirmWeaponLicense')
AddEventHandler('police:confirmWeaponLicense', function(targetId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(targetId)
    
    if not xPlayer or not xTarget then return end
    
    -- Vérifier à nouveau l'autorisation
    if xPlayer.job.name ~= 'police' or xPlayer.job.grade < 2 then return end
    
    -- Prix du permis défini dans la configuration
    local price = Config.WeaponLicensePrice
    
    -- Vérifier si le joueur peut payer
    if xTarget.getMoney() < price then
        SendNotificationToPlayer(source, 'error', 'Permis', 'Le citoyen n\'a pas assez d\'argent pour le permis')
        SendNotificationToPlayer(targetId, 'error', 'Permis', 'Vous n\'avez pas assez d\'argent pour le permis')
        return
    end
    
    -- Retirer l'argent du joueur
    xTarget.removeMoney(price)
    
    -- Ajouter l'argent à la société police
    TriggerEvent('esx_addonaccount:getSharedAccount', 'society_police', function(account)
        if account then
            account.addMoney(price)
        end
    end)
    
    -- Création du permis via le script rp-identity
    exports['rp-identity']:createWeaponLicenseForPlayer(targetId, source)
    
    -- Notification
    SendNotificationToPlayer(source, 'success', 'Permis', 'Vous avez approuvé le permis de port d\'arme')
    SendNotificationToPlayer(targetId, 'success', 'Permis', 'Votre permis de port d\'arme a été approuvé pour €' .. price)
    
    -- Log Discord
    local embed = exports['J_PoliceNat']:FormatEmbed(
        "Permis d'arme",
        ('L\'agent %s a délivré un permis de port d\'arme à %s'):format(
            xPlayer.getName(),
            xTarget.getName()
        ),
        3066993
    )
    exports['J_PoliceNat']:SendToDiscord(Config.DiscordWebhook.alerts, "Police Nationale - Permis", nil, {embed})
end)

-- =============================================
-- Gestion des documents
-- =============================================

-- Événement pour révoquer un permis
RegisterServerEvent('police:revokeDocument')
AddEventHandler('police:revokeDocument', function(targetId, docType, reason)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(targetId)
    
    if not xPlayer or not xTarget then return end
    
    -- Vérifier que c'est un policier
    if xPlayer.job.name ~= 'police' then
        SendNotificationToPlayer(source, 'error', 'Police', 'Vous n\'êtes pas autorisé à faire cela')
        return
    end
    
    -- Vérifier le grade minimum selon le type de document
    local minGrade = (docType == 'Weapon') and 2 or 0
    if xPlayer.job.grade < minGrade then
        SendNotificationToPlayer(source, 'error', 'Police', 'Grade insuffisant pour cette action')
        return
    end
    
    -- Supprimer le document
    MySQL.update('DELETE FROM user_documents WHERE owner = ? AND type = ?', {
        xTarget.identifier,
        docType
    }, function(affectedRows)
        if affectedRows > 0 then
            -- Notification aux joueurs
            SendNotificationToPlayer(source, 'success', 'Permis', 'Vous avez révoqué le permis')
            SendNotificationToPlayer(targetId, 'error', 'Permis', 'Votre permis a été révoqué: ' .. reason)
            
            -- Log Discord
            local embed = exports['J_PoliceNat']:FormatEmbed(
                "Révocation de permis",
                ('L\'agent %s a révoqué le permis %s de %s'):format(
                    xPlayer.getName(),
                    docType,
                    xTarget.getName()
                ),
                15158332,
                {{name = "Motif", value = reason}}
            )
            exports['J_PoliceNat']:SendToDiscord(Config.DiscordWebhook.alerts, "Police Nationale - Permis", nil, {embed})
        else
            SendNotificationToPlayer(source, 'error', 'Permis', 'Cette personne ne possède pas ce permis')
        end
    end)
end)

-- Récupération détaillée des documents d'un joueur
RegisterServerEvent('police:checkDetailedLicenses')
AddEventHandler('police:checkDetailedLicenses', function(target)
    local source = source
    if not IsPolice(source) or not onDutyPlayers[ESX.GetPlayerFromId(source).identifier] then return end
    
    local xTarget = ESX.GetPlayerFromId(target)
    if not xTarget then return end
    
    -- Récupérer uniquement les documents de la table user_documents
    MySQL.query('SELECT id, type, document_number, issue_date, expiration_date, issuer, data FROM user_documents WHERE owner = ?', {
        xTarget.identifier
    }, function(results)
        -- Formater les documents pour l'affichage
        local formattedDocuments = {}
        if results then
            for _, doc in ipairs(results) do
                local docData = json.decode(doc.data)
                table.insert(formattedDocuments, {
                    id = doc.id,
                    type = doc.type,
                    number = doc.document_number,
                    issueDate = os.date('%d/%m/%Y', doc.issue_date),
                    expirationDate = os.date('%d/%m/%Y', doc.expiration_date),
                    issuer = doc.issuer,
                    firstName = docData.firstname,
                    lastName = docData.lastname,
                    dateOfBirth = docData.dateofbirth,
                    sex = docData.sex,
                    height = docData.height,
                    isExpired = doc.expiration_date < os.time()
                })
            end
        end
        
        -- Envoyer les résultats au client
        TriggerClientEvent('police:showDetailedLicenses', source, formattedDocuments)
    end)
end)

-- =============================================
-- Interactions avec les citoyens
-- =============================================

-- Système de menottes, escorte, mise en véhicule
RegisterServerEvent('police:handcuffPlayer')
AddEventHandler('police:handcuffPlayer', function(target)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not IsPolice(source) or not onDutyPlayers[xPlayer.identifier] then return end
    
    TriggerClientEvent('police:getHandcuffed', target)
end)

RegisterServerEvent('police:escortPlayer')
AddEventHandler('police:escortPlayer', function(target)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not IsPolice(source) or not onDutyPlayers[xPlayer.identifier] then return end
    
    TriggerClientEvent('police:getEscorted', target, source)
end)

RegisterServerEvent('police:putInVehicle')
AddEventHandler('police:putInVehicle', function(target)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not IsPolice(source) or not onDutyPlayers[xPlayer.identifier] then return end
    
    TriggerClientEvent('police:putInVehicle', target)
end)

RegisterServerEvent('police:outOfVehicle')
AddEventHandler('police:outOfVehicle', function(target)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not IsPolice(source) or not onDutyPlayers[xPlayer.identifier] then return end
    
    TriggerClientEvent('police:outOfVehicle', target)
end)

-- =============================================
-- Système de plaintes
-- =============================================

-- Enregistrement des plaintes
RegisterServerEvent('police:registerComplaint')
AddEventHandler('police:registerComplaint', function(complaintData)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not IsPolice(source) then return end

    MySQL.insert('INSERT INTO police_complaints (type, plaintiff, description, officer_identifier, date, status) VALUES (?, ?, ?, ?, NOW(), "open")', {
        complaintData.type,
        complaintData.plaintiff,
        complaintData.description,
        xPlayer.identifier
    }, function(id)
        if id then
            -- Notification
            SendNotificationToPlayer(source, 'success', 'Plainte', 'Plainte enregistrée avec succès')
            
            -- Log Discord
            exports['J_PoliceNat']:NotifyComplaint(
                xPlayer.getName(),
                complaintData.plaintiff,
                complaintData.type,
                "Ouvert",
                complaintData.description
            )
        end
    end)
end)

-- Récupération des plaintes
ESX.RegisterServerCallback('police:getComplaints', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not IsPolice(source) then 
        cb({})
        return
    end

    MySQL.query('SELECT c.*, CONCAT(u.firstname, " ", u.lastname) as officer_name FROM police_complaints c LEFT JOIN users u ON c.officer_identifier = u.identifier ORDER BY c.date DESC', {}, function(complaints)
        -- Formater les dates comme dans la gestion des rendez-vous
        if complaints then
            for i=1, #complaints do
                -- Convertir le timestamp en date lisible
                if complaints[i].date then
                    complaints[i].date = os.date('%d/%m/%Y %H:%M', complaints[i].date / 1000)
                end
                if complaints[i].closed_date then
                    complaints[i].closed_date = os.date('%d/%m/%Y %H:%M', complaints[i].closed_date / 1000)
                end
                
                -- Format lisible pour le statut
                if complaints[i].status == 'open' then
                    complaints[i].status = 'Ouvert'
                elseif complaints[i].status == 'closed' then
                    complaints[i].status = 'Fermé'
                end
            end
        end
        
        cb(complaints)
    end)
end)

-- Clôture d'une plainte
RegisterServerEvent('police:closeComplaint')
AddEventHandler('police:closeComplaint', function(complaintId, closeReport)
   local source = source
   local xPlayer = ESX.GetPlayerFromId(source)
   
   if not IsPolice(source) then return end
   MySQL.update('UPDATE police_complaints SET status = ?, close_report = ?, closed_date = NOW(), closed_by = ? WHERE id = ?', {
       'closed',
       closeReport,
       xPlayer.identifier,
       complaintId
   }, function(affectedRows)
       if affectedRows > 0 then
           -- Notification
           SendNotificationToPlayer(source, 'success', 'Plainte', 'Plainte clôturée avec succès')
           
           -- Log Discord
           exports['J_PoliceNat']:NotifyComplaint(
               xPlayer.getName(),
               "Plaignant inconnu", -- Vous pourriez récupérer le plaignant depuis la BDD si souhaité
               "Type inconnu",      -- Vous pourriez récupérer le type depuis la BDD si souhaité
               "Fermé",
               closeReport
           )
       end
   end)
end)

-- =============================================
-- Système d'alertes
-- =============================================

-- Système d'alertes
RegisterServerEvent('police:sendAlert')
AddEventHandler('police:sendAlert', function(code, coords)
   local source = source
   local xPlayer = ESX.GetPlayerFromId(source)
   
   if not IsPolice(source) or not onDutyPlayers[xPlayer.identifier] then return end

   -- Envoi à tous les policiers en service
   local officers = GetOnDutyPolice()
   for _, officer in ipairs(officers) do
       if officer.source ~= source then -- Ne pas envoyer à l'émetteur
           TriggerClientEvent('police:receiveAlert', officer.source, code, coords, xPlayer.getName())
       end
   end

   -- Log Discord
   local embed = exports['J_PoliceNat']:FormatEmbed(
       "Alerte Radio",
       ('Agent %s a envoyé une alerte %s'):format(
           xPlayer.getName(),
           code
       ),
       15105570
   )
   exports['J_PoliceNat']:SendToDiscord(Config.DiscordWebhook.alerts, "Police Nationale - Alertes", nil, {embed})
end)

-- =============================================
-- Gestion du casier judiciaire
-- =============================================

-- Recherche d'une personne par numéro de document d'identité
ESX.RegisterServerCallback('police:searchCitizenByDocumentNumber', function(source, cb, documentNumber)
   if not IsPolice(source) then
       cb(false)
       return
   end

   MySQL.query('SELECT owner FROM user_documents WHERE document_number = ? AND type = "ID" LIMIT 1', {
       documentNumber
   }, function(result)
       if result and result[1] then
           local citizenIdentifier = result[1].owner
           
           -- Récupérer les informations du citoyen
           MySQL.query('SELECT identifier, firstname, lastname, dateofbirth, sex, height, mugshot FROM users WHERE identifier = ?', {
               citizenIdentifier
           }, function(citizenData)
               if not citizenData or not citizenData[1] then
                   cb(false)
                   return
               end
               
               -- Récupérer tous les documents du citoyen
               MySQL.query('SELECT id, type, document_number, issue_date, expiration_date, issuer, data FROM user_documents WHERE owner = ?', {
                   citizenIdentifier
               }, function(documents)
                   -- Formater les documents pour l'affichage
                   local formattedDocuments = {}
                   if documents then
                       for _, doc in ipairs(documents) do
                           local docData = json.decode(doc.data)
                           table.insert(formattedDocuments, {
                               id = doc.id,
                               type = doc.type,
                               number = doc.document_number,
                               issueDate = os.date('%d/%m/%Y', doc.issue_date),
                               expirationDate = os.date('%d/%m/%Y', doc.expiration_date),
                               issuer = doc.issuer,
                               firstName = docData.firstname,
                               lastName = docData.lastname,
                               dateOfBirth = docData.dateofbirth,
                               sex = docData.sex,
                               height = docData.height,
                               isExpired = doc.expiration_date < os.time()
                           })
                       end
                   end
                   
                   -- Récupérer le casier judiciaire du citoyen
                   MySQL.query('SELECT * FROM police_criminal_records WHERE citizen_id = ? ORDER BY date DESC', {
                       citizenIdentifier
                   }, function(criminalRecords)
                       local records = {}
                       if criminalRecords then
                           for _, record in ipairs(criminalRecords) do
                               -- Récupérer le nom de l'officier
                               local officerName = "Inconnu"
                               MySQL.query('SELECT firstname, lastname FROM users WHERE identifier = ? LIMIT 1', {
                                   record.officer_identifier
                               }, function(officerData)
                                   if officerData and officerData[1] then
                                       officerName = officerData[1].firstname .. " " .. officerData[1].lastname
                                   end
                               end)
                               
                               table.insert(records, {
                                   id = record.id,
                                   documentNumber = record.document_number,
                                   offense = record.offense,
                                   date = os.date('%d/%m/%Y %H:%M', record.date / 1000),
                                   fineAmount = record.fine_amount,
                                   jailTime = record.jail_time,
                                   notes = record.notes or 'Aucune',
                                   officerName = officerName
                               })
                           end
                       end
                       
                       cb({
                           citizen = citizenData[1],
                           documents = formattedDocuments,
                           criminalRecords = records
                       })
                   end)
               end)
           end)
       else
           cb(false)
       end
   end)
end)

-- Ajouter une entrée au casier judiciaire
RegisterServerEvent('police:addCriminalRecord')
AddEventHandler('police:addCriminalRecord', function(data)
   local source = source
   local xPlayer = ESX.GetPlayerFromId(source)
   
   if not IsPolice(source) then return end
   
   MySQL.insert('INSERT INTO police_criminal_records (citizen_id, document_number, officer_identifier, offense, fine_amount, jail_time, notes) VALUES (?, ?, ?, ?, ?, ?, ?)', {
       data.citizenId,
       data.documentNumber,
       xPlayer.identifier,
       data.offense,
       data.fineAmount or 0,
       data.jailTime or 0,
       data.notes or ''
   }, function(id)
       if id then
           SendNotificationToPlayer(source, 'success', 'Casier Judiciaire', 'Casier judiciaire mis à jour')
           
           -- Log Discord
           exports['J_PoliceNat']:NotifyCriminalRecord(
               xPlayer.getName(),
               data.citizenName or "Inconnu",
               data.offense,
               data.fineAmount or 0,
               data.jailTime or 0
           )
           
           -- Imposer l'amende si définie
           if data.fineAmount and data.fineAmount > 0 and data.targetId then
               TriggerEvent('esx_billing:sendBill', data.targetId, 'society_police', data.offense, data.fineAmount)
               -- Notification au cible
               SendNotificationToPlayer(data.targetId, 'warning', 'Casier Judiciaire', 'Vous avez été condamné(e) à une amende de €' .. data.fineAmount)
           end
           
           -- Mettre en prison si durée définie
           if data.jailTime and data.jailTime > 0 and data.targetId then
               TriggerEvent('esx-qalle-jail:jailPlayer', data.targetId, data.jailTime, data.offense)
               -- Notification au cible
               SendNotificationToPlayer(data.targetId, 'warning', 'Casier Judiciaire', 'Vous avez été condamné(e) à ' .. data.jailTime .. ' minutes de prison')
           end
       end
   end)
end)

-- Supprimer une entrée du casier judiciaire (réservé aux grades élevés)
RegisterServerEvent('police:deleteCriminalRecord')
AddEventHandler('police:deleteCriminalRecord', function(recordId)
   local source = source
   local xPlayer = ESX.GetPlayerFromId(source)
   
   if not IsPolice(source) or xPlayer.job.grade < Config.Job.bossGrade - 1 then
       SendNotificationToPlayer(source, 'error', 'Police', 'Vous n\'avez pas les permissions nécessaires')
       return
   end
   
   MySQL.update('DELETE FROM police_criminal_records WHERE id = ?', {
       recordId
   }, function(affectedRows)
       if affectedRows > 0 then
           SendNotificationToPlayer(source, 'success', 'Casier Judiciaire', 'Entrée supprimée du casier judiciaire')
           
           -- Log Discord
           local embed = exports['J_PoliceNat']:FormatEmbed(
               "Casier Judiciaire - Suppression",
               ('L\'agent %s a supprimé une entrée du casier judiciaire'):format(
                   xPlayer.getName()
               ),
               7506394,
               {{name = "ID de l'entrée", value = tostring(recordId)}}
           )
           exports['J_PoliceNat']:SendToDiscord(Config.DiscordWebhook.casier, "Police Nationale - Casier Judiciaire", nil, {embed})
       end
   end)
end)

-- Récupération des photos de la galerie du policier
ESX.RegisterServerCallback('police:getOfficerGallery', function(source, cb)
   local xPlayer = ESX.GetPlayerFromId(source)
   
   if not IsPolice(source) then
       cb({})
       return
   end
   
   MySQL.query('SELECT id, image_url, created_at FROM phone_gallery WHERE owner_identifier = ? ORDER BY created_at DESC', {
       xPlayer.identifier
   }, function(gallery)
       cb(gallery or {})
   end)
end)

-- Mise à jour de la photo d'identification du suspect
RegisterServerEvent('police:updateMugshot')
AddEventHandler('police:updateMugshot', function(citizenId, imageUrl)
   local source = source
   local xPlayer = ESX.GetPlayerFromId(source)
   
   if not IsPolice(source) then return end
   
   MySQL.update('UPDATE users SET mugshot = ? WHERE identifier = ?', {
       imageUrl,
       citizenId
}, function(affectedRows)
       if affectedRows > 0 then
           SendNotificationToPlayer(source, 'success', 'Casier Judiciaire', 'Photo d\'identification ajoutée au casier judiciaire')
           
           -- Récupérer le nom du citoyen pour le log
           MySQL.query('SELECT firstname, lastname FROM users WHERE identifier = ?', {
               citizenId
           }, function(result)
               local citizenName = "Inconnu"
               if result and result[1] then
                   citizenName = result[1].firstname .. " " .. result[1].lastname
               end
               
               -- Log Discord
               local embed = exports['J_PoliceNat']:FormatEmbed(
                   "Casier Judiciaire - Photo ajoutée",
                   ('L\'agent %s a ajouté une photo d\'identification à %s'):format(
                       xPlayer.getName(),
                       citizenName
                   ),
                   3066993
               )
               exports['J_PoliceNat']:SendToDiscord(Config.DiscordWebhook.casier, "Police Nationale - Casier Judiciaire", nil, {embed})
           end)
       else
           SendNotificationToPlayer(source, 'error', 'Casier Judiciaire', 'Impossible d\'ajouter la photo au casier judiciaire')
       end
   end)
end)



-- =============================================
-- Récupération des licences
-- =============================================

-- Récupération des licences (version améliorée qui vérifie nos documents personnalisés)
RegisterServerEvent('police:checkLicenses')
AddEventHandler('police:checkLicenses', function(target)
   local source = source
   if not IsPolice(source) or not onDutyPlayers[ESX.GetPlayerFromId(source).identifier] then return end
   
   local xTarget = ESX.GetPlayerFromId(target)
   if not xTarget then return end
   
   -- Utiliser uniquement les documents personnalisés via rp-identity
   local documents = exports['rp-identity']:getPlayerDocuments(xTarget.identifier)
   
   -- Préparer la structure pour l'affichage
   local licenses = {
       identity_card = documents.ID and documents.ID.expirationDate > os.time(),
       drive = documents.Driver and documents.Driver.expirationDate > os.time(),
       weapon = documents.Weapon and documents.Weapon.expirationDate > os.time()
   }
   
   -- Envoyer les résultats au client
   TriggerClientEvent('police:showLicenses', source, licenses)
end)



-- Événement pour révoquer un document par ID citoyen
RegisterServerEvent('police:revokeDocumentById')
AddEventHandler('police:revokeDocumentById', function(citizenId, docType, reason)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer or xPlayer.job.name ~= 'police' then
        SendNotificationToPlayer(source, 'error', 'Police', 'Vous n\'êtes pas autorisé à faire cela')
        return
    end
    
    -- Vérifier que le type de document est autorisé à être révoqué
    if docType ~= 'Driver' and docType ~= 'Weapon' then
        SendNotificationToPlayer(source, 'error', 'Police', 'Vous ne pouvez pas révoquer ce type de document')
        return
    end
    
    -- Déterminer le type de license à supprimer dans user_licenses
    local licenseType = nil
    if docType == 'Driver' then
        licenseType = 'drive'
    elseif docType == 'Weapon' then
        licenseType = 'weapon'
    end
    
    -- Supprimer d'abord le document
    MySQL.update('DELETE FROM user_documents WHERE owner = ? AND type = ?', {
        citizenId,
        docType
    }, function(affectedRows)
        local documentDeleted = (affectedRows > 0)
        
        -- Supprimer ensuite l'entrée correspondante dans user_licenses
        if licenseType then
            MySQL.update('DELETE FROM user_licenses WHERE owner = ? AND type = ?', {
                citizenId,
                licenseType
            }, function(licenseRows)
                local licenseDeleted = (licenseRows > 0)
                
                -- Si au moins une suppression a réussi, considérer l'opération comme un succès
                if documentDeleted or licenseDeleted then
                    -- Notification à l'agent
                    SendNotificationToPlayer(source, 'success', 'Permis', 'Permis révoqué avec succès')
                    
                    -- Log Discord
                    local embed = exports['J_PoliceNat']:FormatEmbed(
                        "Révocation de permis",
                        ('L\'agent %s a révoqué le permis %s'):format(
                            xPlayer.getName(),
                            docType
                        ),
                        15158332,
                        {{name = "Motif", value = reason}}
                    )
                    exports['J_PoliceNat']:SendToDiscord(Config.DiscordWebhook.alerts, "Police Nationale - Permis", nil, {embed})
                    
                    -- Notifier le joueur si en ligne
                    local xTarget = nil
                    for _, playerId in ipairs(GetPlayers()) do
                        local playerObj = ESX.GetPlayerFromId(playerId)
                        if playerObj and playerObj.identifier == citizenId then
                            xTarget = playerObj
                            break
                        end
                    end
                    
                    if xTarget then
                        SendNotificationToPlayer(xTarget.source, 'error', 'Permis', 'Votre permis a été révoqué: ' .. reason)
                    end
                else
                    SendNotificationToPlayer(source, 'error', 'Permis', 'Ce citoyen ne possède pas ce permis')
                end
            end)
        else
            -- Si aucun type de license n'est identifié (ne devrait pas arriver avec nos vérifications)
            if documentDeleted then
                SendNotificationToPlayer(source, 'success', 'Permis', 'Permis révoqué avec succès')
            else
                SendNotificationToPlayer(source, 'error', 'Permis', 'Ce citoyen ne possède pas ce permis')
            end
        end
    end)
end)

RegisterServerEvent("police:syncEscortAnimation")
AddEventHandler("police:syncEscortAnimation", function(targetId, isHolding)
    print("Syncing escort animation to " .. targetId .. ", holding: " .. tostring(isHolding))
    TriggerClientEvent("police:syncEscortHolding", targetId, isHolding)
end)



-- =============================================
-- Gestion des policiers et notifications
-- =============================================

-- Récupération des policiers en service
function GetOnDutyPolice()
   local officers = {}
   local xPlayers = ESX.GetPlayers()
   
   for _, playerId in ipairs(xPlayers) do
       local xPlayer = ESX.GetPlayerFromId(playerId)
       if xPlayer.job.name == 'police' and onDutyPlayers[xPlayer.identifier] then
           table.insert(officers, {
               source = playerId,
               name = xPlayer.getName(),
               grade = xPlayer.job.grade
           })
       end
   end
   
   return officers
end

-- Notification à tous les policiers en service
function NotifyOnDutyPolice(title, message, type)
   local officers = GetOnDutyPolice()
   for _, officer in ipairs(officers) do
       SendNotificationToPlayer(officer.source, type or 'info', title, message)
   end
end

-- =============================================
-- Utilitaires
-- =============================================

-- Nettoyage à la déconnexion
AddEventHandler('playerDropped', function()
   local source = source
   local xPlayer = ESX.GetPlayerFromId(source)
   if xPlayer and xPlayer.job.name == 'police' then
       onDutyPlayers[xPlayer.identifier] = nil
       
       -- Informer tous les agents de police du changement
       local officers = GetOnDutyPolice()
       for _, officer in ipairs(officers) do
           TriggerClientEvent('police:updateOfficersList', officer.source)
       end
   end
end)

-- =============================================
-- Exports
-- =============================================

-- Export des fonctions utiles
exports('IsPolice', IsPolice)
exports('IsOnDuty', function(source)
   local xPlayer = ESX.GetPlayerFromId(source)
   return xPlayer and onDutyPlayers[xPlayer.identifier] or false
end)
exports('GetOnDutyPolice', GetOnDutyPolice)
exports('NotifyOnDutyPolice', NotifyOnDutyPolice)
exports('getPendingWeaponLicenses', function()
   return pendingWeaponLicenses
end)