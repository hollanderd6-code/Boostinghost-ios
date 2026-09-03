import SwiftUI

// MARK: - Écran Messages

struct MessagesView: View {
    @Environment(AuthStore.self) var authStore

    @State private var vm = MessagesViewModel()
    @State private var showAccount = false

    var body: some View {
        NavigationStack {
            Group {
                switch vm.state {
                case .idle, .loading:
                    loadingView
                case .error(let msg):
                    errorView(msg)
                case .loaded:
                    loadedList
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { navBar }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Conversation.self) { conv in
                ConversationDetailView(
                    conversation: conv,
                    ownerName: authStore.session?.displayName ?? ""
                )
            }
        }
        .refreshable { await reload() }
        .task { await reload() }
        .onChange(of: authStore.agencyContext) { Task { await reload() } }
        .sheet(isPresented: $showAccount) {
            AccountSheet()
        }
    }

    private func reload() async {
        vm.agencyAll = authStore.agencyAll
        await vm.load()
    }

    // MARK: - Barre de navigation + filtres

    private var navBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 1) {
                    if !vm.superTitle.isEmpty {
                        Text(vm.superTitle)
                            .font(.bhSurTitre)
                            .foregroundStyle(Color.bhAttenue)
                    }
                    Text("Messages")
                        .bhGrandTitre()
                }
                Spacer(minLength: 12)
                HStack(spacing: 10) {
                    GlassCircleButton(icon: "magnifyingglass") { }
                    InitialsButton {
                        showAccount = true
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 12)

            filterStrip
                .padding(.horizontal, 18)
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

    // MARK: - Bandeau de filtres

    private var filterStrip: some View {
        HStack(spacing: 6) {
            FilterPill(
                label: "Tous",
                isSelected: vm.filter == .tous,
                style: .standard
            ) { vm.filter = .tous }

            FilterPill(
                label: vm.unreadCount > 0 ? "Non lus · \(vm.unreadCount)" : "Non lus",
                isSelected: vm.filter == .nonLus,
                style: .standard
            ) { vm.filter = .nonLus }

            FilterPill(
                label: vm.escalatedCount > 0 ? "À reprendre · \(vm.escalatedCount)" : "À reprendre",
                isSelected: vm.filter == .aReprendre,
                style: .or
            ) { vm.filter = .aReprendre }
        }
    }

    // MARK: - Liste chargée

    private var loadedList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(vm.filtered) { conversation in
                    NavigationLink(value: conversation) {
                        ConversationRow(conversation: conversation)
                            .padding(.horizontal, 18)
                    }
                    .buttonStyle(.plain)
                }

                if vm.filtered.isEmpty {
                    Text("Aucune conversation dans cette catégorie.")
                        .font(.bhCorps)
                        .foregroundStyle(Color.bhAttenue)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 40)
                        .padding(.horizontal, 18)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - États

    private var loadingView: some View {
        ScrollView {
            HStack { Spacer(); ProgressView(); Spacer() }
                .padding(.top, 60)
        }
    }

    private func errorView(_ msg: String) -> some View {
        ScrollView {
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
            .padding(.top, 60)
            .padding(.horizontal, 18)
        }
    }
}

// MARK: - Pilule de filtre

private struct FilterPill: View {
    enum Style { case standard, or }

    let label: String
    let isSelected: Bool
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(textColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(background)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }

    private var textColor: Color {
        switch style {
        case .or:       return .bhOr
        case .standard: return isSelected ? .bhEncre : .bhAttenue
        }
    }

    @ViewBuilder
    private var background: some View {
        let r: CGFloat = 13
        switch style {
        case .or:
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(Color(red: 251/255, green: 243/255, blue: 226/255)
                    .opacity(isSelected ? 0.92 : 0.72))
                .overlay {
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .stroke(Color(hex: "#C9A15B").opacity(isSelected ? 0.40 : 0.20), lineWidth: 1)
                }
        case .standard:
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.88) : Color.white.opacity(0.25))
                .overlay {
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .stroke(Color.white.opacity(0.50), lineWidth: 1)
                }
        }
    }
}

// MARK: - Ligne de conversation

private struct ConversationRow: View {
    let conversation: Conversation

    private var isUnread: Bool    { (conversation.unreadCount ?? 0) > 0 }
    private var isEscalated: Bool { conversation.escalated == true }
    private var isAiDisabled: Bool { conversation.aiDisabled == true }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            guestAvatar
            VStack(alignment: .leading, spacing: 4) {
                topRow
                contextLine
                excerptView
                badgeRow
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 16)
        .background { cardBackground }
    }

    // MARK: - Rond d'initiales

    private var guestAvatar: some View {
        let bg  = isEscalated ? Color(hex: "#FBEAE4") : Color(hex: "#DCE8E1")
        let fg  = isEscalated ? Color.bhTerracotta : Color.bhVert
        let txt = conversation.guestInitial
            ?? conversation.guestDisplayName?.first.map(String.init)
            ?? "?"
        return Text(txt.uppercased())
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(fg)
            .frame(width: 46, height: 46)
            .background(bg, in: Circle())
    }

    // MARK: - Rangée haute : nom + horodatage + point

    private var topRow: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(conversation.guestDisplayName ?? "—")
                .font(.system(size: 16.5, weight: isUnread ? .semibold : .medium))
                .foregroundStyle(isUnread ? Color.bhEncre : Color.bhCorps)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(formattedTimestamp)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.bhAttenue)
                .lineLimit(1)
            if isUnread {
                Circle()
                    .fill(isEscalated ? Color.bhTerracotta : Color.bhVert)
                    .frame(width: 9, height: 9)
            }
        }
    }

    // MARK: - Ligne de contexte : logement · arrive aujourd'hui · Booking

    private var contextLine: some View {
        let parts = [
            conversation.propertyName,
            arrivalText,
            conversation.platform.map { Color.platformLabel($0) }
        ].compactMap { $0 }.filter { !$0.isEmpty }
        return Text(parts.joined(separator: " · "))
            .font(.system(size: 12.5))
            .foregroundStyle(Color.bhAttenue)
            .lineLimit(1)
    }

    private var arrivalText: String? {
        guard let iso = conversation.reservationStartDate else { return nil }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "Europe/Paris")
        guard let date = df.date(from: String(iso.prefix(10))) else { return nil }
        if Calendar.current.isDateInToday(date)    { return "arrive aujourd'hui" }
        if Calendar.current.isDateInTomorrow(date) { return "arrive demain" }
        return nil
    }

    // MARK: - Extrait (2 lignes max)

    private var excerptView: some View {
        Text(conversation.lastMessage ?? "")
            .font(.system(size: 14))
            .foregroundStyle(isUnread ? Color.bhCorps : Color.bhAttenue)
            .lineLimit(2)
    }

    // MARK: - Pastilles

    @ViewBuilder
    private var badgeRow: some View {
        let showSuggestion = conversation.hasSuggestion == true
        if showSuggestion || isAiDisabled {
            HStack(spacing: 6) {
                if showSuggestion {
                    StatusPill(text: "Brouillon prêt", style: .or, icon: "sparkles")
                }
                if isAiDisabled {
                    StatusPill(text: "IA en pause", style: .neutre)
                }
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Fond de carte

    private var cardBackground: some View {
        GlassCardBackground(cornerRadius: 22, fillOpacity: isUnread ? 0.72 : 0.50)
            .overlay {
                if isEscalated {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.bhTerracottaBd, lineWidth: 1)
                }
            }
    }

    // MARK: - Horodatage contextuel

    private var formattedTimestamp: String {
        guard let raw = conversation.lastMessageTime, !raw.isEmpty else { return "" }
        guard let date = parseISO(raw) else { return "" }
        let cal = Calendar.current
        let now = Date()
        if cal.isDateInToday(date) {
            let hhmm = Self.hm.string(from: date)
            return Formatters.time(hhmm) ?? hhmm
        }
        if cal.isDateInYesterday(date) { return "hier" }
        if let days = cal.dateComponents([.day], from: date, to: now).day, days < 7 {
            return String(Self.wd.string(from: date).prefix(3)).lowercased() + "."
        }
        return Self.sd.string(from: date).lowercased()
    }

    // Un seul exemplaire de chaque formatter pour toutes les lignes
    private static let hm: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let wd: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE"
        return f
    }()

    private static let sd: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMM"
        return f
    }()

    private func parseISO(_ raw: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: raw) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: raw)
    }
}
