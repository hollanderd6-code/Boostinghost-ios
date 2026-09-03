import SwiftUI

// MARK: - Fil de conversation

struct ConversationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.tabBarHidden) private var tabBarHidden

    @State private var vm: ConversationDetailViewModel

    init(conversation: Conversation, ownerName: String) {
        _vm = State(wrappedValue: ConversationDetailViewModel(
            conversation: conversation, ownerName: ownerName
        ))
    }

    var body: some View {
        ZStack {
            AppBackground()
            messageArea
        }
        .safeAreaInset(edge: .top, spacing: 0) { navBar }
        .safeAreaInset(edge: .bottom, spacing: 0) { inputBar }
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.load() }
        .onAppear  { withAnimation(.easeInOut(duration: 0.2)) { tabBarHidden.wrappedValue = true  } }
        .onDisappear { withAnimation(.easeInOut(duration: 0.2)) { tabBarHidden.wrappedValue = false } }
        .alert("Erreur", isPresented: Binding(
            get: { vm.sendError != nil },
            set: { if !$0 { vm.sendError = nil } }
        )) {
            Button("OK") { vm.sendError = nil }
        } message: {
            Text(vm.sendError ?? "")
        }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
                    .frame(width: 36, height: 36)
                    .glassEffect(in: .circle)
                    .specularEdge(cornerRadius: 18)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(vm.conversation.guestDisplayName ?? "—")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                    .lineLimit(1)
                let sub = [
                    vm.conversation.propertyName,
                    vm.conversation.platform.map { Color.platformLabel($0) }
                ].compactMap { $0 }.joined(separator: " · ")
                if !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if vm.conversation.aiDisabled == true {
                StatusPill(text: "IA en pause", style: .neutre)
            }
            if vm.conversation.escalated == true {
                StatusPill(text: "À reprendre", style: .or, icon: "sparkles")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Zone de messages

    @ViewBuilder
    private var messageArea: some View {
        switch vm.loadState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let msg):
            VStack(spacing: 12) {
                Text(msg)
                    .font(.bhCorps)
                    .foregroundStyle(Color.bhAttenue)
                    .multilineTextAlignment(.center)
                Button("Réessayer") { Task { await vm.load() } }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            loadedList
        }
    }

    private var loadedList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if vm.messages.isEmpty {
                        Text("Aucun message dans cette conversation.")
                            .font(.bhCorps)
                            .foregroundStyle(Color.bhAttenue)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.top, 40)
                    }
                    ForEach(groupedMessages, id: \.dayKey) { group in
                        DateSeparatorView(label: group.dayLabel)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                        ForEach(group.messages) { msg in
                            MessageBubbleView(message: msg)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 6)
                                .id(msg.id)
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .onChange(of: vm.messages.count) { old, new in
                guard let lastId = vm.messages.last?.id else { return }
                if old == 0 {
                    // Laisse un cycle au safe area pour se stabiliser avant le scroll initial.
                    Task { @MainActor in proxy.scrollTo(lastId, anchor: .bottom) }
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Groupement par jour

    private struct DayGroup: Identifiable {
        let dayKey: String     // "yyyy-MM-dd" — stable pour ForEach
        let dayLabel: String
        let messages: [Message]
        var id: String { dayKey }
    }

    private var groupedMessages: [DayGroup] {
        var result: [DayGroup] = []
        var currentKey = ""
        var currentMsgs: [Message] = []

        for msg in vm.messages {
            let date = parseISO(msg.createdAt) ?? Date()
            let key = dayKey(date)
            if key == currentKey {
                currentMsgs.append(msg)
            } else {
                if !currentMsgs.isEmpty {
                    result.append(DayGroup(
                        dayKey: currentKey,
                        dayLabel: dayLabel(for: currentKey),
                        messages: currentMsgs
                    ))
                }
                currentKey = key
                currentMsgs = [msg]
            }
        }
        if !currentMsgs.isEmpty {
            result.append(DayGroup(
                dayKey: currentKey,
                dayLabel: dayLabel(for: currentKey),
                messages: currentMsgs
            ))
        }
        return result
    }

    private let isoDay: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"; return f
    }()

    private func parseISO(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: raw) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: raw)
    }

    private func dayKey(_ date: Date) -> String { isoDay.string(from: date) }

    private func dayLabel(for key: String) -> String {
        guard let date = isoDay.date(from: key) else { return key }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Aujourd'hui" }
        if cal.isDateInYesterday(date) { return "Hier" }
        let raw = Formatters.day(date)
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    // MARK: - Barre de saisie

    private var inputBar: some View {
        VStack(spacing: 0) {
            if vm.suggestionActive {
                suggestionChip
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Saisir un message…", text: $vm.draftText, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(1...6)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.62))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
                            }
                    )

                Button { Task { await vm.send() } } label: {
                    if vm.isSending {
                        ProgressView()
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.bhVert, in: Circle())
                    }
                }
                .buttonStyle(.plain)
                .disabled(vm.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSending)
                .opacity(vm.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.40 : 1)
                .animation(.easeInOut(duration: 0.15), value: vm.draftText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.white.opacity(0.28))
                .overlay(alignment: .top) { Divider().opacity(0.4) }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var suggestionChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
            Text("Brouillon IA")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Button { vm.dismissSuggestion() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.bhAttenue)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Color.bhOr)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.bhOrFond)
        .overlay(alignment: .bottom) { Divider().opacity(0.3) }
    }
}

// MARK: - Séparateur de date

private struct DateSeparatorView: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.bhAttenue)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Bulle de message

private struct MessageBubbleView: View {
    let message: Message

    private var isOwner: Bool { message.isFromOwner }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isOwner { Spacer(minLength: 0) }

            VStack(alignment: isOwner ? .trailing : .leading, spacing: 3) {
                if message.isBot {
                    Label("Réponse IA", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.bhAttenue)
                        .padding(.horizontal, 2)
                }

                if message.isSystem {
                    systemMessage
                } else {
                    bubble
                }

                Text(formattedTime)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.bhAttenue)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.78,
                   alignment: isOwner ? .trailing : .leading)

            if !isOwner { Spacer(minLength: 0) }
        }
    }

    private var bubble: some View {
        Text(message.message)
            .multilineTextAlignment(.leading)
            .font(.system(size: 15))
            .foregroundStyle(Color.bhEncre)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackground)
    }

    private var bubbleBackground: some View {
        Group {
            if isOwner {
                UnevenRoundedRectangle(
                    topLeadingRadius: 18, bottomLeadingRadius: 18,
                    bottomTrailingRadius: 4, topTrailingRadius: 18,
                    style: .continuous
                )
                .fill(Color.white.opacity(0.80))
                .overlay {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 18, bottomLeadingRadius: 18,
                        bottomTrailingRadius: 4, topTrailingRadius: 18,
                        style: .continuous
                    )
                    .stroke(Color.white.opacity(0.60), lineWidth: 1)
                }
            } else {
                UnevenRoundedRectangle(
                    topLeadingRadius: 4, bottomLeadingRadius: 18,
                    bottomTrailingRadius: 18, topTrailingRadius: 18,
                    style: .continuous
                )
                .fill(Color(hex: "#DCE8E1"))
            }
        }
    }

    private var systemMessage: some View {
        Text(message.message)
            .font(.system(size: 13))
            .foregroundStyle(Color.bhAttenue)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.40))
                    .overlay { Capsule().stroke(Color.white.opacity(0.40), lineWidth: 1) }
            )
            .frame(maxWidth: .infinity)
    }

    private var formattedTime: String {
        guard let raw = message.createdAt else { return "" }
        guard let date = parseISO(raw) else { return "" }
        let hhmm = Self.hmFormatter.string(from: date)
        return Formatters.time(hhmm) ?? hhmm
    }

    private func parseISO(_ raw: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: raw) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: raw)
    }

    private static let hmFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "HH:mm"
        return f
    }()
}
