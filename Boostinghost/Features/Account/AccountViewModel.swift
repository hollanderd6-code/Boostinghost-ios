import Foundation
import Observation

@Observable
@MainActor
final class AccountViewModel {

    // MARK: - Subscription

    var subscriptionStatus: SubscriptionStatus? = nil

    // MARK: - Profile

    var userProfile: UserProfile? = nil

    // MARK: - Counters (nil = still loading; loaded but failed stays nil and shows "—")

    var teamCount:          LoadedInt = .loading
    var platformsConnected: LoadedInt = .loading
    var cleanersCount:      LoadedInt = .loading
    var templatesCount:     LoadedInt = .loading

    // MARK: - Load

    func load() async {
        // DEBUG — à retirer après diagnostic de la réponse subscription
        await debugPrintSubscriptionRaw()

        async let subTask:       SubscriptionStatus       = APIClient.shared.get(Endpoint.subscriptionStatus)
        async let profileTask:   UserProfile              = APIClient.shared.get(Endpoint.userProfile)
        async let teamTask:      SubAccountsResponse      = APIClient.shared.get(Endpoint.subAccountsList, agencyAll: true)
        async let diffusionTask: DiffusionResponse        = APIClient.shared.get(Endpoint.propertiesDiffusion, agencyAll: true)
        async let cleanersTask:  CleanersListResponse     = APIClient.shared.get(Endpoint.cleaners, agencyAll: true)
        async let tplTask:       MessageTemplatesResponse = APIClient.shared.get(Endpoint.messageTemplates, agencyAll: true)

        subscriptionStatus = try? await subTask
        userProfile        = try? await profileTask

        if let r = try? await teamTask {
            teamCount = .loaded(r.subAccounts.count)
        } else {
            teamCount = .failed
        }

        if let r = try? await diffusionTask {
            platformsConnected = .loaded(r.diffuses)
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

    // MARK: - Debug (supprimer après diagnostic)

    private func debugPrintSubscriptionRaw() async {
        guard let token = await APIClient.shared.token else {
            print("[DEBUG-SUB] pas de token")
            return
        }
        var req = URLRequest(url: Endpoint.subscriptionStatus)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req) else {
            print("[DEBUG-SUB] réseau KO")
            return
        }
        let raw = String(data: data, encoding: .utf8) ?? "(non-UTF8)"
        print("[DEBUG-SUB] JSON brut /api/subscription/status :\n\(raw)")
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

