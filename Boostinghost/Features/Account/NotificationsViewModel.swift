import Foundation
import Observation

@Observable
@MainActor
final class NotificationsViewModel {

    enum ViewState { case loading, loaded, subAccountRestricted, failed }

    var viewState: ViewState = .loading
    var settings: NotificationSettings? = nil
    var saveError: String? = nil

    // Ordered display list — snake_case keys match POST body keys exactly.
    static let preferences: [(key: String, label: String)] = [
        ("notif_new_reservation",       "Nouvelle réservation"),
        ("notif_reservation_cancelled", "Réservation annulée"),
        ("notif_new_message",           "Nouveau message voyageur"),
        ("notif_daily_summary",         "Résumé quotidien (8 h)"),
        ("notif_reminder_j1",           "Rappel la veille (18 h)"),
        ("notif_cleaning_alert",        "Ménage non commencé, arrivée proche"),
        ("notif_checklist_done",        "Checklist ménage validée"),
        ("notif_new_invoice",           "Nouvelle facture"),
        ("notif_template_failed",       "Échec d'un message automatique"),
    ]

    // MARK: - Load

    func load() async {
        viewState = .loading
        do {
            settings = try await APIClient.shared.get(Endpoint.notificationSettings)
            viewState = .loaded
        } catch APIError.unauthorized {
            viewState = .subAccountRestricted
        } catch {
            viewState = .failed
        }
    }

    // MARK: - Read

    func value(for key: String) -> Bool {
        guard let s = settings else { return false }
        switch key {
        case "notif_new_reservation":       return s.notifNewReservation
        case "notif_reservation_cancelled": return s.notifReservationCancelled
        case "notif_new_message":           return s.notifNewMessage
        case "notif_daily_summary":         return s.notifDailySummary
        case "notif_reminder_j1":           return s.notifReminderJ1
        case "notif_cleaning_alert":        return s.notifCleaningAlert
        case "notif_checklist_done":        return s.notifChecklistDone
        case "notif_new_invoice":           return s.notifNewInvoice
        case "notif_template_failed":       return s.notifTemplateFailed
        default:                            return false
        }
    }

    // MARK: - Toggle (optimistic, merge POST)

    func toggle(key: String) async {
        guard settings != nil else { return }
        let previous = value(for: key)
        let newValue = !previous

        apply(key: key, value: newValue)

        do {
            try await APIClient.shared.postVoid(
                Endpoint.notificationSettings,
                body: [key: newValue]
            )
        } catch {
            apply(key: key, value: previous)
            saveError = apiMessage(error)
        }
    }

    // MARK: - Private

    private func apply(key: String, value: Bool) {
        guard var s = settings else { return }
        switch key {
        case "notif_new_reservation":       s.notifNewReservation = value
        case "notif_reservation_cancelled": s.notifReservationCancelled = value
        case "notif_new_message":           s.notifNewMessage = value
        case "notif_daily_summary":         s.notifDailySummary = value
        case "notif_reminder_j1":           s.notifReminderJ1 = value
        case "notif_cleaning_alert":        s.notifCleaningAlert = value
        case "notif_checklist_done":        s.notifChecklistDone = value
        case "notif_new_invoice":           s.notifNewInvoice = value
        case "notif_template_failed":       s.notifTemplateFailed = value
        default: break
        }
        settings = s
    }

    private func apiMessage(_ error: Error) -> String {
        if let e = error as? APIError {
            switch e {
            case .server(_, let msg?): return msg
            case .network:             return "Connexion impossible. Vérifiez votre réseau."
            default:                   break
            }
        }
        return "Une erreur est survenue. Réessayez."
    }
}
