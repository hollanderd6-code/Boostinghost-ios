import SwiftUI

// MARK: - Guided flow container

@MainActor
struct OnboardingGuidedFlowView: View {
    @Environment(SetupViewModel.self) private var setupVM
    @Environment(AuthStore.self) private var authStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let coordinator = OnboardingCoordinator.shared

    // Sheet state (all managed here to avoid nested sheet conflicts)
    @State private var accountDest:         AccountDestination? = nil
    @State private var showNewPropSheet     = false
    @State private var showPicker           = false
    @State private var pickerProps:         [Property] = []
    @State private var pickerTitle          = ""
    @State private var pendingAfterPicker:  AccountDestination? = nil

    // Return tracking
    @State private var returnStep:          OnboardingFlowStep? = nil
    @State private var propertyCreated      = false

    // NA state
    @State private var isProcessingNA       = false
    @State private var naError:             String? = nil

    // MARK: - Body

    var body: some View {
        ZStack {
            if coordinator.currentStep == nil {
                completionScreen
                    .transition(transition(for: .completion))
            } else if let step = coordinator.currentStep {
                stepBody(for: step)
                    .transition(transition(for: .step))
                    .id(step)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: coordinator.currentStep)
        // AccountSheet — covers messages, cleaning, team, payments, platforms
        .sheet(item: $accountDest, onDismiss: handleAccountDismiss) { dest in
            AccountSheet(initialDestination: dest)
                .environment(authStore)
                .environment(setupVM)
        }
        // NewPropertySheet — property step
        .sheet(isPresented: $showNewPropSheet, onDismiss: handleNewPropertyDismiss) {
            NewPropertySheet { propertyCreated = true }
        }
        // PropertyPickerSheet — platforms (multi) ; opens AccountSheet after dismiss
        .sheet(isPresented: $showPicker, onDismiss: handlePickerDismiss) {
            PropertyPickerSheet(title: pickerTitle, properties: pickerProps) { _ in
                pendingAfterPicker = .diffusion
            }
        }
        // NA error banner
        .overlay(alignment: .bottom) {
            if let error = naError {
                naErrorBanner(error)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 26)
                    .padding(.bottom, 48)
                    .onTapGesture { withAnimation { naError = nil } }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Erreur : \(error). Toucher pour ignorer.")
            }
        }
        .animation(.easeInOut(duration: 0.22), value: naError != nil)
    }

    // MARK: - Step routing

    @ViewBuilder
    private func stepBody(for step: OnboardingFlowStep) -> some View {
        let idx   = coordinator.flowCurrentIndex
        let total = max(coordinator.flowTotalSteps, 1)

        switch step {
        case .property:
            OnboardingStepShell(
                icon: "house.fill", step: idx, total: total,
                title: "Commençons par votre logement",
                subtitle: "Ajoutez votre premier logement pour commencer à gérer vos réservations."
            ) {
                stepActions {
                    OnboardingPrimaryButton(title: "Ajouter un logement") {
                        showNewPropSheet = true
                    }
                    OnboardingDeferButton { deferCurrentStep(.property) }
                }
            }

        case .platforms:
            let detail = setupVM.steps.first { $0.stepID == .platforms }?.detail
            OnboardingStepShell(
                icon: "antenna.radiowaves.left.and.right", step: idx, total: total,
                title: "Connectez vos plateformes",
                subtitle: detail ?? "Synchronisez Airbnb, Booking.com ou vos calendriers iCal."
            ) {
                stepActions {
                    OnboardingPrimaryButton(title: "Configurer maintenant") {
                        openPlatforms()
                    }
                    OnboardingOutlineButton(title: "Je n'utilise pas de plateformes") {
                        Task { await markNA(.platforms) }
                    }
                    .disabled(isProcessingNA)
                    OnboardingDeferButton { deferCurrentStep(.platforms) }
                }
            }

        case .messages:
            OnboardingStepShell(
                icon: "envelope.fill", step: idx, total: total,
                title: "Automatisez vos messages voyageurs",
                subtitle: "Envoyez automatiquement les bonnes informations avant, pendant et après le séjour."
            ) {
                stepActions {
                    OnboardingPrimaryButton(title: "Configurer mes messages") {
                        openAccount(.messageTemplates, for: .messages)
                    }
                    OnboardingOutlineButton(title: "Je n'en ai pas besoin") {
                        Task { await markNA(.messages) }
                    }
                    .disabled(isProcessingNA)
                    OnboardingDeferButton { deferCurrentStep(.messages) }
                }
            }

        case .cleaning:
            OnboardingStepShell(
                icon: "bubbles.and.sparkles.fill", step: idx, total: total,
                title: "Qui s'occupe du ménage ?",
                subtitle: "Boostinghost peut organiser et assigner automatiquement les interventions."
            ) {
                VStack(spacing: 12) {
                    OnboardingChoiceCard(
                        icon: "person.2.fill",
                        title: "Une équipe ou un prestataire",
                        action: { openAccount(.cleaners, for: .cleaning) }
                    )
                    OnboardingChoiceCard(
                        icon: "person.fill.checkmark",
                        title: "Je m'en occupe moi-même",
                        action: { Task { await markNA(.cleaning) } }
                    )
                    .disabled(isProcessingNA)
                    OnboardingDeferButton { deferCurrentStep(.cleaning) }
                        .padding(.top, 6)
                }
            }

        case .team:
            OnboardingStepShell(
                icon: "person.3.fill", step: idx, total: total,
                title: "Travaillez-vous en équipe ?",
                subtitle: "Invitez vos collaborateurs et définissez leurs accès."
            ) {
                VStack(spacing: 12) {
                    OnboardingChoiceCard(
                        icon: "person.badge.plus",
                        title: "Oui, inviter mon équipe",
                        action: { openAccount(.team, for: .team) }
                    )
                    OnboardingChoiceCard(
                        icon: "person.fill",
                        title: "Non, je travaille seul",
                        action: { Task { await markNA(.team) } }
                    )
                    .disabled(isProcessingNA)
                    OnboardingDeferButton { deferCurrentStep(.team) }
                        .padding(.top, 6)
                }
            }

        case .payments:
            OnboardingStepShell(
                icon: "creditcard.fill", step: idx, total: total,
                title: "Gérez vos paiements et cautions",
                subtitle: "Configurez vos paiements pour encaisser simplement et sécuriser vos réservations."
            ) {
                stepActions {
                    OnboardingPrimaryButton(title: "Configurer les paiements") {
                        openAccount(.payments, for: .payments)
                    }
                    OnboardingDeferButton { deferCurrentStep(.payments) }
                }
            }

        case .welcomeBook:
            let propCount = setupVM.properties?.count ?? 0
            OnboardingStepShell(
                icon: "book.fill", step: idx, total: total,
                title: "Préparez l'arrivée de vos voyageurs",
                subtitle: "Centralisez l'accès, le Wi-Fi, les équipements, les règles et les informations pratiques."
            ) {
                stepActions {
                    OnboardingPrimaryButton(
                        title: propCount > 1 ? "Choisir un logement" : "Compléter le livret"
                    ) {
                        openWelcomeBook()
                    }
                    OnboardingDeferButton { deferCurrentStep(.welcomeBook) }
                }
            }
        }
    }

    // MARK: - Completion screen

    private var completionScreen: some View {
        ZStack {
            AppBackground(expandedHalos: true)
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.bhMentheFond)
                            .frame(width: 64, height: 64)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(Color.bhVert)
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: 12) {
                        Text("Vous êtes prêt")
                            .font(.system(size: 30, weight: .bold))
                            .tracking(-0.9)
                            .foregroundStyle(Color.bhEncre)

                        Text("Vous pourrez compléter le reste\nà tout moment depuis Aujourd'hui.")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.bhAttenue)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, 30)
                }

                Spacer()

                OnboardingPrimaryButton(title: "Accéder à Boostinghost") {
                    coordinator.finishFlow()
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 52)
                .accessibilityAddTraits(.isButton)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - NA error banner

    private func naErrorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14))
                .accessibilityHidden(true)
            Text(message)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.bhTerracotta, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Action helpers

    private func openAccount(_ dest: AccountDestination, for step: OnboardingFlowStep) {
        returnStep  = step
        accountDest = dest
    }

    private func openPlatforms() {
        let props = setupVM.properties ?? []
        if props.count > 1 {
            pickerTitle = "Choisir un logement"
            pickerProps = props
            returnStep  = .platforms
            showPicker  = true
        } else {
            openAccount(.diffusion, for: .platforms)
        }
    }

    private func openWelcomeBook() {
        coordinator.deferAll()
        NotificationRouter.shared.pendingTab = .manage
    }

    private func deferCurrentStep(_ step: OnboardingFlowStep) {
        // Targeted flow (SetupCard tap): just close, no sequence to advance.
        if coordinator.isTargetedFlow {
            coordinator.deferAll()
        } else {
            coordinator.defer_(step: step, setupSteps: setupVM.steps)
        }
    }

    private func markNA(_ step: OnboardingFlowStep) async {
        guard !isProcessingNA else { return }
        isProcessingNA = true
        defer { isProcessingNA = false }
        withAnimation { naError = nil }
        guard let stepID = SetupStepID(rawValue: step.rawValue) else { return }
        do {
            try await setupVM.markNotApplicable(stepID)
            // isManualReplay only blocks onboarding.status persistence —
            // markNotApplicable always persists the actual business preference.
            if coordinator.isTargetedFlow {
                coordinator.deferAll()  // persisted → refresh card → close
            } else {
                coordinator.advance(from: step, setupSteps: setupVM.steps)
            }
        } catch {
            withAnimation { naError = "La mise à jour a échoué. Vérifiez votre connexion." }
        }
    }

    private func handleReturn(from step: OnboardingFlowStep) async {
        await setupVM.silentRefresh()
        // Targeted flow: always close after one action, regardless of step state.
        if coordinator.isTargetedFlow {
            coordinator.deferAll()
            return
        }
        let state = setupVM.steps.first { $0.stepID.rawValue == step.rawValue }?.state
        switch state {
        case .completed, .notApplicable:
            coordinator.advance(from: step, setupSteps: setupVM.steps)
        default:
            coordinator.defer_(step: step, setupSteps: setupVM.steps)
        }
    }

    // MARK: - Sheet dismiss handlers

    private func handleAccountDismiss() {
        guard let step = returnStep else { return }
        returnStep = nil
        Task { await handleReturn(from: step) }
    }

    private func handleNewPropertyDismiss() {
        let created = propertyCreated
        propertyCreated = false
        guard created else { return }
        Task {
            NotificationCenter.default.post(name: .setupShouldRefresh, object: nil)
            await setupVM.silentRefresh()
            coordinator.advance(from: .property, setupSteps: setupVM.steps)
        }
    }

    private func handlePickerDismiss() {
        guard let dest = pendingAfterPicker else { return }
        pendingAfterPicker = nil
        DispatchQueue.main.async {
            self.accountDest = dest
        }
    }

    // MARK: - Transition

    private enum TransitionRole { case step, completion }

    private func transition(for role: TransitionRole) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        switch role {
        case .step:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal:   .move(edge: .leading).combined(with: .opacity)
            )
        case .completion:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal:   .opacity
            )
        }
    }
}

// MARK: - Step shell

private struct OnboardingStepShell<Content: View>: View {
    let icon:     String
    let step:     Int
    let total:    Int
    let title:    String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Progress indicator
                    HStack {
                        Text("Étape \(step) sur \(total)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.bhAttenue)
                        Spacer()
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, 24)
                    .accessibilityLabel("Étape \(step) sur \(total)")

                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.bhMentheFond)
                            .frame(width: 64, height: 64)
                        Image(systemName: icon)
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(Color.bhVert)
                    }
                    .accessibilityHidden(true)
                    .padding(.top, 36)

                    // Title + subtitle
                    VStack(spacing: 10) {
                        Text(title)
                            .font(.system(size: 26, weight: .bold))
                            .tracking(-0.75)
                            .foregroundStyle(Color.bhEncre)
                            .multilineTextAlignment(.center)
                        Text(subtitle)
                            .font(.system(size: 15.5))
                            .foregroundStyle(Color.bhAttenue)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 22)

                    // Step-specific actions
                    content()
                        .padding(.top, 36)
                        .padding(.horizontal, 26)
                        .padding(.bottom, 52)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Reusable action container (standard steps)

private struct stepActions<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(spacing: 14) {
            content()
        }
    }
}

// MARK: - Choice card (cleaning / team binary choice)

private struct OnboardingChoiceCard: View {
    let icon:   String
    let title:  String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.bhMentheFond)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.bhVert)
                }
                Text(title)
                    .font(.system(size: 15.5, weight: .medium))
                    .foregroundStyle(Color.bhEncre)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.bhAttenue.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .frame(minHeight: 44)
    }
}

// MARK: - Buttons

struct OnboardingPrimaryButton: View {
    let title:  String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.bhVert, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }
}

private struct OnboardingOutlineButton: View {
    let title:  String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.bhAttenue)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.bhAttenue.opacity(0.28), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }
}

private struct OnboardingDeferButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Plus tard")
                .font(.system(size: 15))
                .foregroundStyle(Color.bhAttenue)
        }
        .frame(minHeight: 44)
        .accessibilityLabel("Ignorer cette étape pour l'instant")
    }
}

#Preview("Guided — property") {
    let setupVM = SetupViewModel()
    OnboardingGuidedFlowView()
        .environment(setupVM)
        .environment(AuthStore())
}
