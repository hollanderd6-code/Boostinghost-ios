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
    private(set) var hostQuestions: [HostQuestion] = []

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

        // Load host questions in parallel (non-blocking — failure is silent)
        async let questionsTask: () = loadHostQuestions()
        _ = await questionsTask

        if conversation.hasSuggestion == true && !suggestionFetched {
            suggestionFetched = true
            await fetchSuggestion()
        }
    }

    func loadHostQuestions() async {
        #if DEBUG
        let _ep = Endpoint.hostQuestionsForConversation(conversation.id)
        print("[HOSTQ-LIVE3] loadHostQuestions — convId=\(conversation.id) url=\(_ep.absoluteString) agencyAll=true")
        #endif
        do {
            let r: HostQuestionsResponse = try await APIClient.shared.get(
                Endpoint.hostQuestionsForConversation(conversation.id),
                agencyAll: true
            )
            hostQuestions = r.questions
            #if DEBUG
            print("[HOSTQ-LIVE3] GET OK — questions.count=\(r.questions.count)")
            for q in r.questions {
                let tid   = q.triggerMessageId.map { "\($0)" } ?? "nil"
                let mtype = q.meta?.type.map { "\($0)" } ?? "nil"
                print("[HOSTQ-LIVE3]   id=\(q.id) convId=\(q.conversationId) kind=\(q.kind ?? "nil") status=\(q.status ?? "nil") triggerMsgId=\(tid) createdAt=\(q.createdAt ?? "nil") meta.type=\(mtype) meta.reqLabel=\(q.meta?.reqLabel ?? "nil")")
            }
            let merged = mergedItems
            print("[HOSTQ-LIVE3] mergedItems — messages=\(messages.count) hostQ=\(hostQuestions.count) total=\(merged.count)")
            for item in merged {
                switch item {
                case .message(let m):      print("[HOSTQ-LIVE3]   .message(id=\(m.id) createdAt=\(m.createdAt ?? "nil"))")
                case .hostQuestion(let q): print("[HOSTQ-LIVE3]   .hostQuestion(id=\(q.id) status=\(q.status ?? "nil") createdAt=\(q.createdAt ?? "nil"))")
                }
            }
            #endif
        } catch {
            #if DEBUG
            print("[HOSTQ-LIVE3] GET ERROR — \(error)")
            switch error {
            case APIError.server(let code, let msg):
                print("[HOSTQ-LIVE3]   HTTP \(code) — \(msg ?? "(no message)")")
            case APIError.unauthorized:
                print("[HOSTQ-LIVE3]   401 Unauthorized")
            case APIError.decoding(let de):
                print("[HOSTQ-LIVE3]   Decoding: \(de)")
            case APIError.network(let ne):
                print("[HOSTQ-LIVE3]   Network: \(ne)")
            default:
                print("[HOSTQ-LIVE3]   Unknown: \(error)")
            }
            #endif
        }
    }

    // Interleave messages and host questions in chronological order.
    // A question with a triggerMessageId is placed immediately after that message;
    // otherwise it is inserted by createdAt.
    var mergedItems: [ConversationItem] {
        var result: [ConversationItem] = messages.map { .message($0) }
        for q in hostQuestions {
            if let tid = q.triggerMessageId,
               let idx = result.firstIndex(where: {
                   if case .message(let m) = $0 { return m.id == tid }
                   return false
               }) {
                result.insert(.hostQuestion(q), at: idx + 1)
            } else {
                let qDate = q.createdAt ?? ""
                let pos = result.firstIndex(where: { ($0.sortKey) > qDate }) ?? result.endIndex
                result.insert(.hostQuestion(q), at: pos)
            }
        }
        return result
    }

    // MARK: - Host question answer

    func answerHostQuestion(_ id: Int, answer: String, text: String?) async throws {
        let body = HostQuestionAnswerBody(answer: answer, text: text)
        let _: HostQuestionAnswerResponse = try await APIClient.shared.post(
            Endpoint.hostQuestionAnswer(id), body: body, agencyAll: true
        )
        // Refresh questions inline (409 = already answered → still refresh)
        await loadHostQuestions()
        // Trigger HostQuestionManager to refresh polling state
        await HostQuestionManager.shared.fetchPending()
        // Reload messages to pick up the bot reply
        await load()
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
            // Implicit take-over after escalation:
            //   • Temporary escalation (host question "self" path): escalated=true, aiDisabled=false
            //     → de-escalate only; the AI was not explicitly disabled, keep it enabled.
            //   • AI explicitly disabled by the owner AND escalated: re-enable the AI.
            if isEscalated {
                if !isAiDisabled {
                    isEscalated = false
                    Task {
                        try? await APIClient.shared.postVoid(
                            Endpoint.deescalate(conversation.id), body: EmptyBody()
                        )
                    }
                } else {
                    isEscalated  = false
                    isAiDisabled = false
                    Task {
                        try? await APIClient.shared.postVoid(
                            Endpoint.toggleAI(conversation.id), body: EmptyBody()
                        )
                    }
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
