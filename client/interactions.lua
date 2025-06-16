-- J_PoliceNat client/interactions.lua (version avec interface Vue.js)
local ESX = exports["es_extended"]:getSharedObject()

-- =============================================
-- Variables locales
-- =============================================
local draggedPlayer = nil
local isHandcuffed = false
local isDragged = false
isEscorting = false
local escortAnimThread = nil


-- =============================================
-- Actions de restriction (Menottes, escorte, etc.)
-- =============================================

-- Action Menotter
function HandcuffAction()
   local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
   if closestPlayer == -1 or closestDistance > 3.0 then
       SendNotification('error', 'Police', 'Aucun joueur à proximité')
       return
   end

   lib.progressBar({
       duration = Config.Animations.handcuff,
       label = 'Application des menottes...',
       useWhileDead = false,
       canCancel = true,
       disable = {
           car = true,
           move = true,
           combat = true
       },
       anim = {
           dict = 'mp_arrest_paired',
           clip = 'cop_p2_back_right',
           flags = 51
       },
   })

   TriggerServerEvent('police:handcuffPlayer', GetPlayerServerId(closestPlayer))
end

-- Event pour être menotté
RegisterNetEvent('police:getHandcuffed')
AddEventHandler('police:getHandcuffed', function()
   isHandcuffed = not isHandcuffed
   local playerPed = PlayerPedId()

   if isHandcuffed then
       RequestAnimDict('mp_arresting')
       while not HasAnimDictLoaded('mp_arresting') do
           Wait(100)
       end

       TaskPlayAnim(playerPed, 'mp_arresting', 'idle', 8.0, -8, -1, 49, 0, 0, 0, 0)
       SetEnableHandcuffs(playerPed, true)
       DisablePlayerFiring(playerPed, true)
       SetCurrentPedWeapon(playerPed, GetHashKey('WEAPON_UNARMED'), true)
       SetPedCanPlayGestureAnims(playerPed, false)

       -- Désactivation des contrôles
       CreateThread(function()
           while isHandcuffed do
               DisableControlAction(0, 1, true) -- Look Left/Right
               DisableControlAction(0, 2, true) -- Look Up/Down
               DisableControlAction(0, 24, true) -- Attack
               DisableControlAction(0, 257, true) -- Attack 2
               DisableControlAction(0, 25, true) -- Aim
               DisableControlAction(0, 263, true) -- Melee Attack 1
               DisableControlAction(0, 45, true) -- Reload
               DisableControlAction(0, 44, true) -- Cover
               DisableControlAction(0, 37, true) -- Select Weapon
               DisableControlAction(0, 21, true) -- Sprint
               DisableControlAction(0, 22, true) -- Jump
               DisableControlAction(0, 288, true) -- F1
               DisableControlAction(0, 289, true) -- F2
               DisableControlAction(0, 170, true) -- F3
               DisableControlAction(0, 167, true) -- F6
               DisableControlAction(0, 318, true) -- F9
               Wait(0)
           end
       end)
   else
       ClearPedSecondaryTask(playerPed)
       SetEnableHandcuffs(playerPed, false)
       DisablePlayerFiring(playerPed, false)
       SetPedCanPlayGestureAnims(playerPed, true)
   end
end)

-- Action Escorter
function EscortAction()
   local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
   if closestPlayer == -1 or closestDistance > 3.0 then
       SendNotification('error', 'Police Nationale', 'Aucun joueur à proximité')
       return
   end

   -- Définir la variable d'escorte
   isEscorting = not isEscorting
   
   TriggerServerEvent('police:escortPlayer', GetPlayerServerId(closestPlayer))
end


-- Event pour être escorté
RegisterNetEvent('police:getEscorted')
AddEventHandler('police:getEscorted', function(copId)
   local playerPed = PlayerPedId()
   isDragged = not isDragged
   draggedPlayer = copId

   if isDragged then
       -- Attacher le joueur au policier avec un offset
       AttachEntityToEntity(playerPed, GetPlayerPed(GetPlayerFromServerId(draggedPlayer)), 11816, 0.0, 0.58, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
       
-- Notifier le policier de commencer son animation de maintien
       TriggerServerEvent("police:syncEscortAnimation", draggedPlayer, true)
       
       -- Démarrer le thread qui va gérer l'animation de marche
       if escortAnimationThread ~= nil then
           TerminateThread(escortAnimationThread)
           escortAnimationThread = nil
       end
       
       escortAnimationThread = CreateThread(function()
           local copPed = GetPlayerPed(GetPlayerFromServerId(draggedPlayer))
           local isMoving = false
           
           -- Choisir les animations selon l'état des menottes
           local walkDict, walkAnim
           
           -- Précharger les animations nécessaires
           if isHandcuffed then
               -- Animation de marche avec menottes
               walkDict = "mp_arresting"
               walkAnim = "walk" -- Utilisation de l'animation que vous avez suggérée
           else
               -- Animation de marche normale pour joueur escorté
               walkDict = "move_m@generic"    
               walkAnim = "walk"
           end
           
           RequestAnimDict(walkDict)
           RequestAnimDict("mp_arresting") -- Toujours précharger pour l'idle des menottes
           
           while not HasAnimDictLoaded(walkDict) or not HasAnimDictLoaded("mp_arresting") do
               Wait(10)
           end
           
           -- Animation initiale
           if isHandcuffed then
               -- Animation des menottes au début
               TaskPlayAnim(playerPed, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
           end
           
           -- Boucle principale
           while isDragged do
               if DoesEntityExist(copPed) then
                   -- Vérifier si le policier est en mouvement
                   local copSpeed = GetEntitySpeed(copPed)
                   
                   if copSpeed > 0.1 and not isMoving then
                       -- Le policier commence à se déplacer
                       isMoving = true
                       print("Starting movement, handcuffed: " .. tostring(isHandcuffed))
                       ClearPedTasks(playerPed)
                       
                       -- Animation de marche selon l'état des menottes
                       TaskPlayAnim(playerPed, walkDict, walkAnim, 8.0, -8.0, -1, 1, 0, false, false, false)
                   elseif copSpeed <= 0.1 and isMoving then
                       -- Le policier s'arrête
                       isMoving = false
                       print("Stopping movement, handcuffed: " .. tostring(isHandcuffed))
                       ClearPedTasks(playerPed)
                       
                       -- Animation d'idle selon l'état des menottes
                       if isHandcuffed then
                           TaskPlayAnim(playerPed, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
                       end
                   end
               end
               
               Wait(200) -- Vérification régulière
           end
           
           -- Nettoyage à la fin
           if isHandcuffed then
               -- Réappliquer l'animation des menottes
               ClearPedTasks(playerPed)
               TaskPlayAnim(playerPed, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
           else
               ClearPedTasks(playerPed)
           end
       end)
   else
       -- Si on n'est plus escorté, détacher et arrêter le thread
       DetachEntity(playerPed, true, false)
       
       -- Notifier le policier d'arrêter son animation
       TriggerServerEvent("police:syncEscortAnimation", draggedPlayer, false)
       
       if escortAnimationThread ~= nil then
           TerminateThread(escortAnimationThread)
           escortAnimationThread = nil
       end
       
       -- Réappliquer l'animation selon l'état des menottes
       if isHandcuffed then
           ClearPedTasks(playerPed)
           TaskPlayAnim(playerPed, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
       else
           ClearPedTasks(playerPed)
       end
   end
end)

-- Ajouter cet événement pour le policier qui escorte
RegisterNetEvent('police:syncEscortHolding')
AddEventHandler('police:syncEscortHolding', function(isHolding)
    local playerPed = PlayerPedId()
    
    -- Arrêter le thread d'animation précédent s'il existe
    if escortAnimThread ~= nil then
        TerminateThread(escortAnimThread)
        escortAnimThread = nil
    end
    
    -- Mettre à jour l'état d'escorte
    isEscorting = isHolding
    
    if isEscorting then
        -- Animation de maintien pour le policier tenant un suspect
        local walkDict = "switch@trevor@escorted_out"
        local walkAnim = "001215_02_trvs_12_escorted_out_idle_guard2"
        local idleDict = "missminuteman_1ig_2"
        local idleAnim = "handshake_guy_a"
        
        -- Précharger les animations
        RequestAnimDict(walkDict)
        RequestAnimDict(idleDict)
        while not HasAnimDictLoaded(walkDict) or not HasAnimDictLoaded(idleDict) do
            Wait(10)
        end
        
        -- Démarrer avec l'animation à l'arrêt
        TaskPlayAnim(playerPed, idleDict, idleAnim, 8.0, -8.0, -1, 49, 0, false, false, false)
        
        -- Créer un thread pour gérer l'animation du policier
        escortAnimThread = CreateThread(function()
            local isMoving = false
            
            while isEscorting and DoesEntityExist(playerPed) do
                -- Vérifier si le policier est en mouvement
                local speed = GetEntitySpeed(playerPed)
                
                -- Debug
                print("Police speed: " .. tostring(speed) .. ", isMoving: " .. tostring(isMoving))
                
                if speed > 0.1 and not isMoving then
                    -- Le policier commence à bouger
                    isMoving = true
                    print("Starting police escort animation")
                    
                    -- Arrêter l'animation actuelle et jouer l'animation de marche
                    ClearPedTasks(playerPed)
                    TaskPlayAnim(playerPed, walkDict, walkAnim, 8.0, -8.0, -1, 49, 0, false, false, false)
                elseif speed <= 0.1 and isMoving then
                    -- Le policier s'arrête
                    isMoving = false
                    print("Stopping police escort animation")
                    
                    -- Arrêter l'animation de marche et jouer l'animation à l'arrêt
                    ClearPedTasks(playerPed)
                    TaskPlayAnim(playerPed, idleDict, idleAnim, 8.0, -8.0, -1, 49, 0, false, false, false)
                end
                
                Wait(200)
            end
            
            -- Nettoyer l'animation quand on arrête l'escorte
            ClearPedTasks(playerPed)
            isEscorting = false
        end)
    else
        -- Arrêter l'animation et réinitialiser l'état
        ClearPedTasks(playerPed)
        isEscorting = false
    end
end)

-- Ajouter ce hook pour s'assurer que l'animation s'arrête si le joueur se déconnecte ou autres
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if escortAnimThread ~= nil then
            TerminateThread(escortAnimThread)
        end
        ClearPedTasks(PlayerPedId())
        isEscorting = false
    end
end)

-- Action Mettre dans le véhicule
function PutInVehicleAction()
   local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
   if closestPlayer == -1 or closestDistance > 3.0 then
       SendNotification('error', 'Police', 'Aucun joueur à proximité')
       return
   end

   -- Utiliser une autre méthode plus fiable pour détecter les véhicules
   local playerPed = PlayerPedId()
   local coords = GetEntityCoords(playerPed)
   local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
   
   if not DoesEntityExist(vehicle) then
       SendNotification('error', 'Police', 'Aucun véhicule à proximité')
       return
   end

   TriggerServerEvent('police:putInVehicle', GetPlayerServerId(closestPlayer))
end

-- Event pour être mis dans un véhicule
RegisterNetEvent('police:putInVehicle')
AddEventHandler('police:putInVehicle', function()
   local playerPed = PlayerPedId()
   local coords = GetEntityCoords(playerPed)
   
   -- Si le joueur est escorté, on le détache d'abord et on notifie le policier
   if isDragged then
       -- Sauvegarder l'ID du policier avant de réinitialiser
       local copId = draggedPlayer
       
       isDragged = false
       draggedPlayer = nil
       DetachEntity(playerPed, true, false)
       
       -- Notifier le policier d'arrêter son animation d'escorte
       TriggerServerEvent("police:syncEscortAnimation", copId, false)
       
       -- Arrêter le thread d'animation du suspect s'il existe
       if escortAnimationThread ~= nil then
           TerminateThread(escortAnimationThread)
           escortAnimationThread = nil
       end
   end
   
   if not IsPedInAnyVehicle(playerPed, false) then
       local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
       
       if DoesEntityExist(vehicle) then
           local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
           
           -- Recherche d'un siège libre
           for i=0, maxSeats-1 do
               if IsVehicleSeatFree(vehicle, i) then
                   TaskWarpPedIntoVehicle(playerPed, vehicle, i)
                   break
               end
           end
       end
   end
end)

-- Action Sortir du véhicule
function OutOfVehicleAction()
   local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
   if closestPlayer == -1 or closestDistance > 3.0 then
       SendNotification('error', 'Police', 'Aucun joueur à proximité')
       return
   end

   TriggerServerEvent('police:outOfVehicle', GetPlayerServerId(closestPlayer))
end

-- Event pour sortir du véhicule
RegisterNetEvent('police:outOfVehicle')
AddEventHandler('police:outOfVehicle', function()
   local playerPed = PlayerPedId()
   
   if IsPedSittingInAnyVehicle(playerPed) then
       local vehicle = GetVehiclePedIsIn(playerPed, false)
       TaskLeaveVehicle(playerPed, vehicle, 16)
       
       -- Si le joueur est menotté, réappliquer les menottes après être sorti du véhicule
       if isHandcuffed then
           Wait(1000) -- Attendre que l'animation de sortie du véhicule soit terminée
           RequestAnimDict('mp_arresting')
           while not HasAnimDictLoaded('mp_arresting') do
               Wait(100)
           end
           
           TaskPlayAnim(playerPed, 'mp_arresting', 'idle', 8.0, -8, -1, 49, 0, 0, 0, 0)
           SetEnableHandcuffs(playerPed, true)
       end
   end
end)

-- =============================================
-- Actions d'interaction (Fouille, amendes, etc.)
-- =============================================

-- Action Fouille
function SearchAction()
   local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
   if closestPlayer == -1 or closestDistance > 3.0 then
       SendNotification('error', 'Police', 'Aucun joueur à proximité')
       return
   end

   if lib.progressBar({
       duration = Config.Animations.search,
       label = 'Fouille en cours...',
       useWhileDead = false,
       canCancel = true,
       disable = {
           car = true,
           move = true,
           combat = true
       },
       anim = {
           dict = 'anim@gangops@facility@servers@bodysearch@',
           clip = 'player_search',
           flags = 49
       },
   }) then
       -- Utiliser ox_inventory pour ouvrir l'inventaire
       exports.ox_inventory:openInventory('player', GetPlayerServerId(closestPlayer))
   end
end

-- =============================================
-- Système d'amendes
-- =============================================

-- Vérifier les licences d'un citoyen
function CheckCitizenLicenses()
   local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
   if closestPlayer == -1 or closestDistance > 3.0 then
       SendNotification('error', 'Police', 'Aucun joueur à proximité')
       return
   end

   -- Animation de vérification des documents
   local playerPed = PlayerPedId()
   TaskStartScenarioInPlace(playerPed, "PROP_HUMAN_CLIPBOARD", 0, true)
   
   if lib.progressBar({
       duration = 2000,
       label = 'Vérification des documents...',
       useWhileDead = false,
       canCancel = true,
       disable = {
           car = true,
           move = true,
           combat = true
       },
   }) then
       TriggerServerEvent('police:checkDetailedLicenses', GetPlayerServerId(closestPlayer))
       Wait(500)
       ClearPedTasks(playerPed)
   else
       ClearPedTasks(playerPed)
       SendNotification('error', 'Police', 'Vérification annulée')
   end
end

-- Fonction pour délivrer un permis de port d'arme
function IssueWeaponLicense()
   local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
   if closestPlayer == -1 or closestDistance > 3.0 then
       SendNotification('error', 'Police', 'Aucun joueur à proximité')
       return
   end
   
   -- Envoyer une demande de vérification au serveur
   TriggerServerEvent('police:requestWeaponLicense', GetPlayerServerId(closestPlayer))
end

-- Gestionnaire pour l'événement de confirmation du PPA
RegisterNetEvent('police:confirmWeaponLicense')
AddEventHandler('police:confirmWeaponLicense', function(targetId)
   -- Demander confirmation avec prix hardcodé
   local alert = lib.alertDialog({
       header = 'Permis de port d\'arme',
       content = 'Voulez-vous délivrer un permis de port d\'arme à cette personne? Le coût de 1500€ sera prélevé directement.',
       centered = true,
       cancel = true
   })
   
   if alert == 'confirm' then
       TriggerServerEvent('police:confirmWeaponLicense', targetId)
   end
end)

-- =============================================
-- Événements et fonctions utilitaires
-- =============================================

-- Event pour afficher les licences
RegisterNetEvent('police:showDetailedLicenses')
AddEventHandler('police:showDetailedLicenses', function(documents)
   -- Implémenter l'affichage des licences via NUI
   if #documents == 0 then
       SendNotification('info', 'Police', 'Le citoyen ne possède aucun document')
   else
       SendNUIMessage({
           type = 'showLicenses',
           documents = documents
       })
   end
end)

-- Fonction utilitaire pour obtenir le nom du type de document
function GetDocumentTypeName(type)
   local documentTypes = {
       ID = 'Carte d\'identité',
       Driver = 'Permis de conduire',
       Weapon = 'Permis de port d\'arme'
   }
   
   return documentTypes[type] or type
end

-- Fonction standardisée pour envoyer une notification
function SendNotification(type, title, message)
   exports['jl_notifications']:ShowNotification({
       type = type,
       message = message,
       title = title,
       image = 'img/policenat.png',
       duration = 5000
   })
end