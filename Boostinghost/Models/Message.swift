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

    var isFromOwner: Bool { senderType == "owner" || senderType == "property" }
    var isBot: Bool { isBotResponse == true || isAutoResponse == true }
    var isSystem: Bool { false }
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
