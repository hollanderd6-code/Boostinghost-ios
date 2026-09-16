import SwiftUI
import UIKit

// MARK: - Écran ménage (détail)

struct ChecklistDetailView: View {
    @Environment(\.dismiss)      private var dismiss
    @Environment(AuthStore.self) private var authStore

    let ref: CleaningDetailRef
    var canManage: Bool = true
    var onChanged: (() -> Void)? = nil

    @State private var vm                  = ChecklistDetailViewModel()
    @State private var fullscreenPhoto:    FullscreenPhoto? = nil
    @State private var shareItemsToPresent: [Any] = []
    @State private var presentingShareSheet = false
    @State private var isPreparingShare    = false
    @State private var shareError:          String? = nil

    private var isSubAccount: Bool { authStore.session?.isSubAccount == true }

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                mainContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.load(ref: ref, isSubAccount: isSubAccount) }
        .sheet(isPresented: $vm.showRejectSheet) { rejectSheet }
        .sheet(item: $fullscreenPhoto) { item in
            PhotoViewerSheet(dataURI: item.dataURI)
        }
        .sheet(isPresented: $presentingShareSheet) {
            ShareSheet(activityItems: shareItemsToPresent)
        }
        .alert("Erreur", isPresented: Binding(
            get: { shareError != nil },
            set: { if !$0 { shareError = nil } }
        )) {
            Button("OK") { shareError = nil }
        } message: {
            Text(shareError ?? "")
        }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        let surTitre: String = {
            if let d = vm.detail?.checkoutDate { return Formatters.day(d) }
            return ref.dateStr.isEmpty ? " " : Formatters.day(ref.dateStr)
        }()
        return HStack(alignment: .bottom, spacing: 0) {
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
                Text(surTitre)
                    .font(.bhSurTitre)
                    .foregroundStyle(Color.bhAttenue)
                Text(ref.propertyName ?? "Ménage")
                    .bhGrandTitre()
            }
            .padding(.leading, 12)

            Spacer(minLength: 12)

            if vm.detail != nil {
                Button {
                    Task { await sharePdf() }
                } label: {
                    Group {
                        if isPreparingShare {
                            ProgressView().tint(Color.bhVert)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.bhVert)
                        }
                    }
                    .frame(width: 38, height: 38)
                    .glassEffect(in: .circle)
                    .specularEdge(cornerRadius: 19)
                }
                .buttonStyle(.plain)
                .disabled(isPreparingShare)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Contenu principal

    @ViewBuilder
    private var mainContent: some View {
        switch vm.loadState {
        case .idle, .loading:
            loadingPlaceholder
        case .error(let msg):
            errorPlaceholder(msg)
        case .noChecklist:
            noChecklistView
        case .loaded:
            if let detail = vm.detail {
                loadedScrollView(for: detail)
            } else {
                loadingPlaceholder
            }
        }
    }

    // MARK: - États intermédiaires

    private var loadingPlaceholder: some View {
        HStack { Spacer(); ProgressView().tint(Color.bhAttenue); Spacer() }
            .padding(.top, 60)
    }

    private func errorPlaceholder(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(Color.bhAttenue)
            Text(msg)
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
            Button("Réessayer") {
                Task { await vm.load(ref: ref, isSubAccount: isSubAccount) }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.bhVert)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 32)
    }

    // MARK: - État sans checklist soumise

    private var noChecklistView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                noChecklistHeaderCard
                noChecklistStatusCard
                expectedTasksContent
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    private var noChecklistHeaderCard: some View {
        ListCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        if let name = ref.cleanerName, !name.isEmpty {
                            Text(name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.bhEncre)
                        }
                        if !ref.dateStr.isEmpty {
                            Text(Formatters.day(ref.dateStr))
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhAttenue)
                        }
                        if let start = ref.windowStart {
                            Text(slotLabel(start: start, end: ref.windowEnd))
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhAttenue)
                        }
                    }
                    Spacer(minLength: 8)
                    StatusPill(text: "Pas rempli", style: .neutre, icon: "clock")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var noChecklistStatusCard: some View {
        let line: String = {
            if isSubAccount { return "Détail non disponible pour les sous-comptes" }
            if let name = ref.cleanerName, !name.isEmpty {
                return "Pas encore rempli par \(name)"
            }
            return "Pas encore rempli"
        }()
        return ListCard {
            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.bhAttenue)
                Text(line)
                    .font(.bhCorps)
                    .foregroundStyle(Color.bhAttenue)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // Tâches attendues (état "pas encore rempli").
    // nil = template non encore chargé ou absent ; affiche le message d'absence.
    @ViewBuilder
    private var expectedTasksContent: some View {
        if let tasks = vm.expectedTasks, !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("TÂCHES ATTENDUES").bhIntertitre().padding(.top, 4)
                ListCard {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.bhAttenue)
                        Text("Liste prévisionnelle — pas encore remplie par l'intervenante")
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhAttenue)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                ForEach(groupedTasks(tasks), id: \.room) { group in
                    taskSection(room: group.room, tasks: group.tasks)
                }
            }
        } else {
            Text("Aucune checklist définie pour ce logement")
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 12)
        }
    }

    // MARK: - Contenu chargé

    private func loadedScrollView(for detail: ChecklistDetail) -> some View {
        let showBar = detail.ownerStatus == "pending" && canManage
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                headerCard(detail)
                taskSections(detail.tasks)
                if !detail.photos.isEmpty {
                    photosSection(detail.photos)
                }
                if !vm.relatedTickets.isEmpty {
                    incidentsSection(vm.relatedTickets)
                }
                certificationSection(detail)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showBar { actionBar }
        }
        .refreshable {
            vm = ChecklistDetailViewModel()
            await vm.load(ref: ref, isSubAccount: isSubAccount)
        }
    }

    // MARK: - En-tête (checklist soumise)

    private func headerCard(_ detail: ChecklistDetail) -> some View {
        ListCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        if let name = detail.cleanerName, !name.isEmpty {
                            Text(name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.bhEncre)
                        }
                        if let date = detail.checkoutDate {
                            Text(Formatters.day(date))
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhAttenue)
                        }
                        if let start = ref.windowStart {
                            Text(slotLabel(start: start, end: ref.windowEnd))
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhAttenue)
                        }
                        if let iso = detail.completedAt, let date = parseISO(iso) {
                            Text(completionLabel(date: date))
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhAttenue)
                        }
                        if let secs = detail.durationSeconds, secs > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.bhAttenue)
                                Text(durationLabel(secs))
                                    .font(.bhMeta)
                                    .foregroundStyle(Color.bhAttenue)
                            }
                        }
                    }
                    Spacer(minLength: 8)
                    ownerStatusPill(detail.ownerStatus)
                }

                // Message du propriétaire affiché après un rejet
                if let msg = detail.ownerNotes, !msg.isEmpty,
                   detail.ownerStatus == "rejected" {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.bhOr)
                        Text(msg)
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhOr)
                    }
                    .padding(10)
                    .background(
                        Color.bhOrFond,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }

                // Note libre de l'intervenante
                if let note = detail.notes, !note.isEmpty {
                    Text("« \(note) »")
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func ownerStatusPill(_ status: String) -> some View {
        let (text, icon, style): (String, String, PillStyle) = {
            switch status {
            case "validated": return ("Validé",             "checkmark.circle.fill", .vert)
            case "rejected":  return ("Complément demandé", "exclamationmark.circle.fill", .or)
            default:          return ("En attente",          "clock",                .neutre)
            }
        }()
        return StatusPill(text: text, style: style, icon: icon)
    }

    // MARK: - Tâches par pièce

    @ViewBuilder
    private func taskSections(_ tasks: [ChecklistTask]) -> some View {
        if tasks.isEmpty {
            Text("Aucune tâche enregistrée")
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
        } else {
            ForEach(groupedTasks(tasks), id: \.room) { group in
                taskSection(room: group.room, tasks: group.tasks)
            }
        }
    }

    private func taskSection(room: String, tasks: [ChecklistTask]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ChecklistTask.roomLabel(room).uppercased())
                .bhIntertitre()
                .padding(.top, 4)
            ListCard {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { idx, task in
                    CardRow(showSeparator: idx < tasks.count - 1) {
                        HStack(spacing: 12) {
                            Image(systemName: task.checked ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(task.checked
                                    ? Color.bhOccupe
                                    : Color.bhAttenue.opacity(0.35))
                            Text(task.name)
                                .font(.bhCorps)
                                .foregroundStyle(Color.bhEncre)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }

    private func groupedTasks(_ tasks: [ChecklistTask]) -> [(room: String, tasks: [ChecklistTask])] {
        let dict = Dictionary(grouping: tasks, by: { $0.room })
        var result: [(room: String, tasks: [ChecklistTask])] = []
        for room in ChecklistTask.roomOrder {
            if let ts = dict[room], !ts.isEmpty { result.append((room, ts)) }
        }
        for room in dict.keys.filter({ !ChecklistTask.roomOrder.contains($0) }).sorted() {
            if let ts = dict[room], !ts.isEmpty { result.append((room, ts)) }
        }
        return result
    }

    // MARK: - Photos

    private func photosSection(_ photos: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PHOTOS (\(photos.count))").bhIntertitre().padding(.top, 4)
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4),
                ],
                spacing: 4
            ) {
                ForEach(Array(photos.enumerated()), id: \.offset) { _, uri in
                    PhotoThumbView(
                        dataURI: uri,
                        onTap: { fullscreenPhoto = FullscreenPhoto(dataURI: uri) },
                        onLongPress: { shareItem(uri: uri) }
                    )
                }
            }
        }
    }

    // MARK: - Incidents

    private func incidentsSection(_ tickets: [MaintenanceTicket]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INCIDENTS").bhIntertitre().padding(.top, 4)
            ListCard {
                ForEach(Array(tickets.enumerated()), id: \.element.id) { idx, ticket in
                    CardRow(showSeparator: idx < tickets.count - 1) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                Text(ticket.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.bhEncre)
                                    .lineLimit(2)
                                Spacer(minLength: 4)
                                ticketPriorityPill(ticket.priority)
                            }
                            HStack(spacing: 6) {
                                Text(kindLabel(ticket.kind))
                                    .font(.bhMeta)
                                    .foregroundStyle(Color.bhAttenue)
                                Text("·")
                                    .font(.bhMeta)
                                    .foregroundStyle(Color.bhAttenue)
                                Text(ticketStatusLabel(ticket.status))
                                    .font(.bhMeta)
                                    .foregroundStyle(Color.bhAttenue)
                            }
                            if let desc = ticket.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.bhMeta)
                                    .foregroundStyle(Color.bhAttenue)
                                    .lineLimit(2)
                            }
                            if !ticket.photos.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(ticket.photos, id: \.self) { url in
                                            AsyncImage(url: URL(string: url)) { phase in
                                                switch phase {
                                                case .success(let img):
                                                    img.resizable()
                                                       .scaledToFill()
                                                       .frame(width: 64, height: 64)
                                                       .clipped()
                                                       .clipShape(RoundedRectangle(cornerRadius: 8))
                                                default:
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(Color.bhMentheFond)
                                                        .frame(width: 64, height: 64)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func ticketPriorityPill(_ priority: String) -> some View {
        let (label, color): (String, Color) = {
            switch priority {
            case "urgent": return ("Urgent", .bhTerracotta)
            case "high":   return ("Élevé",  .bhOr)
            case "low":    return ("Faible", .bhAttenue)
            default:       return ("Normal", .bhOccupe)
            }
        }()
        return Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.13), in: Capsule())
    }

    private func kindLabel(_ kind: String) -> String { kind == "damage" ? "Dégradation" : "Maintenance" }
    private func ticketStatusLabel(_ status: String) -> String { status == "resolved" ? "Résolu" : "Ouvert" }

    // MARK: - Actions

    private func doValidate() async {
        if await vm.validate() { onChanged?() }
    }

    private func doReject(notes: String) async {
        if await vm.reject(notes: notes) { onChanged?() }
    }

    // Partage d'un seul élément (photo ou signature) — décodage hors fil principal.
    private func shareItem(uri: String) {
        Task {
            let img: UIImage? = await Task.detached(priority: .userInitiated) {
                decodeDataURI(uri)
            }.value
            guard let img else { return }
            shareItemsToPresent = [img]
            presentingShareSheet = true
        }
    }

    private func sharePdf() async {
        guard let id = vm.detail?.id else { return }
        let date = vm.detail?.checkoutDate ?? ref.dateStr
        let cleaner = sanitizeFilename(vm.detail?.cleanerName ?? ref.cleanerName ?? "intervenant")
        let filename = "menage-certifie-\(date)-\(cleaner).pdf"

        isPreparingShare = true
        defer { isPreparingShare = false }

        do {
            let data = try await vm.fetchPdf(id: id)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url)
            shareItemsToPresent = [url]
            presentingShareSheet = true
        } catch let err as APIError {
            shareError = err.userMessage
        } catch {
            shareError = "Impossible de générer le PDF."
        }
    }

    private func sanitizeFilename(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current)
         .lowercased()
         .replacingOccurrences(of: " ", with: "-")
         .filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
    }

    // MARK: - Barre d'action basse

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await doValidate() }
            } label: {
                HStack(spacing: 6) {
                    if vm.actionInProgress {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text("Valider")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Color.bhVert,
                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(vm.actionInProgress)

            Button {
                vm.rejectNotes = ""
                vm.showRejectSheet = true
            } label: {
                Text("Demander un complément")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Color.bhEncreDouce)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .glassEffect(in: .rect(cornerRadius: 15))
                    .specularEdge(cornerRadius: 15)
            }
            .buttonStyle(.plain)
            .disabled(vm.actionInProgress)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Feuille de demande de complément

    private var rejectSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Décrivez le problème à l'intervenante.")
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
            .navigationTitle("Demander un complément")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { vm.showRejectSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Envoyer") {
                        Task { await doReject(notes: vm.rejectNotes) }
                    }
                    .disabled(vm.rejectNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - Certification

    @ViewBuilder
    private func certificationSection(_ detail: ChecklistDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CERTIFICATION").bhIntertitre().padding(.top, 4)
            if detail.cleanerCertified, let uri = detail.signatureData {
                ListCard {
                    VStack(alignment: .leading, spacing: 10) {
                        SignatureImageView(dataURI: uri)
                        HStack(spacing: 8) {
                            Image(systemName: "signature")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.bhOccupeFonce)
                            VStack(alignment: .leading, spacing: 1) {
                                if let name = detail.cleanerName, !name.isEmpty {
                                    Text(name)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.bhEncre)
                                }
                                if let iso = detail.certifiedAt, let date = parseISO(iso) {
                                    Text(Formatters.day(date))
                                        .font(.bhMeta)
                                        .foregroundStyle(Color.bhAttenue)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            } else {
                Text("Ménage non certifié")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
                    .padding(.leading, 2)
            }
        }
    }

    // MARK: - Utilitaires

    private func slotLabel(start: String, end: String?) -> String {
        func fmt(_ t: String) -> String {
            let parts = t.split(separator: ":").compactMap { Int($0) }
            guard let h = parts.first else { return t }
            let m = parts.count > 1 ? parts[1] : 0
            return m == 0 ? "\(h)\u{00A0}h" : "\(h)\u{00A0}h\u{00A0}\(String(format: "%02d", m))"
        }
        if let end { return "\(fmt(start)) → \(fmt(end))" }
        return "Départ \(fmt(start))"
    }

    private func parseISO(_ raw: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: raw) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: raw)
    }

    private func completionLabel(date: Date) -> String {
        let cal = Calendar.current
        let h   = cal.component(.hour,   from: date)
        let m   = cal.component(.minute, from: date)
        let t   = m == 0
            ? "\(h)\u{00A0}h"
            : "\(h)\u{00A0}h\u{00A0}\(String(format: "%02d", m))"
        if cal.isDateInToday(date)     { return "Terminé aujourd'hui \(t)" }
        if cal.isDateInYesterday(date) { return "Terminé hier \(t)" }
        return "Terminé \(Formatters.day(date))"
    }

    private func durationLabel(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 && m > 0 { return "\(h)\u{00A0}h\u{00A0}\(m)\u{00A0}min" }
        if h > 0           { return "\(h)\u{00A0}h" }
        return "\(m)\u{00A0}min"
    }
}

// MARK: - Image de signature (PNG base64, fond blanc opaque)

private struct SignatureImageView: View {
    let dataURI: String

    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                } else {
                    HStack { Spacer(); ProgressView().tint(Color.bhAttenue); Spacer() }
                        .frame(height: 100)
                }
            }
            // Fond blanc opaque : le trait de signature doit se voir franchement
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .task {
            image = await Task.detached(priority: .userInitiated) {
                decodeDataURI(dataURI)
            }.value
        }
    }
}

// MARK: - Vignette photo (base64)

private struct PhotoThumbView: View {
    let dataURI: String
    var onTap:       () -> Void
    var onLongPress: () -> Void

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.bhMentheFond
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onLongPressGesture { onLongPress() }
        .task {
            image = await Task.detached(priority: .userInitiated) {
                decodeDataURI(dataURI)
            }.value
        }
    }
}

// MARK: - Visionneuse plein écran

private struct FullscreenPhoto: Identifiable {
    let id = UUID()
    let dataURI: String
}

private struct PhotoViewerSheet: View {
    let dataURI: String
    @Environment(\.dismiss) private var dismiss

    @State private var image:          UIImage?
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let img = image {
                ZoomableScrollView(image: img)
                    .ignoresSafeArea()
            } else {
                ProgressView().tint(.white)
            }
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                            .padding(20)
                    }
                    Spacer()
                    if image != nil {
                        Button { showShareSheet = true } label: {
                            Image(systemName: "square.and.arrow.up.circle.fill")
                                .font(.system(size: 30))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.white)
                                .padding(20)
                        }
                    }
                }
                Spacer()
            }
        }
        .task {
            image = await Task.detached(priority: .userInitiated) {
                decodeDataURI(dataURI)
            }.value
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = image { ShareSheet(activityItems: [img]) }
        }
    }
}

// MARK: - Visionneuse zoomable (UIScrollView)

private struct ZoomableScrollView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let sv = UIScrollView()
        sv.minimumZoomScale = 1
        sv.maximumZoomScale = 5
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.delegate = context.coordinator
        sv.backgroundColor = .black
        sv.contentInsetAdjustmentBehavior = .never

        let iv = UIImageView(image: image)
        iv.contentMode = .scaleAspectFit
        iv.frame = CGRect(origin: .zero, size: sv.bounds.size)
        iv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sv.addSubview(iv)
        context.coordinator.imageView = iv

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.doubleTapped(_:)))
        tap.numberOfTapsRequired = 2
        sv.addGestureRecognizer(tap)
        return sv
    }

    func updateUIView(_ sv: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let iv = imageView else { return }
            let bw = scrollView.bounds.width, bh = scrollView.bounds.height
            let fw = iv.frame.width,          fh = iv.frame.height
            iv.center = CGPoint(
                x: fw < bw ? bw / 2 : fw / 2,
                y: fh < bh ? bh / 2 : fh / 2
            )
        }

        @objc func doubleTapped(_ g: UITapGestureRecognizer) {
            guard let sv = g.view as? UIScrollView else { return }
            if sv.zoomScale > 1 {
                sv.setZoomScale(1, animated: true)
            } else {
                let loc = g.location(in: sv)
                let w   = sv.bounds.width  / sv.maximumZoomScale
                let h   = sv.bounds.height / sv.maximumZoomScale
                sv.zoom(to: CGRect(x: loc.x - w / 2, y: loc.y - h / 2, width: w, height: h),
                        animated: true)
            }
        }
    }
}

// MARK: - Feuille de partage système

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Décodage base64 partagé

private func decodeDataURI(_ uri: String) -> UIImage? {
    guard let range = uri.range(of: ";base64,") else { return nil }
    let b64 = String(uri[range.upperBound...])
    guard let data = Data(base64Encoded: b64) else { return nil }
    return UIImage(data: data)
}
