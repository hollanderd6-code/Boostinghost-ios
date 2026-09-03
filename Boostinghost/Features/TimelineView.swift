import SwiftUI

// MARK: - Layout constants (design tokens)

private let colWidth:   CGFloat = 46
private let rowHeight:  CGFloat = 52
private let labelWidth: CGFloat = 74
private let dayHeaderH: CGFloat = 44
private let barHeight:  CGFloat = 36
private let barRadius:  CGFloat = 11

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

// rgba(20,32,27,.06) — séparateur de ligne
private let tlSeparator = Color(red: 20/255, green: 32/255, blue: 27/255).opacity(0.06)
// rgba(201,161,91,.07) — fond weekend
private let tlWeekend   = Color(red: 201/255, green: 161/255, blue: 91/255).opacity(0.07)

// MARK: - Vue principale

struct TimelineView: View {
    var vm: CalendarViewModel

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

            BlockDateRow()
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // Reserve for the floating tab bar (same pattern as other screens)
            Color.clear.frame(height: 80)
        }
    }

    // MARK: Colonne gauche fixe

    private var fixedLabelColumn: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: dayHeaderH)
            ForEach(visibleProperties) { prop in
                Text(prop.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                    .lineLimit(1)
                    .padding(.leading, 16)
                    .padding(.trailing, 6)
                    .frame(width: labelWidth, height: rowHeight, alignment: .leading)
                    .overlay(alignment: .bottom) { thinSep }
            }
        }
        .background {
            HStack {
                Spacer()
                Rectangle()
                    .fill(tlSeparator)
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
                                date: vm.dateAtOffset(offset),
                                colWidth: colWidth,
                                height: dayHeaderH
                            )
                            .id("col-\(offset)")
                        }
                    }

                    // Lignes des logements
                    ForEach(visibleProperties) { prop in
                        TimelineRow(
                            reservations: vm.monthReservations.filter { $0.propertyId == prop.id },
                            daysInMonth:  vm.daysInMonth,
                            firstDay:     vm.firstDayOfMonth
                        )
                    }
                }
                .frame(width: CGFloat(vm.daysInMonth) * colWidth)
                .onAppear {
                    // Scroll to today on first display, centered in the visible area
                    if let offset = vm.todayOffset {
                        proxy.scrollTo("col-\(offset)", anchor: .center)
                    }
                }
            }
        }
    }

    private var thinSep: some View {
        Rectangle().fill(tlSeparator).frame(height: 0.5)
    }
}

// MARK: - En-tête de colonne de jour

private struct DayColumnHeader: View {
    let date:     Date
    let colWidth: CGFloat
    let height:   CGFloat

    // File-scope formatters — no allocation per render
    private var dayNumber:  String { tlDayFmt.string(from: date) }
    private var weekLetter: String { tlWeekFmt.string(from: date).uppercased() }
    private var isToday:    Bool   { Calendar.current.isDateInToday(date) }

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
        .overlay(alignment: .bottom) {
            if isToday {
                // Liseré vert 2.5 px (token) sous le jour courant
                Rectangle()
                    .fill(Color.bhVert)
                    .frame(height: 2.5)
            } else {
                Rectangle()
                    .fill(tlSeparator)
                    .frame(height: 0.5)
            }
        }
    }
}

// MARK: - Ligne de logement

private struct TimelineRow: View {
    let reservations: [Reservation]
    let daysInMonth:  Int
    let firstDay:     Date

    private var totalWidth: CGFloat { CGFloat(daysInMonth) * colWidth }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Fond : teinte weekend + séparateurs verticaux
            HStack(spacing: 0) {
                ForEach(0..<daysInMonth, id: \.self) { offset in
                    Rectangle()
                        .fill(isWeekend(offset: offset) ? tlWeekend : Color.clear)
                        .frame(width: colWidth)
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(tlSeparator)
                                .frame(width: 0.3)
                        }
                }
            }

            // Barres de séjour et de blocage
            ForEach(reservations) { r in
                if let geo = barGeometry(for: r) {
                    ReservationBar(reservation: r, width: geo.width, barHeight: barHeight)
                        .offset(x: geo.x, y: (rowHeight - barHeight) / 2)
                }
            }
        }
        .frame(width: totalWidth, height: rowHeight)
        .clipped()
        .overlay(alignment: .bottom) {
            Rectangle().fill(tlSeparator).frame(height: 0.5)
        }
    }

    // File-scope tlCal — no Calendar allocation per call
    private func isWeekend(offset: Int) -> Bool {
        guard let d = tlCal.date(byAdding: .day, value: offset, to: firstDay) else { return false }
        let weekday = tlCal.component(.weekday, from: d)
        return weekday == 1 || weekday == 7   // dimanche ou samedi
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

    var body: some View {
        Group {
            if reservation.isBlock {
                HatchedBar(
                    color: Color.platformBloque,
                    width: width,
                    height: barHeight,
                    radius: barRadius
                )
            } else {
                RoundedRectangle(cornerRadius: barRadius, style: .continuous)
                    .fill(Color.platform(reservation.platform))
                    .overlay(alignment: .leading) {
                        guestLabel
                    }
            }
        }
        .frame(width: width, height: barHeight)
    }

    @ViewBuilder
    private var guestLabel: some View {
        HStack(spacing: 3) {
            PlatformMiniChip(platform: reservation.platform)

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

// MARK: - Vignette de plateforme 16×16

private struct PlatformMiniChip: View {
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
