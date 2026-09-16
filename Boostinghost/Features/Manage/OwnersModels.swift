import Foundation

// MARK: - GET /api/owner-invoices?agency=all

struct OwnerInvoice: Decodable, Identifiable {
    let id: String
    let invoiceNumber: String?
    let issueDate: String?
    let totalTtc: Double?
    let status: String?
    let clientId: String?
    let isCreditNote: Bool?
    let originalInvoiceId: String?
    let clientName: String?

    var isDraft: Bool { status == "draft" }

    private enum CodingKeys: String, CodingKey {
        case id, invoiceNumber, issueDate, totalTtc, status
        case clientId, isCreditNote, originalInvoiceId, clientName
    }

    init(from decoder: Decoder) throws {
        let c              = try decoder.container(keyedBy: CodingKeys.self)
        id                 = c.flexString(forKey: .id) ?? ""
        invoiceNumber      = try? c.decodeIfPresent(String.self, forKey: .invoiceNumber)
        issueDate          = try? c.decodeIfPresent(String.self, forKey: .issueDate)
        totalTtc           = c.flexDouble(forKey: .totalTtc)
        status             = try? c.decodeIfPresent(String.self, forKey: .status)
        clientId           = c.flexString(forKey: .clientId)
        isCreditNote       = try? c.decodeIfPresent(Bool.self,   forKey: .isCreditNote)
        originalInvoiceId  = c.flexString(forKey: .originalInvoiceId)
        clientName         = try? c.decodeIfPresent(String.self, forKey: .clientName)
    }
}

struct OwnerInvoicesResponse: Decodable {
    let invoices: [OwnerInvoice]?
}

// MARK: - GET /api/contrats?status=sent&agency=all
// clientId peut être null pour les contrats antérieurs à la migration —
// ils comptent dans l'alerte globale mais n'alimentent aucune pastille client.

struct OwnerContract: Decodable, Identifiable {
    let id: String
    let status: String?
    let clientId: String?   // null → contrat sans client rattaché
    let createdAt: String?  // ISO 8601 — base de calcul "Envoyé il y a N jours"

    private enum CodingKeys: String, CodingKey {
        case id, status, clientId, createdAt
    }

    init(from decoder: Decoder) throws {
        let c      = try decoder.container(keyedBy: CodingKeys.self)
        id         = c.flexString(forKey: .id) ?? ""
        status     = try? c.decodeIfPresent(String.self, forKey: .status)
        clientId   = c.flexString(forKey: .clientId)
        createdAt  = try? c.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

struct OwnerContractsResponse: Decodable {
    let contracts: [OwnerContract]?
    let total: Int?
}

// MARK: - PUT /api/owner-clients/:id

// PUT body — tous les 11 champs doivent être présents (un champ absent est mis à null par le serveur).
struct UpdateOwnerClientBody: Encodable {
    let clientType: String
    let firstName: String?
    let lastName: String?
    let companyName: String?
    let email: String?
    let phone: String?
    let siret: String?
    let address: String?
    let postalCode: String?
    let city: String?
    let defaultCommissionRate: Double
}

// MARK: - PATCH /api/agency/client-override/:delegatorUserId/:clientId

// Le body est en snake_case côté serveur — CodingKeys explicites pour forcer l'encodage correct.
struct PatchAgencyClientOverrideBody: Encodable {
    let firstName: String?
    let lastName: String?
    let companyName: String?
    let email: String?
    let siret: String?
    let phone: String?
    let address: String?
    let postalCode: String?
    let city: String?

    private enum CodingKeys: String, CodingKey {
        case firstName  = "first_name"
        case lastName   = "last_name"
        case companyName = "company_name"
        case email
        case siret
        case phone
        case address
        case postalCode = "postal_code"
        case city
    }
}

// MARK: - POST /api/owner-clients

struct CreateOwnerClientBody: Encodable {
    let clientType: String
    let companyName: String?
    let firstName: String?
    let lastName: String?
    let email: String?
    let phone: String?
    let siret: String?
    let address: String?
    let postalCode: String?
    let city: String?
    let defaultCommissionRate: Double?
}

struct CreateOwnerClientResponse: Decodable {
    let client: OwnerClient
}

// MARK: - PATCH /api/properties/:propertyId?agency=all (ownerId assignment)

struct PatchPropertyOwnerBody: Encodable {
    let ownerId: String?
}

struct PatchPropertyOwnerResponse: Decodable {
    let success: Bool?
    let propertyId: String?
    let ownerId: String?
    let previousOwnerId: String?

    init(from decoder: Decoder) throws {
        let c           = try decoder.container(keyedBy: CodingKeys.self)
        success         = try? c.decodeIfPresent(Bool.self, forKey: .success)
        propertyId      = c.flexString(forKey: .propertyId)
        ownerId         = c.flexString(forKey: .ownerId)
        previousOwnerId = c.flexString(forKey: .previousOwnerId)
    }

    private enum CodingKeys: String, CodingKey {
        case success, propertyId, ownerId, previousOwnerId
    }
}
