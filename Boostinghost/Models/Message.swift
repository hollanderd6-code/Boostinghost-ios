import Foundation

// MARK: - Message

struct Message: Decodable, Identifiable {
    let id: Int
    let conversationId: Int
    let senderType: String       // "guest" | "owner" | "property"
    let senderName: String?
    let message: String
    let isRead: Bool?
    let isBotResponse: Bool?
    let isAutoResponse: Bool?
    let createdAt: String?
    let readAt: String?
    let deliveredAt: String?
    let delivered: Bool?
    let deliveryError: String?

    var isFromOwner: Bool { senderType == "owner" || senderType == "property" }
    // "system" is the actual sender_type the backend uses for AI-generated responses.
    // is_bot_response / is_auto_response are always false in practice — do not rely on them.
    var isBot: Bool      { senderType == "system" }
    // Templates are sent as "property" messages with a sender_name prefixed "tpl_".
    var isTemplate: Bool { senderType == "property" && senderName?.hasPrefix("tpl_") == true }
    var isOutgoing: Bool { isFromOwner || isBot }
    var isSystem: Bool   { false }
}

// MARK: - Response wrappers

struct MessagesDetailResponse: Decodable {
    let success: Bool?
    let messages: [Message]?
    let conversation: Conversation?
}

struct SuggestionResponse: Decodable {
    let success: Bool?
    let suggestion: String?
}

struct GenericSuccess: Decodable {
    let success: Bool?
}

// MARK: - Request bodies

// MARK: - Toggle AI

struct ToggleAIResponse: Decodable {
    let success: Bool?
    let aiDisabled: Bool?
}

// MARK: - Template send

struct TemplateSendBody: Encodable {
    let conversationId: Int
    enum CodingKeys: String, CodingKey { case conversationId = "conversation_id" }
}

struct TemplateSendResponse: Decodable {
    let success: Bool?
}

// MARK: - Reservation note

struct NoteBody: Encodable {
    let notes: String
}

struct NoteResponse: Decodable {
    let success: Bool?
    let uid: String?
    let notes: String?
}

// MARK: - Suggestion

struct SuggestionStatusBody: Encodable {
    let status: String
}

struct SendPlatformBody: Encodable {
    let message: String
}

struct SendDirectBody: Encodable {
    let conversationId: Int
    let message: String
    let senderType: String
    let senderName: String

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case message
        case senderType    = "sender_type"
        case senderName    = "sender_name"
    }
}

// MARK: - Deposit link (quick-context + short-link)

struct QuickContextResponse: Decodable {
    let depositUrl: String?
    let depositAmountCents: Int?
}

struct ShortLinkBody: Encodable {
    let url: String
}

struct ShortLinkResponse: Decodable {
    let shortUrl: String?
}
