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
    // Public UID — used to cross-reference with Arrivee.reservationUid
    let uid: String?
    let propertyId: String
    let guestName: String?
    let guestFirstName: String?
    let guestLastName: String?
    let guestEmail: String?
    let guestPhone: String?
    let guestCountry: String?
    let guestLanguage: String?
    let guestCity: String?
    let occupancyAdults: Int?
    let occupancyChildren: Int?
    let amountTotal: Double?
    let amountRooms: Double?
    let amountTaxes: Double?
    let amountCleaning: Double?
    let otaCommission: Double?
    let hostPayout: Double?
    let currency: String?
    let startDate: String        // "YYYY-MM-DD" — first 10 chars stripped at decode time
    let endDate: String          // "YYYY-MM-DD"
    let platform: String?
    let source: String?
    let otaName: String?
    let reservationType: String?
    let status: String?
    let notes: String?
    let otaNotes: String?
    let createdAt: String?
    let conversationId: Int?
    // JSONB Postgres — structure inconnue, décodé en dict date→prix (meilleure hypothèse).
    // Remplacer le type si la sortie debug montre autre chose.
    let daysBreakdown: [String: Double]?

    var isBlock: Bool {
        let s = (source          ?? "").lowercased()
        let p = (platform        ?? "").lowercased()
        let r = (reservationType ?? "").lowercased()
        return s == "block" || p == "block" || r == "block"
    }

    // Five observed forms in prod — substring match after stripping spaces and underscores:
    //   null/"guest_app" · "GUEST_APP"/"GUEST_APP" · "bhguest"/"bhguest"
    //   "HOLD"/"bhguest_hold" · "Boostinghost Guest"/"guest_app"
    var isBhGuest: Bool {
        let p = Self.bhNorm(platform)
        let s = Self.bhNorm(source)
        return p.contains("bhguest") || p.contains("guestapp")
            || s.contains("bhguest") || s.contains("guestapp")
    }

    // status == "hold" means the hold is active but not yet paid/confirmed.
    var isPending: Bool { status?.lowercased() == "hold" }

    // True when amountTotal ≈ hostPayout: OTA stored the host net, not the guest gross.
    var isNetAmounts: Bool {
        guard let hp = hostPayout, let at = amountTotal, let oc = otaCommission else { return false }
        return oc > 0 && abs(hp - at) < 0.01
    }

    /// Gross nightly amount to prefill "Loyer / Séjour" in invoice creation.
    /// Priority:
    ///   1. daysBreakdown sum — precise, valid for both net and gross reservations.
    ///   2. amountRooms when clearly distinct from amountTotal (cleaning not folded in).
    ///   3. Non-net fallback: amountTotal − amountCleaning (Booking-style).
    /// Returns nil when amounts are ambiguous (net reservation without breakdown).
    var invoiceRentAmount: Double? {
        // 1. Breakdown sum
        if let b = daysBreakdown, !b.isEmpty {
            let sum = b.values.reduce(0, +)
            if sum > 0 { return sum }
        }
        // Net without breakdown: cannot safely derive guest-facing nightly amount.
        if isNetAmounts { return nil }
        // 2. amountRooms distinct from amountTotal (cleaning not included)
        if let rooms = amountRooms {
            if let total = amountTotal, abs(rooms - total) < 0.01 {
                // rooms ≈ total → cleaning is likely folded in; fall through to case 3
            } else {
                return rooms
            }
        }
        // 3. amountTotal − cleaning (non-net, Booking-style)
        if let total = amountTotal {
            return total - (amountCleaning ?? 0)
        }
        return nil
    }

    private static func bhNorm(_ raw: String?) -> String {
        (raw ?? "").lowercased()
                   .replacingOccurrences(of: " ", with: "")
                   .replacingOccurrences(of: "_", with: "")
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
        case uid
        // Dual aliases: convertFromSnakeCase converts "property_id" → "propertyId" before matching
        case propertyId
        case guestName
        case guestFirstName, guestLastName, guestEmail, guestPhone
        case guestCountry, guestLanguage, guestCity
        case occupancyAdults, occupancyChildren
        case amountTotal, amountRooms, amountTaxes, amountCleaning
        case otaCommission, hostPayout, currency
        case startDate, endDate
        case platform, source, otaName
        case reservationType
        case status
        case notes, otaNotes, createdAt
        case conversationId
        case daysBreakdown
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = c.flexString(forKey: ._id) ?? c.flexString(forKey: .id) ?? ""
        uid        = c.flexString(forKey: .uid)
        propertyId = c.flexString(forKey: .propertyId) ?? ""
        guestName  = try? c.decodeIfPresent(String.self, forKey: .guestName)

        guestFirstName = try? c.decodeIfPresent(String.self, forKey: .guestFirstName)
        guestLastName  = try? c.decodeIfPresent(String.self, forKey: .guestLastName)
        guestEmail     = try? c.decodeIfPresent(String.self, forKey: .guestEmail)
        guestPhone     = try? c.decodeIfPresent(String.self, forKey: .guestPhone)
        guestCountry   = try? c.decodeIfPresent(String.self, forKey: .guestCountry)
        guestLanguage  = try? c.decodeIfPresent(String.self, forKey: .guestLanguage)
        guestCity      = try? c.decodeIfPresent(String.self, forKey: .guestCity)

        occupancyAdults   = c.flexInt(forKey: .occupancyAdults)
        occupancyChildren = c.flexInt(forKey: .occupancyChildren)

        amountTotal    = c.flexDouble(forKey: .amountTotal)
        amountRooms    = c.flexDouble(forKey: .amountRooms)
        amountTaxes    = c.flexDouble(forKey: .amountTaxes)
        amountCleaning = c.flexDouble(forKey: .amountCleaning)
        otaCommission  = c.flexDouble(forKey: .otaCommission)
        hostPayout     = c.flexDouble(forKey: .hostPayout)
        currency       = try? c.decodeIfPresent(String.self, forKey: .currency)

        let rawStart = (try? c.decodeIfPresent(String.self, forKey: .startDate)) ?? ""
        let rawEnd   = (try? c.decodeIfPresent(String.self, forKey: .endDate))   ?? ""
        startDate    = String(rawStart.prefix(10))
        endDate      = String(rawEnd.prefix(10))

        platform        = try? c.decodeIfPresent(String.self, forKey: .platform)
        source          = try? c.decodeIfPresent(String.self, forKey: .source)
        otaName         = try? c.decodeIfPresent(String.self, forKey: .otaName)
        reservationType = try? c.decodeIfPresent(String.self, forKey: .reservationType)
        status          = try? c.decodeIfPresent(String.self, forKey: .status)
        notes           = try? c.decodeIfPresent(String.self, forKey: .notes)
        otaNotes        = try? c.decodeIfPresent(String.self, forKey: .otaNotes)
        createdAt       = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        conversationId  = c.flexInt(forKey: .conversationId)
        daysBreakdown   = c.flexDoubleDict(forKey: .daysBreakdown)
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

// MARK: - Block body (POST /api/blocks?agency=all)

struct BlockBody: Encodable {
    let propertyId: String
    let start:      String   // "YYYY-MM-DD"
    let end:        String   // "YYYY-MM-DD" exclusive (jour après la dernière nuit bloquée)
    let reason:     String
}

// MARK: - Pricing rule body (POST /api/pricing/rules?agency=all)
// rule_type "min_stay" — upsert automatique côté serveur.

struct PricingRuleBody: Encodable {
    let propertyId:  String
    let name:        String
    let ruleType:    String
    let minNights:   Int
    let startDate:   String?
    let endDate:     String?
    let daysOfWeek:  [Int]?
    let priority:    Int?

    enum CodingKeys: String, CodingKey {
        case propertyId = "property_id"
        case name
        case ruleType   = "rule_type"
        case minNights  = "min_nights"
        case startDate  = "start_date"
        case endDate    = "end_date"
        case daysOfWeek = "days_of_week"
        case priority
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(propertyId, forKey: .propertyId)
        try c.encode(name,       forKey: .name)
        try c.encode(ruleType,   forKey: .ruleType)
        try c.encode(minNights,  forKey: .minNights)
        try c.encodeIfPresent(startDate,  forKey: .startDate)
        try c.encodeIfPresent(endDate,    forKey: .endDate)
        try c.encodeIfPresent(daysOfWeek, forKey: .daysOfWeek)
        try c.encodeIfPresent(priority,   forKey: .priority)
    }
}

// MARK: - Manual reservation body (POST /api/reservations/manual?agency=all)
// Only propertyId, start and end are required. nil fields are omitted from JSON.

struct ManualReservationBody: Encodable {
    let propertyId:      String
    let start:           String   // "YYYY-MM-DD"
    let end:             String   // "YYYY-MM-DD"
    let guestName:       String?
    let notes:           String?
    let platform:        String?
    let price:           Double?
    let phone:           String?
    let email:           String?
    let guestCountry:    String?
    let occupancyAdults: Int?
    let amountRooms:     Double?
    let amountCleaning:  Double?
    let amountTaxes:     Double?
    let otaCommission:   Double?

    enum CodingKeys: String, CodingKey {
        case propertyId, start, end, guestName, notes, platform, price, phone, email
        case guestCountry    = "guest_country"
        case occupancyAdults = "occupancy_adults"
        case amountRooms     = "amount_rooms"
        case amountCleaning  = "amount_cleaning"
        case amountTaxes     = "amount_taxes"
        case otaCommission   = "ota_commission"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(propertyId, forKey: .propertyId)
        try c.encode(start,      forKey: .start)
        try c.encode(end,        forKey: .end)
        try c.encodeIfPresent(guestName,       forKey: .guestName)
        try c.encodeIfPresent(notes,           forKey: .notes)
        try c.encodeIfPresent(platform,        forKey: .platform)
        try c.encodeIfPresent(price,           forKey: .price)
        try c.encodeIfPresent(phone,           forKey: .phone)
        try c.encodeIfPresent(email,           forKey: .email)
        try c.encodeIfPresent(guestCountry,    forKey: .guestCountry)
        try c.encodeIfPresent(occupancyAdults, forKey: .occupancyAdults)
        try c.encodeIfPresent(amountRooms,     forKey: .amountRooms)
        try c.encodeIfPresent(amountCleaning,  forKey: .amountCleaning)
        try c.encodeIfPresent(amountTaxes,     forKey: .amountTaxes)
        try c.encodeIfPresent(otaCommission,   forKey: .otaCommission)
    }
}

// MARK: - BHGuest hold body (POST /api/guest/hold)

struct BHGuestHoldBody: Encodable {
    let propertyId: String   // "property_id"
    let checkin:    String   // "YYYY-MM-DD"
    let checkout:   String   // "YYYY-MM-DD"
    let fixedPrice: Double?  // "fixed_price"
    let guestPhone: String?  // "guest_phone"
    let guestEmail: String?  // "guest_email"
    let sendSms:    Bool?    // "send_sms" — présent seulement en mode envoi automatique

    enum CodingKeys: String, CodingKey {
        case propertyId = "property_id"
        case checkin, checkout
        case fixedPrice = "fixed_price"
        case guestPhone = "guest_phone"
        case guestEmail = "guest_email"
        case sendSms    = "send_sms"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(propertyId, forKey: .propertyId)
        try c.encode(checkin,    forKey: .checkin)
        try c.encode(checkout,   forKey: .checkout)
        try c.encodeIfPresent(fixedPrice, forKey: .fixedPrice)
        try c.encodeIfPresent(guestPhone, forKey: .guestPhone)
        try c.encodeIfPresent(guestEmail, forKey: .guestEmail)
        try c.encodeIfPresent(sendSms,    forKey: .sendSms)
    }
}

// MARK: - BHGuest hold response

struct BHGuestHoldResponse: Decodable {
    let token:     String?   // { token } in the server response
    let holdToken: String?   // fallback for a renamed field
    let expiresAt: String?
    let smsSent:   Bool?
}
