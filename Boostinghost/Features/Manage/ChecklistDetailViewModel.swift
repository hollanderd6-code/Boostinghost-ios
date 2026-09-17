import Foundation
import Observation

@MainActor
@Observable
final class ChecklistDetailViewModel {

    enum LoadState { case idle, loading, loaded, editing, noChecklist, error(String) }

    private(set) var loadState:      LoadState = .idle
    private(set) var detail:         ChecklistDetail?
    private(set) var relatedTickets: [MaintenanceTicket] = []
    private(set) var actionInProgress = false
    private(set) var expectedTasks:  [ChecklistTask]? = nil
    private(set) var templateMissing = false

    // Draft state — cleaner editing mode
    private(set) var draftTasks:     [ChecklistTask] = []
    private(set) var draftPhotos:    [PhotoDraft]    = []
    private(set) var draftStartedAt: Date?           = nil
    private(set) var isSavingDraft                   = false
    private(set) var isSubmitting                    = false
    private(set) var draftSaveError: String?         = nil

    var signatureData:      String? = nil
    var showSignatureSheet          = false
    var draftNotes                  = ""
    var showRejectSheet             = false
    var rejectNotes:        String  = ""
    var submitError:        String? = nil

    // CLEANFIX-13: serialize mutations (séparés pour ne pas que notes annule tâches)
    private var pendingMutationTask: Task<Void, Never>? = nil
    private var pendingNotesTask:    Task<Void, Never>? = nil

    // MARK: - Réassort
    private(set) var consumableItems:           [ConsumableItem] = []
    var restockSelected:                         Set<Int>        = []

    // MARK: - État à l'arrivée
    var arrivalChoice:                           ArrivalStateChoice? = nil
    var arrivalDamageTitle                                          = ""
    var arrivalDamageUploadedUrl:                String?            = nil
    private(set) var isUploadingArrivalPhoto                       = false
    private(set) var isSavingArrivalDraft                          = false
    var arrivalDraftSaved                                          = false   // WORKFLOWFIX
    var arrivalReportError:                      String?            = nil

    // MARK: - Signaler un problème
    var problemTitle                                               = ""
    var problemDesc                                                = ""
    var problemPriority                                            = "normal"
    private(set) var isSavingIssueDraft                            = false   // WORKFLOWFIX
    var issueDraftSaved                                            = false   // WORKFLOWFIX
    var problemReportError:                      String?            = nil

    var isAllTasksChecked: Bool {
        !draftTasks.isEmpty && draftTasks.allSatisfy { $0.checked }
    }

    var cameraCount: Int {
        draftPhotos.filter { $0.source == .camera }.count
    }

    var canSubmit: Bool {
        isAllTasksChecked && cameraCount >= 5 && !isSubmitting
    }

    // MARK: - Chargement

    func load(ref: CleaningDetailRef, isSubAccount: Bool) async {
        guard case .idle = loadState else { return }
        loadState = .loading

        if isSubAccount {
            if let checklistId = ref.checklistId {
                // Checklist soumise indexée — read-only (après fix CleaningViewModel)
                do {
                    async let detailTask: ChecklistDetailResponse =
                        APIClient.shared.get(Endpoint.checklist(checklistId), agencyAll: true)
                    async let ticketsTask: MaintenanceTicketsResponse =
                        APIClient.shared.get(Endpoint.maintenanceTickets, agencyAll: true)
                    let detailResp = try await detailTask
                    let allTickets = (try? await ticketsTask)?.tickets ?? []
                    let cl = detailResp.checklist
                    if cl.completedAt == nil {
                        // CLEANFIX-5: brouillon mal indexé — restaurer mode édition
                        await restoreDraftFrom(checklist: cl, ref: ref)
                    } else {
                        detail = cl
                        if let resKey = cl.reservationKey {
                            relatedTickets = allTickets.filter { $0.reservationKey == resKey }
                        }
                        loadState = .loaded
                    }
                } catch APIError.unauthorized {
                    loadState = .error("Non autorisé")
                } catch APIError.network {
                    loadState = .error("Pas de connexion")
                } catch {
                    loadState = .error("Chargement impossible")
                }
            } else {
                // Pas de checklist soumise — chercher un brouillon via GET /draft
                if let rk = ref.reservationKey,
                   let draft = try? await fetchDraft(reservationKey: rk) {
                    restoreFromDraftDetail(draft)
                    return
                }
                // Aucun brouillon — démarrage à partir du modèle
                await loadExpectedTasks(propertyId: ref.propertyId)
                draftTasks     = expectedTasks ?? []
                draftStartedAt = Date()
                loadState      = .editing
                Task { await saveDraftSnapshot(ref: ref) }
                Task { await loadConsumables(ref: ref) }
            }
            return
        }

        // Mode propriétaire (inchangé)
        guard let checklistId = ref.checklistId else {
            await loadExpectedTasks(propertyId: ref.propertyId)
            loadState = .noChecklist
            return
        }

        async let detailTask: ChecklistDetailResponse =
            APIClient.shared.get(Endpoint.checklist(checklistId), agencyAll: true)
        async let ticketsTask: MaintenanceTicketsResponse =
            APIClient.shared.get(Endpoint.maintenanceTickets, agencyAll: true)

        do {
            let detailResp = try await detailTask
            let allTickets = (try? await ticketsTask)?.tickets ?? []
            detail = detailResp.checklist
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

    // MARK: - Restauration brouillon

    private func fetchDraft(reservationKey: String) async throws -> DraftDetail {
        let resp: DraftDetailResponse = try await APIClient.shared.get(
            Endpoint.checklistDraft(reservationKey)
        )
        return resp.draft
    }

    private func restoreFromDraftDetail(_ draft: DraftDetail) {
        draftTasks  = draft.tasks
        draftPhotos = draft.photos
        draftNotes  = draft.notes ?? ""
        if let sa = draft.startedAt, let date = ISO8601DateFormatter().date(from: sa) {
            draftStartedAt = date
        } else {
            draftStartedAt = Date()
        }
        // WORKFLOWFIX: restaurer draft_meta
        arrivalChoice = ArrivalStateChoice.from(draft.arrivalState)
        if let dd = draft.damageDraft {
            arrivalDamageTitle       = dd.title
            arrivalDamageUploadedUrl = dd.photoUrl
            arrivalDraftSaved        = true
        }
        if let id_ = draft.issueDraft {
            problemTitle    = id_.title
            problemDesc     = id_.description ?? ""
            problemPriority = id_.priority
            issueDraftSaved = true
        }
        if let ids = draft.restock { restockSelected = Set(ids) }
        loadState = .editing
    }

    private func scheduleConsumableLoad(ref: CleaningDetailRef) {
        Task { await loadConsumables(ref: ref) }
    }

    private func restoreDraftFrom(checklist: ChecklistDetail, ref: CleaningDetailRef) async {
        // Tenter GET /draft pour récupérer les photos avec leurs ID stables
        let rk = ref.reservationKey ?? checklist.reservationKey
        if let rk, let draft = try? await fetchDraft(reservationKey: rk) {
            restoreFromDraftDetail(draft)
        } else {
            // Fallback : données de ChecklistDetail sans ID photo
            draftTasks  = checklist.tasks
            draftPhotos = checklist.photos.map { PhotoDraft(id: UUID().uuidString, data: $0, source: .unknown) }
            draftNotes  = checklist.notes ?? ""
            draftStartedAt = Date()
            loadState = .editing
        }
        scheduleConsumableLoad(ref: ref)
    }

    // MARK: - Tâches attendues

    private func loadExpectedTasks(propertyId: String?) async {
        guard let pid = propertyId else { templateMissing = true; return }
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
            if let t = resolved { expectedTasks = t.tasks } else { templateMissing = true }
        } catch {
            templateMissing = true
        }
    }

    // MARK: - Snapshot initial

    private func saveDraftSnapshot(ref: CleaningDetailRef) async {
        guard let rk = ref.reservationKey, let pid = ref.propertyId else { return }
        isSavingDraft = true
        defer { isSavingDraft = false }
        let body = ChecklistDraftSnapshotRequest(
            propertyId: pid,
            tasks: draftTasks.map { $0.payload },
            photos: draftPhotos.map { PhotoDraftPayload(id: $0.id, data: $0.data, source: $0.source.rawValue) },
            notes: draftNotes,
            startedAt: draftStartedAt.map { isoString($0) }
        )
        try? await APIClient.shared.patchVoid(Endpoint.checklistDraft(rk), body: body)
    }

    // MARK: - Mutations tâches (CLEANFIX-7)

    func toggleTask(_ id: String, ref: CleaningDetailRef) {
        guard let idx = draftTasks.firstIndex(where: { $0.id == id }) else { return }
        let newChecked = !draftTasks[idx].checked
        draftTasks[idx].checked = newChecked
        draftSaveError = nil
        pendingMutationTask?.cancel()
        pendingMutationTask = Task { [id, newChecked] in
            await self.sendTaskChange(taskId: id, checked: newChecked, ref: ref)
        }
    }

    private func sendTaskChange(taskId: String, checked: Bool, ref: CleaningDetailRef) async {
        guard let rk = ref.reservationKey, let pid = ref.propertyId else { return }
        isSavingDraft = true
        defer { isSavingDraft = false }
        let body = ChecklistDraftTaskChangeRequest(
            propertyId: pid,
            taskChanges: [ChecklistTaskChange(id: taskId, checked: checked)]
        )
        do {
            try await APIClient.shared.patchVoid(Endpoint.checklistDraft(rk), body: body)
        } catch {
            // CLEANFIX-12: rollback + feedback
            if let idx = draftTasks.firstIndex(where: { $0.id == taskId }) {
                draftTasks[idx].checked = !checked
            }
            draftSaveError = "Sauvegarde échouée. Réessayez."
        }
    }

    // MARK: - Notes (CLEANFIX-6 + debounce)

    func scheduleNotesSave(ref: CleaningDetailRef) {
        pendingNotesTask?.cancel()
        pendingNotesTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            await self.sendNotes(ref: ref)
        }
    }

    private func sendNotes(ref: CleaningDetailRef) async {
        guard let rk = ref.reservationKey, let pid = ref.propertyId else { return }
        let body = ChecklistDraftNotesRequest(propertyId: pid, notes: draftNotes)
        try? await APIClient.shared.patchVoid(Endpoint.checklistDraft(rk), body: body)
    }

    // MARK: - Mutations photos (CLEANFIX-8)

    func addPhoto(_ photo: PhotoDraft, ref: CleaningDetailRef) {
        draftPhotos.append(photo)
        draftSaveError = nil
        pendingMutationTask?.cancel()
        pendingMutationTask = Task {
            await self.sendAddPhoto(photo, ref: ref)
        }
    }

    private func sendAddPhoto(_ photo: PhotoDraft, ref: CleaningDetailRef) async {
        guard let rk = ref.reservationKey, let pid = ref.propertyId else { return }
        isSavingDraft = true
        defer { isSavingDraft = false }
        let body = ChecklistDraftAddPhotoRequest(
            propertyId: pid,
            addPhoto: PhotoDraftPayload(id: photo.id, data: photo.data, source: photo.source.rawValue)
        )
        do {
            try await APIClient.shared.patchVoid(Endpoint.checklistDraft(rk), body: body)
        } catch {
            // CLEANFIX-12: rollback
            draftPhotos.removeAll { $0.id == photo.id }
            draftSaveError = "Photo non sauvegardée. Réessayez."
        }
    }

    func removePhoto(id photoId: String, ref: CleaningDetailRef) {
        guard let idx = draftPhotos.firstIndex(where: { $0.id == photoId }) else { return }
        let removed = draftPhotos.remove(at: idx)
        draftSaveError = nil
        pendingMutationTask?.cancel()
        pendingMutationTask = Task {
            await self.sendRemovePhoto(removed, ref: ref)
        }
    }

    private func sendRemovePhoto(_ photo: PhotoDraft, ref: CleaningDetailRef) async {
        guard let rk = ref.reservationKey, let pid = ref.propertyId else { return }
        isSavingDraft = true
        defer { isSavingDraft = false }
        let body = ChecklistDraftRemovePhotoRequest(
            propertyId: pid,
            removePhotoId: photo.id
        )
        do {
            try await APIClient.shared.patchVoid(Endpoint.checklistDraft(rk), body: body)
        } catch {
            // CLEANFIX-12: rollback
            draftPhotos.append(photo)
            draftSaveError = "Suppression non sauvegardée."
        }
    }

    // MARK: - Soumission finale

    func submitChecklist(ref: CleaningDetailRef) async -> Bool {
        guard let reservationKey = ref.reservationKey,
              let propertyId = ref.propertyId,
              let sig = signatureData else { return false }
        isSubmitting = true
        submitError  = nil
        defer { isSubmitting = false }
        let now  = isoString(Date())
        let body = ChecklistSubmitRequest(
            reservationKey: reservationKey,
            propertyId:     propertyId,
            tasks:          draftTasks.map { $0.payload },
            photos:         draftPhotos.map { $0.data },
            notes:          draftNotes,
            duration:       draftStartedAt.map { Int(Date().timeIntervalSince($0)) },
            startedAt:      draftStartedAt.map { isoString($0) },
            checkoutDate:   ref.dateStr.isEmpty ? nil : ref.dateStr,
            signatureData:  sig,
            certifiedAt:    now,
            restock:        restockSelected.isEmpty ? nil : Array(restockSelected).sorted()
        )
        do {
            let _: ChecklistSubmitResponse = try await APIClient.shared.post(
                Endpoint.checklistSubmit, body: body
            )
            return true
        } catch APIError.server(_, let msg) {
            submitError = msg ?? "Erreur lors de l'envoi."
            return false
        } catch {
            submitError = "Envoi impossible. Réessayez."
            return false
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

    // MARK: - Réassort

    func loadConsumables(ref: CleaningDetailRef) async {
        guard let pid = ref.propertyId else { return }
        let resp = try? await APIClient.shared.get(
            Endpoint.cleaningConsumables,
            extraQueryItems: [URLQueryItem(name: "propertyId", value: pid)]
        ) as ConsumablesResponse
        consumableItems = resp?.items ?? []
    }

    func toggleRestock(_ itemId: Int, ref: CleaningDetailRef) {
        if restockSelected.contains(itemId) {
            restockSelected.remove(itemId)
        } else {
            restockSelected.insert(itemId)
        }
        // WORKFLOWFIX: persister dans draft_meta
        let ids = Array(restockSelected).sorted()
        pendingMutationTask?.cancel()
        pendingMutationTask = Task { [ids] in
            guard let rk = ref.reservationKey, let pid = ref.propertyId else { return }
            let body = ChecklistDraftMetaRequest(
                propertyId: pid, arrivalState: nil, damageDraft: nil, issueDraft: nil, restock: ids
            )
            try? await APIClient.shared.patchVoid(Endpoint.checklistDraft(rk), body: body)
        }
    }

    // MARK: - Photo upload (état à l'arrivée)

    func uploadArrivalPhoto(_ dataURI: String, ref: CleaningDetailRef) async {
        guard let pid = ref.propertyId else { return }
        isUploadingArrivalPhoto = true
        arrivalReportError = nil
        defer { isUploadingArrivalPhoto = false }
        let body = PhotoUploadRequest(
            dataUrl: dataURI,
            propertyId: pid,
            reservationKey: ref.reservationKey,
            kind: "arrival_state"
        )
        do {
            let resp: PhotoUploadResponse = try await APIClient.shared.post(
                Endpoint.cleaningPhotoUpload, body: body
            )
            if !resp.url.isEmpty { arrivalDamageUploadedUrl = resp.url }
        } catch {
            arrivalReportError = "Envoi de la photo échoué. Réessayez."
        }
    }

    // WORKFLOWFIX: dégradation stockée dans draft_meta — ticket créé à la soumission finale
    func saveDamageDraft(ref: CleaningDetailRef) async {
        guard let rk = ref.reservationKey, let pid = ref.propertyId,
              !arrivalDamageTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSavingArrivalDraft = true
        arrivalReportError   = nil
        defer { isSavingArrivalDraft = false }
        let dd = DraftDamageDraft(
            title:       arrivalDamageTitle.trimmingCharacters(in: .whitespaces),
            description: nil,
            photoUrl:    arrivalDamageUploadedUrl
        )
        let body = ChecklistDraftMetaRequest(
            propertyId:   pid,
            arrivalState: ArrivalStateChoice.damage.draftValue,
            damageDraft:  dd,
            issueDraft:   nil,
            restock:      nil
        )
        do {
            try await APIClient.shared.patchVoid(Endpoint.checklistDraft(rk), body: body)
            arrivalDraftSaved = true
        } catch APIError.server(_, let msg) {
            arrivalReportError = msg ?? "Sauvegarde échouée."
        } catch {
            arrivalReportError = "Sauvegarde impossible. Réessayez."
        }
    }

    func saveArrivalOk(ref: CleaningDetailRef) async {
        guard let rk = ref.reservationKey, let pid = ref.propertyId else { return }
        isSavingArrivalDraft = true
        defer { isSavingArrivalDraft = false }
        let body = ChecklistDraftMetaRequest(
            propertyId:   pid,
            arrivalState: ArrivalStateChoice.ok.draftValue,
            damageDraft:  nil,
            issueDraft:   nil,
            restock:      nil
        )
        try? await APIClient.shared.patchVoid(Endpoint.checklistDraft(rk), body: body)
        arrivalDraftSaved = false
    }

    // MARK: - Signaler un problème

    // WORKFLOWFIX: incident stocké dans draft_meta — ticket créé à la soumission finale
    func saveIssueDraft(ref: CleaningDetailRef) async {
        guard let rk = ref.reservationKey, let pid = ref.propertyId,
              !problemTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSavingIssueDraft = true
        problemReportError = nil
        defer { isSavingIssueDraft = false }
        let desc = problemDesc.trimmingCharacters(in: .whitespaces)
        let id_ = DraftIssueDraft(
            title:       problemTitle.trimmingCharacters(in: .whitespaces),
            description: desc.isEmpty ? nil : desc,
            priority:    problemPriority
        )
        let body = ChecklistDraftMetaRequest(
            propertyId:   pid,
            arrivalState: nil,
            damageDraft:  nil,
            issueDraft:   id_,
            restock:      nil
        )
        do {
            try await APIClient.shared.patchVoid(Endpoint.checklistDraft(rk), body: body)
            issueDraftSaved = true
        } catch APIError.server(_, let msg) {
            problemReportError = msg ?? "Sauvegarde échouée."
        } catch {
            problemReportError = "Sauvegarde impossible. Réessayez."
        }
    }

    // MARK: - Helpers

    private func isoString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
