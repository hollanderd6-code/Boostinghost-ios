import Foundation
import Observation

@Observable
@MainActor
final class DiffusionViewModel {
    enum LoadState { case loading, loaded, failed }

    var loadState: LoadState = .loading
    var diffusion: DiffusionResponse?
    var santeByProperty: [String: [SantePoint]] = [:]

    func load() async {
        loadState = .loading
        do {
            let resp: DiffusionResponse = try await APIClient.shared.get(
                Endpoint.propertiesDiffusion, agencyAll: true
            )
            diffusion = resp
            for prop in resp.logements where prop.aRegler > 0 {
                let sante: SanteResponse? = try? await APIClient.shared.get(
                    Endpoint.sante(prop.id), agencyAll: true
                )
                santeByProperty[prop.id] = sante?.points.filter { !$0.ok } ?? []
            }
            loadState = .loaded
        } catch {
            loadState = .failed
        }
    }
}
