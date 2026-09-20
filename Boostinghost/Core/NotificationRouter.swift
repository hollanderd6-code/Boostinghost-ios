import Foundation

// MARK: - Intentions de navigation posées par une notification
//
// Règle de fonctionnement : le routeur POSE une intention, la vue la CONSOMME.
// La consommation doit se faire à deux endroits — au montage de la vue (`.task`)
// ET sur changement (`.onChange`) — parce qu'un tap sur notification au
// démarrage à froid pose l'intention AVANT que la vue existe. C'est la cause du
// bug « toutes les notifications ouvrent Aujourd'hui quand l'app était fermée ».

@Observable
@MainActor
final class NotificationRouter {

    static let shared = NotificationRouter()
    private init() {}

    enum MessagesFilterIntent { case aReprendre }

    // Onglet cible
    var pendingTab: AppTab? = nil
    var openSupport: Bool = false

    // Messages
    var pendingConversationId: Int? = nil
    var pendingMessagesFilter: MessagesFilterIntent? = nil

    // Calendrier
    var pendingCalendarDate: Date? = nil
    var calendarNeedsRefresh: Bool = false

    // Gestion
    var pendingManageEntry: ManageEntry? = nil
    var pendingChecklistId: String? = nil
    var pendingDepositId: String? = nil
    var pendingContractId: String? = nil

    // MARK: - Consommation (lit puis efface)

    func takeTab() -> AppTab? {
        defer { pendingTab = nil }
        return pendingTab
    }

    func takeSupport() -> Bool {
        defer { openSupport = false }
        return openSupport
    }

    func takeConversationId() -> Int? {
        defer { pendingConversationId = nil }
        return pendingConversationId
    }

    func takeMessagesFilter() -> MessagesFilterIntent? {
        defer { pendingMessagesFilter = nil }
        return pendingMessagesFilter
    }

    func takeCalendarDate() -> Date? {
        defer { pendingCalendarDate = nil }
        return pendingCalendarDate
    }

    func takeCalendarRefresh() -> Bool {
        defer { calendarNeedsRefresh = false }
        return calendarNeedsRefresh
    }

    func takeManageEntry() -> ManageEntry? {
        defer { pendingManageEntry = nil }
        return pendingManageEntry
    }

    func takeChecklistId() -> String? {
        defer { pendingChecklistId = nil }
        return pendingChecklistId
    }

    func takeDepositId() -> String? {
        defer { pendingDepositId = nil }
        return pendingDepositId
    }

    func takeContractId() -> String? {
        defer { pendingContractId = nil }
        return pendingContractId
    }

    // Déconnexion ou changement de compte : une intention posée pour le compte
    // précédent ne doit pas s'appliquer au suivant.
    func reset() {
        pendingTab = nil
        openSupport = false
        pendingConversationId = nil
        pendingMessagesFilter = nil
        pendingCalendarDate = nil
        calendarNeedsRefresh = false
        pendingManageEntry = nil
        pendingChecklistId = nil
        pendingDepositId = nil
        pendingContractId = nil
    }
}
