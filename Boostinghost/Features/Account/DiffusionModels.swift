import Foundation

// MARK: - GET /api/properties/diffusion?agency=all
// { total, diffuses, vendables, logements: [{ property_id, nom, diffuse, vendable, a_regler }] }

struct DiffusionResponse: Decodable {
    let total:     Int
    let diffuses:  Int
    let vendables: Int
    let logements: [DiffusionProperty]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        total     = c.flexInt(forKey: .total)     ?? 0
        diffuses  = c.flexInt(forKey: .diffuses)  ?? 0
        vendables = c.flexInt(forKey: .vendables) ?? 0
        logements = (try? c.decodeIfPresent([DiffusionProperty].self, forKey: .logements)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case total, diffuses, vendables, logements
    }
}

struct DiffusionProperty: Decodable, Identifiable {
    let id:       String
    let nom:      String
    let diffuse:  Bool
    let vendable: Bool
    let aRegler:  Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = c.flexString(forKey: .propertyId) ?? c.flexString(forKey: .id) ?? UUID().uuidString
        nom      = (try? c.decodeIfPresent(String.self, forKey: .nom))      ?? ""
        diffuse  = (try? c.decodeIfPresent(Bool.self,   forKey: .diffuse))  ?? false
        vendable = (try? c.decodeIfPresent(Bool.self,   forKey: .vendable)) ?? false
        aRegler  = c.flexInt(forKey: .aRegler) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        // Pas de valeur explicite : convertFromSnakeCase transforme
        // "property_id" → "propertyId" et "a_regler" → "aRegler" avant la correspondance.
        case propertyId
        case id, nom, diffuse, vendable
        case aRegler
    }
}

// MARK: - GET /api/properties/:id/sante?agency=all
// { points: [{ cle, ok, titre, quand, details, action }] }

struct SanteResponse: Decodable {
    let points: [SantePoint]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        points = (try? c.decodeIfPresent([SantePoint].self, forKey: .points)) ?? []
    }

    private enum CodingKeys: String, CodingKey { case points }
}

struct SantePoint: Decodable {
    let cle:     String    // "relie" | "calendrier" | "tarifs" | "caution"
    let ok:      Bool
    let titre:   String
    let quand:   String?
    let details: String?
    let action:  String?   // "envoyer" | "prix" | "stripe" — non câblé

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cle     = (try? c.decodeIfPresent(String.self, forKey: .cle))     ?? ""
        ok      = (try? c.decodeIfPresent(Bool.self,   forKey: .ok))      ?? true
        titre   = (try? c.decodeIfPresent(String.self, forKey: .titre))   ?? ""
        quand   = try? c.decodeIfPresent(String.self,  forKey: .quand)
        details = try? c.decodeIfPresent(String.self,  forKey: .details)
        action  = try? c.decodeIfPresent(String.self,  forKey: .action)
    }

    private enum CodingKeys: String, CodingKey {
        case cle, ok, titre, quand, details, action
    }
}
