import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
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
                    if !vm.faq.isEmpty { faqSection }
                    if !vm.videos.isEmpty { videosSection }
                    if !vm.guides.isEmpty { guidesSection }
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
