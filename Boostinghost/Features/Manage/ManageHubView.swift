import SwiftUI

// MARK: - Entrées du sommaire

enum ManageEntry: CaseIterable, Hashable {
    case properties, cleaning, owners, stays

    var title: String {
        switch self {
        case .properties: return "Logements"
        case .cleaning:   return "Ménage"
        case .owners:     return "Propriétaires"
        case .stays:      return "Séjours"
        }
    }

    var subtitle: String {
        switch self {
        case .properties: return "livret, prix, accès, assistant"
        case .cleaning:   return "planning, intervenants, historique"
        case .owners:     return "clients, contrats, factures, débours"
        case .stays:      return "factures voyageurs, cautions"
        }
    }

    var icon: String {
        switch self {
        case .properties: return "building.2"
        case .cleaning:   return "sparkles"
        case .owners:     return "person.2"
        case .stays:      return "doc.text"
        }
    }

    var iconBackground: Color {
        switch self {
        case .properties: return Color(hex: "#DCE8E1")
        case .cleaning:   return Color.bhOrFond
        case .owners, .stays: return Color.white.opacity(0.55)
        }
    }

    var iconForeground: Color {
        switch self {
        case .properties: return Color.bhVert
        case .cleaning:   return Color.bhOr
        case .owners, .stays: return Color.bhAttenue
        }
    }

    func isVisible(for session: Session?) -> Bool {
        guard let session, session.isSubAccount else { return true }
        switch self {
        case .properties: return session.can("can_view_properties")
        case .cleaning:   return session.can("can_view_cleaning")
        case .owners:     return session.can("can_view_owners")
        case .stays:      return session.can("can_view_invoices")
        }
    }

    static func visible(for session: Session?) -> [ManageEntry] {
        allCases.filter { $0.isVisible(for: session) }
    }
}

// MARK: - Sommaire Gestion

struct ManageHubView: View {
    @Environment(AuthStore.self) var authStore
    @State private var vm = ManageHubViewModel()
    @State private var showAccount = false

    private var visibleEntries: [ManageEntry] {
        ManageEntry.visible(for: authStore.session)
    }

    var body: some View {
        if visibleEntries.count == 1, let only = visibleEntries.first {
            subScreenView(for: only)
        } else {
            NavigationStack {
                scrollContent
                    .safeAreaInset(edge: .top, spacing: 0) { navBar }
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: ManageEntry.self) { entry in
                        subScreenView(for: entry)
                    }
            }
            .refreshable { await reload() }
            .task { await reload() }
            .onChange(of: authStore.agencyContext) { Task { await reload() } }
            .sheet(isPresented: $showAccount) {
                AccountSheet()
            }
        }
    }

    private func reload() async {
        vm.agencyAll = authStore.agencyAll
        await vm.load()
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        GlassNavBar(superTitle: superTitle, title: "Gestion") {
            HStack(spacing: 10) {
                GlassCircleButton(icon: "magnifyingglass") { }
                InitialsButton {
                    showAccount = true
                }
            }
        }
    }

    private var superTitle: String {
        guard case .loaded = vm.loadState else { return " " }
        let lg = vm.propertyCount == 1 ? "1 logement"  : "\(vm.propertyCount) logements"
        let gr = vm.groupCount    == 1 ? "1 groupe"     : "\(vm.groupCount) groupes"
        return "\(lg) · \(gr)"
    }

    // MARK: - Contenu défilant

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                switch vm.loadState {
                case .idle, .loading:
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .padding(.top, 40)
                case .error(let msg):
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.bhAttenue)
                        Text(msg)
                            .font(.bhCorps)
                            .foregroundStyle(Color.bhAttenue)
                            .multilineTextAlignment(.center)
                        Button("Réessayer") { Task { await reload() } }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.bhVert)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                case .loaded:
                    entriesCard
                    if !vm.diffusionAlertProperties.isEmpty {
                        diffusionAlertCard
                    }
                    shortcutsSection
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Carte des quatre entrées

    private var entriesCard: some View {
        ListCard {
            ForEach(Array(visibleEntries.enumerated()), id: \.element) { idx, entry in
                NavigationLink(value: entry) {
                    CardRow(showSeparator: idx < visibleEntries.count - 1) {
                        entryRow(entry)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func entryRow(_ entry: ManageEntry) -> some View {
        HStack(spacing: 14) {
            Image(systemName: entry.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(entry.iconForeground)
                .frame(width: 40, height: 40)
                .background(
                    entry.iconBackground,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                Text(entry.subtitle)
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let badge = badge(for: entry) {
                Text(badge)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.bhAttenue)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bhAttenue.opacity(0.55))
        }
    }

    private func badge(for entry: ManageEntry) -> String? {
        guard case .loaded = vm.loadState else { return nil }
        switch entry {
        case .properties:
            return vm.propertyCount > 0 ? "\(vm.propertyCount)" : nil
        case .cleaning:
            guard let n = vm.cleaningTodayCount, n > 0 else { return nil }
            return "\(n) aujourd'hui"
        case .stays:
            guard let n = vm.depositCount, n > 0 else { return nil }
            return "\(n)"
        case .owners:
            return nil
        }
    }

    // MARK: - Carte alerte diffusion (or)

    private var diffusionAlertCard: some View {
        let props = vm.diffusionAlertProperties
        let n = props.count
        return HStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.bhOrClair, Color.bhOr],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 22,
                        bottomLeadingRadius: 22,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.bhOr)
                    Text("\(n) logement\(n == 1 ? "" : "s") à préparer")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.bhOr)
                }
                Text(props.map { $0.nom.isEmpty ? "Logement" : $0.nom }.joined(separator: ", "))
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
                    .lineLimit(2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.bhOrFond, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Raccourcis

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Raccourcis")

            ListCard {
                CardRow(showSeparator: true) {
                    shortcutRow(icon: "plus", label: "Ajouter un logement",
                                trailing: addPropertyQuota)
                }

                CardRow(showSeparator: false) {
                    shortcutRow(icon: "arrow.triangle.2.circlepath",
                                label: "Resynchroniser les plateformes")
                }
            }
        }
    }

    private var addPropertyQuota: String? {
        guard case .loaded = vm.loadState,
              let used  = vm.propertiesUsed,
              let limit = vm.propertiesLimit else { return nil }
        return "\(used) / \(limit)"
    }

    private func shortcutRow(icon: String, label: String, trailing: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.bhVert)
                .frame(width: 28)
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.bhEncre)
            Spacer(minLength: 4)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.bhAttenue)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bhAttenue.opacity(0.55))
        }
    }

    // MARK: - Routage vers sous-écrans

    @ViewBuilder
    private func subScreenView(for entry: ManageEntry) -> some View {
        switch entry {
        case .properties: PropertiesView()
        case .cleaning:   CleaningView()
        case .owners:     OwnersView()
        case .stays:      StaysView()
        }
    }
}
