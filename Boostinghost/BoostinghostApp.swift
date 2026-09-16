import SwiftUI
import FirebaseCore
import FirebaseMessaging

@main
struct BoostinghostApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var authStore = AuthStore()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environment(authStore)
                    .task { await authStore.verifyOnLaunch() }

                if showSplash {
                    SplashView(onFinish: { showSplash = false })
                }
            }
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
        UNUserNotificationCenter.current().delegate = PushNotificationManager.shared
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

    private let onboarding = OnboardingCoordinator.shared
    @State private var setupVM = SetupViewModel()

    var body: some View {
        Group {
            switch authStore.appState {
            case .loading:
                Color.clear.ignoresSafeArea()
            case .authenticated:
                MainTabView()
                    .environment(setupVM)
                    // fullScreenCover is only presented once hasLoaded = true
                    // and isShowingOnboarding = true, preventing any flash for
                    // existing accounts while preferences are being fetched.
                    .fullScreenCover(
                        isPresented: Binding(
                            get: { onboarding.hasLoaded && onboarding.isShowingOnboarding },
                            set: { _ in }
                        )
                    ) {
                        OnboardingFlowView()
                            .environment(authStore)
                            .environment(setupVM)
                    }
            case .unauthenticated:
                LoginView()
            }
        }
        .onChange(of: authStore.appState) { _, newState in
            switch newState {
            case .authenticated:
                Task { await PushNotificationManager.shared.requestAuthorization() }
                if let session = authStore.session {
                    Task { await onboarding.load(session: session) }
                }
            case .unauthenticated:
                onboarding.reset()
                setupVM.reset()
            case .loading:
                break
            }
        }
        // Account switch (agency context change or sub-account login):
        // reset the coordinator and reload for the new effective session.
        .onChange(of: authStore.accountSwitchTrigger) { _, _ in
            onboarding.reset()
            if authStore.appState == .authenticated, let session = authStore.session {
                Task { await onboarding.load(session: session) }
            }
        }
    }
}
