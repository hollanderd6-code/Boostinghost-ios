import SwiftUI

// MARK: - Draft

private struct PracticalInfoDraft {
    var parkingDetails: String
    var trashDay: String
    var nearbyShops: String
    var publicTransport: String

    init(from info: PracticalInfo?) {
        parkingDetails  = info?.parkingDetails  ?? ""
        trashDay        = info?.trashDay        ?? ""
        nearbyShops     = info?.nearbyShops     ?? ""
        publicTransport = info?.publicTransport ?? ""
    }

    // snake_case content inside a camelCase key — see relevé §1 rule 1
    func toJSONString() -> String? {
        let dict: [String: String] = [
            "parking_details":  parkingDetails,
            "trash_day":        trashDay,
            "nearby_shops":     nearbyShops,
            "public_transport": publicTransport
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str  = String(data: data, encoding: .utf8) else { return nil }
        return str
    }
}

// MARK: - Bloc "Le quartier"

struct QuartierBlockView: View {
    @Environment(\.dismiss) private var dismiss

    private let onUpdate: (Property) -> Void

    @State private var displayed: Property
    @State private var draft: PracticalInfoDraft
    @State private var isEditing = false
    @State private var isSaving  = false
    @State private var saveError: String?

    init(property: Property, onUpdate: @escaping (Property) -> Void = { _ in }) {
        self.onUpdate = onUpdate
        self._displayed = State(initialValue: property)
        self._draft = State(initialValue: PracticalInfoDraft(from: property.practicalInfo))
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        livretBanner
                        if isEditing {
                            editCard(icon: "parkingsign", label: "Stationnement",
                                     text: $draft.parkingDetails,  placeholder: "Comment se garer ?")
                            editCard(icon: "trash",        label: "Poubelles",
                                     text: $draft.trashDay,        placeholder: "Jours et couleurs des bacs")
                            editCard(icon: "storefront",   label: "Commerces",
                                     text: $draft.nearbyShops,     placeholder: "Supérette, boulangerie…")
                            editCard(icon: "bus",          label: "Transports en commun",
                                     text: $draft.publicTransport, placeholder: "Bus, métro, RER…")
                        } else {
                            let info = displayed.practicalInfo
                            if let v = info?.parkingDetails, !v.isEmpty {
                                fieldCard(icon: "parkingsign", label: "Stationnement", value: v)
                            }
                            if let v = info?.trashDay, !v.isEmpty {
                                trashCard(value: v)
                            }
                            if let v = info?.nearbyShops, !v.isEmpty {
                                fieldCard(icon: "storefront", label: "Commerces", value: v)
                            }
                            if let v = info?.publicTransport, !v.isEmpty {
                                fieldCard(icon: "bus", label: "Transports en commun", value: v)
                            }
                            if displayed.practicalInfo?.hasAny != true {
                                emptyCard
                            }
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
                Text("Le quartier")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
            }
            .padding(.horizontal, 96)

            HStack {
                if isEditing {
                    Button {
                        draft = PracticalInfoDraft(from: displayed.practicalInfo)
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
                        draft = PracticalInfoDraft(from: displayed.practicalInfo)
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

    // MARK: - Bandeau LIVRET

    private var livretBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.bhVert)
                .frame(width: 22, alignment: .center)
            Text("Ces quatre champs partent directement dans le livret d'accueil. Tu ne les saisis qu'ici.")
                .font(.system(size: 13.5))
                .foregroundStyle(Color.bhOccupeFonce)
                .lineSpacing(3.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.bhMentheFond)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            Color(red: 46/255, green: 139/255, blue: 98/255).opacity(0.28),
                            lineWidth: 1
                        )
                }
        }
    }

    // MARK: - Cartes lecture

    private func fieldCard(icon: String, label: String, value: String) -> some View {
        let lines = value
            .components(separatedBy: "\n")
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

    private func trashCard(value: String) -> some View {
        let lines = value
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "trash", label: "Poubelles", showSeparator: !lines.isEmpty)
                ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                    CardRow(showSeparator: idx < lines.count - 1) {
                        HStack(spacing: 8) {
                            if let color = trashBinColor(for: line) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(color)
                                    .frame(width: 9, height: 9)
                                    .padding(.top, 1)
                            }
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
    }

    // MARK: - Carte édition

    private func editCard(icon: String, label: String,
                          text: Binding<String>, placeholder: String) -> some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: icon, label: label, showSeparator: true)
                CardRow(showSeparator: false) {
                    TextField(placeholder, text: text, axis: .vertical)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.bhEncre)
                        .lineLimit(3...8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - En-tête de champ partagé

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

    // MARK: - Couleur de bac

    private func trashBinColor(for line: String) -> Color? {
        let l = line.lowercased()
        if l.contains("jaune") { return Color(red: 241/255, green: 196/255, blue:  15/255) }
        if l.contains("vert")  { return Color(red:  39/255, green: 174/255, blue:  96/255) }
        if l.contains("bleu")  { return Color(red:  52/255, green: 152/255, blue: 219/255) }
        if l.contains("gris")  { return Color(red: 149/255, green: 165/255, blue: 166/255) }
        if l.contains("noir")  { return Color.black }
        return nil
    }

    // MARK: - État vide

    private var emptyCard: some View {
        ListCard {
            CardRow(showSeparator: false) {
                Text("Aucune information sur le quartier.")
                    .font(.system(size: 14.5))
                    .foregroundStyle(Color.bhAttenue)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Sauvegarde

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        guard let piJSON = draft.toJSONString() else {
            saveError = "Erreur de sérialisation"
            return
        }

        // Rules from relevé §1 :
        // - practicalInfo : JSON string, content in snake_case
        // - internalName + ownerId : always sent (even empty) to allow clearing
        // - photoUrl : always sent to preserve existing photo
        let fields: [(String, String)] = [
            ("practicalInfo", piJSON),
            ("internalName",  displayed.internalName ?? ""),
            ("ownerId",       displayed.ownerId      ?? ""),
            ("photoUrl",      displayed.photoUrl     ?? ""),
        ]

        do {
            let response: PropertyUpdateResponse = try await APIClient.shared.putMultipart(
                Endpoint.property(displayed.id),
                fields: fields,
                agencyAll: true
            )
            displayed = response.property
            onUpdate(response.property)
            isEditing = false
        } catch let err as APIError {
            switch err {
            case .server(_, let msg): saveError = msg ?? "Erreur serveur"
            case .network:            saveError = "Erreur réseau"
            case .decoding:           saveError = "Erreur de décodage de la réponse"
            case .unauthorized:       saveError = "Session expirée"
            case .subscriptionRequired: saveError = "Abonnement requis"
            }
        } catch {
            saveError = error.localizedDescription
        }
    }
}
