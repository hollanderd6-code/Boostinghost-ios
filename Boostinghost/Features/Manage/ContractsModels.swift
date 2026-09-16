import Foundation

// MARK: - Contract list filter

enum ContractFilter: String, CaseIterable, Hashable {
    case sent    = "sent"
    case signed  = "signed"
    case expired = "expired"

    var label: String {
        switch self {
        case .sent:    return "En attente"
        case .signed:  return "Signés"
        case .expired: return "Expirés"
        }
    }
}

// MARK: - Nested JSONB data (contractType, owner info for mandats)

struct ContractData: Decodable {
    let contractType: String?
    let ownerFirstName: String?
    let ownerLastName: String?
}

// MARK: - Full contract model (GET /api/contrats)
// Fields extracted by the server from JSONB are snake_case in SQL but arrive
// camelCase after convertFromSnakeCase. totalPrice arrives as a String.
// NULL for mandats: guestFirstName/guestLastName/propertyName etc. may be nil.

struct Contract: Decodable, Identifiable {
    let id: String
    let status: String?
    let clientId: String?
    let reservationUid: String?
    let signTokenExpiresAt: String?
    let guestSignedAt: String?
    let createdAt: String?
    let guestFirstName: String?
    let guestLastName: String?
    let guestEmail: String?
    let propertyName: String?
    let checkin: String?
    let checkout: String?
    let totalPrice: Double?
    let contractData: ContractData?

    var isMandat: Bool { contractData?.contractType == "mandat" }
    var typeLabel: String { isMandat ? "Mandat de gestion" : "Contrat de location" }

    var signerFirstName: String? { isMandat ? contractData?.ownerFirstName : guestFirstName }
    var signerLastName: String?  { isMandat ? contractData?.ownerLastName  : guestLastName }

    var signerDisplayName: String {
        let parts = [signerFirstName, signerLastName].compactMap { $0 }.filter { !$0.isEmpty }
        let joined = parts.joined(separator: " ")
        return joined.isEmpty ? "—" : joined
    }

    private enum CodingKeys: CodingKey {
        case id, status, clientId, reservationUid, signTokenExpiresAt
        case guestSignedAt, createdAt, guestFirstName, guestLastName
        case guestEmail, propertyName, checkin, checkout, totalPrice, contractData
    }

    init(from decoder: Decoder) throws {
        let c               = try decoder.container(keyedBy: CodingKeys.self)
        id                  = c.flexString(forKey: .id) ?? ""
        status              = try? c.decodeIfPresent(String.self, forKey: .status)
        clientId            = c.flexString(forKey: .clientId)
        reservationUid      = try? c.decodeIfPresent(String.self, forKey: .reservationUid)
        signTokenExpiresAt  = try? c.decodeIfPresent(String.self, forKey: .signTokenExpiresAt)
        guestSignedAt       = try? c.decodeIfPresent(String.self, forKey: .guestSignedAt)
        createdAt           = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        guestFirstName      = try? c.decodeIfPresent(String.self, forKey: .guestFirstName)
        guestLastName       = try? c.decodeIfPresent(String.self, forKey: .guestLastName)
        guestEmail          = try? c.decodeIfPresent(String.self, forKey: .guestEmail)
        propertyName        = try? c.decodeIfPresent(String.self, forKey: .propertyName)
        checkin             = try? c.decodeIfPresent(String.self, forKey: .checkin)
        checkout            = try? c.decodeIfPresent(String.self, forKey: .checkout)
        totalPrice          = c.flexDouble(forKey: .totalPrice)
        contractData        = try? c.decodeIfPresent(ContractData.self, forKey: .contractData)
    }
}

// MARK: - Paginated response

struct ContractsListResponse: Decodable {
    let contracts: [Contract]
    let total: Int
    let limit: Int
    let offset: Int

    private enum CodingKeys: CodingKey {
        case contracts, total, limit, offset
    }

    init(from decoder: Decoder) throws {
        let c     = try decoder.container(keyedBy: CodingKeys.self)
        contracts = (try? c.decode([Contract].self, forKey: .contracts)) ?? []
        total     = (try? c.decode(Int.self, forKey: .total)) ?? 0
        limit     = (try? c.decode(Int.self, forKey: .limit)) ?? 50
        offset    = (try? c.decode(Int.self, forKey: .offset)) ?? 0
    }
}
