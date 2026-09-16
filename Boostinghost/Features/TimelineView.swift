import SwiftUI

// MARK: - Layout constants (design tokens)

private let colWidth:   CGFloat = 64
private let rowHeight:  CGFloat = CalBarLayout.rowH
private let labelWidth: CGFloat = 88
private let dayHeaderH: CGFloat = 44
private let barHeight:  CGFloat = CalBarLayout.barH
private let barRadius:  CGFloat = CalBarLayout.barR

// MARK: - File-scope formatters and calendar
// Never re-instantiated inside View bodies — one allocation for the lifetime of the app.

private let tlDayFmt: DateFormatter = {
    let f = DateFormatter()
    f.locale     = Locale(identifier: "fr_FR")
    f.dateFormat = "d"
    return f
}()

private let tlWeekFmt: DateFormatter = {
    let f = DateFormatter()
    f.locale     = Locale(identifier: "fr_FR")
    f.dateFormat = "EEEEE"
    return f
}()

private let tlCal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

// MARK: - Design-token colors

// rgba(20,32,27,.07) — fond de mise en évidence (ligne ou colonne)
private let tlHighlight = Color(red: 20/255, green: 32/255, blue: 27/255).opacity(0.07)

// rgba(20,32,27,.10) — filet vertical entre colonnes de jour
private let tlColSep    = Color(red: 20/255, green: 32/255, blue: 27/255).opacity(0.10)
// rgba(20,32,27,.18) — filet vertical dim→lun (frontière de semaine, plus marqué)
private let tlWeekSep   = Color(red: 20/255, green: 32/255, blue: 27/255).opacity(0.18)
// rgba(20,32,27,.06) — filet horizontal entre lignes de logements
private let tlRowSep    = Color(red: 20/255, green: 32/255, blue: 27/255).opacity(0.06)
// rgba(201,161,91,.07) — fond weekend
private let tlWeekend   = Color(red: 201/255, green: 161/255, blue: 91/255).opacity(0.07)

// MARK: - Mise en évidence (ligne ou colonne, une seule à la fois)

private enum TimelineHighlight: Equatable {
    case none
    case row(String)   // propertyId
    case col(Int)      // offset depuis le 1er du mois
}

// MARK: - Vue principale

struct TimelineView: View {
    var vm: CalendarViewModel

    @State private var highlight:       TimelineHighlight = .none
    @State private var selectedArrivee: Arrivee?
    @State private var cellTap:         CellTap?

    private var visibleProperties: [PropertySummary] {
        switch vm.displayMode {
        case .allGrid, .allLines: return vm.properties
        case .single(let id):    return vm.properties.filter { $0.id == id }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                fixedLabelColumn
                scrollableContent
            }
            .padding(.top, 16)

            Color.clear.frame(height: 80)
        }
        .sheet(item: $selectedArrivee) { ReservationDetailView(arrivee: $0) }
        .sheet(item: $cellTap)         { DayCellActionSheet(tap: $0, vm: vm) }
    }

    // MARK: Colonne gauche fixe

    private var fixedLabelColumn: some View {
        VStack(spacing: 0) {
            Color.clear.frame(width: labelWidth, height: dayHeaderH)
            ForEach(visibleProperties) { prop in
                Text(prop.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 16)
                    .padding(.trailing, 6)
                    .frame(width: labelWidth, height: rowHeight, alignment: .leading)
                    .background { if highlight == .row(prop.id) { tlHighlight } }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        highlight = highlight == .row(prop.id) ? .none : .row(prop.id)
                    }
                    .overlay(alignment: .bottom) { thinSep }
            }
        }
        .frame(width: labelWidth)
        .background {
            HStack {
                Spacer()
                Rectangle()
                    .fill(tlRowSep)
                    .frame(width: 0.5)
            }
        }
        .background(Color.white.opacity(0.40))
    }

    // MARK: Zone défilable

    private var scrollableContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    // En-tête des jours
                    HStack(spacing: 0) {
                        ForEach(0..<vm.daysInMonth, id: \.self) { offset in
                            DayColumnHeader(
                                date:          vm.dateAtOffset(offset),
                                colWidth:      colWidth,
                                height:        dayHeaderH,
                                isHighlighted: highlight == .col(offset),
                                onTap:         { highlight = highlight == .col(offset) ? .none : .col(offset) }
                            )
                            .id("col-\(offset)")
                        }
                    }

                    // Lignes des logements
                    ForEach(visibleProperties) { prop in
                        TimelineRow(
                            reservations:      vm.monthReservations.filter { $0.propertyId == prop.id },
                            daysInMonth:       vm.daysInMonth,
                            firstDay:          vm.firstDayOfMonth,
                            propData:          vm.calendarData?.properties?[prop.id],
                            isRowHighlighted:  highlight == .row(prop.id),
                            highlightedColumn: { if case .col(let c) = highlight { return c }; return nil }(),
                            onTapReservation:  { r in
                                if r.isBlock {
                                    cellTap = .blocked(property: prop, reservation: r)
                                } else {
                                    selectedArrivee = Arrivee(reservation: r, properties: vm.properties)
                                }
                            },
                            onTapFreeCell: { date in
                                cellTap = .free(property: prop, date: date)
                            }
                        )
                    }
                }
                .frame(width: CGFloat(vm.daysInMonth) * colWidth)
                .task {
                    guard let offset = vm.todayOffset else { return }
                    // Yield once so SwiftUI finishes its first layout pass before scrolling.
                    try? await Task.sleep(for: .milliseconds(1))
                    proxy.scrollTo("col-\(offset)", anchor: .leading)
                }
            }
        }
    }

    private var thinSep: some View {
        Rectangle().fill(tlRowSep).frame(height: 1.0)
    }
}

// MARK: - En-tête de colonne de jour

private struct DayColumnHeader: View {
    let date:          Date
    let colWidth:      CGFloat
    let height:        CGFloat
    let isHighlighted: Bool
    let onTap:         () -> Void

    private var dayNumber:  String { tlDayFmt.string(from: date) }
    private var weekLetter: String { tlWeekFmt.string(from: date).uppercased() }
    private var isToday:    Bool   { Calendar.current.isDateInToday(date) }
    private var isSunday:   Bool   { tlCal.component(.weekday, from: date) == 1 }

    var body: some View {
        VStack(spacing: 2) {
            Text(weekLetter)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(Color.bhAttenue)
            Text(dayNumber)
                .font(.system(size: 13, weight: isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Color.bhVert : Color.bhEncre)
        }
        .frame(width: colWidth, height: height)
        .background { if isHighlighted { tlHighlight } }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .overlay(alignment: .bottom) {
            if isToday {
                Rectangle()
                    .fill(Color.bhVert)
                    .frame(height: 2.5)
            } else {
                Rectangle()
                    .fill(tlRowSep)
                    .frame(height: 0.5)
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(isSunday ? tlWeekSep : tlColSep)
                .frame(width: isSunday ? 1.5 : 1.0)
        }
    }
}

// MARK: - Ligne de logement

private struct TimelineRow: View {
    let reservations:      [Reservation]
    let daysInMonth:       Int
    let firstDay:          Date
    let propData:          PricingCalendarProperty?
    let isRowHighlighted:  Bool
    let highlightedColumn: Int?
    let onTapReservation:  (Reservation) -> Void
    let onTapFreeCell:     (Date) -> Void

    @Environment(AuthStore.self) private var authStore
    private var canViewPricing: Bool { authStore.session?.can("can_view_pricing") ?? true }

    private var totalWidth: CGFloat { CGFloat(daysInMonth) * colWidth }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Fond : teinte weekend + prix + mise en évidence de colonne + séparateurs
            HStack(spacing: 0) {
                ForEach(0..<daysInMonth, id: \.self) { offset in
                    let date    = tlCal.date(byAdding: .day, value: offset, to: firstDay) ?? firstDay
                    let dayKey  = CalendarViewModel.dayKey(for: date)
                    let weekend = isWeekend(offset: offset)
                    let price   = propData?.price(for: dayKey, isWeekend: weekend)
                    let isOccupied = reservations.contains { r in
                        guard let s = r.startDayDate, let e = r.endDayDate else { return false }
                        return s <= date && date < e
                    }
                    let isCheckin  = reservations.contains { $0.startDayDate == date }
                    let isCheckout = reservations.contains { $0.endDayDate   == date }
                    let isMidStay  = isOccupied && !isCheckin
                    let showPrice  = canViewPricing && !isMidStay && !(isCheckin && isCheckout)

                    ZStack {
                        if let p = price, showPrice {
                            if isCheckout && !isCheckin {
                                Text("\(Int(p.rounded()))€")
                                    .font(.system(size: CalBarLayout.priceSize, weight: .medium))
                                    .foregroundStyle(Color.bhAttenue)
                                    .lineLimit(1)
                                    .frame(width: colWidth / 2)
                                    .frame(width: colWidth, alignment: .trailing)
                            } else if isCheckin {
                                Text("\(Int(p.rounded()))€")
                                    .font(.system(size: CalBarLayout.priceSize, weight: .medium))
                                    .foregroundStyle(Color.bhAttenue)
                                    .lineLimit(1)
                                    .frame(width: colWidth / 2)
                                    .frame(width: colWidth, alignment: .leading)
                            } else {
                                Text("\(Int(p.rounded()))€")
                                    .font(.system(size: CalBarLayout.priceSize, weight: .medium))
                                    .foregroundStyle(Color.bhAttenue)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(width: colWidth, height: rowHeight)
                    .background(weekend ? tlWeekend : Color.clear)
                    .overlay { if highlightedColumn == offset { tlHighlight } }
                    .overlay(alignment: .trailing) {
                        let sun = isSunday(offset: offset)
                        Rectangle()
                            .fill(sun ? tlWeekSep : tlColSep)
                            .frame(width: sun ? 1.5 : 1.0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !isOccupied { onTapFreeCell(date) }
                    }
                }
            }

            // Mise en évidence de ligne (entre fond et barres, ne masque pas)
            if isRowHighlighted {
                tlHighlight
                    .frame(width: totalWidth, height: rowHeight)
                    .allowsHitTesting(false)
            }

            // Barres de séjour et de blocage
            ForEach(reservations) { r in
                if let geo = barGeometry(for: r) {
                    ReservationBar(reservation: r, width: geo.width, barHeight: barHeight) {
                        onTapReservation(r)
                    }
                    .offset(x: geo.x, y: CalBarLayout.tlBarTop)
                }
            }
        }
        .frame(width: totalWidth, height: rowHeight)
        .clipped()
        .overlay(alignment: .bottom) {
            Rectangle().fill(tlRowSep).frame(height: 1.0)
        }
    }

    private func isWeekend(offset: Int) -> Bool {
        guard let d = tlCal.date(byAdding: .day, value: offset, to: firstDay) else { return false }
        let weekday = tlCal.component(.weekday, from: d)
        return weekday == 1 || weekday == 7
    }

    private func isSunday(offset: Int) -> Bool {
        guard let d = tlCal.date(byAdding: .day, value: offset, to: firstDay) else { return false }
        return tlCal.component(.weekday, from: d) == 1
    }

    private func barGeometry(for r: Reservation) -> (x: CGFloat, width: CGFloat)? {
        guard let s = r.startDayDate, let e = r.endDayDate else { return nil }
        let startOff = tlCal.dateComponents([.day], from: firstDay, to: s).day ?? 0
        let endOff   = tlCal.dateComponents([.day], from: firstDay, to: e).day ?? 0
        let leftX  = max(0,          (CGFloat(startOff) + 0.5) * colWidth)
        let rightX = min(totalWidth, (CGFloat(endOff)   + 0.5) * colWidth)
        let w = rightX - leftX
        guard w > 0.5 else { return nil }
        return (leftX, w)
    }
}

// MARK: - Barre de réservation

private struct ReservationBar: View {
    let reservation: Reservation
    let width:       CGFloat
    let barHeight:   CGFloat
    let onTap:       () -> Void

    var body: some View {
        Group {
            if reservation.isBlock {
                HatchedBar(
                    color: Color.platformBloque,
                    width: width,
                    height: barHeight,
                    radius: barRadius
                )
            } else if reservation.isBhGuest {
                RoundedRectangle(cornerRadius: barRadius, style: .continuous)
                    .fill(Color.bhTerracotta)
                    .overlay(alignment: .leading) { guestLabel }
            } else {
                RoundedRectangle(cornerRadius: barRadius, style: .continuous)
                    .fill(Color.platform(reservation.platform))
                    .overlay(alignment: .leading) { guestLabel }
            }
        }
        .opacity(reservation.isBhGuest && reservation.isPending ? 0.50 : 1.0)
        .frame(width: width, height: barHeight)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    @ViewBuilder
    private var guestLabel: some View {
        HStack(spacing: 3) {
            if reservation.isBhGuest {
                BhGuestChip()
            } else {
                PlatformMiniChip(platform: reservation.platform)
            }

            if let name = reservation.guestName, width > 52 {
                Text(name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.leading, 4)
    }
}

// MARK: - Pastille BHGuest 16×16

struct BhGuestChip: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.bhTerracotta)
            Text("b")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 16, height: 16)
    }
}

// MARK: - Vignette de plateforme 16×16

struct PlatformMiniChip: View {
    let platform: String?

    private var initial: String {
        String(Color.platformLabel(platform).prefix(1))
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white.opacity(0.28))
            Text(initial)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 16, height: 16)
    }
}

// MARK: - Fond hachuré (blocages)

private struct HatchedBar: View {
    let color:  Color
    let width:  CGFloat
    let height: CGFloat
    let radius: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            let path = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
            ctx.clip(to: path)

            ctx.fill(path, with: .color(color.opacity(0.20)))

            let spacing: CGFloat = 5
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var stripe = Path()
                stripe.move(to: CGPoint(x: x,               y: 0))
                stripe.addLine(to: CGPoint(x: x + size.height, y: size.height))
                ctx.stroke(stripe, with: .color(color.opacity(0.45)), lineWidth: 1.5)
                x += spacing
            }
        }
        .frame(width: width, height: height)
    }
}
