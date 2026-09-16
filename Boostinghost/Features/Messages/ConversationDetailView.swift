import SwiftUI

// MARK: - Fil de conversation

struct ConversationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MessagesViewModel.self) private var messagesVM

    @State private var vm: ConversationDetailViewModel
    @State private var showUpsellSheet    = false
    @State private var showTemplateSheet  = false
    @State private var showNoteSheet      = false
    @State private var showHandBackAlert  = false

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
        .toolbar(.hidden, for: .tabBar)
        .task {
            await messagesVM.markConversationRead(vm.conversation.id)
            await vm.load()
        }
        .alert("Erreur", isPresented: Binding(
            get: { vm.sendError != nil },
            set: { if !$0 { vm.sendError = nil } }
        )) {
            Button("OK") { vm.sendError = nil }
        } message: {
            Text(vm.sendError ?? "")
        }
        .sheet(isPresented: $showUpsellSheet) {
            UpsellSheet(conversationId: vm.conversation.id)
        }
        .sheet(isPresented: $showTemplateSheet) {
            TemplatePickerSheet(conversation: vm.conversation, vm: vm)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showNoteSheet) {
            NoteSheet(vm: vm)
                .presentationDetents([.medium, .large])
        }
        .alert("Aucune caution", isPresented: Binding(
            get: { vm.depositUnavailable },
            set: { if !$0 { vm.clearDepositUnavailable() } }
        )) {
            Button("OK") { vm.clearDepositUnavailable() }
        } message: {
            Text("Aucune caution configurée pour ce logement.")
        }
        .alert("Lien de caution", isPresented: Binding(
            get: { vm.depositLink != nil },
            set: { if !$0 { vm.clearDepositLink() } }
        )) {
            Button("Coller dans le message") { vm.confirmPasteDepositLink() }
            Button("Annuler", role: .cancel) { vm.clearDepositLink() }
        } message: {
            if let cents = vm.depositAmountCents {
                Text("Caution de \(Formatters.amount(Double(cents) / 100.0)). Coller le lien dans le message ?")
            } else {
                Text("Coller le lien de caution dans le message ?")
            }
        }
        .alert("Rendre la conversation à l'IA ?", isPresented: $showHandBackAlert) {
            Button("Rendre à l'IA") { Task { await takeOverAndSync() } }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("L'IA répondra de nouveau automatiquement.")
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

            Menu {
                Button {
                    showUpsellSheet = true
                } label: {
                    Label("Prestation payante", systemImage: "creditcard")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
                    .frame(width: 36, height: 36)
                    .glassEffect(in: .circle)
                    .specularEdge(cornerRadius: 18)
            }
            .buttonStyle(.plain)

            if vm.isEscalated {
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
        let lastSentId = vm.messages.last(where: { $0.isOutgoing })?.id
        return ScrollViewReader { proxy in
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
                            MessageBubbleView(
                                message: msg,
                                isLastSent: msg.id == lastSentId,
                                onRetry: (msg.isOutgoing && msg.delivered == false && msg.deliveryError?.isEmpty == false)
                                    ? { vm.retryMessage(msg) } : nil
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 6)
                            .id(msg.id)
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: vm.messages.count) { old, new in
                guard new > 0, let lastId = vm.messages.last?.id else { return }
                if old == 0 {
                    // Initial load: defaultScrollAnchor may not anchor correctly when
                    // LazyVStack content appears after the ScrollView was already created
                    // (messages loaded asynchronously). Scroll explicitly without animation.
                    proxy.scrollTo(lastId, anchor: .bottom)
                } else if new > old {
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
            } else {
                if let resumeDate = vm.aiResumeDate {
                    aiPauseBanner(resumeDate: resumeDate)
                }
                actionBar
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

                Button { Task { await sendAndSync() } } label: {
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

    // MARK: - Suggestion chip (brouillon IA)

    private var suggestionChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
            Text("Brouillon IA")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Button { vm.dismissSuggestion(); syncSuggestionDismissed() } label: {
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

    // MARK: - Barre d'actions (Reprendre · Template · Note)

    private var actionBar: some View {
        HStack(spacing: 0) {
            actionButton(
                icon: "hand.raised.fill",
                label: vm.isAiDisabled ? "Vous gérez" : "Reprendre",
                color: vm.isAiDisabled ? Color.bhVert : (vm.isEscalated ? Color.bhOr : Color.bhAttenue),
                disabled: false
            ) {
                if vm.isAiDisabled {
                    showHandBackAlert = true
                } else {
                    Task { await takeOverAndSync() }
                }
            }

            Divider()
                .frame(height: 28)
                .opacity(0.4)

            actionButton(
                icon: "bolt.fill",
                label: "Template",
                color: Color.bhVert,
                disabled: vm.conversation.propertyId == nil
            ) {
                showTemplateSheet = true
            }

            Divider()
                .frame(height: 28)
                .opacity(0.4)

            actionButton(
                icon: "note.text",
                label: "Note",
                color: Color.bhVert,
                disabled: vm.noteUid == nil,
                badge: vm.currentNote != nil
            ) {
                showNoteSheet = true
            }

            if !vm.isAirbnb {
                Divider()
                    .frame(height: 28)
                    .opacity(0.4)

                actionButton(
                    icon: "lock.fill",
                    label: "Caution",
                    color: Color.bhVert,
                    disabled: false,
                    loading: vm.isDepositLoading
                ) {
                    Task { await vm.fetchDepositLink() }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.18))
        .overlay(alignment: .bottom) { Divider().opacity(0.4) }
    }

    @ViewBuilder
    private func actionButton(
        icon: String,
        label: String,
        color: Color,
        disabled: Bool,
        badge: Bool = false,
        loading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    if loading {
                        ProgressView()
                            .frame(width: 18, height: 18)
                            .tint(color)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                        if badge {
                            Circle()
                                .fill(Color.bhOr)
                                .frame(width: 7, height: 7)
                                .offset(x: 4, y: -2)
                        }
                    }
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled || loading)
        .opacity(disabled ? 0.35 : 1)
    }
    // MARK: - Sync vers la liste Messages

    private func sendAndSync() async {
        let wasSuggestionActive = vm.suggestionActive
        await vm.send()
        // send() clears draftText on success; use that as the success signal
        if vm.sendError == nil {
            if wasSuggestionActive {
                messagesVM.updateConversation(vm.conversation.id) { $0.hasSuggestion = false }
            }
            // After a manual reply while escalated+paused, AI is re-enabled by send()
            messagesVM.updateConversation(vm.conversation.id) {
                $0.escalated  = vm.isEscalated
                $0.aiDisabled = vm.isAiDisabled
            }
        }
    }

    private func takeOverAndSync() async {
        await vm.takeOver()
        messagesVM.updateConversation(vm.conversation.id) {
            $0.escalated  = vm.isEscalated
            $0.aiDisabled = vm.isAiDisabled
        }
    }

    private func syncSuggestionDismissed() {
        messagesVM.updateConversation(vm.conversation.id) { $0.hasSuggestion = false }
    }

    // MARK: - Décompte pause IA

    @ViewBuilder
    private func aiPauseBanner(resumeDate: Date) -> some View {
        SwiftUI.TimelineView(.periodic(from: Date(), by: 60)) { ctx in
            let remaining = resumeDate.timeIntervalSince(ctx.date)
            if remaining > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(formatAiPauseRemaining(remaining))
                        .font(.system(size: 12))
                }
                .foregroundStyle(Color.bhAttenue)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) { Divider().opacity(0.4) }
            }
        }
    }

    private func formatAiPauseRemaining(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 {
            return "L'IA reprend dans \(h) h \(String(format: "%02d", m))"
        }
        return "L'IA reprend dans \(m) min"
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
    let isLastSent: Bool
    let onRetry: (() -> Void)?

    @State private var showErrorAlert = false
    private var isOwner: Bool { message.isOutgoing }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isOwner { Spacer(minLength: 0) }

            VStack(alignment: isOwner ? .trailing : .leading, spacing: 3) {
                if message.isSystem {
                    systemMessage
                } else {
                    bubble
                }

                originCapsule
                deliveryStatus

                Text(formattedTime)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.bhAttenue)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.78,
                   alignment: isOwner ? .trailing : .leading)

            if !isOwner { Spacer(minLength: 0) }
        }
        .alert("Erreur de transmission", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(message.deliveryError ?? "")
        }
    }

    // MARK: - Marqueur de livraison

    @ViewBuilder
    private var deliveryStatus: some View {
        if isOwner, !message.isSystem {
            if message.delivered == false, message.deliveryError?.isEmpty == false {
                HStack(spacing: 8) {
                    Button { showErrorAlert = true } label: {
                        Text("Non transmis")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.bhTerracotta)
                    }
                    .buttonStyle(.plain)
                    if let retry = onRetry {
                        Button("Réessayer", action: retry)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Color.bhTerracotta)
                    }
                }
                .padding(.horizontal, 4)
            } else if message.delivered == true, isLastSent {
                Text("Délivré")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.bhAttenue)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Marqueur d'origine (sortants automatiques uniquement)

    @ViewBuilder
    private var originCapsule: some View {
        if message.isBot {
            automationLabel(icon: "sparkles", text: "Répondu par l'IA")
        } else if message.isTemplate {
            automationLabel(icon: "bolt.fill", text: "Réponse automatique")
        }
    }

    private func automationLabel(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.bhVert.opacity(0.82)))
    }

    private var bubble: some View {
        Text(linkifiedText)
            .multilineTextAlignment(.leading)
            .font(.system(size: 15))
            .foregroundStyle(Color.bhEncre)
            .textSelection(.enabled)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackground)
            .contextMenu {
                Button {
                    UIPasteboard.general.string = message.message
                } label: {
                    Label("Copier le message", systemImage: "doc.on.doc")
                }
            }
    }

    // Détection des URLs, emails et numéros de téléphone via NSDataDetector.
    // Le static évite de réinstancier le détecteur à chaque rendu.
    private static let linkDetector: NSDataDetector? = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
             | NSTextCheckingResult.CheckingType.phoneNumber.rawValue
    )

    private var linkifiedText: AttributedString {
        let plain = message.message
        var result = AttributedString(plain)
        guard let detector = Self.linkDetector else { return result }

        let matches = detector.matches(in: plain, options: [],
                                        range: NSRange(plain.startIndex..., in: plain))
        for match in matches {
            // NSRange (UTF-16) → Swift String.Index range → grapheme-cluster counts
            guard let stringRange = Range(match.range, in: plain) else { continue }
            let prefixCount = plain[plain.startIndex..<stringRange.lowerBound].count
            let matchCount  = plain[stringRange].count
            let lower = result.index(result.startIndex, offsetByCharacters: prefixCount)
            let upper = result.index(lower,             offsetByCharacters: matchCount)
            let attrRange = lower..<upper

            if let url = match.url {
                result[attrRange].link = url
            } else if let phone = match.phoneNumber {
                result[attrRange].link = URL(string: "tel:\(phone)")
            }
            // bhOccupe (#2E8B62) : ~3,86:1 sur blanc, ~3,10:1 sur #DCE8E1 — soulignement requis.
            result[attrRange].foregroundColor = Color.bhOccupe
            result[attrRange].underlineStyle  = Text.LineStyle(pattern: .solid, color: Color.bhOccupe)
        }
        return result
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
