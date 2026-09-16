import Foundation

@MainActor
@Observable
final class HostQuestionManager {

    static let shared = HostQuestionManager()
    private init() {}

    private(set) var pendingQuestion: HostQuestion?
    // Message renvoyé par le serveur après Oui/Non — observé par MainTabView
    private(set) var lastConfirmation: String?

    private var pollingTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func startPolling() {
        stopPolling()
        pollingTask = Task {
            while !Task.isCancelled {
                await fetchPending()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Fetch

    func fetchPending() async {
        guard await APIClient.shared.token != nil else { return }
        do {
            let r: HostQuestionsResponse = try await APIClient.shared.get(Endpoint.hostQuestionsPending)
            pendingQuestion = r.questions.first
        } catch {
            // Polling silencieux — on ne déconnecte pas sur erreur réseau
        }
    }

    // MARK: - Answer

    // Envoie la réponse de l'hôte.
    // answer: "yes" | "no" | "self"
    // text: précision optionnelle (utilisée avec "no")
    func answer(_ id: Int, answer: String, text: String? = nil) async throws {
        let body = HostQuestionAnswerBody(answer: answer, text: text?.isEmpty == false ? text : nil)
        let r: HostQuestionAnswerResponse = try await APIClient.shared.post(
            Endpoint.hostQuestionAnswer(id), body: body
        )
        if pendingQuestion?.id == id { pendingQuestion = nil }
        if answer != "self", let msg = r.message, !msg.isEmpty {
            lastConfirmation = msg
        }
        // Charger immédiatement la question suivante éventuelle
        await fetchPending()
    }

    func clearConfirmation() {
        lastConfirmation = nil
    }
}

// MARK: - Encodable body

private struct HostQuestionAnswerBody: Encodable {
    let answer: String
    let text: String?
}
