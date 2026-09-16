import Foundation
import Observation

@Observable
@MainActor
final class InvoicesViewModel {

    enum LoadState { case idle, loading, loaded, error(String) }

    // MARK: - State

    var loadState: LoadState = .idle
    var resendError: String? = nil
    var isResending: Bool    = false
    var isSendingToConversation: Bool    = false
    var sendToConversationError: String? = nil
    var lastSentInvoiceNumber: String?   = nil

    private(set) var all: [Invoice] = []

    // MARK: - Computed

    var invoiceCount: Int { all.count }

    var historyTotal: Double {
        all.compactMap(\.total).reduce(0, +)
    }

    // MARK: - Load

    func load() async {
        if case .loaded = loadState {} else { loadState = .loading }
        do {
            let resp: InvoiceHistoryResponse = try await APIClient.shared.get(
                Endpoint.invoiceHistory,
                agencyAll: true
            )
            all = resp.invoices
            loadState = .loaded
        } catch APIError.unauthorized {
            loadState = .error("Session expirée.")
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }

    // MARK: - Resend by email

    func resend(_ invoice: Invoice) async {
        guard let number = invoice.invoiceNumber else { return }
        isResending = true
        resendError = nil
        defer { isResending = false }
        do {
            struct Body: Encodable { let invoiceNumber: String }
            try await APIClient.shared.postVoid(
                Endpoint.resendInvoice,
                body: Body(invoiceNumber: number)
            )
        } catch {
            resendError = error.localizedDescription
        }
    }

    // MARK: - Send to conversation

    func sendToConversation(_ invoice: Invoice) async {
        isSendingToConversation = true
        sendToConversationError = nil
        defer { isSendingToConversation = false }

        struct ByConversation: Encodable { let conversationId: Int }
        struct ByReservation: Encodable { let reservationUid: String }
        struct SendResponse: Decodable { let invoiceNumber: String? }

        do {
            let resp: SendResponse
            if let cid = invoice.conversationId {
                resp = try await APIClient.shared.post(
                    Endpoint.sendInvoiceToConversation,
                    body: ByConversation(conversationId: cid),
                    agencyAll: true
                )
            } else if let uid = invoice.reservationUid {
                resp = try await APIClient.shared.post(
                    Endpoint.sendInvoiceToConversation,
                    body: ByReservation(reservationUid: uid),
                    agencyAll: true
                )
            } else {
                return
            }
            lastSentInvoiceNumber = resp.invoiceNumber ?? invoice.invoiceNumber
        } catch {
            sendToConversationError = error.localizedDescription
        }
    }
}
