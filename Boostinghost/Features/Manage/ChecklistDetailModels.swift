import Foundation

// MARK: - Jeton de navigation vers l'écran ménage

struct CleaningDetailRef: Identifiable, Hashable {
    let propertyId:     String?
    let propertyName:   String?
    let cleanerName:    String?
    let dateStr:        String     // "YYYY-MM-DD" — date du départ voyageur
    let windowStart:    String?    // heure de départ
    let windowEnd:      String?    // heure d'arrivée voyageur suivant (si connue)
    let reservationKey: String?
    let checklistId:    String?    // nil = pas encore soumis

    var id: String {
        if let cid = checklistId { return "cl_\(cid)" }
        return "\(propertyId ?? "")_\(dateStr)"
    }
}

// MARK: - GET /api/cleaning/checklists/:id
// Auth: getUserFromRequest (JWT Bearer uniquement — pas authenticateAny)
// Seul le token du compte principal est accepté.

struct ChecklistDetailResponse: Decodable {
    let checklist: ChecklistDetail
}

struct ChecklistDetail: Decodable, Identifiable {
    let id:               String
    let propertyId:       String?
    let reservationKey:   String?
    let guestName:        String?
    let checkoutDate:     String?    // "YYYY-MM-DD"
    let tasks:            [ChecklistTask]
    let photos:           [String]   // data URIs base64 JPEG
    let notes:            String?    // note de l'intervenante
    let completedAt:      String?    // ISO8601
    let ownerStatus:      String     // "pending" | "validated" | "rejected"
    let ownerNotes:       String?    // message du propriétaire (envoyé à l'intervenante)
    let ownerValidatedAt: String?
    let durationSeconds:  Int?
    let cleanerName:      String?    // alias JOIN
    let cleanerPhone:     String?    // alias JOIN
    // Certification — ajoutée après coup, null sur les anciennes checklists
    let cleanerCertified: Bool       // true si signature fournie
    let certifiedAt:      String?    // ISO8601 avec timezone
    let signatureData:    String?    // data:image/png;base64,… — présent quand cleanerCertified
    let signatureIp:      String?    // preuve technique — ne pas afficher à l'utilisateur

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id est un number en JSON, mais String partout ailleurs dans le projet
        id               = c.flexString(forKey: .id) ?? UUID().uuidString
        propertyId       = try? c.decodeIfPresent(String.self, forKey: .propertyId)
        reservationKey   = try? c.decodeIfPresent(String.self, forKey: .reservationKey)
        guestName        = try? c.decodeIfPresent(String.self, forKey: .guestName)
        checkoutDate     = try? c.decodeIfPresent(String.self, forKey: .checkoutDate)
        tasks            = (try? c.decodeIfPresent([ChecklistTask].self, forKey: .tasks)) ?? []
        photos           = (try? c.decodeIfPresent([String].self, forKey: .photos)) ?? []
        notes            = try? c.decodeIfPresent(String.self, forKey: .notes)
        completedAt      = try? c.decodeIfPresent(String.self, forKey: .completedAt)
        ownerStatus      = (try? c.decodeIfPresent(String.self, forKey: .ownerStatus)) ?? "pending"
        ownerNotes       = try? c.decodeIfPresent(String.self, forKey: .ownerNotes)
        ownerValidatedAt = try? c.decodeIfPresent(String.self, forKey: .ownerValidatedAt)
        durationSeconds  = c.flexInt(forKey: .durationSeconds)
        cleanerName      = try? c.decodeIfPresent(String.self, forKey: .cleanerName)
        cleanerPhone     = try? c.decodeIfPresent(String.self, forKey: .cleanerPhone)
        cleanerCertified = (try? c.decodeIfPresent(Bool.self, forKey: .cleanerCertified)) ?? false
        certifiedAt      = try? c.decodeIfPresent(String.self, forKey: .certifiedAt)
        signatureData    = try? c.decodeIfPresent(String.self, forKey: .signatureData)
        signatureIp      = try? c.decodeIfPresent(String.self, forKey: .signatureIp)
    }

    // Les CodingKeys sont en camelCase : convertFromSnakeCase mappe les clés JSON
    // snake_case vers ces valeurs (ex. owner_status → ownerStatus).
    private enum CodingKeys: String, CodingKey {
        case id, propertyId, reservationKey, guestName, checkoutDate
        case tasks, photos, notes, completedAt
        case ownerStatus, ownerNotes, ownerValidatedAt, durationSeconds
        case cleanerName, cleanerPhone
        case cleanerCertified, certifiedAt, signatureData, signatureIp
    }
}

// MARK: - Tâche de checklist

struct ChecklistTask: Decodable, Identifiable {
    let id:      String
    let name:    String
    let room:    String
    let checked: Bool

    init(from decoder: Decoder) throws {
        let c   = try decoder.container(keyedBy: CodingKeys.self)
        id      = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        // Le web accepte t.name ou t.title — tolérance pour les anciens templates.
        let n   = try? c.decodeIfPresent(String.self, forKey: .name)
        let t   = try? c.decodeIfPresent(String.self, forKey: .title)
        name    = n ?? t ?? "Tâche"
        room    = (try? c.decodeIfPresent(String.self, forKey: .room)) ?? "general"
        checked = (try? c.decodeIfPresent(Bool.self, forKey: .checked)) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, title, room, checked
    }

    static func roomLabel(_ room: String) -> String {
        switch room.lowercased() {
        case "kitchen":  return "Cuisine"
        case "bathroom": return "Salle de bain"
        case "bedroom":  return "Chambre"
        case "living":   return "Salon"
        case "terrace":  return "Terrasse"
        default:         return "Général"
        }
    }

    static let roomOrder = ["kitchen", "bathroom", "bedroom", "living", "terrace", "general"]
}

// MARK: - GET /api/cleaning/templates
// Réponse : { success: true, templates: [...] } — snake_case pur (colonnes PG brutes).
// convertFromSnakeCase mappe property_id → propertyId, is_default → isDefault.

struct CleaningTemplatesResponse: Decodable {
    let templates: [CleaningTemplate]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        templates = (try? c.decodeIfPresent([CleaningTemplate].self, forKey: .templates)) ?? []
    }
    private enum CodingKeys: CodingKey { case templates }
}

struct CleaningTemplate: Decodable {
    let id:         Int
    let propertyId: String?   // nil = modèle global
    let name:       String
    let tasks:      [ChecklistTask]
    let isDefault:  Bool

    init(from decoder: Decoder) throws {
        let c      = try decoder.container(keyedBy: CodingKeys.self)
        id         = (try? c.decodeIfPresent(Int.self,    forKey: .id))         ?? 0
        propertyId = try? c.decodeIfPresent(String.self,  forKey: .propertyId)
        name       = (try? c.decodeIfPresent(String.self, forKey: .name))       ?? "Template ménage"
        tasks      = (try? c.decodeIfPresent([ChecklistTask].self, forKey: .tasks)) ?? []
        isDefault  = (try? c.decodeIfPresent(Bool.self,   forKey: .isDefault))  ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id, propertyId, name, tasks, isDefault
    }
}

// MARK: - GET /api/maintenance/tickets

struct MaintenanceTicketsResponse: Decodable {
    let tickets: [MaintenanceTicket]

    init(from decoder: Decoder) throws {
        if let c = try? decoder.container(keyedBy: CodingKeys.self),
           let arr = try? c.decodeIfPresent([MaintenanceTicket].self, forKey: .tickets) {
            tickets = arr
        } else if let arr = try? [MaintenanceTicket](from: decoder) {
            tickets = arr
        } else {
            tickets = []
        }
    }
    private enum CodingKeys: CodingKey { case tickets }
}

struct MaintenanceTicket: Decodable, Identifiable {
    let id:             String
    let title:          String
    let description:    String?
    let priority:       String   // "low" | "normal" | "high" | "urgent"
    let status:         String   // "open" | "resolved"
    let reservationKey: String?
    let kind:           String   // "maintenance" | "damage"
    let createdAt:      String?
    let photos:         [String] // URLs Cloudinary

    init(from decoder: Decoder) throws {
        let c           = try decoder.container(keyedBy: CodingKeys.self)
        id              = c.flexString(forKey: .id) ?? UUID().uuidString
        title           = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? "—"
        description     = try? c.decodeIfPresent(String.self, forKey: .description)
        priority        = (try? c.decodeIfPresent(String.self, forKey: .priority)) ?? "normal"
        status          = (try? c.decodeIfPresent(String.self, forKey: .status)) ?? "open"
        reservationKey  = try? c.decodeIfPresent(String.self, forKey: .reservationKey)
        kind            = (try? c.decodeIfPresent(String.self, forKey: .kind)) ?? "maintenance"
        createdAt       = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        photos          = (try? c.decodeIfPresent([String].self, forKey: .photos)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, priority, status, reservationKey, kind, createdAt, photos
    }
}
