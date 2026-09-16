import SwiftUI
import PhotosUI
import QuickLook
import UniformTypeIdentifiers
import UIKit

// MARK: - Écran principal

struct DebourView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var authStore
    @State private var vm = DebourViewModel()

    @State private var showCreateSheet    = false
    @State private var showDeleteConfirm: Debour? = nil
    @State private var editingDebour: Debour?      = nil
    @State private var selectedPhoto: Debour?  = nil
    @State private var pdfURL: URL?            = nil
    @State private var isPdfDownloading        = false

    private var canManage: Bool {
        authStore.session?.can("can_manage_debours") ?? true
    }

    // Returns false only in allAccounts mode when the debour belongs to a managed account.
    private func isOwnDebour(_ debour: Debour) -> Bool {
        guard case .allAccounts = authStore.agencyContext else { return true }
        guard let uid = debour.userId else { return true }
        return !authStore.delegations.contains { $0.userId == uid }
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                filterBar
                scrollContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { await vm.load() }
        .sheet(isPresented: $showCreateSheet) {
            DebourCreateSheet(vm: vm)
        }
        .sheet(item: $selectedPhoto) { debour in
            if let urlStr = debour.photoUrl, let url = URL(string: urlStr) {
                DebourPhotoSheet(url: url, description: debour.description)
            }
        }
        .sheet(item: $editingDebour) { debour in
            DebourCreateSheet(vm: vm, editingDebour: debour)
        }
        .quickLookPreview($pdfURL)
        .alert("Supprimer ce débours ?", isPresented: Binding(
            get: { showDeleteConfirm != nil },
            set: { if !$0 { showDeleteConfirm = nil } }
        ), actions: {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                guard let d = showDeleteConfirm else { return }
                Task { await vm.delete(d) }
            }
        }, message: {
            Text("Cette action est définitive.")
        })
        .alert("Erreur", isPresented: Binding(
            get: { vm.actionError != nil },
            set: { if !$0 { vm.actionError = nil } }
        )) {
            Button("OK") { vm.actionError = nil }
        } message: {
            Text(vm.actionError ?? "")
        }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
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
                Text(vm.superTitle)
                    .font(.bhSurTitre)
                    .foregroundStyle(Color.bhAttenue)
                Text("Débours")
                    .bhGrandTitre()
            }
            .padding(.leading, 12)

            Spacer(minLength: 12)

            if canManage {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                        .frame(width: 38, height: 38)
                        .glassEffect(in: .circle)
                        .specularEdge(cornerRadius: 19)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Filtre en puces

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DebourFilter.allCases, id: \.self) { f in
                    Button { vm.filter = f } label: {
                        HStack(spacing: 5) {
                            Text(f.label)
                                .font(.system(size: 14.5, weight: vm.filter == f ? .semibold : .regular))
                                .foregroundStyle(vm.filter == f ? Color.white : Color.bhAttenue)
                            let n = vm.count(for: f)
                            if n > 0 && f != .all {
                                Text("\(n)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(vm.filter == f ? Color.white.opacity(0.8) : Color.bhAttenue)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(vm.filter == f ? Color.bhVert : Color.white.opacity(0.30))
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.18), value: vm.filter)
                }
            }
            .padding(.vertical, 12)
        }
        .contentMargins(.horizontal, 18, for: .scrollContent)
    }

    // MARK: - Contenu principal

    @ViewBuilder
    private var scrollContent: some View {
        switch vm.loadState {
        case .loading:
            Spacer()
            ProgressView().tint(Color.bhAttenue)
            Spacer()
        case .featureBlocked:
            accessView(
                icon: "lock.circle",
                title: "Fonctionnalité non incluse",
                subtitle: "La gestion des débours n'est pas incluse dans votre abonnement actuel."
            )
        case .permissionDenied:
            accessView(
                icon: "hand.raised",
                title: "Accès non autorisé",
                subtitle: "Votre compte n'a pas accès aux débours. Contactez l'administrateur."
            )
        case .error(let msg):
            errorView(msg)
        case .loaded:
            loadedContent
        }
    }

    private var loadedContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if vm.filteredDebours.isEmpty {
                    emptyView
                } else {
                    deboursCard
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .refreshable { await vm.load() }
    }

    // MARK: - Carte de liste

    private var deboursCard: some View {
        ListCard {
            ForEach(Array(vm.filteredDebours.enumerated()), id: \.element.id) { idx, debour in
                CardRow(showSeparator: idx < vm.filteredDebours.count - 1) {
                    debourRow(debour)
                }
            }
        }
    }

    private func debourRow(_ debour: Debour) -> some View {
        Button {
            guard debour.photoUrl != nil else { return }
            if debour.isPdf {
                Task { await openPdf(debour) }
            } else {
                selectedPhoto = debour
            }
        } label: {
            HStack(spacing: 12) {
                photoThumbnail(debour)

                VStack(alignment: .leading, spacing: 3) {
                    Text(debour.description)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        let clientName = vm.clientName(for: debour)
                        Text(clientName)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.bhAttenue)
                            .lineLimit(1)
                        if let d = debour.date, !d.isEmpty {
                            Text("·")
                                .font(.system(size: 12.5))
                                .foregroundStyle(Color.bhAttenue)
                            Text(Formatters.day(d))
                                .font(.system(size: 12.5))
                                .foregroundStyle(Color.bhAttenue)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 5) {
                    Text(DebourAmountFmt.format(debour.montant))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                    StatusPill(text: debour.statusLabel, style: debour.statusPillStyle)
                }
            }
            .frame(minHeight: 52)
            .opacity(vm.actionDebourId == debour.id ? 0.45 : 1)
            .overlay {
                if vm.actionDebourId == debour.id {
                    ProgressView().tint(Color.bhAttenue)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            contextMenuItems(debour)
        }
    }

    @ViewBuilder
    private func contextMenuItems(_ debour: Debour) -> some View {
        if canManage {
            if isOwnDebour(debour) {
                let toggleLabel = debour.status == "pending" ? "Marquer facturé" : "Marquer à facturer"
                Button(toggleLabel) {
                    Task { await vm.toggleStatus(debour) }
                }
                Button {
                    editingDebour = debour
                } label: {
                    Label("Modifier", systemImage: "pencil")
                }
                Button("Supprimer", role: .destructive) {
                    showDeleteConfirm = debour
                }
            } else {
                Button(action: {}) {
                    Label("Compte délégué – lecture seule", systemImage: "lock")
                }
                .disabled(true)
            }
        }
    }

    // MARK: - Vignette photo

    private func photoThumbnail(_ debour: Debour) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.bhMentheFond)

            if let urlStr = debour.photoUrl, let url = URL(string: urlStr) {
                if debour.isPdf {
                    Image(systemName: "doc.text")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.bhAttenue)
                } else {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            Image(systemName: "eurosign.circle")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color.bhVert)
                        }
                    }
                    .clipped()
                }
            } else {
                Image(systemName: "eurosign.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.bhVert)
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Ouverture PDF distant

    private func openPdf(_ debour: Debour) async {
        guard let urlStr = debour.photoUrl, let url = URL(string: urlStr) else { return }
        isPdfDownloading = true
        defer { isPdfDownloading = false }
        do {
            let (tmpURL, _) = try await URLSession.shared.download(from: url)
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("debours-\(debour.id).pdf")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tmpURL, to: dest)
            pdfURL = dest
        } catch {
            vm.actionError = "Impossible d'ouvrir le PDF."
        }
    }

    // MARK: - États vide / erreur / accès

    private var emptyView: some View {
        VStack(spacing: 8) {
            Text("Aucun débours")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.bhEncre)
            Text(emptyLabel)
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var emptyLabel: String {
        switch vm.filter {
        case .pending: return "Aucun débours à facturer pour le moment."
        case .billed:  return "Aucun débours facturé pour le moment."
        case .all:     return "Aucun débours enregistré pour le moment."
        }
    }

    private func accessView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(Color.bhAttenue)
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.bhEncre)
            Text(subtitle)
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

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
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Visionneuse photo plein écran

private struct DebourPhotoSheet: View {
    let url: URL
    let description: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFit()
                            .padding()
                    case .failure:
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.white.opacity(0.6))
                            Text("Impossible de charger l'image.")
                                .font(.bhCorps)
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                    default:
                        ProgressView().tint(.white)
                    }
                }
            }
            .navigationTitle(description)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(Color.white)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Feuille création / édition

private struct DebourCreateSheet: View {
    let vm: DebourViewModel
    let editingDebour: Debour?      // nil = création, non-nil = édition

    @Environment(\.dismiss) private var dismiss

    @State private var selectedClient: OwnerClient?
    @State private var description: String
    @State private var montantStr: String
    @State private var selectedDate: Date
    // URL de la photo existante côté serveur (édition uniquement).
    // Si l'utilisateur sélectionne une nouvelle photo, cette URL reste présente
    // mais n'est pas envoyée — le champ photo envoie les nouvelles données.
    @State private var existingPhotoUrl: String?

    @State private var photoData: Data?       = nil
    @State private var photoMime              = "image/jpeg"
    @State private var photoName              = "photo.jpg"
    @State private var photoPreview: Image?   = nil

    @State private var showClientPicker       = false
    @State private var showSourceDialog       = false
    @State private var showCamera             = false
    @State private var showPhotoPicker        = false
    @State private var showFileImporter       = false
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var photoValidationError: String?      = nil

    @State private var isSending              = false
    @State private var sendError: String?     = nil

    private var isEditing: Bool { editingDebour != nil }

    init(vm: DebourViewModel, editingDebour: Debour? = nil) {
        self.vm = vm
        self.editingDebour = editingDebour

        if let d = editingDebour {
            _description      = State(initialValue: d.description)
            _montantStr       = State(initialValue: Self.rawAmount(d.montant))
            _selectedDate     = State(initialValue: Self.parseDate(d.date) ?? Date())
            _existingPhotoUrl = State(initialValue: d.photoUrl)
            _selectedClient   = State(initialValue: nil)  // résolu dans .task
        } else {
            _description      = State(initialValue: "")
            _montantStr       = State(initialValue: "")
            _selectedDate     = State(initialValue: Date())
            _existingPhotoUrl = State(initialValue: nil)
            _selectedClient   = State(initialValue: nil)
        }
    }

    private static func rawAmount(_ v: Double) -> String {
        let fmt = NumberFormatter()
        fmt.locale = Locale(identifier: "fr_FR")
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        return fmt.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
    }

    private static func parseDate(_ str: String?) -> Date? {
        guard let str, !str.isEmpty else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: str)
    }

    private var montantNormalized: String {
        montantStr.replacingOccurrences(of: ",", with: ".")
    }

    private var hasAnyPhoto: Bool {
        photoData != nil || (existingPhotoUrl != nil && !(existingPhotoUrl?.isEmpty ?? true))
    }

    private var canSubmit: Bool {
        !isSending
        && selectedClient != nil
        && !description.trimmingCharacters(in: .whitespaces).isEmpty
        && Double(montantNormalized) != nil
        && !montantNormalized.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 0) {
                    sheetHeader
                    form
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            // Résoudre le client en édition après que vm.clients est disponible.
            if let d = editingDebour, selectedClient == nil, let cid = d.clientId {
                selectedClient = vm.clients.first { $0.id == cid }
            }
        }
        .sheet(isPresented: $showClientPicker) {
            DebourClientPickerSheet(clients: vm.selectableClients) { client in
                selectedClient = client
                showClientPicker = false
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(
                onCapture: { data, mime in
                    handlePhotoData(data, mime: mime, name: "photo.jpg")
                    showCamera = false
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $photoPickerItem,
            matching: .any(of: [.images]),
            photoLibrary: .shared()
        )
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType.pdf]
        ) { result in
            handleFileImport(result)
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task { await loadPhotoPickerItem(item) }
        }
        .confirmationDialog("Ajouter une photo", isPresented: $showSourceDialog) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Appareil photo") { showCamera = true }
            }
            Button("Photothèque") { showPhotoPicker = true }
            Button("Document PDF") { showFileImporter = true }
            Button("Annuler", role: .cancel) {}
        }
        .alert("Erreur", isPresented: Binding(
            get: { photoValidationError != nil },
            set: { if !$0 { photoValidationError = nil } }
        )) {
            Button("OK") { photoValidationError = nil }
        } message: {
            Text(photoValidationError ?? "")
        }
        .alert("Erreur", isPresented: Binding(
            get: { sendError != nil },
            set: { if !$0 { sendError = nil } }
        )) {
            Button("OK") { sendError = nil }
        } message: {
            Text(sendError ?? "")
        }
        .numericKeyboardBar()
    }

    // MARK: - En-tête feuille

    private var sheetHeader: some View {
        VStack(spacing: 0) {
            SheetHandle()

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(isEditing ? "Débours" : "Nouveau débours")
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                    Text(isEditing ? "Modifier" : "Ajouter")
                        .bhGrandTitre()
                }

                Spacer()

                Button("Annuler") { dismiss() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.bhVert)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .glassEffect(in: .rect(cornerRadius: 12))
                    .specularEdge(cornerRadius: 12)
                    .buttonStyle(.plain)
                    .disabled(isSending)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
        }
    }

    // MARK: - Formulaire

    private var form: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {

                // Client
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Propriétaire")
                    ListCard {
                        CardRow(showSeparator: false) {
                            Button { showClientPicker = true } label: {
                                HStack(spacing: 12) {
                                    if let client = selectedClient {
                                        ProfileAvatarView(
                                            logoUrl: nil,
                                            firstName: client.firstName,
                                            lastName: client.lastName,
                                            company: client.companyName,
                                            size: 36
                                        )
                                        Text(client.displayName)
                                            .font(.system(size: 15))
                                            .foregroundStyle(Color.bhEncre)
                                    } else {
                                        Circle()
                                            .fill(Color.bhMentheFond)
                                            .frame(width: 36, height: 36)
                                            .overlay {
                                                Image(systemName: "person")
                                                    .font(.system(size: 15))
                                                    .foregroundStyle(Color.bhVert)
                                            }
                                        Text("Choisir un propriétaire")
                                            .font(.system(size: 15))
                                            .foregroundStyle(Color.bhAttenue)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.bhAttenue.opacity(0.55))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Détails
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Détails")
                    ListCard {
                        CardRow(showSeparator: true) {
                            TextField("Description (obligatoire)", text: $description)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.bhEncre)
                        }
                        CardRow(showSeparator: true) {
                            HStack {
                                Text("Montant")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.bhAttenue)
                                Spacer()
                                TextField("0,00", text: $montantStr)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.bhEncre)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                                    .frame(width: 100)
                                Text("€")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.bhAttenue)
                            }
                        }
                        CardRow(showSeparator: false) {
                            DatePicker(
                                "Date",
                                selection: $selectedDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.bhEncre)
                            .environment(\.locale, Locale(identifier: "fr_FR"))
                        }
                    }
                }

                // Photo
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Photo (optionnel)")
                    ListCard {
                        // Nouvelle photo sélectionnée localement : aperçu image
                        if let preview = photoPreview {
                            CardRow(showSeparator: true) {
                                HStack(spacing: 12) {
                                    preview
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    Text(photoName)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.bhEncre)
                                        .lineLimit(1)
                                    Spacer()
                                    Button {
                                        photoData    = nil
                                        photoPreview = nil
                                        photoPickerItem = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(Color.bhAttenue)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else if photoData != nil {
                            // PDF ou fichier sans aperçu image
                            CardRow(showSeparator: true) {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.bhAttenue.opacity(0.12))
                                        .frame(width: 56, height: 56)
                                        .overlay {
                                            Image(systemName: "doc.text")
                                                .font(.system(size: 22))
                                                .foregroundStyle(Color.bhAttenue)
                                        }
                                    Text(photoName)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.bhEncre)
                                        .lineLimit(1)
                                    Spacer()
                                    Button {
                                        photoData    = nil
                                        photoPreview = nil
                                        photoPickerItem = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(Color.bhAttenue)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else if let urlStr = existingPhotoUrl, !urlStr.isEmpty,
                                  let url = URL(string: urlStr) {
                            // Photo existante côté serveur (mode édition, pas encore remplacée)
                            CardRow(showSeparator: true) {
                                HStack(spacing: 12) {
                                    if editingDebour?.isPdf == true {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.bhAttenue.opacity(0.12))
                                            .frame(width: 56, height: 56)
                                            .overlay {
                                                Image(systemName: "doc.text")
                                                    .font(.system(size: 22))
                                                    .foregroundStyle(Color.bhAttenue)
                                            }
                                    } else {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let img):
                                                img.resizable().scaledToFill()
                                            default:
                                                Image(systemName: "photo")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(Color.bhAttenue)
                                            }
                                        }
                                        .frame(width: 56, height: 56)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }
                                    Text("Photo existante")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.bhAttenue)
                                    Spacer()
                                }
                            }
                        }

                        // Bouton d'action photo
                        CardRow(showSeparator: false) {
                            Button { showSourceDialog = true } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: hasAnyPhoto ? "arrow.triangle.2.circlepath" : "camera")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Color.bhVert)
                                        .frame(width: 24)
                                    Text(hasAnyPhoto ? "Remplacer" : "Ajouter une photo ou un PDF")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color.bhVert)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Bouton Enregistrer
                PrimaryButton(title: isSending ? "Enregistrement…" : "Enregistrer") {
                    Task { await submit() }
                }
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.45)
                .padding(.top, 8)
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Envoi

    private func submit() async {
        guard let client = selectedClient else {
            sendError = "Veuillez choisir un propriétaire."
            return
        }
        guard !description.trimmingCharacters(in: .whitespaces).isEmpty else {
            sendError = "Veuillez saisir une description."
            return
        }
        guard Double(montantNormalized) != nil else {
            sendError = "Le montant saisi est invalide."
            return
        }
        isSending = true
        defer { isSending = false }

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let dateValue = dateFmt.string(from: selectedDate)

        let descTrimmed = description.trimmingCharacters(in: .whitespaces)
        let fields: [(String, String)] = [
            ("client_id",   client.id),
            ("description", descTrimmed),
            ("montant",     montantNormalized),
            ("date",        dateValue),
        ]

        do {
            if let existing = editingDebour {
                // Édition : PUT /api/debours/:id
                let resp: DebourCreateResponse = try await APIClient.shared.putMultipartWithFile(
                    Endpoint.debour(existing.id),
                    fields: fields,
                    fileField: photoData != nil ? "photo" : nil,
                    fileData: photoData,
                    fileName: photoData != nil ? photoName : nil,
                    fileMimeType: photoData != nil ? photoMime : nil
                )
                if let updated = resp.debour {
                    vm.didUpdate(updated)
                } else {
                    await vm.silentReload()
                }
            } else {
                // Création : POST /api/debours
                let resp: DebourCreateResponse = try await APIClient.shared.postMultipartWithFile(
                    Endpoint.debours,
                    fields: fields,
                    fileField: photoData != nil ? "photo" : nil,
                    fileData: photoData,
                    fileName: photoData != nil ? photoName : nil,
                    fileMimeType: photoData != nil ? photoMime : nil
                )
                if let created = resp.debour {
                    vm.didCreate(created)
                } else {
                    await vm.silentReload()
                }
            }
            dismiss()
        } catch {
            sendError = (error as? APIError)?.userMessage ?? "Erreur lors de l'enregistrement."
        }
    }

    // MARK: - Gestion photo

    private func loadPhotoPickerItem(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let mime = detectMime(data)
        guard validatePhoto(data, mime: mime) else { return }
        let ext = mime == "image/png" ? "png" : mime == "image/webp" ? "webp" : mime == "image/heic" ? "heic" : "jpg"
        handlePhotoData(data, mime: mime, name: "photo.\(ext)")
        photoPickerItem = nil
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else {
                photoValidationError = "Impossible de lire le fichier."; return
            }
            let mime = "application/pdf"
            guard validatePhoto(data, mime: mime) else { return }
            handlePhotoData(data, mime: mime, name: url.lastPathComponent)
        case .failure(let err):
            photoValidationError = err.localizedDescription
        }
    }

    private func handlePhotoData(_ data: Data, mime: String, name: String) {
        photoData    = data
        photoMime    = mime
        photoName    = name
        if mime != "application/pdf", let uiImg = UIImage(data: data) {
            photoPreview = Image(uiImage: uiImg)
        } else {
            photoPreview = nil
        }
    }

    private func validatePhoto(_ data: Data, mime: String) -> Bool {
        let maxBytes = 10 * 1024 * 1024
        guard data.count <= maxBytes else {
            photoValidationError = "Le fichier dépasse la limite de 10\u{202F}Mo."; return false
        }
        let allowed = ["image/jpeg", "image/jpg", "image/png", "image/webp",
                       "image/heic", "image/heif", "application/pdf"]
        guard allowed.contains(mime) else {
            photoValidationError = "Format non accepté. Utilisez une image (JPEG, PNG, HEIC, WebP) ou un PDF."; return false
        }
        return true
    }

    private func detectMime(_ data: Data) -> String {
        let bytes = Array(data.prefix(12))
        if bytes.prefix(4) == [0x25, 0x50, 0x44, 0x46] { return "application/pdf" }
        if bytes.prefix(2) == [0xFF, 0xD8]              { return "image/jpeg" }
        if bytes.prefix(4) == [0x89, 0x50, 0x4E, 0x47] { return "image/png" }
        if bytes.prefix(4) == [0x52, 0x49, 0x46, 0x46]
            && bytes.count >= 12
            && Array(bytes[8..<12]) == [0x57, 0x45, 0x42, 0x50] { return "image/webp" }
        if bytes.count >= 12,
           Array(bytes[4..<8]) == [0x66, 0x74, 0x79, 0x70] {
            let brand = String(bytes: Array(bytes[8..<12]), encoding: .ascii) ?? ""
            if brand.lowercased().hasPrefix("hei") || brand.lowercased().hasPrefix("mif") {
                return "image/heic"
            }
        }
        return "image/jpeg"
    }
}

// MARK: - Sélecteur de client (sub-feuille)

private struct DebourClientPickerSheet: View {
    let clients: [OwnerClient]
    let onSelect: (OwnerClient) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 0) {
                    sheetHeader
                    if clients.isEmpty {
                        Spacer()
                        Text("Aucun client disponible.")
                            .font(.bhCorps)
                            .foregroundStyle(Color.bhAttenue)
                        Spacer()
                    } else {
                        clientList
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var sheetHeader: some View {
        VStack(spacing: 0) {
            SheetHandle()
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Débours")
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                    Text("Choisir un propriétaire")
                        .bhGrandTitre()
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
        }
    }

    private var clientList: some View {
        ScrollView(showsIndicators: false) {
            ListCard {
                ForEach(Array(clients.enumerated()), id: \.element.id) { idx, client in
                    CardRow(showSeparator: idx < clients.count - 1) {
                        Button { onSelect(client) } label: {
                            HStack(spacing: 12) {
                                ProfileAvatarView(
                                    logoUrl: nil,
                                    firstName: client.firstName,
                                    lastName: client.lastName,
                                    company: client.companyName,
                                    size: 38
                                )
                                Text(client.displayName)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.bhEncre)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.bhAttenue.opacity(0.55))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Caméra UIViewControllerRepresentable

private struct CameraView: UIViewControllerRepresentable {
    let onCapture: (Data, String) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture, onCancel: onCancel) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data, String) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (Data, String) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel  = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // Ne pas appeler picker.dismiss — SwiftUI gère la fermeture via le binding.
            // picker.dismiss remonterait la hiérarchie UIKit et fermerait la feuille parente.
            guard let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.85) else { return }
            onCapture(data, "image/jpeg")
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
