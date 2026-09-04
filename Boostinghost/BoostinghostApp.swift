import SwiftUI
import FirebaseCore
import FirebaseMessaging

@main
struct BoostinghostApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var authStore = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authStore)
                .task { await authStore.verifyOnLaunch() }
        }
    }
}

// MARK: - App delegate

private final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = PushNotificationManager.shared
        return true
    }

    // Forward the APNs device token to Firebase so it can map it to an FCM token.
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {}
}

// MARK: - Root routing

private struct RootView: View {
    @Environment(AuthStore.self) var authStore

    var body: some View {
        Group {
            switch authStore.appState {
            case .loading:
                Color.clear.ignoresSafeArea()
            case .authenticated:
                MainTabView()
            case .unauthenticated:
                LoginView()
            }
        }
        // Request notification permission on every transition to .authenticated.
        // UNUserNotificationCenter shows the system dialog only once; subsequent
        // calls silently renew the APNs token — the recommended pattern.
        .onChange(of: authStore.appState) { _, newState in
            if newState == .authenticated {
                Task { await PushNotificationManager.shared.requestAuthorization() }
            }
        }
    }
}
