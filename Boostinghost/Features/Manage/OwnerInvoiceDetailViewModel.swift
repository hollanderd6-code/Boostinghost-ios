import Foundation
import Observation

@Observable
@MainActor
final class OwnerInvoiceDetailViewModel {

    enum LoadState { case loading, loaded, error(String) }
    enum ActionState: Equatable {
        case idle
        case running
        case error(String)
    }

    let invoiceId: String
    var loadState: LoadState = .loading
    var detail: OwnerInvoiceDetailResponse?
    var actionState: ActionState = .idle

    init(invoiceId: String) {
        self.invoiceId = invoiceId
    }

    // MARK: - Chargement

    func load() async {
        loadState = .loading
        do {
            let resp: OwnerInvoiceDetailResponse = try await APIClient.shared.get(
                Endpoint.ownerInvoice(invoiceId),
                agencyAll: true
            )
            detail = resp
            loadState = .loaded
        } catch {
            loadState = .error("Impossible de charger la facture.")
        }
    }

    // MARK: - Actions

    func finalize() async -> Bool {
        actionState = .running
        do {
            let resp: InvoiceActionResponse = try await APIClient.shared.post(
                Endpoint.ownerInvoiceFinalize(invoiceId),
                body: EmptyBody(),
                agencyAll: true
            )
            if let d = detail {
                detail = OwnerInvoiceDetailResponse(invoice: resp.invoice, items: d.items, properties: d.properties)
            }
            actionState = .idle
            return true
        } catch {
            actionState = .error((error as? APIError)?.userMessage ?? "Erreur lors de la validation.")
            return false
        }
    }

    func send() async -> Bool {
        actionState = .running
        do {
            let _: SendActionResponse = try await APIClient.shared.post(
                Endpoint.ownerInvoiceSend(invoiceId),
                body: EmptyBody(),
                agencyAll: true
            )
            await silentReload()
            actionState = .idle
            return true
        } catch {
            actionState = .error((error as? APIError)?.userMessage ?? "Erreur lors de l'envoi.")
            return false
        }
    }

    func markPaid() async -> Bool {
        actionState = .running
        do {
            let resp: InvoiceActionResponse = try await APIClient.shared.post(
                Endpoint.ownerInvoiceMarkPaid(invoiceId),
                body: EmptyBody(),
                agencyAll: true
            )
            if let d = detail {
                detail = OwnerInvoiceDetailResponse(invoice: resp.invoice, items: d.items, properties: d.properties)
            }
            actionState = .idle
            return true
        } catch {
            actionState = .error((error as? APIError)?.userMessage ?? "Erreur lors du marquage.")
            return false
        }
    }

    func delete() async -> Bool {
        actionState = .running
        do {
            try await APIClient.shared.delete(Endpoint.ownerInvoice(invoiceId), agencyAll: true)
            actionState = .idle
            return true
        } catch {
            actionState = .error((error as? APIError)?.userMessage ?? "Erreur lors de la suppression.")
            return false
        }
    }

    // MARK: - Rechargement silencieux (ne bascule pas loadState sur .loading)

    private func silentReload() async {
        do {
            let resp: OwnerInvoiceDetailResponse = try await APIClient.shared.get(
                Endpoint.ownerInvoice(invoiceId),
                agencyAll: true
            )
            detail = resp
            loadState = .loaded
        } catch {}
    }
}

// MARK: - Types de réponse privés

private struct InvoiceActionResponse: Decodable {
    let invoice: OwnerInvoiceDetail
}

private struct SendActionResponse: Decodable {
    let success: Bool?
    let message: String?
}
