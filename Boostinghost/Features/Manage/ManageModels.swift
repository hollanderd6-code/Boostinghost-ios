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
    // Champs trial — tous optionnels pour rester backward-compatible
    let status:          String?
    let daysRemaining:   Int?
    let trialEndDate:    String?
    let displayMessage:  String?
    let showAlert:       Bool?

    init(from decoder: Decoder) throws {
        let c             = try decoder.container(keyedBy: CodingKeys.self)
        planType          = try? c.decodeIfPresent(String.self, forKey: .planType)
        propertiesUsed    = c.flexInt(forKey: .propertiesUsed)
        propertiesLimit   = c.flexInt(forKey: .propertiesLimit)
        currentPeriodEnd  = try? c.decodeIfPresent(String.self, forKey: .currentPeriodEnd)
        status            = try? c.decodeIfPresent(String.self, forKey: .status)
        daysRemaining     = c.flexInt(forKey: .daysRemaining)
        trialEndDate      = try? c.decodeIfPresent(String.self, forKey: .trialEndDate)
        displayMessage    = try? c.decodeIfPresent(String.self, forKey: .displayMessage)
        showAlert         = try? c.decodeIfPresent(Bool.self,   forKey: .showAlert)
    }

    private enum CodingKeys: String, CodingKey {
        case planType, propertiesUsed, propertiesLimit, currentPeriodEnd
        case status, daysRemaining, trialEndDate, displayMessage, showAlert
    }

    // MARK: - Trial helpers

    var isTrial: Bool { status == "trial" || status == "trialing" }

    // Backend showAlert = true quand daysRemaining <= 3 (source de vérité).
    // Fallback local si le champ est absent (vieille version serveur).
    var shouldShowTrialBanner: Bool {
        guard isTrial else { return false }
        if let alert = showAlert { return alert }
        return (daysRemaining ?? Int.max) <= 3
    }
}

#if DEBUG
extension SubscriptionStatus {
    init(status: String?, daysRemaining: Int?, trialEndDate: String? = nil,
         displayMessage: String? = nil, showAlert: Bool? = nil,
         planType: String? = nil, propertiesUsed: Int? = nil,
         propertiesLimit: Int? = nil, currentPeriodEnd: String? = nil) {
        self.status = status
        self.daysRemaining = daysRemaining
        self.trialEndDate = trialEndDate
        self.displayMessage = displayMessage
        self.showAlert = showAlert
        self.planType = planType
        self.propertiesUsed = propertiesUsed
        self.propertiesLimit = propertiesLimit
        self.currentPeriodEnd = currentPeriodEnd
    }
}
#endif
