import SwiftUI

// MARK: - File-scope formatters

private let jourDayNumFmt: DateFormatter = {
    let f = DateFormatter()
    f.locale     = Locale(identifier: "fr_FR")
    f.dateFormat = "d"
    return f
}()

private let jourWeekFmt: DateFormatter = {
    let f = DateFormatter()
    f.locale     = Locale(identifier: "fr_FR")
    f.dateFormat = "EEEEE"   // lettre unique
    return f
}()

private let jourHeaderFmt: DateFormatter = {
    let f = DateFormatter()
    f.locale     = Locale(identifier: "fr_FR")
    f.dateFormat = "EEEE d MMMM"
    return f
}()

// MARK: - Vue principale

struct JourView: View {
    var vm: CalendarViewModel

    var body: some View {
        VStack(spacing: 0) {
            JourDateStrip(vm: vm)

            switch vm.calendarState {
            case .idle, .loading:
                ProgressView()
                    .padding(.top, 80)
                    .tint(Color.bhVert)

            case .error(let msg):
                ContentUnavailableView(msg, systemImage: "wifi.exclamationmark")
                    .padding(.top, 60)

            case .loaded:
                JourContent(vm: vm)
            }

            Color.clear.frame(height: 80)
        }
        .padding(.top, 12)
    }
}

// MARK: - Bande de dates défilante

struct JourDateStrip: View {
    var vm: CalendarViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(0..<vm.daysInMonth, id: \.self) { offset in
                        let date       = vm.dateAtOffset(offset)
                        let key        = CalendarViewModel.dayKey(for: date)
                        let isSelected = vm.selectedDayKey == key
                        let isToday    = Calendar.current.isDateInToday(date)
                        JourDateChip(date: date, isSelected: isSelected, isToday: isToday)
                            .id(key)
                            .onTapGesture { vm.selectedDay = date }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color.white.opacity(0.20))
            .task {
                let key = CalendarViewModel.dayKey(for: vm.effectiveSelectedDay)
                try? await Task.sleep(for: .milliseconds(1))
                proxy.scrollTo(key, anchor: .center)
            }
            .onChange(of: vm.selectedMonthKey) { _, _ in
                let key = CalendarViewModel.dayKey(for: vm.effectiveSelectedDay)
                withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(key, anchor: .center) }
            }
            .onChange(of: vm.selectedDayKey) { _, new in
                withAnimation(.easeInOut(duration: 0.15)) { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }
}

// MARK: - Pastille de jour

struct JourDateChip: View {
    let date:       Date
    let isSelected: Bool
    let isToday:    Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(jourWeekFmt.string(from: date).uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(weekColor)
            Text(jourDayNumFmt.string(from: date))
                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                .foregroundStyle(dayColor)
        }
        .frame(width: 44, height: 58)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isToday ? Color.bhVert : Color.white.opacity(0.80))
                    .shadow(
                        color: Color(red: 20/255, green: 32/255, blue: 27/255).opacity(0.10),
                        radius: 4, x: 0, y: 2
                    )
            }
        }
    }

    private var dayColor: Color {
        if isSelected && isToday { return .white }
        if isSelected            { return Color.bhEncre }
        if isToday               { return Color.bhVert }
        return Color.bhEncre
    }

    private var weekColor: Color {
        if isSelected && isToday { return .white.opacity(0.80) }
        return Color.bhAttenue
    }
}

// MARK: - Contenu

private struct JourContent: View {
    var vm: CalendarViewModel

    @State private var selectedArrivee: Arrivee?

    private var day: Date { vm.effectiveSelectedDay }

    private var arrivals:     [(property: PropertySummary, entry: PricingCalendarEntry)] {
        vm.calendarArrivals(on: day)
    }
    private var departures:   [(property: PropertySummary, entry: PricingCalendarEntry)] {
        vm.calendarDepartures(on: day)
    }
    private var holdArrivals: [(property: PropertySummary, reservation: Reservation)] {
        vm.holdArrivals(on: day)
    }

    private var totalArrivals: Int { arrivals.count + holdArrivals.count }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            // Titre du jour
            Text(jourHeaderFmt.string(from: day).capitalized)
                .bhIntertitre()
                .padding(.horizontal, 20)
                .padding(.top, 16)

            // Compteurs
            HStack(spacing: 10) {
                JourCounter(
                    icon:  "arrow.down.right.circle.fill",
                    color: Color.bhOccupe,
                    count: totalArrivals,
                    label: "arrivée"
                )
                JourCounter(
                    icon:  "arrow.up.right.circle.fill",
                    color: Color.bhDepart,
                    count: departures.count,
                    label: "départ"
                )
            }
            .padding(.horizontal, 16)

            // Arrivées (confirmées + holds en attente)
            if totalArrivals > 0 {
                SectionLabel(text: "Arrivées")
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                ForEach(arrivals, id: \.entry.id) { item in
                    JourEntryCard(property: item.property, entry: item.entry, vm: vm, isArrival: true) {
                        selectedArrivee = Arrivee(calendarEntry: item.entry, property: item.property)
                    }
                    .padding(.horizontal, 16)
                }
                ForEach(holdArrivals, id: \.reservation.id) { item in
                    JourHoldCard(property: item.property, reservation: item.reservation) {
                        selectedArrivee = Arrivee(reservation: item.reservation, properties: vm.properties)
                    }
                    .padding(.horizontal, 16)
                }
            }

            // Départs
            if !departures.isEmpty {
                SectionLabel(text: "Départs")
                    .padding(.horizontal, 20)
                    .padding(.top, totalArrivals == 0 ? 4 : 16)
                ForEach(departures, id: \.entry.id) { item in
                    JourEntryCard(property: item.property, entry: item.entry, vm: vm, isArrival: false) {
                        selectedArrivee = Arrivee(calendarEntry: item.entry, property: item.property)
                    }
                    .padding(.horizontal, 16)
                }
            }

            if totalArrivals == 0 && departures.isEmpty {
                ContentUnavailableView(
                    "Aucun mouvement",
                    systemImage: "calendar.badge.checkmark",
                    description: Text("Pas d'arrivée ni de départ ce jour.")
                )
                .padding(.top, 40)
            }
        }
        .sheet(item: $selectedArrivee) { ReservationDetailView(arrivee: $0) }
    }
}

// MARK: - Carte de hold BHGuest en attente

private struct JourHoldCard: View {
    let property:    PropertySummary
    let reservation: Reservation
    let onTap:       () -> Void

    private var nights: Int {
        guard let s = reservation.startDayDate, let e = reservation.endDayDate else { return 0 }
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return max(0, c.dateComponents([.day], from: s, to: e).day ?? 0)
    }

    var body: some View {
        Button(action: onTap) {
            ListCard {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.bhTerracotta.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.bhTerracotta)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(reservation.guestName ?? "Voyageur")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.bhEncre)
                            .lineLimit(1)
                        Text("\(property.displayName) · \(nights) nuit\(nights > 1 ? "s" : "")")
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhAttenue)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text("En attente")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.bhTerracotta)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.bhTerracotta.opacity(0.12), in: Capsule())

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.bhAttenue)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .buttonStyle(.plain)
        .opacity(0.50)
    }
}

// MARK: - Compteur

private struct JourCounter: View {
    let icon:  String
    let color: Color
    let count: Int
    let label: String

    var body: some View {
        ListCard {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 24))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                    Text(count == 1 ? label : "\(label)s")
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Carte de séjour

private struct JourEntryCard: View {
    let property:  PropertySummary
    let entry:     PricingCalendarEntry
    var vm:        CalendarViewModel
    let isArrival: Bool
    let onTap:     () -> Void

    private var fullRes: Reservation? {
        guard let uid = entry.uid else { return nil }
        return vm.allReservations.first { $0.uid == uid }
    }

    private var guestCount: Int? {
        let a = fullRes?.occupancyAdults   ?? 0
        let c = fullRes?.occupancyChildren ?? 0
        let t = a + c
        return t > 0 ? t : nil
    }

    private var metaLabel: String {
        let n = entry.nights
        var parts: [String] = [
            property.displayName,
            "\(n) nuit\(n > 1 ? "s" : "")",
        ]
        if let g = guestCount {
            parts.append("\(g) voyageur\(g > 1 ? "s" : "")")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Button(action: onTap) {
        ListCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.platform(entry.isBhGuest ? "bhguest" : entry.platform).opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: isArrival ? "arrow.down.right" : "arrow.up.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.platform(entry.isBhGuest ? "bhguest" : entry.platform))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.guest ?? "Voyageur")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                        .lineLimit(1)
                    Text(metaLabel)
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.bhAttenue)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        }
        .buttonStyle(.plain)
    }
}
