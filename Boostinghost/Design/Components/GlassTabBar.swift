import SwiftUI

// MARK: - Onglets disponibles

enum AppTab: String, CaseIterable, Hashable {
    case today    = "Aujourd'hui"
    case calendar = "Calendrier"
    case messages = "Messages"
    case manage   = "Gestion"

    var icon: String {
        switch self {
        case .today:    return "calendar.day.timeline.left"
        case .calendar: return "calendar"
        case .messages: return "bubble.left.and.bubble.right"
        case .manage:   return "square.grid.2x2"
        }
    }

    func isVisible(for session: Session?) -> Bool {
        guard let session, session.isSubAccount else { return true }
        switch self {
        case .today:    return session.can("can_view_calendar")
        case .calendar: return session.can("can_view_calendar")
        case .messages: return session.can("can_view_messages")
        case .manage:
            return session.canAny(
                "can_view_properties",
                "can_view_cleaning",
                "can_view_owners",
                "can_view_invoices"
            )
        }
    }

    static func visible(for session: Session?) -> [AppTab] {
        allCases.filter { $0.isVisible(for: session) }
    }
}

// MARK: - Conteneur principal

struct MainTabView: View {
    @Environment(AuthStore.self) var authStore
    @Environment(SetupViewModel.self) private var setupVM
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .today
    @State private var calendarVM = CalendarViewModel()
    @State private var messagesVM = MessagesViewModel()
    @State private var showSupportSheet = false

    private var router: NotificationRouter { NotificationRouter.shared }
    private var hostQM: HostQuestionManager { HostQuestionManager.shared }
    private var session: Session? { authStore.session }
    private var visibleTabs: [AppTab] { AppTab.visible(for: session) }

    var body: some View {
        ZStack {
            AppBackground()

            if visibleTabs.count == 1, let only = visibleTabs.first {
                featureView(for: only)
            } else {
                TabView(selection: $selectedTab) {
                    if AppTab.today.isVisible(for: session) {
                        Tab(AppTab.today.rawValue, systemImage: AppTab.today.icon, value: AppTab.today) {
                            featureView(for: .today)
                        }
                    }
                    if AppTab.calendar.isVisible(for: session) {
                        Tab(AppTab.calendar.rawValue, systemImage: AppTab.calendar.icon, value: AppTab.calendar) {
                            featureView(for: .calendar)
                        }
                    }
                    if AppTab.messages.isVisible(for: session) {
                        Tab(AppTab.messages.rawValue, systemImage: AppTab.messages.icon, value: AppTab.messages) {
                            featureView(for: .messages)
                        }
                        .badge(messagesVM.unreadCount)
                    }
                    if AppTab.manage.isVisible(for: session) {
                        Tab(AppTab.manage.rawValue, systemImage: AppTab.manage.icon, value: AppTab.manage) {
                            featureView(for: .manage)
                        }
                    }
                }
            }
        }
        .environment(calendarVM)
        .environment(messagesVM)
        .task {
            messagesVM.agencyAll = authStore.agencyAll
            await messagesVM.load()
            hostQM.startPolling()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    messagesVM.agencyAll = authStore.agencyAll
                    await messagesVM.load()
                }
                hostQM.startPolling()
            } else if phase == .background {
                hostQM.stopPolling()
            }
        }
        .onChange(of: authStore.accountSwitchTrigger) {
            selectedTab = .today
        }
        // Cold start / background: pendingTab may have been set before this view mounted.
        // onChange only fires on *changes*, so also consume on appear.
        .onAppear {
            if let tab = router.pendingTab, tab.isVisible(for: session) {
                #if DEBUG
                print("[PUSHREQ] applying pendingTab=\(tab.rawValue) on appear (cold start)")
                #endif
                selectedTab = tab
                NotificationRouter.shared.pendingTab = nil
            }
        }
        .onChange(of: router.pendingTab) { _, tab in
            guard let tab else { return }
            if tab.isVisible(for: session) { selectedTab = tab }
            NotificationRouter.shared.pendingTab = nil
        }
        .onChange(of: router.openSupport) { _, open in
            guard open else { return }
            showSupportSheet = true
            NotificationRouter.shared.openSupport = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToToday)) { _ in
            if AppTab.today.isVisible(for: session) { selectedTab = .today }
        }
        .sheet(isPresented: $showSupportSheet) {
            AccountSheet(initialDestination: .support)
                .environment(authStore)
                .environment(setupVM)
        }
        .onDisappear { hostQM.stopPolling() }
    }

    // MARK: - Vues des onglets

    @ViewBuilder
    private func featureView(for tab: AppTab) -> some View {
        switch tab {
        case .today:
            TodayView(selectedTab: $selectedTab, onSwitchToCalendar: {
                if AppTab.calendar.isVisible(for: session) { selectedTab = .calendar }
            })
        case .calendar:
            CalendarView(selectedTab: $selectedTab)
        case .messages:
            MessagesView()
        case .manage:
            ManageHubView()
        }
    }
}
