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
    var escalated: Bool?
    var aiDisabled: Bool?
    let platform: String?

    // Guest
    let guestDisplayName: String?
    let guestInitial: String?

    // Property
    let propertyId: String?
    let propertyName: String?

    // Reservation — r.uid and r.notes from the reservations JOIN
    let reservationUid: String?
    let notes: String?

    // Last message
    let reservationStartDate: String?
    var unreadCount: Int?
    let lastMessage: String?
    let lastMessageTime: String?

    // T3 — true when owner_suggestion is non-empty AND owner_suggestion_status == 'pending'
    var hasSuggestion: Bool?
    // Non-null → Airbnb/Booking reservation; route d'envoi = send-platform
    let channexBookingId: String?

    private enum CodingKeys: String, CodingKey {
        case id, status, escalated, aiDisabled, platform
        case guestDisplayName, guestInitial, propertyId, propertyName
        case reservationUid, notes
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
        reservationUid = try c.decodeIfPresent(String.self, forKey: .reservationUid)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        reservationStartDate = try c.decodeIfPresent(String.self, forKey: .reservationStartDate)
        unreadCount = c.flexInt(forKey: .unreadCount)
        lastMessage = try c.decodeIfPresent(String.self, forKey: .lastMessage)
        lastMessageTime = try c.decodeIfPresent(String.self, forKey: .lastMessageTime)
        hasSuggestion = try c.decodeIfPresent(Bool.self, forKey: .hasSuggestion)
        channexBookingId = try c.decodeIfPresent(String.self, forKey: .channexBookingId)
    }
}

// Construit une Conversation minimale depuis une Arrivee, pour naviguer vers
// ConversationDetailView sans passer par la liste Messages.
// channexBookingId reste nil : l'envoi emprunte le chemin direct /api/chat/send.
// À revoir quand les détails de séjour seront accessibles depuis Today.
extension Conversation {
    init(arriveeId: Int, guestName: String, platform: String?, propertyName: String, escalated: Bool? = nil, aiDisabled: Bool? = nil) {
        self.id                  = arriveeId
        self.status              = nil
        self.escalated           = escalated
        self.aiDisabled          = aiDisabled
        self.platform            = platform
        self.guestDisplayName    = guestName
        self.guestInitial        = guestName.first.map(String.init)
        self.propertyId          = nil
        self.propertyName        = propertyName
        self.reservationUid      = nil
        self.notes               = nil
        self.reservationStartDate = nil
        self.unreadCount         = nil
        self.lastMessage         = nil
        self.lastMessageTime     = nil
        self.hasSuggestion       = nil
        self.channexBookingId    = nil
    }
}


extension Conversation: Hashable {
    static func == (lhs: Conversation, rhs: Conversation) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
