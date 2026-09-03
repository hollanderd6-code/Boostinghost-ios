import SwiftUI

// MARK: - Visibilité de la barre d'onglets

private struct TabBarHiddenKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var tabBarHidden: Binding<Bool> {
        get { self[TabBarHiddenKey.self] }
        set { self[TabBarHiddenKey.self] = newValue }
    }
}

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

    /// Retourne true si cet onglet est visible pour la session donnée.
    func isVisible(for session: Session?) -> Bool {
        guard let session, session.isSubAccount else { return true }
        switch self {
        case .today:
            return session.can("can_view_calendar")
        case .calendar:
            return session.can("can_view_calendar")
        case .messages:
            return session.can("can_view_messages")
        case .manage:
            return session.canAny(
                "can_view_properties",
                "can_view_cleaning",
                "can_view_owners",
                "can_view_invoices"
            )
        }
    }

    /// Liste des onglets filtrés selon les droits.
    static func visible(for session: Session?) -> [AppTab] {
        allCases.filter { $0.isVisible(for: session) }
    }
}

// MARK: - Barre d'onglets flottante

/// Affichée seulement quand trois onglets ou plus sont visibles.
/// En dessous de trois, chaque feature s'affiche directement.
struct GlassTabBar: View {
    let tabs: [AppTab]
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                tabItem(tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .glassEffect(in: .rect(cornerRadius: 30))
        .specularEdge(cornerRadius: 30)
        .chromeShadow()
        .padding(.horizontal, 20)
    }

    private func tabItem(_ tab: AppTab) -> some View {
        let active = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .imageScale(.medium)
                    .frame(height: 22)
                Text(tab.rawValue)
                    .font(.bhOnglet)
            }
            .foregroundStyle(active ? Color.bhVert : Color.bhAttenue)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: selection)
    }
}

// MARK: - Conteneur principal qui choisit l'affichage selon les droits

struct MainTabView: View {
    @Environment(AuthStore.self) var authStore
    @State private var selection: AppTab = .today
    @State private var tabBarHidden = false

    private var tabs: [AppTab] {
        AppTab.visible(for: authStore.session)
    }

    var body: some View {
        ZStack {
            AppBackground()

            // Si un seul onglet : navigation directe, pas de barre
            if tabs.count == 1, let only = tabs.first {
                featureView(for: only)
                    .environment(\.tabBarHidden, $tabBarHidden)
            } else {
                ZStack(alignment: .bottom) {
                    featureView(for: selection)
                        .safeAreaInset(edge: .bottom) {
                            if tabs.count >= 3 && !tabBarHidden {
                                Color.clear.frame(height: 80)
                            }
                        }
                        .environment(\.tabBarHidden, $tabBarHidden)

                    if tabs.count >= 3 && !tabBarHidden {
                        VStack {
                            Spacer()
                            GlassTabBar(tabs: tabs, selection: $selection)
                                .padding(.bottom, 12)
                        }
                        .ignoresSafeArea(edges: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .onChange(of: authStore.accountSwitchTrigger) {
            selection = .today
        }
    }

    @ViewBuilder
    private func featureView(for tab: AppTab) -> some View {
        switch tab {
        case .today:
            TodayView(onSwitchToCalendar: { selection = .calendar })
        case .calendar:
            CalendarView()
        case .messages:
            MessagesView()
        case .manage:
            ManageHubView()
        }
    }
}
