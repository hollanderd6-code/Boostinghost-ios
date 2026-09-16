import Foundation
import Observation

// MARK: - OnboardingCoordinator
//
// Singleton @Observable responsible for the 4-level intelligent onboarding flow.
//
// Level 1 — First Launch (this file): one welcome screen, presented once.
// Level 2 — Guided business flow (Phase 5.3): conditional step-by-step screens.
// Level 3 — SetupCard on Today (existing, unchanged).
// Level 4 — Contextual tips (Phase 5.5, TipCoordinator).
//
// Ownership rules:
// • Does NOT fetch properties / messages / cleaners — that is SetupViewModel's job.
// • Does NOT recalculate SetupStepState — reads SetupViewModel.steps as-is.
// • Does NOT know the content of any business form.

@Observable
@MainActor
final class OnboardingCoordinator {

    static let shared = OnboardingCoordinator()

    // MARK: - Public display state

    /// Whether the fullScreenCover should be visible.
    /// Guarded by `hasLoaded` in RootView to prevent flash for existing accounts.
    private(set) var isShowingOnboarding = false

    /// True once the initial state has been resolved (local or server).
    private(set) var hasLoaded = false

    /// True when the welcome screen should show (Level 1).
    /// False when the user should land directly on the guided flow (Level 2).
    private(set) var showWelcome = true

    // MARK: - Flow machine state

    /// Current step in the guided flow. nil = no pending step (or flow not started).
    private(set) var currentStep: OnboardingFlowStep? = nil

    /// Steps the user deferred in this session ("Plus tard").
    /// NOT persisted to backend — resets on manual replay.
    private(set) var deferredSteps: Set<OnboardingFlowStep> = []

    /// True when launched manually from Aide (does not write status on completion).
    private(set) var isManualReplay = false

    /// True when opened at a specific step from SetupCard (Phase 5.4).
    /// Targeted mode: no auto-advance, no next step, just close after one action.
    private(set) var isTargetedFlow = false

    /// Total number of pending steps at the start of the current flow run.
    private(set) var flowTotalSteps: Int = 0
    /// 1-based index of the step currently shown (incremented on each advance/defer).
    private(set) var flowCurrentIndex: Int = 0

    // MARK: - Private state

    private var scopedUserId: String = ""
    private var isLoading = false

    private init() {}

    // MARK: - Load

    /// Call when authStore.appState transitions to .authenticated.
    /// Resolves onboarding status from local UserDefaults first (instant),
    /// then reconciles with the server in the background.
    func load(session: Session) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        guard !session.isSubAccount else {
            hasLoaded = true
            return
        }

        scopedUserId = Self.userIdFromJWT(session.token) ?? String(session.token.prefix(24))

        // Pending sync retry before server fetch
        if UserDefaults.standard.bool(forKey: pendingSyncKey()) {
            await trySyncToServer()
        }

        let localRaw = UserDefaults.standard.string(forKey: statusKey())

        if let localRaw, let localStatus = OnboardingStatus(rawValue: localRaw) {
            // We have a local status — apply immediately to avoid any UI delay.
            applyResolvedStatus(localStatus)
            hasLoaded = true

            // Reconcile with server in the background (monotone merge).
            Task {
                guard let serverStatus = await fetchServerStatus() else { return }
                let merged = localStatus.merged(with: serverStatus)
                if merged != localStatus {
                    saveLocalStatus(merged)
                    if merged == .completed || merged == .skipped {
                        isShowingOnboarding = false
                    }
                }
            }
        } else {
            // No local state (first install / fresh device) — must wait for server
            // to avoid showing the flow to existing accounts on a new device.
            if let serverStatus = await fetchServerStatus() {
                saveLocalStatus(serverStatus)
                applyResolvedStatus(serverStatus)
            } else {
                // Server unreachable on first install — show nothing until we know.
                // The user can retry by relaunching the app.
                isShowingOnboarding = false
            }
            hasLoaded = true
        }
    }

    // MARK: - User actions

    /// "Commencer" — enter the guided flow with real setup steps.
    func begin(setupSteps: [SetupStep]) {
        isTargetedFlow = false
        deferredSteps = []
        let first = nextRelevantStep(from: setupSteps, deferring: deferredSteps)
        currentStep = first
        flowTotalSteps  = countPendingSteps(from: setupSteps)
        flowCurrentIndex = first != nil ? 1 : 0
        showWelcome = false
        guard !isManualReplay else { return }
        saveLocalStatus(.inProgress)
        Task { await persistOnboarding(.inProgress, completedAt: nil) }
    }

    /// "Découvrir l'app" — skip the entire flow without going through it.
    func skip() {
        isShowingOnboarding = false
        guard !isManualReplay else { return }
        saveLocalStatus(.skipped)
        Task { await persistOnboarding(.skipped, completedAt: nil) }
    }

    /// "Continuer plus tard" from the guided flow — status stays inProgress.
    /// The user will resume from the flow screen (not the welcome screen) next launch.
    func deferAll() {
        isShowingOnboarding = false
        // Status is already inProgress (set by begin()); no backend write needed.
    }

    /// Advance to the next relevant step after an action on `step`.
    /// Pass the current SetupViewModel.steps (already refreshed).
    /// When no next step exists, currentStep becomes nil → completion screen is shown.
    /// The caller (completion view) must then call finishFlow().
    func advance(from step: OnboardingFlowStep, setupSteps: [SetupStep]) {
        let next = nextRelevantStep(from: setupSteps, after: step, deferring: deferredSteps)
        currentStep = next
        if next != nil { flowCurrentIndex += 1 }
    }

    /// "Plus tard" on a specific step — defer it for this session, then advance.
    func defer_(step: OnboardingFlowStep, setupSteps: [SetupStep]) {
        deferredSteps.insert(step)
        let next = nextRelevantStep(from: setupSteps, after: step, deferring: deferredSteps)
        currentStep = next
        if next != nil { flowCurrentIndex += 1 }
    }

    /// Called by the completion screen's CTA ("Accéder à Boostinghost").
    /// Closes the cover and persists completed status (unless manual replay).
    func finishFlow() {
        isShowingOnboarding = false
        guard !isManualReplay else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        saveLocalStatus(.completed)
        Task { await persistOnboarding(.completed, completedAt: now) }
    }

    /// Manual replay from HelpView — resets deferred, does not update persistent status.
    func startManually(setupSteps: [SetupStep]) {
        isTargetedFlow = false
        isManualReplay = true
        deferredSteps = []
        let first = nextRelevantStep(from: setupSteps, deferring: [])
        currentStep = first
        flowTotalSteps   = countPendingSteps(from: setupSteps)
        flowCurrentIndex = first != nil ? 1 : 0
        showWelcome = false
        isShowingOnboarding = true
    }

    /// Opens directly at a specific step (Phase 5.4 — SetupCard tap).
    /// isManual = true suppresses all onboarding.status persistence.
    /// Targeted mode: one step only — no auto-advance, close after any action.
    func start(at step: OnboardingFlowStep, isManual: Bool = true) {
        isManualReplay   = isManual
        isTargetedFlow   = true
        deferredSteps    = []
        currentStep      = step
        flowTotalSteps   = 1
        flowCurrentIndex = 1
        showWelcome      = false
        isShowingOnboarding = true
    }

    // MARK: - Reset (logout / account switch)

    func reset() {
        isShowingOnboarding  = false
        hasLoaded            = false
        showWelcome          = true
        currentStep          = nil
        deferredSteps        = []
        isManualReplay       = false
        isTargetedFlow       = false
        flowTotalSteps       = 0
        flowCurrentIndex     = 0
        scopedUserId         = ""
    }

    // MARK: - DEBUG

#if DEBUG
    /// Forces the onboarding welcome screen without touching UserDefaults or the backend.
    /// isManualReplay = true suppresses all persistence throughout the flow.
    func previewFirstLaunch() {
        showWelcome         = true
        isManualReplay      = true
        isTargetedFlow      = false
        isShowingOnboarding = true
        hasLoaded           = true
        deferredSteps       = []
        currentStep         = nil
        flowTotalSteps      = 0
        flowCurrentIndex    = 0
    }
#endif

    // MARK: - Private — state helpers

    private func applyResolvedStatus(_ status: OnboardingStatus) {
        switch status {
        case .notStarted:
            showWelcome = true
            isShowingOnboarding = true
        case .inProgress:
            showWelcome = false
            isShowingOnboarding = true
        case .skipped, .completed:
            isShowingOnboarding = false
        }
    }

    private func countPendingSteps(from steps: [SetupStep]) -> Int {
        OnboardingFlowStep.allCases.filter { flow in
            steps.first { $0.stepID.rawValue == flow.rawValue }?.state == .pending
        }.count
    }

    // MARK: - Private — UserDefaults (account-scoped)

    private func statusKey()      -> String { "bh.onboarding.\(scopedUserId).status" }
    private func pendingSyncKey() -> String { "bh.onboarding.\(scopedUserId).pendingSync" }

    private func saveLocalStatus(_ status: OnboardingStatus) {
        guard !scopedUserId.isEmpty else { return }
        UserDefaults.standard.set(status.rawValue, forKey: statusKey())
    }

    // MARK: - Private — network

    private func fetchServerStatus() async -> OnboardingStatus? {
        do {
            let r: UserPreferencesResponse = try await APIClient.shared.get(Endpoint.userPreferences)
            return r.preferences.onboarding.status
        } catch {
            print("[Onboarding] preferences fetch failed: \(error)")
            return nil
        }
    }

    private func persistOnboarding(_ status: OnboardingStatus, completedAt: String?) async {
        guard !scopedUserId.isEmpty else { return }
        struct OnboardingUpdate: Encodable {
            let status: String
            let completedAt: String?
        }
        struct PreferencesWrapper: Encodable { let onboarding: OnboardingUpdate }
        struct Body: Encodable { let preferences: PreferencesWrapper }
        let body = Body(preferences: PreferencesWrapper(
            onboarding: OnboardingUpdate(status: status.rawValue, completedAt: completedAt)
        ))
        do {
            try await APIClient.shared.putVoid(Endpoint.userPreferences, body: body)
            UserDefaults.standard.set(false, forKey: pendingSyncKey())
        } catch {
            UserDefaults.standard.set(true, forKey: pendingSyncKey())
            print("[Onboarding] sync failed, queued for retry: \(error)")
        }
    }

    private func trySyncToServer() async {
        let localRaw = UserDefaults.standard.string(forKey: statusKey())
        guard let status = localRaw.flatMap(OnboardingStatus.init(rawValue:)) else { return }
        await persistOnboarding(status, completedAt: nil)
    }

    // MARK: - Private — JWT sub extraction

    /// Extracts the `sub` claim from a JWT without verifying the signature.
    /// Used only to generate a stable, non-sensitive UserDefaults key per account.
    static func userIdFromJWT(_ token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = (4 - b64.count % 4) % 4
        if pad > 0 { b64 += String(repeating: "=", count: pad) }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub  = json["sub"] as? String else { return nil }
        return sub
    }
}
