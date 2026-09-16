import Foundation

@Observable
@MainActor
final class HelpViewModel {

    enum LoadState { case idle, loading, loaded, error(String) }

    var loadState: LoadState = .idle
    var faq: [HelpFAQItem] = []
    var videos: [HelpVideo] = []
    var guides: [HelpGuide] = []

    func load() async {
        if case .loaded = loadState {} else { loadState = .loading }
        do {
            let resp: HelpContentResponse = try await APIClient.shared.get(Endpoint.helpContent)
            faq    = resp.faq.sorted    { ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0) }
            videos = resp.videos.sorted { ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0) }
            guides = resp.guides.sorted { ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0) }
            loadState = .loaded
        } catch APIError.unauthorized {
            loadState = .error("Session expirée.")
        } catch let e as APIError {
            loadState = .error(e.userMessage)
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }
}
