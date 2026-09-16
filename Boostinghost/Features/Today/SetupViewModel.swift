import Foundation

@Observable
@MainActor
final class SetupViewModel {

    // MARK: - State

    enum LoadState { case idle, loading, loaded }
    private(set) var loadState: LoadState = .idle

    private(set) var steps: [SetupStep] = SetupStepID.allCases.map {
        SetupStep(stepID: $0, state: .pending)
    }

    private(set) var preferences = UserPreferences()

    var isDismissed:           Bool { preferences.setupCardDismissed }
    var completionPercentage:  Int  { steps.filter { $0.state == .completed || $0.state == .notApplicable }.count * 100 / 7 }
    var hasPendingSteps:       Bool { steps.contains { $0.state == .pending || $0.state == .locked } }

    func reset() {
        loadState             = .idle
        steps                 = SetupStepID.allCases.map { SetupStep(stepID: $0, state: .pending) }
        preferences           = UserPreferences()
        cachedProperties      = nil
        cachedTemplates       = nil
        cachedCleaners        = nil
        cachedSubAccountCount = nil
        cachedUserProfile     = nil
        cachedStripeStatus    = nil
    }

    // MARK: - Cached data

    var properties: [Property]? { cachedProperties }

    private var cachedProperties:       [Property]?
    private var cachedTemplates:        [MessageTemplateItem]?
    private var cachedCleaners:         [CleanerItem]?
    private var cachedSubAccountCount:  Int?
    private var cachedUserProfile:      UserProfile?
    private var cachedStripeStatus:     StripeStatusResponse?

    private var isRefreshing = false

    // MARK: - Load

    func load() async {
        guard case .idle = loadState else { return }
        loadState = .loading
        await fetch()
        loadState = .loaded
    }

    func silentRefresh() async {
        guard case .loaded = loadState else { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await fetch()
    }

    private func fetch() async {
        async let propsTask    = fetchProperties()
        async let tplTask      = fetchTemplates()
        async let cleanTask    = fetchCleaners()
        async let subTask      = fetchSubAccountCount()
        async let profileTask  = fetchUserProfile()
        async let stripeTask   = fetchStripeStatus()
        async let prefsTask    = fetchPreferences()

        let (props, tpl, clnrs, subs, profile, stripe, prefs) = await (
            propsTask, tplTask, cleanTask, subTask,
            profileTask, stripeTask, prefsTask
        )

        if let v = props   { cachedProperties      = v }
        if let v = tpl     { cachedTemplates        = v }
        if let v = clnrs   { cachedCleaners         = v }
        if let v = subs    { cachedSubAccountCount  = v }
        if let v = profile { cachedUserProfile      = v }
        if let v = stripe  { cachedStripeStatus     = v }
        if let v = prefs   { preferences = v }

        computeSteps()
    }

    // MARK: - Step computation

    private func computeSteps() {
        let na = Set(preferences.setupStepsNotApplicable)
        steps = SetupStepID.allCases.map { id in
            if na.contains(id.rawValue) {
                return SetupStep(stepID: id, state: .notApplicable)
            }
            let state = stateFor(id)
            let detail = detailFor(id, state: state)
            return SetupStep(stepID: id, state: state, detail: detail)
        }
    }

    private func detailFor(_ id: SetupStepID, state: SetupStepState) -> String? {
        guard state == .pending, id == .platforms,
              let props = cachedProperties, !props.isEmpty else { return nil }
        let total = props.count
        let connected = props.filter {
            $0.channexEnabled == true || ($0.icalUrls?.isEmpty == false)
        }.count
        let suffix = total == 1 ? "logement connecté" : "logements connectés"
        return "\(connected) sur \(total) \(suffix)"
    }

    private func stateFor(_ id: SetupStepID) -> SetupStepState {
        switch id {

        case .property:
            guard let props = cachedProperties else { return .locked }
            return props.isEmpty ? .pending : .completed

        case .platforms:
            guard let props = cachedProperties else { return .locked }
            guard !props.isEmpty else { return .pending }
            let total     = props.count
            let connected = props.filter {
                $0.channexEnabled == true || ($0.icalUrls?.isEmpty == false)
            }.count
            return connected == total ? .completed : .pending

        case .messages:
            guard let tpl = cachedTemplates else { return .locked }
            return tpl.contains { $0.active } ? .completed : .pending

        case .cleaning:
            guard let clnrs = cachedCleaners else { return .locked }
            return clnrs.contains { $0.isActive } ? .completed : .pending

        case .team:
            guard let count = cachedSubAccountCount else { return .locked }
            return count > 0 ? .completed : .pending

        case .payments:
            guard let profile = cachedUserProfile else { return .locked }
            if profile.useBhStripe { return .completed }
            guard let stripe = cachedStripeStatus else { return .locked }
            return (stripe.connected && stripe.canCharge) ? .completed : .pending

        case .welcomeBook:
            guard let props = cachedProperties else { return .locked }
            return props.contains { $0.welcomeBookCompletionBlocks >= 1 } ? .completed : .pending
        }
    }

    // MARK: - Persistence

    func dismiss() async {
        preferences.setupCardDismissed = true
        computeSteps()
        await savePreferences()
    }

    func toggleNotApplicable(_ stepID: SetupStepID) async {
        guard stepID != .property else { return }
        if preferences.setupStepsNotApplicable.contains(stepID.rawValue) {
            preferences.setupStepsNotApplicable.removeAll { $0 == stepID.rawValue }
        } else {
            preferences.setupStepsNotApplicable.append(stepID.rawValue)
        }
        computeSteps()
        await savePreferences()
    }

    /// Marks a step as not applicable and persists to backend.
    /// Throws on network failure and rolls back the optimistic local update.
    func markNotApplicable(_ stepID: SetupStepID) async throws {
        guard stepID != .property else { return }
        guard !preferences.setupStepsNotApplicable.contains(stepID.rawValue) else { return }
        preferences.setupStepsNotApplicable.append(stepID.rawValue)
        computeSteps()
        #if DEBUG
        let markStart = Date()
        #endif
        do {
            struct Body: Encodable { let preferences: UserPreferences }
            try await APIClient.shared.putVoid(Endpoint.userPreferences, body: Body(preferences: preferences))
        } catch {
            preferences.setupStepsNotApplicable.removeAll { $0 == stepID.rawValue }
            computeSteps()
            #if DEBUG
            let elapsed = Date().timeIntervalSince(markStart)
            if let urlErr = (error as? APIError).flatMap({ if case .network(let e) = $0 { return e as? URLError } else { return nil } }) {
                print("[Setup] markNotApplicable PUT \(Endpoint.userPreferences.path) — URLError \(urlErr.code.rawValue) timeout=\(urlErr.code == .timedOut) elapsed=\(String(format: "%.2f", elapsed))s")
            } else if case .server(let code, let msg) = error as? APIError {
                print("[Setup] markNotApplicable PUT \(Endpoint.userPreferences.path) — HTTP \(code) \(msg ?? "") elapsed=\(String(format: "%.2f", elapsed))s")
            } else {
                print("[Setup] markNotApplicable PUT \(Endpoint.userPreferences.path) — \(error) elapsed=\(String(format: "%.2f", elapsed))s")
            }
            #endif
            throw error
        }
    }

    private func savePreferences() async {
        do {
            struct Body: Encodable { let preferences: UserPreferences }
            try await APIClient.shared.putVoid(Endpoint.userPreferences, body: Body(preferences: preferences))
        } catch {
            print("[Setup] savePreferences error: \(error)")
        }
    }

    // MARK: - Fetchers (agencyAll = false)

    private func fetchProperties() async -> [Property]? {
        do {
            let r: PropertiesResponse = try await APIClient.shared.get(Endpoint.properties)
            return r.properties ?? []
        } catch { print("[Setup] properties error: \(error)"); return nil }
    }

    private func fetchTemplates() async -> [MessageTemplateItem]? {
        do {
            let r: MessageTemplatesResponse = try await APIClient.shared.get(Endpoint.messageTemplates)
            return r.templates
        } catch { print("[Setup] templates error: \(error)"); return nil }
    }

    private func fetchCleaners() async -> [CleanerItem]? {
        do {
            let r: CleanersListResponse = try await APIClient.shared.get(Endpoint.cleaners, agencyAll: true)
            return r.cleaners
        } catch { print("[Setup] cleaners error: \(error)"); return nil }
    }

    private func fetchSubAccountCount() async -> Int? {
        do {
            let r: SubAccountsResponse = try await APIClient.shared.get(Endpoint.subAccountsList, agencyAll: true)
            return r.subAccounts.count
        } catch { print("[Setup] subAccounts error: \(error)"); return nil }
    }

    private func fetchUserProfile() async -> UserProfile? {
        do {
            return try await APIClient.shared.get(Endpoint.userProfile)
        } catch { print("[Setup] userProfile error: \(error)"); return nil }
    }

    private func fetchStripeStatus() async -> StripeStatusResponse? {
        do {
            return try await APIClient.shared.get(Endpoint.stripeStatus)
        } catch { print("[Setup] stripeStatus error: \(error)"); return nil }
    }

    private func fetchPreferences() async -> UserPreferences? {
        do {
            let r: UserPreferencesResponse = try await APIClient.shared.get(Endpoint.userPreferences)
            return r.preferences
        } catch { print("[Setup] preferences error: \(error)"); return nil }
    }
}
