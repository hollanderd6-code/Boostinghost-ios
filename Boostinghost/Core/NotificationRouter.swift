import Foundation

@Observable
@MainActor
final class NotificationRouter {
    static let shared = NotificationRouter()
    private init() {}

    var pendingTab: AppTab? = nil
    var openSupport: Bool = false
    // Ouvre directement une conversation après « Je réponds moi-même »
    var pendingConversationId: Int? = nil
}
