import SwiftUI

// MARK: - Draft local

private struct OwnerClientDraft {
    var clientType:     String = "individual"
    var firstName:      String = ""
    var lastName:       String = ""
    var companyName:    String = ""
    var email:          String = ""
    var phone:          String = ""
    var siret:          String = ""
    var address:        String = ""
    var postalCode:     String = ""
    var city:           String = ""
    var commissionRate: String = ""

    init() {}

    init(from c: OwnerClient) {
        clientType     = c.clientType    ?? "individual"
        firstName      = c.firstName     ?? ""
        lastName       = c.lastName      ?? ""
        companyName    = c.companyName   ?? ""
        email          = c.email         ?? ""
        phone          = c.phone         ?? ""
        siret          = c.siret         ?? ""
        address        = c.address       ?? ""
        postalCode     = c.postalCode    ?? ""
        city           = c.city          ?? ""
        if let rate = c.defaultCommissionRate {
            commissionRate = rate.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(rate)) : String(format: "%.2f", rate)
        } else {
            commissionRate = ""
        }
    }

    var isFormValid: Bool {
        clientType == "business"
            ? !companyName.trimmedValue.isEmpty
            : (!firstName.trimmedValue.isEmpty && !lastName.trimmedValue.isEmpty)
    }

    func toBody() -> UpdateOwnerClientBody {
        let rate = Double(commissionRate.replacingOccurrences(of: ",", with: ".")) ?? 20
        return UpdateOwnerClientBody(
            clientType:            clientType,
            firstName:             firstName.trimmedValue.nilIfEmpty,
            lastName:              lastName.trimmedValue.nilIfEmpty,
            companyName:           companyName.trimmedValue.nilIfEmpty,
            email:                 email.trimmedValue.nilIfEmpty,
            phone:                 phone.trimmedValue.nilIfEmpty,
            siret:                 siret.trimmedValue.nilIfEmpty,
            address:               address.trimmedValue.nilIfEmpty,
            postalCode:            postalCode.trimmedValue.nilIfEmpty,
            city:                  city.trimmedValue.nilIfEmpty,
            defaultCommissionRate: rate
        )
    }
}

private extension String {
    var trimmedValue: String { trimmingCharacters(in: .whitespaces) }
    var nilIfEmpty:   String? { trimmedValue.isEmpty ? nil : trimmedValue }
}

// MARK: - Vue

struct OwnerClientDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: OwnerClientDetailViewModel
    let allClients: [OwnerClient]
    var onChanged: (() -> Void)? = nil

    @State private var isEditing  = false
    @State private var isSaving   = false
    @State private var draft      = OwnerClientDraft()
    @State private var saveError: String?

    @State private var showDeleteConfirm   = false
    @State private var showDeleteWithProps = false
    @State private var actionError: String?

    @State private var showPropertySheet = false

    init(client: OwnerClient, allClients: [OwnerClient] = [], onChanged: (() -> Void)? = nil) {
        _vm = State(initialValue: OwnerClientDetailViewModel(client: client))
        self.allClients = allClients
        self.onChanged = onChanged
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                switch vm.loadState {
                case .loading:
                    Spacer()
                    ProgressView().tint(Color.bhAttenue)
                    Spacer()
                case .error(let msg):
                    errorView(msg)
                case .loaded:
                    if let client = vm.client { loadedContent(client) }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .task { await vm.load() }
        .numericKeyboardBar()
        .sheet(isPresented: $showPropertySheet) {
            if let client = vm.client {
                PropertyAssignmentSheet(
                    client: client,
                    allProperties: vm.allProperties,
                    allClients: allClients,
                    initialSelectedIds: Set(vm.associatedProperties.map(\.id)),
                    onSave: { newSelected in
                        try await vm.savePropertyAssignments(newSelected: newSelected)
                        onChanged?()
                    }
                )
            }
        }
        .alert("Erreur", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: { Text(saveError ?? "") }
        .alert("Erreur", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK") { actionError = nil }
        } message: { Text(actionError ?? "") }
        .alert("Supprimer ce client ?", isPresented: $showDeleteConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) { Task { await doDelete() } }
        } message: {
            Text("Cette action est définitive.")
        }
        .alert("Supprimer ce client ?", isPresented: $showDeleteWithProps) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer quand même", role: .destructive) { Task { await doDelete() } }
        } message: {
            let n = vm.associatedProperties.count
            Text("Ce client gère \(n) logement\(n == 1 ? "" : "s"). Ils ne seront plus associés à aucun propriétaire.")
        }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        ZStack {
            if let client = vm.client {
                VStack(spacing: 1) {
                    Text("Propriétaire")
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                    Text(client.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 96)
            }
            HStack {
                if isEditing {
                    Button {
                        if let c = vm.client { draft = OwnerClientDraft(from: c) }
                        isEditing = false
                    } label: {
                        Text("Annuler")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.bhVert)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .glassEffect(in: .rect(cornerRadius: 12))
                            .specularEdge(cornerRadius: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.bhVert)
                            .frame(width: 36, height: 36)
                            .glassEffect(in: .circle)
                            .specularEdge(cornerRadius: 18)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if isEditing {
                    Button { Task { await save() } } label: {
                        if isSaving {
                            ProgressView().tint(Color.bhVert)
                                .frame(width: 24, height: 24)
                                .padding(.horizontal, 18).padding(.vertical, 7)
                        } else {
                            Text("Enregistrer")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.bhVert)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .glassEffect(in: .rect(cornerRadius: 12))
                                .specularEdge(cornerRadius: 12)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving || !draft.isFormValid)
                    .opacity((isSaving || !draft.isFormValid) ? 0.5 : 1)
                } else if case .loaded = vm.loadState {
                    Button {
                        if let c = vm.client { draft = OwnerClientDraft(from: c) }
                        isEditing = true
                    } label: {
                        Text("Modifier")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.bhVert)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .glassEffect(in: .rect(cornerRadius: 12))
                            .specularEdge(cornerRadius: 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 14)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Contenu chargé

    private func loadedContent(_ client: OwnerClient) -> some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if isEditing {
                        editContent(client)
                    } else {
                        readContent(client)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, isEditing || !vm.canDelete ? 40 : 100)
            }
            if !isEditing && vm.canDelete {
                deleteBar
            }
        }
    }

    // MARK: - Lecture

    private func readContent(_ client: OwnerClient) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if client.hasOverride == true {
                overrideBadge
            }
            identiteSection(client)
            contactSection(client)
            adresseSection(client)
            facturationSection(client)
            logementSection
        }
    }

    private var overrideBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.bhOr)
            Text("Coordonnées personnalisées")
                .font(.system(size: 13))
                .foregroundStyle(Color.bhOr)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.bhOr.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.bhOr.opacity(0.30), lineWidth: 1)
                }
        }
    }

    private func identiteSection(_ client: OwnerClient) -> some View {
        let isBusiness = client.clientType == "business"
        let hasSiret   = !(client.siret ?? "").isEmpty
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Identité")
            ListCard {
                CardRow(showSeparator: true) {
                    readRow("Type", value: isBusiness ? "Société" : "Particulier")
                }
                if isBusiness {
                    CardRow(showSeparator: hasSiret) {
                        readRow("Raison sociale", value: client.companyName ?? "—")
                    }
                } else {
                    CardRow(showSeparator: true) {
                        readRow("Prénom", value: client.firstName ?? "—")
                    }
                    CardRow(showSeparator: hasSiret) {
                        readRow("Nom", value: client.lastName ?? "—")
                    }
                }
                if hasSiret {
                    CardRow(showSeparator: false) {
                        readRow("SIRET", value: client.siret!)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func contactSection(_ client: OwnerClient) -> some View {
        let hasEmail = !(client.email ?? "").isEmpty
        let hasPhone = !(client.phone ?? "").isEmpty
        if hasEmail || hasPhone {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Contact")
                ListCard {
                    if hasEmail {
                        CardRow(showSeparator: hasPhone) {
                            readRow("Email", value: client.email!)
                        }
                    }
                    if hasPhone {
                        CardRow(showSeparator: false) {
                            readRow("Téléphone", value: client.phone!)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func adresseSection(_ client: OwnerClient) -> some View {
        let hasAddress    = !(client.address    ?? "").isEmpty
        let hasPostalCode = !(client.postalCode ?? "").isEmpty
        let hasCity       = !(client.city       ?? "").isEmpty
        if hasAddress || hasPostalCode || hasCity {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Adresse")
                ListCard {
                    if hasAddress {
                        CardRow(showSeparator: hasPostalCode || hasCity) {
                            readRow("Adresse", value: client.address!)
                        }
                    }
                    if hasPostalCode {
                        CardRow(showSeparator: hasCity) {
                            readRow("Code postal", value: client.postalCode!)
                        }
                    }
                    if hasCity {
                        CardRow(showSeparator: false) {
                            readRow("Ville", value: client.city!)
                        }
                    }
                }
            }
        }
    }

    private func facturationSection(_ client: OwnerClient) -> some View {
        let rate = client.defaultCommissionRate
        let display = rate.map { r in
            r.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(r))\u{202F}%"
                : "\(String(format: "%.2f", r))\u{202F}%"
        } ?? "20\u{202F}%"
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Facturation")
            ListCard {
                CardRow(showSeparator: false) {
                    readRow("Commission par défaut", value: display)
                }
            }
        }
    }

    private var logementSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: "Logements associés")
                Spacer()
                Button("Modifier") { showPropertySheet = true }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.bhVert)
                    .buttonStyle(.plain)
            }
            ListCard {
                if vm.associatedProperties.isEmpty {
                    CardRow(showSeparator: false) {
                        Text("Aucun logement associé")
                            .font(.system(size: 14.5))
                            .foregroundStyle(Color.bhAttenue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ForEach(Array(vm.associatedProperties.enumerated()), id: \.element.id) { idx, prop in
                        CardRow(showSeparator: idx < vm.associatedProperties.count - 1) {
                            HStack(spacing: 10) {
                                Image(systemName: "house")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.bhVert)
                                    .frame(width: 20)
                                Text(prop.internalName ?? prop.name)
                                    .font(.system(size: 14.5))
                                    .foregroundStyle(Color.bhEncre)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Édition

    private func editContent(_ client: OwnerClient) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if client.isAgencyClient == true, let name = client.delegatorName {
                agencyEditBanner(delegatorName: name)
            }
            if client.isAgencyClient != true {
                typePicker
            }
            identiteEditSection
            coordsEditSection(isAgency: client.isAgencyClient == true)
        }
    }

    private func agencyEditBanner(delegatorName: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "building.2")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.bhVert)
                .frame(width: 22, alignment: .center)
            Text("Ce propriétaire est géré par \(delegatorName). Vos modifications s'appliquent uniquement à votre facturation.")
                .font(.system(size: 13.5))
                .foregroundStyle(Color.bhOccupeFonce)
                .lineSpacing(3.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.bhMentheFond)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(red: 46/255, green: 139/255, blue: 98/255).opacity(0.28), lineWidth: 1)
                }
        }
    }

    private var typePicker: some View {
        Picker("Type", selection: $draft.clientType) {
            Text("Particulier").tag("individual")
            Text("Société").tag("business")
        }
        .pickerStyle(.segmented)
    }

    private var identiteEditSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Identité")
            ListCard {
                if draft.clientType == "business" {
                    CardRow(showSeparator: true) {
                        editField("Raison sociale", text: $draft.companyName, placeholder: "Obligatoire")
                    }
                } else {
                    CardRow(showSeparator: true) {
                        editField("Prénom", text: $draft.firstName, placeholder: "Obligatoire")
                    }
                    CardRow(showSeparator: true) {
                        editField("Nom", text: $draft.lastName, placeholder: "Obligatoire")
                    }
                }
                CardRow(showSeparator: false) {
                    editField("SIRET", text: $draft.siret, placeholder: "Optionnel")
                        .keyboardType(.numberPad)
                }
            }
            if !draft.isFormValid {
                mandatoryHint
            }
        }
    }

    private func coordsEditSection(isAgency: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: isAgency ? "Coordonnées" : "Coordonnées et facturation")
            ListCard {
                CardRow(showSeparator: true) {
                    editField("Email", text: $draft.email, placeholder: "Optionnel")
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                CardRow(showSeparator: true) {
                    editField("Téléphone", text: $draft.phone, placeholder: "Optionnel")
                        .keyboardType(.phonePad)
                }
                CardRow(showSeparator: true) {
                    editField("Adresse", text: $draft.address, placeholder: "Optionnel")
                }
                CardRow(showSeparator: true) {
                    editField("Code postal", text: $draft.postalCode, placeholder: "Optionnel")
                        .keyboardType(.numberPad)
                }
                CardRow(showSeparator: isAgency ? false : true) {
                    editField("Ville", text: $draft.city, placeholder: "Optionnel")
                }
                if !isAgency {
                    CardRow(showSeparator: false) {
                        editField("Commission (%)", text: $draft.commissionRate, placeholder: "20 par défaut")
                            .keyboardType(.decimalPad)
                    }
                }
            }
        }
    }

    private var mandatoryHint: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.bhOr)
            Text(draft.clientType == "business"
                 ? "La raison sociale est obligatoire."
                 : "Le prénom et le nom sont obligatoires.")
                .font(.system(size: 13))
                .foregroundStyle(Color.bhAttenue)
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Barre suppression

    private var deleteBar: some View {
        VStack(spacing: 0) {
            Button {
                if !vm.associatedProperties.isEmpty {
                    showDeleteWithProps = true
                } else {
                    showDeleteConfirm = true
                }
            } label: {
                Group {
                    if vm.actionState == .running {
                        ProgressView().tint(Color.bhTerracotta).scaleEffect(0.85)
                    } else {
                        Text("Supprimer ce client")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.bhTerracotta)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .disabled(vm.actionState == .running)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Actions

    private func save() async {
        guard draft.isFormValid else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await vm.update(body: draft.toBody())
            onChanged?()
            isEditing = false
        } catch {
            saveError = (error as? APIError)?.userMessage ?? "Une erreur est survenue."
        }
    }

    private func doDelete() async {
        let ok = await vm.delete()
        if ok {
            onChanged?()
            dismiss()
        } else if case .error(let msg) = vm.actionState {
            actionError = msg
            vm.actionState = .idle
        }
    }

    // MARK: - Composants

    private func readRow(_ label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 14.5))
                .foregroundStyle(Color.bhAttenue)
            Spacer(minLength: 8)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 14.5))
                .foregroundStyle(Color.bhEncre)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private func editField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
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

    // MARK: - État erreur

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
        .padding(.horizontal, 32)
    }
}

// MARK: - Feuille d'assignation de logements

private struct PropertyAssignmentSheet: View {
    let client: OwnerClient
    let allProperties: [Property]
    let allClients: [OwnerClient]
    let initialSelectedIds: Set<String>
    let onSave: (Set<String>) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIds: Set<String>
    @State private var isSaving = false
    @State private var error: String?
    @State private var pendingReassignProps: [Property] = []
    @State private var showReassignConfirm = false

    init(
        client: OwnerClient,
        allProperties: [Property],
        allClients: [OwnerClient],
        initialSelectedIds: Set<String>,
        onSave: @escaping (Set<String>) async throws -> Void
    ) {
        self.client             = client
        self.allProperties      = allProperties
        self.allClients         = allClients
        self.initialSelectedIds = initialSelectedIds
        self.onSave             = onSave
        _selectedIds = State(initialValue: initialSelectedIds)
    }

    private var sorted: [Property] {
        allProperties.sorted { ($0.internalName ?? $0.name) < ($1.internalName ?? $1.name) }
    }

    private func ownerName(for ownerId: String?) -> String? {
        guard let oid = ownerId, !oid.isEmpty else { return nil }
        return allClients.first { $0.matchingId == oid }?.displayName
    }

    private func isTakenByOther(_ prop: Property) -> Bool {
        guard let oid = prop.ownerId, !oid.isEmpty else { return false }
        return oid != client.matchingId
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                if allProperties.isEmpty {
                    emptyView
                } else {
                    propertiesList
                }
            }
        }
        .alert("Erreur", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
        .alert("Réassigner ces logements ?", isPresented: $showReassignConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Confirmer", role: .destructive) { Task { await doSave() } }
        } message: {
            let names = pendingReassignProps
                .map { $0.internalName ?? $0.name }
                .joined(separator: ", ")
            Text("Ces logements sont déjà attribués à un autre propriétaire : \(names). Les réattribuer à \(client.displayName) retirera leur propriétaire actuel.")
        }
    }

    private var navBar: some View {
        ZStack {
            Text("Logements associés")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.bhEncre)
            HStack {
                Button("Annuler") { dismiss() }
                    .font(.system(size: 16))
                    .foregroundStyle(Color.bhAttenue)
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                Spacer()
                if isSaving {
                    ProgressView().tint(Color.bhAttenue)
                } else {
                    Button("Enregistrer") { Task { await requestSave() } }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                        .buttonStyle(.plain)
                }
            }
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

    private var propertiesList: some View {
        ScrollView(showsIndicators: false) {
            ListCard {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, prop in
                    CardRow(showSeparator: idx < sorted.count - 1) {
                        propertyRow(prop)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }

    private func propertyRow(_ prop: Property) -> some View {
        let isSelected = selectedIds.contains(prop.id)
        let taken      = isTakenByOther(prop)
        let ownerLabel = taken ? ownerName(for: prop.ownerId) : nil
        return Button {
            if isSelected { selectedIds.remove(prop.id) }
            else          { selectedIds.insert(prop.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.bhVert : Color.bhAttenue.opacity(0.4))
                VStack(alignment: .leading, spacing: 3) {
                    Text(prop.internalName ?? prop.name)
                        .font(.system(size: 14.5))
                        .foregroundStyle(Color.bhEncre)
                        .lineLimit(1)
                    if let name = ownerLabel {
                        Text("Propriétaire actuel : \(name)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.bhOr)
                            .lineLimit(1)
                    } else if taken {
                        Text("Attribué à un autre propriétaire")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.bhOr)
                    }
                }
                Spacer(minLength: 4)
            }
        }
        .buttonStyle(.plain)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 60)
            Text("Aucun logement disponible")
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func requestSave() async {
        let newlyAdded = selectedIds.subtracting(initialSelectedIds)
        let reassigns  = sorted.filter { newlyAdded.contains($0.id) && isTakenByOther($0) }
        if !reassigns.isEmpty {
            pendingReassignProps = reassigns
            showReassignConfirm  = true
        } else {
            await doSave()
        }
    }

    private func doSave() async {
        isSaving = true
        do {
            try await onSave(selectedIds)
            dismiss()
        } catch {
            self.error = (error as? APIError)?.userMessage ?? "Une erreur est survenue."
        }
        isSaving = false
    }
}
