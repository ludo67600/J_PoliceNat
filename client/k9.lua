-- J_PoliceNat client/k9.lua (version avec interface Vue.js)
local ESX = exports["es_extended"]:getSharedObject()

-- =============================================
-- Variables locales
-- =============================================
local policeDog = nil
local followingTarget = nil
local searching = false
local attacking = false

-- Commandes d'animation du chien
local dogAnimations = {
   sit = {
       dict = "creatures@rottweiler@amb@world_dog_sitting@base",
       anim = "base"
   },
   laydown = {
       dict = "creatures@rottweiler@amb@sleep_in_kennel@",
       anim = "sleep_in_kennel"
   },
   bark = {
       dict = "creatures@rottweiler@amb@world_dog_barking@idle_a",
       anim = "idle_a"
   }
}

-- =============================================
-- Fonctions utilitaires
-- =============================================

-- Charger une animation
function LoadAnimDict(dict)
   while not HasAnimDictLoaded(dict) do
       RequestAnimDict(dict)
       Wait(10)
   end
end

-- =============================================
-- Gestion du chien (spawn, despawn)
-- =============================================

-- Spawn du chien
function SpawnPoliceDog()
   if policeDog then
       SendNotification('error', 'K9', 'Vous avez déjà un chien')
       return
   end

   -- Chargement du modèle
   local model = GetHashKey(Config.K9.model)
   RequestModel(model)
   while not HasModelLoaded(model) do
       Wait(50)
   end

   local playerPed = PlayerPedId()
   local coords = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 1.0, -1.0)

   policeDog = CreatePed(28, model, coords.x, coords.y, coords.z, GetEntityHeading(playerPed), true, true)

   -- Configuration du chien
   SetPedComponentVariation(policeDog, 0, 0, 0, 0)
   SetBlockingOfNonTemporaryEvents(policeDog, true)
   SetPedFleeAttributes(policeDog, 0, false)
   SetPedCombatAttributes(policeDog, 3, true)
   SetPedCombatAbility(policeDog, 100)
   SetPedCombatMovement(policeDog, 3)
   SetPedCombatRange(policeDog, 2)
   SetEntityHealth(policeDog, 200)
   
   -- Suivre le joueur par défaut
   TaskFollowToOffsetOfEntity(policeDog, playerPed, 0.5, 0.0, 0.0, 5.0, -1, 0.0, true)

   SendNotification('success', 'K9', 'Chien de police déployé')
   
   -- Informer le serveur et l'UI
   TriggerServerEvent('police:updateK9Status', true)
   
   -- Mettre à jour l'UI si elle est ouverte
   if uiOpen then
       SendNUIMessage({
           type = 'updateK9',
           hasK9 = true
       })
   end
   
   return true
end

-- Despawn du chien
function DespawnPoliceDog()
   if not policeDog then return false end

   DeleteEntity(policeDog)
   policeDog = nil

   SendNotification('success', 'K9', 'Chien de police renvoyé')
   
   -- Informer le serveur et l'UI
   TriggerServerEvent('police:updateK9Status', false)
   
   -- Mettre à jour l'UI si elle est ouverte
   if uiOpen then
       SendNUIMessage({
           type = 'updateK9',
           hasK9 = false
       })
   end
   
   return true
end

-- =============================================
-- Commandes du chien
-- =============================================

-- Commande Assis
function CommandSit()
   if not policeDog then return false end
   
   ClearPedTasks(policeDog)
   LoadAnimDict(dogAnimations.sit.dict)
   TaskPlayAnim(policeDog, dogAnimations.sit.dict, dogAnimations.sit.anim, 8.0, -8.0, -1, 1, 0.0, false, false, false)
   
   return true
end

-- Commande Suis-moi
function CommandFollow()
   if not policeDog then return false end
   
   -- Réinitialiser les états
   ClearPedTasks(policeDog)
   followingTarget = nil
   attacking = false
   searching = false
   
   -- Faire suivre le joueur
   local playerPed = PlayerPedId()
   TaskFollowToOffsetOfEntity(policeDog, playerPed, 0.5, 0.0, 0.0, 5.0, -1, 0.5, true)
   
   -- Notification
   SendNotification('info', 'K9', 'Le chien vous suit maintenant')
   
   return true
end

-- Commande Attaque
function CommandAttack()
   if not policeDog or attacking then return false end

   local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
   if closestPlayer == -1 or closestDistance > 5.0 then
       SendNotification('error', 'K9', 'Aucune cible à proximité')
       return false
   end

   local targetPed = GetPlayerPed(closestPlayer)
   attacking = true

   -- Animation d'aboiement avant l'attaque
   LoadAnimDict(dogAnimations.bark.dict)
   TaskPlayAnim(policeDog, dogAnimations.bark.dict, dogAnimations.bark.anim, 8.0, -8.0, -1, 0, 0.0, false, false, false)
   Wait(1500)

   -- Lancement de l'attaque
   TaskCombatPed(policeDog, targetPed, 0, 16)
   
   -- Envoyer un événement au serveur pour l'autre joueur
   TriggerServerEvent('police:k9Attack', GetPlayerServerId(closestPlayer))

   -- Reset après 10 secondes
   SetTimeout(10000, function()
       attacking = false
       CommandFollow()
   end)
   
   return true
end

-- Commande Cherche
function CommandSearch()
   if not policeDog or searching then return false end
   searching = true
   local startCoords = GetEntityCoords(policeDog)

   -- Animation de recherche
   LoadAnimDict("creatures@rottweiler@amb@world_dog_sitting@idle_a")
   TaskPlayAnim(policeDog, "creatures@rottweiler@amb@world_dog_sitting@idle_a", "idle_b", 8.0, -8.0, -1, 0, 0.0, false, false, false)

   -- Progress bar pour la recherche
   if lib.progressBar({
       duration = 10000,
       label = 'Le chien cherche...',
       useWhileDead = false,
       canCancel = true,
       disable = {
           car = true,
       },
   }) then
       local playerPed = PlayerPedId()
       local playerCoords = GetEntityCoords(playerPed, true)
       local detectionFound = false
       
       -- Vérifier s'il y a un joueur à proximité
       local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
       if closestPlayer ~= -1 and closestDistance <= 3.0 then
           print("Recherche K9: Joueur trouvé, vérification")
           local targetId = GetPlayerServerId(closestPlayer)
           TriggerServerEvent('police:k9CheckInventory', targetId)
           
           -- Animation du chien qui renifle le joueur
           local targetPed = GetPlayerPed(closestPlayer)
           TaskGoToEntity(policeDog, targetPed, -1, 0.5, 2.0, 0, 0)
           Wait(2000)
           detectionFound = true
       end
       
       -- Vérifier s'il y a un véhicule à proximité (indépendamment)
       local closestVehicle = GetClosestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, 5.0, 0, 71)
       if DoesEntityExist(closestVehicle) then
           print("Recherche K9: Véhicule trouvé")
           
           -- Si un véhicule est trouvé, vérifier son coffre
           local plate = GetVehicleNumberPlateText(closestVehicle)
           if plate then
               -- Nettoyons la plaque (supprimez les espaces)
               plate = plate:gsub("%s+", "")
               print("Recherche K9: Vérifie la plaque " .. plate)
               
               -- Important: Utiliser le netID du véhicule pour ox_inventory
               local vehNetId = NetworkGetNetworkIdFromEntity(closestVehicle)
               TriggerServerEvent('police:k9CheckVehicle', plate, vehNetId)
               
               -- Faire le chien renifler autour du véhicule
               TaskGoToEntity(policeDog, closestVehicle, -1, 0.5, 2.0, 0, 0)
               Wait(2000)
               detectionFound = true
           end
       end
       
       -- Si aucune détection n'a été faite
       if not detectionFound then
           SendNotification('error', 'K9', 'Aucune cible à proximité pour la recherche')
       end
   end

   searching = false
   CommandFollow()
   
   return true
end

-- =============================================
-- Events de détection et notifications
-- =============================================

-- Event pour la détection d'items pour les joueurs
RegisterNetEvent('police:k9ItemDetectedPlayer')
AddEventHandler('police:k9ItemDetectedPlayer', function(detected)
   if not policeDog then return end
   if detected then
       -- Animation d'aboiement pour signaler la détection
       LoadAnimDict(dogAnimations.bark.dict)
       TaskPlayAnim(policeDog, dogAnimations.bark.dict, dogAnimations.bark.anim, 8.0, -8.0, -1, 0, 0.0, false, false, false)
       
       SendNotification('warning', 'K9', 'Le chien a détecté quelque chose de suspect sur le citoyen !')
   else
       SendNotification('info', 'K9', 'Le chien n\'a rien trouvé de suspect sur le citoyen')
   end
end)

-- Event pour la détection d'items pour les véhicules
RegisterNetEvent('police:k9ItemDetectedVehicle')
AddEventHandler('police:k9ItemDetectedVehicle', function(detected)
   if not policeDog then return end
   if detected then
       -- Animation d'aboiement pour signaler la détection
       LoadAnimDict(dogAnimations.bark.dict)
       TaskPlayAnim(policeDog, dogAnimations.bark.dict, dogAnimations.bark.anim, 8.0, -8.0, -1, 0, 0.0, false, false, false)
       
       SendNotification('warning', 'K9', 'Le chien a détecté quelque chose de suspect dans le véhicule !')
   else
       SendNotification('info', 'K9', 'Le chien n\'a rien trouvé de suspect dans le véhicule')
   end
end)

-- Event pour l'attaque du chien
RegisterNetEvent('police:k9AttackTarget')
AddEventHandler('police:k9AttackTarget', function()
   local playerPed = PlayerPedId()
   
   -- Joue l'animation de blessure
   ApplyDamageToPed(playerPed, 5, false)
   
   if not IsEntityPlayingAnim(playerPed, "missminuteman_1ig_2", "handsup_base", 3) then
       TaskPlayAnim(playerPed, "missminuteman_1ig_2", "handsup_base", 8.0, -8, -1, 49, 0, 0, 0, 0)
       Wait(5000)
       ClearPedTasks(playerPed)
   end
   
   -- Ajout de sang visuel
   ApplyPedDamagePack(playerPed, "SCR_TrevorTreeBang", 0.0, 1.0)
end)

-- =============================================
-- Utilitaires
-- =============================================

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

-- Nettoyage à l'arrêt de la ressource
AddEventHandler('onResourceStop', function(resourceName)
   if resourceName == GetCurrentResourceName() and policeDog then
       DeleteEntity(policeDog)
   end
end)

-- =============================================
-- Exports
-- =============================================

-- Export pour vérifier si le chien existe
exports('DoesK9Exist', function()
   return policeDog ~= nil and DoesEntityExist(policeDog)
end)

-- Exports pour les commandes du chien
exports('SpawnPoliceDog', SpawnPoliceDog)
exports('DespawnPoliceDog', DespawnPoliceDog)
exports('CommandSit', CommandSit)
exports('CommandFollow', CommandFollow)
exports('CommandAttack', CommandAttack)
exports('CommandSearch', CommandSearch)