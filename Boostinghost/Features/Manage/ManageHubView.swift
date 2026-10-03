import SwiftUI
import WebKit

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
    @Environment(SetupViewModel.self) private var setupVM
    @State private var vm = ManageHubViewModel()
    @State private var showAccount = false
    @State private var showSearch = false
    @State private var showNewPropertySheet = false
    @State private var showPlanLimitAlert = false
    @State private var showSyncAlert = false
    @State private var syncAlertMessage = ""

    private var visibleEntries: [ManageEntry] {
        ManageEntry.visible(for: authStore.session)
    }

    var body: some View {
        if visibleEntries.count == 1, let only = visibleEntries.first {
            subScreenView(for: only)
        } else {
            NavigationStack {
                scrollContent
                    .refreshable { await reload() }
                    .safeAreaInset(edge: .top, spacing: 0) { navBar }
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: ManageEntry.self) { entry in
                        subScreenView(for: entry)
                    }
                    .navigationDestination(for: ManageWebShortcut.self) { shortcut in
                        ManageWebScreen(shortcut: shortcut)
                    }
            }
            .task { await reload() }
            .onChange(of: authStore.agencyContext) { Task { await reload() } }
            .sheet(isPresented: $showAccount) {
                AccountSheet().environment(setupVM)
            }
            .sheet(isPresented: $showSearch) {
                GlobalSearchSheet()
            }
            .sheet(isPresented: $showNewPropertySheet) {
                NewPropertySheet {
                    Task { await reload() }
                    NotificationCenter.default.post(name: .setupShouldRefresh, object: nil)
                }
            }
            .alert("Limite atteinte", isPresented: $showPlanLimitAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Le plan Starter est limité à 3 logements. Passez au plan Pro pour créer des logements supplémentaires.")
            }
            .alert("Synchronisation", isPresented: $showSyncAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(syncAlertMessage)
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
                GlassCircleButton(icon: "magnifyingglass") { showSearch = true }
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

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.bhOr)
                    Text("\(n) logement\(n == 1 ? "" : "s") à compléter")
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
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(Color.bhOrFond, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Raccourcis

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Raccourcis")

            ListCard {
                ForEach(visibleWebShortcuts, id: \.self) { shortcut in
                    NavigationLink(value: shortcut) {
                        CardRow(showSeparator: true) {
                            shortcutRow(icon: shortcut.icon, label: shortcut.title)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    if vm.isAtStarterLimit {
                        showPlanLimitAlert = true
                    } else {
                        showNewPropertySheet = true
                    }
                } label: {
                    CardRow(showSeparator: true) {
                        shortcutRow(icon: "plus", label: "Ajouter un logement",
                                    trailing: addPropertyQuota)
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                Button {
                    Task {
                        let msg = await vm.sync()
                        syncAlertMessage = msg
                        showSyncAlert = true
                    }
                } label: {
                    CardRow(showSeparator: false) {
                        syncShortcutRow
                    }
                }
                .buttonStyle(.plain)
                .disabled(vm.isSyncing)
            }
        }
    }

    private var visibleWebShortcuts: [ManageWebShortcut] {
        ManageWebShortcut.allCases.filter { authStore.session?.can($0.permission) ?? false }
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

    private var syncShortcutRow: some View {
        HStack(spacing: 12) {
            Group {
                if vm.isSyncing {
                    ProgressView()
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.bhVert)
                }
            }
            .frame(width: 28)

            Text("Resynchroniser les plateformes")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.bhEncre)

            Spacer(minLength: 4)

            if !vm.isSyncing {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.bhAttenue.opacity(0.55))
            }
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

// MARK: - Raccourcis web (Livrets, Serrures, Reporting)
//
// Ces trois écrans n'existent pas encore en natif. En attendant, ils ouvrent les pages
// du site (déjà au style de l'app) dans un WKWebView, avec la session de l'app :
// le jeton du Keychain est posé dans localStorage["lcc_token"] avant le chargement,
// clé lue par public/js/auth-fetch.js côté site.

enum ManageWebShortcut: String, CaseIterable, Hashable {
    case paymentLink, welcomeBooks, smartLocks, reporting

    var title: String {
        switch self {
        case .paymentLink:  return "Lien de paiement"
        case .welcomeBooks: return "Livrets d'accueil"
        case .smartLocks:   return "Serrures connectées"
        case .reporting:    return "Reporting"
        }
    }

    var icon: String {
        switch self {
        case .paymentLink:  return "link"
        case .welcomeBooks: return "book"
        case .smartLocks:   return "lock"
        case .reporting:    return "chart.bar"
        }
    }

    /// Même permission que la carte du site (public/manage.html, data-perm).
    var permission: String {
        switch self {
        case .paymentLink:  return "can_view_payments"
        case .welcomeBooks: return "can_view_properties"
        case .smartLocks:   return "can_view_smart_locks"
        case .reporting:    return "can_view_reporting"
        }
    }

    var url: URL {
        let path: String
        switch self {
        case .paymentLink:  path = "/paiement.html"
        case .welcomeBooks: path = "/livrets.html"
        case .smartLocks:   path = "/serrures.html"
        case .reporting:    path = "/revenus.html"
        }
        return URL(string: "https://www.boostinghost.fr" + path)!
    }
}

struct ManageWebScreen: View {
    let shortcut: ManageWebShortcut
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var authStore
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        ZStack {
            Color.bhGradientMid.ignoresSafeArea()
            ManageWebView(url: shortcut.url, agencyAll: authStore.agencyAll,
                          isLoading: $isLoading, loadError: $loadError) {
                dismiss()
            }
            .ignoresSafeArea(edges: .bottom)
            if isLoading {
                ProgressView().tint(Color.bhVert)
            }
            if let loadError {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.bhAttenue)
                    Text(loadError)
                        .font(.bhCorps)
                        .foregroundStyle(Color.bhAttenue)
                        .multilineTextAlignment(.center)
                    Button("Retour") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                }
                .padding(24)
            }
        }
        // La page web a son propre en-tête avec bouton retour (renvoyé vers dismiss()).
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct ManageWebView: UIViewRepresentable {
    let url: URL
    /// Vue « Tous les comptes » de l'app → même vue côté site (auth-fetch.js
    /// ajoute ?agency=all aux appels API quand bh_agency_view vaut 'all').
    let agencyAll: Bool
    @Binding var isLoading: Bool
    @Binding var loadError: String?
    let onLeave: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()

        // Session de l'app → localStorage du site, avant tout script de la page.
        if let token = KeychainStore.load(), let json = jsonString(token) {
            controller.addUserScript(WKUserScript(
                source: "try { localStorage.setItem('lcc_token', \(json)); } catch (e) {}",
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))
        }
        controller.addUserScript(WKUserScript(
            source: "try { localStorage.setItem('bh_agency_view', '\(agencyAll ? "all" : "mine")'); } catch (e) {}",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        // La navigation du site (barre latérale, onglets, en-tête mobile) fait doublon
        // avec celle de l'app : on la masque.
        // La marge basse du site (130 px + zone sûre) est conservée : la barre
        // d'onglets de l'app flotte par-dessus la page et masquerait le dernier bouton.
        let css = ".gx-tabbar,.gx-aside,.bhr-tabs,.bhr-top,.bhr-rail,.mobile-tabs{display:none!important}"
        controller.addUserScript(WKUserScript(
            source: "var s=document.createElement('style');s.textContent='\(css)';document.documentElement.appendChild(s);",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        config.userContentController = controller

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {}

    private func jsonString(_ s: String) -> String? {
        guard let data = try? JSONEncoder().encode(s) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: ManageWebView
        init(_ parent: ManageWebView) { self.parent = parent }

        func webView(_ webView: WKWebView,
                     decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            let path = action.request.url?.path ?? ""
            // Le bouton retour de la page renvoie vers le sommaire Gestion du site,
            // ou vers la connexion si la session a expiré : on revient à l'écran natif.
            if path == "/manage.html" || path == "/app.html" || path == "/login.html" {
                parent.onLeave()
                return .cancel
            }
            return .allow
        }

        // Liens « Aperçu » / « Voir le livret » (window.open) : ouverts dans Safari.
        func webView(_ webView: WKWebView, createWebViewWith _: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures _: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url, url.scheme == "https" {
                UIApplication.shared.open(url)
            }
            return nil
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            parent.isLoading = true
            parent.loadError = nil
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadError = error.localizedDescription
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            if (error as NSError).code == NSURLErrorCancelled { return }
            parent.loadError = error.localizedDescription
        }
    }
}
