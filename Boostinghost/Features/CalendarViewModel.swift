import Foundation
import Observation

// MARK: - Supporting types

enum CalendarTab: String { case planning, revenus }

enum CalendarDisplayMode: Equatable {
    case allGrid
    case allLines
    case single(String)   // propertyId

    var persistenceKey: String {
        switch self {
        case .allGrid:        return "allGrid"
        case .allLines:       return "allLines"
        case .single(let id): return "single:\(id)"
        }
    }

    static func from(_ key: String) -> CalendarDisplayMode {
        switch key {
        case "allGrid":  return .allGrid
        case "allLines": return .allLines
        default:
            if key.hasPrefix("single:") { return .single(String(key.dropFirst(7))) }
            return .allGrid
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

    // MARK: Reporting (Vue Revenus)
    private(set) var reportingState: LoadState          = .idle
    private(set) var reportingData:  ReportingResponse?

    // Reservation index built once after load(): [propertyId → reservations sorted by start]
    private var reservationIndex: [String: [Reservation]] = [:]

    // Caches invalidated on reload()
    private var occupancyCache:  [String: [String: Int]] = [:]   // monthKey → dayKey → count
    private var monthResCache:   [String: [Reservation]] = [:]   // monthKey → reservations

    var agencyAll = false

    // MARK: Persisted state

    // Month: never persisted — always opens on the current local month.
    // Purge any legacy "cal.month" key left by older builds.
    var selectedMonthKey: String = {
        UserDefaults.standard.removeObject(forKey: "cal.month")
        return CalendarViewModel.currentMonthKey()
    }()

    var displayModeKey: String =
        UserDefaults.standard.string(forKey: "cal.mode") ?? "allGrid" {
        didSet { UserDefaults.standard.set(displayModeKey, forKey: "cal.mode") }
    }

    var selectedDayKey: String =
        UserDefaults.standard.string(forKey: "cal.day") ?? "" {
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
        case .allGrid:  return "Tous les logements"
        case .allLines: return "Tous les logements — en lignes"
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

    /// 0-based column offset for today in the displayed month, nil if today is outside.
    var todayOffset: Int? {
        let today = utcCal.startOfDay(for: Date())
        let offset = utcCal.dateComponents([.day], from: firstDayOfMonth, to: today).day ?? -1
        guard offset >= 0 && offset < daysInMonth else { return nil }
        return offset
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

    // Fills the full month in one pass using the reservationIndex — O(days × properties × avgStaysPerProperty).
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

    // MARK: Network

    func load() async {
        guard case .idle = loadState else { return }
        loadState = .loading
        let t0 = Date()
        do {
            let r: ReservationsResponse = try await APIClient.shared.get(
                Endpoint.reservations, agencyAll: agencyAll
            )
            allReservations = r.reservations ?? []
            if let props = r.properties, !props.isEmpty { properties = props }
            buildReservationIndex()
            loadState = .loaded
            let ms = Int(Date().timeIntervalSince(t0) * 1000)
            print("[Calendar] load \(ms)ms — \(allReservations.count) réservations, \(properties.count) logements")
        } catch {
            loadState = .error("Impossible de charger les réservations")
        }
    }

    func reload() async {
        loadState        = .idle
        occupancyCache   = [:]
        monthResCache    = [:]
        reservationIndex = [:]
        await load()
    }

    func clearPricing() { dayPrices = [:] }

    // MARK: Reporting

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
            let url = Endpoint.reporting(year: year, month: month, propertyId: propertyId)
            // Reporting is always agency-wide ("données de gestion").
            reportingData  = try await APIClient.shared.get(url, agencyAll: true)
            reportingState = .loaded
        } catch is CancellationError {
            // View disappeared — reset so the next appearance retries cleanly.
            reportingState = .idle
        } catch {
            reportingState = .error("Impossible de charger les revenus")
        }
    }

    func clearReporting() {
        reportingState = .idle
        reportingData  = nil
    }

    func loadPricing(for propertyId: String) async {
        dayPrices = [:]
        guard let r: DayPriceResponse = try? await APIClient.shared.get(
            Endpoint.pricingCalendar(propertyId)
        ) else { return }
        dayPrices = r.prices
    }

    func savePrice(_ price: Double, for day: Date, propertyId: String) async throws {
        let body = PriceOverrideBody(
            property_id: propertyId,
            date: Self.dayKey(for: day),
            price: price
        )
        try await APIClient.shared.postVoid(Endpoint.pricingOverrides, body: body)
        dayPrices[Self.dayKey(for: day)] = price
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

    /// Current month as "yyyy-MM" using the device's local timezone — never shifts on UTC midnight.
    static func currentMonthKey() -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        return String(format: "%04d-%02d", c.year!, c.month!)
    }

    static func dayKey(for date: Date) -> String   { dayKeyFmt.string(from: date) }
    static func monthKey(for date: Date) -> String  { monthKeyFmt.string(from: date) }
    static func parseMonth(_ key: String) -> Date?  { monthKeyFmt.date(from: key) }

    private static let dayKeyFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone   = TimeZone(identifier: "UTC")
        return f
    }()

    private static let monthKeyFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        f.timeZone   = TimeZone(identifier: "UTC")
        return f
    }()

    // UTC-anchored Gregorian calendar — prevents 1-day shifts on "yyyy-MM-dd" strings from Postgres.
    let utcCal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.timeZone     = TimeZone(identifier: "UTC")!
        return c
    }()
}
