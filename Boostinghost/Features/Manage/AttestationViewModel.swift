import Foundation
import Observation

@Observable
@MainActor
final class AttestationViewModel {

    enum LoadState   { case loading, ready, featureBlocked, error(String) }
    enum ActionState: Equatable {
        case idle
        case loading
        case error(String)
    }

    var loadState:     LoadState   = .loading
    var generateState: ActionState = .idle
    var sendState:     ActionState = .idle

    var draft          = AttestationDraft()
    var clients:       [OwnerClient] = []
    var selectedClient: OwnerClient? = nil

    // agency_client_ ids sont refusés par le serveur (400) — on les exclut du sélecteur.
    var selectableClients: [OwnerClient] {
        clients.filter { !$0.id.hasPrefix("agency_client_") }
    }

    // MARK: - Load

    func load() async {
        loadState = .loading
        do {
            async let profileTask: UserProfile          = APIClient.shared.get(Endpoint.userProfile)
            async let clientsTask: OwnerClientsResponse = APIClient.shared.get(Endpoint.ownerClients)
            let profile     = try await profileTask
            let clientsResp = try await clientsTask
            applyProfile(profile)
            clients = clientsResp.clients
            loadState = .ready
        } catch APIError.subscriptionRequired {
            loadState = .featureBlocked
        } catch APIError.server(403, _) {
            loadState = .featureBlocked
        } catch {
            loadState = .error("Impossible de charger les données.")
        }
    }

    private func applyProfile(_ p: UserProfile) {
        draft.emitterCompany    = p.company      ?? ""
        draft.emitterAddress    = p.address      ?? ""
        draft.emitterPostalCode = p.postalCode   ?? ""
        draft.emitterCity       = p.city         ?? ""
        draft.emitterSiret      = p.siret        ?? ""
        draft.emitterEmail      = p.invoiceEmail ?? p.email
        draft.ville             = p.city         ?? ""
    }

    func selectClient(_ client: OwnerClient) {
        selectedClient = client
        draft.clientId = client.id
    }

    func clearClient() {
        selectedClient = nil
        draft.clientId = ""
    }

    // MARK: - Validation

    var isReadyToSubmit: Bool {
        !draft.clientId.isEmpty && draft.hasAtLeastOneCompleteLine
    }

    var beneficiaireMessage: String? {
        selectedClient == nil ? "Sélectionnez un bénéficiaire pour continuer." : nil
    }

    var prestationsMessage: String? {
        guard !draft.hasAtLeastOneCompleteLine else { return nil }
        let hasLabelMissing = draft.lines.contains { line in
            let heuresOk = !line.heures.isEmpty
                && Decimal(string: line.heures.replacingOccurrences(of: ",", with: ".")) != nil
            let tauxOk   = !line.taux.isEmpty
                && Decimal(string: line.taux.replacingOccurrences(of: ",", with: ".")) != nil
            return heuresOk && tauxOk && line.label.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return hasLabelMissing
            ? "Sélectionnez un service pour cette prestation."
            : "Complétez au moins une prestation."
    }

    // MARK: - Build body

    private func buildBody(includeSignature: Bool) -> AttestationRequestBody {
        let completedLines = draft.lines.filter { $0.isComplete }
        let linesBodies = completedLines.map { line in
            AttestationLineBody(
                label:  line.label,
                heures: line.heures.replacingOccurrences(of: ",", with: "."),
                taux:   line.taux.replacingOccurrences(of: ",", with: "."),
                total:  line.totalSendString
            )
        }
        let monthlyBodies = draft.monthlyRows.map { row in
            AttestationMonthRowBody(
                mois:    row.mois,
                heures:  row.heures.replacingOccurrences(of: ",", with: "."),
                montant: row.montant.replacingOccurrences(of: ",", with: ".")
            )
        }
        return AttestationRequestBody(
            clientId:      draft.clientId,
            year:          String(draft.year),
            ville:         draft.ville,
            dateStr:       draft.dateStr,
            emitter:       AttestationEmitterBody(
                company:    draft.emitterCompany,
                address:    draft.emitterAddress,
                postalCode: draft.emitterPostalCode,
                city:       draft.emitterCity,
                siret:      draft.emitterSiret,
                email:      draft.emitterEmail
            ),
            lines:         linesBodies,
            monthlyRows:   monthlyBodies,
            grandTotal:    AttestationDraft.sendString(draft.grandTotalDecimal),
            signatureData: includeSignature ? draft.signatureData : ""
        )
    }

    // MARK: - Generate PDF (POST /api/attestation/generate → Data)

    func generatePDF() async throws -> Data {
        generateState = .loading
        let body = buildBody(includeSignature: false)
        do {
            let data = try await APIClient.shared.postData(Endpoint.attestationGenerate, body: body)
            generateState = .idle
            return data
        } catch {
            let msg = (error as? APIError)?.userMessage ?? "Erreur lors de la génération."
            generateState = .error(msg)
            throw error
        }
    }

    // MARK: - Send (POST /api/attestation/send → AttestationSendResponse)

    func send() async throws -> String {
        // Filet de sécurité : le serveur refuse les ids préfixés agency_client_.
        guard !draft.clientId.hasPrefix("agency_client_") else {
            let msg = "Ce client ne peut pas recevoir d'attestation fiscale."
            sendState = .error(msg)
            throw APIError.server(statusCode: 400, message: msg)
        }
        // ⚠️ Le serveur trace une ligne vide sans erreur si le préfixe manque.
        guard draft.signatureData.hasPrefix("data:image/png;base64,") else {
            let msg = "Signature invalide. Veuillez signer à nouveau."
            sendState = .error(msg)
            throw APIError.server(statusCode: 400, message: msg)
        }
        sendState = .loading
        let body = buildBody(includeSignature: true)
        do {
            let resp: AttestationSendResponse = try await APIClient.shared.post(
                Endpoint.attestationSend, body: body
            )
            sendState = .idle
            return resp.message ?? "Attestation envoyée."
        } catch {
            let msg = (error as? APIError)?.userMessage ?? "Erreur lors de l'envoi."
            sendState = .error(msg)
            throw error
        }
    }
}
