import FirebaseMessaging
import UIKit
import UserNotifications

@MainActor
@Observable
final class PushNotificationManager: NSObject {

    static let shared = PushNotificationManager()

    private(set) var fcmToken: String?

    // Called on every transition to .authenticated (login, re-launch, account change).
    // UNUserNotificationCenter shows the system dialog only once; subsequent calls
    // silently renew the APNs registration — the recommended pattern at each launch.
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
        print("[DEBUG-SAVETOKEN] trigger=requestAuthorization fcmToken-in-memory=\(fcmToken?.prefix(20).description ?? "nil") sdk-cache=\(Messaging.messaging().fcmToken?.prefix(20).description ?? "nil")")
        await sendToken()
    }

    // Sends the current FCM token to the backend bound to the authenticated user.
    // identifierForVendor is stable for the lifetime of the app install on this device.
    // The server deletes any previous row for this token on a different account before
    // inserting, so re-calling after an account change is safe and idempotent.
    func sendToken() async {
        // The in-memory copy is nil on launches where Firebase did not re-invoke the
        // delegate (stable token, already known to the SDK). Fall back to the SDK's
        // own cache so the token is always re-registered with the current user.
        let resolved = fcmToken ?? Messaging.messaging().fcmToken
        guard let token = resolved else {
            print("[DEBUG-SAVETOKEN] skip — fcmToken nil in memory and in SDK cache")
            return
        }
        if fcmToken == nil { fcmToken = token }

        let deviceId = UIDevice.current.identifierForVendor?.uuidString
        print("[DEBUG-SAVETOKEN] POST /api/save-token token=\(token.prefix(20))… device_id=\(deviceId ?? "nil") auth=\(await APIClient.shared.token != nil ? "set" : "nil")")
        let body = SaveTokenBody(token: token, device_type: "ios", device_id: deviceId)
        do {
            try await APIClient.shared.postVoid(Endpoint.saveToken, body: body)
            print("[DEBUG-SAVETOKEN] ✅ success")
        } catch {
            print("[DEBUG-SAVETOKEN] ❌ \(error)")
        }
    }
}

// MARK: - MessagingDelegate

extension PushNotificationManager: MessagingDelegate {

    // Firebase guarantees this is called on the main thread, but nonisolated
    // keeps Swift 6 strict concurrency happy when bridging the ObjC protocol.
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("[DEBUG-FCM] \(token)")
        print("[DEBUG-SAVETOKEN] trigger=delegate")
        Task { @MainActor [weak self] in
            self?.fcmToken = token
            await self?.sendToken()
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {

    // Display banner + sound even when the app is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Route the tap to the appropriate tab or screen.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        // Extract Sendable values before crossing the actor boundary.
        let type    = userInfo["type"] as? String ?? ""
        let convRaw = (userInfo["conversation_id"] as? String)
                   ?? (userInfo["conversationId"]  as? String)
        Task { @MainActor in
            let router = NotificationRouter.shared
            switch type {

            case "new_message", "new_guest_message",
                 "escalation", "negative_sentiment",
                 "upsell_paid":
                if let convId = convRaw.flatMap({ Int($0) }) {
                    router.pendingConversationId = convId
                }
                router.pendingTab = .messages

            case "host_question":
                await HostQuestionManager.shared.fetchPending()

            case "new_cleaning", "cleaning_reminder", "cleaning_alert",
                 "new_invoice",
                 "contract_signed",
                 "deposit_expiry_alert":
                router.pendingTab = .manage

            case "support":
                router.openSupport = true

            case "new_reservation", "new_booking", "new_booking_guest",
                 "cancelled_reservation", "arrivals", "departures",
                 "daily_arrivals", "daily_summary":
                router.pendingTab = .today
                NotificationCenter.default.post(name: .calendarShouldRefresh, object: nil)

            default:
                router.pendingTab = .today
            }
        }
        completionHandler()
    }
}

// MARK: - Private

private struct SaveTokenBody: Encodable {
    let token: String
    let device_type: String
    let device_id: String?
}
