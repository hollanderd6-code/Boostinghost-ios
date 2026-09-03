import Foundation
import Observation

@MainActor
@Observable
final class MessagesViewModel {

    enum Filter: Hashable { case tous, nonLus, aReprendre }
    enum State { case idle, loading, loaded, error(String) }

    private(set) var state: State = .idle
    private(set) var conversations: [Conversation] = []
    var filter: Filter = .tous
    var agencyAll = true

    // MARK: - Derived

    var filtered: [Conversation] {
        switch filter {
        case .tous:       return conversations
        case .nonLus:     return conversations.filter { ($0.unreadCount ?? 0) > 0 }
        case .aReprendre: return conversations.filter { $0.escalated == true }
        }
    }

    var unreadCount: Int {
        conversations.filter { ($0.unreadCount ?? 0) > 0 }.count
    }

    var escalatedCount: Int {
        conversations.filter { $0.escalated == true }.count
    }

    var superTitle: String {
        var parts: [String] = []
        if unreadCount > 0 {
            parts.append("\(unreadCount) non \(unreadCount == 1 ? "lu" : "lus")")
        }
        if escalatedCount > 0 {
            parts.append("\(escalatedCount) à reprendre")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Load

    func load() async {
        state = .loading
        do {
            let r: ConversationsResponse = try await APIClient.shared.get(
                Endpoint.conversations, agencyAll: agencyAll
            )
            // Tri décroissant sur last_message_time (ISO lexicographique)
            conversations = (r.conversations ?? []).sorted {
                ($0.lastMessageTime ?? "") > ($1.lastMessageTime ?? "")
            }
            state = .loaded
        } catch {
            state = .error("Impossible de charger les messages")
        }
    }
}
