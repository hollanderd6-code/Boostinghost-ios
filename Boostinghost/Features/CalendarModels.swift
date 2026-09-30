import Foundation

// MARK: - GET /api/pricing/calendar?from=YYYY-MM-DD&to=YYYY-MM-DD&agency=all
//
// Response shape (camelCase — matches convertFromSnakeCase):
// { from, to, properties: { "<propertyId>": {
//     basePrice, weekendPrice,
//     prices: { "YYYY-MM-DD": Double },
//     booked:  [{ start, end, guest, uid, platform }],
//     blocked: [{ start, end, uid, reason }],
//     currency: "EUR" | "ILS" | "USD" | …  (nil on legacy responses)
//     boostpriceEnabled: Bool,
//     sources:    { "YYYY-MM-DD": "manual_override"|"boostprice"|"period_rule"|… },
//     bpSchedule: { "YYYY-MM-DD": { status: "pending"|"applied", price: Double } }
// } } }

// MARK: - BoostPrice source authority
// sources[date] is the single authority for what price source is applied.
// bpSchedule[date] carries the recommendation metadata only — it is NOT authoritative.

enum PricingSource: Decodable, Equatable {
    case manualOverride
    case boostprice
    case periodRule
    case weekdayRule
    case weekendPrice
    case basePrice
    case none
    case unknown(String)

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PricingSource(rawValue: raw)
    }

    init(rawValue: String) {
        switch rawValue {
        case "manual_override": self = .manualOverride
        case "boostprice":      self = .boostprice
        case "period_rule":     self = .periodRule
        case "weekday_rule":    self = .weekdayRule
        case "weekend_price":   self = .weekendPrice
        case "base_price":      self = .basePrice
        case "none":            self = .none
        default:                self = .unknown(rawValue)
        }
    }
}

enum BoostPriceScheduleStatus: Decodable, Equatable {
    case pending
    case applied
    case declined
    case unknown(String)

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = BoostPriceScheduleStatus(rawValue: raw)
    }

    init(rawValue: String) {
        switch rawValue {
        case "pending":  self = .pending
        case "applied":  self = .applied
        case "declined": self = .declined
        default:         self = .unknown(rawValue)
        }
    }
}

struct BoostPriceScheduleEntry: Decodable, Equatable {
    let status: BoostPriceScheduleStatus
    let price:  Double

    init(from decoder: Decoder) throws {
        let c   = try decoder.container(keyedBy: CodingKeys.self)
        let raw = (try? c.decode(String.self, forKey: .status)) ?? ""
        status  = BoostPriceScheduleStatus(rawValue: raw)
        price   = c.flexDouble(forKey: .price) ?? 0
    }

    private enum CodingKeys: CodingKey {
        case status, price
    }
}

struct PricingCalendarResponse: Decodable {
    let from: String?
    let to:   String?
    // Keys are property _id strings — hyphens not present, convertFromSnakeCase is harmless
    let properties: [String: PricingCalendarProperty]?
}

struct PricingCalendarProperty: Decodable {
    let basePrice:    Double?
    let weekendPrice: Double?
    // Keys are "YYYY-MM-DD" — no underscores, convertFromSnakeCase leaves them intact
    let prices:  [String: Double]?
    let booked:  [PricingCalendarEntry]?
    let blocked: [PricingCalendarBlock]?
    // nil on legacy responses — callers use Formatters.normalizeCurrency to fall back to EUR
    let currency: String?
    // BoostPrice fields — nil on responses from backends before commit bce6c665
    let boostpriceEnabled: Bool?
    let sources:    [String: PricingSource]?
    let bpSchedule: [String: BoostPriceScheduleEntry]?

    func price(for dayKey: String, isWeekend: Bool) -> Double? {
        if let custom = prices?[dayKey] { return custom }
        return isWeekend ? (weekendPrice ?? basePrice) : basePrice
    }
}

// MARK: - BoostPrice helpers

extension PricingCalendarProperty {
    var isBoostPriceEnabled: Bool { boostpriceEnabled ?? false }

    func pricingSource(for dayKey: String) -> PricingSource? {
        sources?[dayKey]
    }

    // Derives from sources ONLY — bpSchedule.status is recommendation metadata, not authority.
    func isBoostPriceEffective(for dayKey: String) -> Bool {
        sources?[dayKey] == .boostprice
    }

    func boostPriceScheduleEntry(for dayKey: String) -> BoostPriceScheduleEntry? {
        bpSchedule?[dayKey]
    }

    func hasPendingRecommendation(for dayKey: String) -> Bool {
        bpSchedule?[dayKey]?.status == .pending
    }

    func boostPriceRecommendation(for dayKey: String) -> Double? {
        guard let entry = bpSchedule?[dayKey], entry.price > 0 else { return nil }
        return entry.price
    }
}

struct PricingCalendarEntry: Decodable, Identifiable {
    let start:    String   // "YYYY-MM-DD"
    let end:      String   // "YYYY-MM-DD"
    let guest:    String?
    let uid:      String?
    let platform: String?

    var id: String { uid ?? "\(start)-\(end)-\(guest ?? "")" }

    // WORKAROUND — /api/pricing/calendar ne renvoie pas le champ platform pour les
    // réservations BHGuest (il est nil), contrairement à /api/reservations qui expose
    // à la fois platform et source. On détecte BHGuest via le préfixe de l'uid côté
    // Channex/Boostinghost. Si le préfixe change côté backend, la couleur BHGuest
    // disparaîtra silencieusement dans les vues Semaine et Jour.
    var isBhGuest: Bool { uid?.hasPrefix("BHGUEST_") == true }

    var startDate: Date? { pceDayFmt.date(from: start) }
    var endDate:   Date? { pceDayFmt.date(from: end) }

    var nights: Int {
        guard let s = startDate, let e = endDate else { return 0 }
        return max(0, pceUtcCal.dateComponents([.day], from: s, to: e).day ?? 0)
    }
}

struct PricingCalendarBlock: Decodable, Identifiable {
    let start:  String
    let end:    String?
    let uid:    String?
    let reason: String?

    var id: String { uid ?? "\(start)-\(end ?? "")" }
    var startDate: Date? { pceDayFmt.date(from: start) }
    var endDate: Date? {
        if let e = end { return pceDayFmt.date(from: e) }
        return startDate.flatMap { pceUtcCal.date(byAdding: .day, value: 1, to: $0) }
    }
}

// File-scope helpers — allocated once, shared across all entries.
private let pceDayFmt: DateFormatter = {
    let f = DateFormatter()
    f.locale     = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone   = TimeZone(identifier: "UTC")
    return f
}()

private let pceUtcCal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()
