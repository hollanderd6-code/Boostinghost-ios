import Foundation
import Observation

@Observable
@MainActor
final class ContractDetailViewModel {

    enum LoadState { case loading, loaded, error(String) }
    enum ResendState: Equatable {
        case idle
        case sending
        case done
        case error(String)
    }

    enum DeleteState: Equatable {
        case idle
        case deleting
        case error(String)
    }

    var loadState: LoadState = .loading
    var resendState: ResendState = .idle
    var deleteState: DeleteState = .idle
    var detail: ContractDetail? = nil

    let contractId: String

    init(contractId: String) {
        self.contractId = contractId
    }

    // MARK: - Chargement

    func load() async {
        loadState = .loading
        do {
            detail = try await APIClient.shared.get(Endpoint.contrat(contractId), agencyAll: true)
            loadState = .loaded
        } catch {
            loadState = .error((error as? APIError)?.userMessage ?? "Impossible de charger le contrat.")
        }
    }

    // MARK: - Renvoi du lien

    func resend() async throws {
        resendState = .sending
        do {
            let _: ContractResendResponse = try await APIClient.shared.post(
                Endpoint.contratResend(contractId),
                body: EmptyBody(),
                agencyAll: true
            )
            resendState = .done
        } catch {
            resendState = .error((error as? APIError)?.userMessage ?? "Erreur lors du renvoi.")
            throw error
        }
    }

    // MARK: - Suppression (DELETE /api/contrats/:id)

    func delete() async -> Bool {
        deleteState = .deleting
        do {
            try await APIClient.shared.delete(Endpoint.contrat(contractId), agencyAll: true)
            deleteState = .idle
            return true
        } catch let error as APIError {
            if case .server(409, _) = error {
                deleteState = .idle
                await load()
                return false
            }
            deleteState = .error(error.userMessage)
            return false
        } catch {
            deleteState = .error(error.localizedDescription)
            return false
        }
    }

    // MARK: - PDF (binaire, sans cache)

    func fetchPdf() async -> Data? {
        do {
            return try await APIClient.shared.getData(Endpoint.contratPdf(contractId), agencyAll: true)
        } catch {
            return nil
        }
    }

    // MARK: - Récapitulatifs (même logique que MandatViewModel)

    var commissionSummary: String {
        guard let d = detail?.contractData else { return "—" }
        switch d.remuType ?? "" {
        case "commission":
            let r = d.commissionRate ?? ""
            return r.isEmpty ? "—" : "\(r)\u{202F}%"
        case "forfait_mensuel":
            let f = d.forfaitMensuel ?? ""
            return f.isEmpty ? "—" : "\(f)\u{202F}€/mois"
        case "forfait_resa":
            let f = d.forfaitResa ?? ""
            return f.isEmpty ? "—" : "\(f)\u{202F}€/rés."
        case "mixte":
            let r = d.mixteRate ?? ""
            return r.isEmpty ? "—" : "\(r)\u{202F}% + forfait"
        case "carte":
            return "À la carte"
        default:
            return "—"
        }
    }

    var dureeSummary: String {
        guard let d = detail?.contractData else { return "—" }
        if (d.dureeType ?? "") == "determinee" {
            let m = d.dureeMois ?? ""
            return m.isEmpty ? "Déterminée" : "\(m)\u{202F}mois"
        }
        return "Indéterminée"
    }

    var preavisSummary: String {
        guard let d = detail?.contractData else { return "—" }
        let p = d.preavis ?? ""
        if p == "0" { return "Aucun" }
        return p.isEmpty ? "—" : "\(p)\u{202F}jours"
    }

    // MARK: - Récapitulatifs contrat de location

    var rentalPriceSummary: String {
        guard let p = detail?.contractData?.totalPrice, !p.isEmpty else { return "—" }
        return "\(p)\u{202F}€"
    }

    var rentalStaySummary: String {
        guard let ci = detail?.contractData?.checkin, !ci.isEmpty,
              let co = detail?.contractData?.checkout, !co.isEmpty else { return "—" }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        guard let d1 = fmt.date(from: ci), let d2 = fmt.date(from: co) else { return "—" }
        let nights = Calendar.current.dateComponents([.day], from: d1, to: d2).day ?? 0
        guard nights > 0 else { return "—" }
        return nights == 1 ? "1\u{202F}nuit" : "\(nights)\u{202F}nuits"
    }

    var rentalDepositSummary: String {
        guard let d = detail?.contractData?.deposit, !d.isEmpty else { return "—" }
        return "\(d)\u{202F}€"
    }
}
