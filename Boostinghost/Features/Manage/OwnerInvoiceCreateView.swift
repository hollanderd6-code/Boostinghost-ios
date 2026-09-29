import SwiftUI

struct OwnerInvoiceCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: OwnerInvoiceCreateViewModel
    @FocusState private var anyFieldFocused: Bool
    @State private var showAddItemSheet = false

    init(mode: OwnerInvoiceCreateViewModel.FormMode = .create) {
        _vm = State(initialValue: OwnerInvoiceCreateViewModel(mode: mode))
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                if vm.isEditMode {
                    editBody
                } else {
                    createBody
                }
            }
        }
        .task {
            if vm.isEditMode { await vm.loadDraft() }
            else             { await vm.loadClients() }
        }
        .onChange(of: vm.dateFrom)         { _, _ in if !vm.isEditMode { vm.resetSummary() } }
        .onChange(of: vm.dateTo)           { _, _ in if !vm.isEditMode { vm.resetSummary() } }
        .onChange(of: vm.createdInvoiceId) { _, newId in if newId != nil { dismiss() } }
        .onChange(of: vm.saveSucceeded)    { _, ok in if ok { dismiss() } }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { anyFieldFocused = false }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
            }
        }
        .confirmationDialog("Ajouter une ligne", isPresented: $showAddItemSheet) {
            Button("% Commission")         { vm.addManualItem(itemType: "commission") }
            Button("Ménage / Nettoyage")   { vm.addManualItem(itemType: "cleaning") }
            Button("Autre prestation")     { vm.addManualItem(itemType: "other") }
            Button("Annuler", role: .cancel) {}
        }
        .confirmationDialog("Réimporter les réservations ?", isPresented: $vm.showReimportConfirm) {
            Button("Réimporter") { Task { await vm.reimportReservations() } }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Toutes les lignes commission (importées et manuelles) seront remplacées par les réservations de la période sélectionnée. Les débours et autres prestations seront conservés.")
        }
    }

    // MARK: - NavBar

    private var navBar: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Button("Annuler") { dismiss() }
                .font(.system(size: 15))
                .foregroundStyle(Color.bhAttenue)
                .frame(width: 80, alignment: .leading)
            Spacer()
            Text(vm.isEditMode ? "Modifier le brouillon" : "Nouvelle facture")
                .bhGrandTitre()
            Spacer()
            Color.clear.frame(width: 80)
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

    // MARK: - Create body

    private var createBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                ownerSection
                if vm.selectedClient != nil {
                    periodSection
                    propertiesSection
                }
                if !vm.selectedPropertyIds.isEmpty {
                    importSection
                }
                if !vm.draftItems.isEmpty {
                    itemsSection
                }
                if !vm.includedItems.isEmpty {
                    vatSection
                    discountSection
                    notesSection
                    reviewSection
                    createSection
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 60)
        }
    }

    // MARK: - Edit body

    @ViewBuilder
    private var editBody: some View {
        switch vm.draftLoadState {
        case .loading:
            Spacer()
            ProgressView().tint(Color.bhAttenue)
            Spacer()
        case .error(let msg):
            Spacer(minLength: 40)
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28)).foregroundStyle(Color.bhAttenue)
            Text(msg)
                .font(.bhCorps).foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Réessayer") { Task { await vm.loadDraft() } }
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.bhVert)
            Spacer()
        case .idle, .loaded:
            editLoadedContent
        }
    }

    private var editLoadedContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                editHeaderSection
                editPeriodSection
                editReimportSection
                if !vm.draftItems.isEmpty {
                    itemsSection
                }
                if !vm.includedItems.isEmpty {
                    vatSection
                    discountSection
                    notesSection
                    reviewSection
                    saveSection
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 60)
        }
    }

    // MARK: - Edit header section (read-only)

    @ViewBuilder
    private var editHeaderSection: some View {
        if let info = vm.editInvoiceInfo {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Facture")
                ListCard {
                    if let name = info.clientName, !name.isEmpty {
                        CardRow(showSeparator: true) {
                            reviewRow("Propriétaire", value: name)
                        }
                    }
                    CardRow(showSeparator: info.periodStart != nil) {
                        reviewRow("Devise", value: vm.invoiceCurrency)
                    }
                    if let ps = info.periodStart {
                        let end = info.periodEnd.map { " → \(Formatters.day($0))" } ?? ""
                        CardRow(showSeparator: false) {
                            reviewRow("Période initiale", value: "\(Formatters.day(ps))\(end)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Edit period section

    private var editPeriodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Dates")
            ListCard {
                CardRow(showSeparator: true) {
                    DatePicker("Date d'émission", selection: $vm.issueDate, displayedComponents: .date)
                        .datePickerStyle(.compact).font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                }
                CardRow(showSeparator: true) {
                    DatePicker("Date d'échéance", selection: $vm.dueDate, displayedComponents: .date)
                        .datePickerStyle(.compact).font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                }
                CardRow(showSeparator: true) {
                    DatePicker("Début de période", selection: $vm.dateFrom, displayedComponents: .date)
                        .datePickerStyle(.compact).font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                }
                CardRow(showSeparator: false) {
                    DatePicker("Fin de période", selection: $vm.dateTo, displayedComponents: .date)
                        .datePickerStyle(.compact).font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                }
            }
            Text("Les prestations existantes ne sont pas recalculées automatiquement.")
                .font(.system(size: 12))
                .foregroundStyle(Color.bhAttenue)
                .padding(.leading, 4)
        }
    }

    // MARK: - Edit reimport section

    @ViewBuilder
    private var editReimportSection: some View {
        switch vm.importLoadState {
        case .loading:
            HStack(spacing: 10) {
                ProgressView().tint(Color.bhVert)
                Text("Réimport en cours…")
                    .font(.bhCorps).foregroundStyle(Color.bhAttenue)
            }.frame(maxWidth: .infinity)
        case .error(let msg):
            VStack(alignment: .leading, spacing: 8) {
                Text(msg).font(.bhCorps).foregroundStyle(Color.bhAttenue)
                reimportButton
            }
        default:
            reimportButton
        }
    }

    private var reimportButton: some View {
        Button { vm.showReimportConfirm = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise.circle")
                Text("Réimporter les réservations")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.bhVert)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.bhVert.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.bhVert.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Owner section

    private var ownerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Propriétaire")
            switch vm.clientsLoadState {
            case .loading:
                ProgressView().tint(Color.bhAttenue).frame(maxWidth: .infinity)
            case .error(let msg):
                Text(msg).font(.bhCorps).foregroundStyle(Color.bhAttenue)
            case .idle, .loaded:
                if vm.clients.isEmpty {
                    Text("Aucun propriétaire trouvé.")
                        .font(.bhCorps).foregroundStyle(Color.bhAttenue)
                } else {
                    ListCard {
                        ForEach(Array(vm.clients.enumerated()), id: \.element.id) { idx, client in
                            CardRow(showSeparator: idx < vm.clients.count - 1) {
                                ownerRow(client)
                            }
                        }
                    }
                }
            }
        }
    }

    private func ownerRow(_ client: OwnerClient) -> some View {
        Button { vm.selectClient(client) } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.bhVert.opacity(vm.selectedClient?.id == client.id ? 0.25 : 0.1))
                        .frame(width: 36, height: 36)
                    Text(client.initials)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                }
                Text(client.displayName)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.bhEncre)
                    .lineLimit(1)
                Spacer()
                if vm.selectedClient?.id == client.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.bhVert).font(.system(size: 18))
                }
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Period section

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Période")
            ListCard {
                CardRow(showSeparator: true) {
                    DatePicker("Du", selection: $vm.dateFrom, displayedComponents: .date)
                        .datePickerStyle(.compact).font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                }
                CardRow(showSeparator: true) {
                    DatePicker("Au", selection: $vm.dateTo, displayedComponents: .date)
                        .datePickerStyle(.compact).font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                }
                CardRow(showSeparator: true) {
                    DatePicker("Date d'émission", selection: $vm.issueDate, displayedComponents: .date)
                        .datePickerStyle(.compact).font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                }
                CardRow(showSeparator: false) {
                    DatePicker("Date d'échéance", selection: $vm.dueDate, displayedComponents: .date)
                        .datePickerStyle(.compact).font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                }
            }
        }
    }

    // MARK: - Properties section

    @ViewBuilder
    private var propertiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Logements")
            switch vm.propertiesLoadState {
            case .loading:
                ProgressView().tint(Color.bhAttenue).frame(maxWidth: .infinity)
            case .error(let msg):
                Text(msg).font(.bhCorps).foregroundStyle(Color.bhAttenue)
            case .idle, .loaded:
                if vm.ownerProperties.isEmpty {
                    Text("Aucun logement associé à ce propriétaire.")
                        .font(.bhCorps).foregroundStyle(Color.bhAttenue)
                } else {
                    ListCard {
                        ForEach(Array(vm.ownerProperties.enumerated()), id: \.element.id) { idx, prop in
                            CardRow(showSeparator: idx < vm.ownerProperties.count - 1) {
                                propertyRow(prop)
                            }
                        }
                    }
                    if let cur = vm.selectedCurrency {
                        Text("Devise : \(cur)")
                            .font(.system(size: 12)).foregroundStyle(Color.bhAttenue).padding(.leading, 4)
                    }
                }
            }
        }
    }

    private func propertyRow(_ property: Property) -> some View {
        let isSelected   = vm.selectedPropertyIds.contains(property.id)
        let isCompatible = vm.isCurrencyCompatible(property)
        return Button {
            if isCompatible { vm.toggleProperty(property) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.square.fill" : (isCompatible ? "square" : "square.slash"))
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.bhVert : (isCompatible ? Color.bhAttenue : Color.bhAttenue.opacity(0.35)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(property.internalName ?? property.name)
                        .font(.system(size: 15))
                        .foregroundStyle(isCompatible ? Color.bhEncre : Color.bhAttenue.opacity(0.5))
                        .lineLimit(1)
                    if let cur = property.currency {
                        currencyBadge(cur)
                    } else {
                        Text("Devise à configurer")
                            .font(.system(size: 11)).foregroundStyle(Color.bhAttenue.opacity(0.6))
                    }
                }
                Spacer()
                if !isCompatible && property.currency != nil {
                    Text("Devise différente")
                        .font(.system(size: 11)).foregroundStyle(Color.bhAttenue.opacity(0.55))
                }
            }
            .frame(minHeight: 44).opacity(isCompatible ? 1.0 : 0.55)
        }
        .buttonStyle(.plain).disabled(!isCompatible)
    }

    // MARK: - Import section

    @ViewBuilder
    private var importSection: some View {
        switch vm.importLoadState {
        case .loading:
            HStack(spacing: 10) {
                ProgressView().tint(Color.bhVert)
                Text("Chargement des réservations…")
                    .font(.bhCorps).foregroundStyle(Color.bhAttenue)
            }.frame(maxWidth: .infinity)
        case .error(let msg):
            VStack(alignment: .leading, spacing: 8) {
                Text(msg).font(.bhCorps).foregroundStyle(Color.bhAttenue)
                importButton
            }
        default:
            importButton
        }
    }

    private var importButton: some View {
        Button { Task { await vm.importReservations() } } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle")
                Text("Importer les réservations")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.bhVert, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Items section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("Prestations")
                Spacer()
                Button { showAddItemSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                        Text("Ajouter")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
                }
                .buttonStyle(.plain)
            }

            let included = vm.draftItems.filter { $0.isIncluded }
            if !included.isEmpty {
                ListCard {
                    ForEach(Array(included.enumerated()), id: \.element.id) { idx, item in
                        CardRow(showSeparator: idx < included.count - 1) {
                            itemRow(item)
                        }
                    }
                }
            }

            let incompatible = vm.incompatibleItems
            if !incompatible.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Réservations historiques — devise différente")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.bhAttenue)
                        .padding(.leading, 4)
                    ListCard {
                        ForEach(Array(incompatible.enumerated()), id: \.element.id) { idx, item in
                            CardRow(showSeparator: idx < incompatible.count - 1) {
                                historicalItemRow(item)
                            }
                        }
                    }
                }
            }
        }
    }

    private func itemRow(_ item: OwnerInvoiceDraftItem) -> some View {
        let knownTypes  = ["commission", "cleaning", "other"]
        let isDeletable = !item.isDebours && knownTypes.contains(item.itemType)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                typeBadge(item.itemType)
                currencyBadge(item.currency)
                if item.isDebours { dejoursBadge }
                Spacer()
                Text(Formatters.amount(item.lineTotal, currency: item.currency))
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.bhEncre)
                if isDeletable {
                    Button { vm.removeItem(id: item.id) } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13)).foregroundStyle(Color.bhAttenue.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }

            if item.isDebours {
                Text(item.description.isEmpty ? "—" : item.description)
                    .font(.system(size: 13)).foregroundStyle(Color.bhAttenue)
            } else {
                TextField("Description", text: Binding(
                    get: { item.description },
                    set: { vm.updateDescription(id: item.id, text: $0) }
                ))
                .font(.system(size: 13)).foregroundStyle(Color.bhEncre)
                .focused($anyFieldFocused)

                if item.itemType == "commission" {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Loyer (\(item.currency))")
                                .font(.system(size: 10)).foregroundStyle(Color.bhAttenue)
                            if item.isImported {
                                Text(Formatters.amount(item.rentalAmount, currency: item.currency))
                                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.bhEncre)
                            } else {
                                TextField("0", text: Binding(
                                    get: { item.rentalAmount == 0 ? "" : formatDecimal(item.rentalAmount) },
                                    set: { vm.updateRentalAmount(id: item.id, amount: parseDecimal($0)) }
                                ))
                                .keyboardType(.decimalPad).focused($anyFieldFocused)
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.bhEncre)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Taux (%)")
                                .font(.system(size: 10)).foregroundStyle(Color.bhAttenue)
                            TextField("20", text: Binding(
                                get: { formatDecimal(item.commissionRate) },
                                set: { vm.updateCommissionRate(id: item.id, rate: parseDecimal($0)) }
                            ))
                            .keyboardType(.decimalPad).focused($anyFieldFocused)
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.bhEncre)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quantité")
                                .font(.system(size: 10)).foregroundStyle(Color.bhAttenue)
                            TextField("1", text: Binding(
                                get: { formatDecimal(item.quantity) },
                                set: { vm.updateQuantity(id: item.id, qty: parseDecimal($0)) }
                            ))
                            .keyboardType(.decimalPad).focused($anyFieldFocused)
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.bhEncre)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Prix U. (\(item.currency))")
                                .font(.system(size: 10)).foregroundStyle(Color.bhAttenue)
                            TextField("0", text: Binding(
                                get: { item.unitPrice == 0 ? "" : formatDecimal(item.unitPrice) },
                                set: { vm.updateUnitPrice(id: item.id, price: parseDecimal($0)) }
                            ))
                            .keyboardType(.decimalPad).focused($anyFieldFocused)
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.bhEncre)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func historicalItemRow(_ item: OwnerInvoiceDraftItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13)).foregroundStyle(Color.bhOr)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.description)
                    .font(.system(size: 13)).foregroundStyle(Color.bhAttenue).lineLimit(1)
                Text("Devise historique \(item.currency) — facture séparée nécessaire")
                    .font(.system(size: 11)).foregroundStyle(Color.bhOr)
            }
            Spacer()
            Text(Formatters.amount(item.lineTotal, currency: item.currency))
                .font(.system(size: 13)).foregroundStyle(Color.bhAttenue)
        }
        .frame(minHeight: 44)
        .opacity(0.6)
    }

    // MARK: - VAT section

    private var vatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("TVA")
            ListCard {
                CardRow(showSeparator: vm.vatApplicable) {
                    Toggle("TVA applicable", isOn: $vm.vatApplicable)
                        .font(.system(size: 15)).tint(Color.bhVert)
                }
                if vm.vatApplicable {
                    CardRow(showSeparator: false) {
                        HStack {
                            Text("Taux TVA (%)")
                                .font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                            Spacer()
                            TextField("20", text: Binding(
                                get: { formatDecimal(vm.vatRate) },
                                set: { vm.vatRate = parseDecimal($0) }
                            ))
                            .keyboardType(.decimalPad).focused($anyFieldFocused)
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.bhEncre)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Discount section

    private var discountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Remise")
            ListCard {
                CardRow(showSeparator: vm.discountType != "none") {
                    Picker("Type", selection: $vm.discountType) {
                        Text("Aucune").tag("none")
                        Text("Pourcentage").tag("percent")
                        Text("Montant fixe").tag("fixed")
                    }
                    .font(.system(size: 15)).tint(Color.bhVert)
                }
                if vm.discountType != "none" {
                    CardRow(showSeparator: false) {
                        HStack {
                            Text(vm.discountType == "percent" ? "Remise (%)" : "Remise (\(vm.invoiceCurrency))")
                                .font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                            Spacer()
                            TextField("0", text: Binding(
                                get: { vm.discountValue == 0 ? "" : formatDecimal(vm.discountValue) },
                                set: { vm.discountValue = parseDecimal($0) }
                            ))
                            .keyboardType(.decimalPad).focused($anyFieldFocused)
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.bhEncre)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Notes section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Notes")
            ListCard {
                CardRow(showSeparator: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes client")
                            .font(.system(size: 11)).foregroundStyle(Color.bhAttenue)
                        TextField("Apparaissent sur le document", text: $vm.notes, axis: .vertical)
                            .font(.system(size: 14)).foregroundStyle(Color.bhEncre)
                            .lineLimit(3...6)
                            .focused($anyFieldFocused)
                    }
                }
                CardRow(showSeparator: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes internes")
                            .font(.system(size: 11)).foregroundStyle(Color.bhAttenue)
                        TextField("Usage interne uniquement", text: $vm.internalNotes, axis: .vertical)
                            .font(.system(size: 14)).foregroundStyle(Color.bhEncre)
                            .lineLimit(2...4)
                            .focused($anyFieldFocused)
                    }
                }
            }
        }
    }

    // MARK: - Review section

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Récapitulatif")
            ListCard {
                if let client = vm.selectedClient {
                    CardRow(showSeparator: true) {
                        reviewRow("Propriétaire", value: client.displayName)
                    }
                } else if let name = vm.editInvoiceInfo?.clientName, !name.isEmpty {
                    CardRow(showSeparator: true) {
                        reviewRow("Propriétaire", value: name)
                    }
                }
                CardRow(showSeparator: true) {
                    reviewRow("Devise", value: vm.invoiceCurrency)
                }
                CardRow(showSeparator: vm.discountType != "none" || vm.vatApplicable) {
                    reviewRow("Sous-total HT", value: Formatters.amount(vm.subtotalHt, currency: vm.invoiceCurrency))
                }
                if vm.discountType != "none" && vm.discountAmount > 0 {
                    let label = vm.discountType == "percent" ? "Remise \(Int(vm.discountValue))%" : "Remise"
                    CardRow(showSeparator: vm.vatApplicable) {
                        reviewRow(label, value: "− " + Formatters.amount(vm.discountAmount, currency: vm.invoiceCurrency))
                    }
                }
                if vm.vatApplicable {
                    CardRow(showSeparator: true) {
                        reviewRow("Net HT", value: Formatters.amount(vm.netHt, currency: vm.invoiceCurrency))
                    }
                    CardRow(showSeparator: true) {
                        reviewRow("TVA \(Int(vm.vatRate))%", value: Formatters.amount(vm.vatAmount, currency: vm.invoiceCurrency))
                    }
                }
                CardRow(showSeparator: false) {
                    HStack {
                        Text("Total TTC")
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(Color.bhEncre)
                        Spacer()
                        Text(Formatters.amount(vm.totalTtc, currency: vm.invoiceCurrency))
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(Color.bhVert)
                    }
                }
            }
        }
    }

    // MARK: - Create section

    @ViewBuilder
    private var createSection: some View {
        VStack(spacing: 12) {
            if let err = vm.createError {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .padding(.horizontal, 4)
            }
            Button {
                anyFieldFocused = false
                Task { await vm.createInvoice() }
            } label: {
                HStack(spacing: 8) {
                    if vm.isSubmitting {
                        ProgressView().tint(Color.white)
                    } else {
                        Image(systemName: "doc.badge.plus")
                    }
                    Text(vm.isSubmitting ? "Création en cours…" : "Créer le brouillon")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    vm.isReadyToCreate
                        ? Color.bhVert
                        : Color.bhAttenue.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(!vm.isReadyToCreate)

            if vm.hasCurrencyMismatch {
                Text("Certaines prestations ont une devise incompatible avec la facture.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bhOr)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Save section (edit mode)

    @ViewBuilder
    private var saveSection: some View {
        VStack(spacing: 12) {
            if let err = vm.saveError {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .padding(.horizontal, 4)
            }
            Button {
                anyFieldFocused = false
                Task { await vm.saveChanges() }
            } label: {
                HStack(spacing: 8) {
                    if vm.isSubmitting {
                        ProgressView().tint(Color.white)
                    } else {
                        Image(systemName: "checkmark.circle")
                    }
                    Text(vm.isSubmitting ? "Enregistrement…" : "Enregistrer les modifications")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    vm.isReadyToSave
                        ? Color.bhVert
                        : Color.bhAttenue.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(!vm.isReadyToSave)

            if vm.hasCurrencyMismatch {
                Text("Certaines prestations ont une devise incompatible avec la facture.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bhOr)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.bhAttenue)
            .padding(.leading, 4)
    }

    private func reviewRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 14)).foregroundStyle(Color.bhEncre)
            Spacer()
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.bhEncre)
        }
    }

    private func currencyBadge(_ currency: String) -> some View {
        Text(currency)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.bhVert)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.bhVert.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }

    private var dejoursBadge: some View {
        Text("débours")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.bhAttenue)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color.bhAttenue.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }

    private func typeBadge(_ itemType: String) -> some View {
        let label: String = {
            switch itemType {
            case "commission": return "COM"
            case "cleaning":   return "MÉN"
            default:           return "AUT"
            }
        }()
        return Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.bhAttenue)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color.bhAttenue.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Decimal helpers

    private func parseDecimal(_ s: String) -> Double {
        Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func formatDecimal(_ v: Double) -> String {
        String(format: "%g", v)
    }
}
