import Foundation

// MARK: - Réponse GET /api/aujourdhui/etats

struct TodayResponse: Decodable {
    let date: String
    let compteurs: Compteurs
    let arrivees: [Arrivee]
    let departs: [Depart]

    struct Compteurs: Decodable {
        let arrivees: Int
        /// hold + pending_approval (correction production 1 sept 2026)
        let enAttente: Int?
        let departs: Int
        let aTraiter: Int

        private enum CodingKeys: String, CodingKey {
            case arrivees, enAttente, departs, aTraiter
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            arrivees  = c.flexInt(forKey: .arrivees)  ?? 0
            enAttente = c.flexInt(forKey: .enAttente)
            departs   = c.flexInt(forKey: .departs)   ?? 0
            aTraiter  = c.flexInt(forKey: .aTraiter)  ?? 0
        }
    }
}

// MARK: - Arrivée

struct Arrivee: Decodable, Identifiable {
    var id: String { reservationUid }

    let reservationUid: String
    let conversationId: Int?
    let propertyId: String?
    let propertyName: String
    let propertyAddress: String?
    let guestName: String
    let guestPhone: String?
    let platform: String?
    let arrivalTime: String?
    let nights: Int?
    let guests: Int?
    let unreadCount: Int?
    let escalated: Bool?
    let aiDisabled: Bool?
    let blocking: [String]
    let status: String?

    var isUrgent: Bool { !blocking.isEmpty }

    private enum CodingKeys: String, CodingKey {
        case reservationUid, conversationId, propertyId, propertyName, propertyAddress
        case guestName, guestPhone, platform, arrivalTime, nights, guests
        case unreadCount, escalated, aiDisabled, blocking, status
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reservationUid  = try c.decode(String.self, forKey: .reservationUid)
        conversationId  = c.flexInt(forKey: .conversationId)
        propertyId      = try c.decodeIfPresent(String.self, forKey: .propertyId)
        propertyName    = try c.decode(String.self, forKey: .propertyName)
        propertyAddress = try c.decodeIfPresent(String.self, forKey: .propertyAddress)
        guestName       = try c.decode(String.self, forKey: .guestName)
        guestPhone      = try c.decodeIfPresent(String.self, forKey: .guestPhone)
        platform        = try c.decodeIfPresent(String.self, forKey: .platform)
        arrivalTime     = try c.decodeIfPresent(String.self, forKey: .arrivalTime)
        nights          = c.flexInt(forKey: .nights)
        guests          = c.flexInt(forKey: .guests)
        unreadCount     = c.flexInt(forKey: .unreadCount)
        escalated       = try c.decodeIfPresent(Bool.self, forKey: .escalated)
        aiDisabled      = try c.decodeIfPresent(Bool.self, forKey: .aiDisabled)
        blocking        = (try? c.decode([String].self, forKey: .blocking)) ?? []
        status          = try c.decodeIfPresent(String.self, forKey: .status)
    }
}

// MARK: - Départ

struct Depart: Decodable, Identifiable {
    var id: String { reservationUid }

    let reservationUid: String
    let conversationId: Int?
    let propertyName: String
    let guestName: String
    let platform: String?
    let departureTime: String?
    let nights: Int?
    let blocking: [String]?
    let status: String?

    private enum CodingKeys: String, CodingKey {
        case reservationUid, conversationId, propertyName, guestName
        case platform, departureTime, nights, blocking, status
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reservationUid = try c.decode(String.self, forKey: .reservationUid)
        conversationId = c.flexInt(forKey: .conversationId)
        propertyName   = try c.decode(String.self, forKey: .propertyName)
        guestName      = try c.decode(String.self, forKey: .guestName)
        platform       = try c.decodeIfPresent(String.self, forKey: .platform)
        departureTime  = try c.decodeIfPresent(String.self, forKey: .departureTime)
        nights         = c.flexInt(forKey: .nights)
        blocking       = try c.decodeIfPresent([String].self, forKey: .blocking)
        status         = try c.decodeIfPresent(String.self, forKey: .status)
    }
}

// MARK: - Réponse GET /api/cleaning/assignments

struct CleaningAssignmentsResponse: Decodable {
    let assignments: [CleaningAssignment]?
}

struct CleaningAssignment: Decodable, Identifiable {
    // UUID stable généré localement — non issu du JSON
    var id: UUID = UUID()
    let reservationKey: String?
    let propertyName: String
    let cleanerName: String
    let cleanerPhone: String?
    let windowStart: String?
    let windowEnd: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case reservationKey, propertyName, cleanerName, cleanerPhone
        case windowStart, windowEnd, status
    }
}
