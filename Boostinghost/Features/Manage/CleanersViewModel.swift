import Foundation
import Observation

enum CleanerError: Error {
    case smsOptionRequired
}

@Observable
@MainActor
final class CleanersViewModel {
    enum LoadState { case loading, loaded, failed }

    var loadState: LoadState = .loading
    var cleaners: [CleanerItem] = []

    // Chargés en parallèle avec les intervenants.
    private(set) var defaultsByProperty: [String: DefaultCleanerEntry] = [:]
    private(set) var properties: [Property] = []

    var showCreateSheet = false

    // MARK: - Load (parallel)

    func load() async {
        loadState = .loading

        async let cleanersTask: CleanersListResponse   = APIClient.shared.get(Endpoint.cleaners, agencyAll: true)
        async let defaultsTask: DefaultCleanersResponse = APIClient.shared.get(Endpoint.defaultCleaners, agencyAll: true)
        async let propertiesTask: PropertiesResponse    = APIClient.shared.get(Endpoint.properties, agencyAll: true)

        do {
            cleaners = (try await cleanersTask).cleaners
        } catch {
            loadState = .failed
            return
        }

        defaultsByProperty = (try? await defaultsTask)?.defaults ?? [:]
        properties = ((try? await propertiesTask)?.properties ?? [])
            .filter { !$0.id.isEmpty }
            .sorted { ($0.internalName ?? $0.name) < ($1.internalName ?? $1.name) }

        loadState = .loaded

        // Recoupement IDs : vérifie que Property.id correspond aux clés de defaultsByProperty.
        let propIds    = Set(properties.map { $0.id })
        let defaultIds = Set(defaultsByProperty.keys)
        let matched    = propIds.intersection(defaultIds)
        let onlyInDefault = defaultIds.subtracting(propIds)
        print("[DEBUG-CLEANER-IDS] \(properties.count) logements chargés")
        print("[DEBUG-CLEANER-IDS] Exemples Property.id  : \(Array(propIds).prefix(3))")
        print("[DEBUG-CLEANER-IDS] Exemples defaults keys: \(Array(defaultIds).prefix(3))")
        print("[DEBUG-CLEANER-IDS] Correspondances : \(matched.count) / \(defaultIds.count)")
        if !onlyInDefault.isEmpty {
            print("[DEBUG-CLEANER-IDS] Clés sans logement correspondant : \(Array(onlyInDefault).prefix(5))")
        }
    }

    // MARK: - Derived queries

    // Nombre de logements dont cet intervenant est le ménage par défaut.
    func propertyCount(for cleanerId: String) -> Int? {
        let n = defaultsByProperty.values.filter { $0.cleanerId == cleanerId }.count
        return n > 0 ? n : nil
    }

    // Logements assignés à cet intervenant, triés par nom affiché.
    func assignedProperties(for cleanerId: String) -> [Property] {
        let ids = Set(defaultsByProperty.filter { $0.value.cleanerId == cleanerId }.map { $0.key })
        return properties.filter { ids.contains($0.id) }
    }

    // Entrée par défaut pour un logement donné (pour détecter « assigné à un autre »).
    func defaultEntry(for propertyId: String) -> DefaultCleanerEntry? {
        defaultsByProperty[propertyId]
    }

    // MARK: - Create (POST /api/cleaners)

    func create(name: String, email: String?, phone: String?,
                notes: String?, isActive: Bool) async throws -> CleanerItem {
        let body = CleanerWriteBody(name: name, email: email, phone: phone,
                                    notes: notes, isActive: isActive, subAccountId: nil)
        let resp: CreateCleanerResponse = try await APIClient.shared.post(
            Endpoint.cleaners, body: body, agencyAll: true
        )
        cleaners.append(resp.cleaner)
        cleaners.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return resp.cleaner
    }

    // MARK: - Update (PUT /api/cleaners/:id)
    // PUT ne renvoie ni pinCode ni accessToken — mise à jour locale depuis l'objet existant.

    func update(id: String, name: String, email: String?,
                phone: String?, notes: String?, isActive: Bool) async throws {
        let subAccountId = cleaners.first(where: { $0.id == id })?.subAccountId
        let body = CleanerWriteBody(name: name, email: email, phone: phone,
                                    notes: notes, isActive: isActive, subAccountId: subAccountId)
        try await APIClient.shared.putVoid(Endpoint.cleaner(id), body: body, agencyAll: true)
        if let idx = cleaners.firstIndex(where: { $0.id == id }) {
            cleaners[idx].name     = name
            cleaners[idx].email    = email
            cleaners[idx].phone    = phone
            cleaners[idx].notes    = notes
            cleaners[idx].isActive = isActive
        }
    }

    // MARK: - Delete (DELETE /api/cleaners/:id)

    func delete(id: String) async throws {
        try await APIClient.shared.delete(Endpoint.cleaner(id), agencyAll: true)
        cleaners.removeAll { $0.id == id }
        defaultsByProperty = defaultsByProperty.filter { $0.value.cleanerId != id }
    }

    // MARK: - Regenerate link (POST /api/cleaners/:id/regenerate-link)

    func regenerateLink(id: String) async throws -> String {
        let resp: RegenerateLinkResponse = try await APIClient.shared.post(
            Endpoint.cleanerRegenerateLink(id), body: EmptyBody(), agencyAll: true
        )
        let newToken = resp.cleaner.accessToken
        if let idx = cleaners.firstIndex(where: { $0.id == id }) {
            cleaners[idx].accessToken = newToken
        }
        return newToken
    }

    // MARK: - SMS toggle (PUT /api/cleaners/:id/sms-toggle)

    func toggleSms(id: String, enabled: Bool) async throws {
        do {
            try await APIClient.shared.putVoid(
                Endpoint.cleanerSmsToggle(id),
                body: SmsToggleBody(enabled: enabled),
                agencyAll: true
            )
        } catch let err as APIError {
            if case .server(403, .some(let msg)) = err, msg == "option_required" {
                throw CleanerError.smsOptionRequired
            }
            throw err
        }
        if let idx = cleaners.firstIndex(where: { $0.id == id }) {
            cleaners[idx].smsRecapEnabled = enabled
        }
    }

    // MARK: - Set default cleaner (PUT /api/cleaning/default-cleaner/:propertyId)
    // cleanerId nil → { cleanerId: null } → retire l'association.

    func setDefaultCleaner(propertyId: String, cleanerId: String?) async throws {
        try await APIClient.shared.putVoid(
            Endpoint.defaultCleaner(propertyId),
            body: DefaultCleanerBody(cleanerId: cleanerId),
            agencyAll: true
        )

        if let cid = cleanerId {
            let name = cleaners.first(where: { $0.id == cid })?.name ?? ""
            defaultsByProperty[propertyId] = DefaultCleanerEntry(cleanerId: cid, cleanerName: name)
        } else {
            defaultsByProperty.removeValue(forKey: propertyId)
        }
    }

    // MARK: - Access URL (client-side)

    func accessURL(for cleaner: CleanerItem) -> URL? {
        let base = "https://www.boostinghost.fr/cleaning-tasks.html"
        if !cleaner.accessToken.isEmpty {
            return URL(string: "\(base)?t=\(cleaner.accessToken)")
        } else if !cleaner.pinCode.isEmpty {
            return URL(string: base)
        }
        return nil
    }
}
