import Foundation

// MARK: - Filtre

enum DebourFilter: CaseIterable, Hashable {
    case pending, billed, all

    var label: String {
        switch self {
        case .pending: return "À facturer"
        case .billed:  return "Facturés"
        case .all:     return "Tous"
        }
    }
}

// MARK: - GET /api/debours?agency=all
// Réponse snake_case, auto-converti via convertFromSnakeCase.
// montant arrive en CHAÎNE "12.50" → flexDouble.

struct Debour: Decodable, Identifiable {
    let id: String
    let userId: String?
    let clientId: String?
    let description: String
    let montant: Double
    let date: String?
    let photoUrl: String?
    let status: String      // "pending" | "billed"
    let createdAt: String?

    var isPdf: Bool { photoUrl?.lowercased().hasSuffix(".pdf") == true }

    var statusLabel: String  { status == "billed" ? "facturé" : "à facturer" }
    var statusPillStyle: PillStyle { status == "billed" ? .vert : .or }

    private enum CodingKeys: CodingKey {
        case id, userId, clientId, description, montant, date, photoUrl, status, createdAt
    }

    init(from decoder: Decoder) throws {
        let c       = try decoder.container(keyedBy: CodingKeys.self)
        id          = c.flexString(forKey: .id) ?? ""
        userId      = c.flexString(forKey: .userId)
        clientId    = c.flexString(forKey: .clientId)
        description = (try? c.decodeIfPresent(String.self, forKey: .description)) ?? ""
        montant     = c.flexDouble(forKey: .montant) ?? 0
        date        = try? c.decodeIfPresent(String.self, forKey: .date)
        photoUrl    = try? c.decodeIfPresent(String.self, forKey: .photoUrl)
        status      = (try? c.decodeIfPresent(String.self, forKey: .status)) ?? "pending"
        createdAt   = try? c.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

// MARK: - Réponses API

struct DebourListResponse: Decodable {
    let debours: [Debour]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        debours = (try? c.decodeIfPresent([Debour].self, forKey: .debours)) ?? []
    }

    private enum CodingKeys: CodingKey { case debours }
}

struct DebourCreateResponse: Decodable {
    let success: Bool?
    let debour: Debour?    // serveur retourne "debour" OU "debours" selon la version

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try? c.decodeIfPresent(Bool.self, forKey: .success)
        debour  = (try? c.decodeIfPresent(Debour.self, forKey: .debour))
                  ?? (try? c.decodeIfPresent(Debour.self, forKey: .debours))
    }

    private enum CodingKeys: CodingKey { case success, debour, debours }
}

struct DebourStatusBody: Encodable {
    let status: String
}
