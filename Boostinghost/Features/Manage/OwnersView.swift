import SwiftUI

struct OwnersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = OwnersViewModel()

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                scrollContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { await vm.load() }
        .sheet(isPresented: $vm.showCreateSheet) {
            OwnerClientCreateSheet(vm: vm)
        }
        .alert("Client ajouté", isPresented: Binding(
            get: { vm.createSuccessName != nil },
            set: { if !$0 { vm.createSuccessName = nil } }
        )) {
            Button("OK") { vm.createSuccessName = nil }
        } message: {
            if let name = vm.createSuccessName {
                Text("\(name) a été ajouté à votre liste de propriétaires.")
            }
        }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
                    .frame(width: 38, height: 38)
                    .glassEffect(in: .circle)
                    .specularEdge(cornerRadius: 19)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(superTitle)
                    .font(.bhSurTitre)
                    .foregroundStyle(Color.bhAttenue)
                Text("Propriétaires")
                    .bhGrandTitre()
            }
            .padding(.leading, 12)

            Spacer(minLength: 12)

            Button { vm.showCreateSheet = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
                    .frame(width: 38, height: 38)
                    .glassEffect(in: .circle)
                    .specularEdge(cornerRadius: 19)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    private var superTitle: String {
        guard case .loaded = vm.loadState else { return " " }
        let nc = vm.clientCount
        let nl = vm.totalPropertyCount
        let clientPart = nc == 1 ? "1 client"    : "\(nc) clients"
        let logPart    = nl == 1 ? "1 logement"  : "\(nl) logements"
        return "\(clientPart) · \(logPart)"
    }

    // MARK: - Contenu principal

    @ViewBuilder
    private var scrollContent: some View {
        switch vm.loadState {
        case .loading:
            Spacer()
            ProgressView().tint(Color.bhAttenue)
            Spacer()
        case .featureBlocked:
            featureBlockedView
        case .error(let msg):
            errorView(msg)
        case .loaded:
            loadedContent
        }
    }

    private var loadedContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if !vm.pendingContracts.isEmpty {
                    signatureAlertCard
                }
                if vm.clients.isEmpty {
                    emptyClientsView
                } else {
                    clientsCard
                }
                documentsSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .refreshable { await vm.load() }
    }

    // MARK: - Alerte signature

    private var signatureAlertCard: some View {
        let n    = vm.pendingContracts.count
        let days = vm.daysSince(vm.oldestPendingContract?.createdAt)

        return HStack(spacing: 14) {
            Image(systemName: "signature")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.bhOr)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(n) contrat\(n == 1 ? "" : "s") en attente de signature")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bhOr)
                Text(sentAgoDays(days))
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.bhOrFond, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.bhOrClair.opacity(0.45), lineWidth: 1)
        }
    }

    private func sentAgoDays(_ days: Int) -> String {
        switch days {
        case 0:  return "Envoyé aujourd'hui"
        case 1:  return "Envoyé il y a 1 jour"
        default: return "Envoyé il y a \(days) jours"
        }
    }

    // MARK: - Carte clients

    private var clientsCard: some View {
        ListCard {
            ForEach(Array(vm.clients.enumerated()), id: \.element.id) { idx, client in
                CardRow(showSeparator: idx < vm.clients.count - 1) {
                    NavigationLink(destination: OwnerClientDetailView(
                        client: client,
                        allClients: vm.clients,
                        onChanged: { Task { await vm.load() } }
                    )) {
                        clientRow(client)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func clientRow(_ client: OwnerClient) -> some View {
        HStack(spacing: 12) {
            ProfileAvatarView(
                logoUrl:   nil,
                firstName: client.firstName,
                lastName:  client.lastName,
                company:   client.companyName,
                size:      42
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(client.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                    .lineLimit(1)
                Text(clientSubtitle(client))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.bhAttenue)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let badge = vm.badgeText(for: client) {
                StatusPill(text: badge, style: .or)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bhAttenue.opacity(0.55))
        }
    }

    // TODO: GET /api/properties ne retourne pas de champ city (composite address uniquement)
    // Afficher les villes distinctes quand la route exposera city.
    private func clientSubtitle(_ client: OwnerClient) -> String {
        let n = vm.propertyCount(for: client)
        return n == 1 ? "1 logement" : "\(n) logements"
    }

    // MARK: - Section DOCUMENTS

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Documents")
            ListCard {
                CardRow(showSeparator: true) {
                    NavigationLink(destination: ContractsView()) {
                        docRowLabel(icon: "signature", label: "Contrats", trailing: contractsTrailing)
                    }
                    .buttonStyle(.plain)
                }
                CardRow(showSeparator: true) {
                    NavigationLink(destination: OwnerInvoicesView()) {
                        docRowLabel(icon: "doc.text",
                                    label: "Factures propriétaires",
                                    trailing: invoicesTrailing)
                    }
                    .buttonStyle(.plain)
                }
                CardRow(showSeparator: true) {
                    NavigationLink(destination: AttestationView()) {
                        docRowLabel(icon: "doc.plaintext",
                                    label: "Attestation fiscale",
                                    trailing: nil)
                    }
                    .buttonStyle(.plain)
                }
                CardRow(showSeparator: false) {
                    NavigationLink(destination: DebourView()) {
                        docRowLabel(icon: "eurosign.circle",
                                    label: "Débours",
                                    trailing: nil)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var contractsTrailing: String? {
        let n = vm.pendingContracts.count
        guard n > 0 else { return nil }
        return n == 1 ? "1 en attente" : "\(n) en attente"
    }

    private var invoicesTrailing: String? {
        let n = vm.draftInvoices.count
        guard n > 0 else { return nil }
        return n == 1 ? "1 brouillon" : "\(n) brouillons"
    }

    private func docRowLabel(icon: String, label: String, trailing: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.bhVert)
                .frame(width: 28)
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.bhEncre)
            Spacer(minLength: 4)
            if let trailing {
                Text(trailing)
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bhAttenue.opacity(0.55))
        }
    }

    // MARK: - États

    private var featureBlockedView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)
            Image(systemName: "lock.circle")
                .font(.system(size: 40))
                .foregroundStyle(Color.bhAttenue)
            Text("Fonctionnalité non incluse")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.bhEncre)
            Text("La gestion des propriétaires n'est pas incluse dans votre abonnement actuel.")
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Spacer(minLength: 40)
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(Color.bhAttenue)
            Text(msg)
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
            Button("Réessayer") { Task { await vm.load() } }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bhVert)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyClientsView: some View {
        Text("Aucun client")
            .font(.bhCorps)
            .foregroundStyle(Color.bhAttenue)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 20)
    }
}

// MARK: - Feuille de création d'un propriétaire

private struct OwnerClientCreateSheet: View {
    let vm: OwnersViewModel

    private enum ClientType: String, CaseIterable {
        case individual = "individual"
        case business   = "business"

        var label: String {
            switch self {
            case .individual: return "Particulier"
            case .business:   return "Société"
            }
        }
    }

    @State private var clientType     = ClientType.individual
    @State private var companyName    = ""
    @State private var firstName      = ""
    @State private var lastName       = ""
    @State private var email          = ""
    @State private var phone          = ""
    @State private var siret          = ""
    @State private var address        = ""
    @State private var postalCode     = ""
    @State private var city           = ""
    @State private var commissionRate = ""
    @State private var isSaving       = false
    @State private var error: String?

    private var isFormValid: Bool {
        switch clientType {
        case .individual:
            return !firstName.trimmingCharacters(in: .whitespaces).isEmpty
                && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
        case .business:
            return !companyName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private var mandatoryHint: String? {
        guard !isFormValid else { return nil }
        switch clientType {
        case .individual: return "Le prénom et le nom sont obligatoires."
        case .business:   return "La raison sociale est obligatoire."
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                sheetNavBar
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
                        typePicker
                        mandatorySection
                        optionalSection
                        createButton
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .numericKeyboardBar()
    }

    // MARK: - Barre de navigation

    private var sheetNavBar: some View {
        VStack(spacing: 0) {
            SheetHandle()
            ZStack {
                Text("Nouveau propriétaire")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                HStack {
                    Button("Annuler") { vm.showCreateSheet = false }
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

    // MARK: - Sélecteur de type

    private var typePicker: some View {
        Picker("Type", selection: $clientType) {
            ForEach(ClientType.allCases, id: \.self) { type in
                Text(type.label).tag(type)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Champs obligatoires (changent selon le type)

    private var mandatorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Identité")
            ListCard {
                switch clientType {
                case .individual:
                    CardRow(showSeparator: true) {
                        fieldRow("Prénom", text: $firstName, placeholder: "Obligatoire")
                    }
                    CardRow(showSeparator: false) {
                        fieldRow("Nom", text: $lastName, placeholder: "Obligatoire")
                    }
                case .business:
                    CardRow(showSeparator: false) {
                        fieldRow("Raison sociale", text: $companyName, placeholder: "Obligatoire")
                    }
                }
            }
            if let hint = mandatoryHint {
                inlineHint(hint)
            }
        }
    }

    // MARK: - Champs optionnels

    private var optionalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Coordonnées et facturation")
            ListCard {
                CardRow(showSeparator: true) {
                    fieldRow("Email", text: $email, placeholder: "Optionnel")
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                CardRow(showSeparator: true) {
                    fieldRow("Téléphone", text: $phone, placeholder: "Optionnel")
                        .keyboardType(.phonePad)
                }
                CardRow(showSeparator: true) {
                    fieldRow("SIRET", text: $siret, placeholder: "Optionnel")
                        .keyboardType(.numberPad)
                }
                CardRow(showSeparator: true) {
                    fieldRow("Adresse", text: $address, placeholder: "Optionnel")
                }
                CardRow(showSeparator: true) {
                    fieldRow("Code postal", text: $postalCode, placeholder: "Optionnel")
                        .keyboardType(.numberPad)
                }
                CardRow(showSeparator: true) {
                    fieldRow("Ville", text: $city, placeholder: "Optionnel")
                }
                CardRow(showSeparator: false) {
                    fieldRow("Commission (%)", text: $commissionRate, placeholder: "20 par défaut")
                        .keyboardType(.decimalPad)
                }
            }
        }
    }

    // MARK: - Bouton créer

    private var createButton: some View {
        PrimaryButton(title: "Créer le propriétaire") {
            Task { await save() }
        }
        .disabled(!isFormValid || isSaving)
        .opacity(isFormValid && !isSaving ? 1 : 0.5)
    }

    // MARK: - Composants

    private func fieldRow(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(Color.bhEncre)
                .frame(width: 130, alignment: .leading)
            TextField(placeholder, text: text)
                .font(.system(size: 14.5))
                .foregroundStyle(Color.bhEncre)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
        }
    }

    private func inlineHint(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.bhOr)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color.bhAttenue)
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Action

    private func save() async {
        guard !isSaving, isFormValid else { return }
        isSaving = true
        error    = nil

        let rate = Double(commissionRate.replacingOccurrences(of: ",", with: "."))

        do {
            try await vm.create(
                clientType:            clientType.rawValue,
                companyName:           companyName.trimmingCharacters(in: .whitespaces).nonEmpty,
                firstName:             firstName.trimmingCharacters(in: .whitespaces).nonEmpty,
                lastName:              lastName.trimmingCharacters(in: .whitespaces).nonEmpty,
                email:                 email.trimmingCharacters(in: .whitespaces).nonEmpty,
                phone:                 phone.trimmingCharacters(in: .whitespaces).nonEmpty,
                siret:                 siret.trimmingCharacters(in: .whitespaces).nonEmpty,
                address:               address.trimmingCharacters(in: .whitespaces).nonEmpty,
                postalCode:            postalCode.trimmingCharacters(in: .whitespaces).nonEmpty,
                city:                  city.trimmingCharacters(in: .whitespaces).nonEmpty,
                defaultCommissionRate: rate
            )
        } catch {
            self.error = ownerClientAPIMessage(error)
        }
        isSaving = false
    }
}

private func ownerClientAPIMessage(_ error: Error) -> String {
    if let e = error as? APIError {
        switch e {
        case .server(_, let msg?): return msg
        case .network:             return "Connexion impossible. Vérifiez votre réseau."
        default:                   break
        }
    }
    return "Une erreur est survenue. Réessayez."
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
