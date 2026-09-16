import Foundation
import Observation

@Observable
@MainActor
final class OwnerClientDetailViewModel {

    enum LoadState { case loading, loaded, error(String) }
    enum ActionState: Equatable {
        case idle
        case running
        case error(String)
    }

    let clientId: String
    var loadState: LoadState = .loading
    var client: OwnerClient?
    var associatedProperties: [Property] = []
    var allProperties: [Property] = []
    var actionState: ActionState = .idle

    init(client: OwnerClient) {
        self.clientId = client.id
        self.client   = client
    }

    // MARK: - Chargement

    func load() async {
        loadState = .loading
        // Les agency clients (id préfixé "agency_client_") n'existent pas dans
        // la table owner_clients du compte propre — GET /:id renvoie 404.
        // On utilise les données déjà présentes depuis la liste et on saute le GET.
        if client?.isAgencyClient == true {
            await loadProperties()
            loadState = .loaded
            return
        }
        do {
            // GET /api/owner-clients/:id renvoie l'objet à plat, sans enveloppe { client }.
            let fetched: OwnerClient = try await APIClient.shared.get(
                Endpoint.ownerClient(clientId))
            client = fetched
            await loadProperties()
            loadState = .loaded
        } catch {
            loadState = .error("Impossible de charger le client.")
        }
    }

    private func loadProperties() async {
        guard let matchingId = client?.matchingId else { return }
        let propsResp: PropertiesResponse? = try? await APIClient.shared.get(
            Endpoint.properties, agencyAll: true)
        let all = propsResp?.properties ?? []
        allProperties = all
        associatedProperties = all.filter { $0.ownerId == matchingId }
    }

    // MARK: - Assignation de logements

    func savePropertyAssignments(newSelected: Set<String>) async throws {
        guard let matchingId = client?.matchingId else { return }
        let currentIds = Set(associatedProperties.map(\.id))
        let toAssign   = newSelected.subtracting(currentIds)
        let toRemove   = currentIds.subtracting(newSelected)
        guard !toAssign.isEmpty || !toRemove.isEmpty else { return }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for propId in toAssign {
                group.addTask {
                    let _: PatchPropertyOwnerResponse = try await APIClient.shared.patch(
                        Endpoint.property(propId),
                        body: PatchPropertyOwnerBody(ownerId: matchingId),
                        agencyAll: true
                    )
                }
            }
            for propId in toRemove {
                group.addTask {
                    let _: PatchPropertyOwnerResponse = try await APIClient.shared.patch(
                        Endpoint.property(propId),
                        body: PatchPropertyOwnerBody(ownerId: nil),
                        agencyAll: true
                    )
                }
            }
            for try await _ in group {}
        }

        await loadProperties()
    }

    // MARK: - Modification

    func update(body: UpdateOwnerClientBody) async throws {
        if client?.isAgencyClient == true {
            guard let delegatorId = client?.delegatorUserId else {
                throw APIError.server(statusCode: 400, message: "Compte délégant introuvable.")
            }
            let matchingId = client?.matchingId ?? clientId
            let overrideBody = PatchAgencyClientOverrideBody(
                firstName:   body.firstName,
                lastName:    body.lastName,
                companyName: body.companyName,
                email:       body.email,
                siret:       body.siret,
                phone:       body.phone,
                address:     body.address,
                postalCode:  body.postalCode,
                city:        body.city
            )
            let resp: PatchAgencyClientOverrideResponse = try await APIClient.shared.patch(
                Endpoint.agencyClientOverride(delegatorUserId: delegatorId, clientId: matchingId),
                body: overrideBody)
            client = resp.client
        } else {
            // PUT /api/owner-clients/:id renvoie { client: {...} }.
            let resp: PutOwnerClientResponse = try await APIClient.shared.put(
                Endpoint.ownerClient(clientId), body: body)
            client = resp.client
        }
    }

    // MARK: - Suppression (impossible pour un client d'agence)

    var canDelete: Bool { client?.isAgencyClient != true }

    func delete() async -> Bool {
        actionState = .running
        do {
            try await APIClient.shared.delete(Endpoint.ownerClient(clientId))
            actionState = .idle
            return true
        } catch {
            actionState = .error((error as? APIError)?.userMessage ?? "Erreur lors de la suppression.")
            return false
        }
    }
}

// PUT /api/owner-clients/:id → { client: {...} }
private struct PutOwnerClientResponse: Decodable {
    let client: OwnerClient
}

// PATCH /api/agency/client-override/:delegatorUserId/:clientId → { client: {...} }
private struct PatchAgencyClientOverrideResponse: Decodable {
    let client: OwnerClient
}
