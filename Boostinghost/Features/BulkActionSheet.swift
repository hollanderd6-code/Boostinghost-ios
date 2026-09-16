import SwiftUI

private let bulkCal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

// 0=Lun … 6=Dim; maps to Gregorian weekday values (1=Sun, 2=Mon…)
private let dayLabels   = ["L", "M", "M", "J", "V", "S", "D"]
private let dayWeekdays = [2, 3, 4, 5, 6, 7, 1]

// MARK: - Sheet

struct BulkActionSheet: View {
    let vm: CalendarViewModel
    @Environment(\.dismiss) private var dismiss

    private enum BulkAction: Hashable { case block, price, minStay }

    @State private var selectedPropIds: Set<String>
    @State private var startDate:  Date
    @State private var endDate:    Date

    @State private var useDayFilter = false
    @State private var enabledDays: Set<Int> = [0, 1, 2, 3, 4, 5, 6]

    @State private var action:       BulkAction = .price
    @State private var blockReason   = ""
    @State private var priceText     = ""
    @State private var clearPrice    = false
    @State private var minNights     = 2

    @State private var isLoading   = false
    @State private var progress:   Double = 0
    @State private var isDone      = false
    @State private var failedCount = 0
    @State private var error:      String?

    init(vm: CalendarViewModel) {
        self.vm = vm
        _selectedPropIds = State(initialValue: Set(vm.properties.map(\.id)))
        let today = bulkCal.startOfDay(for: Date())
        _startDate = State(initialValue: today)
        _endDate   = State(initialValue: bulkCal.date(byAdding: .day, value: 6, to: today) ?? today)
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            Group {
                if isDone { doneView } else { mainForm }
            }
            .navigationTitle("Modification en masse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.disabled(isLoading)
                }
            }
            .overlay { if isLoading { loadingOverlay } }
        }
        .presentationDragIndicator(.visible)
        .alert("Erreur", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    // MARK: Main form

    private var mainForm: some View {
        Form {
            Section {
                Button {
                    if allSelected { selectedPropIds.removeAll() }
                    else { selectedPropIds = Set(vm.properties.map(\.id)) }
                } label: {
                    Label(
                        allSelected ? "Tout désélectionner" : "Tout sélectionner",
                        systemImage: allSelected ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundStyle(Color.bhVert)
                }
                ForEach(vm.properties) { prop in
                    Toggle(prop.displayName, isOn: propBinding(prop.id))
                }
            } header: {
                Text("Logements (\(selectedPropIds.count)/\(vm.properties.count))")
            }

            Section("Période") {
                DatePicker("Début", selection: $startDate, displayedComponents: .date)
                DatePicker("Fin",   selection: $endDate,   displayedComponents: .date)
                    .onChange(of: startDate) { _, new in
                        if endDate < new { endDate = new }
                    }
                LabeledContent("Nuits") {
                    Text("\(nightCount)").foregroundStyle(Color.bhEncre)
                }
            }

            if action == .price {
                Section {
                    Toggle("Filtrer par jour de la semaine", isOn: $useDayFilter)
                    if useDayFilter { dayChipsRow }
                }
            }

            Section {
                Picker("", selection: $action) {
                    Text("Bloquer").tag(BulkAction.block)
                    Text("Prix").tag(BulkAction.price)
                    Text("Nuit min.").tag(BulkAction.minStay)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 4)
            }

            switch action {
            case .block:   blockFields
            case .price:   priceFields
            case .minStay: minStayFields
            }
        }
    }

    // MARK: Day chips

    @ViewBuilder
    private var dayChipsRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let on = enabledDays.contains(i)
                Text(dayLabels[i])
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .foregroundStyle(on ? Color.white : Color.bhEncre)
                    .background(on ? Color.bhVert : Color.bhEncre.opacity(0.08), in: Circle())
                    .onTapGesture {
                        if on { enabledDays.remove(i) } else { enabledDays.insert(i) }
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    // MARK: Block fields

    @ViewBuilder
    private var blockFields: some View {
        Section("Motif (facultatif)") {
            TextField("Travaux, usage personnel…", text: $blockReason)
        }
        let n = selectedPropIds.count
        Section {
            Button { Task { await performBlock() } } label: {
                Text("Bloquer sur \(n) logement\(n > 1 ? "s" : "")")
                    .bold().frame(maxWidth: .infinity)
            }
            .foregroundStyle(Color.bhVert)
            .disabled(selectedPropIds.isEmpty)
        }
    }

    // MARK: Price fields

    @ViewBuilder
    private var priceFields: some View {
        Section {
            HStack {
                TextField("Prix / nuit", text: $priceText)
                    .keyboardType(.decimalPad)
                    .disabled(clearPrice)
                Text("€").foregroundStyle(Color.bhAttenue)
            }
            Toggle("Revenir au prix calculé", isOn: $clearPrice)
                .onChange(of: clearPrice) { _, on in if on { priceText = "" } }
        }
        let nights = matchingNights
        let n      = selectedPropIds.count
        Section {
            Button { Task { await performPrice() } } label: {
                Text("Appliquer : \(nights.count) nuit\(nights.count > 1 ? "s" : "") × \(n) logement\(n > 1 ? "s" : "")")
                    .bold().frame(maxWidth: .infinity)
            }
            .foregroundStyle(Color.bhVert)
            .disabled(selectedPropIds.isEmpty || nights.isEmpty || (!clearPrice && priceText.isEmpty))
        }
    }

    // MARK: Min stay fields

    @ViewBuilder
    private var minStayFields: some View {
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
        let n = selectedPropIds.count
        Section {
            Button { Task { await performMinStay() } } label: {
                Text("Appliquer sur \(n) logement\(n > 1 ? "s" : "")")
                    .bold().frame(maxWidth: .infinity)
            }
            .foregroundStyle(Color.bhVert)
            .disabled(selectedPropIds.isEmpty)
        }
    }

    // MARK: Loading overlay

    @ViewBuilder
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.08).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView(value: progress)
                    .tint(Color.bhVert)
                    .padding(.horizontal, 40)
                Text("Application en cours… \(Int(progress * 100)) %")
                    .font(.subheadline)
                    .foregroundStyle(Color.bhAttenue)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 48)
        }
    }

    // MARK: Done view

    @ViewBuilder
    private var doneView: some View {
        Form {
            if failedCount == 0 {
                Section {
                    Label(
                        action == .block ? "Blocages enregistrés." : "Modifications appliquées.",
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(Color.bhVert)
                }
            } else {
                Section {
                    Label(
                        "\(failedCount) opération\(failedCount > 1 ? "s" : "") ont échoué.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(Color.bhTerracotta)
                    .listRowBackground(Color.bhTerracottaFond)
                }
            }
            Section {
                Button("Fermer") { dismiss() }
                    .frame(maxWidth: .infinity).foregroundStyle(Color.bhVert)
            }
        }
    }

    // MARK: Helpers

    private var allSelected: Bool { selectedPropIds.count == vm.properties.count }

    private var nightCount: Int {
        max(0, bulkCal.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1
    }

    private var exclusiveEnd: Date {
        bulkCal.date(byAdding: .day, value: 1, to: endDate) ?? endDate
    }

    private var matchingNights: [Date] {
        var nights: [Date] = []
        var night = startDate
        while night <= endDate {
            if nightMatchesDayFilter(night) { nights.append(night) }
            guard let next = bulkCal.date(byAdding: .day, value: 1, to: night) else { break }
            night = next
        }
        return nights
    }

    private func nightMatchesDayFilter(_ night: Date) -> Bool {
        guard useDayFilter else { return true }
        let weekday = bulkCal.component(.weekday, from: night)
        guard let idx = dayWeekdays.firstIndex(of: weekday) else { return false }
        return enabledDays.contains(idx)
    }

    private func selectedProperties() -> [PropertySummary] {
        vm.properties.filter { selectedPropIds.contains($0.id) }
    }

    private func propBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { selectedPropIds.contains(id) },
            set: { if $0 { selectedPropIds.insert(id) } else { selectedPropIds.remove(id) } }
        )
    }

    // MARK: Network

    private func performBlock() async {
        let props = selectedProperties()
        guard !props.isEmpty else { return }
        isLoading = true
        progress  = 0
        var failed = 0
        for (i, prop) in props.enumerated() {
            do {
                try await vm.blockDates(
                    propertyId: prop.id,
                    start:      startDate,
                    end:        exclusiveEnd,
                    reason:     blockReason
                )
            } catch { failed += 1 }
            progress = Double(i + 1) / Double(props.count)
        }
        isLoading   = false
        failedCount = failed
        if failed == 0 { await vm.refreshCalendar() }
        isDone = true
    }

    private func performPrice() async {
        let nights = matchingNights
        let props  = selectedProperties()
        guard !nights.isEmpty, !props.isEmpty else { return }
        let price: Double? = clearPrice ? nil : Double(priceText.replacingOccurrences(of: ",", with: "."))
        guard clearPrice || price != nil else {
            error = "Entrez un prix valide."
            return
        }
        let total = nights.count * props.count
        isLoading = true
        progress  = 0
        var failed = 0
        var done   = 0
        for prop in props {
            for night in nights {
                do {
                    let body = PriceOverrideBody(
                        property_id: prop.id,
                        date:        CalendarViewModel.dayKey(for: night),
                        price:       price
                    )
                    try await APIClient.shared.postVoid(
                        Endpoint.pricingOverrides, body: body, agencyAll: true
                    )
                } catch { failed += 1 }
                done += 1
                progress = Double(done) / Double(total)
            }
        }
        isLoading   = false
        failedCount = failed
        if failed == 0 { await vm.refreshCalendar() }
        isDone = true
    }

    private func performMinStay() async {
        let props = selectedProperties()
        guard !props.isEmpty else { return }
        isLoading = true
        progress  = 0
        var failed = 0
        for (i, prop) in props.enumerated() {
            do {
                try await vm.createMinStayRule(
                    propertyId: prop.id,
                    minNights:  minNights,
                    start:      startDate,
                    end:        exclusiveEnd
                )
            } catch { failed += 1 }
            progress = Double(i + 1) / Double(props.count)
        }
        isLoading   = false
        failedCount = failed
        if failed == 0 { await vm.refreshCalendar() }
        isDone = true
    }
}
