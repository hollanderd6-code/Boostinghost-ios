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

    // AI state — mutable so takeOver() and load() can update independently of the
    // immutable `conversation` struct. The server can auto-de-escalate while the
    // view is open (integrated-chat-handler); load() refreshes from the response.
    private(set) var isEscalated: Bool
    private(set) var isAiDisabled: Bool

    // Suggestion
    private(set) var suggestionText: String? = nil
    private(set) var suggestionActive: Bool = false
    private var suggestionFetched: Bool = false

    // Compose
    var draftText: String = ""
    private(set) var isSending: Bool = false
    var sendError: String? = nil

    // Note — pre-populated from conversation.notes once the backend fix is live
    private(set) var currentNote: String?

    init(conversation: Conversation, ownerName: String) {
        self.conversation = conversation
        self.ownerName = ownerName
        self.isEscalated  = conversation.escalated  ?? false
        self.isAiDisabled = conversation.aiDisabled ?? false
        self.currentNote  = conversation.notes.flatMap { $0.isEmpty ? nil : $0 }
    }

    // MARK: - Load

    func load() async {
        let wasLoaded = (loadState == .loaded)
        if !wasLoaded { loadState = .loading }

        do {
            let r: MessagesDetailResponse = try await APIClient.shared.get(
                Endpoint.messages(conversation.id)
            )
            messages = (r.messages ?? []).sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
            // Refresh AI state from server (auto-de-escalation possible server-side)
            if let conv = r.conversation {
                if let v = conv.escalated  { isEscalated  = v }
                if let v = conv.aiDisabled { isAiDisabled = v }
            }
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

    // MARK: - Reprendre la main

    func takeOver() async {
        guard let r: ToggleAIResponse = try? await APIClient.shared.post(
            Endpoint.toggleAI(conversation.id)
        ) else { return }
        let newAiDisabled = r.aiDisabled ?? false
        isAiDisabled = newAiDisabled
        if !newAiDisabled { isEscalated = false }
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
            // Implicit take-over: re-enable AI when human replies while escalated+paused.
            // Uses mutable vars — safe even when takeOver() was already called this session.
            if isEscalated && isAiDisabled {
                isEscalated  = false
                isAiDisabled = false
                Task {
                    try? await APIClient.shared.postVoid(
                        Endpoint.toggleAI(conversation.id), body: EmptyBody()
                    )
                }
            }
            await load()
        } catch {
            sendError = "Envoi échoué. Vérifiez votre connexion et réessayez."
            if wasSuggestionActive { suggestionActive = true }
        }

        isSending = false
    }

    // MARK: - Template

    func sendTemplate(id: Int) async throws {
        let _: TemplateSendResponse = try await APIClient.shared.post(
            Endpoint.messageTemplateSend(id),
            body: TemplateSendBody(conversationId: conversation.id)
        )
        await load()
    }

    // MARK: - Note

    // Backend accepts reservation_uid or channex_booking_id — prefer channex when present
    var noteUid: String? { conversation.channexBookingId ?? conversation.reservationUid }

    func saveNote(_ text: String) async throws {
        guard let uid = noteUid else { return }
        let r: NoteResponse = try await APIClient.shared.patch(
            Endpoint.reservationNote(uid),
            body: NoteBody(notes: text)
        )
        currentNote = r.notes.flatMap { $0.isEmpty ? nil : $0 }
    }

    // MARK: - Caution (deposit link)

    private(set) var isDepositLoading = false
    private(set) var depositLink: String? = nil
    private(set) var depositAmountCents: Int? = nil
    private(set) var depositUnavailable = false

    // Airbnb filter mirrors the web front-end: normalise platform (lowercase, strip _-space)
    // and hide the button if the result contains "airbnb" or equals "abb".
    var isAirbnb: Bool {
        guard let p = conversation.platform else { return false }
        let norm = p.lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        return norm.contains("airbnb") || norm == "abb"
    }

    // IMPORTANT: do NOT call at view open — quick-context is a side-effecting GET
    // that may create a Stripe session if no deposit exists yet.
    func fetchDepositLink() async {
        guard !isDepositLoading else { return }
        isDepositLoading = true
        defer { isDepositLoading = false }

        do {
            let ctx: QuickContextResponse = try await APIClient.shared.get(
                Endpoint.quickContext(conversation.id)
            )
            guard let rawUrl = ctx.depositUrl, !rawUrl.isEmpty else {
                depositUnavailable = true
                return
            }
            let r: ShortLinkResponse? = try? await APIClient.shared.post(
                Endpoint.shortLink,
                body: ShortLinkBody(url: rawUrl)
            )
            let shortUrl = r?.shortUrl.flatMap { $0.isEmpty ? nil : $0 } ?? rawUrl
            depositLink = shortUrl
            depositAmountCents = ctx.depositAmountCents
        } catch {
            sendError = "Impossible de récupérer le lien de caution."
        }
    }

    func confirmPasteDepositLink() {
        guard let url = depositLink else { return }
        draftText = url
        depositLink = nil
        depositAmountCents = nil
    }

    func clearDepositLink() {
        depositLink = nil
        depositAmountCents = nil
    }

    func clearDepositUnavailable() {
        depositUnavailable = false
    }

    // MARK: - AI pause countdown

    // Returns the date the AI will silently resume (sent + 2 h) when the host sent
    // a manual message while AI is enabled. nil if AI is explicitly disabled or no
    // manual message exists in the loaded window.
    var aiResumeDate: Date? {
        guard !isAiDisabled else { return nil }
        guard let last = messages.last(where: { $0.senderType == "owner" }),
              let raw = last.createdAt,
              let sent = parseMessageDate(raw) else { return nil }
        return sent.addingTimeInterval(7200)
    }

    private func parseMessageDate(_ raw: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: raw) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: raw)
    }

    // MARK: - Retry failed delivery

    func retryMessage(_ message: Message) {
        draftText = message.message
    }
}
