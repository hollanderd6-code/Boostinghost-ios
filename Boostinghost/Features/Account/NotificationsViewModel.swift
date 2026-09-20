import Foundation
import Observation

// Préférences de notifications.
//
// Deux changements par rapport à la version précédente :
//
// 1. Les valeurs sont décodées en dictionnaire tolérant (`[String: Bool]`) au
//    lieu d'une struct à champs fixes. La réponse de
//    GET /api/settings/notifications est un objet plat dont les clés sont les
//    colonnes `notif_*` ; avec un dictionnaire, ajouter une préférence ne
//    demande plus qu'une ligne dans `sections` — et une clé inconnue du serveur
//    ne casse plus le décodage (c'était le piège CodingKeys/snake_case du
//    CLAUDE.md).
// 2. La liste est groupée en sections, et n'expose que des types réellement
//    envoyés par le backend.
//
// Volontairement ABSENTS : `new_cleaning` et `cleaning_reminder` partent au
// prestataire, et cet écran renvoie 401 pour un sous-compte — un interrupteur
// que la personne concernée ne peut pas voir n'a pas sa place ici.

@Observable
@MainActor
final class NotificationsViewModel {

    enum ViewState { case loading, loaded, subAccountRestricted, failed }

    struct Section: Identifiable {
        let id: String
        let title: String
        let items: [(key: String, label: String, note: String?)]
    }

    var viewState: ViewState = .loading
    var values: [String: Bool] = [:]
    var saveError: String? = nil

    // Ordre d'affichage. Les clés sont les noms de colonnes exacts attendus par
    // POST /api/settings/notifications.
    static let sections: [Section] = [
        Section(id: "reservations", title: "Réservations", items: [
            ("notif_new_reservation",       "Nouvelle réservation",     nil),
            ("notif_reservation_cancelled", "Réservation annulée",      nil),
            ("notif_daily_summary",         "Résumé quotidien (8 h)",   nil),
            ("notif_reminder_j1",           "Rappel la veille (18 h)",  nil)
        ]),
        Section(id: "messages", title: "Messagerie", items: [
            ("notif_new_message",    "Nouveau message voyageur", nil),
            ("notif_escalation",     "Conversation à reprendre", "L'assistant passe la main : ton de la conversation, demande hors périmètre."),
            ("notif_host_question",  "Question à arbitrer",      "L'assistant demande ton accord avant de répondre."),
            ("notif_template_failed", "Échec d'un message automatique", nil)
        ]),
        Section(id: "cleaning", title: "Ménage", items: [
            ("notif_cleaning_alert",  "Ménage non commencé, arrivée proche", nil),
            ("notif_checklist_done",  "Checklist ménage validée",            nil)
        ]),
        Section(id: "money", title: "Argent", items: [
            ("notif_new_invoice",       "Nouvelle facture",                  nil),
            ("notif_upsell_paid",       "Prestation payée par un voyageur",  nil),
            ("notif_deposit_expiry",    "Caution proche de l'expiration",    "48 h avant la fin de l'empreinte bancaire."),
            ("notif_deposit_released",  "Caution libérée automatiquement",   nil)
        ])
    ]

    // MARK: - Load

    func load() async {
        viewState = .loading
        do {
            let prefs: NotificationPrefs = try await APIClient.shared.get(Endpoint.notificationSettings)
            values = prefs.values
            viewState = .loaded
        } catch APIError.unauthorized {
            viewState = .subAccountRestricted
        } catch {
            viewState = .failed
        }
    }

    // MARK: - Read
    //
    // Une préférence absente de la réponse est considérée activée : c'est le
    // comportement du serveur, qui n'envoie la colonne que si elle existe.

    func value(for key: String) -> Bool {
        values[key] ?? true
    }

    // MARK: - Toggle (optimiste, POST partiel)

    func toggle(key: String) async {
        let previous = value(for: key)
        let newValue = !previous
        values[key] = newValue

        do {
            try await APIClient.shared.postVoid(
                Endpoint.notificationSettings,
                body: [key: newValue]
            )
        } catch {
            values[key] = previous
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
// Le backend renvoie tantôt des booléens, tantôt 0/1, tantôt "true" : on
// accepte les trois et on ignore tout le reste (dates, objets imbriqués).

struct NotificationPrefs: Decodable {
    let values: [String: Bool]

    private struct AnyKey: CodingKey {
        let stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        var out: [String: Bool] = [:]
        for key in c.allKeys {
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
            // L'APIClient applique `convertFromSnakeCase`, y compris aux clés de
            // dictionnaire (piège documenté dans CLAUDE.md) : `notif_new_message`
            // arrive donc en `notifNewMessage`. On stocke les deux formes pour
            // que la recherche par nom de colonne fonctionne dans les deux cas.
            out[key.stringValue] = v
            out[Self.snakeCased(key.stringValue)] = v
        }
        values = out
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
