import Foundation

// MARK: - Réponse GET /api/chat/conversations

struct ConversationsResponse: Decodable {
    let success: Bool?
    let conversations: [Conversation]?
}

// MARK: - Conversation

struct Conversation: Decodable, Identifiable {
    let id: Int

    // Conversation state
    let status: String?
    let escalated: Bool?
    let aiDisabled: Bool?
    let platform: String?

    // Guest
    let guestDisplayName: String?
    let guestInitial: String?

    // Property
    let propertyId: String?
    let propertyName: String?

    // Reservation
    let reservationStartDate: String?

    // Last message
    let unreadCount: Int?
    let lastMessage: String?
    let lastMessageTime: String?

    // T3 — true when owner_suggestion is non-empty AND owner_suggestion_status == 'pending'
    let hasSuggestion: Bool?
    // Non-null → Airbnb/Booking reservation; route d'envoi = send-platform
    let channexBookingId: String?

    private enum CodingKeys: String, CodingKey {
        case id, status, escalated, aiDisabled, platform
        case guestDisplayName, guestInitial, propertyId, propertyName
        case reservationStartDate, unreadCount, lastMessage, lastMessageTime
        case hasSuggestion, channexBookingId
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        escalated = try c.decodeIfPresent(Bool.self, forKey: .escalated)
        aiDisabled = try c.decodeIfPresent(Bool.self, forKey: .aiDisabled)
        platform = try c.decodeIfPresent(String.self, forKey: .platform)
        guestDisplayName = try c.decodeIfPresent(String.self, forKey: .guestDisplayName)
        guestInitial = try c.decodeIfPresent(String.self, forKey: .guestInitial)
        propertyId = try c.decodeIfPresent(String.self, forKey: .propertyId)
        propertyName = try c.decodeIfPresent(String.self, forKey: .propertyName)
        reservationStartDate = try c.decodeIfPresent(String.self, forKey: .reservationStartDate)
        unreadCount = c.flexInt(forKey: .unreadCount)
        lastMessage = try c.decodeIfPresent(String.self, forKey: .lastMessage)
        lastMessageTime = try c.decodeIfPresent(String.self, forKey: .lastMessageTime)
        hasSuggestion = try c.decodeIfPresent(Bool.self, forKey: .hasSuggestion)
        channexBookingId = try c.decodeIfPresent(String.self, forKey: .channexBookingId)
    }
}

extension Conversation: Hashable {
    static func == (lhs: Conversation, rhs: Conversation) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
