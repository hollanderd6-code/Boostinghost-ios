import SwiftUI

// MARK: - Grille du mois

struct MonthGridView: View {
    var vm: CalendarViewModel
    @State private var editingDay: Date? = nil   // nil = fermé, Date = PriceEditSheet ouverte

    private static let columns = Array(
        repeating: GridItem(.flexible(), spacing: 2), count: 7
    )

    private var selectedPropertyId: String? {
        if case .single(let id) = vm.displayMode { return id }
        return nil
    }

    var body: some View {
        VStack(spacing: 12) {
            gridCard
            if selectedPropertyId == nil, let day = vm.selectedDay {
                DayDetailCard(day: day, vm: vm)
                    .padding(.horizontal, 16)
            }
            BlockDateRow()
                .padding(.horizontal, 16)
        }
        .padding(.top, 16)
        .sheet(isPresented: Binding(
            get:  { editingDay != nil },
            set:  { if !$0 { editingDay = nil } }
        )) {
            if let day = editingDay, let propId = selectedPropertyId {
                PriceEditSheet(day: day, propertyId: propId, vm: vm)
            }
        }
    }

    // MARK: Carte grille

    private var gridCard: some View {
        VStack(spacing: 0) {
            weekHeader
            separator
            LazyVGrid(columns: Self.columns, spacing: 2) {
                // Cases vides avant le 1er du mois
                ForEach(0..<vm.firstWeekdayOffset, id: \.self) { _ in
                    Color.clear.frame(height: 56)
                }
                // Cases de chaque jour
                ForEach(1...max(1, vm.daysInMonth), id: \.self) { day in
                    let date = vm.dayDate(day)
                    DayCell(date: date, day: day, vm: vm)
                        .onTapGesture { handleTap(date: date) }
                }
            }
            .padding(8)
        }
        .background(GlassCardBackground(cornerRadius: 22))
        .padding(.horizontal, 16)
    }

    private let weekLetters = ["L","M","M","J","V","S","D"]

    private var weekHeader: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                Text(weekLetters[i])
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.bhAttenue)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.bhAttenue.opacity(0.20))
            .frame(height: 0.5)
            .padding(.horizontal, 8)
    }

    // MARK: Tap

    private func handleTap(date: Date) {
        if let propId = selectedPropertyId {
            // Mode logement : ouvre la feuille de prix
            // /api/host/pricing/* n'a pas de support agence — la feuille
            // n'est accessible que pour les logements du compte connecté.
            editingDay = date
        } else {
            // Mode grille : sélection / désélection du jour
            let key = CalendarViewModel.dayKey(for: date)
            if vm.selectedDayKey == key {
                vm.selectedDay = nil
            } else {
                vm.selectedDay = date
            }
        }
    }
}

// MARK: - Case de jour

private struct DayCell: View {
    let date: Date
    let day:  Int
    var vm: CalendarViewModel

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var isSelected: Bool {
        vm.selectedDayKey == CalendarViewModel.dayKey(for: date)
    }

    private var occupancy: Int     { vm.occupancy(for: date) }
    private var totalProps: Int    { vm.properties.count }
    private var rate: Double {
        totalProps > 0 ? Double(occupancy) / Double(totalProps) : 0
    }

    private var bgOpacity: Double  { 0.10 + rate * (0.26 - 0.10) }
    private var highOccupancy: Bool { rate > 0.80 }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(labelColor)

            subLabel
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(selectionRing)
    }

    @ViewBuilder
    private var subLabel: some View {
        switch vm.displayMode {
        case .allGrid, .allLines:
            if totalProps > 0 {
                Text("\(occupancy)/\(totalProps)")
                    .font(.system(size: 9.5))
                    .foregroundStyle(subLabelColor)
            }
        case .single:
            let key = CalendarViewModel.dayKey(for: date)
            if let price = vm.dayPrices[key] {
                Text("\(Int(price))€")
                    .font(.system(size: 9.5))
                    .foregroundStyle(subLabelColor)
            }
        }
    }

    private var labelColor: Color {
        if isToday { return .white }
        if highOccupancy { return Color.bhOccupeFonce }
        return Color.bhEncre
    }

    private var subLabelColor: Color {
        if isToday        { return .white.opacity(0.85) }
        if highOccupancy  { return Color.bhOccupeFonce }
        return Color.bhAttenue
    }

    @ViewBuilder
    private var background: some View {
        if isToday {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.bhVert)
        } else {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    Color(red: 46/255, green: 139/255, blue: 98/255)
                        .opacity(bgOpacity)
                )
        }
    }

    private var selectionRing: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(
                Color.bhVert.opacity(isSelected && !isToday ? 0.6 : 0),
                lineWidth: 1.5
            )
    }
}

// MARK: - Carte de détail du jour

struct DayDetailCard: View {
    let day: Date
    var vm: CalendarViewModel

    private var arrivals:   [Reservation] { vm.arrivals(on: day) }
    private var departures: [Reservation] { vm.departures(on: day) }
    // Simplified: ménage = departure (cleaning always follows a checkout)
    private var cleanings:  [Reservation] { departures }

    private var headerText: String {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        let dateStr  = f.string(from: day).uppercased()
        let occ      = vm.occupancy(for: day)
        let total    = vm.properties.count
        return "\(dateStr) · \(occ)/\(total) OCCUPÉS"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(headerText)
                .bhIntertitre()
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            thinDivider

            DayDetailRow(
                icon: "arrow.down.right.circle",
                color: Color.bhOccupe,
                label: "Arrivées",
                count: arrivals.count,
                timeHint: arrivalHint
            )

            thinDivider

            DayDetailRow(
                icon: "arrow.up.right.circle",
                color: Color.bhDepart,
                label: "Départs",
                count: departures.count,
                timeHint: departureHint
            )

            thinDivider

            DayDetailRow(
                icon: "sparkles",
                color: Color.bhOrClair,
                label: "Ménages",
                count: cleanings.count,
                timeHint: nil
            )
        }
        .background(GlassCardBackground(cornerRadius: 22))
    }

    private var thinDivider: some View {
        Rectangle()
            .fill(Color.bhAttenue.opacity(0.15))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    // Première heure d'arrivée connue parmi les logements attendus
    private var arrivalHint: String? {
        let ids = arrivals.map(\.propertyId)
        guard let t = vm.properties.first(where: { ids.contains($0.id) })?.arrivalTime,
              let formatted = Formatters.time(t) else { return nil }
        return "dès \(formatted)"
    }

    private var departureHint: String? {
        let ids = departures.map(\.propertyId)
        guard let t = vm.properties.first(where: { ids.contains($0.id) })?.departureTime,
              let formatted = Formatters.time(t) else { return nil }
        return "avant \(formatted)"
    }
}

private struct DayDetailRow: View {
    let icon:     String
    let color:    Color
    let label:    String
    let count:    Int
    let timeHint: String?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .imageScale(.medium)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                if let hint = timeHint {
                    Text(hint)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.bhAttenue)
                }
            }

            Spacer()

            Text("\(count)")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(count > 0 ? Color.bhEncre : Color.bhAttenue)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bhAttenue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Ligne « Bloquer des dates »

struct BlockDateRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "nosign")
                .foregroundStyle(Color.bhAttenue)
                .imageScale(.medium)
            Text("Bloquer des dates")
                .font(.system(size: 15))
                .foregroundStyle(Color.bhEncre)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bhAttenue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.60), lineWidth: 1)
        }
    }
}

// MARK: - Feuille de modification de prix

struct PriceEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let day:        Date
    let propertyId: String
    var vm:         CalendarViewModel

    @State private var priceText = ""
    @State private var saving    = false
    @State private var errorMsg: String?

    private var dayLabel: String { Formatters.day(day) }

    var body: some View {
        NavigationStack {
            Form {
                Section(dayLabel.capitalized) {
                    TextField("Prix de la nuit", text: $priceText)
                        .keyboardType(.decimalPad)
                }
                if let msg = errorMsg {
                    Section {
                        Text(msg).foregroundStyle(Color.bhTerracotta)
                    }
                }
            }
            .navigationTitle("Prix manuel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { Task { await save() } }
                        .disabled(saving || priceText.isEmpty)
                }
            }
        }
        .onAppear {
            let key = CalendarViewModel.dayKey(for: day)
            if let p = vm.dayPrices[key] { priceText = String(Int(p)) }
        }
    }

    private func save() async {
        let normalized = priceText.replacingOccurrences(of: ",", with: ".")
        guard let price = Double(normalized) else {
            errorMsg = "Prix invalide"
            return
        }
        saving = true
        do {
            try await vm.savePrice(price, for: day, propertyId: propertyId)
            dismiss()
        } catch {
            errorMsg = "Impossible d'enregistrer le prix"
            saving = false
        }
    }
}
