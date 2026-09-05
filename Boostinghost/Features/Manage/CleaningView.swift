import SwiftUI

// MARK: - Segments

private enum CleaningPeriod: String, CaseIterable {
    case today   = "Aujourd'hui"
    case week    = "Semaine"
    case history = "Historique"
}

// MARK: - Écran Ménage

struct CleaningView: View {
    @Environment(AuthStore.self)       private var authStore
    @Environment(CalendarViewModel.self) private var calendarVM
    @Environment(\.dismiss)            private var dismiss
    @State private var vm     = CleaningViewModel()
    @State private var period: CleaningPeriod = .today

    private var session:      Session? { authStore.session }
    private var isSubAccount: Bool     { session?.isSubAccount == true }
    private var canManage:    Bool     { session?.can("can_manage_cleaning") ?? true }

    private var displaySuperTitle: String {
        switch period {
        case .today:
            return vm.superTitle
        case .week:
            let n = vm.weekCount
            return n > 0 ? "\(n) cette semaine" : " "
        case .history:
            return " "
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                switch period {
                case .today:   todayContent
                case .week:    weekContent
                case .history: historyContent
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.load(isSubAccount: isSubAccount, reservations: calendarVM.allReservations) }
        .sheet(isPresented: $vm.showRejectSheet) { rejectSheet }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                if !isSubAccount {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.bhVert)
                            .frame(width: 38, height: 38)
                            .glassEffect(in: .circle)
                            .specularEdge(cornerRadius: 19)
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(displaySuperTitle)
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                    Text("Ménage")
                        .bhGrandTitre()
                }
                .padding(.leading, isSubAccount ? 0 : 12)

                Spacer(minLength: 12)

                if !isSubAccount {
                    GlassCircleButton(icon: "plus") { }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 12)

            SegmentedGlass(
                options: CleaningPeriod.allCases.map { (label: $0.rawValue, value: $0) },
                selection: $period
            )
            .padding(.horizontal, 18)
            .padding(.bottom, period == .history && !vm.historyCleanerNames.isEmpty ? 8 : 14)

            if period == .history && !vm.historyCleanerNames.isEmpty {
                cleanerFilterBar
                    .padding(.bottom, 10)
            }
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Filtre intervenantes (onglet Historique)

    private var cleanerFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                cleanerChip("Tous", selected: vm.historyCleanerFilter == nil) {
                    vm.historyCleanerFilter = nil
                }
                ForEach(vm.historyCleanerNames, id: \.self) { name in
                    cleanerChip(name, selected: vm.historyCleanerFilter == name) {
                        vm.historyCleanerFilter = (vm.historyCleanerFilter == name) ? nil : name
                    }
                }
            }
            .padding(.horizontal, 18)
        }
    }

    @ViewBuilder
    private func cleanerChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if selected {
                Text(label)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.bhVert, in: Capsule())
            } else {
                Text(label)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.bhEncre)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .glassEffect(in: .rect(cornerRadius: 16))
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: selected)
    }

    // MARK: - Contenu Aujourd'hui

    @ViewBuilder
    private var todayContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                switch vm.loadState {
                case .idle, .loading:
                    loadingIndicator
                case .error(let msg):
                    errorContent(msg)
                case .loaded:
                    todayLoadedContent
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .refreshable { await vm.load(isSubAccount: isSubAccount, reservations: calendarVM.allReservations) }
    }

    @ViewBuilder
    private var todayLoadedContent: some View {
        ForEach(vm.tightAssignments) { a in
            AssignmentCard(assignment: a, isTight: true, canManage: canManage)
        }
        ForEach(vm.wideAssignments) { a in
            AssignmentCard(assignment: a, isTight: false, canManage: canManage)
        }

        if !vm.checklistsToValidate.isEmpty {
            SectionLabel(text: "À VALIDER").padding(.top, 4)
            ForEach(vm.checklistsToValidate) { cl in
                ValidateCard(
                    checklist: cl,
                    canManage: canManage,
                    onValidate: { Task { await vm.validate(checklist: cl) } },
                    onReject: {
                        vm.rejectTargetId  = cl.id
                        vm.rejectNotes     = ""
                        vm.showRejectSheet = true
                    }
                )
            }
        }

        if !isSubAccount && !vm.cleaners.isEmpty {
            SectionLabel(text: "INTERVENANTS").padding(.top, 4)
            ListCard {
                ForEach(Array(vm.cleaners.enumerated()), id: \.element.id) { idx, cleaner in
                    CardRow(showSeparator: idx < vm.cleaners.count - 1) {
                        CleanerRow(cleaner: cleaner)
                    }
                }
            }
        }

        if vm.tightAssignments.isEmpty && vm.wideAssignments.isEmpty && vm.checklistsToValidate.isEmpty {
            emptyState(label: "Aucun ménage aujourd'hui")
        }
    }

    // MARK: - Contenu Semaine

    @ViewBuilder
    private var weekContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                switch vm.loadState {
                case .idle, .loading:
                    loadingIndicator
                case .error(let msg):
                    errorContent(msg)
                case .loaded:
                    if vm.weekGroups.isEmpty {
                        emptyState(label: "Aucun ménage cette semaine")
                    } else {
                        ForEach(vm.weekGroups) { group in
                            Text(Formatters.day(group.dateStr))
                                .bhIntertitre()
                                .padding(.top, 4)
                            ForEach(group.tight) { a in
                                AssignmentCard(assignment: a, isTight: true,  canManage: false, isFuture: true)
                            }
                            ForEach(group.wide) { a in
                                AssignmentCard(assignment: a, isTight: false, canManage: false, isFuture: true)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .refreshable { await vm.load(isSubAccount: isSubAccount, reservations: calendarVM.allReservations) }
    }

    // MARK: - Contenu Historique

    @ViewBuilder
    private var historyContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                switch vm.loadState {
                case .idle, .loading:
                    loadingIndicator
                case .error(let msg):
                    errorContent(msg)
                case .loaded:
                    historyLoadedContent
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .refreshable { await vm.load(isSubAccount: isSubAccount, reservations: calendarVM.allReservations) }
    }

    @ViewBuilder
    private var historyLoadedContent: some View {
        if vm.historyTotalCount == 0 {
            emptyState(label: "Aucun ménage sur 30 jours")
        } else {
            historyBody
        }
    }

    @ViewBuilder
    private var historyBody: some View {
        let n = vm.historyTotalCount
        Text("\(n) ménage\(n == 1 ? "" : "s") sur 30 jours")
            .font(.bhCorps)
            .foregroundStyle(Color.bhAttenue)
            .frame(maxWidth: .infinity, alignment: .leading)

        if vm.filteredHistoryGroups.isEmpty {
            Text("Aucun résultat pour ce filtre")
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        } else {
            ForEach(vm.filteredHistoryGroups) { group in
                Text(Formatters.day(group.dateStr))
                    .bhIntertitre()
                    .padding(.top, 4)
                ListCard {
                    ForEach(Array(group.items.enumerated()), id: \.element.id) { idx, item in
                        CardRow(showSeparator: idx < group.items.count - 1) {
                            HistoryItemRow(item: item)
                        }
                    }
                }
            }
        }
    }

    // MARK: - États communs

    private var loadingIndicator: some View {
        HStack { Spacer(); ProgressView().tint(Color.bhAttenue); Spacer() }
            .padding(.top, 48)
    }

    private func errorContent(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(Color.bhAttenue)
            Text(msg)
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
            Button("Réessayer") {
                Task { await vm.load(isSubAccount: isSubAccount, reservations: calendarVM.allReservations) }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.bhVert)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private func emptyState(label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(Color.bhAttenue)
            Text(label)
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Feuille de rejet

    private var rejectSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Décrivez le problème pour l'intervenante.")
                    .font(.bhCorps)
                    .foregroundStyle(Color.bhAttenue)
                TextEditor(text: $vm.rejectNotes)
                    .frame(minHeight: 130)
                    .padding(12)
                    .background(
                        Color.white.opacity(0.65),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                Spacer()
            }
            .padding(20)
            .navigationTitle("Rejeter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { vm.showRejectSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Rejeter") {
                        guard let id = vm.rejectTargetId, !vm.rejectNotes.isEmpty,
                              let cl = vm.checklistsToValidate.first(where: { $0.id == id })
                        else { return }
                        vm.showRejectSheet = false
                        Task { await vm.reject(checklist: cl, notes: vm.rejectNotes) }
                    }
                    .disabled(vm.rejectNotes.isEmpty)
                    .foregroundStyle(Color.bhTerracotta)
                }
            }
        }
    }
}

// MARK: - Carte assignation (Aujourd'hui et Semaine)

private struct AssignmentCard: View {
    let assignment: CleaningAssignment
    let isTight:    Bool
    let canManage:  Bool
    var isFuture:   Bool = false

    @Environment(\.openURL) private var openURL

    var body: some View {
        if isTight { tightCard } else { wideCard }
    }

    private var tightCard: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.bhTerracotta)
                .frame(width: 4)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 22, bottomLeadingRadius: 22,
                        bottomTrailingRadius: 0, topTrailingRadius: 0
                    )
                )
            cardContent(accentColor: Color.bhTerracotta)
        }
        .background(Color.bhTerracottaBd, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var wideCard: some View {
        ListCard { cardContent(accentColor: Color.bhOccupe) }
    }

    private func cardContent(accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(assignment.resolvedPropertyName ?? assignment.propertyId ?? "—")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                    if let name = assignment.cleanerName, !name.isEmpty {
                        Text(name)
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhAttenue)
                    }
                }
                Spacer(minLength: 8)
                CleaningBadge(
                    label: isTight ? "SERRÉ" : "LARGE",
                    background: accentColor
                )
            }

            SlotGauge(
                windowStart: assignment.windowStart,
                windowEnd:   assignment.windowEnd,
                isTight:     isTight,
                isFuture:    isFuture
            )

            if !isFuture, let line = stateLine {
                Text(line)
                    .font(.system(size: 13.5, weight: isTight ? .semibold : .regular))
                    .foregroundStyle(isTight ? accentColor : Color.bhAttenue)
            }

            if canManage,
               let phone = assignment.cleanerPhone, !phone.isEmpty,
               let name  = assignment.cleanerName,  !name.isEmpty {
                callButton(name: name, phone: phone)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stateLine: String? {
        let statusText: String
        switch assignment.status ?? "pending" {
        case "in_progress": statusText = "En cours"
        case "completed":   statusText = "Terminé"
        default:            statusText = "Pas commencé"
        }
        if let d = slotDuration {
            let h   = Int(d / 3600)
            let m   = Int((d.truncatingRemainder(dividingBy: 3600)) / 60)
            let dur = m == 0 ? "\(h)\u{00A0}h de créneau" : "\(h)\u{00A0}h \(m) de créneau"
            return "\(statusText) · \(dur)"
        }
        if !isTight { return "\(statusText) · aucune arrivée avant demain" }
        return statusText
    }

    private var slotDuration: TimeInterval? {
        CleaningAssignment.slotDuration(start: assignment.windowStart, end: assignment.windowEnd)
    }

    private func callButton(name: String, phone: String) -> some View {
        Button {
            let cleaned = phone.filter { $0.isNumber || $0 == "+" }
            if let url = URL(string: "tel:\(cleaned)") { openURL(url) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "phone")
                    .font(.system(size: 13, weight: .semibold))
                Text("Appeler \(name)")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.bhVert, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Jauge de créneau

private struct SlotGauge: View {
    let windowStart: String?
    let windowEnd:   String?
    let isTight:     Bool
    var isFuture:    Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Text(formatted(windowStart) ?? "—")
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
                .frame(minWidth: 36, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.bhAttenue.opacity(0.15))
                    Capsule()
                        .fill(isTight ? Color.bhTerracotta : Color.bhOccupe)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)

            Text(formatted(windowEnd) ?? "demain")
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
                .frame(minWidth: 36, alignment: .leading)
        }
    }

    private var progress: Double {
        guard !isFuture,
              let s = CleaningAssignment.parseWindowTime(windowStart),
              let e = CleaningAssignment.parseWindowTime(windowEnd),
              e > s else { return 0 }
        let p = Date().timeIntervalSince(s) / e.timeIntervalSince(s)
        return max(0, min(1, p))
    }

    private func formatted(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let hhmm = raw.contains("T")
            ? String(raw.components(separatedBy: "T").last?.prefix(5) ?? "")
            : raw
        return Formatters.time(hhmm)
    }
}

// MARK: - Ligne Historique

private struct HistoryItemRow: View {
    let item: CleaningHistoryItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.propertyName ?? "—")
                    .font(.system(size: 15.5, weight: .medium))
                    .foregroundStyle(Color.bhEncre)
                if let name = item.cleanerName, !name.isEmpty {
                    Text(name)
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                }
            }
            Spacer(minLength: 8)
            statusPill
        }
    }

    private var statusPill: some View {
        let (text, style, icon): (String, PillStyle, String?) = {
            switch item.checklistStatus {
            case "validated": return ("Validé",        .vert,       "checkmark.circle.fill")
            case "rejected":  return ("Rejeté",        .terracotta, "xmark.circle.fill")
            case "completed": return ("À valider",     .or,         "clock.fill")
            default:          return ("Pas de retour", .neutre,     nil)
            }
        }()
        return StatusPill(text: text, style: style, icon: icon)
    }
}

// MARK: - Carte À VALIDER

private struct ValidateCard: View {
    let checklist:  CleaningChecklist
    let canManage:  Bool
    let onValidate: () -> Void
    let onReject:   () -> Void

    var body: some View {
        ListCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(checklist.resolvedPropertyName ?? checklist.propertyId ?? "—")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)

                Text(completionLabel)
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)

                if canManage {
                    HStack(spacing: 10) {
                        Button(action: onValidate) {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                Text("Valider")
                                    .font(.system(size: 14.5, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color.bhVert, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(action: onReject) {
                            Text("Rejeter")
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundStyle(Color.bhTerracotta)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .glassEffect(in: .rect(cornerRadius: 20))
                                .specularEdge(cornerRadius: 20)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var completionLabel: String {
        let n         = checklist.photoCount
        let photoPart = n > 0 ? " · \(n) photo\(n == 1 ? "" : "s")" : ""

        guard let iso  = checklist.completedAt else { return "Terminé\(photoPart)" }
        guard let date = Self.parseISO(iso)    else { return "Terminé\(photoPart)" }

        let cal = Calendar.current
        let h   = cal.component(.hour,   from: date)
        let m   = cal.component(.minute, from: date)
        let t   = m == 0
            ? "\(h)\u{00A0}h"
            : "\(h)\u{00A0}h\u{00A0}\(String(format: "%02d", m))"

        if cal.isDateInToday(date)     { return "Terminé aujourd'hui \(t)\(photoPart)" }
        if cal.isDateInYesterday(date) { return "Terminé hier \(t)\(photoPart)" }
        return "Terminé \(Formatters.day(date))\(photoPart)"
    }

    private static func parseISO(_ raw: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: raw) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: raw)
    }
}

// MARK: - Ligne intervenant

private struct CleanerRow: View {
    let cleaner: CleanerItem

    var body: some View {
        HStack(spacing: 12) {
            initialsCircle

            VStack(alignment: .leading, spacing: 2) {
                Text(cleaner.name)
                    .font(.system(size: 15.5, weight: .medium))
                    .foregroundStyle(Color.bhEncre)
                Text(subtitle)
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
            }

            Spacer(minLength: 4)

            if !cleaner.isActive {
                Text("Inactif")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
            }
        }
    }

    private var initialsCircle: some View {
        let words   = cleaner.name.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first.map(String.init) }.joined().uppercased()
        return ZStack {
            Circle()
                .fill(Color(hex: "#DCE8E1"))
                .frame(width: 40, height: 40)
            Text(letters.isEmpty ? "?" : letters)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bhVert)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if cleaner.subAccountId != nil { parts.append("sous-compte actif") }
        if cleaner.smsRecapEnabled     { parts.append("SMS activé") }
        return parts.isEmpty ? "intervenant" : parts.joined(separator: " · ")
    }
}

// MARK: - Badge SERRÉ / LARGE

private struct CleaningBadge: View {
    let label:      String
    let background: Color

    var body: some View {
        Text(label)
            .font(.system(size: 10.5, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
    }
}
