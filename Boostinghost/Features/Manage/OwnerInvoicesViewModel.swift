import Foundation
import Observation

@Observable
@MainActor
final class OwnerInvoicesViewModel {

    enum LoadState { case loading, loaded, error(String) }

    var loadState: LoadState = .loading
    var invoices: [OwnerInvoice] = []
    var actionError: String? = nil

    var filter: OwnerInvoiceFilter = .all {
        didSet { guard filter != oldValue else { return } }
    }

    var filteredInvoices: [OwnerInvoice] {
        let base: [OwnerInvoice]
        if filter == .all {
            base = invoices
        } else {
            base = invoices.filter { $0.status == filter.rawValue }
        }
        return base.sorted { lhs, rhs in
            let l = lhs.issueDate ?? ""
            let r = rhs.issueDate ?? ""
            return l > r
        }
    }

    var superTitle: String {
        guard case .loaded = loadState else { return " " }
        let n = filteredInvoices.count
        return n == 1 ? "1 facture" : "\(n) factures"
    }

    func count(for f: OwnerInvoiceFilter) -> Int {
        if f == .all { return invoices.count }
        return invoices.filter { $0.status == f.rawValue }.count
    }

    func reload() async {
        if case .loaded = loadState {} else { loadState = .loading }
        do {
            let resp: OwnerInvoicesResponse = try await APIClient.shared.get(
                Endpoint.ownerInvoices,
                agencyAll: true
            )
            invoices = resp.invoices ?? []
            loadState = .loaded
        } catch {
            loadState = .error("Impossible de charger les factures.")
        }
    }

    // MARK: - Actions de la liste (contextMenu)

    func finalize(invoiceId: String) async {
        do {
            let _: AnyInvoiceResponse = try await APIClient.shared.post(
                Endpoint.ownerInvoiceFinalize(invoiceId),
                body: EmptyBody(),
                agencyAll: true
            )
            await silentReload()
        } catch {
            actionError = (error as? APIError)?.userMessage ?? "Erreur lors de la validation."
        }
    }

    func send(invoiceId: String) async {
        do {
            let _: AnyInvoiceResponse = try await APIClient.shared.post(
                Endpoint.ownerInvoiceSend(invoiceId),
                body: EmptyBody(),
                agencyAll: true
            )
            await silentReload()
        } catch {
            actionError = (error as? APIError)?.userMessage ?? "Erreur lors de l'envoi."
        }
    }

    func markPaid(invoiceId: String) async {
        do {
            let _: AnyInvoiceResponse = try await APIClient.shared.post(
                Endpoint.ownerInvoiceMarkPaid(invoiceId),
                body: EmptyBody(),
                agencyAll: true
            )
            await silentReload()
        } catch {
            actionError = (error as? APIError)?.userMessage ?? "Erreur lors du marquage."
        }
    }

    func delete(invoiceId: String) async {
        do {
            try await APIClient.shared.delete(Endpoint.ownerInvoice(invoiceId), agencyAll: true)
            await silentReload()
        } catch {
            actionError = (error as? APIError)?.userMessage ?? "Erreur lors de la suppression."
        }
    }

    private func silentReload() async {
        do {
            let resp: OwnerInvoicesResponse = try await APIClient.shared.get(
                Endpoint.ownerInvoices,
                agencyAll: true
            )
            invoices = resp.invoices ?? []
            loadState = .loaded
        } catch {}
    }
}

private struct AnyInvoiceResponse: Decodable {}
