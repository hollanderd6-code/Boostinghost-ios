import Foundation

// MARK: - GET /api/search?q=<text>&agency=all

struct SearchResultReservation: Decodable, Identifiable, Hashable {
    var id: String { uid }
    let uid: String
    let guestName: String?
    let startDate: String?
    let endDate: String?
    let propertyId: String?
    let platform: String?
}

struct SearchResultConversation: Decodable, Identifiable, Hashable {
    let id: Int
    let guestName: String?
    let platform: String?
    let propertyId: String?
    let reservationUid: String?
}

struct SearchResultProperty: Decodable, Identifiable, Hashable {
    let id: String
    let name: String?
    let internalName: String?

    var displayName: String { name ?? internalName ?? "Logement" }

    private enum CodingKeys: CodingKey {
        case id, name, internalName
    }

    init(from decoder: Decoder) throws {
        let c        = try decoder.container(keyedBy: CodingKeys.self)
        id           = c.flexString(forKey: .id) ?? ""
        name         = try? c.decodeIfPresent(String.self, forKey: .name)
        internalName = try? c.decodeIfPresent(String.self, forKey: .internalName)
    }
}

struct SearchResultOwnerInvoice: Decodable, Identifiable, Hashable {
    let id: String
    let invoiceNumber: String?
    let clientName: String?
    let totalTtc: Double?
    let status: String?
    let issueDate: String?

    private enum CodingKeys: CodingKey {
        case id, invoiceNumber, clientName, totalTtc, status, issueDate
    }

    init(from decoder: Decoder) throws {
        let c         = try decoder.container(keyedBy: CodingKeys.self)
        id            = c.flexString(forKey: .id) ?? ""
        invoiceNumber = try? c.decodeIfPresent(String.self, forKey: .invoiceNumber)
        clientName    = try? c.decodeIfPresent(String.self, forKey: .clientName)
        totalTtc      = c.flexDouble(forKey: .totalTtc)
        status        = try? c.decodeIfPresent(String.self, forKey: .status)
        issueDate     = try? c.decodeIfPresent(String.self, forKey: .issueDate)
    }
}

struct SearchResultVoyageurInvoice: Decodable, Hashable {
    let invoiceNumber: String?
    let clientName: String?
    let downloadUrl: String?
    let expired: Bool?
}

struct SearchResultOwnerClient: Decodable, Identifiable, Hashable {
    let id: String
    let clientType: String?
    let firstName: String?
    let lastName: String?
    let companyName: String?
    let email: String?

    var displayName: String {
        if let cn = companyName, !cn.isEmpty { return cn }
        let parts = [firstName, lastName].compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? "Client sans nom" : parts.joined(separator: " ")
    }

    var initials: String {
        if let cn = companyName, !cn.isEmpty { return String(cn.first!).uppercased() }
        var result = ""
        if let f = firstName?.first { result.append(f) }
        if let l = lastName?.first  { result.append(l) }
        return result.isEmpty ? "?" : result.uppercased()
    }

    private enum CodingKeys: CodingKey {
        case id, clientType, firstName, lastName, companyName, email
    }

    init(from decoder: Decoder) throws {
        let c       = try decoder.container(keyedBy: CodingKeys.self)
        id          = c.flexString(forKey: .id) ?? ""
        clientType  = try? c.decodeIfPresent(String.self, forKey: .clientType)
        firstName   = try? c.decodeIfPresent(String.self, forKey: .firstName)
        lastName    = try? c.decodeIfPresent(String.self, forKey: .lastName)
        companyName = try? c.decodeIfPresent(String.self, forKey: .companyName)
        email       = try? c.decodeIfPresent(String.self, forKey: .email)
    }
}

struct SearchResults: Decodable {
    let reservations: [SearchResultReservation]?
    let conversations: [SearchResultConversation]?
    let properties: [SearchResultProperty]?
    let ownerInvoices: [SearchResultOwnerInvoice]?
    let voyageurInvoices: [SearchResultVoyageurInvoice]?
    let ownerClients: [SearchResultOwnerClient]?

    var isEmpty: Bool {
        (reservations?.isEmpty ?? true)
            && (conversations?.isEmpty ?? true)
            && (properties?.isEmpty ?? true)
            && (ownerInvoices?.isEmpty ?? true)
            && (voyageurInvoices?.isEmpty ?? true)
            && (ownerClients?.isEmpty ?? true)
    }
}

struct SearchResponse: Decodable {
    let q: String?
    let results: SearchResults?
}

// MARK: - Extensions de construction depuis résultats de recherche

extension Conversation {
    init(fromSearch r: SearchResultConversation) {
        id                   = r.id
        status               = nil
        escalated            = nil
        aiDisabled           = nil
        platform             = r.platform
        guestDisplayName     = r.guestName
        guestInitial         = r.guestName?.first.map(String.init)
        propertyId           = r.propertyId
        propertyName         = nil
        reservationUid       = nil
        notes                = nil
        reservationStartDate = nil
        unreadCount          = nil
        lastMessage          = nil
        lastMessageTime      = nil
        hasSuggestion        = nil
        channexBookingId     = nil
    }
}

extension Arrivee {
    init(fromSearch r: SearchResultReservation) {
        reservationUid  = r.uid
        conversationId  = nil
        propertyId      = r.propertyId
        propertyName    = ""
        propertyAddress = nil
        guestName       = r.guestName ?? "Voyageur"
        guestPhone      = nil
        platform        = r.platform
        arrivalTime     = nil
        nights          = nil
        guests          = nil
        unreadCount     = nil
        escalated       = nil
        aiDisabled      = nil
        blocking        = []
        status          = nil
    }
}

extension OwnerClient {
    init(fromSearch r: SearchResultOwnerClient) {
        id                    = r.id
        userId                = nil
        clientType            = r.clientType
        firstName             = r.firstName
        lastName              = r.lastName
        companyName           = r.companyName
        email                 = r.email
        phone                 = nil
        siret                 = nil
        address               = nil
        postalCode            = nil
        city                  = nil
        defaultCommissionRate = nil
        stripeAccountId       = nil
        useBhStripe           = nil
        isAgencyClient        = nil
        hasOverride           = nil
        originalId            = nil
        delegatorUserId       = nil
        delegatorName         = nil
    }
}
