-- J_PoliceNat client/appointments.lua (version avec interface Vue.js)
local ESX = exports["es_extended"]:getSharedObject()

-- =============================================
-- Menu d'accueil / réception
-- =============================================
function OpenReceptionMenu()
   local elements = {
       {
           title = 'Prendre un rendez-vous',
           description = 'Demander un rendez-vous avec un agent',
           icon = 'calendar-plus',
           onSelect = function()
               OpenNewAppointmentMenu()
           end
       },
       {
           title = 'Mes rendez-vous',
           description = 'Consulter mes rendez-vous',
           icon = 'list-check',
           onSelect = function()
               TriggerServerEvent('police:getMyAppointments')
           end
       },
       {
           title = 'Signaler un véhicule volé',
           description = 'Déclarer le vol de votre véhicule',
           icon = 'car-burst',
           onSelect = function()
               OpenReportStolenVehicleMenu()
           end
       },
       {
           title = 'Marquer un véhicule comme retrouvé',
           description = 'Signaler que vous avez retrouvé votre véhicule',
           icon = 'car-on',
           onSelect = function()
               OpenRecoverOwnVehicleMenu()
           end
       }
   }

   lib.registerContext({
       id = 'police_reception',
       title = 'Accueil Police Nationale',
       options = elements
   })

   lib.showContext('police_reception')
end

-- =============================================
-- Gestion des rendez-vous pour les citoyens
-- =============================================

-- Prendre un nouveau rendez-vous
function OpenNewAppointmentMenu()
  -- Version simplifiée mais fonctionnelle
  local input = lib.inputDialog('Demande de rendez-vous', {
      { type = 'input', label = 'Sujet', required = true },
      { type = 'input', label = 'Description', required = true },
      { type = 'input', label = 'Date (JJ/MM/AAAA)', required = true, placeholder = '01/01/2025' },
      { type = 'input', label = 'Heure', required = true, placeholder = '14:00' }
  })
  
  if input then
      -- Vérification du format de date
      if not input[3]:match("^%d%d/%d%d/%d%d%d%d$") then
          SendNotification('error', 'Erreur', 'Format de date invalide. Utilisez JJ/MM/AAAA')
          return
      end
      
      TriggerServerEvent('police:requestAppointment', {
          subject = input[1],
          description = input[2],
          date = input[3],
          time = input[4]
      })
  end
end

-- Afficher les rendez-vous du citoyen
RegisterNetEvent('police:showMyAppointments')
AddEventHandler('police:showMyAppointments', function(appointments)
  -- Si l'interface Vue.js est ouverte, lui envoyer les données
  if uiOpen then
      SendNUIMessage({
          type = 'updateAppointments',
          appointments = appointments
      })
      return
  end
  
  -- Sinon utiliser le menu ox_lib
  local elements = {}
  
  for _, appointment in ipairs(appointments) do
      table.insert(elements, {
          title = appointment.subject,
          description = ('Date: %s à %s - Statut: %s'):format(appointment.date, appointment.time, appointment.status),
          metadata = {
              {label = 'Description', value = appointment.description},
              {label = 'Agent assigné', value = appointment.officer_name or 'Non assigné'}
          },
          onSelect = function()
              if appointment.status == 'En attente' then
                  local alert = lib.alertDialog({
                      header = 'Annuler le rendez-vous',
                      content = 'Voulez-vous annuler ce rendez-vous ?',
                      centered = true,
                      cancel = true
                  })
                  
                  if alert == 'confirm' then
                      TriggerServerEvent('police:cancelAppointment', appointment.id)
                      SendNotification('success', 'Rendez-vous', 'Rendez-vous annulé')
                      Wait(500)
                      TriggerServerEvent('police:getMyAppointments')
                  end
              end
          end
      })
  end
  
  if #elements == 0 then
      table.insert(elements, {
          title = 'Aucun rendez-vous',
          description = 'Vous n\'avez pas de rendez-vous programmé',
          disabled = true
      })
  end

  lib.registerContext({
      id = 'my_appointments',
      title = 'Mes rendez-vous',
      options = elements
  })

  lib.showContext('my_appointments')
end)

-- =============================================
-- Gestion des véhicules signalés volés
-- =============================================

-- Menu pour signaler un véhicule volé
function OpenReportStolenVehicleMenu()
  ESX.TriggerServerCallback('police:getOwnedVehicles', function(vehicles)
      local elements = {}
      local hasNonStolenVehicles = false
      
      for _, vehicle in ipairs(vehicles) do
          -- Ne montrer que les véhicules qui ne sont pas déjà marqués comme volés
          if not vehicle.stolen then
              hasNonStolenVehicles = true
              local vehicleName = GetLabelText(GetDisplayNameFromVehicleModel(GetHashKey(vehicle.model)))
              -- Si le nom n'est pas trouvé, utiliser le nom du modèle
              if vehicleName == 'NULL' then
                  vehicleName = vehicle.model
              end
              
              table.insert(elements, {
                  title = vehicleName .. ' [' .. vehicle.plate .. ']',
                  description = 'Signaler ce véhicule comme volé',
                  icon = 'car',
                  onSelect = function()
                      local input = lib.inputDialog('Signalement de vol', {
                          {
                              type = 'textarea',
                              label = 'Description',
                              description = 'Décrivez les circonstances du vol',
                              required = true
                          }
                      })
                      
                      if input then
                          TriggerServerEvent('police:reportStolenVehicle', vehicle.plate, input[1])
                          
                          -- Revenir au menu principal après quelques secondes
                          Wait(1000)
                          OpenReceptionMenu()
                      end
                  end
              })
          end
      end
      
      if not hasNonStolenVehicles then
          table.insert(elements, {
              title = 'Aucun véhicule à signaler',
              description = 'Vous n\'avez aucun véhicule pouvant être signalé comme volé',
              disabled = true
          })
      end

      lib.registerContext({
          id = 'citizen_report_stolen',
          title = 'Signaler un véhicule volé',
          menu = 'police_reception', -- Permet de revenir au menu précédent
          options = elements
      })

      lib.showContext('citizen_report_stolen')
  end)
end

-- Menu pour marquer un véhicule comme retrouvé
function OpenRecoverOwnVehicleMenu()
  ESX.TriggerServerCallback('police:getStolenVehicles', function(vehicles)
      local elements = {}
      
      if #vehicles == 0 then
          table.insert(elements, {
              title = 'Aucun véhicule volé',
              description = 'Vous n\'avez aucun véhicule signalé comme volé',
              disabled = true
          })
      else
          for _, vehicle in ipairs(vehicles) do
              local vehicleName = GetLabelText(GetDisplayNameFromVehicleModel(GetHashKey(vehicle.vehicle.model)))
              if vehicleName == 'NULL' then
                  vehicleName = vehicle.vehicle.model
              end
              
              table.insert(elements, {
                  title = vehicleName .. ' [' .. vehicle.plate .. ']',
                  description = 'Marquer ce véhicule comme retrouvé',
                  icon = 'car-on',
                  onSelect = function()
                      local alert = lib.alertDialog({
                          header = 'Véhicule retrouvé',
                          content = 'Confirmez-vous avoir retrouvé ce véhicule?',
                          centered = true,
                          cancel = true
                      })
                      
                      if alert == 'confirm' then
                          TriggerServerEvent('police:recoverStolenVehicle', vehicle.plate, false)
                          
                          -- Revenir au menu principal après quelques secondes
                          Wait(1000)
                          OpenReceptionMenu()
                      end
                  end
              })
          end
      end

      lib.registerContext({
          id = 'citizen_recover_vehicle',
          title = 'Marquer un véhicule comme retrouvé',
          menu = 'police_reception',
          options = elements
      })

      lib.showContext('citizen_recover_vehicle')
  end)
end

-- =============================================
-- Gestion des rendez-vous pour les agents via Interface Vue.js
-- =============================================

-- Fonction qui remplace OpenAppointmentsManagementMenu, mais qui ne fait que déclencher l'événement
function OpenAppointmentsManagementMenu()
   -- Ne pas exécuter RefreshAppointments si interface NUI est ouverte
   -- au lieu de cela, envoyer directement un message à l'interface NUI pour changer de section
   if uiOpen then
       -- Simplement mettre à jour l'interface Vue.js en changeant la section active
       SendNUIMessage({
           type = 'setActiveSection',
           section = 'appointments'
       })
   else
       -- Si l'interface Vue.js n'est pas ouverte, déclencher l'événement serveur
       TriggerServerEvent('police:getOfficerAppointments')
   end
end

-- Rafraîchir les rendez-vous (utilisé depuis l'interface Vue.js)
function RefreshAppointments()
   TriggerServerEvent('police:getOfficerAppointments')
end

-- Menu détails d'un rendez-vous (pour les agents)
function OpenAppointmentDetailsMenu(appointment)
  local elements = {
      {
          title = 'Détails du rendez-vous',
          description = appointment.description,
          metadata = {
              {label = 'Citoyen', value = appointment.citizen_name or 'Inconnu'},
              {label = 'Date', value = appointment.date .. ' à ' .. appointment.time},
              {label = 'Statut', value = appointment.status}
          }
      }
  }
  
  -- Options selon le statut
  if appointment.status == 'En attente' then
      table.insert(elements, {
          title = 'Accepter le rendez-vous',
          description = 'Prendre en charge ce rendez-vous',
          icon = 'check',
          onSelect = function()
              TriggerServerEvent('police:acceptAppointment', appointment.id)
              SendNotification('success', 'Rendez-vous', 'Rendez-vous accepté')
              Wait(500)
              RefreshAppointments()
          end
      })
  end
  
  if appointment.status == 'En attente' or appointment.status == 'Accepté' then
      table.insert(elements, {
          title = 'Annuler le rendez-vous',
          description = 'Annuler ce rendez-vous',
          icon = 'xmark',
          onSelect = function()
              TriggerServerEvent('police:cancelAppointment', appointment.id)
              SendNotification('error', 'Rendez-vous', 'Rendez-vous annulé')
              Wait(500)
              RefreshAppointments()
          end
      })
  end
  
  if appointment.status == 'Accepté' then
      table.insert(elements, {
          title = 'Marquer comme terminé',
          description = 'Clôturer ce rendez-vous',
          icon = 'check-double',
          onSelect = function()
              TriggerServerEvent('police:finishAppointment', appointment.id)
              SendNotification('success', 'Rendez-vous', 'Rendez-vous terminé')
              Wait(500)
              RefreshAppointments()
          end
      })
  end

  lib.registerContext({
      id = 'appointment_details',
      title = 'Rendez-vous #' .. appointment.id,
      menu = 'officer_appointments',
      options = elements
  })

  lib.showContext('appointment_details')
end

-- =============================================
-- Fonctions d'intégration avec l'interface Vue.js
-- =============================================

-- Accepter un rendez-vous (via l'interface Vue.js)
RegisterNUICallback('acceptAppointment', function(data, cb)
  TriggerServerEvent('police:acceptAppointment', data.id)
  cb({success = true})
end)

-- Terminer un rendez-vous (via l'interface Vue.js)
RegisterNUICallback('finishAppointment', function(data, cb)
  TriggerServerEvent('police:finishAppointment', data.id)
  cb({success = true})
end)

-- Annuler un rendez-vous (via l'interface Vue.js)
RegisterNUICallback('cancelAppointment', function(data, cb)
  TriggerServerEvent('police:cancelAppointment', data.id)
  cb({success = true})
end)

-- Rafraîchir les rendez-vous (via l'interface Vue.js)
RegisterNUICallback('refreshAppointments', function(data, cb)
  RefreshAppointments()
  cb({success = true})
end)

-- Callback pour changer de section (ajouté pour contrôler les sections depuis l'UI)
RegisterNUICallback('setActiveSection', function(data, cb)
   -- Ici on peut ajouter un comportement spécifique par section
   cb({success = true})
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