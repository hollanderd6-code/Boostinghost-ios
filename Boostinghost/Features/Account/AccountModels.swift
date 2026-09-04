import Foundation

// MARK: - User profile (GET /api/user/profile)
// Relevé dans docs/releves/mon-compte.md §1 — réponse plate, use_bh_stripe en snake_case.

struct UserProfile: Decodable {
    let email:         String?
    let firstName:     String?
    let lastName:      String?
    let company:       String?
    let accountType:   String?
    let address:       String?
    let postalCode:    String?
    let city:          String?
    let siret:         String?
    let phone:         String?
    let invoiceEmail:  String?
    let website:       String?
    let vatRegime:     String?
    let vatNumber:     String?
    let legalForm:     String?

    init(from decoder: Decoder) throws {
        let c         = try decoder.container(keyedBy: CodingKeys.self)
        email         = try? c.decodeIfPresent(String.self, forKey: .email)
        firstName     = try? c.decodeIfPresent(String.self, forKey: .firstName)
        lastName      = try? c.decodeIfPresent(String.self, forKey: .lastName)
        company       = try? c.decodeIfPresent(String.self, forKey: .company)
        accountType   = try? c.decodeIfPresent(String.self, forKey: .accountType)
        address       = try? c.decodeIfPresent(String.self, forKey: .address)
        postalCode    = try? c.decodeIfPresent(String.self, forKey: .postalCode)
        city          = try? c.decodeIfPresent(String.self, forKey: .city)
        siret         = try? c.decodeIfPresent(String.self, forKey: .siret)
        phone         = try? c.decodeIfPresent(String.self, forKey: .phone)
        invoiceEmail  = try? c.decodeIfPresent(String.self, forKey: .invoiceEmail)
        website       = try? c.decodeIfPresent(String.self, forKey: .website)
        vatRegime     = try? c.decodeIfPresent(String.self, forKey: .vatRegime)
        vatNumber     = try? c.decodeIfPresent(String.self, forKey: .vatNumber)
        legalForm     = try? c.decodeIfPresent(String.self, forKey: .legalForm)
    }

    private enum CodingKeys: String, CodingKey {
        case email, firstName, lastName, company, accountType
        case address, postalCode, city, siret, phone
        case invoiceEmail, website, vatRegime, vatNumber, legalForm
    }
}

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

// Relevé dans GET /api/cleaners?agency=all (2026-09-04).
// pinCode et accessToken donnent accès à l'espace intervenant — jamais affichés en clair.
// Les champs mutables (var) sont mis à jour localement après PUT/sms-toggle/regenerate-link
// pour éviter un rechargement réseau et préserver pinCode/accessToken après PUT.
struct CleanerItem: Decodable, Identifiable, Hashable {
    // Equality and hashing by id only — stable across mutations of var fields.
    static func == (lhs: CleanerItem, rhs: CleanerItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id:              String
    var name:            String
    var phone:           String?
    var email:           String?
    var notes:           String?
    let pinCode:         String    // masqué — ne pas afficher ; ne change pas après création
    var isActive:        Bool
    let subAccountId:    Int?      // non nil → sous-compte lié
    var smsRecapEnabled: Bool
    var accessToken:     String    // masqué — ne pas afficher ; mis à jour par regenerate-link
    let createdAt:       String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id peut être préfixé MongoDB (_id) ou format string backend (id)
        id              = c.flexString(forKey: ._id) ?? c.flexString(forKey: .id) ?? ""
        name            = (try? c.decodeIfPresent(String.self, forKey: .name))            ?? ""
        phone           = try? c.decodeIfPresent(String.self, forKey: .phone)
        email           = try? c.decodeIfPresent(String.self, forKey: .email)
        notes           = try? c.decodeIfPresent(String.self, forKey: .notes)
        pinCode         = (try? c.decodeIfPresent(String.self, forKey: .pinCode))         ?? ""
        isActive        = (try? c.decodeIfPresent(Bool.self,   forKey: .isActive))        ?? true
        subAccountId    = c.flexInt(forKey: .subAccountId)
        smsRecapEnabled = (try? c.decodeIfPresent(Bool.self,   forKey: .smsRecapEnabled)) ?? false
        accessToken     = (try? c.decodeIfPresent(String.self, forKey: .accessToken))     ?? ""
        createdAt       = try? c.decodeIfPresent(String.self,  forKey: .createdAt)
    }

    private enum CodingKeys: String, CodingKey {
        case _id = "_id"  // MongoDB — tiret bas initial préservé par convertFromSnakeCase
        case id, name, phone, email, notes, createdAt
        // Pas de valeur explicite pour les clés snake_case :
        // convertFromSnakeCase les convertit avant la correspondance.
        case pinCode         // "pin_code"          → "pinCode"
        case isActive        // "is_active"         → "isActive"
        case subAccountId    // "sub_account_id"    → "subAccountId"
        case smsRecapEnabled // "sms_recap_enabled" → "smsRecapEnabled"
        case accessToken     // "access_token"      → "accessToken"
    }
}

// MARK: - Cleaner write models

// Corps POST /api/cleaners et PUT /api/cleaners/:id.
// subAccountId préservé depuis l'objet local sur PUT ; nil sur création.
struct CleanerWriteBody: Encodable {
    let name:         String
    let email:        String?
    let phone:        String?
    let notes:        String?
    let isActive:     Bool
    let subAccountId: Int?
}

// Réponse 201 POST /api/cleaners : { message, cleaner }
struct CreateCleanerResponse: Decodable {
    let cleaner: CleanerItem
}

// Corps PUT /api/cleaners/:id/sms-toggle
struct SmsToggleBody: Encodable {
    let enabled: Bool
}

// Réponse POST /api/cleaners/:id/regenerate-link : { success, cleaner: { access_token } }
// convertFromSnakeCase mappe access_token → accessToken.
struct RegenerateLinkResponse: Decodable {
    struct CleanerToken: Decodable {
        let accessToken: String
    }
    let cleaner: CleanerToken
}

// MARK: - Default cleaners (GET /api/cleaning/default-cleaners)
// Relevé 2026-09-04 : { success, defaults: { "<propertyId>": { cleanerId, cleanerName, pinCode } } }
// Les clés du dict sont les property_id du backend — utilisées telles quelles.

struct DefaultCleanersResponse: Decodable {
    let success:  Bool
    let defaults: [String: DefaultCleanerEntry]
}

struct DefaultCleanerEntry: Decodable {
    let cleanerId:   String
    let cleanerName: String

    init(cleanerId: String, cleanerName: String) {
        self.cleanerId   = cleanerId
        self.cleanerName = cleanerName
    }
}

// Corps PUT /api/cleaning/default-cleaner/:propertyId
// cleanerId: null → retire l'association ; cleanerId: "c_..." → associe.
// encode personnalisé : JSONEncoder omet les optionals nil par défaut avec encodeIfPresent,
// mais le serveur attend explicitement { cleanerId: null } pour retirer.
struct DefaultCleanerBody: Encodable {
    let cleanerId: String?

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(cleanerId, forKey: .cleanerId)
    }

    private enum CodingKeys: String, CodingKey { case cleanerId }
}

// MARK: - Message templates (GET /api/message-templates) — "Messages automatiques"
// Relevé server.js:30985 — res.json({ templates: result.rows }).
// id : SERIAL PostgreSQL (entier). property_ids : JSONB → tableau JSON dans la réponse.
// portee, logements_couverts, logements_cibles : champs calculés ajoutés par le handler GET.

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

struct MessageTemplateItem: Decodable, Identifiable, Hashable {
    static func == (lhs: MessageTemplateItem, rhs: MessageTemplateItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id:                  Int
    let title:               String
    let message:             String
    let triggerType:         String
    let triggerOffsetHours:  Int
    let triggerOffsetDays:   Int
    let sendCondition:       String
    var active:              Bool
    let propertyIds:         [String]   // JSONB : [] = tous les logements (distinction préservée)
    let propertyId:          String?    // legacy : ignoré quand propertyIds non vide
    let logementsCouverts:   Int?       // calculé côté serveur (peut être absent)
    let logementsCibles:     Int?       // null quand portée globale
    let portee:              String?    // "ciblee" | "globale"

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                 = (try? c.decodeIfPresent(Int.self,    forKey: .id))                 ?? 0
        title              = (try? c.decodeIfPresent(String.self, forKey: .title))              ?? ""
        message            = (try? c.decodeIfPresent(String.self, forKey: .message))            ?? ""
        triggerType        = (try? c.decodeIfPresent(String.self, forKey: .triggerType))        ?? ""
        triggerOffsetHours = (try? c.decodeIfPresent(Int.self,    forKey: .triggerOffsetHours)) ?? 0
        triggerOffsetDays  = (try? c.decodeIfPresent(Int.self,    forKey: .triggerOffsetDays))  ?? 0
        sendCondition      = (try? c.decodeIfPresent(String.self, forKey: .sendCondition))      ?? "always"
        active             = (try? c.decodeIfPresent(Bool.self,   forKey: .active))             ?? true
        propertyId         = try? c.decodeIfPresent(String.self,  forKey: .propertyId)
        logementsCouverts  = try? c.decodeIfPresent(Int.self,     forKey: .logementsCouverts)
        logementsCibles    = try? c.decodeIfPresent(Int.self,     forKey: .logementsCibles)
        portee             = try? c.decodeIfPresent(String.self,  forKey: .portee)

        // property_ids : JSONB retourné comme tableau JSON ou, défensivement, comme chaîne JSON.
        if let arr = try? c.decodeIfPresent([String].self, forKey: .propertyIds) {
            propertyIds = arr
        } else if let str  = try? c.decodeIfPresent(String.self, forKey: .propertyIds),
                  let data = str.data(using: .utf8),
                  let arr  = try? JSONDecoder().decode([String].self, from: data) {
            propertyIds = arr
        } else {
            propertyIds = []
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, message, active, portee
        case triggerType         // trigger_type
        case triggerOffsetHours  // trigger_offset_hours
        case triggerOffsetDays   // trigger_offset_days
        case sendCondition       // send_condition
        case propertyIds         // property_ids (JSONB)
        case propertyId          // property_id (legacy)
        case logementsCouverts   // logements_couverts
        case logementsCibles     // logements_cibles
    }
}

extension MessageTemplateItem {

    // Déclencheur localisé avec offset. Les 7 valeurs du backend sont couvertes.
    var triggerLabel: String {
        let d = triggerOffsetDays, h = triggerOffsetHours
        switch triggerType {
        case "before_arrival":
            if d > 0 { return "Avant l'arrivée · J-\(d)" }
            if h > 0 { return "Avant l'arrivée · \(h) h" }
            return "Avant l'arrivée"
        case "on_arrival":   return "À l'arrivée"
        case "after_arrival":
            if d > 0 { return "Après l'arrivée · J+\(d)" }
            if h > 0 { return "Après l'arrivée · \(h) h" }
            return "Après l'arrivée"
        case "before_departure":
            if d > 0 { return "Avant le départ · J-\(d)" }
            if h > 0 { return "Avant le départ · \(h) h" }
            return "Avant le départ"
        case "on_departure":  return "Au départ"
        case "after_departure":
            if d > 0 { return "Après le départ · J+\(d)" }
            if h > 0 { return "Après le départ · \(h) h" }
            return "Après le départ"
        case "on_booking":    return "À la réservation"
        default:              return triggerType
        }
    }

    // [] = tous les logements (jamais converti en liste explicite).
    var scopeLabel: String {
        if propertyIds.isEmpty { return "Tous les logements" }
        let n = propertyIds.count
        return "\(n) logement\(n == 1 ? "" : "s")"
    }

    // Ligne de contexte pour la cellule de liste : déclencheur · plateformes · portée.
    var contextLine: String {
        let cond = SendConditionComponents(sendCondition)
        var parts: [String] = [triggerLabel]
        if cond.hasPlatforms {
            parts.append(cond.platforms.map { SendConditionComponents.platformLabel($0) }.joined(separator: ", "))
        }
        parts.append(scopeLabel)
        return parts.joined(separator: " · ")
    }
}

// MARK: - SendConditionComponents
// Décompose le champ TEXT send_condition en deux ensembles :
//   conditions (combinées EN) : deposit_active, deposit_captured, deposit_pending, police_complete
//   plateformes (combinées OU) : platform_booking, platform_airbnb, platform_direct
// Séparateur confirmé server.js:30260 : .split(',').map(s => s.trim()).filter(Boolean)
// "always" ou vide → ensembles vides.

struct SendConditionComponents {
    private static let knownConditions: Set<String> = [
        "deposit_active", "deposit_captured", "deposit_pending", "police_complete"
    ]
    private static let knownPlatforms: Set<String> = [
        "platform_booking", "platform_airbnb", "platform_direct"
    ]

    let conditions: [String]  // triés, combinés EN
    let platforms:  [String]  // triés, combinés OU

    var hasConditions: Bool { !conditions.isEmpty }
    var hasPlatforms:  Bool { !platforms.isEmpty }

    init(_ raw: String) {
        guard !raw.isEmpty, raw != "always" else {
            conditions = []; platforms = []; return
        }
        var tokens = raw
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        // checkin_complete : alias historique → deposit_active + police_complete (server.js:30264)
        if let idx = tokens.firstIndex(of: "checkin_complete") {
            tokens.remove(at: idx)
            if !tokens.contains("deposit_active") { tokens.append("deposit_active") }
            if !tokens.contains("police_complete") { tokens.append("police_complete") }
        }
        conditions = tokens.filter { Self.knownConditions.contains($0) }.sorted()
        platforms  = tokens.filter { Self.knownPlatforms.contains($0) }.sorted()
    }

    // Recompose pour l'écriture : conditions d'abord, plateformes ensuite, virgule sans espace.
    var recomposed: String {
        let all = conditions + platforms
        return all.isEmpty ? "always" : all.joined(separator: ",")
    }

    static func conditionLabel(_ token: String) -> String {
        switch token {
        case "deposit_active", "deposit_captured": return "Caution validée"
        case "deposit_pending":                    return "Caution en attente"
        case "police_complete":                    return "Fiche de police complète"
        default:                                   return token
        }
    }

    static func platformLabel(_ token: String) -> String {
        switch token {
        case "platform_airbnb":  return "Airbnb"
        case "platform_booking": return "Booking.com"
        case "platform_direct":  return "Direct / BHGuest"
        default:                 return token
        }
    }
}

#if DEBUG
extension SendConditionComponents {
    static func selfTest() {
        // 1. "always" → ensembles vides, recomposé = "always"
        let a = SendConditionComponents("always")
        assert(a.conditions.isEmpty && a.platforms.isEmpty)
        assert(a.recomposed == "always")

        // 2. Vide → même résultat
        assert(SendConditionComponents("").recomposed == "always")

        // 3. Une seule condition
        let b = SendConditionComponents("deposit_active")
        assert(b.conditions == ["deposit_active"] && b.platforms.isEmpty)
        assert(b.recomposed == "deposit_active")

        // 4. Deux conditions + deux plateformes
        let c = SendConditionComponents("deposit_active,police_complete,platform_booking,platform_airbnb")
        assert(c.conditions == ["deposit_active", "police_complete"])
        assert(c.platforms  == ["platform_airbnb", "platform_booking"])

        // 5. Tour complet lecture → écriture → relecture
        let reread = SendConditionComponents(c.recomposed)
        assert(reread.conditions == c.conditions && reread.platforms == c.platforms,
               "round-trip raté : \(c.recomposed)")

        // 6. Alias checkin_complete → deposit_active + police_complete, round-trip stable
        let d = SendConditionComponents("checkin_complete")
        assert(d.conditions.contains("deposit_active") && d.conditions.contains("police_complete"))
        assert(SendConditionComponents(d.recomposed).conditions == d.conditions)

        // 7. Espaces autour des virgules tolérés à la lecture
        let e = SendConditionComponents("deposit_active , platform_booking")
        assert(e.conditions == ["deposit_active"] && e.platforms == ["platform_booking"])

        print("[SendConditionComponents] selfTest OK")
    }
}
#endif

// MARK: - Corps PUT /api/message-templates/:id (bascule rapide)
struct TemplateActiveToggleBody: Encodable {
    let active: Bool
}

// MARK: - Corps PUT /api/message-templates/:id (édition complète)
// Clés explicitement en snake_case : JSONEncoder() n'applique aucune stratégie de conversion.
struct TemplateWriteBody: Encodable {
    let title:              String
    let message:            String
    let triggerType:        String
    let triggerOffsetDays:  Int
    let triggerOffsetHours: Int
    let sendCondition:      String
    let propertyIds:        [String]
    let active:             Bool

    private enum CodingKeys: String, CodingKey {
        case title, message, active
        case triggerType        = "trigger_type"
        case triggerOffsetDays  = "trigger_offset_days"
        case triggerOffsetHours = "trigger_offset_hours"
        case sendCondition      = "send_condition"
        case propertyIds        = "property_ids"
    }
}

// Réponse PUT /api/message-templates/:id : { success, template: { ... } }
struct TemplateSaveResponse: Decodable {
    let template: MessageTemplateItem
}

// MARK: - Notification settings (GET /api/settings/notifications)
// Relevé server.js : 9 clés snake_case actives. Les champs legacy (newReservation,
// reminder, whatsappEnabled, whatsappNumber) et les deux clés sans handler serveur
// (notif_cleaning_reminder, notif_deposit_request) sont ignorés.
// POST fusionne : envoyer seulement la clé modifiée sous forme [String: Bool].

struct NotificationSettings: Decodable {
    var notifNewReservation:       Bool
    var notifReservationCancelled: Bool
    var notifNewMessage:           Bool
    var notifDailySummary:         Bool
    var notifReminderJ1:           Bool
    var notifCleaningAlert:        Bool
    var notifChecklistDone:        Bool
    var notifNewInvoice:           Bool
    var notifTemplateFailed:       Bool

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        notifNewReservation       = (try? c.decodeIfPresent(Bool.self, forKey: .notifNewReservation))       ?? false
        notifReservationCancelled = (try? c.decodeIfPresent(Bool.self, forKey: .notifReservationCancelled)) ?? false
        notifNewMessage           = (try? c.decodeIfPresent(Bool.self, forKey: .notifNewMessage))           ?? false
        notifDailySummary         = (try? c.decodeIfPresent(Bool.self, forKey: .notifDailySummary))         ?? false
        notifReminderJ1           = (try? c.decodeIfPresent(Bool.self, forKey: .notifReminderJ1))           ?? false
        notifCleaningAlert        = (try? c.decodeIfPresent(Bool.self, forKey: .notifCleaningAlert))        ?? false
        notifChecklistDone        = (try? c.decodeIfPresent(Bool.self, forKey: .notifChecklistDone))        ?? false
        notifNewInvoice           = (try? c.decodeIfPresent(Bool.self, forKey: .notifNewInvoice))           ?? false
        notifTemplateFailed       = (try? c.decodeIfPresent(Bool.self, forKey: .notifTemplateFailed))       ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case notifNewReservation       = "notif_new_reservation"
        case notifReservationCancelled = "notif_reservation_cancelled"
        case notifNewMessage           = "notif_new_message"
        case notifDailySummary         = "notif_daily_summary"
        case notifReminderJ1           = "notif_reminder_j1"
        case notifCleaningAlert        = "notif_cleaning_alert"
        case notifChecklistDone        = "notif_checklist_done"
        case notifNewInvoice           = "notif_new_invoice"
        case notifTemplateFailed       = "notif_template_failed"
    }
}
