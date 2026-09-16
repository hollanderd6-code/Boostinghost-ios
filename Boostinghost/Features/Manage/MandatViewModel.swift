import Foundation
import Observation

@Observable
@MainActor
final class MandatViewModel {

    enum LoadState { case loading, ready, error(String) }
    enum SendState: Equatable {
        case idle
        case sending
        case error(String)
    }

    var loadState: LoadState = .loading
    var sendState: SendState = .idle
    var draft = MandatDraft()
    var currentStep: Int = 1
    // true quand GET /api/mandat/last retourne source non nil → bannière de pré-remplissage
    var hasPrefill: Bool = false

    let client: OwnerClient

    init(client: OwnerClient) {
        self.client = client
    }

    // MARK: - Navigation

    var isCurrentStepValid: Bool {
        switch currentStep {
        case 1:       return draft.isStep1Valid
        case 2, 3, 4: return true  // placeholders toujours valides
        case 5:       return true  // "Signer le mandat" toujours actif
        default:      return false
        }
    }

    func nextStep() { if currentStep < 5 { currentStep += 1 } }
    func prevStep()  { if currentStep > 1 { currentStep -= 1 } }

    // MARK: - Pré-remplissage

    func load() async {
        // Un client délégué (is_agency_client) ne peut pas recevoir de mandat.
        // Son id est préfixé "agency_client_" — le serveur l'écrit null si envoyé.
        // L'entrée vers cet écran doit déjà être bloquée par le call-site ; ce guard
        // est un filet de sécurité si cela n'a pas été fait.
        if client.isAgencyClient == true {
            loadState = .error("Les mandats ne peuvent être créés que pour vos propres clients.")
            return
        }

        loadState = .loading
        do {
            async let profileTask: UserProfile       = APIClient.shared.get(Endpoint.userProfile)
            async let lastTask: MandatLastResponse   = APIClient.shared.get(Endpoint.mandatLast)

            let profile = try await profileTask
            let last    = try await lastTask

            applyProfile(profile)
            applyClient()
            if let src = last.source {
                applySource(src)
                hasPrefill = true
            }
            loadState = .ready
        } catch {
            loadState = .error((error as? APIError)?.userMessage ?? "Impossible de charger les données.")
        }
    }

    private func applyProfile(_ p: UserProfile) {
        draft.companyName    = p.company ?? ""
        draft.companyEmail   = p.email
        draft.companySiret   = p.siret ?? ""
        let fn = p.firstName ?? ""; let ln = p.lastName ?? ""
        draft.companyRep     = [fn, ln].filter { !$0.isEmpty }.joined(separator: " ")
        draft.companyAddress = [p.address, p.postalCode, p.city]
            .compactMap { v in v.flatMap { $0.isEmpty ? nil : $0 } }
            .joined(separator: " ")
        draft.companyLogoUrl = p.logoUrl ?? ""
    }

    private func applyClient() {
        draft.ownerFirstName = client.firstName ?? ""
        draft.ownerLastName  = client.lastName  ?? ""
        draft.ownerEmail     = client.email     ?? ""
        draft.ownerAddress   = [client.address, client.postalCode, client.city]
            .compactMap { v in v.flatMap { $0.isEmpty ? nil : $0 } }
            .joined(separator: " ")
        draft.ownerPhone     = client.phone ?? ""
    }

    private func applySource(_ s: MandatSource) {
        if let v = s.remuType        { draft.remuType        = v }
        if let v = s.commissionRate  { draft.commissionRate  = v }
        if let v = s.commissionBase  { draft.commissionBase  = v }
        if let v = s.forfaitMensuel  { draft.forfaitMensuel  = v }
        if let v = s.forfaitResa     { draft.forfaitResa     = v }
        if let v = s.mixteRate       { draft.mixteRate       = v }
        if let v = s.mixteForfait    { draft.mixteForfait    = v }
        if let v = s.tva             { draft.tva             = v }
        if let v = s.tarifPreavis    { draft.tarifPreavis    = v }
        if let v = s.reversement     { draft.reversement     = v }
        if let v = s.dureeType       { draft.dureeType       = v }
        if let v = s.dateDebut       { draft.dateDebut       = v }
        if let v = s.dureeMois       { draft.dureeMois       = v }
        if let v = s.renouvellement  { draft.renouvellement  = v }
        if let v = s.preavis         { draft.preavis         = v }
        if let v = s.exclusivite     { draft.exclusivite     = v }
        if let v = s.respPlafond     { draft.respPlafond     = v }
        if let v = s.juridiction     { draft.juridiction     = v }
        if let v = s.confidentialite { draft.confidentialite = v }
    }

    func resetPrefill() {
        draft.remuType        = ""
        draft.commissionRate  = ""
        draft.commissionBase  = "ht"
        draft.forfaitMensuel  = ""
        draft.forfaitResa     = ""
        draft.mixteRate       = ""
        draft.mixteForfait    = ""
        draft.tva             = "franchise"
        draft.tarifPreavis    = "60"
        draft.reversement     = "mensuel"
        draft.dureeType       = "indeterminee"
        draft.dateDebut       = ""
        draft.dureeMois       = ""
        draft.renouvellement  = "tacite"
        draft.preavis         = "30"
        draft.exclusivite     = "non"
        draft.respPlafond     = "oui"
        draft.juridiction     = "lieu_bien"
        draft.confidentialite = "5"
        hasPrefill = false
    }

    // MARK: - Envoi

    func send() async throws {
        // Filet de sécurité : le serveur écrit null pour tout id préfixé "agency_client_".
        guard !client.id.hasPrefix("agency_client_") else {
            let msg = "Ce client ne peut pas recevoir de mandat (client délégué)."
            sendState = .error(msg)
            throw APIError.server(statusCode: 400, message: msg)
        }

        sendState = .sending
        draft.signatureDate = ISO8601DateFormatter().string(from: Date())
        let body = MandatSendBody(draft: draft, clientId: client.id)
        do {
            let _: MandatSendResponse = try await APIClient.shared.post(Endpoint.sendMandat, body: body)
            sendState = .idle
        } catch {
            sendState = .error((error as? APIError)?.userMessage ?? "Erreur réseau.")
            throw error
        }
    }

    // MARK: - Récapitulatif étape 5

    var commissionSummary: String {
        switch draft.remuType {
        case "commission":
            let r = draft.commissionRate
            return r.isEmpty ? "—" : "\(r)\u{202F}%"
        case "forfait_mensuel":
            let f = draft.forfaitMensuel
            return f.isEmpty ? "—" : "\(f)\u{202F}€/mois"
        case "forfait_resa":
            let f = draft.forfaitResa
            return f.isEmpty ? "—" : "\(f)\u{202F}€/rés."
        case "mixte":
            let r = draft.mixteRate
            return r.isEmpty ? "—" : "\(r)\u{202F}% + forfait"
        case "carte":
            return "À la carte"
        default:
            return "—"
        }
    }

    var dureeSummary: String {
        if draft.dureeType == "determinee" {
            let m = draft.dureeMois
            return m.isEmpty ? "Déterminée" : "\(m) mois"
        }
        return "Indéterminée"
    }

    var preavisSummary: String {
        if draft.preavis == "0" { return "Aucun" }
        return draft.preavis.isEmpty ? "—" : "\(draft.preavis) jours"
    }
}
