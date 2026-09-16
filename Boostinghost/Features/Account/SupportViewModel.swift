import Foundation

@Observable
@MainActor
final class SupportViewModel {

    enum LoadState { case idle, loading, loaded, error(String) }

    // MARK: - State

    var loadState: LoadState = .idle
    var messages: [SupportMessage] = []
    private(set) var conversationId: String? = nil

    var draft: String = ""
    var isSending: Bool = false
    var sendError: String? = nil

    // MARK: - Load

    func load() async {
        if case .loaded = loadState {} else { loadState = .loading }
        do {
            let convResp: SupportConversationResponse = try await APIClient.shared.get(
                Endpoint.supportConversation
            )
            let cid = convResp.conversation.id
            conversationId = cid
            let msgsResp: SupportMessagesResponse = try await APIClient.shared.get(
                Endpoint.supportMessages(cid)
            )
            messages = msgsResp.messages
            loadState = .loaded
        } catch APIError.unauthorized {
            loadState = .error("Session expirée.")
        } catch let e as APIError {
            loadState = .error(e.userMessage)
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }

    // MARK: - Send text

    func sendText() async {
        guard let cid = conversationId else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        isSending = true
        defer { isSending = false }

        struct Body: Encodable { let conversationId: String; let message: String }
        let body = Body(conversationId: cid, message: text)

        #if DEBUG
        let bodyJSON = (try? String(data: JSONEncoder().encode(body), encoding: .utf8)) ?? "?"
        print("[DEBUG-SUPPORT] POST \(Endpoint.supportSendMessage.absoluteString)")
        print("[DEBUG-SUPPORT] body: \(bodyJSON)")
        #endif

        do {
            let msg: SupportMessage = try await APIClient.shared.post(
                Endpoint.supportSendMessage,
                body: body
            )
            messages.append(msg)
        } catch APIError.decoding {
            // Le POST a réussi (2xx) mais la réponse ne correspond pas au modèle.
            // L'action a abouti — ne jamais alerter. On recharge pour afficher le message.
            await reloadMessages()
        } catch let e as APIError {
            sendError = e.userMessage
            draft = text
        } catch {
            sendError = error.localizedDescription
            draft = text
        }
    }

    // MARK: - Upload image

    func uploadImage(_ data: Data, mimeType: String) async {
        guard let cid = conversationId else { return }
        isSending = true
        defer { isSending = false }
        do {
            let msg: SupportMessage = try await APIClient.shared.postMultipartUpload(
                Endpoint.supportUpload,
                imageData: data,
                mimeType: mimeType,
                fileName: "support.\(mimeType == "image/png" ? "png" : "jpg")",
                textFields: [("conversationId", cid)]
            )
            messages.append(msg)
        } catch APIError.decoding {
            await reloadMessages()
        } catch let e as APIError {
            sendError = e.userMessage
        } catch {
            sendError = error.localizedDescription
        }
    }

    // MARK: - Reload silencieux

    private func reloadMessages() async {
        guard let cid = conversationId else { return }
        do {
            let resp: SupportMessagesResponse = try await APIClient.shared.get(
                Endpoint.supportMessages(cid)
            )
            messages = resp.messages
        } catch {
            // silencieux — l'action principale a réussi
        }
    }
}
