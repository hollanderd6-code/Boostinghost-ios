import Foundation
import Observation

@MainActor
@Observable
final class ConversationDetailViewModel {

    enum LoadState: Equatable {
        case idle, loading, loaded, error(String)
    }

    let conversation: Conversation
    let ownerName: String

    private(set) var loadState: LoadState = .idle
    private(set) var messages: [Message] = []

    // Suggestion
    private(set) var suggestionText: String? = nil
    private(set) var suggestionActive: Bool = false
    private var suggestionFetched: Bool = false

    // Compose
    var draftText: String = ""
    private(set) var isSending: Bool = false
    var sendError: String? = nil

    init(conversation: Conversation, ownerName: String) {
        self.conversation = conversation
        self.ownerName = ownerName
    }

    // MARK: - Load

    func load() async {
        let wasLoaded = (loadState == .loaded)
        if !wasLoaded { loadState = .loading }

        // mark-read: fire and forget
        Task {
            try? await APIClient.shared.postVoid(
                Endpoint.markRead(conversation.id), body: EmptyBody()
            )
        }

        do {
            let r: MessagesDetailResponse = try await APIClient.shared.get(
                Endpoint.messages(conversation.id)
            )
            messages = (r.messages ?? []).sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
            loadState = .loaded
        } catch {
            if !wasLoaded { loadState = .error("Impossible de charger la conversation") }
            return
        }

        if conversation.hasSuggestion == true && !suggestionFetched {
            suggestionFetched = true
            await fetchSuggestion()
        }
    }

    // MARK: - Suggestion

    func fetchSuggestion() async {
        guard let r: SuggestionResponse = try? await APIClient.shared.get(
            Endpoint.suggestion(conversation.id)
        ) else { return }
        guard let text = r.suggestion, !text.isEmpty else { return }
        suggestionText = text
        suggestionActive = true
        draftText = text
    }

    func dismissSuggestion() {
        suggestionActive = false
        draftText = ""
        suggestionText = nil
        Task {
            try? await APIClient.shared.postVoid(
                Endpoint.suggestionStatus(conversation.id),
                body: SuggestionStatusBody(status: "dismissed")
            )
        }
    }

    func regenerateSuggestion() async {
        guard let r: SuggestionResponse = try? await APIClient.shared.post(
            Endpoint.suggestionRegen(conversation.id), body: EmptyBody()
        ) else {
            sendError = "Impossible de générer un brouillon."
            return
        }
        guard let text = r.suggestion, !text.isEmpty else {
            sendError = "Aucun brouillon disponible pour cette conversation."
            return
        }
        suggestionText = text
        suggestionActive = true
        draftText = text
    }

    // MARK: - Send

    func send() async {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        isSending = true
        sendError = nil
        let wasSuggestionActive = suggestionActive

        if wasSuggestionActive {
            suggestionActive = false
            Task {
                try? await APIClient.shared.postVoid(
                    Endpoint.suggestionStatus(conversation.id),
                    body: SuggestionStatusBody(status: "used")
                )
            }
        }

        do {
            if let channexId = conversation.channexBookingId, !channexId.isEmpty {
                let _: GenericSuccess = try await APIClient.shared.post(
                    Endpoint.sendPlatform(conversation.id),
                    body: SendPlatformBody(message: text)
                )
            } else {
                let _: GenericSuccess = try await APIClient.shared.post(
                    Endpoint.send,
                    body: SendDirectBody(
                        conversationId: conversation.id,
                        message: text,
                        senderType: "owner",
                        senderName: ownerName
                    )
                )
            }
            draftText = ""
            suggestionText = nil
            // Refresh messages (no loading spinner since wasLoaded)
            await load()
        } catch {
            sendError = "Envoi échoué. Vérifiez votre connexion et réessayez."
            if wasSuggestionActive { suggestionActive = true }
        }

        isSending = false
    }
}
