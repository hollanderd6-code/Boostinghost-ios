import Foundation
import Observation

// MARK: - Supporting types

enum CalendarTab: String { case jour, semaine, mensuel, revenus }

enum CalendarDisplayMode: Equatable {
    case allGrid            // legacy — displayed as allLines since the grid view was removed
    case allLines
    case single(String)     // propertyId

    var persistenceKey: String {
        switch self {
        case .allGrid:        return "allGrid"
        case .allLines:       return "allLines"
        case .single(let id): return "single:\(id)"
        }
    }

    static func from(_ key: String) -> CalendarDisplayMode {
        switch key {
        case "allGrid":  return .allLines   // grid view removed — treat as allLines
        case "allLines": return .allLines
        default:
            if key.hasPrefix("single:") { return .single(String(key.dropFirst(7))) }
            return .allLines
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class CalendarViewModel {

    enum LoadState { case idle, loading, loaded, error(String) }

    private(set) var loadState:        LoadState     = .idle
    private(set) var allReservations:  [Reservation]  = []
    private(set) var properties:       [PropertySummary] = []
    private(set) var dayPrices:        [String: Double] = [:]

    // Guard: prevents overlapping silentRefresh calls (polling + push arriving simultaneously).
    private var isRefreshing = false

    // MARK: Reporting (Vue Revenus)
    private(set) var reportingState: LoadState          = .idle
    private(set) var reportingData:  ReportingResponse?

    // MARK: Pricing calendar (Vues Jour et Semaine)
    private(set) var calendarState: LoadState               = .idle
    private(set) var calendarData:  PricingCalendarResponse?

    // Reservation index built once after load(): [propertyId → reservations sorted by start]
    private var reservationIndex: [String: [Reservation]] = [:]

    // Caches invalidated on reload()
    private var occupancyCache:  [String: [String: Int]] = [:]   // monthKey → dayKey → count
    private var monthResCache:   [String: [Reservation]] = [:]   // monthKey → reservations

    var agencyAll = false

    // MARK: Persisted state

    // Month: never persisted — always opens on the current local month.
    var selectedMonthKey: String = {
        UserDefaults.standard.removeObject(forKey: "cal.month")
        return CalendarViewModel.currentMonthKey()
    }()

    var displayModeKey: String =
        UserDefaults.standard.string(forKey: "cal.mode") ?? "allLines" {
        didSet { UserDefaults.standard.set(displayModeKey, forKey: "cal.mode") }
    }

    // Default to today; falls back to firstDayOfMonth when outside the current month.
    var selectedDayKey: String = {
        let saved = UserDefaults.standard.string(forKey: "cal.day") ?? ""
        return saved.isEmpty ? CalendarViewModel.dayKey(for: Date()) : saved
    }() {
        didSet { UserDefaults.standard.set(selectedDayKey, forKey: "cal.day") }
    }

    // MARK: Derived properties

    var displayMode: CalendarDisplayMode {
        get { CalendarDisplayMode.from(displayModeKey) }
        set { displayModeKey = newValue.persistenceKey }
    }

    var selectedDay: Date? {
        get {
            guard !selectedDayKey.isEmpty else { return nil }
            return Reservation.parseDay(selectedDayKey)
        }
        set { selectedDayKey = newValue.map { Self.dayKey(for: $0) } ?? "" }
    }

    // Selected day clamped to the current month — used by Jour and Semaine views.
    var effectiveSelectedDay: Date {
        guard let d = selectedDay else { return firstDayOfMonth }
        return Self.monthKey(for: d) == selectedMonthKey ? d : firstDayOfMonth
    }

    var currentMonthDate: Date {
        Self.parseMonth(selectedMonthKey) ?? Date()
    }

    var monthTitle: String {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "fr_FR")
        f.dateFormat = "MMMM"
        return f.string(from: currentMonthDate).capitalized
    }

    var superTitle: String {
        switch displayMode {
        case .allGrid, .allLines: return "Tous les logements"
        case .single(let id):
            return properties.first(where: { $0.id == id })?.displayName ?? "Logement"
        }
    }

    var daysInMonth: Int {
        utcCal.range(of: .day, in: .month, for: currentMonthDate)?.count ?? 30
    }

    var firstDayOfMonth: Date {
        utcCal.date(from: utcCal.dateComponents([.year, .month], from: currentMonthDate))
            ?? currentMonthDate
    }

    var firstWeekdayOffset: Int {
        let weekday = utcCal.component(.weekday, from: firstDayOfMonth)
        return (weekday + 5) % 7   // 0 = Monday … 6 = Sunday
    }

    var todayOffset: Int? {
        let today = utcCal.startOfDay(for: Date())
        let offset = utcCal.dateComponents([.day], from: firstDayOfMonth, to: today).day ?? -1
        guard offset >= 0 && offset < daysInMonth else { return nil }
        return offset
    }

    // Properties shown in the current display mode (all or single).
    var visibleProperties: [PropertySummary] {
        switch displayMode {
        case .allGrid, .allLines: return properties
        case .single(let id):     return properties.filter { $0.id == id }
        }
    }

    // MARK: Week (Semaine tab)

    // Monday of the week that contains effectiveSelectedDay.
    var weekStartDate: Date {
        let day     = effectiveSelectedDay
        let weekday = utcCal.component(.weekday, from: day)   // 1 = Sun … 7 = Sat
        let offset  = -((weekday + 5) % 7)                    // Mon = 0, Tue = 1, …
        return utcCal.date(byAdding: .day, value: offset, to: day) ?? day
    }

    // The 7 days (Mon … Sun) of the selected week.
    var weekDays: [Date] {
        (0..<7).compactMap { utcCal.date(byAdding: .day, value: $0, to: weekStartDate) }
    }

    // MARK: Month helpers

    func dateAtOffset(_ offset: Int) -> Date {
        utcCal.date(byAdding: .day, value: offset, to: firstDayOfMonth) ?? firstDayOfMonth
    }

    func dayDate(_ day: Int) -> Date {
        utcCal.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) ?? firstDayOfMonth
    }

    // MARK: Filtered reservations (cached per month)

    var monthReservations: [Reservation] {
        let mk = selectedMonthKey
        if let hit = monthResCache[mk] { return hit }
        let result = buildMonthReservations(for: mk)
        monthResCache[mk] = result
        return result
    }

    private func buildMonthReservations(for monthKey: String) -> [Reservation] {
        guard let monthDate = Self.parseMonth(monthKey),
              let end = utcCal.date(byAdding: .month, value: 1, to: monthDate)
        else { return [] }
        return allReservations.filter { r in
            guard let s = r.startDayDate, let e = r.endDayDate else { return false }
            return s < end && e > monthDate
        }
    }

    // MARK: Occupancy (cached per month)

    func occupancy(for day: Date) -> Int {
        let mk = Self.monthKey(for: day)
        let dk = Self.dayKey(for: day)
        if let v = occupancyCache[mk]?[dk] { return v }
        populateOccupancyCache(for: mk)
        return occupancyCache[mk]?[dk] ?? 0
    }

    private func populateOccupancyCache(for monthKey: String) {
        guard let monthDate = Self.parseMonth(monthKey) else { return }
        let days = utcCal.range(of: .day, in: .month, for: monthDate)?.count ?? 30
        var cache = [String: Int](minimumCapacity: days)

        for offset in 0..<days {
            guard let day = utcCal.date(byAdding: .day, value: offset, to: monthDate) else { continue }
            let dk = Self.dayKey(for: day)
            var count = 0
            for prop in properties {
                let occupied = (reservationIndex[prop.id] ?? []).contains { r in
                    guard !r.isBlock, let s = r.startDayDate, let e = r.endDayDate else { return false }
                    return s <= day && day < e
                }
                if occupied { count += 1 }
            }
            cache[dk] = count
        }
        occupancyCache[monthKey] = cache
    }

    func arrivals(on day: Date) -> [Reservation] {
        let key = Self.dayKey(for: day)
        return monthReservations.filter { !$0.isBlock && $0.startDate == key }
    }

    func departures(on day: Date) -> [Reservation] {
        let key = Self.dayKey(for: day)
        return monthReservations.filter { !$0.isBlock && $0.endDate == key }
    }

    // MARK: BHGuest holds (from allReservations — absent from calendarData)

    // Pending holds = isBhGuest with status "hold" (not yet paid/confirmed).
    var activeHolds: [Reservation] {
        allReservations.filter { $0.isBhGuest && $0.isPending }
    }

    // Holds arriving on a given day — for JourView's Arrivées section.
    func holdArrivals(on day: Date) -> [(property: PropertySummary, reservation: Reservation)] {
        let key = Self.dayKey(for: day)
        return activeHolds.compactMap { r in
            guard r.startDate == key,
                  let prop = properties.first(where: { $0.id == r.propertyId })
            else { return nil }
            return (prop, r)
        }
    }

    // Holds that overlap the given week — for SemaineView's bar overlay.
    func holdEntriesForProperty(_ propertyId: String, overlapping days: [Date]) -> [Reservation] {
        guard let weekStart = days.first, let weekEnd = days.last else { return [] }
        guard let weekEndExclusive = utcCal.date(byAdding: .day, value: 1, to: weekEnd) else { return [] }
        return activeHolds.filter { r in
            guard r.propertyId == propertyId,
                  let s = r.startDayDate, let e = r.endDayDate
            else { return false }
            return s < weekEndExclusive && e > weekStart
        }
    }

    // MARK: Silent refresh (polling + push accelerator)
    // Never mutates loadState / calendarState — safe to call in background.
    // Ignores failures: keeps existing data intact on network errors.

    func silentRefresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // Capture context before any await to detect stale responses.
        let capturedAgencyAll = agencyAll
        let capturedMonthKey  = selectedMonthKey
        let capturedFirstDay  = firstDayOfMonth

        let t0 = Date()
        do {
            let r: ReservationsResponse = try await APIClient.shared.get(
                Endpoint.reservations, agencyAll: capturedAgencyAll
            )
            guard agencyAll == capturedAgencyAll else {
                print("↪️ [Calendar] Ignoring stale reservations response after agency change")
                return
            }
            allReservations = r.reservations ?? []
            if let props = r.properties, !props.isEmpty { properties = props }
            buildReservationIndex()
            occupancyCache = [:]
            monthResCache  = [:]
            let ms = Int(Date().timeIntervalSince(t0) * 1000)
            print("[Calendar] silentRefresh \(ms)ms — \(allReservations.count) réservations")
        } catch {
            print("[Calendar] silentRefresh reservations error: \(error)")
        }

        guard case .loaded = calendarState else { return }
        let from = Self.dayKey(for: capturedFirstDay)
        guard let nextMonthDate = utcCal.date(byAdding: .month, value: 1, to: capturedFirstDay) else { return }
        let to = Self.dayKey(for: nextMonthDate)
        do {
            let newCal: PricingCalendarResponse = try await APIClient.shared.get(
                Endpoint.pricingCalendarAll,
                agencyAll: capturedAgencyAll,
                extraQueryItems: [
                    URLQueryItem(name: "from", value: from),
                    URLQueryItem(name: "to",   value: to),
                ]
            )
            guard agencyAll == capturedAgencyAll else {
                print("↪️ [Calendar] Ignoring stale pricing response after agency change")
                return
            }
            guard selectedMonthKey == capturedMonthKey else {
                print("↪️ [Calendar] Ignoring stale pricing response for \(capturedMonthKey)")
                return
            }
            calendarData = newCal
            print("[Calendar] silentRefresh calendar done")
        } catch {
            print("[Calendar] silentRefresh calendar error: \(error)")
        }
    }

    // MARK: Calendar data queries (Vues Jour et Semaine)

    func calendarArrivals(on day: Date) -> [(property: PropertySummary, entry: PricingCalendarEntry)] {
        let key = Self.dayKey(for: day)
        var result: [(PropertySummary, PricingCalendarEntry)] = []
        for prop in visibleProperties {
            guard let propData = calendarData?.properties?[prop.id] else { continue }
            for entry in propData.booked ?? [] where entry.start == key {
                result.append((prop, entry))
            }
        }
        return result
    }

    func calendarDepartures(on day: Date) -> [(property: PropertySummary, entry: PricingCalendarEntry)] {
        let key = Self.dayKey(for: day)
        var result: [(PropertySummary, PricingCalendarEntry)] = []
        for prop in visibleProperties {
            guard let propData = calendarData?.properties?[prop.id] else { continue }
            for entry in propData.booked ?? [] where entry.end == key {
                result.append((prop, entry))
            }
        }
        return result
    }

    // MARK: Navigation

    func nextMonth() {
        guard let next = utcCal.date(byAdding: .month, value: 1, to: currentMonthDate)
        else { return }
        selectedMonthKey = Self.monthKey(for: next)
    }

    func previousMonth() {
        guard let prev = utcCal.date(byAdding: .month, value: -1, to: currentMonthDate)
        else { return }
        selectedMonthKey = Self.monthKey(for: prev)
    }

    func nextWeek() {
        guard let next = utcCal.date(byAdding: .day, value: 7, to: effectiveSelectedDay) else { return }
        let nextMK = Self.monthKey(for: next)
        if nextMK != selectedMonthKey { selectedMonthKey = nextMK }
        selectedDay = next
    }

    func previousWeek() {
        guard let prev = utcCal.date(byAdding: .day, value: -7, to: effectiveSelectedDay) else { return }
        let prevMK = Self.monthKey(for: prev)
        if prevMK != selectedMonthKey { selectedMonthKey = prevMK }
        selectedDay = prev
    }

    // MARK: Network — Reservations

    func load() async {
        switch loadState {
        case .idle, .loaded: break
        default: return
        }
        if case .loaded = loadState {} else { loadState = .loading }
        let t0 = Date()
        do {
            let r: ReservationsResponse = try await APIClient.shared.get(
                Endpoint.reservations, agencyAll: agencyAll
            )
            allReservations  = r.reservations ?? []
            if let props = r.properties, !props.isEmpty { properties = props }
            buildReservationIndex()
            // Invalidate derived caches only after new data is set, so any re-render triggered by
            // the loadState change below rebuilds them from the fresh allReservations.
            occupancyCache  = [:]
            monthResCache   = [:]
            loadState       = .loaded
            let ms = Int(Date().timeIntervalSince(t0) * 1000)
            print("[Calendar] load \(ms)ms — \(allReservations.count) réservations, \(properties.count) logements")
        } catch {
            loadState = .error("Impossible de charger les réservations")
        }
    }

    func reload() async {
        if case .loaded = loadState {} else { loadState = .idle }
        calendarState    = .idle
        calendarData     = nil
        reservationIndex = [:]
        await load()
    }

    func clearPricing() { dayPrices = [:] }

    // MARK: Network — Pricing calendar (Jour + Semaine)

    func loadCalendar() async {
        guard case .idle = calendarState else { return }
        calendarState = .loading
        let from = Self.dayKey(for: firstDayOfMonth)
        guard let nextMonthDate = utcCal.date(byAdding: .month, value: 1, to: firstDayOfMonth) else {
            calendarState = .error("Mois invalide")
            return
        }
        let to = Self.dayKey(for: nextMonthDate)
        do {
            calendarData  = try await APIClient.shared.get(
                Endpoint.pricingCalendarAll,
                agencyAll: agencyAll,
                extraQueryItems: [
                    URLQueryItem(name: "from", value: from),
                    URLQueryItem(name: "to",   value: to),
                ]
            )
            calendarState = .loaded
            print("[Calendar] calendar \(from)→\(to) — \(calendarData?.properties?.count ?? 0) logements")
            #if DEBUG
            debugLogBookedEntries()
            #endif
        } catch {
            calendarState = .error("Impossible de charger le calendrier")
        }
    }

    func clearCalendar() {
        calendarState = .idle
        calendarData  = nil
    }

    #if DEBUG
    private func debugLogBookedEntries() {
        guard let props = calendarData?.properties else {
            print("[CalendarDebug] aucune propriété dans calendarData")
            return
        }

        // Collecte toutes les entrées booked, tous logements confondus
        var all: [(propId: String, entry: PricingCalendarEntry)] = []
        for (propId, propData) in props {
            for entry in propData.booked ?? [] {
                all.append((propId, entry))
            }
        }

        // 15 premières entrées
        print("[CalendarDebug] ── 15 premières entrées booked ──────────────────")
        for item in all.prefix(15) {
            print("  propId=\(item.propId.suffix(6))  platform=\(item.entry.platform ?? "nil")  uid=\(item.entry.uid ?? "nil")  guest=\(item.entry.guest ?? "nil")  \(item.entry.start)→\(item.entry.end)")
        }

        // Récapitulatif : valeurs distinctes de platform avec occurrences
        var platformCounts: [String: Int] = [:]
        var uidNilCount = 0
        for item in all {
            let key = item.entry.platform ?? "(nil)"
            platformCounts[key, default: 0] += 1
            if item.entry.uid == nil { uidNilCount += 1 }
        }
        print("[CalendarDebug] ── plateformes distinctes (\(all.count) entrées total) ──")
        for (platform, count) in platformCounts.sorted(by: { $0.value > $1.value }) {
            print("  \(count)×  \"\(platform)\"")
        }
        print("[CalendarDebug] uid nil : \(uidNilCount)/\(all.count)")

        // Vérification C — croisement uid calendarData ↔ allReservations
        let calUids = Set(all.compactMap(\.entry.uid))
        let resUids = Set(allReservations.compactMap(\.uid))
        let matched = calUids.intersection(resUids)
        let absent  = calUids.subtracting(resUids)
        print("[CalendarDebug] ── croisement uid (\(calUids.count) cal / \(resUids.count) res) ──")
        print("[CalendarDebug] présents dans les deux : \(matched.count)")
        print("[CalendarDebug] absents de allReservations : \(absent.count)")
        for uid in Array(matched).prefix(3) { print("[CalendarDebug]   ✓ \(uid)") }
        for uid in Array(absent).prefix(3)  { print("[CalendarDebug]   ✗ \(uid)") }
        print("[CalendarDebug] ────────────────────────────────────────────────")
    }
    #endif

    // MARK: Network — Reporting

    func loadReporting() async {
        if case .loading = reportingState { return }
        reportingState = .loading
        reportingData  = nil

        let parts = selectedMonthKey.split(separator: "-")
        guard parts.count == 2,
              let year  = Int(parts[0]),
              let month = Int(parts[1]) else {
            reportingState = .error("Mois invalide")
            return
        }
        let propertyId: String?
        if case .single(let id) = displayMode { propertyId = id } else { propertyId = nil }

        do {
            reportingData  = try await APIClient.shared.get(
                Endpoint.reporting,
                agencyAll: true,
                extraQueryItems: Endpoint.reportingItems(year: year, month: month, propertyId: propertyId)
            )
            reportingState = .loaded
        } catch is CancellationError {
            reportingState = .idle
        } catch {
            reportingState = .error("Impossible de charger les revenus")
        }
    }

    func clearReporting() {
        reportingState = .idle
        reportingData  = nil
    }

    // MARK: Network — Pricing single property (Mensuel — single mode)

    func loadPricing(for propertyId: String) async {
        dayPrices = [:]
        guard let r: DayPriceResponse = try? await APIClient.shared.get(
            Endpoint.pricingCalendar(propertyId)
        ) else { return }
        dayPrices = r.prices
    }

    func savePrice(_ price: Double, for day: Date, propertyId: String) async throws {
        let key = Self.dayKey(for: day)
        let previous = dayPrices[key]
        // Optimistic: update immediately so Mensuel single-mode feels instant.
        dayPrices[key] = price
        let body = PriceOverrideBody(property_id: propertyId, date: key, price: price)
        do {
            try await APIClient.shared.postVoid(Endpoint.pricingOverrides, body: body)
        } catch {
            dayPrices[key] = previous
            throw error
        }
    }

    // MARK: - Network — Calendar cell actions

    func blockDates(propertyId: String, start: Date, end: Date, reason: String) async throws {
        // end is already exclusive (checkout convention) — BlockBody expects exclusive end.
        let body = BlockBody(
            propertyId: propertyId,
            start: Self.dayKey(for: start),
            end: Self.dayKey(for: end),
            reason: reason
        )
        try await APIClient.shared.postVoid(Endpoint.blocks, body: body, agencyAll: true)
    }

    func setPrice(propertyId: String, start: Date, end: Date, price: Double?) async throws {
        // end is exclusive (checkout convention): iterate [start, end)
        var current = start
        while utcCal.compare(current, to: end, toGranularity: .day) == .orderedAscending {
            let body = PriceOverrideBody(property_id: propertyId, date: Self.dayKey(for: current), price: price)
            try await APIClient.shared.postVoid(Endpoint.pricingOverrides, body: body, agencyAll: true)
            guard let next = utcCal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
    }

    func createMinStayRule(propertyId: String, minNights: Int, start: Date, end: Date) async throws {
        let startKey = Self.dayKey(for: start)
        // end is exclusive (checkout convention); rules API expects inclusive end_date.
        let inclusiveEnd = utcCal.date(byAdding: .day, value: -1, to: end) ?? end
        let endKey = Self.dayKey(for: inclusiveEnd)
        let body = PricingRuleBody(
            propertyId:  propertyId,
            name:        Self.minStayRuleName(minNights: minNights, start: startKey, end: endKey),
            ruleType:    "min_stay",
            minNights:   minNights,
            startDate:   startKey,
            endDate:     endKey,
            daysOfWeek:  nil,
            priority:    nil
        )
        try await APIClient.shared.postVoid(Endpoint.pricingRules, body: body, agencyAll: true)
    }

    private static func minStayRuleName(minNights: Int, start: String, end: String) -> String {
        func short(_ key: String) -> String {
            let p = key.split(separator: "-")
            guard p.count == 3 else { return key }
            return "\(p[2])/\(p[1])"
        }
        let label = minNights == 1 ? "1 nuit" : "\(minNights) nuits"
        return start == end
            ? "Min \(label) — \(short(start))"
            : "Min \(label) — \(short(start)) au \(short(end))"
    }

    func createManualReservation(
        propertyId:      String,
        start:           Date,
        end:             Date,
        guestName:       String?,
        notes:           String?,
        platform:        String?,
        price:           Double?,
        phone:           String?,
        email:           String?,
        guestCountry:    String?,
        occupancyAdults: Int?,
        amountRooms:     Double?,
        amountCleaning:  Double?,
        amountTaxes:     Double?,
        otaCommission:   Double?
    ) async throws {
        let body = ManualReservationBody(
            propertyId:      propertyId,
            start:           Self.dayKey(for: start),
            end:             Self.dayKey(for: end),
            guestName:       guestName,
            notes:           notes,
            platform:        platform,
            price:           price,
            phone:           phone,
            email:           email,
            guestCountry:    guestCountry,
            occupancyAdults: occupancyAdults,
            amountRooms:     amountRooms,
            amountCleaning:  amountCleaning,
            amountTaxes:     amountTaxes,
            otaCommission:   otaCommission
        )
        try await APIClient.shared.postVoid(Endpoint.manualReservations, body: body, agencyAll: true)
    }

    func unblock(_ uid: String) async throws {
        try await APIClient.shared.delete(Endpoint.block(uid), agencyAll: true)
    }

    func createGuestHold(
        propertyId: String,
        checkin:    Date,
        checkout:   Date,
        fixedPrice: Double?,
        guestPhone: String?,
        guestEmail: String?,
        sendSms:    Bool
    ) async throws -> BHGuestHoldResponse {
        let body = BHGuestHoldBody(
            propertyId: propertyId,
            checkin:    Self.dayKey(for: checkin),
            checkout:   Self.dayKey(for: checkout),
            fixedPrice: fixedPrice,
            guestPhone: guestPhone,
            guestEmail: guestEmail,
            sendSms:    sendSms ? true : nil
        )
        return try await APIClient.shared.post(Endpoint.guestHold, body: body)
    }

    // MARK: Network — Property reorder

    private struct PropertyOrderBody: Encodable {
        let order: [String]
    }

    // Saves a new property order to the backend, then applies it directly.
    // Does NOT rely on a second GET: the backend cache is per-process on Render.com,
    // so a subsequent GET might hit a different process with a stale PROPERTIES array
    // and silently return the old order — leaving vm.properties unchanged.
    // The PUT response (200) confirms the DB commit; we trust the caller's newOrder.
    func reorderProperties(_ newOrder: [PropertySummary]) async throws {
        #if DEBUG
        print("[CALORDER] before = \(properties.map(\.displayName))")
        print("[CALORDER] submit = \(newOrder.map(\.displayName))")
        #endif
        let body = PropertyOrderBody(order: newOrder.map(\.id))
        try await APIClient.shared.putVoid(Endpoint.propertiesOrderBulk, body: body)
        // PUT confirmed (200): DB commit done, backend cache refreshed.
        // Apply directly — no second GET that could return a stale order.
        properties = newOrder
        buildReservationIndex()
        occupancyCache = [:]
        monthResCache  = [:]
        #if DEBUG
        print("[CALORDER] after  = \(properties.map(\.displayName))")
        #endif
    }

    func reloadMonthData() async {
        await reload()
        await loadCalendar()
    }

    func refreshCalendar() async {
        await reloadMonthData()
    }

    // MARK: Index builder

    private func buildReservationIndex() {
        var idx = [String: [Reservation]]()
        for r in allReservations {
            idx[r.propertyId, default: []].append(r)
        }
        for key in idx.keys {
            idx[key]?.sort { ($0.startDayDate ?? .distantPast) < ($1.startDayDate ?? .distantPast) }
        }
        reservationIndex = idx
    }

    // MARK: Date key helpers

    static func currentMonthKey() -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        return String(format: "%04d-%02d", c.year!, c.month!)
    }

    nonisolated static func dayKey(for date: Date) -> String { Formatters.dayKey(date) }
    static func monthKey(for date: Date) -> String  { monthKeyFmt.string(from: date) }
    static func parseMonth(_ key: String) -> Date?  { monthKeyFmt.date(from: key) }

    private static let monthKeyFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        f.timeZone   = TimeZone(identifier: "UTC")
        return f
    }()

    let utcCal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.timeZone     = TimeZone(identifier: "UTC")!
        return c
    }()
}

// MARK: - Notification name

extension Notification.Name {
    static let calendarShouldRefresh = Notification.Name("CalendarShouldRefresh")
}
