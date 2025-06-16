// Déclaration de l'application Vue
const PoliceApp = {
    data() {
        return {
            // États de l'application
            showApp: false,
            isOnDuty: false,
            activeSection: 'service',
            
            // Informations du joueur
            playerData: {
                id: 0,
                name: '',
                job: 'police', 
                grade: 0,
                gradeName: 'Gardien de la Paix',
            },
            
            // Agents en service
            onDutyOfficers: [],
            
            // Sections disponibles
            sections: [
                { id: 'service', name: 'Service', icon: 'fas fa-user-clock', alwaysVisible: true },
                { id: 'citizens', name: 'Citoyens', icon: 'fas fa-users', onDutyOnly: true },
                { id: 'vehicles', name: 'Véhicules', icon: 'fas fa-car', onDutyOnly: true },
                { id: 'props', name: 'Objets', icon: 'fas fa-box', onDutyOnly: true },
                { id: 'k9', name: 'K9', icon: 'fas fa-dog', onDutyOnly: true, minGrade: 2 },
                { id: 'clothing', name: 'Tenues', icon: 'fas fa-shirt', onDutyOnly: true },
                { id: 'appointments', name: 'Rendez-vous', icon: 'fas fa-calendar', onDutyOnly: true },
                { id: 'records', name: 'Casier', icon: 'fas fa-file-alt', onDutyOnly: true },
                { id: 'complaints', name: 'Plaintes', icon: 'fas fa-file-pen', onDutyOnly: true },
                { id: 'alerts', name: 'Alertes', icon: 'fas fa-bell', onDutyOnly: true },
                { id: 'boss', name: 'Admin', icon: 'fas fa-building', onDutyOnly: true, minGrade: 10 }
            ],
            
            // Gestion des notifications
            notifications: [],
            
            // Gestion des modals
            showModal: false,
            modalType: '',
            modalTitle: '',
            
            // Props disponibles
            availableProps: [],
            hasK9: false,
            
            // Tenues et accessoires
            availableUniforms: [],
            availableAccessories: [],
            currentAccessoryType: null,
            
            // Amendes
            fineCategories: [],
            selectedFineCategory: null,
            newFine: {
                amount: 0,
                reason: ''
            },
            
            // Gestion des rendez-vous
            appointments: [],
            appointmentFilter: 'all',
            selectedAppointment: null,
            
            // Gestion des plaintes
            complaints: [],
            complaintFilter: 'all',
            complaintsTab: 'list',
            selectedComplaint: null,
            complaintCloseReason: '',
            complaintCategories: [
                { label: 'Vol', value: 'theft' },
                { label: 'Agression', value: 'assault' },
                { label: 'Vandalisme', value: 'vandalism' },
                { label: 'Autre', value: 'other' }
            ],
            newComplaint: {
                type: 'theft',
                plaintiff: '',
                description: ''
            },
            
            // Casier judiciaire
            criminalSearch: '',
            selectedCitizen: null,
            criminalRecords: [],
            documents: [],
            criminalTab: 'records',
            newRecord: {
                offense: '',
                fineAmount: 0,
                jailTime: 0,
                notes: ''
            },
            
            // Photos de la galerie et mugshot
            galleryPhotos: [],
            showGalleryModal: false,
            selectedPhoto: null,
            loadingGallery: false,
			
			// Informations véhicule
			impoundData: null,
            vehicleInfo: null,
            stolenVehicles: [],
            vehicleInfoTab: 'basic', 
            
            // Alertes radio
            alertCodes: []
        };
    },
    
    computed: {
        // Filtrer les sections visibles en fonction du statut de service et du grade
        visibleSections() {
            return this.sections.filter(section => {
                // Si la section est toujours visible, la montrer
                if (section.alwaysVisible) return true;
                
                // Sinon, vérifier si le joueur est en service
                if (section.onDutyOnly && !this.isOnDuty) return false;
                
                // Vérifier si le joueur a le grade minimum requis
                if (section.minGrade && this.playerData.grade < section.minGrade) return false;
                
                return true;
            });
        },
        
        // Filtrer les rendez-vous en fonction du filtre sélectionné
        filteredAppointments() {
            if (this.appointmentFilter === 'all') {
                return this.appointments;
            } else if (this.appointmentFilter === 'pending') {
                return this.appointments.filter(app => app.status === 'En attente');
            } else if (this.appointmentFilter === 'accepted') {
                return this.appointments.filter(app => app.status === 'Accepté');
            }
            return this.appointments;
        },
        
        // Filtrer les plaintes en fonction du filtre sélectionné
        filteredComplaints() {
            if (this.complaintFilter === 'all') {
                return this.complaints;
            } else if (this.complaintFilter === 'open') {
                return this.complaints.filter(complaint => complaint.status === 'Ouvert');
            } else if (this.complaintFilter === 'closed') {
                return this.complaints.filter(complaint => complaint.status === 'Fermé');
            }
            return this.complaints;
        },
        
        // Vérifier si le citoyen a déjà une photo
        citizenHasMugshot() {
            return this.selectedCitizen && this.selectedCitizen.mugshot && this.selectedCitizen.mugshot !== '';
        }
    },
    
    methods: {
        // === Méthodes générales de l'application ===
        
        // Initialiser l'application
        initApp(data) {
            // Mise à jour des informations du joueur
            if (data.playerData) {
                this.playerData = data.playerData;
            }
            
            // Mise à jour du statut de service
            if (data.isOnDuty !== undefined) {
                this.isOnDuty = data.isOnDuty;
            }
            
            // Chargement des agents en service
            if (data.onDutyOfficers) {
                this.onDutyOfficers = data.onDutyOfficers;
            }
            
            // Chargement des props disponibles
            if (data.props) {
                this.availableProps = data.props;
            }
            
            // Chargement des tenues disponibles
            if (data.uniforms) {
                this.availableUniforms = data.uniforms;
            }
            
            // Chargement des catégories d'amendes
            if (data.fineCategories) {
                this.fineCategories = data.fineCategories;
            }
            
            // Chargement des codes d'alerte
            if (data.alertCodes) {
                this.alertCodes = data.alertCodes;
            }
            
            // Statut du chien K9
            if (data.hasK9 !== undefined) {
                this.hasK9 = data.hasK9;
            }
            
            this.showApp = true;
        },
        
        // Fermer l'application
        closeApp() {
            this.showApp = false;
            // Envoyer un message à LUA pour fermer l'interface
            fetch(`https://${GetParentResourceName()}/closeUI`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            });
        },
        
        // Changer de section
        setActiveSection(sectionId) {
            this.activeSection = sectionId;
            
            // Si on change vers des sections avec données dynamiques, les charger
            if (sectionId === 'appointments') {
                this.refreshAppointments();
            } else if (sectionId === 'complaints') {
                this.refreshComplaints();
            }
        },
        
        // === Méthodes pour les notifications ===
        
        // Ajouter une notification
        addNotification(title, message, type = 'info') {
            const notification = {
                title,
                message,
                type,
                id: Date.now() // ID unique basé sur le timestamp
            };
            
            this.notifications.push(notification);
            
            // Supprimer automatiquement après 5 secondes
            setTimeout(() => {
                this.removeNotification(this.notifications.findIndex(n => n.id === notification.id));
            }, 5000);
        },
        
        // Supprimer une notification
        removeNotification(index) {
            if (index > -1) {
                this.notifications.splice(index, 1);
            }
        },
        
        // Déterminer l'icône en fonction du type de notification
        notificationIcon(type) {
            switch (type) {
                case 'success': return 'fas fa-check-circle';
                case 'error': return 'fas fa-times-circle';
                case 'warning': return 'fas fa-exclamation-triangle';
                default: return 'fas fa-info-circle';
            }
        },
        
        // === Méthodes pour les modals ===
        
        // Ouvrir un modal
        openModal(type, title, data = null) {
            this.modalType = type;
            this.modalTitle = title;
            
            // Traitement spécifique selon le type de modal
            if (type === 'appointmentDetails') {
                this.selectedAppointment = data;
            } else if (type === 'complaintDetails') {
                this.selectedComplaint = data;
                this.complaintCloseReason = '';
            } else if (type === 'uniforms') {
                // Les uniformes sont déjà chargés dans availableUniforms
            } else if (type === 'accessories') {
                this.currentAccessoryType = data;
                this.loadAccessories(data);
            } else if (type === 'fines') {
                // Les catégories d'amendes sont déjà chargées
            } else if (type === 'fineDetails') {
                this.selectedFineCategory = data;
                this.newFine.amount = data.minAmount;
                this.newFine.reason = '';
            } else if (type === 'addRecord') {
                this.newRecord = {
                    offense: '',
                    fineAmount: 0,
                    jailTime: 0,
                    notes: ''
                };
            } else if (type === 'gallery') {
                this.loadGalleryPhotos();
            }
            
            this.showModal = true;
        },
        
        // Fermer le modal
        closeModal() {
            this.showModal = false;
            this.modalType = '';
            this.modalTitle = '';
            this.selectedAppointment = null;
            this.selectedComplaint = null;
            this.complaintCloseReason = '';
            this.currentAccessoryType = null;
            this.selectedFineCategory = null;
            this.selectedPhoto = null;
        },
        
        // === Méthodes pour le service ===
        
        // Basculer l'état de service
        toggleDuty() {
            // Envoyer un message à LUA pour changer l'état de service
            fetch(`https://${GetParentResourceName()}/toggleDuty`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.isOnDuty = data.isOnDuty;
                    this.addNotification(
                        'Service',
                        this.isOnDuty ? 'Vous êtes maintenant hors service' : 'Vous êtes maintenant en service', 
                        this.isOnDuty ? 'error' : 'success' 
                    );
                }
            })
            .catch(error => {
                console.error('Erreur lors du changement de service:', error);
                this.addNotification('Erreur', 'Impossible de changer l\'état de service', 'error');
            });
        },
        
        // === Méthodes pour les interactions ===
        
        // Exécuter une action
        executeAction(action) {
            // Envoyer un message à LUA pour exécuter l'action
            fetch(`https://${GetParentResourceName()}/executeAction`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ action })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    // Traitement spécifique selon l'action
                    if (action === 'spawnK9' || action === 'dismissK9') {
                        this.hasK9 = data.hasK9;
                    }
                    
                    // Afficher une notification si présente
                    if (data.notification) {
                        this.addNotification(data.notification.title, data.notification.message, data.notification.type);
                    }
                    
                    // Fermer le modal si nécessaire
                    if (data.closeModal) {
                        this.closeModal();
                    }
                    
                    // Ouvrir un nouveau modal si demandé
                    if (data.openModal) {
                        this.openModal(data.openModal.type, data.openModal.title, data.openModal.data);
                    }
                }
            })
            .catch(error => {
                console.error('Erreur lors de l\'exécution de l\'action:', error);
                this.addNotification('Erreur', 'Impossible d\'exécuter l\'action', 'error');
            });
			
            // Traitement spécifique côté UI selon l'action
            if (action === 'bossMenu') {
                // Fermer l'interface avant d'ouvrir le menu boss
                this.closeApp();
                
                // Demander au script LUA d'ouvrir le menu boss
                fetch(`https://${GetParentResourceName()}/openBossMenu`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({})
                }).catch(error => {
                    console.error('Erreur lors de l\'ouverture du menu boss:', error);
                });
                
                return;
            }
            
            // Traitement spécifique côté UI selon l'action
            if (action === 'helmets') {
                this.openModal('accessories', 'Casques/Coiffes', 'helmets');
            } else if (action === 'vests') {
                this.openModal('accessories', 'Gilets', 'vests');
            } else if (action === 'bracelets') {
                this.openModal('accessories', 'Brassards', 'bracelets');
            } else if (action === 'fine') {
                this.openModal('fines', 'Catégories d\'amendes');
            } else if (action === 'license') {
                this.openModal('licenseManagement', 'Gestion des permis');
            }
        },
        
        // === Méthodes pour les props ===
        
        // Placer un prop
        placeProp(model) {
            this.executeAction('placeProp_' + model);
            this.closeApp(); // Fermer l'UI pour permettre de placer l'objet
        },
        
        // === Méthodes pour les tenues ===
        
        // Ouvrir le menu des tenues
        openUniformsMenu() {
            // Charger les tenues disponibles pour le grade actuel
            this.openModal('uniforms', 'Tenues de Service');
        },
        
        // Appliquer une tenue
        applyUniform(uniform) {
            fetch(`https://${GetParentResourceName()}/applyUniform`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ uniform })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.addNotification('Tenue', 'Tenue appliquée avec succès', 'success');
                    this.closeModal();
                }
            })
            .catch(error => {
                console.error('Erreur lors de l\'application de la tenue:', error);
                this.addNotification('Erreur', 'Impossible d\'appliquer la tenue', 'error');
            });
        },
        
        // Charger les accessoires
        loadAccessories(type) {
            fetch(`https://${GetParentResourceName()}/getAccessories`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ type })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.availableAccessories = data.accessories;
                }
            })
            .catch(error => {
                console.error('Erreur lors du chargement des accessoires:', error);
                this.addNotification('Erreur', 'Impossible de charger les accessoires', 'error');
            });
        },
        
        // Appliquer un accessoire
        applyAccessory(type, accessory) {
            fetch(`https://${GetParentResourceName()}/applyAccessory`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ type, accessory })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.addNotification('Accessoire', 'Accessoire appliqué avec succès', 'success');
                    this.closeModal();
                }
            })
            .catch(error => {
                console.error('Erreur lors de l\'application de l\'accessoire:', error);
                this.addNotification('Erreur', 'Impossible d\'appliquer l\'accessoire', 'error');
            });
        },
        
        // Retirer un accessoire
        removeAccessory(type) {
            fetch(`https://${GetParentResourceName()}/removeAccessory`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ type })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.addNotification('Accessoire', 'Accessoire retiré avec succès', 'success');
                    this.closeModal();
                }
            })
            .catch(error => {
                console.error('Erreur lors du retrait de l\'accessoire:', error);
                this.addNotification('Erreur', 'Impossible de retirer l\'accessoire', 'error');
            });
        },
        
        // === Méthodes pour les amendes ===
        
        // Sélectionner une catégorie d'amende
        selectFineCategory(category) {
            this.openModal('fineDetails', 'Détails de l\'amende', category);
        },
        
        // Soumettre une amende
        submitFine() {
            if (!this.newFine.amount || !this.newFine.reason) {
                this.addNotification('Erreur', 'Veuillez remplir tous les champs', 'error');
                return;
            }
            
            fetch(`https://${GetParentResourceName()}/submitFine`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    amount: this.newFine.amount,
                    reason: this.newFine.reason
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.addNotification('Amende', 'Amende donnée avec succès', 'success');
                    this.closeModal();
                }
            })
            .catch(error => {
                console.error('Erreur lors de la soumission de l\'amende:', error);
                this.addNotification('Erreur', 'Impossible de donner l\'amende', 'error');
            });
        },
                
        // === Méthodes pour les rendez-vous ===
        
        // Rafraîchir la liste des rendez-vous
        refreshAppointments() {
            fetch(`https://${GetParentResourceName()}/getAppointments`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.appointments = data.appointments;
                }
            })
            .catch(error => {
                console.error('Erreur lors du chargement des rendez-vous:', error);
                this.addNotification('Erreur', 'Impossible de charger les rendez-vous', 'error');
            });
        },
        
        // Sélectionner un rendez-vous
        selectAppointment(appointment) {
            this.openModal('appointmentDetails', 'Détails du rendez-vous', appointment);
        },
        
        // Accepter un rendez-vous
        acceptAppointment(id) {
            fetch(`https://${GetParentResourceName()}/acceptAppointment`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ id })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.addNotification('Rendez-vous', 'Rendez-vous accepté avec succès', 'success');
                    this.closeModal();
                    this.refreshAppointments();
                }
            })
            .catch(error => {
                console.error('Erreur lors de l\'acceptation du rendez-vous:', error);
                this.addNotification('Erreur', 'Impossible d\'accepter le rendez-vous', 'error');
            });
        },
        
        // Terminer un rendez-vous
        finishAppointment(id) {
            fetch(`https://${GetParentResourceName()}/finishAppointment`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ id })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.addNotification('Rendez-vous', 'Rendez-vous terminé avec succès', 'success');
                    this.closeModal();
                    this.refreshAppointments();
                }
            })
            .catch(error => {
                console.error('Erreur lors de la terminaison du rendez-vous:', error);
                this.addNotification('Erreur', 'Impossible de terminer le rendez-vous', 'error');
            });
        },
        
        // Annuler un rendez-vous
        cancelAppointment(id) {
            fetch(`https://${GetParentResourceName()}/cancelAppointment`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ id })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.addNotification('Rendez-vous', 'Rendez-vous annulé avec succès', 'success');
                    this.closeModal();
                    this.refreshAppointments();
                }
            })
            .catch(error => {
                console.error('Erreur lors de l\'annulation du rendez-vous:', error);
                this.addNotification('Erreur', 'Impossible d\'annuler le rendez-vous', 'error');
            });
        },
        
        // Formater la classe de statut pour les rendez-vous
        appointmentStatusClass(status) {
            switch (status) {
                case 'En attente': return 'status-pending';
                case 'Accepté': return 'status-accepted';
                case 'Terminé': return 'status-completed';
                case 'Annulé': return 'status-cancelled';
                default: return '';
            }
        },
        
        // === Méthodes pour les plaintes ===
        
        // Rafraîchir la liste des plaintes
        refreshComplaints() {
            fetch(`https://${GetParentResourceName()}/getComplaints`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.complaints = data.complaints;
                }
            })
            .catch(error => {
                console.error('Erreur lors du chargement des plaintes:', error);
                this.addNotification('Erreur', 'Impossible de charger les plaintes', 'error');
            });
        },
        
        // Sélectionner une plainte
        selectComplaint(complaint) {
            this.openModal('complaintDetails', 'Détails de la plainte', complaint);
        },
        
        // Fermer une plainte
        closeComplaint(id) {
            if (!this.complaintCloseReason) {
                this.addNotification('Erreur', 'Veuillez indiquer un rapport de clôture', 'error');
                return;
            }
            
            fetch(`https://${GetParentResourceName()}/closeComplaint`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    id,
                    closeReport: this.complaintCloseReason
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.addNotification('Plainte', 'Plainte clôturée avec succès', 'success');
                    this.closeModal();
                    this.refreshComplaints();
                }
            })
            .catch(error => {
                console.error('Erreur lors de la clôture de la plainte:', error);
                this.addNotification('Erreur', 'Impossible de clôturer la plainte', 'error');
            });
        },
        
        // Soumettre une nouvelle plainte
        submitComplaint() {
            if (!this.newComplaint.plaintiff || !this.newComplaint.description) {
                this.addNotification('Erreur', 'Veuillez remplir tous les champs', 'error');
                return;
            }
            
            fetch(`https://${GetParentResourceName()}/registerComplaint`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(this.newComplaint)
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.addNotification('Plainte', 'Plainte enregistrée avec succès', 'success');
                    this.newComplaint = {
                        type: 'theft',
                        plaintiff: '',
                        description: ''
                    };
                    this.complaintsTab = 'list';
                    this.refreshComplaints();
                }
            })
            .catch(error => {
                console.error('Erreur lors de l\'enregistrement de la plainte:', error);
                this.addNotification('Erreur', 'Impossible d\'enregistrer la plainte', 'error');
            });
        },
        
        // Tronquer le texte pour l'affichage
        truncateText(text, maxLength) {
            if (text.length <= maxLength) return text;
            return text.substring(0, maxLength) + '...';
        },
        
        // === Méthodes pour le casier judiciaire ===
        
        // Rechercher un casier judiciaire
        searchCriminalRecords() {
            if (!this.criminalSearch) {
                this.addNotification('Erreur', 'Veuillez saisir un numéro de carte d\'identité', 'error');
                return;
            }
            
            fetch(`https://${GetParentResourceName()}/searchCriminalRecords`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ documentNumber: this.criminalSearch })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.selectedCitizen = data.citizen;
                    this.criminalRecords = data.criminalRecords;
                    this.documents = data.documents;
                    this.criminalTab = 'records';
                } else {
                    this.addNotification('Erreur', 'Aucun citoyen trouvé avec ce numéro d\'identité', 'error');
                }
            })
            .catch(error => {
                console.error('Erreur lors de la recherche du casier judiciaire:', error);
                this.addNotification('Erreur', 'Impossible de rechercher le casier judiciaire', 'error');
            });
        },
        
        // Ouvrir le formulaire d'ajout d'infraction
        openAddRecordForm() {
            this.openModal('addRecord', 'Ajouter une infraction');
        },
        
        // Ouvrir le modal de galerie pour les photos
        openGalleryModal() {
            this.openModal('gallery', 'Galerie de photos');
        },
        
        // Charger les photos de la galerie
        loadGalleryPhotos() {
            this.loadingGallery = true;
            
            fetch(`https://${GetParentResourceName()}/getOfficerGallery`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.galleryPhotos = data.gallery;
                    this.loadingGallery = false;
                }
            })
            .catch(error => {
                console.error('Erreur lors du chargement des photos:', error);
                this.addNotification('Erreur', 'Impossible de charger les photos', 'error');
                this.loadingGallery = false;
            });
        },
        
        // Sélectionner une photo comme mugshot
        selectPhotoAsMugshot(photo) {
            if (!this.selectedCitizen) {
                this.addNotification('Erreur', 'Aucun citoyen sélectionné', 'error');
                return;
            }
            
            fetch(`https://${GetParentResourceName()}/setMugshot`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    citizenId: this.selectedCitizen.identifier,
                    imageUrl: photo.image_url
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    // Mettre à jour les données du citoyen
                    this.selectedCitizen.mugshot = photo.image_url;
                    this.addNotification('Casier judiciaire', 'Photo d\'identification ajoutée avec succès', 'success');
                    this.closeModal();
                }
            })
            .catch(error => {
                console.error('Erreur lors de l\'ajout de la photo:', error);
                this.addNotification('Erreur', 'Impossible d\'ajouter la photo', 'error');
            });
        },
        
        // Soumettre une nouvelle infraction
        submitNewRecord() {
            if (!this.newRecord.offense) {
                this.addNotification('Erreur', 'Veuillez indiquer la nature de l\'infraction', 'error');
                return;
            }
            
            fetch(`https://${GetParentResourceName()}/addCriminalRecord`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    citizenId: this.selectedCitizen.identifier,
                    documentNumber: this.documents[0].number,
                    citizenName: this.selectedCitizen.firstname + ' ' + this.selectedCitizen.lastname,
                    offense: this.newRecord.offense,
                    fineAmount: this.newRecord.fineAmount,
                    jailTime: this.newRecord.jailTime,
                    notes: this.newRecord.notes
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.addNotification('Casier judiciaire', 'Infraction ajoutée avec succès', 'success');
                    this.closeModal();
                    
                    // Rafraîchir les données du casier
                    this.searchCriminalRecords();
                }
            })
            .catch(error => {
                console.error('Erreur lors de l\'ajout de l\'infraction:', error);
                this.addNotification('Erreur', 'Impossible d\'ajouter l\'infraction', 'error');
            });
        },
        
        // Supprimer une entrée du casier judiciaire
        deleteRecord(id) {
            const confirmDelete = confirm('Êtes-vous sûr de vouloir supprimer cette entrée du casier judiciaire ?');
            if (!confirmDelete) return;
            
            fetch(`https://${GetParentResourceName()}/deleteCriminalRecord`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ id })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.addNotification('Casier judiciaire', 'Entrée supprimée avec succès', 'success');
                    
                    // Rafraîchir les données du casier
                    this.searchCriminalRecords();
                }
            })
            .catch(error => {
                console.error('Erreur lors de la suppression de l\'entrée:', error);
                this.addNotification('Erreur', 'Impossible de supprimer l\'entrée', 'error');
            });
        },
        
        // Obtenir le nom du type de document
        getDocumentTypeName(type) {
            const documentTypes = {
                ID: 'Carte d\'identité',
                Driver: 'Permis de conduire',
                Weapon: 'Permis de port d\'arme'
            };
            
            return documentTypes[type] || type;
        },
        
        // Formater la date de création d'une photo
        formatPhotoDate(dateStr) {
            if (!dateStr) return 'Date inconnue';
            
            const date = new Date(dateStr);
            return date.toLocaleDateString('fr-FR', { 
                day: '2-digit', 
                month: '2-digit', 
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
        },
		
		// Marquer un véhicule volé comme retrouvé
        markVehicleAsRecovered(plate) {
            fetch(`https://${GetParentResourceName()}/recoverStolenVehicle`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ plate })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.addNotification('success', 'Véhicule', 'Véhicule marqué comme retrouvé');
                    // Filtrer la liste pour enlever le véhicule marqué comme retrouvé
                    this.stolenVehicles = this.stolenVehicles.filter(v => v.plate !== plate);
                }
            })
            .catch(error => {
                console.error('Erreur lors de la récupération du véhicule:', error);
                this.addNotification('error', 'Erreur', 'Impossible de marquer le véhicule comme retrouvé');
            });
        },

        // Confirmer la mise en fourrière
        confirmImpound() {
            fetch(`https://${GetParentResourceName()}/confirmImpound`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.addNotification('success', 'Fourrière', 'Véhicule mis en fourrière avec succès');
                } else {
                    this.addNotification('error', 'Fourrière', 'Impossible de mettre le véhicule en fourrière');
                }
                this.closeModal();
            })
            .catch(error => {
                console.error('Erreur lors de la mise en fourrière:', error);
                this.addNotification('error', 'Erreur', 'Une erreur est survenue');
                this.closeModal();
            });
        },

        revokeDocument(docType, citizenId) {
            // Vérifiez que le type de document est autorisé
            if (docType !== 'Driver' && docType !== 'Weapon') {
                this.addNotification('error', 'Erreur', 'Vous ne pouvez pas révoquer ce type de document');
                return;
            }

            
            // Afficher une boîte de dialogue pour saisir la raison
            const reason = prompt("Motif de révocation:", "");
            if (reason === null || reason.trim() === "") {
                this.addNotification('error', 'Erreur', 'Vous devez spécifier un motif de révocation');
                return;
            }
            
            // Appel au callback NUI
            fetch(`https://${GetParentResourceName()}/revokeDocument`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    type: docType,
                    citizenId: citizenId,
                    reason: reason
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    // Une notification sera déjà envoyée par le serveur
                    // Rafraîchir la liste des documents après un court délai
                    setTimeout(() => {
                        this.searchCriminalRecords();
                    }, 500);
                } else {
                    this.addNotification('error', 'Erreur', data.message || 'Impossible de révoquer le permis');
                }
            })
            .catch(error => {
                console.error('Erreur lors de la révocation du permis:', error);
                this.addNotification('error', 'Erreur', 'Une erreur est survenue lors de la communication avec le serveur');
            });
        },

        // === Méthodes pour les alertes radio ===
        
        // Envoyer une alerte radio
        sendAlert(code) {
            fetch(`https://${GetParentResourceName()}/sendAlert`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ code })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.addNotification('Alerte', 'Alerte envoyée avec succès', 'success');
                    // Fermer l'interface après l'envoi de l'alerte
                    this.closeApp();
                }
            })
            .catch(error => {
                console.error('Erreur lors de l\'envoi de l\'alerte:', error);
                this.addNotification('Erreur', 'Impossible d\'envoyer l\'alerte', 'error');
            });
        }
		
    },
    
    // Gestion des événements clavier
    mounted() {
        // Écouter l'événement de message pour l'initialisation
        window.addEventListener('message', (event) => {
            const data = event.data;
            
            if (data.type === 'open') {
                this.initApp(data);
            } else if (data.type === 'close') {
                this.showApp = false;
            } else if (data.type === 'updateDuty') {
                this.isOnDuty = data.isOnDuty;
            } else if (data.type === 'updateK9') {
                this.hasK9 = data.hasK9;
            } else if (data.type === 'notification') {
                this.addNotification(data.title, data.message, data.notificationType || 'info');
            } else if (data.type === 'updateAppointments') {
                this.appointments = data.appointments;
            } else if (data.type === 'updateComplaints') {
                this.complaints = data.complaints;
            } else if (data.type === 'setActiveSection') {
                this.setActiveSection(data.section);
            } else if (data.type === 'updateOfficersList') {
                this.onDutyOfficers = data.officers;
            } else if (data.type === 'setVehicleInfo') {
                this.vehicleInfo = data.vehicleInfo;
                this.setActiveSection('vehicles');
                this.vehicleInfoTab = 'basic';
            } else if (data.type === 'setStolenVehicles') {
                this.stolenVehicles = data.vehicles;
                this.setActiveSection('vehicles');
                this.vehicleInfoTab = 'stolen';
            } else if (data.type === 'showImpoundConfirm') {
                this.impoundData = data.vehicle;
                this.openModal('impoundConfirm', 'Confirmation fourrière');
            }
        });
        
        // Écouter l'événement d'appui sur la touche Escape pour fermer l'application
        document.addEventListener('keydown', (event) => {
            if (event.key === 'Escape' && this.showApp) {
                if (this.showModal) {
                    this.closeModal();
                } else {
                    this.closeApp();
                }
            }
        });
    }
};

// Initialisation de Vue
const app = Vue.createApp(PoliceApp).mount('#app');

// Initialiser les écouteurs d'événements pour les messages depuis LUA
window.addEventListener('load', () => {
    // Envoyer un message à LUA pour signaler que l'interface est prête
    fetch(`https://${GetParentResourceName()}/uiReady`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
});