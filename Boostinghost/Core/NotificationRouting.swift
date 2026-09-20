import SwiftUI

// MARK: - Consommation des intentions de notification
//
// Un tap sur notification pose une intention dans NotificationRouter. Elle doit
// être consommée à DEUX moments : au montage de la vue (démarrage à froid — la
// vue n'existait pas encore quand l'intention a été posée) et sur changement
// (app déjà ouverte). Ces modifiers font les deux ; chaque écran n'a plus qu'une
// ligne à ajouter.

private struct PendingRouteTrigger: ViewModifier {
    let action: @MainActor () -> Void
    private var router: NotificationRouter { NotificationRouter.shared }

    func body(content: Content) -> some View {
        content
            .task { action() }
            .onChange(of: router.pendingTab)            { _, _ in action() }
            .onChange(of: router.openSupport)           { _, _ in action() }
            .onChange(of: router.pendingConversationId) { _, _ in action() }
            .onChange(of: router.pendingCalendarDate)   { _, _ in action() }
            .onChange(of: router.calendarNeedsRefresh)  { _, _ in action() }
            .onChange(of: router.pendingManageEntry)    { _, _ in action() }
            .onChange(of: router.pendingChecklistId)    { _, _ in action() }
            .onChange(of: router.pendingDepositId)      { _, _ in action() }
            .onChange(of: router.pendingContractId)     { _, _ in action() }
    }
}

extension View {
    /// Exécute `perform` au montage puis à chaque intention posée par une notification.
    func onPendingRoute(perform action: @MainActor @escaping () -> Void) -> some View {
        modifier(PendingRouteTrigger(action: action))
    }

    // MARK: MainTabView

    func pushTabRoute(
        selectedTab: Binding<AppTab>,
        session: Session?,
        showSupport: Binding<Bool>
    ) -> some View {
        onPendingRoute {
            let router = NotificationRouter.shared
            if let tab = router.takeTab(), tab.isVisible(for: session) {
                selectedTab.wrappedValue = tab
            }
            if router.takeSupport() {
                showSupport.wrappedValue = true
            }
        }
    }

    // MARK: MessagesView

    func pushConversationRoute(
        path: Binding<[Conversation]>,
        vm: MessagesViewModel,
        reload: @escaping () async -> Void
    ) -> some View {
        onPendingRoute {
            let router = NotificationRouter.shared
            if router.takeMessagesFilter() == .aReprendre { vm.filter = .aReprendre }
            guard let convId = router.takeConversationId() else { return }
            if let conv = vm.conversations.first(where: { $0.id == convId }) {
                path.wrappedValue = [conv]          // remplace la pile : pas de doublon
            } else {
                Task {
                    await reload()
                    if let conv = vm.conversations.first(where: { $0.id == convId }) {
                        path.wrappedValue = [conv]
                    }
                }
            }
        }
    }

    // MARK: CalendarView

    func pushCalendarRoute(vm: CalendarViewModel) -> some View {
        onPendingRoute {
            let router = NotificationRouter.shared
            if let date = router.takeCalendarDate() {
                vm.selectedMonthKey = NotificationRouteFormat.month.string(from: date)
                vm.selectedDayKey   = NotificationRouteFormat.day.string(from: date)
            }
            if router.takeCalendarRefresh() {
                Task { await vm.silentRefresh() }
            }
        }
    }

    // MARK: ManageHubView

    func pushManageRoute(path: Binding<[ManageEntry]>, session: Session?) -> some View {
        onPendingRoute {
            guard let entry = NotificationRouter.shared.takeManageEntry(),
                  entry.isVisible(for: session) else { return }
            path.wrappedValue = [entry]
        }
    }
}

// Formats attendus par CalendarViewModel (`selectedMonthKey`, `selectedDayKey`).
// À vérifier une fois contre les valeurs par défaut du view model si l'app
// n'atterrit pas sur le bon mois.
enum NotificationRouteFormat {
    static let month: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Paris")
        f.dateFormat = "yyyy-MM"
        return f
    }()

    static let day: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Paris")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
