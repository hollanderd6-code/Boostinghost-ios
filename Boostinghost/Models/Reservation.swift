import Foundation

// MARK: - Reservation
//
// Tolerant decoding: dual aliases handled via explicit CodingKeys.
// convertFromSnakeCase in APIClient maps "start_date" → "startDate" before
// matching, so a single CodingKey covers both forms.
// "_id" is preserved as-is by convertFromSnakeCase (leading underscore).
//
// TEST: alias — init Reservation from {"start_date":"2026-09-19","end_date":"2026-09-21",
//   "property_id":"abc","guest_name":"Paul"} → startDate=="2026-09-19", propertyId=="abc"
// TEST: date without shift — parseDay("2026-09-19T00:00:00.000Z") must return
//   a Date whose UTC components are year 2026 month 9 day 19, NOT day 18.
// TEST: block via source — isBlock true when source=="BLOCK" or "block" or "Block"
// TEST: block via platform — isBlock true when platform=="BLOCK"
// TEST: block via reservation_type — isBlock true when reservation_type=="block"

struct Reservation: Decodable, Identifiable {
    let id: String
    let propertyId: String
    let guestName: String?
    let startDate: String        // "YYYY-MM-DD" — first 10 chars stripped at decode time
    let endDate: String          // "YYYY-MM-DD"
    let platform: String?
    let source: String?
    let reservationType: String?
    let status: String?

    var isBlock: Bool {
        let s = (source          ?? "").lowercased()
        let p = (platform        ?? "").lowercased()
        let r = (reservationType ?? "").lowercased()
        return s == "block" || p == "block" || r == "block"
    }

    var startDayDate: Date? { Self.parseDay(startDate) }
    var endDayDate:   Date? { Self.parseDay(endDate) }

    // Takes the first 10 chars and parses with a UTC formatter — never shifts the day.
    static func parseDay(_ raw: String) -> Date? {
        dayParser.date(from: String(raw.prefix(10)))
    }

    private static let dayParser: DateFormatter = {
        let f = DateFormatter()
        f.locale   = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private enum CodingKeys: String, CodingKey {
        // Both "_id" (MongoDB) and "id" (SQL) — convertFromSnakeCase preserves leading "_"
        case _id = "_id", id
        // Dual aliases: convertFromSnakeCase converts "property_id" → "propertyId" before matching
        case propertyId
        case guestName
        case startDate
        case endDate
        case platform, source
        case reservationType
        case status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = c.flexString(forKey: ._id) ?? c.flexString(forKey: .id) ?? ""
        propertyId = c.flexString(forKey: .propertyId) ?? ""
        guestName  = try? c.decodeIfPresent(String.self, forKey: .guestName)

        let rawStart = (try? c.decodeIfPresent(String.self, forKey: .startDate)) ?? ""
        let rawEnd   = (try? c.decodeIfPresent(String.self, forKey: .endDate))   ?? ""
        startDate    = String(rawStart.prefix(10))
        endDate      = String(rawEnd.prefix(10))

        platform        = try? c.decodeIfPresent(String.self, forKey: .platform)
        source          = try? c.decodeIfPresent(String.self, forKey: .source)
        reservationType = try? c.decodeIfPresent(String.self, forKey: .reservationType)
        status          = try? c.decodeIfPresent(String.self, forKey: .status)
    }
}

// MARK: - PropertySummary
//
// Comes from the "properties" array inside the /api/reservations envelope.
// Fields confirmed in 03-api-contracts.md and 04-routes-relevees.md.

struct PropertySummary: Decodable, Identifiable {
    let id: String
    let name: String
    let internalName: String?
    let arrivalTime: String?
    let departureTime: String?
    let color: String?

    var displayName: String { internalName.flatMap { $0.isEmpty ? nil : $0 } ?? name }

    private enum CodingKeys: String, CodingKey {
        case _id = "_id", id
        case name
        case internalName
        case arrivalTime
        case departureTime
        case color
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = c.flexString(forKey: ._id) ?? c.flexString(forKey: .id) ?? ""
        name          = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        internalName  = try? c.decodeIfPresent(String.self, forKey: .internalName)
        arrivalTime   = try? c.decodeIfPresent(String.self, forKey: .arrivalTime)
        departureTime = try? c.decodeIfPresent(String.self, forKey: .departureTime)
        color         = try? c.decodeIfPresent(String.self, forKey: .color)
    }
}

// MARK: - Envelopes

struct ReservationsResponse: Decodable {
    let reservations: [Reservation]?
    let properties:   [PropertySummary]?
    let lastSync:     String?
    let syncStatus:   String?
}

// MARK: - Block body (POST /api/blocks)

struct BlockBody: Encodable {
    let propertyId: String
    let start:      String   // "YYYY-MM-DD"
    let end:        String   // "YYYY-MM-DD"
    let reason:     String
}
