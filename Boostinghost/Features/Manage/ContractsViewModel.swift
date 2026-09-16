import Foundation
import Observation

@Observable
@MainActor
final class ContractsViewModel {

    enum LoadState { case loading, loaded, error(String) }

    var loadState: LoadState = .loading
    var contracts: [Contract] = []
    var total: Int = 0
    var isLoadingMore = false
    var filter: ContractFilter = .sent {
        didSet {
            guard filter != oldValue else { return }
            Task { await reload() }
        }
    }

    private let pageSize = 50

    var hasMore: Bool { contracts.count < total }

    var superTitle: String {
        guard case .loaded = loadState else { return " " }
        return total == 1 ? "1 contrat" : "\(total) contrats"
    }

    // MARK: - Load

    func reload() async {
        if case .loaded = loadState {} else { loadState = .loading }
        total = 0
        await fetch(offset: 0)
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        await fetch(offset: contracts.count)
        isLoadingMore = false
    }

    private func fetch(offset: Int) async {
        do {
            let resp: ContractsListResponse = try await APIClient.shared.get(
                Endpoint.contrats,
                agencyAll: true,
                extraQueryItems: [
                    URLQueryItem(name: "status", value: filter.rawValue),
                    URLQueryItem(name: "limit",  value: "\(pageSize)"),
                    URLQueryItem(name: "offset", value: "\(offset)"),
                ]
            )
            if offset == 0 {
                contracts = resp.contracts
            } else {
                contracts.append(contentsOf: resp.contracts)
            }
            total = resp.total
            loadState = .loaded
        } catch {
            if offset == 0 {
                loadState = .error("Impossible de charger les contrats.")
            }
        }
    }

    // MARK: - Resend (POST /api/contrats/:id/resend-sign)

    func resend(_ contract: Contract) async throws {
        struct ResendResponse: Decodable { let success: Bool? }
        let _: ResendResponse = try await APIClient.shared.post(
            Endpoint.contratResend(contract.id),
            body: EmptyBody()
        )
    }

    // MARK: - PDF (GET /api/contrats/:id/pdf)

    func downloadPdf(_ contract: Contract) async -> URL? {
        do {
            let data = try await APIClient.shared.getData(Endpoint.contratPdf(contract.id))
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("contrat-\(contract.id).pdf")
            try data.write(to: tmp)
            return tmp
        } catch {
            return nil
        }
    }

    // MARK: - Delete (DELETE /api/contrats/:id)

    func delete(_ contract: Contract) async throws {
        try await APIClient.shared.delete(Endpoint.contrat(contract.id), agencyAll: true)
        removeLocally(id: contract.id)
    }

    func removeLocally(id: String) {
        guard contracts.contains(where: { $0.id == id }) else { return }
        contracts.removeAll { $0.id == id }
        total = max(0, total - 1)
    }
}
