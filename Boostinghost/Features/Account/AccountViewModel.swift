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

    var teamCount:               LoadedInt = .loading
    var platformsConnected:      LoadedInt = .loading
    var cleanersCount:           LoadedInt = .loading
    var templatesCount:          LoadedInt = .loading
    var managedPropertiesCount:  LoadedInt = .loading

    var notificationPrefs: NotificationPrefs? = nil

    // MARK: - Paiements

    var stripeStatus: StripeStatusResponse? = nil

    // MARK: - Accès ménage (sous-compte cleaner uniquement)

    var cleanerAccess: CleanerAccessInfo? = nil

    // MARK: - Load

    func load() async {
        async let subTask:       SubscriptionStatus       = APIClient.shared.get(Endpoint.subscriptionStatus)
        async let profileTask:   UserProfile              = APIClient.shared.get(Endpoint.userProfile)
        async let teamTask:      SubAccountsResponse      = APIClient.shared.get(Endpoint.subAccountsList, agencyAll: true)
        async let diffusionTask: DiffusionResponse        = APIClient.shared.get(Endpoint.propertiesDiffusion, agencyAll: true)
        async let cleanersTask:  CleanersListResponse     = APIClient.shared.get(Endpoint.cleaners, agencyAll: true)
        async let tplTask:       MessageTemplatesResponse = APIClient.shared.get(Endpoint.messageTemplates, agencyAll: true)
        async let propsTask:     PropertiesResponse       = APIClient.shared.get(Endpoint.properties, agencyAll: true)
        async let notifTask:     NotificationPrefs        = APIClient.shared.get(Endpoint.notificationSettings)
        async let cleanerTask:   CleanerAccessInfo        = APIClient.shared.get(Endpoint.cleaningMeAccess)
        async let stripeTask:    StripeStatusResponse     = APIClient.shared.get(Endpoint.stripeStatus)

        subscriptionStatus    = try? await subTask
        userProfile           = try? await profileTask
        notificationPrefs     = try? await notifTask
        cleanerAccess         = try? await cleanerTask
        stripeStatus          = try? await stripeTask

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

        if let r = try? await propsTask {
            managedPropertiesCount = .loaded(r.properties?.count ?? 0)
        } else {
            managedPropertiesCount = .failed
        }
    }

    // Refresh only the data that drives paymentsLabel — called when .setupShouldRefresh fires.
    func silentRefreshPayments() async {
        async let profileTask: UserProfile          = APIClient.shared.get(Endpoint.userProfile)
        async let stripeTask:  StripeStatusResponse = APIClient.shared.get(Endpoint.stripeStatus)
        if let p = try? await profileTask { userProfile = p }
        stripeStatus = try? await stripeTask
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

