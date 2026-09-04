import Foundation
import Observation

@Observable
@MainActor
final class MessageTemplatesViewModel {
    enum LoadState { case loading, loaded, failed }

    var loadState: LoadState = .loading
    var templates: [MessageTemplateItem] = []
    private(set) var properties: [Property] = []
    var selectedPropertyId: String? = nil

    private var isTogglingActive = false

    // MARK: - Load

    func load() async {
        loadState = .loading

        var extra: [URLQueryItem] = []
        if let pid = selectedPropertyId {
            extra = [URLQueryItem(name: "property_id", value: pid)]
        }

        if properties.isEmpty {
            // Premier chargement : récupère les templates et la liste de logements en parallèle.
            async let tplTask:  MessageTemplatesResponse = APIClient.shared.get(
                Endpoint.messageTemplates, agencyAll: true, extraQueryItems: extra)
            async let propTask: PropertiesResponse       = APIClient.shared.get(
                Endpoint.properties, agencyAll: true)

            do {
                templates = (try await tplTask).templates
            } catch {
                loadState = .failed
                return
            }

            // Double if-let intentionnel : distingue l'erreur réseau (r == nil)
            // de la réponse inattendue sans clé "properties" (list == nil).
            // Les deux cas laissent properties = [] → filtre absent, mais la liste
            // de templates s'affiche quand même sans filtre actif.
            if let r = try? await propTask, let list = r.properties {
                properties = list
                    .filter { !$0.id.isEmpty }
                    .sorted { ($0.internalName ?? $0.name) < ($1.internalName ?? $1.name) }
            }
        } else {
            // Rechargement après changement de filtre : templates seulement.
            do {
                let r: MessageTemplatesResponse = try await APIClient.shared.get(
                    Endpoint.messageTemplates, agencyAll: true, extraQueryItems: extra)
                templates = r.templates
            } catch {
                loadState = .failed
                return
            }
        }

        loadState = .loaded
    }

    // MARK: - Filtre logement

    func selectProperty(_ id: String?) async {
        guard id != selectedPropertyId else { return }
        selectedPropertyId = id
        await load()
    }

    // MARK: - Sauvegarde complète (PUT /api/message-templates/:id)

    func saveTemplate(id: Int, body: TemplateWriteBody) async throws -> MessageTemplateItem {
        let response: TemplateSaveResponse = try await APIClient.shared.put(
            Endpoint.messageTemplate(id), body: body, agencyAll: true)
        let updated = response.template
        if let idx = templates.firstIndex(where: { $0.id == id }) {
            templates[idx] = updated
        }
        return updated
    }

    // MARK: - Bascule active (PUT /api/message-templates/:id)

    func toggleActive(templateId: Int, current: Bool) async throws {
        guard !isTogglingActive else { return }
        isTogglingActive = true
        defer { isTogglingActive = false }
        let newValue = !current
        try await APIClient.shared.putVoid(
            Endpoint.messageTemplate(templateId),
            body: TemplateActiveToggleBody(active: newValue),
            agencyAll: true
        )
        if let idx = templates.firstIndex(where: { $0.id == templateId }) {
            templates[idx].active = newValue
        }
    }
}
