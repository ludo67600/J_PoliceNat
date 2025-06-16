-- J_PoliceNat client/props.lua (version avec interface Vue.js)
local ESX = exports["es_extended"]:getSharedObject()

-- Variables locales
local placedProps = {}
local previewProp = nil
local isPlacingProp = false
local previewModel = nil
local previewRotation = 0.0

-- Charger un modèle
function LoadModel(model)
  local hash = GetHashKey(model)
  RequestModel(hash)
  local timeout = 0
  while not HasModelLoaded(hash) do
      timeout = timeout + 1
      if timeout > 100 then
          SendNotification('error', 'Props', 'Impossible de charger le modèle')
          return false
      end
      Wait(10)
  end
  return true
end

-- Démarrer le placement d'un prop avec prévisualisation
function StartPlacingProp(model)
  -- S'assurer qu'on ne place pas déjà un prop
  if isPlacingProp then return end
  
  -- Charge le modèle
  if not LoadModel(model) then return end
  
  -- Initialisation
  isPlacingProp = true
  previewModel = model
  previewRotation = 0.0
  
  -- Fermer l'interface NUI si elle est ouverte
  if uiOpen then
      ClosePoliceUI()
  end
  
  -- Créer l'objet de prévisualisation
  local playerPed = PlayerPedId()
  local coords = GetEntityCoords(playerPed)
  previewProp = CreateObject(GetHashKey(model), coords.x, coords.y, coords.z, false, false, false)
  
  -- Rendre l'objet semi-transparent
  SetEntityAlpha(previewProp, 150, false)
  SetEntityCollision(previewProp, false, false)
  
  -- Afficher les instructions
  lib.showTextUI('[E] Placer    [←/→] Rotation    [BACKSPACE] Annuler')
  
  -- Boucle de prévisualisation
  CreateThread(function()
      while isPlacingProp and DoesEntityExist(previewProp) do
          local playerPed = PlayerPedId()
          local coords = GetEntityCoords(playerPed)
          local forward = GetEntityForwardVector(playerPed)
          local x, y, z = table.unpack(coords + forward * 2.0)
          
          -- Mettre à jour la position de l'objet de prévisualisation
          SetEntityCoords(previewProp, x, y, z, false, false, false, false)
          SetEntityHeading(previewProp, previewRotation)
          PlaceObjectOnGroundProperly(previewProp)
          
          -- Contrôles de rotation
          if IsControlPressed(0, 174) then -- Flèche gauche
              previewRotation = previewRotation - 2.0
          elseif IsControlPressed(0, 175) then -- Flèche droite
              previewRotation = previewRotation + 2.0
          end
          
          -- Validation ou annulation
          if IsControlJustPressed(0, 38) then -- E pour valider
              -- Récupérer les coordonnées finales
              local finalCoords = GetEntityCoords(previewProp)
              local finalHeading = GetEntityHeading(previewProp)
              
              -- Supprimer l'objet de prévisualisation
              DeleteObject(previewProp)
              previewProp = nil
              
              -- Créer l'objet réel
              local object = CreateObject(GetHashKey(model), finalCoords.x, finalCoords.y, finalCoords.z, true, false, true)
              SetEntityHeading(object, finalHeading)
              PlaceObjectOnGroundProperly(object)
              FreezeEntityPosition(object, true)
              
              -- Ajouter aux objets placés
              table.insert(placedProps, object)
              
              -- Envoyer les informations au serveur
              local propInfo = {
                  model = model,
                  coords = GetEntityCoords(object),
                  heading = GetEntityHeading(object)
              }
              TriggerServerEvent('police:saveProp', propInfo)
              
              SendNotification('success', 'Props', 'Objet placé avec succès')
              
              -- Terminer le placement
              isPlacingProp = false
              lib.hideTextUI()
              break
              
          elseif IsControlJustPressed(0, 194) then -- BACKSPACE pour annuler
              -- Supprimer l'objet de prévisualisation
              DeleteObject(previewProp)
              previewProp = nil
              
              -- Terminer le placement
              isPlacingProp = false
              lib.hideTextUI()
              
              SendNotification('error', 'Props', 'Placement annulé')
              break
          end
          
          Wait(0)
      end
  end)
end

-- Supprimer un prop proche
function RemoveClosestProp()
  local playerPed = PlayerPedId()
  local coords = GetEntityCoords(playerPed)
  local closestObject = nil
  local closestDistance = 5.0
  
  -- Trouver l'objet le plus proche parmi ceux qu'on a placés
  for i, object in ipairs(placedProps) do
      if DoesEntityExist(object) then
          local objCoords = GetEntityCoords(object)
          local distance = #(coords - objCoords)
          if distance < closestDistance then
              closestObject = object
              closestDistance = distance
          end
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
          
          -- Retirer de notre liste
          for i, obj in ipairs(placedProps) do
              if obj == closestObject then
                  table.remove(placedProps, i)
                  break
              end
          end
          
          SendNotification('success', 'Props', 'Objet supprimé avec succès')
          return true
      end
  else
      SendNotification('error', 'Props', 'Aucun objet à proximité')
      return false
  end
  
  return false
end

-- Synchroniser les props quand un joueur rejoint
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(playerData)
  Wait(1000) -- Attendre que tout soit chargé
  if playerData.job.name == 'police' then
      TriggerServerEvent('police:requestProps')
  end
end)

-- Chargement des props depuis le serveur
RegisterNetEvent('police:loadProps')
AddEventHandler('police:loadProps', function(props)
  -- Nettoyer les props existants
  for _, obj in ipairs(placedProps) do
      if DoesEntityExist(obj) then
          DeleteObject(obj)
      end
  end
  placedProps = {}
  
  -- Recréer les props
  for propId, propInfo in pairs(props) do
      local model = GetHashKey(propInfo.model)
      RequestModel(model)
      while not HasModelLoaded(model) do
          Wait(50)
      end
      
      local obj = CreateObject(model, propInfo.coords.x, propInfo.coords.y, propInfo.coords.z, false, false, true)
      SetEntityHeading(obj, propInfo.heading)
      PlaceObjectOnGroundProperly(obj)
      FreezeEntityPosition(obj, true)
      
      table.insert(placedProps, obj)
  end
end)

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
  if resourceName == GetCurrentResourceName() then
      -- Nettoyer l'objet de prévisualisation
      if DoesEntityExist(previewProp) then
          DeleteObject(previewProp)
      end
      
      -- Nettoyer les props placés
      for _, obj in ipairs(placedProps) do
          if DoesEntityExist(obj) then
              DeleteObject(obj)
          end
      end
  end
end)