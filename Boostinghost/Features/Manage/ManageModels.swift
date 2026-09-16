import Foundation

// MARK: - PATCH /api/properties/:id  { icalUrls: [...] }

struct ICalPatchResponse: Decodable {
    let property: Property?
    let avertissement: String?  // avertissement renvoyé par le serveur (même clé que Channex)

    init(from decoder: Decoder) throws {
        let c         = try decoder.container(keyedBy: CodingKeys.self)
        property      = try? c.decodeIfPresent(Property.self,   forKey: .property)
        avertissement = try? c.decodeIfPresent(String.self, forKey: .avertissement)
    }

    private enum CodingKeys: CodingKey { case property, avertissement }
}

// MARK: - POST /api/sync/ical

struct SyncIcalResponse: Decodable {
    let success: Bool?
    let message: String?
}

// MARK: - POST /api/diffusion/sync-all

struct SyncDiffusionResponse: Decodable {
    let message: String?
    let count: Int?
}

// MARK: - POST /api/properties → { success, message, property: { id } }

struct PropertyCreateResponse: Decodable {
    let success: Bool?
    let message: String?
}

// MARK: - GET /api/subscription/status (périmètre compte propre, sans agency=all)

struct SubscriptionStatus: Decodable {
    let planType:        String?
    let propertiesUsed:  Int?
    let propertiesLimit: Int?
    // Relevé dans server.js:11219 — la réponse envoie exactement "currentPeriodEnd".
    let currentPeriodEnd: String?

    init(from decoder: Decoder) throws {
        let c             = try decoder.container(keyedBy: CodingKeys.self)
        planType          = try? c.decodeIfPresent(String.self, forKey: .planType)
        propertiesUsed    = c.flexInt(forKey: .propertiesUsed)
        propertiesLimit   = c.flexInt(forKey: .propertiesLimit)
        currentPeriodEnd  = try? c.decodeIfPresent(String.self, forKey: .currentPeriodEnd)
    }

    private enum CodingKeys: String, CodingKey {
        case planType, propertiesUsed, propertiesLimit, currentPeriodEnd
    }
}
