import SwiftUI

struct TeamListView: View {

    @State private var vm = TeamViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                content
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(for: SubAccount.self) { member in
            TeamMemberDetailView(member: member, teamVM: vm)
        }
        .task { await vm.load() }
        .sheet(isPresented: $vm.showCreateSheet) {
            SubAccountCreateSheet(vm: vm)
        }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Mon compte")
                        .font(.system(size: 16.5, weight: .semibold))
                }
                .foregroundStyle(Color.bhVert)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 1) {
                Text(surTitle)
                    .font(.bhSurTitre)
                    .foregroundStyle(Color.bhAttenue)
                Text("Mon équipe et accès")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
            }

            Spacer()

            if authStore.session?.can("can_manage_team") ?? true {
                Button { vm.showCreateSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 90, height: 1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    private var surTitle: String {
        switch vm.loadState {
        case .loaded:
            let n = vm.members.count
            return "\(n) membre\(n == 1 ? "" : "s")"
        default:
            return " "
        }
    }

    // MARK: - Contenu principal

    @ViewBuilder
    private var content: some View {
        switch vm.loadState {
        case .idle, .loading:
            Spacer()
            ProgressView().tint(Color.bhAttenue)
            Spacer()

        case .failed(let msg):
            Spacer()
            Text(msg)
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()

        case .loaded:
            if vm.members.isEmpty {
                Spacer()
                Text("Aucun membre dans l'équipe.")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    memberList
                        .padding(.horizontal, 18)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Liste des membres

    private var memberList: some View {
        VStack(spacing: 12) {
            ForEach(vm.members, id: \.id) { member in
                ListCard {
                    NavigationLink(value: member) {
                        memberRow(member)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Ligne de liste

    @ViewBuilder
    private func memberRow(_ member: SubAccount) -> some View {
        CardRow(verticalPadding: 16, showSeparator: false) {
            HStack(spacing: 14) {

                ProfileAvatarView(
                    logoUrl:   nil,
                    firstName: member.firstName,
                    lastName:  member.lastName,
                    company:   nil,
                    size:      40
                )

                // Nom + e-mail
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(member.displayName.isEmpty ? member.email ?? "—" : member.displayName)
                            .font(.system(size: 15.5, weight: .medium))
                            .foregroundStyle(Color.bhEncre)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if !member.isActive {
                            StatusPill(text: "inactif", style: .neutre)
                        }
                    }
                    Text(member.email ?? "—")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if vm.isAgencyMode, let parentName = member.parentUserName, !parentName.isEmpty {
                        Text(parentName)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color(hex: "#5E6B63"))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Spacer(minLength: 8)

                // Chevron décoratif
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.bhAttenue.opacity(0.55))
            }
        }
    }
}

// MARK: - Feuille de création de sous-compte

private struct SubAccountCreateSheet: View {
    let vm: TeamViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var firstName        = ""
    @State private var lastName         = ""
    @State private var email            = ""
    @State private var password         = ""
    @State private var selectedTargetId = ""
    @State private var isLoadingTargets      = true
    @State private var isSaving              = false
    @State private var error: String?
    @State private var selectedPropertyIds   = [String]()
    @State private var showPropertyPicker    = false

    // Affiché seulement si le serveur renvoie plusieurs comptes à choisir.
    private var showSelector: Bool { !isLoadingTargets && vm.targetAccounts.count > 1 }

    private var propertiesReady: Bool {
        switch vm.propertiesLoadState {
        case .loaded: return true
        default: return false
        }
    }

    private var isFormValid: Bool {
        propertiesReady
        && !isLoadingTargets
        && (!showSelector || !selectedTargetId.isEmpty)
        && !firstName.trimmingCharacters(in: .whitespaces).isEmpty
        && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
        && !email.trimmingCharacters(in: .whitespaces).isEmpty
        && !password.isEmpty
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if let err = error {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.85),
                                            in: RoundedRectangle(cornerRadius: 10))
                        }
                        targetSection
                        formFields
                        propertiesAreaSection
                        PrimaryButton(title: "Créer le sous-compte") {
                            Task { await save() }
                        }
                        .disabled(!isFormValid || isSaving)
                        .opacity(isFormValid && !isSaving ? 1 : 0.5)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            await vm.loadTargetAccounts()
            isLoadingTargets = false
            if vm.targetAccounts.count == 1 {
                selectedTargetId = vm.targetAccounts[0].userId
            }
            await vm.loadProperties()
        }
        .onChange(of: selectedTargetId) { selectedPropertyIds = [] }
        .sheet(isPresented: $showPropertyPicker) {
            PropertyAccessPickerSheet(
                selectedIds: $selectedPropertyIds,
                properties: vm.properties
            )
        }
    }

    // MARK: - Barre

    private var navBar: some View {
        VStack(spacing: 0) {
            SheetHandle()
            ZStack {
                Text("Nouveau sous-compte")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                HStack {
                    Button("Annuler") { dismiss() }
                        .font(.system(size: 16))
                        .foregroundStyle(Color.bhAttenue)
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                    Spacer()
                    if isSaving { ProgressView().tint(Color.bhAttenue) }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Section logements (loading / error / picker)

    @ViewBuilder
    private var propertiesAreaSection: some View {
        switch vm.propertiesLoadState {
        case .idle, .loading:
            ListCard {
                CardRow(showSeparator: false) {
                    HStack {
                        Text("Logements accessibles")
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundStyle(Color.bhEncre)
                        Spacer()
                        ProgressView().tint(Color.bhAttenue).scaleEffect(0.85)
                    }
                }
            }
        case .loaded:
            if !vm.properties.isEmpty {
                propertiesSection
            }
        case .failed:
            ListCard {
                CardRow(showSeparator: false) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Logements accessibles")
                                .font(.system(size: 14.5, weight: .medium))
                                .foregroundStyle(Color.bhEncre)
                            Text("Impossible de charger les logements.")
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhAttenue)
                        }
                        Spacer()
                        Button("Réessayer") {
                            Task { await vm.reloadProperties() }
                        }
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Color.bhVert)
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Sélecteur de logements accessibles

    private var propertyPickerLabel: String {
        if selectedPropertyIds.isEmpty { return "Tous les logements" }
        let n = selectedPropertyIds.count
        return "\(n) logement\(n == 1 ? "" : "s")"
    }

    private var propertiesSection: some View {
        ListCard {
            CardRow(showSeparator: false) {
                Button { showPropertyPicker = true } label: {
                    HStack(spacing: 10) {
                        Text("Logements accessibles")
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundStyle(Color.bhEncre)
                        Spacer(minLength: 8)
                        Text(propertyPickerLabel)
                            .font(.system(size: 14.5))
                            .foregroundStyle(Color.bhAttenue)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.bhAttenue.opacity(0.55))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            }
        }
    }

    // MARK: - Sélecteur de compte de rattachement

    @ViewBuilder
    private var targetSection: some View {
        // Affiché pendant le chargement (spinner) et après si plusieurs comptes.
        if isLoadingTargets || vm.targetAccounts.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                ListCard {
                    CardRow(showSeparator: false) {
                        HStack {
                            Text("Compte de rattachement")
                                .font(.system(size: 14.5, weight: .medium))
                                .foregroundStyle(Color.bhEncre)
                            Spacer()
                            if isLoadingTargets {
                                ProgressView().tint(Color.bhAttenue).scaleEffect(0.85)
                            } else {
                                Picker("", selection: $selectedTargetId) {
                                    Text("Sélectionner…").tag("")
                                    ForEach(vm.targetAccounts) { account in
                                        Text(account.name).tag(account.userId)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(selectedTargetId.isEmpty ? Color.bhAttenue : Color.bhVert)
                            }
                        }
                    }
                }
                Text("Le rattachement ne pourra pas être modifié après création.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#5E6B63"))
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Champs

    private var formFields: some View {
        ListCard {
            CardRow(showSeparator: true) {
                fieldRow("Prénom", text: $firstName, placeholder: "Obligatoire")
                    .textInputAutocapitalization(.words)
            }
            CardRow(showSeparator: true) {
                fieldRow("Nom", text: $lastName, placeholder: "Obligatoire")
                    .textInputAutocapitalization(.words)
            }
            CardRow(showSeparator: true) {
                fieldRow("Email", text: $email, placeholder: "Obligatoire")
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
            CardRow(showSeparator: false) {
                HStack {
                    Text("Mot de passe")
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(Color.bhEncre)
                        .frame(width: 110, alignment: .leading)
                    SecureField("Obligatoire", text: $password)
                        .font(.system(size: 14.5))
                        .foregroundStyle(Color.bhEncre)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                }
            }
        }
    }

    @ViewBuilder
    private func fieldRow(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(Color.bhEncre)
                .frame(width: 110, alignment: .leading)
            TextField(placeholder, text: text)
                .font(.system(size: 14.5))
                .foregroundStyle(Color.bhEncre)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
        }
    }

    // MARK: - Action

    private func save() async {
        guard !isSaving, isFormValid else { return }
        isSaving = true
        error    = nil
        let target = showSelector ? (selectedTargetId.isEmpty ? nil : selectedTargetId) : nil
        do {
            try await vm.createSubAccount(
                email:        email.trimmingCharacters(in: .whitespaces),
                password:     password,
                firstName:    firstName.trimmingCharacters(in: .whitespaces),
                lastName:     lastName.trimmingCharacters(in: .whitespaces),
                targetUserId: target,
                propertyIds:  selectedPropertyIds
            )
            dismiss()
        } catch APIError.server(_, let msg) {
            error = msg ?? "Une erreur est survenue."
        } catch {
            self.error = "Une erreur est survenue. Réessayez."
        }
        isSaving = false
    }
}
