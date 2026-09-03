import Foundation

// MARK: - Sub-accounts (GET /api/sub-accounts/list)
// Relevé dans sub-accounts-routes.js:811 — res.json({ success, subAccounts: [...] })

struct SubAccountsResponse: Decodable {
    let subAccounts: [SubAccountItem]

    private enum CodingKeys: String, CodingKey { case subAccounts }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        subAccounts = (try? c.decodeIfPresent([SubAccountItem].self, forKey: .subAccounts)) ?? []
    }
}

struct SubAccountItem: Decodable {
    let id: String?

    private enum CodingKeys: String, CodingKey { case id, _id = "_id" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexString(forKey: ._id) ?? c.flexString(forKey: .id)
    }
}

// MARK: - Cleaners (GET /api/cleaners) — intervenant count

struct CleanersListResponse: Decodable {
    let cleaners: [CleanerItem]

    private enum CodingKeys: String, CodingKey { case cleaners }

    init(from decoder: Decoder) throws {
        if let c = try? decoder.container(keyedBy: CodingKeys.self),
           let arr = try? c.decodeIfPresent([CleanerItem].self, forKey: .cleaners) {
            cleaners = arr
        } else if let arr = try? [CleanerItem](from: decoder) {
            cleaners = arr
        } else {
            cleaners = []
        }
    }
}

struct CleanerItem: Decodable {
    let id: String?

    private enum CodingKeys: String, CodingKey { case id, _id = "_id" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexString(forKey: ._id) ?? c.flexString(forKey: .id)
    }
}

// MARK: - Message templates (GET /api/message-templates) — "Messages automatiques"
// Relevé dans server.js:30880 — res.json({ templates: result.rows })

struct MessageTemplatesResponse: Decodable {
    let templates: [MessageTemplateItem]

    private enum CodingKeys: String, CodingKey { case templates }

    init(from decoder: Decoder) throws {
        if let c = try? decoder.container(keyedBy: CodingKeys.self),
           let arr = try? c.decodeIfPresent([MessageTemplateItem].self, forKey: .templates) {
            templates = arr
        } else if let arr = try? [MessageTemplateItem](from: decoder) {
            templates = arr
        } else {
            templates = []
        }
    }
}

struct MessageTemplateItem: Decodable {
    let id: String?

    private enum CodingKeys: String, CodingKey { case id, _id = "_id" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexString(forKey: ._id) ?? c.flexString(forKey: .id)
    }
}

// MARK: - Notification settings (GET /api/settings/notifications)
//
// Relevé dans server.js:3385 (getNotificationSettings) et server.js:12129 (POST route).
//
// POST /api/settings/notifications ne lit dans req.body que ces 4 champs :
//   newReservation (Bool), reminder (Bool), whatsappEnabled (Bool), whatsappNumber (String)
//
// Les 12 champs renvoyés par GET mais ignorés par POST — à rétablir quand le serveur
// les lira depuis req.body :
//   notif_new_reservation, notif_reservation_cancelled, notif_daily_summary, notif_reminder_j1,
//   notif_cleaning_reminder, notif_cleaning_completed, notif_checklist_done, notif_deposit_request,
//   notif_new_message, notif_new_invoice, notif_cleaning_alert, notif_template_failed

struct NotificationSettings: Codable {
    var newReservation:  Bool
    var reminder:        Bool
    var whatsappEnabled: Bool
    var whatsappNumber:  String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        newReservation  = (try? c.decodeIfPresent(Bool.self,   forKey: .newReservation))  ?? false
        reminder        = (try? c.decodeIfPresent(Bool.self,   forKey: .reminder))        ?? false
        whatsappEnabled = (try? c.decodeIfPresent(Bool.self,   forKey: .whatsappEnabled)) ?? false
        whatsappNumber  = (try? c.decodeIfPresent(String.self, forKey: .whatsappNumber))  ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case newReservation, reminder, whatsappEnabled, whatsappNumber
    }
}
