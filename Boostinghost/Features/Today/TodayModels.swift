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
    let guestName: String?
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
        guestName       = try c.decodeIfPresent(String.self, forKey: .guestName)
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
    let guestName: String?
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
        guestName      = try c.decodeIfPresent(String.self, forKey: .guestName)
        platform       = try c.decodeIfPresent(String.self, forKey: .platform)
        departureTime  = try c.decodeIfPresent(String.self, forKey: .departureTime)
        nights         = c.flexInt(forKey: .nights)
        blocking       = try c.decodeIfPresent([String].self, forKey: .blocking)
        status         = try c.decodeIfPresent(String.self, forKey: .status)
    }
}

// MARK: - Arrivee depuis un Départ (pour ouvrir ReservationDetailView depuis DepartCard)

extension Arrivee {
    init(fromDepart d: Depart) {
        reservationUid  = d.reservationUid
        conversationId  = d.conversationId
        propertyId      = nil
        propertyName    = d.propertyName
        propertyAddress = nil
        guestName       = d.guestName
        guestPhone      = nil
        platform        = d.platform
        arrivalTime     = nil
        nights          = d.nights
        guests          = nil
        unreadCount     = nil
        escalated       = nil
        aiDisabled      = nil
        blocking        = []
        status          = d.status
    }
}

// MARK: - Arrivée depuis une entrée du calendrier de prix (onglets Jour et Semaine)

extension Arrivee {
    init(calendarEntry entry: PricingCalendarEntry, property: PropertySummary) {
        reservationUid  = entry.uid ?? ""
        conversationId  = nil
        propertyId      = property.id
        propertyName    = property.displayName
        propertyAddress = nil
        guestName       = entry.guest ?? "Voyageur"
        guestPhone      = nil
        platform        = entry.isBhGuest ? "bhguest" : entry.platform
        arrivalTime     = property.arrivalTime
        nights          = entry.nights
        guests          = nil
        unreadCount     = nil
        escalated       = nil
        aiDisabled      = nil
        blocking        = []
        status          = nil
    }
}

// MARK: - Arrivée depuis une Reservation (onglet Mensuel)

extension Arrivee {
    init(reservation r: Reservation, properties: [PropertySummary]) {
        let prop        = properties.first { $0.id == r.propertyId }
        reservationUid  = r.uid ?? r.id
        conversationId  = r.conversationId
        propertyId      = r.propertyId
        propertyName    = prop?.displayName ?? r.propertyId
        propertyAddress = nil
        guestName       = r.guestName ?? "Voyageur"
        guestPhone      = r.guestPhone
        platform        = r.isBhGuest ? "bhguest" : r.platform
        arrivalTime     = prop?.arrivalTime
        nights          = { () -> Int? in
            guard let s = Reservation.parseDay(r.startDate),
                  let e = Reservation.parseDay(r.endDate) else { return nil }
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            return cal.dateComponents([.day], from: s, to: e).day
        }()
        guests          = {
            let t = (r.occupancyAdults ?? 0) + (r.occupancyChildren ?? 0)
            return t > 0 ? t : nil
        }()
        unreadCount     = nil
        escalated       = nil
        aiDisabled      = nil
        blocking        = []
        status          = r.status
    }
}

// MARK: - Réponse GET /api/cleaning/assignments

struct CleaningAssignmentsResponse: Decodable {
    let assignments: [CleaningAssignment]?
}

struct CleaningAssignment: Decodable, Identifiable {
    // UUID stable généré localement — non issu du JSON
    var id: UUID = UUID()
    let propertyId: String?
    let reservationKey: String?  // "<propertyId>_<startDate>_<endDate>" — sert à filtrer les ménages du jour
    let cleanerName: String?
    let cleanerPhone: String?
    let cleanerEmail: String?
    var windowStart: String?     // calculé post-décodage depuis property.departureTime
    var windowEnd: String?       // calculé post-décodage : arrivalTime si même-jour, sinon nil
    let status: String?          // "pending", "in_progress", "completed"
    let groupName: String?
    let propertyName: String?    // joint par le serveur ; priorité à resolvedPropertyName
    let isDefault: Bool?         // true = assignation virtuelle (non persistée)

    // Résolu post-décodage à partir de la liste des logements.
    var resolvedPropertyName: String?
    // Résolu post-décodage depuis checklistByKey (reservationKey → checklist.id).
    var checklistId: String? = nil

    enum CodingKeys: String, CodingKey {
        case propertyId, reservationKey, cleanerName, cleanerPhone, cleanerEmail
        case windowStart, windowEnd, status, groupName, propertyName, isDefault
    }
}
