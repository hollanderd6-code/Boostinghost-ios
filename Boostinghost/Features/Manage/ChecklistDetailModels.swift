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
// Auth: authenticateAny — accepte le JWT d'un compte principal ET d'un sous-compte cleaner.
// Sous-compte cleaner : IDOR guard — cleaner_id résolu via sub_account_id du JWT.

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
    var checked: Bool

    init(id: String, name: String, room: String, checked: Bool) {
        self.id      = id
        self.name    = name
        self.room    = room
        self.checked = checked
    }

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

// MARK: - Source d'une photo de ménage

enum PhotoSource: String, Codable {
    case camera, gallery, unknown
}

// MARK: - Photo brouillon (ID stable côté client)

struct PhotoDraft: Identifiable {
    let id:     String      // UUID local — utilisé pour les opérations addPhoto/removePhotoId
    let data:   String      // data:image/jpeg;base64,…
    let source: PhotoSource

    init(id: String, data: String, source: PhotoSource = .unknown) {
        self.id     = id
        self.data   = data
        self.source = source
    }
}

// MARK: - Mutation de tâche ciblée

struct ChecklistTaskChange: Encodable {
    let id:      String
    let checked: Bool
}

// MARK: - Payload de tâche (encodage uniquement)

struct ChecklistTaskPayload: Encodable {
    let id:      String
    let name:    String
    let room:    String
    let checked: Bool
}

extension ChecklistTask {
    var payload: ChecklistTaskPayload {
        ChecklistTaskPayload(id: id, name: name, room: room, checked: checked)
    }
}

// MARK: - PATCH /api/cleaning/checklists/:reservationKey/draft

// Snapshot initial (première sauvegarde)
struct ChecklistDraftSnapshotRequest: Encodable {
    let propertyId:   String
    let tasks:        [ChecklistTaskPayload]
    let photos:       [PhotoDraftPayload]
    let notes:        String
    let startedAt:    String?
}

// Mutation tâche unique
struct ChecklistDraftTaskChangeRequest: Encodable {
    let propertyId:   String
    let taskChanges:  [ChecklistTaskChange]
}

// Ajout d'une photo
struct ChecklistDraftAddPhotoRequest: Encodable {
    let propertyId: String
    let addPhoto:   PhotoDraftPayload
}

// Suppression d'une photo
struct ChecklistDraftRemovePhotoRequest: Encodable {
    let propertyId:    String
    let removePhotoId: String
}

// Mise à jour des notes
struct ChecklistDraftNotesRequest: Encodable {
    let propertyId: String
    let notes:      String
}

// Payload photo encodable (id + data + source)
struct PhotoDraftPayload: Encodable {
    let id:     String
    let data:   String
    let source: String   // "camera" | "gallery" | "unknown"
}

// MARK: - POST /api/cleaning/checklist (chemin JWT sous-compte)

struct ChecklistSubmitRequest: Encodable {
    let reservationKey: String
    let propertyId:     String
    let tasks:          [ChecklistTaskPayload]
    let photos:         [String]           // data URI uniquement — sans ID
    let notes:          String
    let duration:       Int?
    let startedAt:      String?
    let checkoutDate:   String?
    let signatureData:  String?
    let certifiedAt:    String?
    let restock:        [Int]?             // IDs des articles à réassortir
}

struct ChecklistSubmitResponse: Decodable {
    let checklistId: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        checklistId = c.flexString(forKey: .checklistId)
    }
    private enum CodingKeys: CodingKey { case checklistId }
}

// MARK: - GET /api/cleaning/checklists/:reservationKey/draft

struct DraftDetailResponse: Decodable {
    let draft: DraftDetail
}

// WORKFLOWFIX: champs draft_meta retournés par GET /draft
struct DraftDamageDraft: Codable {
    let title:       String
    let description: String?
    let photoUrl:    String?
}

struct DraftIssueDraft: Codable {
    let title:       String
    let description: String?
    let priority:    String
}

struct ChecklistDraftMetaRequest: Encodable {
    let propertyId:   String
    let arrivalState: String?
    let damageDraft:  DraftDamageDraft?
    let issueDraft:   DraftIssueDraft?
    let restock:      [Int]?
}

struct DraftDetail: Decodable {
    let tasks:        [ChecklistTask]
    let photos:       [PhotoDraft]   // objets {id,data} ou data URI string (tolérance)
    let notes:        String?
    let startedAt:    String?
    // WORKFLOWFIX: champs draft_meta
    let arrivalState: String?
    let damageDraft:  DraftDamageDraft?
    let issueDraft:   DraftIssueDraft?
    let restock:      [Int]?

    init(from decoder: Decoder) throws {
        let c        = try decoder.container(keyedBy: CodingKeys.self)
        tasks        = (try? c.decodeIfPresent([ChecklistTask].self, forKey: .tasks)) ?? []
        // Photos stockées comme [{id,data}] ou ["data:..."] — les deux tolérés
        let rawArr   = try? c.decodeIfPresent([DraftPhotoRaw].self, forKey: .photos)
        photos       = rawArr?.compactMap { $0.toPhotoDraft() } ?? []
        notes        = try? c.decodeIfPresent(String.self, forKey: .notes)
        startedAt    = try? c.decodeIfPresent(String.self, forKey: .startedAt)
        arrivalState = try? c.decodeIfPresent(String.self, forKey: .arrivalState)
        damageDraft  = try? c.decodeIfPresent(DraftDamageDraft.self, forKey: .damageDraft)
        issueDraft   = try? c.decodeIfPresent(DraftIssueDraft.self, forKey: .issueDraft)
        restock      = try? c.decodeIfPresent([Int].self, forKey: .restock)
    }
    private enum CodingKeys: String, CodingKey {
        case tasks, photos, notes, startedAt, arrivalState, damageDraft, issueDraft, restock
    }
}

// Tolère {"id":"…","data":"…","source":"…"} ET "data:image/…" (chaîne brute)
struct DraftPhotoRaw: Decodable {
    private let id:     String?
    private let data:   String?
    private let raw:    String?
    private let source: String?

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let s = try? single.decode(String.self) {
            id = UUID().uuidString; data = s; raw = s; source = nil
        } else {
            let c  = try decoder.container(keyedBy: CodingKeys.self)
            id     = try? c.decodeIfPresent(String.self, forKey: .id)
            data   = try? c.decodeIfPresent(String.self, forKey: .data)
            source = try? c.decodeIfPresent(String.self, forKey: .source)
            raw    = nil
        }
    }
    private enum CodingKeys: CodingKey { case id, data, source }

    func toPhotoDraft() -> PhotoDraft? {
        let photoId     = id ?? UUID().uuidString
        let photoData   = data ?? raw ?? ""
        guard !photoData.isEmpty else { return nil }
        let photoSource = PhotoSource(rawValue: source ?? "") ?? .unknown
        return PhotoDraft(id: photoId, data: photoData, source: photoSource)
    }
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

// MARK: - Réassort (GET /api/cleaning/consumables — JWT)

struct ConsumableItem: Decodable, Identifiable {
    let id:    Int
    let label: String
    let icon:  String
}

struct ConsumablesResponse: Decodable {
    let items: [ConsumableItem]
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([ConsumableItem].self, forKey: .items)) ?? []
    }
    private enum CodingKeys: CodingKey { case items }
}

// MARK: - Upload photo ménage (POST /api/cleaning/photo-upload — JWT)

struct PhotoUploadRequest: Encodable {
    let dataUrl:        String
    let propertyId:     String
    let reservationKey: String?
    let kind:           String
}

struct PhotoUploadResponse: Decodable {
    let url:           String
    let certificateId: String?
    init(from decoder: Decoder) throws {
        let c         = try decoder.container(keyedBy: CodingKeys.self)
        url           = (try? c.decodeIfPresent(String.self, forKey: .url)) ?? ""
        certificateId = try? c.decodeIfPresent(String.self, forKey: .certificateId)
    }
    private enum CodingKeys: CodingKey { case url, certificateId }
}

// MARK: - Rapport incident / dégradation (POST /api/cleaning/maintenance — JWT)

struct MaintenanceReportRequest: Encodable {
    let propertyId:     String
    let title:          String
    let description:    String?
    let priority:       String
    let photos:         [String]
    let reservationKey: String?
    let kind:           String
}

struct MaintenanceReportResponse: Decodable {
    let ticketId: Int?
    init(from decoder: Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        ticketId = try? c.decodeIfPresent(Int.self, forKey: .ticketId)
    }
    private enum CodingKeys: CodingKey { case ticketId }
}

// MARK: - Sélection état à l'arrivée

enum ArrivalStateChoice: Equatable {
    case ok     // RAS — ex-cas, conservé pour compatibilité
    case damage

    var draftValue: String {
        switch self { case .ok: return "ras"; case .damage: return "damage" }
    }

    static func from(_ raw: String?) -> ArrivalStateChoice? {
        switch raw {
        case "ras":    return .ok
        case "damage": return .damage
        default:       return nil
        }
    }
}
