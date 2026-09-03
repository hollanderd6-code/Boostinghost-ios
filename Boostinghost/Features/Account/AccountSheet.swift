import SwiftUI

struct AccountSheet: View {
    @Environment(AuthStore.self) var authStore
    @Environment(\.dismiss) private var dismiss

    @State private var showSwitcher = false
    @State private var subscription: SubscriptionStatus? = nil

    private var isSubAccount: Bool { authStore.session?.isSubAccount == true }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                sheetHeader
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        profileCard
                        if !isSubAccount {
                            group1
                            group2
                            group3
                        }
                        signOutCard
                        appFooter
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            await authStore.fetchDelegations()
            subscription = try? await APIClient.shared.get(Endpoint.subscriptionStatus)
        }
        .sheet(isPresented: $showSwitcher) {
            AccountSwitcherSheet {
                showSwitcher = false
                dismiss()
            }
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(Color.bhAttenue.opacity(0.3))
                .frame(width: 38, height: 5)
            HStack {
                Text("Mon compte")
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.96)
                    .foregroundStyle(Color.bhEncre)
                Spacer()
                Button("Fermer") { dismiss() }
                    .font(.system(size: 16.5, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Carte de profil

    private var profileCard: some View {
        // Read displayName directly in body context so @Observable tracks it.
        let name = authStore.session?.displayName ?? ""
        let words = name.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first.map(String.init) }.joined().uppercased()

        return ListCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#DCE8E1"))
                        .frame(width: 52, height: 52)
                    Text(letters.isEmpty ? "?" : letters)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(name.isEmpty ? "Mon compte" : name)
                        .font(.system(size: 18.5, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                    if let line = planLine {
                        Text(line)
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhAttenue)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.bhAttenue.opacity(0.55))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Groupe 1 — Organisation

    private var group1: some View {
        ListCard {
            settingsRow(icon: "creditcard",  title: "Abonnement et factures",  sep: true)
            settingsRow(icon: "person.2",    title: "Mon équipe et accès",     sep: true)
            // Comptes gérés — actif
            CardRow(showSeparator: true) {
                Button { showSwitcher = true } label: {
                    rowHStack(icon: "building.2", title: "Comptes gérés",
                              value: delegationsLabel)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            settingsRow(icon: "link",        title: "Plateformes connectées",  sep: false)
        }
    }

    // MARK: - Groupe 2 — Opérations

    private var group2: some View {
        ListCard {
            settingsRow(icon: "sparkles",       title: "Ménage et prestataires",  sep: true)
            settingsRow(icon: "text.bubble",    title: "Messages automatiques",   sep: true)
            settingsRow(icon: "bell",            title: "Notifications",           sep: false)
        }
    }

    // MARK: - Groupe 3 — Support

    private var group3: some View {
        ListCard {
            settingsRow(icon: "questionmark.circle", title: "Aide et tutoriels",  sep: true)
            settingsRow(icon: "envelope",            title: "Nous écrire",
                        value: "Réponse sous 2 h",                                sep: false)
        }
    }

    // MARK: - Se déconnecter

    private var signOutCard: some View {
        Button { authStore.signOut() } label: {
            ListCard {
                Text("Se déconnecter")
                    .font(.system(size: 16.5, weight: .semibold))
                    .foregroundStyle(Color.bhTerracotta)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pied

    private var appFooter: some View {
        Text("Boostinghost 3.2  ·  CGU  ·  Confidentialité")
            .font(.system(size: 12.5))
            .foregroundStyle(Color.bhAttenue)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func settingsRow(icon: String, title: String,
                              value: String? = nil, sep: Bool) -> some View {
        CardRow(showSeparator: sep) {
            rowHStack(icon: icon, title: title, value: value)
        }
    }

    private func rowHStack(icon: String, title: String, value: String? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.bhAttenue)
                .frame(width: 22)
            Text(title)
                .font(.system(size: 15.5, weight: .medium))
                .foregroundStyle(Color.bhEncre)
            Spacer(minLength: 4)
            if let value {
                Text(value)
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bhAttenue.opacity(0.55))
        }
    }

    private var planLine: String? {
        guard let type = subscription?.planType,
              let plan = formattedPlan(type) else { return nil }
        var parts = ["Formule \(plan)"]
        if let n = subscription?.propertiesUsed, n > 0 {
            parts.append("\(n) logement\(n == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    private func formattedPlan(_ type: String) -> String? {
        switch type.lowercased() {
        case "agency", "agence", "agence_monthly":  return "Agence"
        case "pro", "pro_monthly":                   return "Pro"
        case "pro_annual":                           return "Pro (annuel)"
        case "starter":                              return "Starter"
        default:                                     return nil
        }
    }

    private var delegationsLabel: String? {
        switch authStore.agencyContext {
        case .own:
            let n = authStore.delegations.count
            return n > 0 ? "\(n) compte\(n == 1 ? "" : "s")" : nil
        case .allAccounts:
            return "Vue globale"
        case .delegating(_, let name, _):
            return name
        }
    }
}
