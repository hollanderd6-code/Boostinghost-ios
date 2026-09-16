import Foundation
import Observation

@Observable
@MainActor
final class DebourViewModel {

    enum LoadState {
        case loading
        case loaded
        case featureBlocked
        case permissionDenied
        case error(String)
    }

    var loadState: LoadState = .loading
    var debours: [Debour] = []
    var clients: [OwnerClient] = []
    var filter: DebourFilter = .pending {
        didSet { guard filter != oldValue else { return } }
    }
    var actionDebourId: String? = nil
    var actionError: String? = nil

    // MARK: - Derived

    var filteredDebours: [Debour] {
        switch filter {
        case .all:     return debours
        case .pending: return debours.filter { $0.status == "pending" }
        case .billed:  return debours.filter { $0.status == "billed" }
        }
    }

    var pendingTotal: Double {
        debours.filter { $0.status == "pending" }.reduce(0) { $0 + $1.montant }
    }

    var superTitle: String {
        guard case .loaded = loadState else { return " " }
        let n = debours.count
        let nPart = n == 1 ? "1 débours" : "\(n) débours"
        return "\(nPart) · \(DebourAmountFmt.format(pendingTotal)) en attente"
    }

    func count(for f: DebourFilter) -> Int {
        switch f {
        case .all:     return debours.count
        case .pending: return debours.filter { $0.status == "pending" }.count
        case .billed:  return debours.filter { $0.status == "billed" }.count
        }
    }

    var selectableClients: [OwnerClient] {
        clients.filter { $0.isAgencyClient != true }
    }

    func clientName(for debour: Debour) -> String {
        guard let cid = debour.clientId else { return "—" }
        return clients.first(where: { $0.id == cid })?.displayName ?? "—"
    }

    // MARK: - Chargement

    func load() async {
        if case .loaded = loadState {} else { loadState = .loading }
        async let deboursTask: DebourListResponse = APIClient.shared.get(
            Endpoint.debours, agencyAll: true
        )
        async let clientsTask: OwnerClientsResponse = APIClient.shared.get(
            Endpoint.ownerClients
        )

        do {
            let resp = try await deboursTask
            debours = resp.debours
        } catch APIError.subscriptionRequired {
            loadState = .featureBlocked; return
        } catch APIError.server(403, _) {
            loadState = .permissionDenied; return
        } catch {
            loadState = .error("Impossible de charger les débours."); return
        }

        clients = (try? await clientsTask)?.clients ?? []
        loadState = .loaded
    }

    // MARK: - Bascule de statut

    func toggleStatus(_ debour: Debour) async {
        let newStatus = debour.status == "pending" ? "billed" : "pending"
        actionDebourId = debour.id
        defer { actionDebourId = nil }
        do {
            try await APIClient.shared.patchVoid(
                Endpoint.debourStatus(debour.id),
                body: DebourStatusBody(status: newStatus)
            )
            await silentReload()
        } catch {
            actionError = (error as? APIError)?.userMessage ?? "Erreur lors de la mise à jour."
        }
    }

    // MARK: - Suppression

    func delete(_ debour: Debour) async {
        actionDebourId = debour.id
        defer { actionDebourId = nil }
        do {
            try await APIClient.shared.delete(Endpoint.debour(debour.id))
            await silentReload()
        } catch {
            actionError = (error as? APIError)?.userMessage ?? "Erreur lors de la suppression."
        }
    }

    // MARK: - Ajout / mise à jour depuis la feuille

    func didCreate(_ debour: Debour) {
        debours.insert(debour, at: 0)
    }

    func didUpdate(_ updated: Debour) {
        if let idx = debours.firstIndex(where: { $0.id == updated.id }) {
            debours[idx] = updated
        }
    }

    // MARK: - Rechargement silencieux

    func silentReload() async {
        do {
            let resp: DebourListResponse = try await APIClient.shared.get(
                Endpoint.debours, agencyAll: true
            )
            debours = resp.debours
            if case .loading = loadState {} else { loadState = .loaded }
        } catch {}
    }
}

// MARK: - Formatter montant (2 décimales, fr_FR)

enum DebourAmountFmt {
    private static let fmt: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    static func format(_ value: Double) -> String {
        let s = fmt.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "\(s)\u{202F}€"
    }
}
