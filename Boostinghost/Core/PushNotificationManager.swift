import FirebaseMessaging
import UIKit
import UserNotifications

@MainActor
@Observable
final class PushNotificationManager: NSObject {

    static let shared = PushNotificationManager()

    private(set) var fcmToken: String?

    // MARK: - Autorisation et jeton

    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
        await sendToken()
    }

    func sendToken() async {
        let resolved = fcmToken ?? Messaging.messaging().fcmToken
        guard let token = resolved else { return }
        if fcmToken == nil { fcmToken = token }

        let deviceId = UIDevice.current.identifierForVendor?.uuidString
        let body = SaveTokenBody(token: token, device_type: "ios", device_id: deviceId)
        try? await APIClient.shared.postVoid(Endpoint.saveToken, body: body)
    }

    // MARK: - Pastille et tiroir
    //
    // Le serveur n'envoie volontairement plus de `badge` dans le payload APNs
    // (« le badge est piloté par l'app »). Personne ne le pilotait : à appeler
    // au lancement, à chaque retour au premier plan et après chaque
    // MessagesViewModel.load().

    func refreshBadge(unread: Int) async {
        try? await UNUserNotificationCenter.current().setBadgeCount(max(0, unread))
    }

    func clearDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    // MARK: - Historique in-app
    //
    // Équivalent iOS de logNotificationToHistory() du client web : sans cet
    // appel, GET /api/notifications/history reste vide pour un utilisateur iOS.

    func logToHistory(title: String, body: String, type: String, data: [String: String]) async {
        let payload = NotificationHistoryBody(
            title: title,
            body: body,
            type: type.isEmpty ? "push" : type,
            data: data
        )
        try? await APIClient.shared.postVoid(Endpoint.notificationHistoryPush, body: payload)
    }
}

// MARK: - MessagingDelegate

extension PushNotificationManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        Task { @MainActor [weak self] in
            self?.fcmToken = token
            await self?.sendToken()
        }
    }
}

// MARK: - Table de routage
//
// Alignée sur ROUTES de public/js/push-notifications-handler.js (le routeur web
// est la référence tenue à jour). Tout type ajouté côté serveur doit être ajouté
// ici ; sinon il tombe dans le repli.
//
// Le payload est aplati en [String: String] AVANT de traverser vers le
// MainActor : [AnyHashable: Any] n'est pas Sendable et Swift 6 refuse de le
// capturer dans une closure isolée.

enum PushRoute {

    private static let messages: Set<String> = [
        "new_message", "new_chat_message", "new_guest_message",
        "chat_sms", "sms_reply", "upsell_paid", "negative_sentiment",
        "template_failed", "template_delivery_unknown"
    ]

    private static let messagesEscalated: Set<String> = [
        "escalation", "escalade", "escalade_message", "escalade_reminder"
    ]

    private static let calendar: Set<String> = [
        "new_reservation", "new_booking", "new_booking_guest", "new_booking_channex",
        "cancelled_reservation", "reservation_cancelled", "cancelled_booking_channex",
        "reservation_modified"
    ]

    private static let today: Set<String> = [
        "arrivals", "departures", "daily_arrivals", "check_in",
        "daily_summary", "monthly_summary", "reminder_j1",
        "hosterzz_mission"
    ]

    private static let cleaning: Set<String> = [
        "new_cleaning", "cleaning_reminder", "cleaning_alert", "cleaning_assigned",
        "cleaning_completed", "cleaning_validated", "cleaning_recap", "cleaning_lastminute",
        "cleaning_complement", "consumable_restock", "restock_assigned"
    ]

    private static let properties: Set<String> = ["smart_lock_battery"]

    private static let stays: Set<String> = [
        "new_deposit", "deposit_paid", "deposit_captured", "deposit_expiry_alert",
        "deposit_reminder", "deposit_auto_released", "caution", "payment_received",
        "new_invoice"
    ]

    private static let contracts: Set<String> = ["contract_signed"]

    /// Aplatit le userInfo APNs en dictionnaire Sendable.
    static func flatten(_ userInfo: [AnyHashable: Any]) -> [String: String] {
        var out: [String: String] = [:]
        for (key, value) in userInfo {
            guard let k = key as? String else { continue }
            switch value {
            case let s as String:    out[k] = s
            case let n as NSNumber:  out[k] = n.stringValue
            case let b as Bool:      out[k] = b ? "true" : "false"
            default:                 continue   // aps, dictionnaires imbriqués : ignorés
            }
        }
        return out
    }

    // Le backend mélange snake_case et camelCase : toujours lire les deux.
    static func value(_ data: [String: String], _ keys: String...) -> String? {
        for key in keys {
            if let s = data[key], !s.isEmpty { return s }
        }
        return nil
    }

    @MainActor
    static func apply(_ data: [String: String]) {
        let router = NotificationRouter.shared
        let type   = value(data, "type") ?? ""
        let conv   = value(data, "conversation_id", "conversationId").flatMap { Int($0) }
        let screen = value(data, "screen") ?? ""

        // Messagerie
        if messages.contains(type) || messagesEscalated.contains(type) || screen == "messages" {
            if let conv { router.pendingConversationId = conv }
            if messagesEscalated.contains(type) { router.pendingMessagesFilter = .aReprendre }
            router.pendingTab = .messages
            return
        }

        // Question hôte : feuille modale, pas d'onglet
        if type == "host_question" {
            Task { await HostQuestionManager.shared.fetchPending() }
            return
        }

        // Réservations → Calendrier à la date concernée
        if calendar.contains(type) {
            router.pendingCalendarDate = date(data, "check_in", "start_date", "checkIn", "startDate")
            router.calendarNeedsRefresh = true
            router.pendingTab = .calendar
            return
        }

        // Résumés et journée en cours → Aujourd'hui
        if today.contains(type) {
            router.calendarNeedsRefresh = true
            router.pendingTab = .today
            return
        }

        // Ménage → Gestion ▸ Ménage, et la checklist si l'id est fourni
        if cleaning.contains(type) {
            router.pendingChecklistId = value(data, "checklistId", "checklist_id", "cleaning_id", "cleaningId")
            router.pendingManageEntry = .cleaning
            router.pendingTab = .manage
            return
        }

        // Cautions et factures → Gestion ▸ Séjours
        if stays.contains(type) {
            router.pendingDepositId = value(data, "depositId", "deposit_id")
            router.pendingManageEntry = .stays
            router.pendingTab = .manage
            return
        }

        // Contrats → Gestion ▸ Propriétaires
        if contracts.contains(type) {
            router.pendingContractId = value(data, "contractId", "contract_id")
            router.pendingManageEntry = .owners
            router.pendingTab = .manage
            return
        }

        // Serrures connectées → Gestion ▸ Logements
        if properties.contains(type) {
            router.pendingManageEntry = .properties
            router.pendingTab = .manage
            return
        }

        if type == "support" {
            router.openSupport = true
            return
        }

        // Repli du routeur web : un conversation_id sans type connu, c'est un message.
        if let conv {
            router.pendingConversationId = conv
            router.pendingTab = .messages
            return
        }

        router.pendingTab = .today
    }

    private static func date(_ data: [String: String], _ keys: String...) -> Date? {
        guard let raw = keys.compactMap({ data[$0] }).first(where: { !$0.isEmpty }) else { return nil }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: raw) { return d }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "Europe/Paris")
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: String(raw.prefix(10)))
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        let title = content.title
        let body  = content.body
        // Valeurs Sendable extraites AVANT de traverser vers le MainActor.
        let data  = PushRoute.flatten(content.userInfo)
        let type  = PushRoute.value(data, "type") ?? "push"

        Task { @MainActor in
            await PushNotificationManager.shared.logToHistory(
                title: title, body: body, type: type, data: data
            )
        }
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let data = PushRoute.flatten(response.notification.request.content.userInfo)

        Task { @MainActor in
            PushRoute.apply(data)
            PushNotificationManager.shared.clearDeliveredNotifications()
        }
        completionHandler()
    }
}

// MARK: - Bodies

private struct SaveTokenBody: Encodable {
    let token: String
    let device_type: String
    let device_id: String?
}

private struct NotificationHistoryBody: Encodable {
    let title: String
    let body: String
    let type: String
    let data: [String: String]
}
