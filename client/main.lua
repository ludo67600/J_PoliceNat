-- J_PoliceNat client/main.lua (version avec interface Vue.js)
local ESX = exports["es_extended"]:getSharedObject()

-- =============================================
-- Variables locales et initialisation
-- =============================================
local PlayerData = {}
local isOnDuty = false
local currentAlert = nil
local activeBlips = {}
uiOpen = false

-- Variables globales pour les rendez-vous
local appointmentsCache = {}
local appointmentsPromise = nil

-- Variables pour la liste des agents en service
local onDutyOfficers = {}

-- Initialisation
CreateThread(function()
    Wait(1000)
    while ESX.GetPlayerData().job == nil do
        Wait(100)
    end
    PlayerData = ESX.GetPlayerData()
    InitializeTargetPoints()
    CreateLocationPeds()
end)

-- Mise à jour des données joueur
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
    Wait(500)
    if PlayerData.job.name == 'police' then
        TriggerServerEvent('police:getDutyStatus')
    end
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
    if job.name ~= 'police' then
        isOnDuty = false
    end
end)

-- =============================================
-- Interface NUI
-- =============================================

-- Récupérer la liste des agents en service
function RefreshOnDutyOfficers()
    ESX.TriggerServerCallback('police:getOnDutyOfficers', function(officers)
        onDutyOfficers = officers or {}
        
        -- Mise à jour de l'interface si elle est ouverte
        if uiOpen then
            SendNUIMessage({
                type = 'updateOfficersList',
                officers = onDutyOfficers
            })
        end
    end)
end

-- Ouvrir l'interface
function OpenPoliceUI()
    if uiOpen then return end
    
    -- Récupérer la liste des agents en service
    RefreshOnDutyOfficers()
    
    -- Préparer les données pour l'interface
    local data = {
        type = 'open',
        playerData = {
            id = GetPlayerServerId(PlayerId()),
            name = GetPlayerName(PlayerId()),
            job = PlayerData.job.name,
            grade = PlayerData.job.grade,
            gradeName = GetGradeName(PlayerData.job.grade)
        },
        isOnDuty = isOnDuty,
        onDutyOfficers = onDutyOfficers,
        props = GetAvailableProps(),
        uniforms = GetAvailableUniforms(),
        fineCategories = Config.Fines.categories,
        alertCodes = Config.Alerts.radioCodes,
        hasK9 = DoesK9Exist()
    }
    
    -- Afficher l'interface
    SendNUIMessage(data)
    SetNuiFocus(true, true)
    uiOpen = true
end

-- Fermer l'interface
function ClosePoliceUI()
    SendNUIMessage({
        type = 'close'
    })
    SetNuiFocus(false, false)
    uiOpen = false
end

-- Vérification du service et du grade
function IsOnDuty()
    return isOnDuty and PlayerData.job and PlayerData.job.name == Config.Job.name
end

function HasMinimumGrade(minGrade)
    return PlayerData.job and PlayerData.job.grade >= minGrade
end

-- Obtenir le nom du grade
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
    
    return gradeNames[grade] or "Policier Adjoint"
end

-- =============================================
-- Création des PNJ aux points d'interaction
-- =============================================
function CreateLocationPeds()
    -- Créer un PNJ pour chaque emplacement configuré
    for location, data in pairs(Config.Locations) do
        if data.ped then
            local model = GetHashKey(data.ped.model)
            
            -- Charger le modèle
            RequestModel(model)
            while not HasModelLoaded(model) do
                Wait(10)
            end
            
            -- Créer le PNJ
            local ped = CreatePed(4, model, data.coords.x, data.coords.y, data.coords.z - 1.0, data.ped.heading, false, true)
            
            -- Configurer le PNJ
            SetEntityHeading(ped, data.ped.heading)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            
            -- Exécuter le scénario si défini
            if data.ped.scenario then
                TaskStartScenarioInPlace(ped, data.ped.scenario, 0, true)
            end
            
            -- Libérer le modèle
            SetModelAsNoLongerNeeded(model)
        end
    end
end

-- =============================================
-- Création du blip du commissariat
-- =============================================
CreateThread(function()
    -- Configuration du blip
    local blipConfig = {
        sprite = 60,    -- Sprite/icône du blip (60 = étoile de police)
        color = 38,     -- Couleur du blip (38 = bleu)
        scale = 1.0,    -- Taille du blip
        label = "Police Nationale" -- Nom affiché
    }
    
    -- Attendre que la carte soit chargée
    Wait(2000)
    
    -- Créer le blip à l'emplacement de l'accueil
    local coords = Config.Locations.main.coords
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    
    -- Configurer l'apparence du blip
    SetBlipSprite(blip, blipConfig.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, blipConfig.scale)
    SetBlipColour(blip, blipConfig.color)
    SetBlipAsShortRange(blip, true)
    
    -- Ajouter un nom au blip
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(blipConfig.label)
    EndTextCommandSetBlipName(blip)
end)

-- =============================================
-- Gestion du service (on/off duty)
-- =============================================

-- Bascule du statut de service
function ToggleDuty()
    if not PlayerData.job or PlayerData.job.name ~= Config.Job.name then return end
    local newDutyStatus = not isOnDuty
    TriggerServerEvent('police:toggleDuty', newDutyStatus)
end

-- Réception du statut de service
RegisterNetEvent('police:setDuty')
AddEventHandler('police:setDuty', function(newStatus)
    isOnDuty = newStatus
    
    -- Mise à jour de l'interface si elle est ouverte
    if uiOpen then
        SendNUIMessage({
            type = 'updateDuty',
            isOnDuty = isOnDuty
        })
        
        -- Mettre à jour la liste des agents en service
        RefreshOnDutyOfficers()
    end
end)

-- Mise à jour de la liste des agents en service
RegisterNetEvent('police:updateOfficersList')
AddEventHandler('police:updateOfficersList', function()
    -- Mettre à jour la liste uniquement si on est policier
    if PlayerData.job and PlayerData.job.name == 'police' then
        RefreshOnDutyOfficers()
    end
end)

-- =============================================
-- Initialisation des points d'interaction (ox_target)
-- =============================================

function InitializeTargetPoints()
    -- Point d'accueil
    exports.ox_target:addBoxZone({
        coords = Config.Locations.main.coords,
        size = vec3(1.0, 1.0, 2.0),
        rotation = 0.0,
        options = {
            {
                name = 'police_reception',
                icon = 'fa-solid fa-clipboard',
                label = 'Accueil Police',
                distance = 2.5,
                onSelect = function()
                    OpenReceptionMenu()
                end
            }
        }
    })

    -- Vestiaire
    exports.ox_target:addBoxZone({
        coords = Config.Locations.vestiaire.coords,
        size = vec3(1.5, 1.5, 2.0),
        rotation = 0.0,
        options = {
            {
                name = 'police_cloakroom',
                icon = 'fa-solid fa-shirt',
                label = 'Vestiaire',
                distance = 2.5,
                canInteract = function()
                    return PlayerData.job and PlayerData.job.name == 'police'
                end,
                onSelect = function()
                    ExecuteFunction("clothing")
                end
            }
        }
    })

    -- Garage
    exports.ox_target:addBoxZone({
        coords = Config.Locations.garage.coords,
        size = vec3(3.0, 3.0, 2.0),
        rotation = 0.0,
        options = {
            {
                name = 'police_garage',
                icon = 'fa-solid fa-car',
                label = 'Garage',
                distance = 3.5,
                canInteract = function()
                    return IsOnDuty()
                end,
                onSelect = function()
                    OpenGarageMenu()
                end
            }
        }
    })

    -- Armurerie
    exports.ox_target:addBoxZone({
        coords = Config.Locations.armory.coords,
        size = vec3(1.5, 1.5, 2.0),
        rotation = 0.0,
        options = {
            {
                name = 'police_armory',
                icon = 'fa-solid fa-shield',
                label = 'Armurerie',
                distance = 2.5,
                canInteract = function()
                    return IsOnDuty()
                end,
                onSelect = function()
                    TriggerEvent('ox_inventory:openInventory', 'shop', {type = 'Police Armoury'})
                end
            }
        }
    })
end

-- Fonction pour ouvrir le menu du vestiaire
function OpenCloakroomMenu()
    -- Vérifier que le joueur est bien gendarme
    if not PlayerData.job or PlayerData.job.name ~= Config.Job.name then
        return
    end
    
    -- Utiliser ox_lib pour créer un menu contextuel
    local elements = {
        {
            title = 'Tenue civile',
            description = 'Retourner en tenue civile',
            icon = 'shirt',
            onSelect = function()
                ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
                    TriggerEvent('skinchanger:loadSkin', skin)
                end)
            end
        },
        {
            title = 'Tenues de service',
            description = 'Voir les tenues disponibles',
            icon = 'fas fa-person-military-pointing',
            onSelect = function()
                OpenUniformsSubMenu()
            end
        }
    }

    lib.registerContext({
        id = 'police_cloakroom',
        title = 'Vestiaire Police',
        options = elements
    })

    lib.showContext('police_cloakroom')
end

-- Sous-menu pour les uniformes
function OpenUniformsSubMenu()
    local elements = {}
    
    -- Filtrer les uniformes selon le grade
    for _, uniform in ipairs(Config.Uniforms) do
        if PlayerData.job.grade >= uniform.minGrade then
            table.insert(elements, {
                title = uniform.label,
                description = 'Porter cette tenue',
                onSelect = function()
                    ApplyUniform(uniform)
                end
            })
        end
    end
    
    lib.registerContext({
        id = 'police_uniforms',
        title = 'Tenues de service',
        menu = 'police_cloakroom',
        options = elements
    })

    lib.showContext('police_uniforms')
end

-- Fonction pour appliquer un uniforme
function ApplyUniform(uniform)
    local playerPed = PlayerPedId()
    
    ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
        -- Choix du skin selon le sexe du joueur
        local uniformData = nil
        
        if skin.sex == 0 then
            uniformData = uniform.male
        else
            uniformData = uniform.female
        end
        
        if uniformData then
            TriggerEvent('skinchanger:loadClothes', skin, uniformData)
            SendNotification('success', 'Vestiaire', 'Tenue changée avec succès')
        else
            SendNotification('error', 'Vestiaire', 'Tenue non disponible pour votre genre')
        end
    end)
end

-- =============================================
-- Gestion des rendez-vous
-- =============================================

-- Enregistrement central de l'événement de rendez-vous
RegisterNetEvent('police:showOfficerAppointments')
AddEventHandler('police:showOfficerAppointments', function(appointments)
    -- Stocker les rendez-vous reçus
    appointmentsCache = appointments or {}
    
    -- Résoudre la promesse si elle existe
    if appointmentsPromise then
        appointmentsPromise:resolve(appointmentsCache)
        appointmentsPromise = nil
    end
    
    -- Si l'interface Vue.js est ouverte, lui envoyer les données
    if uiOpen then
        SendNUIMessage({
            type = 'updateAppointments',
            appointments = appointmentsCache
        })
        return -- Ne pas ouvrir le menu ox_lib si l'interface Vue.js est ouverte
    end
    
    -- Sinon utiliser le menu ox_lib
    local elements = {}
    
    for _, appointment in ipairs(appointmentsCache) do
        local statusColor = {
            ['En attente'] = 'yellow',
            ['Accepté'] = 'green',
            ['Terminé'] = 'gray',
            ['Annulé'] = 'red'
        }
        
        table.insert(elements, {
            title = appointment.subject,
            description = ('Date: %s à %s - Statut: %s'):format(appointment.date, appointment.time, appointment.status),
            metadata = {
                {label = 'Citoyen', value = appointment.citizen_name or 'Inconnu'},
                {label = 'Description', value = appointment.description}
            },
            icon = appointment.status == 'En attente' and 'bell' or 'calendar',
            onSelect = function()
                OpenAppointmentDetailsMenu(appointment)
            end
        })
    end
    
    if #elements == 0 then
        table.insert(elements, {
            title = 'Aucun rendez-vous',
            description = 'Aucun rendez-vous à traiter',
            disabled = true
        })
    end

    lib.registerContext({
        id = 'officer_appointments',
        title = 'Gestion des Rendez-vous',
        options = elements
    })

    lib.showContext('officer_appointments')
end)

-- =============================================
-- Fonction centrale standardisée pour les notifications
-- =============================================
function SendNotification(type, title, message)
    -- On utilise toujours jl_notifications sauf pour les notifications de service qui utilisent aussi l'UI
    exports['jl_notifications']:ShowNotification({
        type = type,
        message = message,
        title = title,
        image = 'img/policenat.png',
        duration = 5000
    })
    
    -- Uniquement pour prise/fin de service - On envoie aussi à l'UI si elle est ouverte
    if title == 'Service' and uiOpen then
        SendNUIMessage({
            type = 'notification',
            title = title,
            message = message,
            notificationType = type
        })
    end
end

-- =============================================
-- Callbacks NUI
-- =============================================

-- Callback pour fermer l'UI
RegisterNUICallback('closeUI', function(data, cb)
    ClosePoliceUI()
    cb({})
end)

-- Callback quand l'UI est prête
RegisterNUICallback('uiReady', function(data, cb)
    cb({})
end)

-- Callback pour changer l'état de service
RegisterNUICallback('toggleDuty', function(data, cb)
    ToggleDuty()
    cb({success = true, isOnDuty = isOnDuty})
end)

-- Callback pour exécuter une action
RegisterNUICallback('executeAction', function(data, cb)
    -- Liste des actions qui doivent fermer l'interface
    local closeUIActions = {
        -- Actions citoyens
        "handcuff", "escort", "putInVehicle", "outOfVehicle", "search",
        -- Actions véhicules
        "impound", "unlock",
        -- Actions K9
        "k9Sit", "k9Follow", "k9Attack", "k9Search"
    }
    
    -- Vérifier si l'action doit fermer l'interface
    local shouldCloseUI = false
    for _, closeAction in ipairs(closeUIActions) do
        if data.action == closeAction then
            shouldCloseUI = true
            break
        end
    end
    
    -- Fermer l'interface avant d'exécuter l'action si nécessaire
    if shouldCloseUI then
        -- Envoyer un message pour cacher l'interface
        SendNUIMessage({
            type = 'close'
        })
        -- Désactiver le focus du curseur
        SetNuiFocus(false, false)
        uiOpen = false
        
        -- Petit délai pour s'assurer que l'UI est fermée avant d'exécuter l'action
        Wait(100)
    end
    
    -- Exécuter l'action après avoir fermé l'interface
    local result = ExecuteFunction(data.action)
    cb(result or {success = true})
end)

-- Callback pour appliquer une tenue
RegisterNUICallback('applyUniform', function(data, cb)
    local uniform = data.uniform
    
    ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
        if skin.sex == 0 then
            TriggerEvent('skinchanger:loadClothes', skin, uniform.male)
        else
            TriggerEvent('skinchanger:loadClothes', skin, uniform.female)
        end
    end)
    
    cb({success = true})
end)

-- Callback pour récupérer les accessoires disponibles
RegisterNUICallback('getAccessories', function(data, cb)
    local type = data.type
    local accessories = {}
    
    for _, accessory in ipairs(Config.Accessories[type]) do
        if HasMinimumGrade(accessory.minGrade) then
            table.insert(accessories, accessory)
        end
    end
    
    cb({success = true, accessories = accessories})
end)

-- Callback pour appliquer un accessoire
RegisterNUICallback('applyAccessory', function(data, cb)
    local type = data.type
    local accessory = data.accessory
    
    ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
        local accessoryItems = {}
        
        if skin.sex == 0 then -- Homme
            accessoryItems = accessory.male
        else -- Femme
            accessoryItems = accessory.female
        end
        
        local currentSkin = {}
        TriggerEvent('skinchanger:getSkin', function(getSkin)
            currentSkin = getSkin
        end)
        
        -- Appliquer uniquement les éléments de l'accessoire
        for k, v in pairs(accessoryItems) do
            currentSkin[k] = v
        end
        
        TriggerEvent('skinchanger:loadSkin', currentSkin)
    end)
    
    cb({success = true})
end)

-- Callback pour retirer un accessoire
RegisterNUICallback('removeAccessory', function(data, cb)
    local type = data.type
    
    ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
        local currentSkin = {}
        TriggerEvent('skinchanger:getSkin', function(getSkin)
            currentSkin = getSkin
        end)
        
        -- Réinitialiser les valeurs selon la catégorie
        if type == 'helmets' then
            currentSkin['helmet_1'] = -1
            currentSkin['helmet_2'] = 0
        elseif type == 'vests' then
            currentSkin['bproof_1'] = 0
            currentSkin['bproof_2'] = 0
        elseif type == 'bracelets' then
            -- Comme il peut s'agir soit de tshirt, soit de chain, on réinitialise les deux
            if currentSkin['tshirt_1'] == 56 then -- Brassard Chaine
                currentSkin['tshirt_1'] = 105 -- Valeur par défaut des uniformes
                currentSkin['tshirt_2'] = 0
            end
            if currentSkin['chain_1'] == 7 then -- Brassard
                currentSkin['chain_1'] = 3 -- Valeur par défaut des uniformes
                currentSkin['chain_2'] = 0
            end
        end
        
        TriggerEvent('skinchanger:loadSkin', currentSkin)
    end)
    
    cb({success = true})
end)

-- Callback pour soumettre une amende
RegisterNUICallback('submitFine', function(data, cb)
    local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
    if closestPlayer == -1 or closestDistance > 3.0 then
        cb({success = false, message = "Aucun joueur à proximité"})
        return
    end
    
    TriggerServerEvent('police:finePlayer', GetPlayerServerId(closestPlayer), data.amount, data.reason)
    cb({success = true})
end)

-- Callback pour récupérer les rendez-vous
RegisterNUICallback('getAppointments', function(data, cb)
    -- Créer une nouvelle promesse
    appointmentsPromise = promise.new()
    
    -- Déclencher l'événement serveur
    TriggerServerEvent('police:getOfficerAppointments')
    
    -- Attendre max 5 secondes pour la réponse
    local success, result = pcall(function()
        return Citizen.Await(appointmentsPromise, 5000)
    end)
    
    if success then
        cb({success = true, appointments = result})
    else
        cb({success = false, appointments = {}})
    end
end)

-- Callbacks pour gérer les rendez-vous
RegisterNUICallback('acceptAppointment', function(data, cb)
    TriggerServerEvent('police:acceptAppointment', data.id)
    cb({success = true})
end)

RegisterNUICallback('finishAppointment', function(data, cb)
    TriggerServerEvent('police:finishAppointment', data.id)
    cb({success = true})
end)

RegisterNUICallback('cancelAppointment', function(data, cb)
    TriggerServerEvent('police:cancelAppointment', data.id)
    cb({success = true})
end)

-- Callback pour récupérer les plaintes
RegisterNUICallback('getComplaints', function(data, cb)
    ESX.TriggerServerCallback('police:getComplaints', function(complaints)
        cb({success = true, complaints = complaints or {}})
    end)
end)

-- Callback pour gérer les plaintes
RegisterNUICallback('registerComplaint', function(data, cb)
    TriggerServerEvent('police:registerComplaint', data)
    cb({success = true})
end)

RegisterNUICallback('closeComplaint', function(data, cb)
    TriggerServerEvent('police:closeComplaint', data.id, data.closeReport)
    cb({success = true})
end)

-- Callback pour le casier judiciaire
RegisterNUICallback('searchCriminalRecords', function(data, cb)
    ESX.TriggerServerCallback('police:searchCitizenByDocumentNumber', function(result)
        if result then
            cb({success = true, citizen = result.citizen, criminalRecords = result.criminalRecords, documents = result.documents})
        else
            cb({success = false})
        end
    end, data.documentNumber)
end)

RegisterNUICallback('addCriminalRecord', function(data, cb)
    TriggerServerEvent('police:addCriminalRecord', data)
    cb({success = true})
end)

RegisterNUICallback('deleteCriminalRecord', function(data, cb)
    TriggerServerEvent('police:deleteCriminalRecord', data.id)
    cb({success = true})
end)

-- Callback pour récupérer les photos de la galerie
RegisterNUICallback('getOfficerGallery', function(data, cb)
    ESX.TriggerServerCallback('police:getOfficerGallery', function(gallery)
        cb({success = true, gallery = gallery})
    end)
end)

-- Callback pour définir une photo d'identification
RegisterNUICallback('setMugshot', function(data, cb)
    TriggerServerEvent('police:updateMugshot', data.citizenId, data.imageUrl)
    cb({success = true})
end)

-- Callback pour les alertes
RegisterNUICallback('sendAlert', function(data, cb)
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('police:sendAlert', data.code, coords)
    cb({success = true})
end)

-- Callback pour changer de section active
RegisterNUICallback('setActiveSection', function(data, cb)
    -- On peut ajouter un comportement spécifique pour chaque section si nécessaire
    cb({success = true})
end)

-- Callback pour marquer un véhicule comme retrouvé (via l'interface Vue.js)
RegisterNUICallback('recoverStolenVehicle', function(data, cb)
    TriggerServerEvent('police:recoverStolenVehicle', data.plate, true)
    cb({success = true})
end)

-- Callback pour la confirmation de mise en fourrière
RegisterNUICallback('confirmImpound', function(data, cb)
    local vehicle = GetVehicleInDirection()
    if not vehicle then
        SendNotification('error', 'Police', 'Aucun véhicule à proximité')
        cb({success = false})
        return
    end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    local networkId = NetworkGetNetworkIdFromEntity(vehicle)
    currentTask = true
    
    if lib.progressBar({
        duration = Config.Animations.impound,
        label = 'Mise en fourrière...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped',
            flags = 49
        },
    }) then
        TriggerServerEvent('police:impoundVehicle', plate, GetEntityCoords(vehicle), networkId)
        cb({success = true})
    else
        cb({success = false})
    end
    
    currentTask = false
end)

-- Callback pour révoquer un document
RegisterNUICallback('revokeDocument', function(data, cb)
    local citizenId = data.citizenId
    local docType = data.type
    local reason = data.reason
    
    if not citizenId or not docType or not reason then
        cb({success = false, message = "Paramètres invalides"})
        return
    end
    
    -- Au lieu d'essayer d'accéder à MySQL directement, envoyez un événement au serveur
    TriggerServerEvent('police:revokeDocumentById', citizenId, docType, reason)
    
    -- Supposons que ça fonctionne et renvoyons une réponse positive
    cb({success = true})
end)


-- Callback pour ouvrir le menu boss
RegisterNUICallback('openBossMenu', function(data, cb)
    OpenBossMenu()
    cb({success = true})
end)

-- =============================================
-- Exécution des fonctions d'action
-- =============================================

-- Fonction centrale pour exécuter les différentes actions
function ExecuteFunction(action)
    -- Gestion du K9
    if action == "spawnK9" then
        if not DoesK9Exist() then
            TriggerEvent("police:spawnK9")
            return {success = true, hasK9 = true}
        end
    elseif action == "dismissK9" then
        if DoesK9Exist() then
            TriggerEvent("police:dismissK9")
            return {success = true, hasK9 = false}
        end
    elseif action == "k9Sit" then
        TriggerEvent("police:k9Sit")
    elseif action == "k9Follow" then
        TriggerEvent("police:k9Follow")
    elseif action == "k9Attack" then
        TriggerEvent("police:k9Attack")
    elseif action == "k9Search" then
        TriggerEvent("police:k9Search")
    
    -- Gestion des tenues
    elseif action == "civilianClothes" then
        ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
            TriggerEvent('skinchanger:loadSkin', skin)
        end)
    elseif action == "removeAllAccessories" then
        ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
            local currentSkin = {}
            TriggerEvent('skinchanger:getSkin', function(getSkin)
                currentSkin = getSkin
            end)
            
            -- Réinitialiser tous les accessoires
            currentSkin['helmet_1'] = -1
            currentSkin['helmet_2'] = 0
            currentSkin['bproof_1'] = 0
            currentSkin['bproof_2'] = 0
            
            -- Réinitialiser les brassards (avec les valeurs par défaut des uniformes)
            currentSkin['tshirt_1'] = 105
            currentSkin['tshirt_2'] = 0
            currentSkin['chain_1'] = 3
            currentSkin['chain_2'] = 0
            
            TriggerEvent('skinchanger:loadSkin', currentSkin)
        end)
    
    -- Gestion des citoyens
    elseif action == "handcuff" then
        HandcuffAction()
    elseif action == "escort" then
        EscortAction()
    elseif action == "putInVehicle" then
        PutInVehicleAction()
    elseif action == "outOfVehicle" then
        OutOfVehicleAction()
    elseif action == "search" then
        SearchAction()
    
    -- Gestion des véhicules
    elseif action == "checkVehicle" then
        CheckVehicleAction()
    elseif action == "impound" then
        ImpoundAction()
    elseif action == "unlock" then
        UnlockAction()
    elseif action == "recoverVehicle" then
        RecoverVehicleAction()
    elseif action == "stolenList" then
        OpenStolenVehiclesListMenu()
    
    -- Gestion des permis
    elseif action == "checkLicenses" then
        CheckCitizenLicenses()
    elseif action == "issueWeaponLicense" then
        IssueWeaponLicense()
    elseif action == "revokeLicense" then
        -- Géré directement via le formulaire NUI
    
    -- Gestion des objets
    elseif action:find("placeProp_") then
        local propModel = action:gsub("placeProp_", "")
        StartPlacingProp(propModel)
    elseif action == "removeProp" then
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local closestObject = nil
        local closestDistance = 5.0
        
        -- Trouver l'objet le plus proche
        for i, object in ipairs(GetGamePool('CObject')) do
            local objCoords = GetEntityCoords(object)
            local distance = #(coords - objCoords)
            if distance < closestDistance then
                closestObject = object
                closestDistance = distance
            end
        end
        
        if closestObject and DoesEntityExist(closestObject) then
            local objCoords = GetEntityCoords(closestObject)
            local model = GetEntityModel(closestObject)
            
            -- Trouver le nom du modèle
            local modelName = nil
            for _, p in ipairs(Config.Props) do
                if GetHashKey(p.model) == model then
                    modelName = p.model
                    break
                end
            end
            
            if modelName then
                -- Informer le serveur
                TriggerServerEvent('police:removeProp', {
                    model = modelName,
                    coords = objCoords,
                    heading = GetEntityHeading(closestObject)
                })
                
                -- Supprimer l'objet localement
                DeleteObject(closestObject)
            end
        end
    
    -- Autres actions
    elseif action == "clothing" then
        OpenCloakroomMenu()
    elseif action == "bossMenu" then
        OpenBossMenu()
    else
        -- Action non reconnue
        return {success = false, message = "Action non reconnue"}
    end
    
    return {success = true}
end

-- Obtenir les props disponibles en fonction du grade
function GetAvailableProps()
    local availableProps = {}
    
    for _, prop in ipairs(Config.Props) do
        if HasMinimumGrade(prop.minGrade) then
            table.insert(availableProps, prop)
        end
    end
    
    return availableProps
end

-- Obtenir les tenues disponibles en fonction du grade
function GetAvailableUniforms()
    local availableUniforms = {}
    
    for _, uniform in ipairs(Config.Uniforms) do
        if HasMinimumGrade(uniform.minGrade) then
            table.insert(availableUniforms, uniform)
        end
    end
    
    return availableUniforms
end

-- Fonction pour ouvrir le menu boss
function OpenBossMenu()
    TriggerEvent('esx_society:openBossMenu', 'police', function(data, menu)
    end, {wash = false})
end

-- =============================================
-- Events
-- =============================================

-- Réception des alertes radio
RegisterNetEvent('police:receiveAlert')
AddEventHandler('police:receiveAlert', function(code, coords, officerName)
    -- Trouver les informations du code d'alerte
    local codeInfo = nil
    for _, codeData in ipairs(Config.Alerts.radioCodes) do
        if codeData.code == code then
            codeInfo = codeData
            break
        end
    end
    
    if not codeInfo then return end
    
    -- Notification
    SendNotification('error', 'Alerte ' .. code, officerName .. ': ' .. codeInfo.label)
    
-- Création d'un blip temporaire
   local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
   SetBlipSprite(blip, Config.Alerts.blip.sprite)
   SetBlipColour(blip, Config.Alerts.blip.color)
   SetBlipScale(blip, Config.Alerts.blip.scale)
   BeginTextCommandSetBlipName("STRING")
   AddTextComponentString('Alerte: ' .. code)
   EndTextCommandSetBlipName(blip)
   
   -- Ajouter à la liste des blips actifs
   table.insert(activeBlips, {
       blip = blip,
       time = GetGameTimer() + (Config.Alerts.duration * 1000)
   })
   
   -- S'assurer que le thread de nettoyage est actif
   if #activeBlips == 1 then
       CreateThread(function()
           while #activeBlips > 0 do
               local currentTime = GetGameTimer()
               for i = #activeBlips, 1, -1 do
                   if currentTime > activeBlips[i].time then
                       RemoveBlip(activeBlips[i].blip)
                       table.remove(activeBlips, i)
                   end
               end
               Wait(1000)
           end
       end)
   end
end)

-- =============================================
-- Commandes et keybinds
-- =============================================

-- Menu F6
RegisterCommand('policemenu', function()
   if not PlayerData.job or PlayerData.job.name ~= Config.Job.name then return end
   OpenPoliceUI()
end)

RegisterKeyMapping('policemenu', 'Menu Police', 'keyboard', 'F6')

-- =============================================
-- Callbacks
-- =============================================

-- Vérification K9
function DoesK9Exist()
   return exports['J_PoliceNat']:DoesK9Exist()
end

-- Spawn K9
RegisterNetEvent('police:spawnK9')
AddEventHandler('police:spawnK9', function()
   exports['J_PoliceNat']:SpawnPoliceDog()
   
   -- Mise à jour de l'interface si elle est ouverte
   if uiOpen then
       SendNUIMessage({
           type = 'updateK9',
           hasK9 = true
       })
   end
end)

-- Dismiss K9
RegisterNetEvent('police:dismissK9')
AddEventHandler('police:dismissK9', function()
   exports['J_PoliceNat']:DespawnPoliceDog()
   
   -- Mise à jour de l'interface si elle est ouverte
   if uiOpen then
       SendNUIMessage({
           type = 'updateK9',
           hasK9 = false
      })
  end
end)

-- K9 Sit
RegisterNetEvent('police:k9Sit')
AddEventHandler('police:k9Sit', function()
  exports['J_PoliceNat']:CommandSit()
end)

-- K9 Follow
RegisterNetEvent('police:k9Follow')
AddEventHandler('police:k9Follow', function()
  exports['J_PoliceNat']:CommandFollow()
end)

-- K9 Attack
RegisterNetEvent('police:k9Attack')
AddEventHandler('police:k9Attack', function()
  exports['J_PoliceNat']:CommandAttack()
end)

-- K9 Search
RegisterNetEvent('police:k9Search')
AddEventHandler('police:k9Search', function()
  exports['J_PoliceNat']:CommandSearch()
end)