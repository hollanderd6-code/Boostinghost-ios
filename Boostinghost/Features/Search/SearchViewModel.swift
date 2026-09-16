import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    enum State {
        case idle
        case searching
        case results(SearchResults)
        case empty
        case error(String)
    }

    var query: String = ""
    private(set) var state: State = .idle
    var agencyAll: Bool = false

    private var searchTask: Task<Void, Never>? = nil

    func onQueryChange() {
        searchTask?.cancel()
        searchTask = nil
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else {
            state = .idle
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await search(query: q)
        }
    }

    private func search(query: String) async {
        state = .searching
        do {
            let response: SearchResponse = try await APIClient.shared.get(
                Endpoint.search,
                agencyAll: true,
                extraQueryItems: [URLQueryItem(name: "q", value: query)]
            )
            guard !Task.isCancelled else { return }
            if let r = response.results, !r.isEmpty {
                state = .results(r)
            } else {
                state = .empty
            }
        } catch {
            guard !Task.isCancelled else { return }
            state = .error((error as? APIError)?.userMessage ?? error.localizedDescription)
        }
    }
}
