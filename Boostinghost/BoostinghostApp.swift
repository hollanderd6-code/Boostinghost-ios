import SwiftUI

@main
struct BoostinghostApp: App {
    @State private var authStore = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authStore)
                .task { await authStore.verifyOnLaunch() }
        }
    }
}

// MARK: - Root routing

private struct RootView: View {
    @Environment(AuthStore.self) var authStore

    var body: some View {
        switch authStore.appState {
        case .loading:
            Color.clear.ignoresSafeArea()
        case .authenticated:
            MainTabView()
        case .unauthenticated:
            LoginView()
        }
    }
}

