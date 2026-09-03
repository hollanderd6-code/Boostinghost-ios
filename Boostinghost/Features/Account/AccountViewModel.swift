import Foundation
import Observation

@Observable
@MainActor
final class AccountViewModel {

    // MARK: - Subscription

    var subscriptionStatus: SubscriptionStatus? = nil

    // MARK: - Counters (nil = still loading; loaded but failed stays nil and shows "—")

    var teamCount:          LoadedInt = .loading
    var platformsConnected: LoadedInt = .loading
    var cleanersCount:      LoadedInt = .loading
    var templatesCount:     LoadedInt = .loading

    // MARK: - Load

    func load() async {
        async let subTask:      SubscriptionStatus    = APIClient.shared.get(Endpoint.subscriptionStatus)
        async let teamTask:     SubAccountsResponse   = APIClient.shared.get(Endpoint.subAccountsList)
        async let propsTask:    PropertiesResponse    = APIClient.shared.get(Endpoint.properties)
        async let cleanersTask: CleanersListResponse  = APIClient.shared.get(Endpoint.cleaners)
        async let tplTask:      MessageTemplatesResponse  = APIClient.shared.get(Endpoint.messageTemplates)

        subscriptionStatus  = try? await subTask

        if let r = try? await teamTask {
            teamCount = .loaded(r.subAccounts.count)
        } else {
            teamCount = .failed
        }

        if let r = try? await propsTask {
            let n = (r.properties ?? []).filter { $0.hasActiveConnection }.count
            platformsConnected = .loaded(n)
        } else {
            platformsConnected = .failed
        }

        if let r = try? await cleanersTask {
            cleanersCount = .loaded(r.cleaners.count)
        } else {
            cleanersCount = .failed
        }

        if let r = try? await tplTask {
            templatesCount = .loaded(r.templates.count)
        } else {
            templatesCount = .failed
        }
    }
}

// MARK: - LoadedInt

enum LoadedInt: Equatable {
    case loading
    case loaded(Int)
    case failed

    var value: Int? {
        guard case .loaded(let n) = self else { return nil }
        return n
    }
}

// MARK: - Property helper

private extension Property {
    var hasActiveConnection: Bool {
        if channexEnabled == true { return true }
        if let raw = icalUrlsRaw, !raw.isEmpty, raw != "[]", raw != "null" { return true }
        return false
    }
}
