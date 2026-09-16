import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SetupViewModel.self) private var setupVM
    @State private var vm = HelpViewModel()
    @State private var searchText = ""
    @State private var expandedIDs: Set<Int> = []

    private var filteredFAQ: [HelpFAQItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return vm.faq }
        return vm.faq.filter {
            $0.question.lowercased().contains(q) || $0.answerText.lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                contentBody
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.load() }
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
                    Text("Centre de ressources")
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                    Text("Aide et tutoriels")
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

    // MARK: - Content

    @ViewBuilder
    private var contentBody: some View {
        switch vm.loadState {
        case .idle, .loading:
            Spacer()
            ProgressView().scaleEffect(1.2)
            Spacer()
        case .error(let msg):
            errorView(msg)
        case .loaded:
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    searchBar
                    setupSection
                    if !vm.faq.isEmpty { faqSection }
                    if !vm.videos.isEmpty { videosSection }
                    if !vm.guides.isEmpty { guidesSection }
                    #if DEBUG
                    debugSection
                    #endif
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .refreshable { await vm.load() }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(Color.bhAttenue)
            TextField("Rechercher dans les questions…", text: $searchText)
                .font(.bhCorps)
                .foregroundStyle(Color.bhEncre)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.bhAttenue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .glassEffect(in: .rect(cornerRadius: 14))
                .specularEdge(cornerRadius: 14)
        }
    }

    // MARK: - Configuration (deux entrées distinctes)

    @State private var isRestoringCard = false
    @State private var restoreError: String?

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Configuration")
            ListCard {
                // Entry 1 — always visible for main accounts: resume guided flow
                CardRow(showSeparator: setupVM.isDismissed) {
                    Button {
                        resumeConfiguration()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "checklist")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.bhVert)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reprendre ma configuration")
                                    .font(.system(size: 15.5))
                                    .foregroundStyle(Color.bhEncre)
                                Text("Continuer ou modifier la configuration")
                                    .font(.bhMeta)
                                    .foregroundStyle(Color.bhAttenue)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.bhAttenue.opacity(0.55))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                }

                // Entry 2 — only if the setup card has been dismissed
                if setupVM.isDismissed {
                    CardRow(showSeparator: false) {
                        Button {
                            Task { await restoreCard() }
                        } label: {
                            HStack(spacing: 14) {
                                if isRestoringCard {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .frame(width: 22)
                                } else {
                                    Image(systemName: "eye")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Color.bhAttenue)
                                        .frame(width: 22)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Réafficher le suivi de configuration")
                                        .font(.system(size: 15.5))
                                        .foregroundStyle(Color.bhEncre)
                                    if let err = restoreError {
                                        Text(err)
                                            .font(.bhMeta)
                                            .foregroundStyle(Color.bhTerracotta)
                                    } else {
                                        Text("Afficher la carte de suivi sur Aujourd'hui")
                                            .font(.bhMeta)
                                            .foregroundStyle(Color.bhAttenue)
                                    }
                                }
                                Spacer(minLength: 8)
                                if !isRestoringCard {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.bhAttenue.opacity(0.55))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isRestoringCard)
                        .frame(minHeight: 44)
                    }
                }
            }
        }
    }

    private func resumeConfiguration() {
        NotificationCenter.default.post(name: .navigateToToday, object: nil)
        // TECH DEBT: The 400ms delay is a workaround for the absence of a
        // SwiftUI sheet-dismiss-completion callback. AccountSheet dismisses
        // itself via NotificationCenter, leaving no synchronous hook.
        // Replace before release with a proper mechanism: observe a
        // pendingOnboardingAction flag in NotificationRouter from RootView's
        // sheet onDismiss callback, and trigger startManually() there.
        let steps = setupVM.steps
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            OnboardingCoordinator.shared.startManually(setupSteps: steps)
        }
    }

    private func restoreCard() async {
        isRestoringCard = true
        restoreError    = nil
        let start = Date()
        do {
            struct Body: Encodable { let preferences: Prefs }
            struct Prefs: Encodable { let setupCardDismissed: Bool }
            try await APIClient.shared.putVoid(
                Endpoint.userPreferences,
                body: Body(preferences: Prefs(setupCardDismissed: false))
            )
            NotificationCenter.default.post(name: .setupShouldRefresh, object: nil)
            NotificationCenter.default.post(name: .navigateToToday, object: nil)
        } catch {
            let elapsed = Date().timeIntervalSince(start)
            #if DEBUG
            debugLogPreferencesError(error, label: "restoreCard", elapsed: elapsed)
            #endif
            restoreError = "Impossible de réafficher la carte."
        }
        isRestoringCard = false
    }

#if DEBUG
    private func debugLogPreferencesError(_ error: Error, label: String, elapsed: TimeInterval) {
        let path = Endpoint.userPreferences.relativePath ?? Endpoint.userPreferences.absoluteString
        print("[Debug][\(label)][PUT \(path)] durée=\(String(format: "%.2f", elapsed))s")
        if let api = error as? APIError {
            switch api {
            case .network(let urlErr as URLError):
                print("  catégorie : réseau URLError")
                print("  code : \(urlErr.code.rawValue) — \(urlErr.localizedDescription)")
                print("  timeout : \(urlErr.code == .timedOut ? "oui" : "non")")
            case .network(let other):
                print("  catégorie : réseau (autre)")
                print("  erreur : \(other.localizedDescription)")
            case .server(let status, let msg):
                print("  catégorie : serveur HTTP \(status)")
                if let msg { print("  message : \(msg)") }
                print("  timeout : non")
            case .unauthorized:
                print("  catégorie : 401 non autorisé")
            default:
                print("  catégorie : \(api)")
            }
        } else {
            print("  catégorie : \(type(of: error)) — \(error.localizedDescription)")
        }
    }
#endif

    // MARK: - FAQ

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Questions fréquentes")
            let items = filteredFAQ
            if items.isEmpty {
                ListCard {
                    Text("Aucune question ne correspond à votre recherche.")
                        .font(.bhCorps)
                        .foregroundStyle(Color.bhAttenue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ListCard {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        CardRow(verticalPadding: 14, showSeparator: index < items.count - 1) {
                            FAQItemRow(
                                item: item,
                                isExpanded: expandedIDs.contains(item.id)
                            ) {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    if expandedIDs.contains(item.id) {
                                        expandedIDs.remove(item.id)
                                    } else {
                                        expandedIDs.insert(item.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Videos

    private var videosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Vidéos")
            ListCard {
                ForEach(Array(vm.videos.enumerated()), id: \.element.id) { index, video in
                    CardRow(showSeparator: index < vm.videos.count - 1) {
                        VideoItemRow(video: video)
                    }
                }
            }
        }
    }

    // MARK: - Guides

    private var guidesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Guides")
            VStack(spacing: 10) {
                ForEach(vm.guides) { guide in
                    GuideCard(guide: guide)
                }
            }
        }
    }

    // MARK: - Debug (DEBUG builds only)

#if DEBUG
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Développement")
            ListCard {
                CardRow(showSeparator: true) {
                    Button {
                        NotificationCenter.default.post(name: .navigateToToday, object: nil)
                        // TECH DEBT: 400ms fixed delay — see resumeConfiguration() comment.
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            OnboardingCoordinator.shared.previewFirstLaunch()
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.bhVert)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tester le premier démarrage")
                                    .font(.system(size: 15.5))
                                    .foregroundStyle(Color.bhEncre)
                                Text("Simule le premier lancement — sans persistance")
                                    .font(.bhMeta)
                                    .foregroundStyle(Color.bhAttenue)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.bhAttenue.opacity(0.55))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                }

                CardRow(showSeparator: false) {
                    Button {
                        NotificationCenter.default.post(name: .navigateToToday, object: nil)
                        // TECH DEBT: 400ms fixed delay — see resumeConfiguration() comment.
                        let steps = setupVM.steps
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            OnboardingCoordinator.shared.startManually(setupSteps: steps)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "checklist.checked")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.bhVert)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tester la configuration guidée")
                                    .font(.system(size: 15.5))
                                    .foregroundStyle(Color.bhEncre)
                                Text("Flow métier basé sur vos vraies données")
                                    .font(.bhMeta)
                                    .foregroundStyle(Color.bhAttenue)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.bhAttenue.opacity(0.55))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                }
            }
        }
    }
#endif

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.bhAttenue)
            .tracking(0.5)
    }

    // MARK: - Error

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Spacer(minLength: 40)
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(Color.bhAttenue)
            Text(msg)
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
            Button("Réessayer") { Task { await vm.load() } }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bhVert)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - FAQ item row

private struct FAQItemRow: View {
    let item: HelpFAQItem
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: 12) {
                    Text(item.question)
                        .font(.system(size: 15.5, weight: .medium))
                        .foregroundStyle(Color.bhEncre)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.bhAttenue)
                        .padding(.top, 3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(item.answerText)
                    .font(.bhCorps)
                    .foregroundStyle(Color(hex: "#5E6B63"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }
        }
    }
}

// MARK: - Video item row

private struct VideoItemRow: View {
    let video: HelpVideo

    var body: some View {
        Button {
            let urlStr = "https://www.youtube.com/watch?v=\(video.youtubeId)"
            guard let url = URL(string: urlStr) else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(Color.bhVert)
                    .frame(width: 26)
                Text(video.title)
                    .font(.system(size: 15.5, weight: .medium))
                    .foregroundStyle(Color.bhEncre)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.bhAttenue.opacity(0.55))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Guide card

private struct GuideCard: View {
    let guide: HelpGuide

    private var symbol: String {
        let slug = guide.pageUrl
            .trimmingCharacters(in: .init(charactersIn: "/"))
            .components(separatedBy: "/").last ?? ""
        switch slug {
        case "tuto-calendrier":       return "calendar"
        case "tuto-messages":         return "bubble.left.and.bubble.right"
        case "tuto-connecter-airbnb": return "link"
        case "tuto-bhguest":          return "house"
        default:                      return "doc.richtext"
        }
    }

    private var fullURL: URL? {
        let base = "https://www.boostinghost.fr/"
        let path = guide.pageUrl.hasPrefix("/") ? String(guide.pageUrl.dropFirst()) : guide.pageUrl
        return URL(string: base + path)
    }

    var body: some View {
        Button {
            guard let url = fullURL else { return }
            UIApplication.shared.open(url)
        } label: {
            ListCard {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: symbol)
                        .font(.system(size: 22))
                        .foregroundStyle(Color.bhVert)
                        .frame(width: 28)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(guide.title)
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundStyle(Color.bhEncre)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let desc = guide.description, !desc.isEmpty {
                            Text(desc)
                                .font(.bhCorps)
                                .foregroundStyle(Color(hex: "#5E6B63"))
                                .multilineTextAlignment(.leading)
                        }

                        let hasBadges = guide.timeLabel != nil || guide.badgeLabel != nil
                        if hasBadges {
                            HStack(spacing: 6) {
                                if let label = guide.timeLabel {
                                    HelpBadgePill(label: label, accent: false)
                                }
                                if let label = guide.badgeLabel {
                                    HelpBadgePill(label: label, accent: true)
                                }
                            }
                        }
                    }

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.bhAttenue.opacity(0.55))
                        .padding(.top, 3)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Badge pill

private struct HelpBadgePill: View {
    let label: String
    let accent: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(accent ? Color.bhVert : Color.bhAttenue)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(accent ? Color.bhVert.opacity(0.12) : Color.bhAttenue.opacity(0.12))
            }
    }
}
