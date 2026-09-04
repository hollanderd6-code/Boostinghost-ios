import SwiftUI

// MARK: - Navigation destinations

enum AccountDestination: Hashable {
    case subscription
    case profile
    case team
    case diffusion
    case cleaners
    case messageTemplates
    case notifications
}

// MARK: - Sheet principale

struct AccountSheet: View {
    @Environment(AuthStore.self) var authStore
    @Environment(\.dismiss) private var dismiss

    @State private var vm = AccountViewModel()
    @State private var showSwitcher = false

    private var isSubAccount: Bool { authStore.session?.isSubAccount == true }

    var body: some View {
        NavigationStack {
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
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AccountDestination.self) { dest in
                switch dest {
                case .subscription:
                    SubscriptionView(status: vm.subscriptionStatus)
                case .profile:
                    
                    ProfileView(profile: vm.userProfile)
                case .team:
                    TeamListView()
                case .diffusion:
                    DiffusionView()
                case .cleaners:
                    CleanersView()
                case .messageTemplates:
                    MessageTemplatesView()
                case .notifications:
                    NotificationsView()
                }
            }
        }
        .task {
            await authStore.fetchDelegations()
            await vm.load()
        }
        .sheet(isPresented: $showSwitcher) {
            AccountSwitcherSheet { showSwitcher = false; dismiss() }
        }
    }

    // MARK: - En-tête en verre

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

    @ViewBuilder
    private var profileCard: some View {
        let name    = authStore.session?.displayName ?? ""
        let words   = name.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first.map(String.init) }.joined().uppercased()

        if isSubAccount {
            // Sub-accounts: display only, no navigation
            ListCard {
                HStack(spacing: 14) {
                    initialsCircle(letters: letters)
                    Text(name.isEmpty ? "Mon compte" : name)
                        .font(.system(size: 18.5, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        } else {
            NavigationLink(value: AccountDestination.profile) {
                ListCard {
                    HStack(spacing: 14) {
                        initialsCircle(letters: letters)
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
            .buttonStyle(.plain)
        }
    }

    private func initialsCircle(letters: String) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#DCE8E1"))
                .frame(width: 52, height: 52)
            Text(letters.isEmpty ? "?" : letters)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.bhVert)
        }
    }

    // MARK: - Groupe 1 — Organisation

    private var group1: some View {
        ListCard {
            // Abonnement — sous-écran push
            CardRow(showSeparator: true) {
                NavigationLink(value: AccountDestination.subscription) {
                    rowContent(icon: "creditcard", title: "Abonnement et factures")
                }
                .buttonStyle(.plain)
            }

            // Mon équipe
            CardRow(showSeparator: true) {
                NavigationLink(value: AccountDestination.team) {
                    rowContent(icon: "person.2",
                               title: "Mon équipe et accès",
                               value: teamLabel)
                }
                .buttonStyle(.plain)
            }

            // Comptes gérés — ouvre le sélecteur
            CardRow(showSeparator: true) {
                Button { showSwitcher = true } label: {
                    rowContent(icon: "building.2",
                               title: "Comptes gérés",
                               value: delegationsLabel)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // Plateformes — ouvre l'écran de diffusion
            CardRow(showSeparator: false) {
                NavigationLink(value: AccountDestination.diffusion) {
                    rowContent(icon: "link",
                               title: "Plateformes connectées",
                               value: platformsLabel,
                               valueColor: platformsColor,
                               valueBold: platformsConnected > 0)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Groupe 2 — Opérations

    private var group2: some View {
        ListCard {
            CardRow(showSeparator: true) {
                NavigationLink(value: AccountDestination.cleaners) {
                    rowContent(icon: "sparkles",
                               title: "Ménage et prestataires",
                               value: cleanersLabel)
                }
                .buttonStyle(.plain)
            }
            CardRow(showSeparator: true) {
                NavigationLink(value: AccountDestination.messageTemplates) {
                    rowContent(icon: "text.bubble",
                               title: "Messages automatiques",
                               value: templatesLabel)
                }
                .buttonStyle(.plain)
            }
            CardRow(showSeparator: false) {
                NavigationLink(value: AccountDestination.notifications) {
                    rowContent(icon: "bell", title: "Notifications")
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Groupe 3 — Support

    private var group3: some View {
        ListCard {
            CardRow(showSeparator: true) {
                rowContent(icon: "questionmark.circle", title: "Aide et tutoriels")
            }
            CardRow(showSeparator: false) {
                rowContent(icon: "envelope",
                           title: "Nous écrire",
                           value: "Réponse sous 2 h")
            }
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

    // MARK: - Helpers visuels

    @ViewBuilder
    private func rowContent(icon: String,
                            title: String,
                            value: String? = nil,
                            valueColor: Color = .bhAttenue,
                            valueBold: Bool = false) -> some View {
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
                    .font(.system(size: 13, weight: valueBold ? .semibold : .regular))
                    .foregroundStyle(valueColor)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bhAttenue.opacity(0.55))
        }
    }

    // MARK: - Labels calculés

    private var planLine: String? {
        guard let type = vm.subscriptionStatus?.planType,
              let plan = formattedPlan(type) else { return nil }
        var parts = ["Formule \(plan)"]
        if let n = vm.subscriptionStatus?.propertiesUsed, n > 0 {
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

    private var teamLabel: String? {
        switch vm.teamCount {
        case .loading:          return nil
        case .failed:           return "—"
        case .loaded(let n):    return n > 0 ? "\(n) personne\(n == 1 ? "" : "s")" : nil
        }
    }

    private var delegationsLabel: String? {
        switch authStore.agencyContext {
        case .own:
            let n = authStore.delegations.filter(\.isAccepted).count
            return n > 0 ? "\(n) délégation\(n == 1 ? "" : "s")" : nil
        case .allAccounts:
            return "Vue globale"
        case .delegating(_, let name, _):
            return name
        }
    }

    private var platformsLabel: String? {
        switch vm.platformsConnected {
        case .loading:          return nil
        case .failed:           return "—"
        case .loaded(let n):    return n > 0 ? "\(n) diffusé\(n == 1 ? "" : "s")" : "Aucun"
        }
    }

    private var platformsColor: Color {
        if case .loaded(let n) = vm.platformsConnected, n > 0 { return .bhVert }
        return .bhAttenue
    }

    private var platformsConnected: Int {
        if case .loaded(let n) = vm.platformsConnected { return n }
        return 0
    }

    private var cleanersLabel: String? {
        switch vm.cleanersCount {
        case .loading:          return nil
        case .failed:           return "—"
        case .loaded(let n):    return n > 0 ? "\(n) intervenant\(n == 1 ? "" : "s")" : nil
        }
    }

    private var templatesLabel: String? {
        switch vm.templatesCount {
        case .loading:          return nil
        case .failed:           return "—"
        case .loaded(let n):    return n > 0 ? "\(n) modèle\(n == 1 ? "" : "s")" : nil
        }
    }
}
