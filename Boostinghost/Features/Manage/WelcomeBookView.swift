import SwiftUI
import SafariServices

// MARK: - Safari wrapper

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Internal nav sections

private enum BookSection: Hashable {
    case acces, sejour, quartier, equipements
}

// MARK: - View

struct WelcomeBookView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: WelcomeBookViewModel

    @State private var property: Property
    private let onPropertyUpdate: (Property) -> Void

    @State private var activeSection: BookSection? = nil
    @State private var showPreview = false
    @State private var copiedFeedback = false

    init(vm: WelcomeBookViewModel, property: Property, onPropertyUpdate: @escaping (Property) -> Void) {
        self.vm = vm
        self._property = State(initialValue: property)
        self.onPropertyUpdate = onPropertyUpdate
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                contentArea
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { await vm.fetch() }
        .sheet(isPresented: $showPreview) {
            if let url = vm.publicUrl { SafariView(url: url) }
        }
        .navigationDestination(item: $activeSection) { section in
            switch section {
            case .acces:
                AccesBlockView(property: property) { updated in
                    property = updated
                    onPropertyUpdate(updated)
                }
            case .sejour:
                SejourBlockView(property: property) { updated in
                    property = updated
                    onPropertyUpdate(updated)
                }
            case .quartier:
                QuartierBlockView(property: property) { updated in
                    property = updated
                    onPropertyUpdate(updated)
                }
            case .equipements:
                EquipementsBlockView(property: property) { updated in
                    property = updated
                    onPropertyUpdate(updated)
                }
            }
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        ZStack {
            VStack(spacing: 1) {
                Text(property.internalName ?? property.name)
                    .font(.bhSurTitre)
                    .foregroundStyle(Color.bhAttenue)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("Livret d'accueil")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
            }
            .padding(.horizontal, 96)

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                        .frame(width: 36, height: 36)
                        .glassEffect(in: .circle)
                        .specularEdge(cornerRadius: 18)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.horizontal, 18)
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

    // MARK: - Content dispatcher

    @ViewBuilder
    private var contentArea: some View {
        switch vm.state {
        case .idle, .loading:
            Spacer()
            ProgressView().tint(Color.bhAttenue)
            Spacer()
        case .notCreated:
            notCreatedFill
        case .creating:
            Spacer()
            VStack(spacing: 12) {
                ProgressView().tint(Color.bhVert)
                Text("Création du livret…")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.bhAttenue)
            }
            Spacer()
        case .loaded, .saving:
            loadedFill
        case .failed(let msg):
            Spacer()
            VStack(spacing: 16) {
                Text(msg)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.bhTerracotta)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button("Réessayer") {
                    Task { await vm.refresh() }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bhVert)
            }
            Spacer()
        }
    }

    // MARK: - Not created

    private var notCreatedFill: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                ListCard {
                    CardRow(showSeparator: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top, spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.bhMentheFond)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "book")
                                        .font(.system(size: 19, weight: .medium))
                                        .foregroundStyle(Color.bhVert)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Livret d'accueil")
                                        .font(.system(size: 15.5, weight: .semibold))
                                        .foregroundStyle(Color.bhEncre)
                                    Text("Créez le guide pratique de vos voyageurs. Il se remplit à partir des blocs que vous avez déjà renseignés.")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.bhAttenue)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            PrimaryButton(title: "Créer le livret") {
                                Task { await vm.create() }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Loaded

    private var loadedFill: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                infoSection
                contenuSection
                if vm.publicUrl != nil { diffusionSection }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Informations du logement

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Informations du logement")
            ListCard {
                VStack(spacing: 0) {
                    infoRow(icon: "key.fill", title: "Accès",
                            summary: accesSummary, showSeparator: true) { activeSection = .acces }
                    infoRow(icon: "clock", title: "Séjour",
                            summary: sejourSummary, showSeparator: true) { activeSection = .sejour }
                    infoRow(icon: "map", title: "Le quartier",
                            summary: quartierSummary, showSeparator: true) { activeSection = .quartier }
                    infoRow(icon: "list.bullet", title: "Équipements & règles",
                            summary: equipSummary, showSeparator: false) { activeSection = .equipements }
                }
            }
        }
    }

    private func infoRow(icon: String, title: String, summary: String,
                         showSeparator: Bool, action: @escaping () -> Void) -> some View {
        CardRow(showSeparator: showSeparator) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.bhMentheFond).frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.bhVert)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                    Text(summary)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.bhAttenue.opacity(0.55))
            }
            .contentShape(Rectangle())
            .onTapGesture { action() }
        }
    }

    // MARK: - Contenu du livret

    private var contenuSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Contenu du livret")
            ListCard {
                VStack(spacing: 0) {
                    textFieldRow(label: "Présentation",
                                 placeholder: "Bienvenue dans notre logement…",
                                 text: $vm.welcomeDescription,
                                 showSeparator: true)
                    textFieldRow(label: "Instructions de départ",
                                 placeholder: "Laissez les clés sur la table…",
                                 text: $vm.checkoutInstructions,
                                 showSeparator: false)
                }
            }
            PrimaryButton(title: isSaving ? "Enregistrement…" : "Enregistrer") {
                Task { await vm.saveExtras() }
            }
            .disabled(isSaving)

            if let err = vm.saveError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 13))
                    Text(err)
                        .font(.system(size: 13))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Color.bhTerracotta)
                .padding(.horizontal, 4)
                .transition(.opacity)
            }
        }
    }

    private func textFieldRow(label: String, placeholder: String,
                              text: Binding<String>, showSeparator: Bool) -> some View {
        CardRow(verticalPadding: 14, showSeparator: showSeparator) {
            VStack(alignment: .leading, spacing: 8) {
                Text(label)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color.bhAttenue)
                TextField(placeholder, text: text, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.bhEncre)
                    .lineLimit(3...8)
            }
        }
    }

    // MARK: - Diffusion

    private var diffusionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Diffusion")
            ListCard {
                VStack(spacing: 0) {
                    CardRow(showSeparator: true) {
                        Button { showPreview = true } label: {
                            HStack {
                                Label("Aperçu", systemImage: "safari")
                                    .font(.system(size: 15.5, weight: .medium))
                                    .foregroundStyle(Color.bhEncre)
                                Spacer()
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.bhAttenue.opacity(0.6))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    CardRow(showSeparator: true) {
                        Button {
                            UIPasteboard.general.string = vm.publicUrl?.absoluteString
                            withAnimation { copiedFeedback = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { copiedFeedback = false }
                            }
                        } label: {
                            HStack {
                                Label(copiedFeedback ? "Lien copié !" : "Copier le lien",
                                      systemImage: copiedFeedback ? "checkmark.circle.fill" : "link")
                                    .font(.system(size: 15.5, weight: .medium))
                                    .foregroundStyle(copiedFeedback ? Color.bhOccupe : Color.bhEncre)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    CardRow(showSeparator: false) {
                        if let url = vm.publicUrl {
                            ShareLink(item: url) {
                                HStack {
                                    Label("Partager", systemImage: "square.and.arrow.up")
                                        .font(.system(size: 15.5, weight: .medium))
                                        .foregroundStyle(Color.bhEncre)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Summaries

    private var accesSummary: String {
        var parts: [String] = []
        if let c = property.accessCode, !c.isEmpty { parts.append("code \(c)") }
        if let w = property.wifiName, !w.isEmpty   { parts.append("wifi \(w)") }
        if parts.isEmpty, let i = property.accessInstructions, !i.isEmpty {
            parts.append(String(i.prefix(40)))
        }
        return parts.isEmpty ? "À remplir" : parts.joined(separator: " · ")
    }

    private var sejourSummary: String {
        var parts: [String] = []
        if let a = Formatters.time(property.arrivalTime),
           let d = Formatters.time(property.departureTime) {
            parts.append("\(a) → \(d)")
        }
        if let g = property.maxGuests { parts.append("\(g) pers.") }
        return parts.isEmpty ? "À remplir" : parts.joined(separator: " · ")
    }

    private var quartierSummary: String { property.practicalInfo?.summary ?? "À remplir" }
    private var equipSummary: String    { property.amenities?.summary    ?? "À remplir" }

    // MARK: - Helpers

    private var isSaving: Bool {
        if case .saving = vm.state { return true }
        return false
    }
}
