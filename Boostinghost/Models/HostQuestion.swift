import Foundation

// MARK: - GET /api/host-questions/pending

struct HostQuestionsResponse: Decodable {
    let questions: [HostQuestion]
}

// MARK: - Question d'arbitrage voyageur

struct HostQuestion: Decodable, Identifiable, Equatable {

    let id: Int
    let conversationId: Int
    let propertyId: String?
    let guestName: String?
    let question: String?
    let guestMessage: String?
    let language: String?
    // "factual" | "schedule"
    let kind: String?
    let meta: HostQuestionMeta?
    let status: String?
    let createdAt: String?
    // Enrichi par le polling (JOIN nuits adjacentes)
    let prevCheckout: String?
    let nextCheckin: String?

    // No raw values — convertFromSnakeCase maps conversation_id→conversationId, etc.
    private enum CodingKeys: CodingKey {
        case id, conversationId, propertyId, guestName, question, guestMessage
        case language, kind, meta, status, createdAt, prevCheckout, nextCheckin
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(Int.self, forKey: .id)
        conversationId = try c.decode(Int.self, forKey: .conversationId)
        propertyId     = c.flexString(forKey: .propertyId)
        guestName      = try c.decodeIfPresent(String.self, forKey: .guestName)
        question       = try c.decodeIfPresent(String.self, forKey: .question)
        guestMessage   = try c.decodeIfPresent(String.self, forKey: .guestMessage)
        language       = try c.decodeIfPresent(String.self, forKey: .language)
        kind           = try c.decodeIfPresent(String.self, forKey: .kind)
        // meta peut arriver comme objet inline ou chaîne JSON (JSONB)
        meta           = c.flexDecodeJSON(HostQuestionMeta.self, forKey: .meta)
        status         = try c.decodeIfPresent(String.self, forKey: .status)
        createdAt      = try c.decodeIfPresent(String.self, forKey: .createdAt)
        prevCheckout   = try c.decodeIfPresent(String.self, forKey: .prevCheckout)
        nextCheckin    = try c.decodeIfPresent(String.self, forKey: .nextCheckin)
    }

    static func == (lhs: HostQuestion, rhs: HostQuestion) -> Bool { lhs.id == rhs.id }
}

// MARK: - Métadonnées JSONB

struct HostQuestionMeta: Decodable {
    let propertyName: String?
    let checkin: String?
    let checkout: String?
    // Disponibilité des nuits adjacentes — peut arriver Bool ou "true"/"false"
    let freeBefore: Bool?
    let freeAfter: Bool?
    // Schedule kind
    let type: String?      // "early_checkin" | "late_checkout"
    let reqLabel: String?
    let refLabel: String?

    // No raw values — convertFromSnakeCase maps property_name→propertyName, etc.
    private enum CodingKeys: CodingKey {
        case propertyName, checkin, checkout, freeBefore, freeAfter, type, reqLabel, refLabel
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        propertyName = try c.decodeIfPresent(String.self, forKey: .propertyName)
        checkin      = try c.decodeIfPresent(String.self, forKey: .checkin)
        checkout     = try c.decodeIfPresent(String.self, forKey: .checkout)
        if let b = try? c.decodeIfPresent(Bool.self, forKey: .freeBefore) {
            freeBefore = b
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .freeBefore) {
            freeBefore = s.lowercased() == "true"
        } else {
            freeBefore = nil
        }
        if let b = try? c.decodeIfPresent(Bool.self, forKey: .freeAfter) {
            freeAfter = b
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .freeAfter) {
            freeAfter = s.lowercased() == "true"
        } else {
            freeAfter = nil
        }
        type     = try c.decodeIfPresent(String.self, forKey: .type)
        reqLabel = try c.decodeIfPresent(String.self, forKey: .reqLabel)
        refLabel = try c.decodeIfPresent(String.self, forKey: .refLabel)
    }
}

// MARK: - POST /api/host-questions/:id/answer

struct HostQuestionAnswerResponse: Decodable {
    let success: Bool?
    let sent: Bool?
    let message: String?
}
