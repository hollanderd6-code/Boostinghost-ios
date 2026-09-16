import Foundation

// MARK: - Property
//
// The backend mixes camelCase and snake_case for the same field; convertFromSnakeCase
// in APIClient handles both automatically (snake_case → camelCase, camelCase passthrough).
// Numeric fields arrive as String OR Number depending on the record → flexDouble / flexInt.
// amenities/houseRules/practicalInfo arrive as object, JSON string, or array — decoded via flexDecodeJSON.

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

    // MARK: - Platform connectivity (for AccountSheet platform count)
    let channexEnabled: Bool?         // OTA channel via Channex
    let channexPropertyId: String?    // set once connect-property succeeds; nil = not yet connected
    let icalUrlsRaw: String?          // JSON-encoded array of iCal URLs (may be "[]" or null)
    let icalUrls: [ICalEntry]?        // decoded array from icalUrlsRaw or inline array
    let lastIcalSyncAt: String?       // ISO date of last cron pass, or null
    let icalSyncStatus: [String: ICalSyncInfo]? // per-URL sync state

    // MARK: - Livret content (object-or-JSON-string, decoded via flexDecodeJSON)
    let amenities: Amenities?
    let houseRules: HouseRules?
    let practicalInfo: PracticalInfo?

    // MARK: - IA & réponses rapides
    let arrivalMessage: String?
    let customAutoResponses: [CustomAutoResponse]?  // Q&R personnalisées (JSONB)
    let quickReplies: [QuickReply]?                 // [{ title, text }], max 5

    // MARK: - Upsell (Prestations payantes — colonnes de la table properties)
    let lateCheckoutEnabled: Bool?
    let lateCheckoutToleranceMinutes: Int?
    let lateCheckoutPricePerHour: Double?
    let lateCheckoutMaxMinutes: Int?
    let earlyCheckinEnabled: Bool?
    let earlyCheckinToleranceMinutes: Int?
    let earlyCheckinPricePerHour: Double?
    let earlyCheckinMaxMinutes: Int?
    let welcomeBasketEnabled: Bool?
    let welcomeBasketPrice: Double?
    let welcomeBasketDescription: String?

    // MARK: - Outil de pricing externe
    let externalPricing: Bool?

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
        // Platform connectivity
        case channexEnabled, channexPropertyId
        case icalUrls, lastIcalSyncAt, icalSyncStatus
        // Livret
        case amenities, houseRules, practicalInfo
        // IA & réponses rapides
        case arrivalMessage, customAutoResponses, quickReplies
        // Upsell
        case lateCheckoutEnabled, lateCheckoutToleranceMinutes
        case lateCheckoutPricePerHour, lateCheckoutMaxMinutes
        case earlyCheckinEnabled, earlyCheckinToleranceMinutes
        case earlyCheckinPricePerHour, earlyCheckinMaxMinutes
        case welcomeBasketEnabled, welcomeBasketPrice, welcomeBasketDescription
        // Plateformes
        case externalPricing
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

        channexEnabled     = try? c.decodeIfPresent(Bool.self,   forKey: .channexEnabled)
        channexPropertyId  = c.flexString(forKey: .channexPropertyId)
        icalUrlsRaw        = try? c.decodeIfPresent(String.self, forKey: .icalUrls)
        icalUrls           = c.flexDecodeJSON([ICalEntry].self, forKey: .icalUrls)
        lastIcalSyncAt     = try? c.decodeIfPresent(String.self, forKey: .lastIcalSyncAt)
        icalSyncStatus     = try? c.decodeIfPresent([String: ICalSyncInfo].self, forKey: .icalSyncStatus)

        amenities     = c.flexDecodeJSON(Amenities.self,     forKey: .amenities)
        houseRules    = c.flexDecodeJSON(HouseRules.self,    forKey: .houseRules)
        practicalInfo = c.flexDecodeJSON(PracticalInfo.self, forKey: .practicalInfo)

        arrivalMessage      = try? c.decodeIfPresent(String.self, forKey: .arrivalMessage)
        customAutoResponses = c.flexDecodeJSON([CustomAutoResponse].self, forKey: .customAutoResponses)
        quickReplies        = c.flexDecodeJSON([QuickReply].self, forKey: .quickReplies)

        lateCheckoutEnabled          = try? c.decodeIfPresent(Bool.self, forKey: .lateCheckoutEnabled)
        lateCheckoutToleranceMinutes = c.flexInt(forKey: .lateCheckoutToleranceMinutes)
        lateCheckoutPricePerHour     = c.flexDouble(forKey: .lateCheckoutPricePerHour)
        lateCheckoutMaxMinutes       = c.flexInt(forKey: .lateCheckoutMaxMinutes)
        earlyCheckinEnabled          = try? c.decodeIfPresent(Bool.self, forKey: .earlyCheckinEnabled)
        earlyCheckinToleranceMinutes = c.flexInt(forKey: .earlyCheckinToleranceMinutes)
        earlyCheckinPricePerHour     = c.flexDouble(forKey: .earlyCheckinPricePerHour)
        earlyCheckinMaxMinutes       = c.flexInt(forKey: .earlyCheckinMaxMinutes)
        welcomeBasketEnabled         = try? c.decodeIfPresent(Bool.self, forKey: .welcomeBasketEnabled)
        welcomeBasketPrice           = c.flexDouble(forKey: .welcomeBasketPrice)
        welcomeBasketDescription     = try? c.decodeIfPresent(String.self, forKey: .welcomeBasketDescription)

        externalPricing = try? c.decodeIfPresent(Bool.self, forKey: .externalPricing)
    }
}

// MARK: - API response envelopes

struct PropertiesResponse: Decodable {
    let properties: [Property]?
}

struct PropertyUpdateResponse: Decodable {
    let property: Property
}

// MARK: - PropertyGroup

struct PropertyGroup: Decodable, Identifiable {
    let id: String   // tolerant: handles PG Int or MongoDB string ID
    let name: String
    let propertyIds: [String]

    private enum CodingKeys: String, CodingKey { case id, name, propertyIds }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = c.flexString(forKey: .id) ?? ""
        name        = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        propertyIds = (try? c.decodeIfPresent([String].self, forKey: .propertyIds)) ?? []
    }
}

struct PropertyGroupsResponse: Decodable {
    let groups: [PropertyGroup]?
}

// MARK: - QuickReply

struct QuickReply: Decodable {
    let title: String
    let text: String
}

// MARK: - CustomAutoResponse (Q&R personnalisées — colonne custom_auto_responses JSONB)

struct CustomAutoResponse: Decodable {
    let keywords: String   // mots-clés déclencheurs, séparés par des virgules
    let response: String   // texte envoyé au voyageur
}

// MARK: - PropertyFact (table property_facts — GET /api/properties/:id/facts)

struct PropertyFact: Decodable {
    let id: Int
    let question: String
    let answer: Bool?
    let detail: String?
}

struct PropertyFactsResponse: Decodable {
    let facts: [PropertyFact]
}

// MARK: - PropertyMarkupsResponse (GET /api/properties/:id/markups)

struct PropertyMarkupsResponse: Decodable {
    let markups: [String: Double]   // clé absente = pas de majoration
    let codes: [String: String]     // tous les codes connus → libellé affichable
}

// MARK: - Upsell / Markups / Facts additional responses

struct MarkupSaveResponse: Decodable {
    let markups: [String: Double]
}

struct PropertyFactAddResponse: Decodable {
    let fact: PropertyFact
}

// MARK: - OwnerClient (GET /api/owner-clients → { clients: [] })
// is_agency_client: true → id préfixé "agency_client_N", coordonnées modifiables via PATCH override (DELETE scopé au compte propre)

struct OwnerClient: Decodable, Identifiable {
    let id: String
    let userId: Int?
    let clientType: String?
    let firstName: String?
    let lastName: String?
    let companyName: String?
    let email: String?
    let phone: String?
    let siret: String?
    let address: String?
    let postalCode: String?
    let city: String?
    let defaultCommissionRate: Double?  // arrives as String "20"
    let stripeAccountId: String?
    let useBhStripe: Bool?
    let isAgencyClient: Bool?
    let hasOverride: Bool?
    let originalId: String?
    let delegatorUserId: Int?
    let delegatorName: String?

    // Pour les agency clients, id = "agency_client_<real>". On extrait le vrai id
    // afin de croiser avec property.ownerId qui stocke l'entier réel (cf. clients.html l.2149).
    var matchingId: String {
        (originalId ?? id).replacingOccurrences(of: "agency_client_", with: "")
    }

    // Nom affiché : company_name si présent, sinon prénom + nom
    var displayName: String {
        if let cn = companyName, !cn.isEmpty { return cn }
        let parts = [firstName, lastName].compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? "Client sans nom" : parts.joined(separator: " ")
    }

    // Initiales : première lettre prénom + première lettre nom, sinon première lettre company_name
    var initials: String {
        if let cn = companyName, !cn.isEmpty { return String(cn.first!).uppercased() }
        var result = ""
        if let f = firstName?.first { result.append(f) }
        if let l = lastName?.first  { result.append(l) }
        return result.isEmpty ? "?" : result.uppercased()
    }

    private enum CodingKeys: String, CodingKey {
        case id, userId
        case clientType, firstName, lastName, companyName
        case email, phone, siret, address, postalCode, city
        case defaultCommissionRate
        case stripeAccountId, useBhStripe
        case isAgencyClient, hasOverride, originalId, delegatorUserId, delegatorName
    }

    init(from decoder: Decoder) throws {
        let c                 = try decoder.container(keyedBy: CodingKeys.self)
        id                    = c.flexString(forKey: .id) ?? ""
        userId                = c.flexInt(forKey: .userId)
        clientType            = try? c.decodeIfPresent(String.self, forKey: .clientType)
        firstName             = try? c.decodeIfPresent(String.self, forKey: .firstName)
        lastName              = try? c.decodeIfPresent(String.self, forKey: .lastName)
        companyName           = try? c.decodeIfPresent(String.self, forKey: .companyName)
        email                 = try? c.decodeIfPresent(String.self, forKey: .email)
        phone                 = try? c.decodeIfPresent(String.self, forKey: .phone)
        siret                 = try? c.decodeIfPresent(String.self, forKey: .siret)
        address               = try? c.decodeIfPresent(String.self, forKey: .address)
        postalCode            = try? c.decodeIfPresent(String.self, forKey: .postalCode)
        city                  = try? c.decodeIfPresent(String.self, forKey: .city)
        defaultCommissionRate = c.flexDouble(forKey: .defaultCommissionRate)
        stripeAccountId       = try? c.decodeIfPresent(String.self, forKey: .stripeAccountId)
        useBhStripe           = try? c.decodeIfPresent(Bool.self,   forKey: .useBhStripe)
        isAgencyClient        = try? c.decodeIfPresent(Bool.self,   forKey: .isAgencyClient)
        hasOverride           = try? c.decodeIfPresent(Bool.self,   forKey: .hasOverride)
        originalId            = c.flexString(forKey: .originalId)
        delegatorUserId       = c.flexInt(forKey: .delegatorUserId)
        delegatorName         = try? c.decodeIfPresent(String.self, forKey: .delegatorName)
    }
}

struct OwnerClientsResponse: Decodable {
    let clients: [OwnerClient]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clients = (try? c.decodeIfPresent([OwnerClient].self, forKey: .clients)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case clients }
}

// MARK: - ICalEntry  { url, platform } — colonne icalUrls du logement

struct ICalEntry: Codable, Identifiable {
    let url: String
    let platform: String
    var id: String { url }
}

// MARK: - ICalSyncInfo — état par URL dans icalSyncStatus

struct ICalSyncInfo: Decodable {
    let ok: Bool?
    let at: String?
    let events: Int?
    let error: String?
}

// MARK: - Hashable

extension Property: Hashable {
    static func == (lhs: Property, rhs: Property) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Livret content types

struct Amenities: Decodable {
    let draps: Bool?
    let serviettes: Bool?
    let cuisineEquipee: Bool?
    let laveLinge: Bool?
    let laveVaisselle: Bool?
    let television: Bool?
    let parking: Bool?
    let climatisation: Bool?
    let custom: [String]?

    var hasAny: Bool {
        [draps, serviettes, cuisineEquipee, laveLinge,
         laveVaisselle, television, parking, climatisation]
            .contains { $0 == true }
    }

    var summary: String {
        var names: [String] = []
        if draps          == true { names.append("draps") }
        if serviettes     == true { names.append("serviettes") }
        if cuisineEquipee == true { names.append("cuisine") }
        if laveLinge      == true { names.append("lave-linge") }
        if laveVaisselle  == true { names.append("lave-vaisselle") }
        if television     == true { names.append("TV") }
        if parking        == true { names.append("parking") }
        if climatisation  == true { names.append("clim") }
        return names.isEmpty ? "—" : names.joined(separator: " · ")
    }
}

struct HouseRules: Decodable {
    let animaux: Bool?
    let fumeurs: Bool?
    let fetes: Bool?
    let enfants: Bool?
    let custom: [String]?

    var isDefined: Bool {
        animaux != nil || fumeurs != nil || fetes != nil || enfants != nil
    }
}

struct PracticalInfo: Decodable {
    let parkingDetails: String?
    let trashDay: String?
    let nearbyShops: String?
    let publicTransport: String?

    var hasAny: Bool {
        [parkingDetails, trashDay, nearbyShops, publicTransport]
            .contains { ($0 ?? "").isEmpty == false }
    }

    var summary: String {
        var names: [String] = []
        if let p = parkingDetails,  !p.isEmpty { names.append("parking") }
        if let t = trashDay,        !t.isEmpty { names.append("poubelles") }
        if let s = nearbyShops,     !s.isEmpty { names.append("commerces") }
        if let t = publicTransport, !t.isEmpty { names.append("transports") }
        return names.isEmpty ? "—" : names.joined(separator: " · ")
    }
}
