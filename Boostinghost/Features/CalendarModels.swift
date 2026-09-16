import Foundation

// MARK: - GET /api/pricing/calendar?from=YYYY-MM-DD&to=YYYY-MM-DD&agency=all
//
// Response shape (camelCase — matches convertFromSnakeCase):
// { from, to, properties: { "<propertyId>": {
//     basePrice, weekendPrice,
//     prices: { "YYYY-MM-DD": Double },
//     booked:  [{ start, end, guest, uid, platform }],
//     blocked: [{ start, end, uid, reason }]
// } } }

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

    func price(for dayKey: String, isWeekend: Bool) -> Double? {
        if let custom = prices?[dayKey] { return custom }
        return isWeekend ? (weekendPrice ?? basePrice) : basePrice
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
