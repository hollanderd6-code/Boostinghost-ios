import Foundation
import Observation

@MainActor
@Observable
final class ChecklistDetailViewModel {

    enum LoadState { case idle, loading, loaded, noChecklist, error(String) }

    private(set) var loadState:      LoadState = .idle
    private(set) var detail:         ChecklistDetail?
    private(set) var relatedTickets: [MaintenanceTicket] = []
    private(set) var actionInProgress = false
    private(set) var expectedTasks:  [ChecklistTask]? = nil
    private(set) var templateMissing = false

    var showRejectSheet = false
    var rejectNotes:    String = ""

    // MARK: - Chargement

    func load(ref: CleaningDetailRef, isSubAccount: Bool) async {
        guard case .idle = loadState else { return }
        loadState = .loading

        // Les sous-comptes ne peuvent pas appeler GET /checklists/:id (pas d'authenticateAny).
        // S'il n'y a pas de checklist soumise, on charge les tâches attendues depuis le modèle.
        guard !isSubAccount, let checklistId = ref.checklistId else {
            if ref.checklistId == nil {
                await loadExpectedTasks(propertyId: ref.propertyId)
            }
            loadState = .noChecklist
            return
        }

        // Fetch le détail et tous les tickets en parallèle.
        async let detailTask: ChecklistDetailResponse =
            APIClient.shared.get(Endpoint.checklist(checklistId), agencyAll: true)
        async let ticketsTask: MaintenanceTicketsResponse =
            APIClient.shared.get(Endpoint.maintenanceTickets, agencyAll: true)

        do {
            let detailResp = try await detailTask
            let allTickets = (try? await ticketsTask)?.tickets ?? []

            detail = detailResp.checklist
            // Les incidents se lient par reservation_key — pas de FK directe.
            if let resKey = detailResp.checklist.reservationKey {
                relatedTickets = allTickets.filter { $0.reservationKey == resKey }
            }
            loadState = .loaded
        } catch APIError.unauthorized {
            loadState = .error("Non autorisé")
        } catch APIError.network {
            loadState = .error("Pas de connexion")
        } catch {
            loadState = .error("Chargement impossible")
        }
    }

    // MARK: - Tâches attendues (GET /api/cleaning/templates)
    // Résolution 3 niveaux : modèle exact du logement → is_default → n'importe quel global.
    // Le serveur retourne déjà uniquement les modèles du logement + les globaux quand
    // ?propertyId est fourni, mais l'ordre serveur (is_default DESC) ne correspond pas
    // à la priorité : on résout côté client.

    private func loadExpectedTasks(propertyId: String?) async {
        guard let pid = propertyId else {
            templateMissing = true
            return
        }
        do {
            let resp: CleaningTemplatesResponse = try await APIClient.shared.get(
                Endpoint.cleaningTemplates,
                agencyAll: true,
                extraQueryItems: [URLQueryItem(name: "propertyId", value: pid)]
            )
            let templates = resp.templates
            let resolved = templates.first(where: { $0.propertyId == pid })
                        ?? templates.first(where: { $0.isDefault })
                        ?? templates.first(where: { $0.propertyId == nil })
            if let t = resolved {
                expectedTasks = t.tasks
            } else {
                templateMissing = true
            }
        } catch {
            templateMissing = true
        }
    }

    // MARK: - Valider (PUT /:id/validate)

    func validate() async -> Bool {
        guard let id = detail?.id else { return false }
        actionInProgress = true
        defer { actionInProgress = false }
        do {
            let resp: ChecklistDetailResponse = try await APIClient.shared.put(
                Endpoint.checklistValidate(id), body: EmptyBody(), agencyAll: true
            )
            detail = resp.checklist
            return true
        } catch { return false }
    }

    // MARK: - PDF certifié (GET /:id/pdf)

    func fetchPdf(id: String) async throws -> Data {
        try await APIClient.shared.getData(Endpoint.checklistPdf(id), agencyAll: true)
    }

    // MARK: - Demander un complément (PUT /:id/reject)
    // L'état côté backend devient "rejected" — le libellé "Demander un complément"
    // est choisi pour masquer le mot "rejet" à l'hôte.

    func reject(notes: String) async -> Bool {
        guard let id = detail?.id else { return false }
        showRejectSheet = false
        actionInProgress = true
        defer { actionInProgress = false }
        do {
            let resp: ChecklistDetailResponse = try await APIClient.shared.put(
                Endpoint.checklistReject(id), body: RejectBody(notes: notes), agencyAll: true
            )
            detail = resp.checklist
            return true
        } catch { return false }
    }
}
