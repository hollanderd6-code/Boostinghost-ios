import SwiftUI

// MARK: - Navigation destinations

enum AccountDestination: Hashable, Identifiable {
    var id: Self { self }
    case subscription
    case profile
    case team
    case diffusion
    case cleaners
    case messageTemplates
    case notifications
    case payments
    case help
    case support
}

// MARK: - Sheet principale

struct AccountSheet: View {
    var initialDestination: AccountDestination? = nil

    @Environment(AuthStore.self) var authStore
    @Environment(\.dismiss) private var dismiss

    @State private var path: NavigationPath
    @State private var vm = AccountViewModel()
    @State private var showSwitcher = false
    @State private var showPIN      = false

    init(initialDestination: AccountDestination? = nil) {
        self.initialDestination = initialDestination
        if let dest = initialDestination {
            var p = NavigationPath()
            p.append(dest)
            _path = State(initialValue: p)
        } else {
            _path = State(initialValue: NavigationPath())
        }
    }

    private var isSubAccount: Bool { authStore.session?.isSubAccount == true }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppBackground()
                VStack(spacing: 0) {
                    sheetHeader
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            profileCard
                            cleanerAccessCard
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
                    ProfileView(initialProfile: vm.userProfile) { updated in
                        vm.userProfile = updated
                    }
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
                case .payments:
                    StripeSettingsView()
                case .help:
                    HelpView()
                case .support:
                    SupportView()
                }
            }
        }
        .task {
            await authStore.fetchDelegations()
            await vm.load()
        }
        // Retour de l'écran Notifications : relire les préférences pour que le
        // compteur « x sur y actives » reflète les bascules qui viennent d'être faites.
        .onChange(of: path) { _, newPath in
            guard newPath.isEmpty else { return }
            Task { vm.notificationPrefs = try? await APIClient.shared.get(Endpoint.notificationSettings) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToToday)) { _ in
            dismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: .setupShouldRefresh)) { _ in
            Task { await vm.silentRefreshPayments() }
        }
        .sheet(isPresented: $showSwitcher) {
            AccountSwitcherSheet { showSwitcher = false; dismiss() }
        }
    }

    // MARK: - En-tête en verre

    private var sheetHeader: some View {
        VStack(spacing: 0) {
            SheetHandle()
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
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Carte de profil

    @ViewBuilder
    private var profileCard: some View {
        let first = vm.userProfile?.firstName ?? ""
        let last  = vm.userProfile?.lastName  ?? ""
        let joined = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        let name   = joined.isEmpty ? (authStore.session?.displayName ?? "") : joined

        if isSubAccount {
            // Derive initials from session.displayName when /api/user/profile returns nothing
            // for sub-accounts (main-account endpoint → 403 → userProfile stays nil).
            let displayWords = name.split(separator: " ").map(String.init)
            ListCard {
                HStack(spacing: 14) {
                    ProfileAvatarView(
                        logoUrl:   vm.userProfile?.logoUrl,
                        firstName: vm.userProfile?.firstName ?? displayWords.first,
                        lastName:  vm.userProfile?.lastName  ?? (displayWords.count > 1 ? displayWords.last : nil),
                        company:   vm.userProfile?.company,
                        size:      52
                    )
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
                        ProfileAvatarView(
                            logoUrl:   vm.userProfile?.logoUrl,
                            firstName: vm.userProfile?.firstName,
                            lastName:  vm.userProfile?.lastName,
                            company:   vm.userProfile?.company,
                            size:      52
                        )
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

    // MARK: - Carte Mon accès ménage (sous-compte cleaner uniquement)

    @ViewBuilder
    private var cleanerAccessCard: some View {
        if isSubAccount, let access = vm.cleanerAccess {
            ListCard {
                CardRow(showSeparator: true) {
                    HStack(spacing: 10) {
                        Text("Code PIN")
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundStyle(Color.bhEncre)
                        Spacer(minLength: 4)
                        Text(showPIN ? access.pinCode : String(repeating: "●", count: max(access.pinCode.count, 4)))
                            .font(.system(size: 15).monospacedDigit())
                            .foregroundStyle(Color.bhEncre)
                        Button(showPIN ? "Masquer" : "Afficher") { showPIN.toggle() }
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(Color.bhVert)
                            .buttonStyle(.plain)
                        Button {
                            UIPasteboard.general.string = access.pinCode
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.bhVert)
                        }
                        .buttonStyle(.plain)
                    }
                }
                CardRow(showSeparator: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Text("Accès web")
                                .font(.system(size: 14.5, weight: .medium))
                                .foregroundStyle(Color.bhEncre)
                            Spacer(minLength: 4)
                            if let url = URL(string: access.accessUrl), !access.accessUrl.isEmpty {
                                Button("Ouvrir") { UIApplication.shared.open(url) }
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundStyle(Color.bhVert)
                                    .buttonStyle(.plain)
                                ShareLink(item: url) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color.bhVert)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text("Remplissez vos tâches depuis un navigateur.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color(hex: "#5E6B63"))
                    }
                }
            }
        }
    }

    // MARK: - Groupe 1 — Organisation

    private var group1: some View {
        ListCard {
            // Abonnement — sous-écran push
            CardRow(showSeparator: true) {
                NavigationLink(value: AccountDestination.subscription) {
                    rowContent(icon: "creditcard", title: "Abonnement et factures",
                               value: planName)
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

            // Paiements — Stripe et passerelle
            CardRow(showSeparator: true) {
                NavigationLink(value: AccountDestination.payments) {
                    rowContent(icon: "banknote", title: "Paiements",
                               value: paymentsLabel)
                }
                .buttonStyle(.plain)
            }

            // Plateformes — ouvre l'écran de diffusion
            CardRow(showSeparator: false) {
                NavigationLink(value: AccountDestination.diffusion) {
                    rowContent(icon: "link",
                               title: "Plateformes connectées",
                               value: platformsLabel)
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
                    rowContent(icon: "bell", title: "Notifications",
                               value: notificationsLabel)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Groupe 3 — Support

    private var group3: some View {
        ListCard {
            CardRow(showSeparator: true) {
                NavigationLink(value: AccountDestination.help) {
                    rowContent(icon: "questionmark.circle", title: "Aide et tutoriels",
                               value: "FAQ · Guides")
                }
                .buttonStyle(.plain)
            }
            CardRow(showSeparator: false) {
                NavigationLink(value: AccountDestination.support) {
                    rowContent(icon: "envelope",
                               title: "Nous écrire",
                               value: "Réponse sous 2 h")
                }
                .buttonStyle(.plain)
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
        if case .loaded(let n) = vm.managedPropertiesCount, n > 0 {
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

    private var planName: String? {
        guard let type = vm.subscriptionStatus?.planType else { return nil }
        return formattedPlan(type)
    }

    private var notificationsLabel: String? {
        guard let prefs = vm.notificationPrefs else { return nil }
        let keys   = NotificationsViewModel.sections.flatMap { $0.items.map(\.key) }
        let active = keys.filter { prefs.values[$0] ?? true }.count
        return "\(active) sur \(keys.count) active\(active == 1 ? "" : "s")"
    }

    private var teamLabel: String? {
        switch vm.teamCount {
        case .loading:          return nil
        case .failed:           return "—"
        case .loaded(let n):    return n > 0 ? "\(n) personne\(n == 1 ? "" : "s")" : nil
        }
    }

    private var delegationsLabel: String? {
        let delegations = authStore.delegations.count
        let total = delegations + 1  // +1 for the user's own account
        switch authStore.agencyContext {
        case .own, .allAccounts:
            return "\(total) compte\(total == 1 ? "" : "s")"
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

    private var paymentsLabel: String? {
        guard let profile = vm.userProfile else { return nil }
        if profile.useBhStripe { return "Stripe Boostinghost" }
        guard let s = vm.stripeStatus else { return nil }
        if s.connected && s.canCharge { return "Stripe personnel" }
        return "À configurer"
    }
}
