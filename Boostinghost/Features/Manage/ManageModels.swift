import Foundation

// MARK: - GET /api/reservations-with-deposits (tableau nu, pas enveloppé)

struct ReservationWithDeposit: Decodable {
    let deposit: Deposit?

    struct Deposit: Decodable {
        let status: String?
    }
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
