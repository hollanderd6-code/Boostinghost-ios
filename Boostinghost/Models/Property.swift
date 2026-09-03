import Foundation

// MARK: - Property
//
// The backend mixes camelCase and snake_case for the same field; convertFromSnakeCase
// in APIClient handles both automatically (snake_case → camelCase, camelCase passthrough).
// Numeric fields arrive as String OR Number depending on the record → flexDouble / flexInt.
// amenities / houseRules / practicalInfo are excluded here (object-or-JSON-string; add
// when building the Properties screen with FlexJSON support).

struct Property: Decodable, Identifiable {

    // MARK: - Identity
    let id: String
    let name: String
    let internalName: String?
    let color: String?
    let address: String?
    let photoUrl: String?

    // MARK: - Capacity
    let maxGuests: Int?      // "maxGuests" in form, "capacity" in DB
    let bedrooms: Int?
    let beds: Int?
    let bathrooms: Int?

    // MARK: - Schedule
    let arrivalTime: String?
    let departureTime: String?
    let minNights: Int?

    // MARK: - Pricing (String-or-Number in the API)
    let basePrice: Double?
    let weekendPrice: Double?
    let cleaningFee: Double?
    let touristTax: Double?           // "touristTaxPerNight" in form, "touristTax" in DB
    let depositAmount: Double?        // arrives as "0" (String) on new properties
    let depositReleaseDays: Int?

    // MARK: - Commissions (percentage, String-or-Number)
    let conciergePct: Double?         // "conciergePct" / "concierge_commission"
    let airbnbCommissionPct: Double?  // "airbnbCommissionPct" / "airbnb_commission"
    let bookingCommissionPct: Double? // "bookingCommissionPct" / "booking_commission"

    // MARK: - Access
    let accessCode: String?
    let accessInstructions: String?
    let wifiName: String?
    let wifiPassword: String?

    // MARK: - Links & relations
    let ownerId: String?              // String ObjectId or Int FK
    let welcomeBookUrl: String?       // "welcomeBookUrl" / "welcomeUrl"
    let autoResponsesEnabled: Bool?

    // MARK: - Decoding

    private enum CodingKeys: String, CodingKey {
        // Identity
        case id, _id = "_id"
        case name, internalName, color, address
        case photo, photoUrl
        // Capacity — dual-naming: form = maxGuests, DB column = capacity
        case capacity, maxGuests
        case bedrooms, beds, bathrooms
        // Schedule
        case arrivalTime, departureTime, minNights
        // Pricing
        case basePrice, weekendPrice, cleaningFee
        case touristTax, touristTaxPerNight
        case depositAmount, depositReleaseDays
        // Commissions — dual-naming: form name vs DB column name
        case conciergePct, conciergeCommission
        case airbnbCommissionPct, airbnbCommission
        case bookingCommissionPct, bookingCommission
        // Access
        case accessCode, accessInstructions, wifiName, wifiPassword
        // Links
        case ownerId, welcomeBookUrl, welcomeUrl, autoResponsesEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // id: MongoDB _id (string) takes priority, then integer or string id field
        if let v = c.flexString(forKey: ._id) {
            id = v
        } else if let v = c.flexString(forKey: .id) {
            id = v
        } else {
            id = ""
        }

        name             = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        internalName     = try? c.decodeIfPresent(String.self, forKey: .internalName)
        color            = try? c.decodeIfPresent(String.self, forKey: .color)
        address          = try? c.decodeIfPresent(String.self, forKey: .address)
        photoUrl         = (try? c.decodeIfPresent(String.self, forKey: .photoUrl))
                        ?? (try? c.decodeIfPresent(String.self, forKey: .photo))

        // Capacity: form sends maxGuests, DB column is capacity
        maxGuests        = c.flexInt(forKey: .maxGuests) ?? c.flexInt(forKey: .capacity)
        bedrooms         = c.flexInt(forKey: .bedrooms)
        beds             = c.flexInt(forKey: .beds)
        bathrooms        = c.flexInt(forKey: .bathrooms)

        arrivalTime      = try? c.decodeIfPresent(String.self, forKey: .arrivalTime)
        departureTime    = try? c.decodeIfPresent(String.self, forKey: .departureTime)
        minNights        = c.flexInt(forKey: .minNights)

        basePrice        = c.flexDouble(forKey: .basePrice)
        weekendPrice     = c.flexDouble(forKey: .weekendPrice)
        cleaningFee      = c.flexDouble(forKey: .cleaningFee)
        // Form sends touristTaxPerNight; DB column is touristTax
        touristTax       = c.flexDouble(forKey: .touristTaxPerNight)
                        ?? c.flexDouble(forKey: .touristTax)
        depositAmount    = c.flexDouble(forKey: .depositAmount)
        depositReleaseDays = c.flexInt(forKey: .depositReleaseDays)

        // Form sends conciergePct; DB column is concierge_commission → conciergeCommission
        conciergePct     = c.flexDouble(forKey: .conciergePct)
                        ?? c.flexDouble(forKey: .conciergeCommission)
        airbnbCommissionPct  = c.flexDouble(forKey: .airbnbCommissionPct)
                            ?? c.flexDouble(forKey: .airbnbCommission)
        bookingCommissionPct = c.flexDouble(forKey: .bookingCommissionPct)
                            ?? c.flexDouble(forKey: .bookingCommission)

        accessCode         = try? c.decodeIfPresent(String.self, forKey: .accessCode)
        accessInstructions = try? c.decodeIfPresent(String.self, forKey: .accessInstructions)
        wifiName           = try? c.decodeIfPresent(String.self, forKey: .wifiName)
        wifiPassword       = try? c.decodeIfPresent(String.self, forKey: .wifiPassword)

        ownerId            = c.flexString(forKey: .ownerId)
        welcomeBookUrl     = (try? c.decodeIfPresent(String.self, forKey: .welcomeBookUrl))
                          ?? (try? c.decodeIfPresent(String.self, forKey: .welcomeUrl))
        autoResponsesEnabled = try? c.decodeIfPresent(Bool.self, forKey: .autoResponsesEnabled)
    }
}

// MARK: - API response envelopes

struct PropertiesResponse: Decodable {
    let properties: [Property]?
}

// MARK: - PropertyGroup

struct PropertyGroup: Decodable, Identifiable {
    let id: String   // tolerant: handles PG Int or MongoDB string ID
    let name: String

    private enum CodingKeys: String, CodingKey { case id, name }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id   = c.flexString(forKey: .id) ?? ""
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
    }
}

struct PropertyGroupsResponse: Decodable {
    let groups: [PropertyGroup]?
}
