import SwiftUI

// MARK: - Flow container

struct OnboardingFlowView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(SetupViewModel.self) private var setupVM
    private let coordinator = OnboardingCoordinator.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Tour is shown after "Commencer" and before the guided flow.
    // Only relevant when showWelcome was true (notStarted path).
    // Resumed inProgress flows skip directly to the guided flow.
    @State private var showingTour = false
    // Spinner on the tour's final CTA while setupVM is still loading.
    @State private var isAwaitingBegin = false

    var body: some View {
        ZStack {
            if coordinator.showWelcome && !showingTour {
                OnboardingWelcomeView(
                    onCommencer:    { handleCommencer() },
                    onDecouvrirApp: { coordinator.skip() }
                )
                .transition(pageTransition)
            } else if showingTour {
                AppTourView(
                    isAwaitingBegin: isAwaitingBegin,
                    onConfigure: { handleConfigureFromTour() },
                    onSkip: { coordinator.skip() }
                )
                .transition(pageTransition)
                .onChange(of: setupVM.loadState) { _, newState in
                    guard isAwaitingBegin, case .loaded = newState else { return }
                    isAwaitingBegin = false
                    coordinator.begin(setupSteps: setupVM.steps)
                    showingTour = false
                }
            } else {
                OnboardingGuidedFlowView()
                    .environment(authStore)
                    .environment(setupVM)
                    .transition(pageTransition)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: showingTour)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: coordinator.showWelcome)
    }

    // MARK: - Actions

    private func handleCommencer() {
        // Kick off load in background so it's ready by the time the user
        // reaches the "Configurer Boostinghost" CTA on the tour's last page.
        if case .idle = setupVM.loadState { Task { await setupVM.load() } }
        showingTour = true
    }

    private func handleConfigureFromTour() {
        if case .loaded = setupVM.loadState {
            // Batch both state changes so SwiftUI renders a single transition.
            coordinator.begin(setupSteps: setupVM.steps)
            showingTour = false
        } else {
            isAwaitingBegin = true
            if case .idle = setupVM.loadState { Task { await setupVM.load() } }
            // If .loading: onChange on loadState will trigger begin() when done.
        }
    }

    private var pageTransition: AnyTransition {
        reduceMotion ? .opacity :
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal:   .move(edge: .leading).combined(with: .opacity)
            )
    }
}

// MARK: - Level 1 — Welcome screen

struct OnboardingWelcomeView: View {
    var isLoading:      Bool = false
    let onCommencer:    () -> Void
    let onDecouvrirApp: () -> Void

    var body: some View {
        ZStack {
            AppBackground(expandedHalos: true)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Brand mark + wordmark
                VStack(spacing: 16) {
                    BrandMark(showBackground: true, size: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .shadow(
                            color: Color(hex: "#0E3B2E").opacity(0.25),
                            radius: 28, x: 0, y: 12
                        )

                    Text("BOOSTINGHOST")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(2.4)
                        .foregroundStyle(Color.bhAttenue)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Boostinghost")

                Spacer().frame(height: 40)

                // Main copy
                VStack(spacing: 14) {
                    Text("Bienvenue sur\nBoostinghost")
                        .font(.system(size: 36, weight: .bold))
                        .tracking(-1.15)
                        .foregroundStyle(Color.bhEncre)
                        .multilineTextAlignment(.center)

                    Text("Découvrez Boostinghost et prenez en main\nvotre activité en quelques instants.")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.bhAttenue)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 44)

                Spacer()

                // CTAs
                VStack(spacing: 20) {
                    Button(action: onCommencer) {
                        ZStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Commencer")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.bhVert.opacity(isLoading ? 0.65 : 1))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(isLoading)
                    .accessibilityLabel(isLoading ? "Chargement en cours" : "Commencer")

                    Button(action: onDecouvrirApp) {
                        Text("Accéder directement à l'app")
                            .font(.system(size: 15.5))
                            .foregroundStyle(Color.bhAttenue)
                    }
                    .padding(.bottom, 4)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 52)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview("Welcome") {
    OnboardingWelcomeView(onCommencer: {}, onDecouvrirApp: {})
}

#Preview("Welcome — loading") {
    OnboardingWelcomeView(isLoading: true, onCommencer: {}, onDecouvrirApp: {})
}
