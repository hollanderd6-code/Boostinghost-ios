import Foundation

// MARK: - GET /api/support/conversation
// Retourne la conversation active (open/waiting) ou en crée une.
// Réponse : { conversation: { id, status, ... } }

struct SupportConversation: Decodable {
    let id: String
    let status: String
}

struct SupportConversationResponse: Decodable {
    let conversation: SupportConversation
}

// MARK: - GET /api/support/messages/:conversationId
// Réponse : { messages: [...] }
// POST /api/support/messages et POST /api/support/upload
// renvoient un objet message plat (RETURNING *).

struct SupportMessage: Decodable, Identifiable {
    let id: Int
    let senderType: String   // "user" | "admin"
    let senderName: String?
    let message: String
    let imageUrl: String?
    let createdAt: String

    var isFromUser: Bool { senderType == "user" }
}

struct SupportMessagesResponse: Decodable {
    let messages: [SupportMessage]
}
