import SwiftUI

// MARK: - Liste des intervenants

struct CleanersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var authStore
    @State private var vm = CleanersViewModel()

    private var canWrite: Bool { authStore.session?.can("can_manage_cleaning") ?? false }

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
        .navigationDestination(for: CleanerItem.self) { cleaner in
            CleanerDetailView(cleaner: cleaner, listVM: vm)
        }
        .task { await vm.load() }
        .sheet(isPresented: $vm.showCreateSheet) {
            CleanerCreateSheet(vm: vm)
        }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        ZStack {
            VStack(spacing: 2) {
                Text(countLabel)
                    .font(.bhSurTitre)
                    .foregroundStyle(Color.bhAttenue)
                Text("Ménage")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
            }
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
                if canWrite {
                    Button { vm.showCreateSheet = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.bhVert)
                    }
                    .buttonStyle(.plain)
                }
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

    private var countLabel: String {
        guard case .loaded = vm.loadState else { return " " }
        let n = vm.cleaners.count
        return "\(n) intervenant\(n == 1 ? "" : "s")"
    }

    // MARK: - Contenu principal

    @ViewBuilder
    private var scrollContent: some View {
        switch vm.loadState {
        case .loading:
            Spacer()
            ProgressView().tint(Color.bhAttenue)
            Spacer()
        case .failed:
            Spacer()
            Text("Impossible de charger les intervenants.")
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        case .loaded:
            if vm.cleaners.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Text("Aucun intervenant enregistré.")
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                    if canWrite {
                        GlassButton(title: "Ajouter un intervenant", icon: "plus") {
                            vm.showCreateSheet = true
                        }
                    }
                }
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    cleanersList
                        .padding(.horizontal, 18)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Liste (une seule carte, CardRow > NavigationLink)
    // L'ordre CardRow-avant-NavigationLink est intentionnel : le séparateur du CardRow
    // reste à l'intérieur du clip de la carte et ne déborde pas sur les coins arrondis.

    private var cleanersList: some View {
        ListCard {
            ForEach(Array(vm.cleaners.enumerated()), id: \.element.id) { idx, cleaner in
                CardRow(showSeparator: idx < vm.cleaners.count - 1) {
                    NavigationLink(value: cleaner) {
                        cleanerRow(cleaner)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func cleanerRow(_ cleaner: CleanerItem) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#DCE8E1"))
                    .frame(width: 40, height: 40)
                let ini = cleaner.name.split(separator: " ").prefix(2)
                    .compactMap { $0.first.map(String.init) }.joined().uppercased()
                Text(ini.isEmpty ? "?" : ini)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(cleaner.name)
                        .font(.system(size: 15.5, weight: .medium))
                        .foregroundStyle(Color.bhEncre)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if !cleaner.isActive {
                        StatusPill(text: "inactif", style: .neutre)
                    }
                }
                if let sub = cleaner.phone ?? cleaner.email, !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color(hex: "#5E6B63"))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let count = vm.propertyCount(for: cleaner.id) {
                Text("\(count) logement\(count == 1 ? "" : "s")")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.bhAttenue)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bhAttenue.opacity(0.55))
        }
    }
}

// MARK: - Fiche intervenant (lecture + édition)

private struct CleanerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var authStore

    let listVM: CleanersViewModel
    @State private var cleaner: CleanerItem

    @State private var isEditing     = false
    @State private var isSaving      = false
    @State private var isTogglingSms = false

    // Champs d'édition — info
    @State private var editName     = ""
    @State private var editEmail    = ""
    @State private var editPhone    = ""
    @State private var editNotes    = ""
    @State private var editIsActive = true

    // Champs d'édition — logements
    @State private var editAssignments:   [String: Bool] = [:]
    @State private var initialAssignments:[String: Bool] = [:]

    // Alertes et erreurs
    @State private var showDeleteConfirm     = false
    @State private var showRegenerateConfirm = false
    @State private var actionError: String?  = nil

    private var canWrite: Bool { authStore.session?.can("can_manage_cleaning") ?? false }
    private var nameIsValid: Bool { !editName.trimmingCharacters(in: .whitespaces).isEmpty }

    init(cleaner: CleanerItem, listVM: CleanersViewModel) {
        self.listVM = listVM
        _cleaner    = State(initialValue: cleaner)
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                if let err = actionError, isEditing {
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
                        if isEditing { editContent } else { readContent }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .alert("Supprimer \(cleaner.name) ?", isPresented: $showDeleteConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer définitivement", role: .destructive) {
                Task { await doDelete() }
            }
        } message: {
            Text("Cette action est irréversible. Les assignations de ménage, les logements par défaut et les checklists de cet intervenant seront également supprimés.")
        }
        .alert("Régénérer le lien d'accès ?", isPresented: $showRegenerateConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Régénérer", role: .destructive) {
                Task { await doRegenerateLink() }
            }
        } message: {
            Text("L'ancien lien cessera de fonctionner immédiatement. L'intervenant devra utiliser le nouveau lien pour accéder à ses tâches.")
        }
        .alert("Erreur", isPresented: Binding(
            get: { actionError != nil && !isEditing },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK") { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        HStack {
            if isEditing {
                Button("Annuler") { cancelEdit() }
                    .font(.system(size: 16))
                    .foregroundStyle(Color.bhVert)
                    .buttonStyle(.plain)
                    .disabled(isSaving)
            } else {
                Button { dismiss() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Ménage")
                            .font(.system(size: 16.5, weight: .semibold))
                    }
                    .foregroundStyle(Color.bhVert)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text(isEditing ? "Modification" : cleaner.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.bhEncre)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Group {
                if isEditing {
                    if isSaving {
                        ProgressView().tint(Color.bhAttenue)
                    } else {
                        Button("Enregistrer") { Task { await saveEdit() } }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(nameIsValid ? Color.bhVert : Color.bhAttenue)
                            .buttonStyle(.plain)
                            .disabled(!nameIsValid)
                    }
                } else if canWrite {
                    Button("Modifier") { startEdit() }
                        .font(.system(size: 16))
                        .foregroundStyle(Color.bhVert)
                        .buttonStyle(.plain)
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

    // MARK: - Contenu lecture

    @ViewBuilder
    private var readContent: some View {
        cleanerHeader
        infoSection
        accessSection
        smsSection
        linkSection
        propertiesSection
        if canWrite { deleteButton }
    }

    private var cleanerHeader: some View {
        ListCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#DCE8E1"))
                        .frame(width: 52, height: 52)
                    Image(systemName: "person.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.bhVert)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(cleaner.name)
                            .font(.system(size: 18.5, weight: .semibold))
                            .foregroundStyle(Color.bhEncre)
                        if !cleaner.isActive { StatusPill(text: "inactif", style: .neutre) }
                    }
                    if let email = cleaner.email, !email.isEmpty {
                        Text(email).font(.bhMeta).foregroundStyle(Color.bhAttenue)
                    } else if let phone = cleaner.phone, !phone.isEmpty {
                        Text(phone).font(.bhMeta).foregroundStyle(Color.bhAttenue)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Informations")
            ListCard {
                CardRow(showSeparator: true)  { infoRow("Téléphone", cleaner.phone) }
                CardRow(showSeparator: true)  { infoRow("Email",     cleaner.email) }
                CardRow(showSeparator: false) { infoRow("Notes",     cleaner.notes) }
            }
        }
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(Color.bhEncre)
                .frame(width: 90, alignment: .leading)
            Text(value?.isEmpty == false ? value! : "—")
                .font(.system(size: 14.5))
                .foregroundStyle(value?.isEmpty == false ? Color.bhEncre : Color.bhAttenue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accessSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Code d'accès")
            ListCard {
                CardRow(showSeparator: false) {
                    HStack {
                        Text("Code PIN")
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundStyle(Color.bhEncre)
                            .frame(width: 90, alignment: .leading)
                        Text(cleaner.pinCode.isEmpty ? "—" : cleaner.pinCode)
                            .font(.system(size: 18, weight: .semibold).monospaced())
                            .foregroundStyle(Color.bhEncre)
                            .tracking(6)
                        Spacer()
                    }
                }
            }
            Text("Communiquez ce code à l'intervenant pour qu'il puisse accéder à son espace de travail.")
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
                .padding(.horizontal, 4)
        }
    }

    private var smsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Notifications")
            ListCard {
                CardRow(showSeparator: false) {
                    HStack {
                        Text("Récap par SMS")
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundStyle(Color.bhEncre)
                        Spacer()
                        if isTogglingSms {
                            ProgressView().tint(Color.bhAttenue).scaleEffect(0.8)
                        } else {
                            Toggle("", isOn: Binding(
                                get: { cleaner.smsRecapEnabled },
                                set: { _ in Task { await toggleSmsRecap() } }
                            ))
                            .labelsHidden()
                            .tint(Color.bhVert)
                            .disabled(!canWrite)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var linkSection: some View {
        if let url = listVM.accessURL(for: cleaner) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Lien d'accès")
                ListCard {
                    CardRow(showSeparator: canWrite) {
                        ShareLink(item: url) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.bhVert)
                                    .frame(width: 22)
                                Text("Partager le lien d'accès")
                                    .font(.system(size: 14.5, weight: .medium))
                                    .foregroundStyle(Color.bhVert)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    if canWrite {
                        CardRow(showSeparator: false) {
                            Button { showRegenerateConfirm = true } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.bhAttenue)
                                        .frame(width: 22)
                                    Text("Régénérer le lien")
                                        .font(.system(size: 14.5, weight: .medium))
                                        .foregroundStyle(Color.bhAttenue)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var propertiesSection: some View {
        let assigned = listVM.assignedProperties(for: cleaner.id)
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Logements associés")
            ListCard {
                if assigned.isEmpty {
                    CardRow(showSeparator: false) {
                        Text("Aucun logement associé")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.bhAttenue)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
                    }
                } else {
                    ForEach(Array(assigned.enumerated()), id: \.element.id) { idx, prop in
                        CardRow(showSeparator: idx < assigned.count - 1) {
                            Text(prop.internalName ?? prop.name)
                                .font(.system(size: 14.5))
                                .foregroundStyle(Color.bhEncre)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private var deleteButton: some View {
        Button { showDeleteConfirm = true } label: {
            ListCard {
                Text("Supprimer cet intervenant")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bhTerracotta)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Contenu édition

    @ViewBuilder
    private var editContent: some View {
        ListCard {
            CardRow(showSeparator: true) {
                editField("Nom",       text: $editName,  placeholder: "Obligatoire")
            }
            CardRow(showSeparator: true) {
                editField("Email",     text: $editEmail, placeholder: "Optionnel")
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
            CardRow(showSeparator: true) {
                editField("Téléphone", text: $editPhone, placeholder: "Optionnel")
                    .keyboardType(.phonePad)
            }
            CardRow(showSeparator: true) {
                editField("Notes",     text: $editNotes, placeholder: "Zone, remarques…")
            }
            CardRow(showSeparator: false) {
                Toggle(isOn: $editIsActive) {
                    Text("Actif")
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(Color.bhEncre)
                }
                .tint(Color.bhVert)
            }
        }
        editPropertiesSection
    }

    @ViewBuilder
    private func editField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(Color.bhEncre)
                .frame(width: 90, alignment: .leading)
            TextField(placeholder, text: text)
                .font(.system(size: 14.5))
                .foregroundStyle(Color.bhEncre)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
        }
    }

    // Section logements en mode édition : liste de tous les logements avec coche.
    // Cocher associe cet intervenant ; décocher retire. Si un logement est déjà
    // assigné à un AUTRE intervenant, cela est mentionné pour prévenir l'écrasement.
    @ViewBuilder
    private var editPropertiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Logements associés")
            if listVM.properties.isEmpty {
                ListCard {
                    CardRow(showSeparator: false) {
                        Text("Chargement des logements…")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.bhAttenue)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
                    }
                }
            } else {
                ListCard {
                    ForEach(Array(listVM.properties.enumerated()), id: \.element.id) { idx, prop in
                        CardRow(showSeparator: idx < listVM.properties.count - 1) {
                            propertyToggleRow(prop)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func propertyToggleRow(_ prop: Property) -> some View {
        let isChecked   = editAssignments[prop.id] == true
        let otherEntry  = listVM.defaultEntry(for: prop.id)
        let isOtherCleaner = !isChecked && otherEntry != nil && otherEntry?.cleanerId != cleaner.id

        Button {
            editAssignments[prop.id] = !isChecked
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isChecked ? Color.bhVert : Color.bhAttenue.opacity(0.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text(prop.internalName ?? prop.name)
                        .font(.system(size: 14.5))
                        .foregroundStyle(Color.bhEncre)
                        .lineLimit(1)
                    if isOtherCleaner, let name = otherEntry?.cleanerName, !name.isEmpty {
                        Text("assigné à \(name)")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color(hex: "#5E6B63"))
                    }
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func startEdit() {
        editName     = cleaner.name
        editEmail    = cleaner.email  ?? ""
        editPhone    = cleaner.phone  ?? ""
        editNotes    = cleaner.notes  ?? ""
        editIsActive = cleaner.isActive

        let currentIds = Set(listVM.defaultsByProperty
            .filter { $0.value.cleanerId == cleaner.id }
            .map { $0.key })
        let assignments = Dictionary(uniqueKeysWithValues:
            listVM.properties.map { ($0.id, currentIds.contains($0.id)) })
        editAssignments    = assignments
        initialAssignments = assignments

        isEditing = true
    }

    private func cancelEdit() {
        actionError = nil
        isEditing   = false
    }

    private func saveEdit() async {
        guard !isSaving, nameIsValid else { return }
        isSaving = true
        let name = editName.trimmingCharacters(in: .whitespaces)

        // 1 — informations de base
        do {
            try await listVM.update(
                id:       cleaner.id,
                name:     name,
                email:    editEmail.isEmpty ? nil : editEmail,
                phone:    editPhone.isEmpty ? nil : editPhone,
                notes:    editNotes.isEmpty ? nil : editNotes,
                isActive: editIsActive
            )
            cleaner.name     = name
            cleaner.email    = editEmail.isEmpty ? nil : editEmail
            cleaner.phone    = editPhone.isEmpty ? nil : editPhone
            cleaner.notes    = editNotes.isEmpty ? nil : editNotes
            cleaner.isActive = editIsActive
        } catch {
            actionError = cleanerAPIMessage(error)
            isSaving = false
            return
        }

        // 2 — associations de logements (uniquement celles qui ont changé)
        let changed = listVM.properties.filter {
            editAssignments[$0.id] != initialAssignments[$0.id]
        }
        if !changed.isEmpty {
            var failures: [String] = []
            for prop in changed {
                let shouldAssign = editAssignments[prop.id] == true
                do {
                    try await listVM.setDefaultCleaner(
                        propertyId: prop.id,
                        cleanerId:  shouldAssign ? cleaner.id : nil
                    )
                } catch {
                    let detail = cleanerAPIMessage(error)
                    failures.append("\(prop.internalName ?? prop.name) (\(detail))")
                }
            }
            if !failures.isEmpty {
                actionError = "Non enregistré pour : \(failures.joined(separator: " · "))"
            }
        }

        isEditing = false
        isSaving  = false
    }

    private func toggleSmsRecap() async {
        guard !isTogglingSms else { return }
        isTogglingSms = true
        let newValue = !cleaner.smsRecapEnabled
        cleaner.smsRecapEnabled = newValue
        do {
            try await listVM.toggleSms(id: cleaner.id, enabled: newValue)
        } catch CleanerError.smsOptionRequired {
            cleaner.smsRecapEnabled = !newValue
            actionError = "Le récap par SMS nécessite une option payante sur votre plan."
        } catch {
            cleaner.smsRecapEnabled = !newValue
            actionError = cleanerAPIMessage(error)
        }
        isTogglingSms = false
    }

    private func doRegenerateLink() async {
        do {
            cleaner.accessToken = try await listVM.regenerateLink(id: cleaner.id)
        } catch {
            actionError = cleanerAPIMessage(error)
        }
    }

    private func doDelete() async {
        do {
            try await listVM.delete(id: cleaner.id)
            dismiss()
        } catch {
            actionError = cleanerAPIMessage(error)
        }
    }
}

// MARK: - Feuille de création

private struct CleanerCreateSheet: View {
    let vm: CleanersViewModel
    @State private var name     = ""
    @State private var email    = ""
    @State private var phone    = ""
    @State private var notes    = ""
    @State private var isActive = true
    @State private var isSaving = false
    @State private var error: String?

    private var nameIsValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                createNavBar
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
                        formFields
                        PrimaryButton(title: "Ajouter") { Task { await save() } }
                            .disabled(!nameIsValid || isSaving)
                            .opacity(nameIsValid && !isSaving ? 1 : 0.5)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var createNavBar: some View {
        ZStack {
            Text("Nouvel intervenant")
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
        .padding(.vertical, 14)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    private var formFields: some View {
        ListCard {
            CardRow(showSeparator: true) { fieldRow("Nom",       text: $name,  placeholder: "Obligatoire") }
            CardRow(showSeparator: true) {
                fieldRow("Email", text: $email, placeholder: "Optionnel")
                    .keyboardType(.emailAddress).textInputAutocapitalization(.never)
            }
            CardRow(showSeparator: true) {
                fieldRow("Téléphone", text: $phone, placeholder: "Optionnel").keyboardType(.phonePad)
            }
            CardRow(showSeparator: true) { fieldRow("Notes", text: $notes, placeholder: "Zone, remarques…") }
            CardRow(showSeparator: false) {
                Toggle(isOn: $isActive) {
                    Text("Actif")
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(Color.bhEncre)
                }
                .tint(Color.bhVert)
            }
        }
    }

    @ViewBuilder
    private func fieldRow(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(Color.bhEncre)
                .frame(width: 90, alignment: .leading)
            TextField(placeholder, text: text)
                .font(.system(size: 14.5))
                .foregroundStyle(Color.bhEncre)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
        }
    }

    private func save() async {
        guard !isSaving, nameIsValid else { return }
        isSaving = true
        error    = nil
        do {
            _ = try await vm.create(
                name:     name.trimmingCharacters(in: .whitespaces),
                email:    email.isEmpty ? nil : email,
                phone:    phone.isEmpty ? nil : phone,
                notes:    notes.isEmpty ? nil : notes,
                isActive: isActive
            )
            vm.showCreateSheet = false
        } catch {
            self.error = cleanerAPIMessage(error)
        }
        isSaving = false
    }
}

// MARK: - Formatage des erreurs API

private func cleanerAPIMessage(_ error: Error) -> String {
    if let e = error as? APIError {
        switch e {
        case .server(_, let msg?): return msg
        case .network:             return "Connexion impossible. Vérifiez votre réseau."
        default:                   break
        }
    }
    return "Une erreur est survenue. Réessayez."
}
