import SwiftUI

// MARK: - Free functions (nonisolated, testable)

func boostPriceAuthorityLabel(_ source: PricingSource?) -> String {
    switch source {
    case .manualOverride: return "Prix manuel"
    case .boostprice:     return "Prix BoostPrice"
    case .periodRule:     return "Règle de période"
    case .weekdayRule:    return "Règle hebdomadaire"
    case .weekendPrice:   return "Prix weekend"
    case .basePrice, .none, nil: return "Prix de base"
    case .unknown:        return "Prix calculé"
    }
}

func boostPriceDayDelta(effective: Double, scheduled: Double) -> Double {
    scheduled - effective
}

// MARK: - Cell tap context

enum CellTap: Identifiable {
    case free(property: PropertySummary, date: Date)
    case blocked(property: PropertySummary, reservation: Reservation)

    var id: String {
        switch self {
        case .free(let p, let d):    return "free-\(p.id)-\(CalendarViewModel.dayKey(for: d))"
        case .blocked(let p, let r): return "blocked-\(p.id)-\(r.id)"
        }
    }
}

// MARK: - Sheet

struct DayCellActionSheet: View {
    let tap: CellTap
    let vm:  CalendarViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var authStore

    private var canViewPricing:   Bool { authStore.session?.can("can_view_pricing")   ?? true }
    private var canManagePricing: Bool { authStore.session?.can("can_manage_pricing") ?? true }

    private var currencySymbol: String {
        Formatters.currencySymbol(for: vm.currency(forPropertyId: property.id))
    }

    private enum CellAction:    Hashable { case block, price }
    private enum PriceSubAction: Hashable { case tarif, nuitMin }

    @State private var selectedAction:  CellAction     = .block
    @State private var priceSubAction:  PriceSubAction = .tarif

    // Block
    @State private var blockStart: Date
    @State private var blockEnd:   Date
    @State private var blockReason = ""

    // Price (shared period)
    @State private var priceStart: Date
    @State private var priceEnd:   Date
    // Tarif
    @State private var priceText   = ""
    @State private var clearPrice  = false
    // Nuit min
    @State private var minNights   = 2

    @State private var isLoading = false
    @State private var error: String?
    @State private var showCreateReservation = false
    @State private var showBHGuestHold       = false
    @State private var showBoostPriceDetail  = false

    private enum ExplainState {
        case idle                        // not relevant — section hidden
        case loading
        case loaded(NightScheduleRow?)   // nil = no row for this date
        case failed
    }
    @State private var explainState: ExplainState = .idle

    // Orphaned state: unblock succeeded but the subsequent blockDates call failed.
    // The user must be told explicitly — dates are currently unblocked.
    private struct OrphanedBlock {
        let start:        Date
        let end:          Date
        let reason:       String
        let errorMessage: String
    }
    @State private var orphanedBlock: OrphanedBlock?

    private let initialDate: Date
    private let initialDatePlusOne: Date

    private var nightDayKey: String { CalendarViewModel.dayKey(for: initialDate) }

    private var initialDateIsWeekend: Bool {
        let w = vm.utcCal.component(.weekday, from: initialDate)
        return w == 1 || w == 7
    }

    private var property: PropertySummary {
        switch tap {
        case .free(let p, _):    return p
        case .blocked(let p, _): return p
        }
    }

    init(tap: CellTap, vm: CalendarViewModel) {
        self.tap = tap
        self.vm  = vm
        let date: Date
        switch tap {
        case .free(_, let d):
            date = d
        case .blocked(_, let r):
            date = r.startDayDate ?? Date()
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: date) ?? date
        initialDate        = date
        initialDatePlusOne = tomorrow
        _blockStart = State(initialValue: date)

        // For blocked cells initialise blockEnd from the reservation's actual end date.
        if case .blocked(_, let r) = tap, let end = r.endDayDate {
            _blockEnd = State(initialValue: end)
        } else {
            _blockEnd = State(initialValue: tomorrow)
        }

        // For blocked cells pre-fill reason if available.
        if case .blocked(_, let r) = tap, let notes = r.notes, !notes.isEmpty {
            _blockReason = State(initialValue: notes)
        }

        _priceStart = State(initialValue: date)
        _priceEnd   = State(initialValue: tomorrow)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch tap {
                case .free:
                    freeForm
                case .blocked(_, let r):
                    if let orphan = orphanedBlock {
                        orphanRecoveryForm(orphan: orphan)
                    } else {
                        blockedForm(reservation: r)
                    }
                }
            }
            .navigationTitle(property.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.disabled(isLoading)
                }
            }
            .overlay {
                if isLoading {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    ProgressView().tint(Color.bhVert)
                }
            }
            .navigationDestination(isPresented: $showCreateReservation) {
                CreateReservationView(
                    vm: vm,
                    property: property,
                    start: initialDate,
                    end: initialDatePlusOne,
                    onComplete: { dismiss() }
                )
            }
            .navigationDestination(isPresented: $showBHGuestHold) {
                BHGuestHoldView(
                    vm:         vm,
                    property:   property,
                    start:      initialDate,
                    end:        initialDatePlusOne,
                    onComplete: { dismiss() }
                )
            }
            .navigationDestination(isPresented: $showBoostPriceDetail) {
                BoostPriceDetailView(target: BoostPriceNavTarget(
                    propertyId:      property.id,
                    propertyName:    property.displayName,
                    externalPricing: false
                ))
            }
        }
        .presentationDragIndicator(.visible)
        .alert("Erreur", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    // MARK: Explainability load

    private func loadExplainability() async {
        guard case .free = tap, canViewPricing else { return }
        let propData = vm.calendarData?.properties?[property.id]
        guard bpExplainabilityRelevant(
            propData:        propData,
            dayKey:          nightDayKey,
            externalPricing: false
        ) else { return }

        explainState = .loading
        do {
            let resp: NightScheduleResponse = try await APIClient.shared.get(
                Endpoint.pricingSchedule(property.id),
                agencyAll: false,
                extraQueryItems: Endpoint.pricingScheduleQueryItems(from: nightDayKey, to: nightDayKey)
            )
            explainState = .loaded(resp.nights.first { $0.date == nightDayKey })
        } catch {
            explainState = .failed
        }
    }

    // MARK: Night price detail

    @ViewBuilder
    private var nightPriceSection: some View {
        if canViewPricing,
           let propData = vm.calendarData?.properties?[property.id],
           let price = propData.price(for: nightDayKey, isWeekend: initialDateIsWeekend) {
            let source    = propData.pricingSource(for: nightDayKey)
            let currency  = vm.currency(forPropertyId: property.id)
            let bpEnabled = propData.isBoostPriceEnabled
            let pending   = propData.boostPriceScheduleEntry(for: nightDayKey)

            Section(Formatters.day(initialDate).capitalized) {
                LabeledContent("Prix de la nuit") {
                    Text(Formatters.amount(price, currency: currency))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                }

                HStack(spacing: 4) {
                    if source == .manualOverride {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.bhEncre)
                    } else if source == .boostprice {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.bhOccupeFonce)
                    }
                    Text(boostPriceAuthorityLabel(source))
                        .font(.system(size: 13))
                        .foregroundStyle(source == .boostprice ? Color.bhOccupeFonce : Color.bhAttenue)
                }

                if let entry = pending, entry.status == .pending, entry.price > 0 {
                    LabeledContent("Recommandation") {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.bhOrClair)
                            Text(Formatters.amount(entry.price, currency: currency))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.bhOrClair)
                        }
                    }
                }

                if bpEnabled {
                    Button {
                        showBoostPriceDetail = true
                    } label: {
                        Label("Voir dans BoostPrice", systemImage: "bolt.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.bhVert)
                    }
                }
            }

            explainSection
        }
    }

    // MARK: Pourquoi ce prix ?

    @ViewBuilder
    private var explainSection: some View {
        switch explainState {
        case .idle:
            EmptyView()

        case .loading:
            Section {
                HStack {
                    Spacer()
                    ProgressView().tint(Color.bhVert)
                    Spacer()
                }
                .padding(.vertical, 4)
            } header: {
                Label("Pourquoi ce prix ?", systemImage: "bolt.fill")
                    .foregroundStyle(Color.bhOccupeFonce)
            }

        case .loaded(let row):
            Section {
                explainRows(for: row)
            } header: {
                Label("Pourquoi ce prix ?", systemImage: "bolt.fill")
                    .foregroundStyle(Color.bhOccupeFonce)
            }

        case .failed:
            Section {
                Button {
                    Task { await loadExplainability() }
                } label: {
                    Label("Réessayer", systemImage: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bhVert)
                }
            } header: {
                Label("Pourquoi ce prix ?", systemImage: "bolt.fill")
                    .foregroundStyle(Color.bhOccupeFonce)
            }
        }
    }

    @ViewBuilder
    private func explainRows(for row: NightScheduleRow?) -> some View {
        if let exp = row?.resolvedExplainability {
            let items = bpExplanationItems(from: exp, date: initialDate)
            if items.isEmpty {
                Text("Aucun facteur significatif pour cette nuit.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.bhAttenue)
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.icon)
                            .foregroundStyle(
                                item.impact == .positive ? Color.bhOccupeFonce
                                : item.impact == .negative ? Color.bhTerracotta
                                : Color.bhAttenue
                            )
                            .imageScale(.small)
                            .frame(width: 20)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.bhEncre)
                            if let detail = item.detail {
                                Text(detail)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.bhAttenue)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            }
        } else {
            Text("Le détail de ce calcul sera disponible après le prochain recalcul BoostPrice.")
                .font(.system(size: 13))
                .foregroundStyle(Color.bhAttenue)
        }
    }

    // MARK: Free cell form

    private var freeForm: some View {
        Form {
            nightPriceSection

            if canManagePricing {
                Section {
                    Picker("", selection: $selectedAction) {
                        Text("Bloquer").tag(CellAction.block)
                        Text("Prix").tag(CellAction.price)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 4)
                }
            }

            switch selectedAction {
            case .block: blockSection
            case .price:
                if canManagePricing { priceSection } else { blockSection }
            }

            Section {
                Button {
                    showCreateReservation = true
                } label: {
                    Label("Créer une réservation", systemImage: "calendar.badge.plus")
                        .foregroundStyle(Color.bhVert)
                }
                Button {
                    showBHGuestHold = true
                } label: {
                    Label("Lien BHGuest", systemImage: "link.badge.plus")
                        .foregroundStyle(Color.bhTerracotta)
                }
            }
        }
        .task { await loadExplainability() }
    }

    // MARK: Block

    @ViewBuilder
    private var blockSection: some View {
        Section("Période") {
            DatePicker("Début", selection: $blockStart, displayedComponents: .date)
            DatePicker("Fin",   selection: $blockEnd,   displayedComponents: .date)
                .onChange(of: blockStart) { _, new in
                    if blockEnd < new { blockEnd = new }
                }
        }
        Section("Motif (facultatif)") {
            TextField("Travaux, usage personnel…", text: $blockReason)
        }
        Section {
            Button {
                Task { await performBlock() }
            } label: {
                Text("Bloquer").bold().frame(maxWidth: .infinity)
            }
            .foregroundStyle(Color.bhVert)
        }
    }

    // MARK: Price

    @ViewBuilder
    private var priceSection: some View {
        Section {
            Picker("", selection: $priceSubAction) {
                Text("Tarif").tag(PriceSubAction.tarif)
                Text("Nuit min.").tag(PriceSubAction.nuitMin)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .padding(.vertical, 4)
        }

        Section("Période") {
            DatePicker("Début", selection: $priceStart, displayedComponents: .date)
            DatePicker("Fin",   selection: $priceEnd,   displayedComponents: .date)
                .onChange(of: priceStart) { _, new in
                    if priceEnd < new { priceEnd = new }
                }
        }

        switch priceSubAction {
        case .tarif:   tarifFields
        case .nuitMin: nuitMinFields
        }
    }

    @ViewBuilder
    private var tarifFields: some View {
        Section {
            HStack {
                TextField("Prix / nuit", text: $priceText)
                    .keyboardType(.decimalPad)
                    .disabled(clearPrice)
                Text(currencySymbol).foregroundStyle(Color.bhAttenue)
            }
            Toggle("Revenir au prix calculé", isOn: $clearPrice)
                .onChange(of: clearPrice) { _, on in
                    if on { priceText = "" }
                }
        }
        Section {
            Button {
                Task { await performPrice() }
            } label: {
                Text("Appliquer").bold().frame(maxWidth: .infinity)
            }
            .foregroundStyle(Color.bhVert)
            .disabled(!clearPrice && priceText.isEmpty)
        }
    }

    @ViewBuilder
    private var nuitMinFields: some View {
        Section {
            Stepper(value: $minNights, in: 1...30) {
                HStack {
                    Text("Minimum")
                    Spacer()
                    Text("\(minNights) \(minNights == 1 ? "nuit" : "nuits")")
                        .foregroundStyle(Color.bhAttenue)
                }
            }
        }
        Section {
            Label(
                "Sur Booking.com, vérifiez que la case Restrictions est cochée dans l'extranet pour que le minimum soit appliqué.",
                systemImage: "info.circle"
            )
            .font(.footnote)
            .foregroundStyle(Color.secondary)
            .listRowBackground(Color.clear)
        }
        Section {
            Button {
                Task { await performMinStay() }
            } label: {
                Text("Appliquer").bold().frame(maxWidth: .infinity)
            }
            .foregroundStyle(Color.bhVert)
        }
    }

    // MARK: Orphan recovery form
    // Shown when unblock succeeded but the subsequent blockDates call failed.

    @ViewBuilder
    private func orphanRecoveryForm(orphan: OrphanedBlock) -> some View {
        Form {
            Section {
                Label(
                    "Les dates ont été débloquées mais le nouveau blocage a échoué.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(Color.bhTerracotta)
                .listRowBackground(Color.bhTerracottaFond)
            } footer: {
                Text("Erreur : \(orphan.errorMessage)")
                    .foregroundStyle(Color.bhTerracotta)
            }

            Section("Plage à recréer") {
                LabeledContent("Début", value: Formatters.day(orphan.start))
                LabeledContent("Fin",   value: Formatters.day(
                    vm.utcCal.date(byAdding: .day, value: -1, to: orphan.end) ?? orphan.end
                ))
                if !orphan.reason.isEmpty {
                    LabeledContent("Motif", value: orphan.reason)
                }
            }

            Section {
                Button {
                    Task { await retryOrphanedBlock(orphan: orphan) }
                } label: {
                    Text("Réessayer le blocage")
                        .bold().frame(maxWidth: .infinity)
                }
                .foregroundStyle(Color.bhVert)
            }

            Section {
                Button(role: .destructive) { dismiss() } label: {
                    Text("Fermer sans bloquer")
                        .frame(maxWidth: .infinity)
                }
            } footer: {
                Text("Les dates sont actuellement débloquées et disponibles à la réservation.")
                    .foregroundStyle(Color.bhTerracotta)
            }
        }
    }

    // MARK: Blocked cell form
    // The backend has no PUT/PATCH for blocks — modify = delete + recreate.

    @ViewBuilder
    private func blockedForm(reservation: Reservation) -> some View {
        Form {
            Section("Période du blocage") {
                DatePicker("Début", selection: $blockStart, displayedComponents: .date)
                DatePicker("Fin",   selection: $blockEnd,   displayedComponents: .date)
                    .onChange(of: blockStart) { _, new in
                        if blockEnd < new { blockEnd = new }
                    }
            }

            Section("Motif (facultatif)") {
                TextField("Travaux, usage personnel…", text: $blockReason)
            }

            Section {
                Button {
                    Task { await performModifyBlock(uid: reservation.uid) }
                } label: {
                    Text("Enregistrer les modifications")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(Color.bhVert)
            } footer: {
                Text("Modifie la plage sans toucher aux réservations existantes.")
            }

            Section {
                Button(role: .destructive) {
                    Task { await performUnblock(uid: reservation.uid) }
                } label: {
                    Label("Débloquer ces dates", systemImage: "lock.open")
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Network

    private func performBlock() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await vm.blockDates(
                propertyId: property.id,
                start: blockStart,
                end: blockEnd,
                reason: blockReason
            )
            await vm.refreshCalendar()
            dismiss()
        } catch {
            self.error = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }

    private func performModifyBlock(uid: String?) async {
        guard let uid else {
            error = "Identifiant de blocage manquant."
            return
        }
        isLoading = true

        // Step 1 — delete the existing block.
        do {
            try await vm.unblock(uid)
        } catch {
            isLoading = false
            self.error = "Impossible de supprimer le blocage : \((error as? APIError)?.userMessage ?? error.localizedDescription)"
            return
        }

        // Step 2 — recreate with new dates/reason.
        // If this fails the dates are now unblocked — surface that explicitly.
        do {
            try await vm.blockDates(
                propertyId: property.id,
                start:      blockStart,
                end:        blockEnd,
                reason:     blockReason
            )
            isLoading = false
            await vm.refreshCalendar()
            dismiss()
        } catch {
            isLoading = false
            orphanedBlock = OrphanedBlock(
                start:        blockStart,
                end:          blockEnd,
                reason:       blockReason,
                errorMessage: (error as? APIError)?.userMessage ?? error.localizedDescription
            )
        }
    }

    private func retryOrphanedBlock(orphan: OrphanedBlock) async {
        isLoading = true
        do {
            try await vm.blockDates(
                propertyId: property.id,
                start:      orphan.start,
                end:        orphan.end,
                reason:     orphan.reason
            )
            orphanedBlock = nil
            isLoading = false
            await vm.refreshCalendar()
            dismiss()
        } catch {
            isLoading = false
            orphanedBlock = OrphanedBlock(
                start:        orphan.start,
                end:          orphan.end,
                reason:       orphan.reason,
                errorMessage: (error as? APIError)?.userMessage ?? error.localizedDescription
            )
        }
    }

    private func performPrice() async {
        isLoading = true
        defer { isLoading = false }
        let price: Double? = clearPrice ? nil : Double(priceText.replacingOccurrences(of: ",", with: "."))
        do {
            try await vm.setPrice(propertyId: property.id, start: priceStart, end: priceEnd, price: price)
            await vm.refreshCalendar()
            dismiss()
        } catch {
            self.error = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }

    private func performMinStay() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await vm.createMinStayRule(
                propertyId: property.id,
                minNights:  minNights,
                start:      priceStart,
                end:        priceEnd
            )
            await vm.refreshCalendar()
            dismiss()
        } catch {
            self.error = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }

    private func performUnblock(uid: String?) async {
        guard let uid else {
            error = "Identifiant de blocage manquant."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await vm.unblock(uid)
            await vm.refreshCalendar()
            dismiss()
        } catch {
            self.error = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }
}
