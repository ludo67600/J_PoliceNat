-- J_PoliceNat client/vehicles.lua (version avec interface Vue.js)
local ESX = exports["es_extended"]:getSharedObject()

-- Variables locales
local currentTask = false

-- =============================================
-- Actions pour les véhicules
-- =============================================

-- Récupérer un véhicule volé
function RecoverVehicleAction()
   local vehicle = GetVehicleInDirection()
   if not vehicle then
       SendNotification('error', 'Police', 'Aucun véhicule à proximité')
       return
   end

   local plate = GetVehicleNumberPlateText(vehicle)
   
   -- Vérifier si le véhicule est signalé comme volé
   ESX.TriggerServerCallback('police:checkVehicleStatus', function(isStolen)
       if not isStolen then
           SendNotification('error', 'Police', 'Ce véhicule n\'est pas signalé comme volé')
           return
       end
       
       local alert = lib.alertDialog({
           header = 'Véhicule retrouvé',
           content = 'Voulez-vous marquer le véhicule ' .. plate .. ' comme retrouvé?',
           centered = true,
           cancel = true
       })

       if alert == 'confirm' then
           TriggerServerEvent('police:recoverStolenVehicle', plate, true)
       end
   end, plate)
end

-- Action Vérifier le véhicule
function CheckVehicleAction()
   local vehicle = GetVehicleInDirection()
   if not vehicle then
       SendNotification('error', 'Police', 'Aucun véhicule à proximité')
       return
   end

   local plate = GetVehicleNumberPlateText(vehicle)
   currentTask = true

   if lib.progressBar({
       duration = 2000,
       label = 'Vérification du véhicule...',
       useWhileDead = false,
       canCancel = true,
       disable = {
           car = true,
           move = true,
           combat = true
       },
       anim = {
           dict = 'amb@code_human_police_investigate@idle_b',
           clip = 'idle_f',
           flags = 51
       },
   }) then
       if uiOpen then
           -- Récupérer les informations du véhicule pour l'interface
           ESX.TriggerServerCallback('police:checkVehicleStatus', function(isStolen)
               -- Envoyer les données à l'interface Vue.js
               local statusValue = isStolen and "SIGNALÉ VOLÉ" or "En règle"
               
               SendNUIMessage({
                   type = 'setVehicleInfo',
                   vehicleInfo = {
                       plate = plate,
                       owner = "Récupération...",
                       model = "Récupération...",
                       status = statusValue,
                       isStolen = isStolen
                   }
               })
               
               -- Puis compléter avec les autres infos
               TriggerServerEvent('police:checkVehicle', plate)
           end, plate)
       else
           -- Si l'interface n'est pas ouverte, utiliser la méthode standard
           TriggerServerEvent('police:checkVehicle', plate)
       end
   end

   currentTask = false
end

-- Action Mise en fourrière
function ImpoundAction() 
   local vehicle = GetVehicleInDirection()
   if not vehicle then
       SendNotification('error', 'Police', 'Aucun véhicule à proximité')
       return
   end

   -- Si l'interface tablette est ouverte, utiliser le système de confirmation de l'interface
   if uiOpen then
       SendNUIMessage({
           type = 'showImpoundConfirm',
           vehicle = {
               plate = GetVehicleNumberPlateText(vehicle)
           }
       })
   else
       -- Sinon, utiliser le menu ox_lib comme avant
       local alert = lib.alertDialog({
           header = 'Confirmation fourrière',
           content = 'Voulez-vous mettre ce véhicule en fourrière ?',
           centered = true,
           cancel = true
       })

       if alert == 'confirm' then
           local plate = GetVehicleNumberPlateText(vehicle)
           local networkId = NetworkGetNetworkIdFromEntity(vehicle) -- Récupérer l'ID réseau
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
               SendNotification('success', 'Police', 'Véhicule mis en fourrière')
           end

           currentTask = false
       end
   end
end

-- Action Déverrouillage
function UnlockAction()
   local vehicle = GetVehicleInDirection()
   if not vehicle then
       SendNotification('error', 'Police', 'Aucun véhicule à proximité')
       return
   end

   currentTask = true

   if lib.progressBar({
       duration = Config.Animations.unlock,
       label = 'Déverrouillage du véhicule...',
       useWhileDead = false,
       canCancel = true,
       disable = {
           car = true,
           move = true,
           combat = true
       },
       anim = {
           dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
           clip = 'machinic_loop_mechandplayer',
           flags = 49
       },
   }) then
       SetVehicleDoorsLocked(vehicle, 1)
       SetVehicleDoorsLockedForAllPlayers(vehicle, false)
       SendNotification('success', 'Police', 'Véhicule déverrouillé')

       -- Effet visuel
       local coords = GetEntityCoords(vehicle)
       local hash = GetHashKey('prop_cs_cardigan')
       
       RequestModel(hash)
       while not HasModelLoaded(hash) do
           Wait(0)
       end
       
       local prop = CreateObject(hash, coords.x, coords.y, coords.z + 2.0, true, true, true)
       PlaceObjectOnGroundProperly(prop)
       SetModelAsNoLongerNeeded(hash)
       Wait(2000)
       DeleteEntity(prop)
   end

   currentTask = false
end

-- =============================================
-- Garage véhicules de service
-- =============================================

-- Garage véhicules de service
function OpenGarageMenu()
   ESX.TriggerServerCallback('police:getAuthorizedVehicles', function(vehicles)
       local elements = {}
       
       for _, vehicle in ipairs(vehicles) do
           table.insert(elements, {
               title = vehicle.label,
               description = 'Sortir ce véhicule',
               onSelect = function()
                   SpawnPoliceVehicle(vehicle.model)
               end
           })
       end
       
       table.insert(elements, {
           title = 'Ranger le véhicule',
           description = 'Ranger le véhicule de service',
           onSelect = function()
               local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
               if vehicle ~= 0 then
                   ESX.Game.DeleteVehicle(vehicle)
                   SendNotification('success', 'Garage Police', 'Véhicule rangé')
               end
           end
       })
       
       lib.registerContext({
           id = 'police_garage',
           title = 'Garage Police',
           options = elements
       })
       
       lib.showContext('police_garage')
   end)
end

-- Spawn d'un véhicule de police
function SpawnPoliceVehicle(model)
   local playerPed = PlayerPedId()
   
   -- Vérifier si nous avons des points de spawn configurés
   if Config.Locations.garage and Config.Locations.garage.vehicleSpawnPoints and #Config.Locations.garage.vehicleSpawnPoints > 0 then
       -- Vérifier si le point de spawn est libre
       local spawnPoint = Config.Locations.garage.vehicleSpawnPoints[1]
       local isOccupied = IsPositionOccupied(spawnPoint.coords.x, spawnPoint.coords.y, spawnPoint.coords.z, 2.0, false, true, true, false, false, 0, false)
       
       if isOccupied then
           -- Si la place est occupée, afficher un message d'erreur avec une image
           SendNotification('error', 'Garage Police Nationale', 'La zone de stationnement est occupée. Dégagez la zone pour sortir un véhicule.')
           return
       end
       
       -- Si la place est libre, on sort le véhicule
       ESX.Game.SpawnVehicle(model, vector3(spawnPoint.coords.x, spawnPoint.coords.y, spawnPoint.coords.z), spawnPoint.heading, function(vehicle)
           TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
           SetVehicleExtra(vehicle, 1, false)
           SetVehicleExtra(vehicle, 2, false)
           SetVehicleExtra(vehicle, 3, false)
           SetVehicleExtra(vehicle, 4, false)
           SetVehicleExtra(vehicle, 5, false)
           SetVehicleExtra(vehicle, 6, false)
           SetVehicleExtra(vehicle, 7, false)
           SetVehicleExtra(vehicle, 8, false)
           SetVehicleExtra(vehicle, 9, false)
           SetVehicleExtra(vehicle, 10, false)
           SetVehicleExtra(vehicle, 11, false)
           SetVehicleExtra(vehicle, 12, false)
           SetVehicleLivery(vehicle, 0)
           SetVehicleMod(vehicle, 48, 0, false)
           
           SendNotification('success', 'Garage Police Nationale', 'Véhicule de service sorti')
       end)
   else
       -- Si aucun point de spawn n'est configuré
       SendNotification('error', 'Garage Police Nationale', 'Aucun point de stationnement n\'est configuré')
   end
end

-- =============================================
-- Liste des véhicules volés
-- =============================================

function OpenStolenVehiclesListMenu()
   
   ESX.TriggerServerCallback('police:getStolenVehicles', function(vehicles)
       local elements = {}
       
       if #vehicles == 0 then
           SendNotification('info', 'Police', 'Aucun véhicule n\'est actuellement signalé comme volé')
           
           -- Envoyer également à l'UI Vue.js si elle est ouverte
           if uiOpen then
               SendNUIMessage({
                   type = 'setStolenVehicles',
                   vehicles = {}
               })
           end
           
           return
       end
       
       local vehiclesList = {}
       
       for _, vehicle in ipairs(vehicles) do
           local vehicleName = GetLabelText(GetDisplayNameFromVehicleModel(GetHashKey(vehicle.vehicle.model)))
           if vehicleName == 'NULL' then
               vehicleName = vehicle.vehicle.model
           end
           
           table.insert(vehiclesList, {
               id = _,
               plate = vehicle.plate,
               model = vehicleName,
               owner = vehicle.owner_name or 'Inconnu'
           })
       end
       
       -- Envoyer la liste à l'UI Vue.js si elle est ouverte
       if uiOpen then
           SendNUIMessage({
               type = 'setStolenVehicles',
               vehicles = vehiclesList
           })
       else

           -- Sinon, utiliser le menu ox_lib (code existant)
           for _, vehicle in ipairs(vehiclesList) do
               table.insert(elements, {
                   title = vehicle.model .. ' [' .. vehicle.plate .. ']',
                   description = 'Propriétaire: ' .. vehicle.owner,
                   icon = 'car-burst',
                   onSelect = function()
                       local options = {
                           {
                               title = 'Marquer comme retrouvé',
                               description = 'Signaler que ce véhicule a été retrouvé',
                               icon = 'car-on',
                               onSelect = function()
                                   TriggerServerEvent('police:recoverStolenVehicle', vehicle.plate, true)
                                   Wait(500)
                                   OpenStolenVehiclesListMenu()
                               end
                           }
                       }
                       
                       lib.registerContext({
                           id = 'stolen_vehicle_options',
                           title = 'Options pour ' .. vehicle.plate,
                           menu = 'stolen_vehicles_list',
                           options = options
                       })
                       
                       lib.showContext('stolen_vehicle_options')
                   end
               })
           end
           
           lib.registerContext({
               id = 'stolen_vehicles_list',
               title = 'Véhicules signalés volés',
               options = elements
           })
           
           lib.showContext('stolen_vehicles_list')
       end
   end)
end

-- =============================================
-- Fonctions utilitaires
-- =============================================

-- Obtenir le véhicule ciblé
function GetVehicleInDirection()
   local playerPed = PlayerPedId()
   local playerCoords = GetEntityCoords(playerPed)
   local forward = GetEntityForwardVector(playerPed)
   local endCoords = playerCoords + (forward * 5.0)

   local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(
       playerCoords.x, playerCoords.y, playerCoords.z,
       endCoords.x, endCoords.y, endCoords.z,
       10, playerPed, 0
   )

   local _, hit, _, _, vehicle = GetShapeTestResult(rayHandle)

   if hit and DoesEntityExist(vehicle) then
       return vehicle
   end

   return nil
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

-- =============================================
-- Events
-- =============================================

-- Event pour recevoir les infos du véhicule
RegisterNetEvent('police:receiveVehicleInfo')
AddEventHandler('police:receiveVehicleInfo', function(data) 
   if not data then
       SendNotification('error', 'Police', 'Aucune information trouvée')
       return
   end

   -- Debug
   print("Données reçues du véhicule:")
   print("Plaque: " .. data.plate)
   print("Statut volé (type): " .. type(data.stolen))
   print("Statut volé (valeur): " .. tostring(data.stolen))

   -- Correction du formatage du statut
   local statusValue = ""
   if data.stolen == true then
       statusValue = "SIGNALÉ VOLÉ"
   else
       statusValue = "En règle"
   end

   -- Si l'interface NUI est ouverte, utiliser le système de notification NUI
   if uiOpen then
       SendNUIMessage({
           type = 'setVehicleInfo',
           vehicleInfo = {
               plate = data.plate,
               owner = data.owner or 'Inconnu',
               model = data.model or 'Inconnu',
               status = statusValue,
               isStolen = data.stolen
           }
       })
   else
       -- Sinon utiliser le menu ox_lib
       local elements = {
           {
               title = 'Informations du véhicule',
               description = ('Plaque: %s'):format(data.plate),
               metadata = {
                   {label = 'Propriétaire', value = data.owner or 'Inconnu'},
                   {label = 'Modèle', value = data.model or 'Inconnu'},
                   {label = 'Statut', value = statusValue}
               }
           }
       }
       
       -- Ajouter une option pour marquer comme retrouvé si le véhicule est volé
       if data.stolen then
           table.insert(elements, {
               title = 'Marquer comme retrouvé',
               description = 'Signaler que ce véhicule a été retrouvé',
               icon = 'car-on',
               onSelect = function()
                   TriggerServerEvent('police:recoverStolenVehicle', data.plate, true)
               end
           })
       end

       lib.registerContext({
           id = 'police_vehicle_info',
           title = 'Informations Véhicule',
           options = elements
       })

       lib.showContext('police_vehicle_info')
   end
end)

-- Événement pour supprimer un véhicule pour tous les joueurs
RegisterNetEvent('police:deleteVehicleForAll')
AddEventHandler('police:deleteVehicleForAll', function(networkId)
   local vehicle = NetworkGetEntityFromNetworkId(networkId)
   
   if DoesEntityExist(vehicle) then
       -- Ne supprime que si le véhicule existe réellement pour ce client
       DeleteEntity(vehicle)
   end
end)

-- Fonction pour scanner les véhicules à proximité
RegisterNetEvent('police:startVehicleCheck')
AddEventHandler('police:startVehicleCheck', function()
   -- Ne vérifier que si le joueur est policier et en service
   if not IsOnDuty() then return end
   
   CreateThread(function()
       local playerPed = PlayerPedId()
       local playerCoords = GetEntityCoords(playerPed)
       local vehicles = GetGamePool('CVehicle') -- Récupère tous les véhicules dans le monde
       local nearbyPlates = {}
       
       for _, vehicle in ipairs(vehicles) do
           local distance = #(playerCoords - GetEntityCoords(vehicle))
           -- Vérifier uniquement les véhicules dans un rayon de 30m
           if distance <= 30.0 then
               local plate = GetVehicleNumberPlateText(vehicle)
               if plate and plate ~= "" then
                   -- Stocker la plaque et les coordonnées du véhicule
                   nearbyPlates[plate] = GetEntityCoords(vehicle)
               end
           end
       end
       
       -- Envoyer les plaques au serveur pour vérification
       if next(nearbyPlates) then -- Si la table n'est pas vide
           TriggerServerEvent('police:checkNearbyVehicles', nearbyPlates)
       end
   end)
end)

-- Gestion des notifications de véhicule volé
RegisterNetEvent('police:vehicleStolenNotify')
AddEventHandler('police:vehicleStolenNotify', function(coords)
   if not coords then return end
   
   -- Notification
   SendNotification('warning', 'Véhicule volé', 'Un véhicule volé a été détecté à proximité')
   
   -- Créer un blip sur la carte
   local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
   SetBlipSprite(blip, 225) -- Sprite de voiture
   SetBlipColour(blip, 1) -- Rouge
   SetBlipScale(blip, 1.0)
   SetBlipAsShortRange(blip, false)
   
   BeginTextCommandSetBlipName("STRING")
   AddTextComponentString('Véhicule volé')
   EndTextCommandSetBlipName(blip)
   
   -- Supprimer le blip après 60 secondes
   SetTimeout(60000, function()
       RemoveBlip(blip)
   end)
end)