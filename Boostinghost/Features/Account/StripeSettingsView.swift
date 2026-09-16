import SwiftUI
import SafariServices

struct StripeSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var profileVM     = ProfileViewModel()
    @State private var stripeStatus:  StripeStatusResponse?
    @State private var isLoadingStatus = false
    @State private var onboardingURL:  URL?
    @State private var showOnboarding  = false
    @State private var isLoadingLink   = false
    @State private var linkError:      String?

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        if profileVM.isLoading {
                            HStack { Spacer(); ProgressView(); Spacer() }
                                .padding(.top, 60)
                        } else {
                            bhStripeSection
                            if !profileVM.useBhStripe {
                                personalStripeSection
                            }
                        }
                        if let err = linkError {
                            Text(err)
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhTerracotta)
                                .padding(.horizontal, 18)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await profileVM.load(initial: nil)
            await loadStripeStatus()
        }
        .onChange(of: profileVM.useBhStripe) { _, _ in
            Task { await loadStripeStatus() }
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            Task {
                await loadStripeStatus()
                NotificationCenter.default.post(name: .setupShouldRefresh, object: nil)
            }
        }) {
            if let url = onboardingURL {
                SafariSheet(url: url)
            }
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                        .frame(width: 38, height: 38)
                        .glassEffect(in: .circle)
                        .specularEdge(cornerRadius: 19)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Mon compte")
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                    Text("Paiements")
                        .bhGrandTitre()
                }
                .padding(.leading, 12)

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Sections

    private var bhStripeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Passerelle intégrée")
            ListCard {
                CardRow(showSeparator: false) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Passerelle Boostinghost")
                                .font(.system(size: 15.5, weight: .medium))
                                .foregroundStyle(Color.bhEncre)
                            Text("Utiliser la passerelle de paiement intégrée")
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhAttenue)
                        }
                        Spacer(minLength: 8)
                        if profileVM.isTogglingStripe {
                            ProgressView()
                                .tint(Color.bhAttenue)
                                .scaleEffect(0.8)
                        } else {
                            Toggle("", isOn: Binding(
                                get:  { profileVM.useBhStripe },
                                set:  { v in Task { await profileVM.toggleStripe(v) } }
                            ))
                            .labelsHidden()
                            .tint(Color.bhVert)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var personalStripeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Compte Stripe personnel")
            ListCard {
                CardRow(showSeparator: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        stripeStatusRow
                        if isLoadingStatus {
                            ProgressView()
                                .tint(Color.bhAttenue)
                                .scaleEffect(0.8)
                        } else {
                            connectButton
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var stripeStatusRow: some View {
        if let s = stripeStatus {
            HStack(spacing: 8) {
                Circle()
                    .fill(s.connected && s.canCharge ? Color.bhVert : Color.bhTerracotta)
                    .frame(width: 8, height: 8)
                Text(statusLabel(s))
                    .font(.system(size: 14.5))
                    .foregroundStyle(Color.bhEncre)
            }
        }
    }

    private func statusLabel(_ s: StripeStatusResponse) -> String {
        if s.connected && s.canCharge { return "Compte Stripe connecté et opérationnel" }
        if s.connected { return "Compte connecté — configuration incomplète" }
        return "Aucun compte Stripe connecté"
    }

    @ViewBuilder
    private var connectButton: some View {
        let label = (stripeStatus?.connected == true) ? "Gérer le compte Stripe" : "Connecter Stripe"
        Button {
            Task { await openStripeOnboarding() }
        } label: {
            ZStack {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .opacity(isLoadingLink ? 0 : 1)
                if isLoadingLink {
                    ProgressView().tint(.white).scaleEffect(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(Color.bhVert, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoadingLink)
    }

    // MARK: - Helpers

    private func loadStripeStatus() async {
        isLoadingStatus = true
        defer { isLoadingStatus = false }
        do {
            stripeStatus = try await APIClient.shared.get(Endpoint.stripeStatus)
        } catch {
            print("[StripeSettings] stripeStatus error: \(error)")
        }
    }

    private func openStripeOnboarding() async {
        isLoadingLink = true
        linkError = nil
        defer { isLoadingLink = false }
        do {
            let r: StripeOnboardingLinkResponse = try await APIClient.shared.post(Endpoint.stripeCreateOnboarding, body: EmptyBody())
            guard let url = URL(string: r.url) else { return }
            onboardingURL = url
            showOnboarding = true
        } catch let err as APIError {
            linkError = err.userMessage
        } catch {
            linkError = error.localizedDescription
        }
    }
}

// MARK: - Safari wrapper

private struct SafariSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
