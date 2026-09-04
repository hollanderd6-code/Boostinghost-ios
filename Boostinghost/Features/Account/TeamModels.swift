import Foundation

// MARK: - Réponse liste équipe (GET /api/sub-accounts/list)
// Relevé dans docs/releves/mon-compte.md §3.
// convertFromSnakeCase géré par APIClient — pas de CodingKeys manuels.

struct SubAccountsTeamResponse: Decodable {
    let subAccounts: [SubAccount]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        subAccounts = (try? c.decodeIfPresent([SubAccount].self, forKey: .subAccounts)) ?? []
    }
    private enum CodingKeys: CodingKey { case subAccounts }
}

// MARK: - Sous-compte (toutes les colonnes du relevé)

struct SubAccount: Decodable, Identifiable, Hashable {

    // MARK: Métadonnées

    let id: Int
    let email: String?
    let firstName: String?
    let lastName: String?
    let role: String?
    let isActive: Bool
    let createdAt: String?
    let lastLogin: String?

    // MARK: Calendrier

    let canViewCalendar: Bool
    let canEditReservations: Bool
    let canCreateReservations: Bool
    let canDeleteReservations: Bool

    // MARK: Messages

    let canViewMessages: Bool
    let canSendMessages: Bool
    let canViewTemplates: Bool
    let canManageTemplates: Bool

    // MARK: Ménage

    let canViewCleaning: Bool
    let canAssignCleaning: Bool
    let canManageCleaningStaff: Bool

    // MARK: Logements

    let canViewProperties: Bool
    let canEditProperties: Bool
    let canViewSmartLocks: Bool
    let canManageSmartLocks: Bool
    let canViewWelcomeBook: Bool
    let canAccessSettings: Bool
    let canManageTeam: Bool

    // MARK: Propriétaires

    let canViewOwners: Bool
    let canViewContracts: Bool

    // MARK: Argent

    let canViewFinances: Bool
    let canEditFinances: Bool
    let canViewDeposits: Bool
    let canManageDeposits: Bool
    let canViewInvoices: Bool
    let canManageInvoices: Bool
    let canViewPayments: Bool
    let canManagePayments: Bool
    let canViewPricing: Bool
    let canManagePricing: Bool
    let canViewDebours: Bool
    let canManageDebours: Bool
    let canViewReporting: Bool

    // MARK: Préférences de notifications

    let notifSubNewReservation: Bool
    let notifSubReservationCancelled: Bool
    let notifSubCleaningAssigned: Bool
    let notifSubCleaningCompleted: Bool
    let notifSubDepositPaid: Bool
    let notifSubPaymentReceived: Bool
    let notifSubNewMessage: Bool
    let notifSubDailySummary: Bool

    // MARK: Décodage tolérant (nil → false pour les bool, nil → 0 pour l'id)

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id        = (try? c.decodeIfPresent(Int.self,    forKey: .id))        ?? 0
        email     = try? c.decodeIfPresent(String.self,  forKey: .email)
        firstName = try? c.decodeIfPresent(String.self,  forKey: .firstName)
        lastName  = try? c.decodeIfPresent(String.self,  forKey: .lastName)
        role      = try? c.decodeIfPresent(String.self,  forKey: .role)
        isActive  = (try? c.decodeIfPresent(Bool.self,   forKey: .isActive)) ?? true
        createdAt = try? c.decodeIfPresent(String.self,  forKey: .createdAt)
        lastLogin = try? c.decodeIfPresent(String.self,  forKey: .lastLogin)

        func b(_ k: CodingKeys) -> Bool { (try? c.decodeIfPresent(Bool.self, forKey: k)) ?? false }

        canViewCalendar        = b(.canViewCalendar)
        canEditReservations    = b(.canEditReservations)
        canCreateReservations  = b(.canCreateReservations)
        canDeleteReservations  = b(.canDeleteReservations)

        canViewMessages        = b(.canViewMessages)
        canSendMessages        = b(.canSendMessages)
        canViewTemplates       = b(.canViewTemplates)
        canManageTemplates     = b(.canManageTemplates)

        canViewCleaning        = b(.canViewCleaning)
        canAssignCleaning      = b(.canAssignCleaning)
        canManageCleaningStaff = b(.canManageCleaningStaff)

        canViewProperties      = b(.canViewProperties)
        canEditProperties      = b(.canEditProperties)
        canViewSmartLocks      = b(.canViewSmartLocks)
        canManageSmartLocks    = b(.canManageSmartLocks)
        canViewWelcomeBook     = b(.canViewWelcomeBook)
        canAccessSettings      = b(.canAccessSettings)
        canManageTeam          = b(.canManageTeam)

        canViewOwners          = b(.canViewOwners)
        canViewContracts       = b(.canViewContracts)

        canViewFinances        = b(.canViewFinances)
        canEditFinances        = b(.canEditFinances)
        canViewDeposits        = b(.canViewDeposits)
        canManageDeposits      = b(.canManageDeposits)
        canViewInvoices        = b(.canViewInvoices)
        canManageInvoices      = b(.canManageInvoices)
        canViewPayments        = b(.canViewPayments)
        canManagePayments      = b(.canManagePayments)
        canViewPricing         = b(.canViewPricing)
        canManagePricing       = b(.canManagePricing)
        canViewDebours         = b(.canViewDebours)
        canManageDebours       = b(.canManageDebours)
        canViewReporting       = b(.canViewReporting)

        notifSubNewReservation       = b(.notifSubNewReservation)
        notifSubReservationCancelled = b(.notifSubReservationCancelled)
        notifSubCleaningAssigned     = b(.notifSubCleaningAssigned)
        notifSubCleaningCompleted    = b(.notifSubCleaningCompleted)
        notifSubDepositPaid          = b(.notifSubDepositPaid)
        notifSubPaymentReceived      = b(.notifSubPaymentReceived)
        notifSubNewMessage           = b(.notifSubNewMessage)
        notifSubDailySummary         = b(.notifSubDailySummary)
    }

    // convertFromSnakeCase du décodeur gère la conversion snake_case → camelCase.
    private enum CodingKeys: CodingKey {
        case id, email, firstName, lastName, role, isActive, createdAt, lastLogin
        case canViewCalendar, canEditReservations, canCreateReservations, canDeleteReservations
        case canViewMessages, canSendMessages, canViewTemplates, canManageTemplates
        case canViewCleaning, canAssignCleaning, canManageCleaningStaff
        case canViewProperties, canEditProperties, canViewSmartLocks, canManageSmartLocks
        case canViewWelcomeBook, canAccessSettings, canManageTeam
        case canViewOwners, canViewContracts
        case canViewFinances, canEditFinances, canViewDeposits, canManageDeposits
        case canViewInvoices, canManageInvoices, canViewPayments, canManagePayments
        case canViewPricing, canManagePricing, canViewDebours, canManageDebours
        case canViewReporting
        case notifSubNewReservation, notifSubReservationCancelled
        case notifSubCleaningAssigned, notifSubCleaningCompleted
        case notifSubDepositPaid, notifSubPaymentReceived
        case notifSubNewMessage, notifSubDailySummary
    }

    // MARK: - Hashable (par id, suffisant pour NavigationLink)

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SubAccount, rhs: SubAccount) -> Bool { lhs.id == rhs.id }
}

// MARK: - Propriétés d'affichage

extension SubAccount {

    var displayName: String {
        [firstName, lastName]
            .compactMap { s -> String? in guard let s, !s.isEmpty else { return nil }; return s }
            .joined(separator: " ")
    }

    var initials: String {
        displayName.split(separator: " ").prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }

    var roleLabel: String {
        switch role {
        case "owner":      return "Propriétaire"
        case "manager":    return "Manager"
        case "cleaner":    return "Prestataire ménage"
        case "accountant": return "Comptable"
        case "custom":     return "Personnalisé"
        default:           return role ?? "—"
        }
    }

    /// Résumé des domaines ayant au moins un droit accordé.
    var rightsSummary: String {
        var domains: [String] = []
        if canViewCalendar || canEditReservations || canCreateReservations || canDeleteReservations {
            domains.append("Calendrier")
        }
        if canViewMessages || canSendMessages || canViewTemplates || canManageTemplates {
            domains.append("Messages")
        }
        if canViewCleaning || canAssignCleaning || canManageCleaningStaff {
            domains.append("Ménage")
        }
        if canViewProperties || canEditProperties || canViewSmartLocks || canManageSmartLocks
            || canViewWelcomeBook || canAccessSettings || canManageTeam {
            domains.append("Logements")
        }
        if canViewOwners || canViewContracts {
            domains.append("Propriétaires")
        }
        if canViewFinances || canEditFinances || canViewDeposits || canManageDeposits
            || canViewInvoices || canManageInvoices || canViewPayments || canManagePayments
            || canViewPricing || canManagePricing || canViewDebours || canManageDebours
            || canViewReporting {
            domains.append("Argent")
        }
        if domains.count == 6 { return "Tous les droits" }
        return domains.isEmpty ? "Aucun accès" : domains.joined(separator: ", ")
    }
}

// MARK: - État local pour l'édition des droits

struct PermissionsEditState {
    var canViewCalendar: Bool
    var canEditReservations: Bool
    var canCreateReservations: Bool
    var canDeleteReservations: Bool
    var canViewMessages: Bool
    var canSendMessages: Bool
    var canViewTemplates: Bool
    var canManageTemplates: Bool
    var canViewCleaning: Bool
    var canAssignCleaning: Bool
    var canManageCleaningStaff: Bool
    var canViewProperties: Bool
    var canEditProperties: Bool
    var canViewSmartLocks: Bool
    var canManageSmartLocks: Bool
    var canViewWelcomeBook: Bool
    var canAccessSettings: Bool
    var canManageTeam: Bool
    var canViewOwners: Bool
    var canViewContracts: Bool
    var canViewFinances: Bool
    var canEditFinances: Bool
    var canViewDeposits: Bool
    var canManageDeposits: Bool
    var canViewInvoices: Bool
    var canManageInvoices: Bool
    var canViewPayments: Bool
    var canManagePayments: Bool
    var canViewPricing: Bool
    var canManagePricing: Bool
    var canViewDebours: Bool
    var canManageDebours: Bool
    var canViewReporting: Bool
    var notifSubNewReservation: Bool
    var notifSubReservationCancelled: Bool
    var notifSubCleaningAssigned: Bool
    var notifSubCleaningCompleted: Bool
    var notifSubDepositPaid: Bool
    var notifSubPaymentReceived: Bool
    var notifSubNewMessage: Bool
    var notifSubDailySummary: Bool

    init(from m: SubAccount) {
        canViewCalendar           = m.canViewCalendar
        canEditReservations       = m.canEditReservations
        canCreateReservations     = m.canCreateReservations
        canDeleteReservations     = m.canDeleteReservations
        canViewMessages           = m.canViewMessages
        canSendMessages           = m.canSendMessages
        canViewTemplates          = m.canViewTemplates
        canManageTemplates        = m.canManageTemplates
        canViewCleaning           = m.canViewCleaning
        canAssignCleaning         = m.canAssignCleaning
        canManageCleaningStaff    = m.canManageCleaningStaff
        canViewProperties         = m.canViewProperties
        canEditProperties         = m.canEditProperties
        canViewSmartLocks         = m.canViewSmartLocks
        canManageSmartLocks       = m.canManageSmartLocks
        canViewWelcomeBook        = m.canViewWelcomeBook
        canAccessSettings         = m.canAccessSettings
        canManageTeam             = m.canManageTeam
        canViewOwners             = m.canViewOwners
        canViewContracts          = m.canViewContracts
        canViewFinances           = m.canViewFinances
        canEditFinances           = m.canEditFinances
        canViewDeposits           = m.canViewDeposits
        canManageDeposits         = m.canManageDeposits
        canViewInvoices           = m.canViewInvoices
        canManageInvoices         = m.canManageInvoices
        canViewPayments           = m.canViewPayments
        canManagePayments         = m.canManagePayments
        canViewPricing            = m.canViewPricing
        canManagePricing          = m.canManagePricing
        canViewDebours            = m.canViewDebours
        canManageDebours          = m.canManageDebours
        canViewReporting          = m.canViewReporting
        notifSubNewReservation    = m.notifSubNewReservation
        notifSubReservationCancelled = m.notifSubReservationCancelled
        notifSubCleaningAssigned  = m.notifSubCleaningAssigned
        notifSubCleaningCompleted = m.notifSubCleaningCompleted
        notifSubDepositPaid       = m.notifSubDepositPaid
        notifSubPaymentReceived   = m.notifSubPaymentReceived
        notifSubNewMessage        = m.notifSubNewMessage
        notifSubDailySummary      = m.notifSubDailySummary
    }

    func toRequest(firstName: String, lastName: String) -> SubAccountUpdateRequest {
        SubAccountUpdateRequest(
            firstName: firstName,
            lastName: lastName,
            role: "custom",
            permissions: .init(
                canViewReservations:    canViewCalendar,
                canEditReservations:    canEditReservations,
                canCreateReservations:  canCreateReservations,
                canDeleteReservations:  canDeleteReservations,
                canViewMessages:        canViewMessages,
                canSendMessages:        canSendMessages,
                canViewTemplates:       canViewTemplates,
                canManageTemplates:     canManageTemplates,
                canViewCleaning:        canViewCleaning,
                canManageCleaning:      canAssignCleaning,
                canManageCleaningStaff: canManageCleaningStaff,
                canViewProperties:      canViewProperties,
                canEditProperties:      canEditProperties,
                canViewSmartLocks:      canViewSmartLocks,
                canManageSmartLocks:    canManageSmartLocks,
                canViewWelcomeBook:     canViewWelcomeBook,
                canAccessSettings:      canAccessSettings,
                canManageTeam:          canManageTeam,
                canViewOwners:          canViewOwners,
                canViewContracts:       canViewContracts,
                canViewFinances:        canViewFinances,
                canEditFinances:        canEditFinances,
                canViewDeposits:        canViewDeposits,
                canManageDeposits:      canManageDeposits,
                canViewInvoices:        canViewInvoices,
                canManageInvoices:      canManageInvoices,
                canViewPayments:        canViewPayments,
                canManagePayments:      canManagePayments,
                canViewPricing:         canViewPricing,
                canManagePricing:       canManagePricing,
                canViewDebours:         canViewDebours,
                canManageDebours:       canManageDebours,
                canViewReporting:       canViewReporting
            ),
            notifications: .init(
                notifSubNewReservation:      notifSubNewReservation,
                notifSubReservationCancelled: notifSubReservationCancelled,
                notifSubCleaningAssigned:    notifSubCleaningAssigned,
                notifSubCleaningCompleted:   notifSubCleaningCompleted,
                notifSubDepositPaid:         notifSubDepositPaid,
                notifSubPaymentReceived:     notifSubPaymentReceived,
                notifSubNewMessage:          notifSubNewMessage,
                notifSubDailySummary:        notifSubDailySummary
            ),
            propertyIds: []
        )
    }
}

// MARK: - Corps du PUT /api/sub-accounts/:id
// Clés de permissions : alias front (can_view_reservations, can_manage_cleaning…),
// pas les noms de colonnes DB. Le serveur fait la traduction.

struct SubAccountUpdateRequest: Encodable {
    let firstName: String
    let lastName: String
    let role: String
    let permissions: PermissionsPayload
    let notifications: NotificationsPayload
    let propertyIds: [Int]

    struct PermissionsPayload: Encodable {
        var canViewReservations: Bool
        var canEditReservations: Bool
        var canCreateReservations: Bool
        var canDeleteReservations: Bool
        var canViewMessages: Bool
        var canSendMessages: Bool
        var canViewTemplates: Bool
        var canManageTemplates: Bool
        var canViewCleaning: Bool
        var canManageCleaning: Bool
        var canManageCleaningStaff: Bool
        var canViewProperties: Bool
        var canEditProperties: Bool
        var canViewSmartLocks: Bool
        var canManageSmartLocks: Bool
        var canViewWelcomeBook: Bool
        var canAccessSettings: Bool
        var canManageTeam: Bool
        var canViewOwners: Bool
        var canViewContracts: Bool
        var canViewFinances: Bool
        var canEditFinances: Bool
        var canViewDeposits: Bool
        var canManageDeposits: Bool
        var canViewInvoices: Bool
        var canManageInvoices: Bool
        var canViewPayments: Bool
        var canManagePayments: Bool
        var canViewPricing: Bool
        var canManagePricing: Bool
        var canViewDebours: Bool
        var canManageDebours: Bool
        var canViewReporting: Bool

        enum CodingKeys: String, CodingKey {
            case canViewReservations    = "can_view_reservations"
            case canEditReservations    = "can_edit_reservations"
            case canCreateReservations  = "can_create_reservations"
            case canDeleteReservations  = "can_delete_reservations"
            case canViewMessages        = "can_view_messages"
            case canSendMessages        = "can_send_messages"
            case canViewTemplates       = "can_view_templates"
            case canManageTemplates     = "can_manage_templates"
            case canViewCleaning        = "can_view_cleaning"
            case canManageCleaning      = "can_manage_cleaning"
            case canManageCleaningStaff = "can_manage_cleaning_staff"
            case canViewProperties      = "can_view_properties"
            case canEditProperties      = "can_edit_properties"
            case canViewSmartLocks      = "can_view_smart_locks"
            case canManageSmartLocks    = "can_manage_smart_locks"
            case canViewWelcomeBook     = "can_view_welcome_book"
            case canAccessSettings      = "can_access_settings"
            case canManageTeam          = "can_manage_team"
            case canViewOwners          = "can_view_owners"
            case canViewContracts       = "can_view_contracts"
            case canViewFinances        = "can_view_finances"
            case canEditFinances        = "can_edit_finances"
            case canViewDeposits        = "can_view_deposits"
            case canManageDeposits      = "can_manage_deposits"
            case canViewInvoices        = "can_view_invoices"
            case canManageInvoices      = "can_manage_invoices"
            case canViewPayments        = "can_view_payments"
            case canManagePayments      = "can_manage_payments"
            case canViewPricing         = "can_view_pricing"
            case canManagePricing       = "can_manage_pricing"
            case canViewDebours         = "can_view_debours"
            case canManageDebours       = "can_manage_debours"
            case canViewReporting       = "can_view_reporting"
        }
    }

    struct NotificationsPayload: Encodable {
        var notifSubNewReservation: Bool
        var notifSubReservationCancelled: Bool
        var notifSubCleaningAssigned: Bool
        var notifSubCleaningCompleted: Bool
        var notifSubDepositPaid: Bool
        var notifSubPaymentReceived: Bool
        var notifSubNewMessage: Bool
        var notifSubDailySummary: Bool

        enum CodingKeys: String, CodingKey {
            case notifSubNewReservation      = "notif_sub_new_reservation"
            case notifSubReservationCancelled = "notif_sub_reservation_cancelled"
            case notifSubCleaningAssigned    = "notif_sub_cleaning_assigned"
            case notifSubCleaningCompleted   = "notif_sub_cleaning_completed"
            case notifSubDepositPaid         = "notif_sub_deposit_paid"
            case notifSubPaymentReceived     = "notif_sub_payment_received"
            case notifSubNewMessage          = "notif_sub_new_message"
            case notifSubDailySummary        = "notif_sub_daily_summary"
        }
    }
}

// MARK: - Groupes de permissions pour la vue détail

extension SubAccount {

    struct PermissionGroup {
        let title: String
        let collapsedLabel: String
        let entries: [Entry]

        init(title: String, entries: [Entry], collapsedLabel: String = "Aucun accès") {
            self.title          = title
            self.entries        = entries
            self.collapsedLabel = collapsedLabel
        }

        var shouldCollapse: Bool {
            !entries.contains { $0.granted }
        }

        struct Entry {
            let label: String
            let kind: Kind
            let granted: Bool
        }

        enum Kind {
            case read   // can_view_* — tête de groupe, non indenté
            case write  // droits d'écriture — indenté
        }
    }

    /// Les 41 colonnes de permissions du relevé (33 can_* + 8 notif_sub_*),
    /// groupées dans l'ordre Calendrier · Messages · Ménage · Logements · Propriétaires · Argent.
    var permissionGroups: [PermissionGroup] {
        typealias E = PermissionGroup.Entry
        typealias K = PermissionGroup.Kind

        return [
            PermissionGroup(title: "Calendrier", entries: [
                E(label: "Voir le calendrier",              kind: .read,  granted: canViewCalendar),
                E(label: "Modifier les réservations",       kind: .write, granted: canEditReservations),
                E(label: "Créer des réservations",          kind: .write, granted: canCreateReservations),
                E(label: "Supprimer des réservations",      kind: .write, granted: canDeleteReservations),
            ]),
            PermissionGroup(title: "Messages", entries: [
                E(label: "Voir les messages",               kind: .read,  granted: canViewMessages),
                E(label: "Envoyer des messages",            kind: .write, granted: canSendMessages),
                E(label: "Voir les modèles automatiques",   kind: .read,  granted: canViewTemplates),
                E(label: "Gérer les modèles automatiques",  kind: .write, granted: canManageTemplates),
            ]),
            PermissionGroup(title: "Ménage", entries: [
                E(label: "Voir les assignations",           kind: .read,  granted: canViewCleaning),
                E(label: "Assigner les ménages",            kind: .write, granted: canAssignCleaning),
                E(label: "Gérer les prestataires",          kind: .write, granted: canManageCleaningStaff),
            ]),
            PermissionGroup(title: "Logements", entries: [
                E(label: "Voir les logements",              kind: .read,  granted: canViewProperties),
                E(label: "Voir les livrets d'accueil",      kind: .read,  granted: canViewWelcomeBook),
                E(label: "Voir les serrures connectées",    kind: .read,  granted: canViewSmartLocks),
                E(label: "Modifier les logements",          kind: .write, granted: canEditProperties),
                E(label: "Gérer les serrures connectées",   kind: .write, granted: canManageSmartLocks),
                E(label: "Accéder aux paramètres",          kind: .write, granted: canAccessSettings),
                E(label: "Gérer l'équipe",                  kind: .write, granted: canManageTeam),
            ]),
            PermissionGroup(title: "Propriétaires", entries: [
                E(label: "Voir les propriétaires",          kind: .read,  granted: canViewOwners),
                E(label: "Voir les contrats",               kind: .read,  granted: canViewContracts),
            ]),
            PermissionGroup(title: "Argent", entries: [
                E(label: "Voir les finances",               kind: .read,  granted: canViewFinances),
                E(label: "Voir les cautions",               kind: .read,  granted: canViewDeposits),
                E(label: "Voir les factures",               kind: .read,  granted: canViewInvoices),
                E(label: "Voir les paiements",              kind: .read,  granted: canViewPayments),
                E(label: "Voir les tarifs",                 kind: .read,  granted: canViewPricing),
                E(label: "Voir les débours",                kind: .read,  granted: canViewDebours),
                E(label: "Voir les rapports",               kind: .read,  granted: canViewReporting),
                E(label: "Modifier les finances",           kind: .write, granted: canEditFinances),
                E(label: "Gérer les cautions",              kind: .write, granted: canManageDeposits),
                E(label: "Gérer les factures",              kind: .write, granted: canManageInvoices),
                E(label: "Gérer les paiements",             kind: .write, granted: canManagePayments),
                E(label: "Gérer les tarifs",                kind: .write, granted: canManagePricing),
                E(label: "Gérer les débours",               kind: .write, granted: canManageDebours),
            ]),
            // Préférences de notifications — distinctes des droits d'accès
            PermissionGroup(
                title: "Notifications reçues",
                entries: [
                    E(label: "Nouvelle réservation",        kind: .read, granted: notifSubNewReservation),
                    E(label: "Annulation de réservation",   kind: .read, granted: notifSubReservationCancelled),
                    E(label: "Récap quotidien",             kind: .read, granted: notifSubDailySummary),
                    E(label: "Nouveau message",             kind: .read, granted: notifSubNewMessage),
                    E(label: "Ménage assigné",              kind: .read, granted: notifSubCleaningAssigned),
                    E(label: "Ménage terminé",              kind: .read, granted: notifSubCleaningCompleted),
                    E(label: "Caution reçue",               kind: .read, granted: notifSubDepositPaid),
                    E(label: "Paiement reçu",               kind: .read, granted: notifSubPaymentReceived),
                ],
                collapsedLabel: "Aucune alerte active"
            ),
        ]
    }
}
