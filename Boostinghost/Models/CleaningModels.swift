import Foundation

// MARK: - GET /api/cleaning/checklists

struct CleaningChecklistsResponse: Decodable {
    let checklists: [CleaningChecklist]

    init(from decoder: Decoder) throws {
        if let c = try? decoder.container(keyedBy: CodingKeys.self),
           let arr = try? c.decodeIfPresent([CleaningChecklist].self, forKey: .checklists) {
            checklists = arr
        } else if let arr = try? [CleaningChecklist](from: decoder) {
            checklists = arr
        } else {
            checklists = []
        }
    }

    private enum CodingKeys: CodingKey { case checklists }
}

struct CleaningChecklist: Decodable, Identifiable {
    let id: String
    let propertyId: String?
    let reservationKey: String?  // croisement avec les assignations pour l'Historique
    let cleanerName: String?
    let status: String?         // "completed", "validated", "rejected"
    let completedAt: String?    // ISO8601
    let photos: [String]?       // photo URLs

    var resolvedPropertyName: String?
    var photoCount: Int { photos?.count ?? 0 }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = c.flexString(forKey: ._id) ?? c.flexString(forKey: .id) ?? UUID().uuidString
        propertyId     = try? c.decodeIfPresent(String.self, forKey: .propertyId)
        reservationKey = try? c.decodeIfPresent(String.self, forKey: .reservationKey)
        cleanerName    = try? c.decodeIfPresent(String.self, forKey: .cleanerName)
        status         = try? c.decodeIfPresent(String.self, forKey: .status)
        completedAt    = try? c.decodeIfPresent(String.self, forKey: .completedAt)
        photos         = try? c.decodeIfPresent([String].self, forKey: .photos)
        resolvedPropertyName = nil
    }

    private enum CodingKeys: String, CodingKey {
        case _id = "_id", id
        case propertyId, reservationKey, cleanerName, status, completedAt, photos
    }
}

// MARK: - Semaine : groupes par jour

struct CleaningDayGroup: Identifiable {
    var id: String { dateStr }
    let dateStr: String              // "YYYY-MM-DD"
    let tight: [CleaningAssignment]
    let wide:  [CleaningAssignment]
}

// MARK: - Historique : ligne et groupe

struct CleaningHistoryItem: Identifiable {
    var id: UUID = UUID()
    let dateStr: String          // "YYYY-MM-DD" (date du ménage = départ)
    let propertyName: String?
    let cleanerName: String?
    let checklistStatus: String? // "validated", "rejected", "completed" (à valider), nil = pas de retour
}

struct CleaningHistoryGroup: Identifiable {
    var id: String { dateStr }
    let dateStr: String
    let items: [CleaningHistoryItem]
}

// MARK: - Utilitaire de créneau partagé entre ViewModel et View

extension CleaningAssignment {

    // Durée entre l'heure de départ et l'heure d'arrivée suivante.
    // Retourne nil si l'une des deux bornes est absente.
    static func slotDuration(start: String?, end: String?) -> TimeInterval? {
        guard let s = parseWindowTime(start),
              let e = parseWindowTime(end) else { return nil }
        let d = e.timeIntervalSince(s)
        return d > 0 ? d : nil
    }

    // Parse "HH:mm" ou ISO8601 en Date (heure du jour courant pour HH:mm).
    static func parseWindowTime(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        if raw.contains("T") {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f.date(from: raw) { return d }
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: raw)
        }
        let parts = raw.split(separator: ":").compactMap { Int($0) }
        guard let h = parts.first else { return nil }
        let m = parts.count > 1 ? parts[1] : 0
        return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date())
    }
}

// MARK: - Write bodies

struct RejectBody: Encodable {
    let notes: String
}
