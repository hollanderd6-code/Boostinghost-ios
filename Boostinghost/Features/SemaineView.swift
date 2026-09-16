import SwiftUI

// MARK: - Layout constants

private let swLabelW:     CGFloat = 76
private let swDayHeaderH: CGFloat = 44
private let swRowH:       CGFloat = CalBarLayout.rowH
private let swBarH:       CGFloat = CalBarLayout.barH
private let swBarRadius:  CGFloat = CalBarLayout.barR

// MARK: - File-scope formatters

private let swDayNumFmt: DateFormatter = {
    let f = DateFormatter()
    f.locale     = Locale(identifier: "fr_FR")
    f.dateFormat = "d"
    return f
}()

private let swWeekFmt: DateFormatter = {
    let f = DateFormatter()
    f.locale     = Locale(identifier: "fr_FR")
    f.dateFormat = "EEEEE"
    return f
}()

private let swUtcCal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

// MARK: - Design tokens

private let swRowSep  = Color(red: 20/255, green: 32/255, blue: 27/255).opacity(0.06)
private let swColSep  = Color(red: 20/255, green: 32/255, blue: 27/255).opacity(0.10)
private let swWeekend = Color(red: 201/255, green: 161/255, blue: 91/255).opacity(0.07)

// MARK: - Vue principale

struct SemaineView: View {
    var vm: CalendarViewModel

    @State private var selectedArrivee: Arrivee?

    var body: some View {
        VStack(spacing: 0) {
            switch vm.calendarState {
            case .idle, .loading:
                ProgressView()
                    .padding(.top, 80)
                    .tint(Color.bhVert)

            case .error(let msg):
                ContentUnavailableView(msg, systemImage: "wifi.exclamationmark")
                    .padding(.top, 60)

            case .loaded:
                SemaineGrid(vm: vm) { selectedArrivee = $0 }
            }

            Color.clear.frame(height: 80)
        }
        .padding(.top, 16)
        .sheet(item: $selectedArrivee) { ReservationDetailView(arrivee: $0) }
    }
}

// MARK: - Grille semaine

private struct SemaineGrid: View {
    var vm: CalendarViewModel
    let onTapEntry: (Arrivee) -> Void

    private var days: [Date] { vm.weekDays }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: swLabelW, height: swDayHeaderH)

                ForEach(days, id: \.self) { day in
                    SemDayHeader(date: day)
                }
            }
            .background(Color.white.opacity(0.28))
            .overlay(alignment: .bottom) {
                Rectangle().fill(swRowSep).frame(height: 0.5)
            }

            ForEach(vm.visibleProperties) { prop in
                SemPropertyRow(
                    property:    prop,
                    days:        days,
                    propData:    vm.calendarData?.properties?[prop.id],
                    holdEntries: vm.holdEntriesForProperty(prop.id, overlapping: days),
                    onTapEntry:  onTapEntry,
                    onTapHold:   { r in
                        onTapEntry(Arrivee(reservation: r, properties: vm.properties))
                    }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .background(alignment: .leading) {
            Rectangle()
                .fill(swRowSep)
                .frame(width: 0.5)
                .offset(x: swLabelW)
        }
    }
}

// MARK: - En-tête d'un jour

private struct SemDayHeader: View {
    let date: Date

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(swWeekFmt.string(from: date).uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isToday ? Color.bhVert : Color.bhAttenue)

            Text(swDayNumFmt.string(from: date))
                .font(.system(size: 13, weight: isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Color.bhVert : Color.bhEncre)
        }
        .frame(maxWidth: .infinity, minHeight: swDayHeaderH)
        .overlay(alignment: .bottom) {
            if isToday {
                Rectangle().fill(Color.bhVert).frame(height: 2)
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(swColSep).frame(width: 1.0)
        }
    }
}

// MARK: - Ligne de logement
//
// Même architecture ZStack que TimelineRow (Mensuel) :
//   1. HStack de fond — label + cellules (weekend, prix, séparateurs)
//   2. overlay GeometryReader — barres de réservation et de blocage
// La géométrie de chaque barre est calculée depuis les vraies dates (start/end),
// avec le même max/min que Mensuel pour clipper les débordements de semaine.

private struct SemPropertyRow: View {
    let property:    PropertySummary
    let days:        [Date]
    let propData:    PricingCalendarProperty?
    let holdEntries: [Reservation]
    let onTapEntry:  (Arrivee) -> Void
    let onTapHold:   (Reservation) -> Void

    @Environment(AuthStore.self) private var authStore
    private var canViewPricing: Bool { authStore.session?.can("can_view_pricing") ?? true }

    private var weekStart: Date { days.first ?? Date() }
    private var booked:  [PricingCalendarEntry] { propData?.booked  ?? [] }
    private var blocked: [PricingCalendarBlock]  { propData?.blocked ?? [] }

    var body: some View {
        HStack(spacing: 0) {
            Text(property.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bhEncre)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .padding(.leading, 12)
                .padding(.trailing, 6)
                .frame(width: swLabelW, height: swRowH, alignment: .leading)

            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                SemBgCell(
                    day:            day,
                    propData:       propData,
                    booked:         booked,
                    canViewPricing: canViewPricing
                )
            }
        }
        .overlay {
            GeometryReader { geo in
                let cellW = (geo.size.width - swLabelW) / CGFloat(days.count)

                ForEach(booked, id: \.id) { entry in
                    if let bg = barGeometry(entry: entry, cellW: cellW) {
                        SemEntryBar(entry: entry, width: bg.width) {
                            onTapEntry(Arrivee(calendarEntry: entry, property: property))
                        }
                        .offset(x: swLabelW + bg.x, y: CalBarLayout.swOverlayY)
                    }
                }

                ForEach(blocked, id: \.id) { block in
                    if let bg = blockGeo(block: block, cellW: cellW) {
                        SemHatchedBar(color: Color.platformBloque, leftCap: true, rightCap: true)
                            .frame(width: bg.width, height: swBarH)
                            .offset(x: swLabelW + bg.x, y: CalBarLayout.swOverlayY)
                    }
                }

                ForEach(holdEntries, id: \.id) { hold in
                    if let bg = holdBarGeo(reservation: hold, cellW: cellW) {
                        SemHoldBar(reservation: hold, width: bg.width) {
                            onTapHold(hold)
                        }
                        .offset(x: swLabelW + bg.x, y: CalBarLayout.swOverlayY)
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(swRowSep).frame(height: 0.5)
        }
    }

    private func barGeometry(
        entry: PricingCalendarEntry,
        cellW: CGFloat
    ) -> (x: CGFloat, width: CGFloat)? {
        guard let s = entry.startDate, let e = entry.endDate else { return nil }
        let totalW   = CGFloat(days.count) * cellW
        let startOff = swUtcCal.dateComponents([.day], from: weekStart, to: s).day ?? 0
        let endOff   = swUtcCal.dateComponents([.day], from: weekStart, to: e).day ?? 0
        let leftX    = max(0,      (CGFloat(startOff) + 0.5) * cellW)
        let rightX   = min(totalW, (CGFloat(endOff)   + 0.5) * cellW)
        guard rightX - leftX > 0.5 else { return nil }
        return (leftX, rightX - leftX)
    }

    private func blockGeo(
        block: PricingCalendarBlock,
        cellW: CGFloat
    ) -> (x: CGFloat, width: CGFloat)? {
        guard let s = block.startDate, let e = block.endDate else { return nil }
        let totalW   = CGFloat(days.count) * cellW
        let startOff = swUtcCal.dateComponents([.day], from: weekStart, to: s).day ?? 0
        let endOff   = swUtcCal.dateComponents([.day], from: weekStart, to: e).day ?? 0
        let leftX    = max(0,      (CGFloat(startOff) + 0.5) * cellW)
        let rightX   = min(totalW, (CGFloat(endOff)   + 0.5) * cellW)
        guard rightX - leftX > 0.5 else { return nil }
        return (leftX, rightX - leftX)
    }

    private func holdBarGeo(
        reservation: Reservation,
        cellW: CGFloat
    ) -> (x: CGFloat, width: CGFloat)? {
        guard let s = reservation.startDayDate, let e = reservation.endDayDate else { return nil }
        let totalW   = CGFloat(days.count) * cellW
        let startOff = swUtcCal.dateComponents([.day], from: weekStart, to: s).day ?? 0
        let endOff   = swUtcCal.dateComponents([.day], from: weekStart, to: e).day ?? 0
        let leftX    = max(0,      (CGFloat(startOff) + 0.5) * cellW)
        let rightX   = min(totalW, (CGFloat(endOff)   + 0.5) * cellW)
        guard rightX - leftX > 0.5 else { return nil }
        return (leftX, rightX - leftX)
    }
}

// MARK: - Cellule de fond (weekend + prix + séparateur)

private struct SemBgCell: View {
    let day:            Date
    let propData:       PricingCalendarProperty?
    let booked:         [PricingCalendarEntry]
    let canViewPricing: Bool

    private var dayKey: String { CalendarViewModel.dayKey(for: day) }

    private var isWeekend: Bool {
        let w = swUtcCal.component(.weekday, from: day)
        return w == 1 || w == 7
    }

    // Prix visible uniquement sur les jours entièrement libres (pas de checkin, pas de séjour en cours).
    // Sur un jour de départ, le prix s'affiche dans la moitié droite derrière la barre de départ.
    private var showPrice: Bool {
        guard canViewPricing else { return false }
        let occupied = booked.contains { $0.start <= dayKey && $0.end > dayKey }
        let checkin  = booked.contains { $0.start == dayKey }
        return !occupied && !checkin
    }

    var body: some View {
        ZStack {
            if showPrice, let p = propData?.price(for: dayKey, isWeekend: isWeekend) {
                Text("\(Int(p.rounded()))€")
                    .font(.system(size: CalBarLayout.priceSize, weight: .medium))
                    .foregroundStyle(Color.bhAttenue)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: swRowH)
        .background(isWeekend ? swWeekend : Color.clear)
        .overlay(alignment: .trailing) {
            Rectangle().fill(swColSep).frame(width: 1.0)
        }
    }
}

// MARK: - Barre de réservation

private struct SemEntryBar: View {
    let entry:  PricingCalendarEntry
    let width:  CGFloat
    let onTap:  () -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: swBarRadius, style: .continuous)
            .fill(entry.isBhGuest ? Color.bhTerracotta : Color.platform(entry.platform))
            .overlay(alignment: .leading) {
                HStack(spacing: 3) {
                    if entry.isBhGuest {
                        BhGuestChip()
                    } else {
                        PlatformMiniChip(platform: entry.platform)
                    }
                    if let name = entry.guest {
                        Text(name)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(width: width, height: swBarH)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
    }
}

// MARK: - Barre de hold en attente (opacité 0.50)

private struct SemHoldBar: View {
    let reservation: Reservation
    let width:       CGFloat
    let onTap:       () -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: swBarRadius, style: .continuous)
            .fill(Color.bhTerracotta)
            .overlay(alignment: .leading) {
                HStack(spacing: 3) {
                    BhGuestChip()
                    if let name = reservation.guestName {
                        Text(name)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(width: width, height: swBarH)
            .opacity(0.50)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
    }
}

// MARK: - Barre hachurée (blocages)

private struct SemHatchedBar: View {
    let color:    Color
    let leftCap:  Bool
    let rightCap: Bool

    private var topLeading:     CGFloat { leftCap  ? swBarRadius : 0 }
    private var bottomLeading:  CGFloat { leftCap  ? swBarRadius : 0 }
    private var topTrailing:    CGFloat { rightCap ? swBarRadius : 0 }
    private var bottomTrailing: CGFloat { rightCap ? swBarRadius : 0 }

    var body: some View {
        Canvas { ctx, size in
            let rect  = CGRect(origin: .zero, size: size)
            let shape = UnevenRoundedRectangle(
                topLeadingRadius:     topLeading,
                bottomLeadingRadius:  bottomLeading,
                bottomTrailingRadius: bottomTrailing,
                topTrailingRadius:    topTrailing,
                style: .continuous
            )
            let path  = shape.path(in: rect)
            ctx.clip(to: path)
            ctx.fill(path, with: .color(color.opacity(0.20)))

            let spacing: CGFloat = 4
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var stripe = Path()
                stripe.move(to:    CGPoint(x: x,               y: 0))
                stripe.addLine(to: CGPoint(x: x + size.height, y: size.height))
                ctx.stroke(stripe, with: .color(color.opacity(0.40)), lineWidth: 1.5)
                x += spacing
            }
        }
        .frame(maxWidth: .infinity)
    }
}
