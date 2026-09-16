import Foundation
import Observation

@Observable
@MainActor
final class OwnersViewModel {

    enum LoadState { case loading, loaded, featureBlocked, error(String) }

    var loadState: LoadState = .loading
    var clients: [OwnerClient]      = []
    var draftInvoices: [OwnerInvoice]   = []   // factures brouillon propriétaires
    var pendingContracts: [OwnerContract] = []  // contrats status == "sent"
    var propertyCountByOwner: [String: Int] = [:]
    var totalPropertyCount: Int = 0

    var showCreateSheet: Bool   = false
    var createSuccessName: String? = nil

    // MARK: - Derived

    var clientCount: Int { clients.count }

    // Contrat envoyé le plus anciennement (pour l'alerte : "Envoyé il y a N jours")
    var oldestPendingContract: OwnerContract? {
        pendingContracts.max(by: { daysSince($0.createdAt) < daysSince($1.createdAt) })
    }

    func propertyCount(for client: OwnerClient) -> Int {
        propertyCountByOwner[client.matchingId] ?? 0
    }

    func draftCount(for clientId: String) -> Int {
        draftInvoices.filter { $0.clientId == clientId }.count
    }

    func contractCount(for clientId: String) -> Int {
        pendingContracts.filter { $0.clientId == clientId }.count
    }

    // Pastille prioritaire : "contrat non signé" > "facture à envoyer"
    // Un contrat avec clientId nil ne pose aucune pastille.
    func badgeText(for client: OwnerClient) -> String? {
        if contractCount(for: client.matchingId) > 0 { return "contrat non signé" }
        if draftCount(for: client.matchingId) > 0    { return "facture à envoyer" }
        return nil
    }

    func daysSince(_ isoDate: String?) -> Int {
        guard let isoDate else { return 0 }
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: String(isoDate.prefix(10))) else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0)
    }

    // MARK: - Load

    func load() async {
        if case .loaded = loadState {} else { loadState = .loading }

        // owner-clients : pas d'agency=all — la route résout elle-même la délégation
        do {
            let resp: OwnerClientsResponse = try await APIClient.shared.get(Endpoint.ownerClients)
            clients = resp.clients
        } catch APIError.subscriptionRequired {
            loadState = .featureBlocked; return
        } catch APIError.server(403, _) {
            loadState = .featureBlocked; return
        } catch {
            loadState = .error("Impossible de charger les clients."); return
        }

        // Fetches secondaires en parallèle — échec silencieux (badges dégradent)
        async let invoicesTask: OwnerInvoicesResponse  = APIClient.shared.get(
            Endpoint.ownerInvoices, agencyAll: true)
        async let contratsTask: OwnerContractsResponse = APIClient.shared.get(
            Endpoint.contrats,
            agencyAll: true,
            extraQueryItems: [URLQueryItem(name: "status", value: "sent")])
        async let propsTask: PropertiesResponse        = APIClient.shared.get(
            Endpoint.properties, agencyAll: true)

        if let invResp = try? await invoicesTask {
            draftInvoices = (invResp.invoices ?? []).filter { $0.isDraft }
        }
        if let contResp = try? await contratsTask {
            pendingContracts = contResp.contracts ?? []
        }
        if let propsResp = try? await propsTask {
            let props = propsResp.properties ?? []
            totalPropertyCount = props.count
            var dict: [String: Int] = [:]
            for prop in props {
                guard let oid = prop.ownerId else { continue }
                dict[oid, default: 0] += 1
            }
            propertyCountByOwner = dict

            // [DEBUG-OWNER-IDS] — retirer après diagnostic
            let sampleClients  = clients.prefix(3).map { "\($0.id) → \($0.matchingId)" }
            let sampleOwnerIds = props.compactMap { $0.ownerId }.prefix(3)
            let matches        = props.compactMap { $0.ownerId }
                                      .filter { oid in clients.contains { $0.matchingId == oid } }.count
            print("[DEBUG-OWNER-IDS] client.id → matchingId exemples : \(sampleClients)")
            print("[DEBUG-OWNER-IDS] property.ownerId exemples        : \(Array(sampleOwnerIds))")
            print("[DEBUG-OWNER-IDS] correspondances trouvées         : \(matches) / \(props.count) logements")
        }

        loadState = .loaded
    }

    // MARK: - Create

    func create(
        clientType: String,
        companyName: String?,
        firstName: String?,
        lastName: String?,
        email: String?,
        phone: String?,
        siret: String?,
        address: String?,
        postalCode: String?,
        city: String?,
        defaultCommissionRate: Double?
    ) async throws {
        let body = CreateOwnerClientBody(
            clientType:            clientType,
            companyName:           companyName,
            firstName:             firstName,
            lastName:              lastName,
            email:                 email,
            phone:                 phone,
            siret:                 siret,
            address:               address,
            postalCode:            postalCode,
            city:                  city,
            defaultCommissionRate: defaultCommissionRate
        )
        let resp: CreateOwnerClientResponse = try await APIClient.shared.post(
            Endpoint.ownerClients, body: body)
        let newClient = resp.client
        clients.insert(newClient, at: 0)
        showCreateSheet  = false
        createSuccessName = newClient.displayName
    }
}
