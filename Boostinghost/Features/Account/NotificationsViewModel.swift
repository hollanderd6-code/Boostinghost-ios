import Foundation
import Observation

// Préférences de notifications — alignées sur la liste blanche réelle du
// serveur (`BOOL_KEYS`, server.js:12571) et sur DEFAULT_NOTIFICATION_SETTINGS
// (server.js:3503). Toute clé absente de cette liste blanche est ignorée
// silencieusement par POST /api/settings/notifications : ne rien inventer ici.
//
// Les valeurs sont décodées en dictionnaire tolérant plutôt qu'en struct à
// champs fixes : une clé ajoutée côté serveur n'exige plus de toucher au
// décodeur, et le piège CodingKeys/convertFromSnakeCase du CLAUDE.md disparaît.

@Observable
@MainActor
final class NotificationsViewModel {

    enum ViewState { case loading, loaded, subAccountRestricted, failed }

    struct Toggle: Identifiable {
        let key: String
        let label: String
        let note: String?
        var id: String { key }
    }

    struct Section: Identifiable {
        let id: String
        let title: String
        let items: [Toggle]
    }

    // Niveau de notification des messages voyageurs (`notif_message_level`).
    enum MessageLevel: String, CaseIterable, Identifiable {
        case all         = "all"
        case aiOff       = "ai_off"
        case escalation  = "escalation"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all:        return "Chaque message"
            case .aiOff:      return "IA silencieuse"
            case .escalation: return "Escalades"
            }
        }

        var explanation: String {
            switch self {
            case .all:        return "Une notification pour chaque message reçu, même quand l'assistant a répondu."
            case .aiOff:      return "Seulement quand l'assistant ne répond pas — le réglage par défaut."
            case .escalation: return "Uniquement quand l'assistant passe la main."
            }
        }
    }

    var viewState: ViewState = .loading
    var values: [String: Bool] = [:]
    var messageLevel: MessageLevel = .aiOff
    var saveError: String? = nil

    static let sections: [Section] = [
        Section(id: "reservations", title: "Réservations", items: [
            Toggle(key: "notif_new_reservation",       label: "Nouvelle réservation",    note: nil),
            Toggle(key: "notif_reservation_cancelled", label: "Réservation annulée",     note: nil),
            Toggle(key: "notif_daily_summary",         label: "Résumé quotidien (8 h)",  note: nil),
            Toggle(key: "notif_reminder_j1",           label: "Rappel la veille (18 h)", note: nil)
        ]),
        Section(id: "messages", title: "Messagerie", items: [
            Toggle(key: "notif_new_message",     label: "Message voyageur", note: nil),
            Toggle(key: "notif_template_failed", label: "Échec d'un message automatique", note: nil)
        ]),
        Section(id: "cleaning", title: "Ménage", items: [
            Toggle(key: "notif_cleaning_reminder",  label: "Rappel de ménage",  note: "La veille d'un départ."),
            Toggle(key: "notif_cleaning_alert",     label: "Ménage non commencé, arrivée proche", note: nil),
            Toggle(key: "notif_cleaning_completed", label: "Ménage terminé",    note: nil),
            Toggle(key: "notif_checklist_done",     label: "Checklist validée", note: nil)
        ]),
        Section(id: "money", title: "Argent", items: [
            Toggle(key: "notif_new_invoice",     label: "Nouvelle facture",    note: nil),
            Toggle(key: "notif_deposit_request", label: "Demande de caution",  note: nil)
        ])
    ]

    // MARK: - Load

    func load() async {
        viewState = .loading
        do {
            let prefs: NotificationPrefs = try await APIClient.shared.get(Endpoint.notificationSettings)
            values = prefs.values
            messageLevel = MessageLevel(rawValue: prefs.messageLevel ?? "") ?? .aiOff
            viewState = .loaded
        } catch APIError.unauthorized {
            viewState = .subAccountRestricted
        } catch {
            viewState = .failed
        }
    }

    // MARK: - Read
    //
    // Une préférence absente de la réponse vaut `true` : c'est la valeur par
    // défaut de DEFAULT_NOTIFICATION_SETTINGS côté serveur.

    func value(for key: String) -> Bool {
        values[key] ?? true
    }

    // MARK: - Write (optimiste, POST partiel)

    func toggle(key: String) async {
        let previous = value(for: key)
        values[key] = !previous
        do {
            try await APIClient.shared.postVoid(Endpoint.notificationSettings, body: [key: !previous])
        } catch {
            values[key] = previous
            saveError = apiMessage(error)
        }
    }

    func setMessageLevel(_ level: MessageLevel) async {
        let previous = messageLevel
        guard level != previous else { return }
        messageLevel = level
        do {
            try await APIClient.shared.postVoid(
                Endpoint.notificationSettings,
                body: ["notif_message_level": level.rawValue]
            )
        } catch {
            messageLevel = previous
            saveError = apiMessage(error)
        }
    }

    // MARK: - Private

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

// MARK: - Décodage tolérant
//
// Le serveur renvoie des booléens, parfois 0/1 ou "true" selon l'historique de
// la ligne JSON. On accepte les trois, on ignore le reste (chaînes libres comme
// whatsappNumber), et `notif_message_level` est extrait à part.

struct NotificationPrefs: Decodable {
    let values: [String: Bool]
    let messageLevel: String?

    private struct AnyKey: CodingKey {
        let stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        var out: [String: Bool] = [:]
        var level: String? = nil

        for key in c.allKeys {
            let name = Self.snakeCased(key.stringValue)

            if name == "notif_message_level" {
                level = try? c.decode(String.self, forKey: key)
                continue
            }

            let decoded: Bool?
            if let b = try? c.decode(Bool.self, forKey: key) {
                decoded = b
            } else if let i = try? c.decode(Int.self, forKey: key) {
                decoded = i != 0
            } else if let s = try? c.decode(String.self, forKey: key) {
                decoded = (s == "true" || s == "1")
            } else {
                decoded = nil
            }
            guard let v = decoded else { continue }

            // L'APIClient applique convertFromSnakeCase, y compris aux clés de
            // dictionnaire : `notif_new_message` arrive en `notifNewMessage`.
            // On stocke les deux formes pour que la recherche par nom de
            // colonne fonctionne dans les deux cas.
            out[key.stringValue] = v
            out[name] = v
        }

        values = out
        messageLevel = level
    }

    static func snakeCased(_ s: String) -> String {
        var out = ""
        for ch in s {
            if ch.isUppercase {
                out.append("_")
                out.append(Character(ch.lowercased()))
            } else {
                out.append(ch)
            }
        }
        return out
    }
}
