import SwiftUI

// MARK: - Draft

private struct IdentiteDraft {
    var name: String
    var internalName: String
    var color: Color
    var address: String
    var maxGuests: String
    var bedrooms: String
    var beds: String
    var bathrooms: String
    var selectedOwnerId: String?   // nil = aucun propriétaire

    init(from p: Property) {
        name            = p.name
        internalName    = p.internalName ?? ""
        color           = p.color.flatMap { $0.isEmpty ? nil : Color(hex: $0) } ?? Color(hex: "#2E8B62")
        address         = p.address ?? ""
        maxGuests       = p.maxGuests.map  { String($0) } ?? ""
        bedrooms        = p.bedrooms.map   { String($0) } ?? ""
        beds            = p.beds.map       { String($0) } ?? ""
        bathrooms       = p.bathrooms.map  { String($0) } ?? ""
        selectedOwnerId = p.ownerId?.isEmpty == false ? p.ownerId : nil
    }
}

// Le PATCH /api/properties/:id accepte "" comme ownerId — "" || null = null côté serveur.
private struct OwnerPatchBody: Encodable {
    let ownerId: String
}

// MARK: - Bloc "Identité"

struct IdentiteBlockView: View {
    @Environment(\.dismiss) private var dismiss

    private let onUpdate: (Property) -> Void

    @State private var displayed: Property
    @State private var draft: IdentiteDraft
    @State private var isEditing = false
    @State private var isSaving  = false
    @State private var saveError: String?

    @State private var clients: [OwnerClient] = []
    @State private var clientsLoaded = false

    init(property: Property, onUpdate: @escaping (Property) -> Void = { _ in }) {
        self.onUpdate = onUpdate
        self._displayed = State(initialValue: property)
        self._draft = State(initialValue: IdentiteDraft(from: property))
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if isEditing {
                            nomEditCard
                            adresseEditCard
                            capaciteEditCard
                            if let url = displayed.photoUrl, !url.isEmpty {
                                photoCard(urlString: url)
                            }
                            proprietaireEditCard
                        } else {
                            nomCard
                            if let addr = displayed.address, !addr.isEmpty {
                                fieldCard(icon: "mappin.and.ellipse", label: "Adresse", value: addr)
                            }
                            capaciteCard
                            if let url = displayed.photoUrl, !url.isEmpty {
                                photoCard(urlString: url)
                            }
                            proprietaireReadCard
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { await loadClients() }
        .alert("Erreur", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        ZStack {
            VStack(spacing: 1) {
                Text(displayed.internalName ?? displayed.name)
                    .font(.bhSurTitre)
                    .foregroundStyle(Color.bhAttenue)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("Identité")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
            }
            .padding(.horizontal, 96)

            HStack {
                if isEditing {
                    Button {
                        draft = IdentiteDraft(from: displayed)
                        isEditing = false
                    } label: {
                        Text("Annuler")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.bhVert)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .glassEffect(in: .rect(cornerRadius: 12))
                            .specularEdge(cornerRadius: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.bhVert)
                            .frame(width: 36, height: 36)
                            .glassEffect(in: .circle)
                            .specularEdge(cornerRadius: 18)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if isEditing {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(Color.bhVert)
                                .frame(width: 24, height: 24)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 7)
                        } else {
                            Text("Enregistrer")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.bhVert)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .glassEffect(in: .rect(cornerRadius: 12))
                                .specularEdge(cornerRadius: 12)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                } else {
                    Button {
                        draft = IdentiteDraft(from: displayed)
                        isEditing = true
                    } label: {
                        Text("Modifier")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.bhVert)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .glassEffect(in: .rect(cornerRadius: 12))
                            .specularEdge(cornerRadius: 12)
                    }
                    .buttonStyle(.plain)
                }
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

    // MARK: - Cartes lecture

    private var nomCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "textformat", label: "Nom public", showSeparator: true)
                CardRow(showSeparator: hasInternalName) {
                    Text(displayed.name)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.bhEncre)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let v = displayed.internalName, !v.isEmpty, v != displayed.name {
                    fieldHeader(icon: "tag", label: "Nom interne", showSeparator: true)
                    CardRow(showSeparator: false) {
                        Text(v)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.bhEncre)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let hex = displayed.color, !hex.isEmpty {
                    fieldHeader(icon: "circle.fill", label: "Couleur", showSeparator: true)
                    CardRow(showSeparator: false) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 8, height: 8)
                            Text(hex.uppercased())
                                .font(.system(size: 15, design: .monospaced))
                                .foregroundStyle(Color.bhAttenue)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var hasInternalName: Bool {
        guard let v = displayed.internalName, !v.isEmpty, v != displayed.name else { return false }
        return true
    }

    private var capaciteCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "person.2", label: "Capacité", showSeparator: true)
                CardRow(showSeparator: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let n = displayed.maxGuests {
                            Text("\(n) personne\(n == 1 ? "" : "s") max")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.bhEncre)
                        }
                        let det = capaciteDetail
                        if !det.isEmpty {
                            Text(det)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.bhAttenue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var capaciteDetail: String {
        var p: [String] = []
        if let b = displayed.bedrooms  { p.append("\(b) chambre\(b == 1 ? "" : "s")") }
        if let b = displayed.beds      { p.append("\(b) lit\(b == 1 ? "" : "s")") }
        if let b = displayed.bathrooms { p.append("\(b) salle\(b == 1 ? "" : "s") de bain") }
        return p.joined(separator: " · ")
    }

    private func photoCard(urlString: String) -> some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "photo", label: "Photo", showSeparator: true)
                CardRow(showSeparator: false) {
                    if let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 160)
                                    .clipped()
                                    .cornerRadius(10)
                            case .failure:
                                Text(urlString)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(Color.bhAttenue)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                            case .empty:
                                ProgressView().frame(maxWidth: .infinity).frame(height: 80)
                            @unknown default: EmptyView()
                            }
                        }
                    }
                }
            }
        }
    }

    private var proprietaireReadCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "person", label: "Propriétaire", showSeparator: true)
                CardRow(showSeparator: false) {
                    if let ownerId = displayed.ownerId, !ownerId.isEmpty {
                        if !clientsLoaded {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Chargement…").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                            }
                        } else if let c = clients.first(where: { $0.id == ownerId }) {
                            Text(c.displayName)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.bhEncre)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("Propriétaire introuvable")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.bhAttenue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        Text("Aucun propriétaire lié")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.bhAttenue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: - Cartes édition

    private var nomEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "textformat", label: "Nom public", showSeparator: true)
                CardRow(showSeparator: true) {
                    TextField("Nom du logement", text: $draft.name)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.bhEncre)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                fieldHeader(icon: "tag", label: "Nom interne", showSeparator: true)
                CardRow(showSeparator: true) {
                    TextField("Identifiant de gestion (facultatif)", text: $draft.internalName)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.bhEncre)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                fieldHeader(icon: "circle.fill", label: "Couleur", showSeparator: true)
                CardRow(showSeparator: false) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(draft.color)
                            .frame(width: 8, height: 8)
                        Text("Point coloré dans le classement des revenus")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.bhAttenue)
                        Spacer()
                        ColorPicker("", selection: $draft.color, supportsOpacity: false)
                            .labelsHidden()
                    }
                }
            }
        }
    }

    private var adresseEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "mappin.and.ellipse", label: "Adresse", showSeparator: true)
                CardRow(showSeparator: false) {
                    TextField("Adresse complète", text: $draft.address, axis: .vertical)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.bhEncre)
                        .lineLimit(2...4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var capaciteEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "person.2", label: "Capacité", showSeparator: true)
                intRow(label: "Voyageurs max", text: $draft.maxGuests, showSep: true)
                intRow(label: "Chambres",      text: $draft.bedrooms,  showSep: true)
                intRow(label: "Lits",          text: $draft.beds,      showSep: true)
                intRow(label: "Salles de bain", text: $draft.bathrooms, showSep: false)
            }
        }
    }

    private func intRow(label: String, text: Binding<String>, showSep: Bool) -> some View {
        CardRow(showSeparator: showSep) {
            HStack {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.bhAttenue)
                Spacer()
                TextField("—", text: text)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.bhEncre)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .frame(width: 60)
            }
        }
    }

    private var proprietaireEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "person", label: "Propriétaire", showSeparator: true)
                CardRow(showSeparator: false) {
                    if !clientsLoaded {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Chargement…").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                        }
                    } else {
                        Picker("Propriétaire", selection: $draft.selectedOwnerId) {
                            Text("Aucun propriétaire").tag(String?.none)
                            ForEach(clients) { c in
                                Text(c.displayName).tag(Optional(c.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.bhEncre)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: - Helpers communs

    private func fieldCard(icon: String, label: String, value: String) -> some View {
        let lines = value.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: icon, label: label, showSeparator: !lines.isEmpty)
                ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                    CardRow(showSeparator: idx < lines.count - 1) {
                        Text(line)
                            .font(.system(size: 15))
                            .lineSpacing(8)
                            .foregroundStyle(Color.bhEncre)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fieldHeader(icon: String, label: String, showSeparator: Bool) -> some View {
        CardRow(showSeparator: showSeparator) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.bhVert)
                    .frame(width: 20, alignment: .center)
                Text(label.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.96)
                    .foregroundStyle(Color.bhAttenue)
                Spacer()
            }
        }
    }

    // MARK: - Chargement clients

    private func loadClients() async {
        guard !clientsLoaded else { return }
        if let r: OwnerClientsResponse = try? await APIClient.shared.get(Endpoint.ownerClients) {
            clients = r.clients
        }
        clientsLoaded = true
    }

    // MARK: - Sauvegarde

    private func save() async {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            saveError = "Le nom du logement ne peut pas être vide."
            return
        }

        isSaving = true
        defer { isSaving = false }

        // PATCH propriétaire si changé — route dédiée (owner_id seul)
        if draft.selectedOwnerId != displayed.ownerId {
            do {
                try await APIClient.shared.patchVoid(
                    Endpoint.property(displayed.id),
                    body: OwnerPatchBody(ownerId: draft.selectedOwnerId ?? ""),
                    agencyAll: true
                )
            } catch let err as APIError {
                saveError = apiErrorText(err); return
            } catch {
                saveError = error.localizedDescription; return
            }
        }

        // PUT champs identité
        var fields: [(String, String)] = [
            ("name",         trimmedName),
            ("internalName", draft.internalName.trimmingCharacters(in: .whitespaces)),
            ("color",        draft.color.hexString),
            ("address",      draft.address.trimmingCharacters(in: .whitespaces)),
            ("ownerId",      draft.selectedOwnerId ?? ""),
            ("photoUrl",     displayed.photoUrl   ?? ""),
        ]
        for (key, val) in [("maxGuests", draft.maxGuests), ("bedrooms", draft.bedrooms),
                           ("beds", draft.beds), ("bathrooms", draft.bathrooms)] {
            if !val.isEmpty { fields.append((key, val)) }
        }

        do {
            let r: PropertyUpdateResponse = try await APIClient.shared.putMultipart(
                Endpoint.property(displayed.id),
                fields: fields,
                agencyAll: true
            )
            displayed = r.property
            onUpdate(r.property)
            isEditing = false
        } catch let err as APIError {
            saveError = apiErrorText(err)
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func apiErrorText(_ err: APIError) -> String {
        switch err {
        case .server(_, let msg):    return msg ?? "Erreur serveur"
        case .network:               return "Erreur réseau"
        case .decoding:              return "Erreur de décodage"
        case .unauthorized:          return "Session expirée"
        case .subscriptionRequired:  return "Abonnement requis"
        }
    }
}
