import Foundation

// MARK: - Step identifiers

enum SetupStepID: String, CaseIterable, Codable {
    case property    = "property"
    case platforms   = "platforms"
    case messages    = "messages"
    case cleaning    = "cleaning"
    case team        = "team"
    case payments    = "payments"
    case welcomeBook = "welcomeBook"

    var title: String {
        switch self {
        case .property:    return "Créer un logement"
        case .platforms:   return "Connecter les plateformes"
        case .messages:    return "Messages automatiques"
        case .cleaning:    return "Configurer le ménage"
        case .team:        return "Inviter l'équipe"
        case .payments:    return "Configurer les paiements"
        case .welcomeBook: return "Compléter le livret"
        }
    }

    var description: String {
        switch self {
        case .property:    return "Ajoutez votre premier logement"
        case .platforms:   return "Reliez Airbnb, Booking.com ou autre"
        case .messages:    return "Automatisez l'accueil et le départ"
        case .cleaning:    return "Ajoutez un prestataire de ménage"
        case .team:        return "Donnez accès à vos collaborateurs"
        case .payments:    return "Activez la passerelle de paiement"
        case .welcomeBook: return "Accès, équipements et infos pratiques"
        }
    }

    var icon: String {
        switch self {
        case .property:    return "building.2"
        case .platforms:   return "link.circle"
        case .messages:    return "text.bubble"
        case .cleaning:    return "sparkles"
        case .team:        return "person.2"
        case .payments:    return "creditcard"
        case .welcomeBook: return "book"
        }
    }
}

// MARK: - Step state

enum SetupStepState: Equatable {
    case completed
    case pending
    case notApplicable
    case locked         // endpoint failed, state unknown
}

// MARK: - Step model

struct SetupStep: Identifiable {
    var id: SetupStepID { stepID }
    let stepID: SetupStepID
    var state: SetupStepState
    var detail: String? = nil
}

// MARK: - Onboarding status

enum OnboardingStatus: String, Codable, Equatable {
    case notStarted = "notStarted"
    case inProgress = "inProgress"
    case skipped    = "skipped"
    case completed  = "completed"

    // Monotone rank: notStarted(0) < inProgress(1) < skipped(2) < completed(3)
    // A status can never be downgraded to a lower rank.
    var rank: Int {
        switch self {
        case .notStarted: return 0
        case .inProgress: return 1
        case .skipped:    return 2
        case .completed:  return 3
        }
    }

    func merged(with other: OnboardingStatus) -> OnboardingStatus {
        rank >= other.rank ? self : other
    }
}

struct OnboardingPreferences: Codable, Equatable {
    var status:      OnboardingStatus
    var completedAt: String?           // ISO string or nil — not parsed client-side

    init(status: OnboardingStatus = .notStarted, completedAt: String? = nil) {
        self.status      = status
        self.completedAt = completedAt
    }

    init(from decoder: Decoder) throws {
        let c       = try decoder.container(keyedBy: CodingKeys.self)
        status      = (try? c.decodeIfPresent(OnboardingStatus.self, forKey: .status)) ?? .notStarted
        completedAt = try? c.decodeIfPresent(String.self, forKey: .completedAt)
    }

    private enum CodingKeys: CodingKey { case status, completedAt }
}

// MARK: - Onboarding flow step

enum OnboardingFlowStep: String, CaseIterable, Equatable {
    case property
    case platforms
    case messages
    case cleaning
    case team
    case payments
    case welcomeBook
}

/// Determines the next onboarding step to present.
/// - Parameters:
///   - steps: Current SetupViewModel steps (source of truth — never recalculated here).
///   - current: The step just completed; search starts after it. Pass nil to start from the beginning.
///   - deferred: Steps the user chose to defer in this session (not persisted).
/// - Returns: The next `pending` step not in `deferred`, or nil if none remain.
func nextRelevantStep(
    from steps: [SetupStep],
    after current: OnboardingFlowStep? = nil,
    deferring deferred: Set<OnboardingFlowStep> = []
) -> OnboardingFlowStep? {
    let order: [OnboardingFlowStep] = [
        .property, .platforms, .messages,
        .cleaning, .team, .payments, .welcomeBook
    ]
    let startIdx: Int = {
        guard let c = current, let i = order.firstIndex(of: c) else { return 0 }
        return i + 1
    }()
    guard startIdx < order.count else { return nil }
    for step in order[startIdx...] {
        if deferred.contains(step) { continue }
        let state = steps.first { $0.stepID.rawValue == step.rawValue }?.state
        switch state {
        case .pending:                              return step
        case .completed, .notApplicable, .locked:  continue
        case nil:                                  continue
        }
    }
    return nil
}

// MARK: - User preferences

struct UserPreferences: Codable {
    var setupCardDismissed:      Bool
    var setupStepsNotApplicable: [String]
    var onboarding:              OnboardingPreferences

    init(setupCardDismissed: Bool = false,
         setupStepsNotApplicable: [String] = [],
         onboarding: OnboardingPreferences = OnboardingPreferences()) {
        self.setupCardDismissed      = setupCardDismissed
        self.setupStepsNotApplicable = setupStepsNotApplicable
        self.onboarding              = onboarding
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        setupCardDismissed      = (try? c.decodeIfPresent(Bool.self,                  forKey: .setupCardDismissed))      ?? false
        setupStepsNotApplicable = (try? c.decodeIfPresent([String].self,              forKey: .setupStepsNotApplicable)) ?? []
        onboarding              = (try? c.decodeIfPresent(OnboardingPreferences.self, forKey: .onboarding))              ?? OnboardingPreferences()
    }

    // Custom encode: only include setup fields.
    // OnboardingCoordinator uses its own PUT body for onboarding updates —
    // this prevents SetupViewModel's preference saves from accidentally
    // sending an onboarding patch.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(setupCardDismissed,      forKey: .setupCardDismissed)
        try c.encode(setupStepsNotApplicable, forKey: .setupStepsNotApplicable)
    }

    private enum CodingKeys: CodingKey {
        case setupCardDismissed
        case setupStepsNotApplicable
        case onboarding
    }
}

struct UserPreferencesResponse: Decodable {
    let preferences: UserPreferences

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        preferences = (try? c.decodeIfPresent(UserPreferences.self, forKey: .preferences)) ?? UserPreferences()
    }

    private enum CodingKeys: CodingKey { case preferences }
}

// MARK: - Stripe status

struct StripeStatusResponse: Decodable {
    let connected:        Bool
    let canCharge:        Bool
    let chargesEnabled:   Bool?
    let payoutsEnabled:   Bool?
    let detailsSubmitted: Bool?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        connected        = (try? c.decodeIfPresent(Bool.self, forKey: .connected))        ?? false
        canCharge        = (try? c.decodeIfPresent(Bool.self, forKey: .canCharge))        ?? false
        chargesEnabled   = try? c.decodeIfPresent(Bool.self, forKey: .chargesEnabled)
        payoutsEnabled   = try? c.decodeIfPresent(Bool.self, forKey: .payoutsEnabled)
        detailsSubmitted = try? c.decodeIfPresent(Bool.self, forKey: .detailsSubmitted)
    }

    private enum CodingKeys: CodingKey {
        case connected, canCharge, chargesEnabled, payoutsEnabled, detailsSubmitted
    }
}

struct StripeOnboardingLinkResponse: Decodable {
    let url: String
}

// MARK: - Notifications

extension Notification.Name {
    static let setupShouldRefresh = Notification.Name("setupShouldRefresh")
    static let navigateToToday    = Notification.Name("navigateToToday")
}
