import SwiftUI

struct TeamMemberDetailView: View {

    let member: SubAccount
    let teamVM: TeamViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var editState: PermissionsEditState
    @State private var isSaving = false
    @State private var saveError: String?

    init(member: SubAccount, teamVM: TeamViewModel) {
        self.member  = member
        self.teamVM  = teamVM
        _editState   = State(initialValue: PermissionsEditState(from: member))
    }

    private var isCustomRole: Bool { member.role == "custom" }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                if let err = saveError {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.85))
                }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        memberHeader
                        if isEditing {
                            editContent
                        } else {
                            readContent
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        HStack {
            // Bouton gauche
            if isEditing {
                Button("Annuler") {
                    editState  = PermissionsEditState(from: member)
                    saveError  = nil
                    isEditing  = false
                }
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.bhVert)
                .buttonStyle(.plain)
                .disabled(isSaving)
            } else {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Mon équipe")
                            .font(.system(size: 16.5, weight: .semibold))
                    }
                    .foregroundStyle(Color.bhVert)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Titre central
            Text(isEditing ? "Modification" : (member.displayName.isEmpty ? "Membre" : member.displayName))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.bhEncre)
                .lineLimit(1)

            Spacer()

            // Bouton droit
            Group {
                if isEditing {
                    if isSaving {
                        ProgressView().tint(Color.bhAttenue)
                    } else {
                        Button("Enregistrer") {
                            Task { await save() }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                        .buttonStyle(.plain)
                        .lineLimit(1)
                        .fixedSize()
                    }
                } else if isCustomRole {
                    Button("Modifier") { isEditing = true }
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.bhVert)
                        .buttonStyle(.plain)
                        .lineLimit(1)
                } else {
                    Color.clear.frame(width: 1, height: 1)
                }
            }
            .frame(minWidth: 70, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - En-tête du membre

    private var memberHeader: some View {
        ListCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#DCE8E1"))
                        .frame(width: 52, height: 52)
                    Text(member.initials.isEmpty ? "?" : member.initials)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(member.displayName.isEmpty ? member.email ?? "—" : member.displayName)
                            .font(.system(size: 18.5, weight: .semibold))
                            .foregroundStyle(Color.bhEncre)
                        if !member.isActive {
                            StatusPill(text: "inactif", style: .neutre)
                        }
                    }
                    Text(member.roleLabel)
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                    if let email = member.email {
                        Text(email)
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhAttenue)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Contenu lecture

    private var readContent: some View {
        Group {
            if !isCustomRole {
                fixedRoleBanner
            }
            ForEach(Array(member.permissionGroups.enumerated()), id: \.offset) { _, group in
                permissionGroupView(group)
            }
        }
    }

    // Bannière pour les rôles prédéfinis (droits fixés côté serveur)
    private var fixedRoleBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.bhOr)
            Text("Les droits de ce membre sont définis par son rôle et ne peuvent pas être modifiés individuellement.")
                .font(.system(size: 13.5))
                .foregroundStyle(Color.bhAttenue)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.bhOr.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Groupe de permissions (lecture)

    @ViewBuilder
    private func permissionGroupView(_ group: SubAccount.PermissionGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: group.title)
            ListCard {
                if group.shouldCollapse {
                    CardRow(showSeparator: false) {
                        Text(group.collapsedLabel)
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhAttenue)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 2)
                    }
                } else {
                    ForEach(Array(group.entries.enumerated()), id: \.offset) { idx, entry in
                        CardRow(showSeparator: idx < group.entries.count - 1) {
                            accessRow(entry)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func accessRow(_ entry: SubAccount.PermissionGroup.Entry) -> some View {
        HStack(spacing: 10) {
            // Gouttière fixe 20 pt : coche ou vide — label toujours au même x
            Group {
                if entry.granted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.bhOccupe)
                } else {
                    Color.clear
                }
            }
            .frame(width: 20, height: 20)

            Text(entry.label)
                .font(.system(size: 14.5))
                .foregroundStyle(entry.granted ? Color.bhEncre : Color.bhAttenue)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Contenu édition

    @ViewBuilder
    private var editContent: some View {
        editSection(title: "Calendrier", entries: [
            ("Voir le calendrier",             false, $editState.canViewCalendar),
            ("Modifier les réservations",      true,  $editState.canEditReservations),
            ("Créer des réservations",         true,  $editState.canCreateReservations),
            ("Supprimer des réservations",     true,  $editState.canDeleteReservations),
        ])
        editSection(title: "Messages", entries: [
            ("Voir les messages",              false, $editState.canViewMessages),
            ("Envoyer des messages",           true,  $editState.canSendMessages),
            ("Voir les modèles automatiques",  false, $editState.canViewTemplates),
            ("Gérer les modèles automatiques", true,  $editState.canManageTemplates),
        ])
        editSection(title: "Ménage", entries: [
            ("Voir les assignations",          false, $editState.canViewCleaning),
            ("Assigner les ménages",           true,  $editState.canAssignCleaning),
            ("Gérer les prestataires",         true,  $editState.canManageCleaningStaff),
        ])
        editSection(title: "Logements", entries: [
            ("Voir les logements",             false, $editState.canViewProperties),
            ("Voir les livrets d'accueil",     false, $editState.canViewWelcomeBook),
            ("Voir les serrures connectées",   false, $editState.canViewSmartLocks),
            ("Modifier les logements",         true,  $editState.canEditProperties),
            ("Gérer les serrures connectées",  true,  $editState.canManageSmartLocks),
            ("Accéder aux paramètres",         true,  $editState.canAccessSettings),
            ("Gérer l'équipe",                 true,  $editState.canManageTeam),
        ])
        editSection(title: "Propriétaires", entries: [
            ("Voir les propriétaires",         false, $editState.canViewOwners),
            ("Voir les contrats",              false, $editState.canViewContracts),
        ])
        editSection(title: "Argent", entries: [
            ("Voir les finances",              false, $editState.canViewFinances),
            ("Voir les cautions",              false, $editState.canViewDeposits),
            ("Voir les factures",              false, $editState.canViewInvoices),
            ("Voir les paiements",             false, $editState.canViewPayments),
            ("Voir les tarifs",                false, $editState.canViewPricing),
            ("Voir les débours",               false, $editState.canViewDebours),
            ("Voir les rapports",              false, $editState.canViewReporting),
            ("Modifier les finances",          true,  $editState.canEditFinances),
            ("Gérer les cautions",             true,  $editState.canManageDeposits),
            ("Gérer les factures",             true,  $editState.canManageInvoices),
            ("Gérer les paiements",            true,  $editState.canManagePayments),
            ("Gérer les tarifs",               true,  $editState.canManagePricing),
            ("Gérer les débours",              true,  $editState.canManageDebours),
        ])
        editSection(title: "Notifications reçues", entries: [
            ("Nouvelle réservation",           false, $editState.notifSubNewReservation),
            ("Annulation de réservation",      false, $editState.notifSubReservationCancelled),
            ("Récap quotidien",                false, $editState.notifSubDailySummary),
            ("Nouveau message",                false, $editState.notifSubNewMessage),
            ("Ménage assigné",                 false, $editState.notifSubCleaningAssigned),
            ("Ménage terminé",                 false, $editState.notifSubCleaningCompleted),
            ("Caution reçue",                  false, $editState.notifSubDepositPaid),
            ("Paiement reçu",                  false, $editState.notifSubPaymentReceived),
        ])
    }

    @ViewBuilder
    private func editSection(
        title: String,
        entries: [(label: String, indented: Bool, binding: Binding<Bool>)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            ListCard {
                ForEach(Array(entries.enumerated()), id: \.offset) { idx, entry in
                    CardRow(showSeparator: idx < entries.count - 1) {
                        HStack(spacing: 8) {
                            Text(entry.label)
                                .font(.system(size: 14.5))
                                .foregroundStyle(Color.bhEncre)
                            Spacer(minLength: 8)
                            Toggle("", isOn: entry.binding)
                                .labelsHidden()
                                .tint(Color.bhVert)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sauvegarde

    private func save() async {
        isSaving  = true
        saveError = nil
        let req   = editState.toRequest(
            firstName: member.firstName ?? "",
            lastName:  member.lastName  ?? ""
        )
        do {
            try await teamVM.update(id: member.id, request: req)
            Task { await teamVM.reload() }
            dismiss()
        } catch APIError.server(let code, let msg) {
            saveError = msg ?? "Erreur serveur (\(code))."
        } catch {
            saveError = "Impossible d'enregistrer les modifications."
        }
        isSaving = false
    }
}
