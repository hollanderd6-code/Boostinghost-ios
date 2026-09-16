import SwiftUI

// MARK: - Draft

private struct AccesDraft {
    var accessCode: String
    var wifiName: String
    var wifiPassword: String
    var accessInstructions: String

    init(from p: Property) {
        accessCode          = p.accessCode          ?? ""
        wifiName            = p.wifiName            ?? ""
        wifiPassword        = p.wifiPassword        ?? ""
        accessInstructions  = p.accessInstructions  ?? ""
    }
}

// MARK: - Bloc "Accès" — LIVRET

struct AccesBlockView: View {
    @Environment(\.dismiss) private var dismiss

    private let onUpdate: (Property) -> Void

    @State private var displayed: Property
    @State private var draft: AccesDraft
    @State private var isEditing = false
    @State private var isSaving  = false
    @State private var saveError: String?

    init(property: Property, onUpdate: @escaping (Property) -> Void = { _ in }) {
        self.onUpdate = onUpdate
        self._displayed = State(initialValue: property)
        self._draft = State(initialValue: AccesDraft(from: property))
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
                            codeEditCard
                            wifiEditCard
                            instructionsEditCard
                        } else {
                            if let code = displayed.accessCode, !code.isEmpty {
                                simpleCard(icon: "key.fill", label: "Code d'accès", value: code)
                            }
                            if hasWifi { wifiCard }
                            if let instr = displayed.accessInstructions, !instr.isEmpty {
                                fieldCard(icon: "text.alignleft", label: "Instructions", value: instr)
                            }
                            if !hasAnyAcces { emptyCard }
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
        } message: { Text(saveError ?? "") }
    }

    private var hasAnyAcces: Bool {
        (displayed.accessCode?.isEmpty == false) || hasWifi
            || (displayed.accessInstructions?.isEmpty == false)
    }

    private var hasWifi: Bool {
        displayed.wifiName?.isEmpty == false || displayed.wifiPassword?.isEmpty == false
    }

    // MARK: - Nav bar

    private var navBar: some View {
        ZStack {
            VStack(spacing: 1) {
                Text(displayed.internalName ?? displayed.name)
                    .font(.bhSurTitre).foregroundStyle(Color.bhAttenue)
                    .lineLimit(1).truncationMode(.tail)
                Text("Accès")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.bhEncre)
            }
            .padding(.horizontal, 96)
            HStack {
                if isEditing {
                    Button {
                        draft = AccesDraft(from: displayed)
                        isEditing = false
                    } label: {
                        Text("Annuler")
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(Color.bhVert)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .glassEffect(in: .rect(cornerRadius: 12)).specularEdge(cornerRadius: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.bhVert)
                            .frame(width: 36, height: 36)
                            .glassEffect(in: .circle).specularEdge(cornerRadius: 18)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if isEditing {
                    Button { Task { await save() } } label: {
                        if isSaving {
                            ProgressView().tint(Color.bhVert)
                                .frame(width: 24, height: 24).padding(.horizontal, 18).padding(.vertical, 7)
                        } else {
                            Text("Enregistrer")
                                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.bhVert)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .glassEffect(in: .rect(cornerRadius: 12)).specularEdge(cornerRadius: 12)
                        }
                    }
                    .buttonStyle(.plain).disabled(isSaving)
                } else {
                    Button {
                        draft = AccesDraft(from: displayed)
                        isEditing = true
                    } label: {
                        Text("Modifier")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.bhVert)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .glassEffect(in: .rect(cornerRadius: 12)).specularEdge(cornerRadius: 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 14)
        .background {
            Rectangle().glassEffect(in: .rect).specularEdge(cornerRadius: 0)
                .chromeShadow().ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Bandeau LIVRET

    private var livretBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 15, weight: .medium)).foregroundStyle(Color.bhVert)
                .frame(width: 22, alignment: .center)
            Text("Le code, le WiFi et les instructions partent directement dans le livret d'accueil. Tu ne les saisis qu'ici.")
                .font(.system(size: 13.5)).foregroundStyle(Color.bhOccupeFonce)
                .lineSpacing(3.5).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.bhMentheFond)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(red: 46/255, green: 139/255, blue: 98/255).opacity(0.28), lineWidth: 1)
                }
        }
    }

    // MARK: - Cartes lecture

    private var wifiCard: some View {
        ListCard {
            VStack(spacing: 0) {
                let hasPwd = displayed.wifiPassword?.isEmpty == false
                fieldHeader(icon: "wifi", label: "WiFi", showSeparator: true)
                if let name = displayed.wifiName, !name.isEmpty {
                    CardRow(showSeparator: hasPwd) {
                        HStack {
                            Text("Réseau").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                            Spacer()
                            Text(name).font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                        }
                    }
                }
                if let pwd = displayed.wifiPassword, !pwd.isEmpty {
                    CardRow(showSeparator: false) {
                        HStack {
                            Text("Mot de passe").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                            Spacer()
                            Text(pwd).font(.system(size: 15, design: .monospaced)).foregroundStyle(Color.bhEncre)
                        }
                    }
                }
            }
        }
    }

    private var emptyCard: some View {
        ListCard {
            CardRow(showSeparator: false) {
                Text("Aucune information d'accès renseignée.")
                    .font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func simpleCard(icon: String, label: String, value: String) -> some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: icon, label: label, showSeparator: true)
                CardRow(showSeparator: false) {
                    Text(value).font(.system(size: 15, design: .monospaced)).foregroundStyle(Color.bhEncre)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func fieldCard(icon: String, label: String, value: String) -> some View {
        let lines = value.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: icon, label: label, showSeparator: !lines.isEmpty)
                ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                    CardRow(showSeparator: idx < lines.count - 1) {
                        Text(line).font(.system(size: 15)).lineSpacing(8)
                            .foregroundStyle(Color.bhEncre)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: - Cartes édition

    private var codeEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "key.fill", label: "Code d'accès", showSeparator: true)
                CardRow(showSeparator: false) {
                    TextField("Code de la boîte à clés, digicode…", text: $draft.accessCode)
                        .font(.system(size: 15, design: .monospaced)).foregroundStyle(Color.bhEncre)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var wifiEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "wifi", label: "WiFi", showSeparator: true)
                CardRow(showSeparator: true) {
                    HStack {
                        Text("Réseau").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                        Spacer()
                        TextField("Nom du réseau", text: $draft.wifiName)
                            .font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                            .multilineTextAlignment(.trailing)
                    }
                }
                CardRow(showSeparator: false) {
                    HStack {
                        Text("Mot de passe").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                        Spacer()
                        TextField("Mot de passe", text: $draft.wifiPassword)
                            .font(.system(size: 15, design: .monospaced)).foregroundStyle(Color.bhEncre)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
    }

    private var instructionsEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "text.alignleft", label: "Instructions", showSeparator: true)
                CardRow(showSeparator: false) {
                    TextField("Comment accéder au logement ?", text: $draft.accessInstructions,
                              axis: .vertical)
                        .font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                        .lineLimit(3...10).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private func fieldHeader(icon: String, label: String, showSeparator: Bool) -> some View {
        CardRow(showSeparator: showSeparator) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(Color.bhVert)
                    .frame(width: 20, alignment: .center)
                Text(label.uppercased())
                    .font(.system(size: 12, weight: .bold)).tracking(0.96)
                    .foregroundStyle(Color.bhAttenue)
                Spacer()
            }
        }
    }

    // MARK: - Sauvegarde

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let fields: [(String, String)] = [
            ("internalName",        displayed.internalName ?? ""),
            ("ownerId",             displayed.ownerId      ?? ""),
            ("photoUrl",            displayed.photoUrl     ?? ""),
            ("accessCode",          draft.accessCode),
            ("wifiName",            draft.wifiName),
            ("wifiPassword",        draft.wifiPassword),
            ("accessInstructions",  draft.accessInstructions),
        ]

        do {
            let r: PropertyUpdateResponse = try await APIClient.shared.putMultipart(
                Endpoint.property(displayed.id), fields: fields, agencyAll: true
            )
            displayed = r.property
            onUpdate(r.property)
            NotificationCenter.default.post(name: .setupShouldRefresh, object: nil)
            isEditing = false
        } catch let err as APIError {
            switch err {
            case .server(_, let msg):   saveError = msg ?? "Erreur serveur"
            case .network:              saveError = "Erreur réseau"
            case .decoding:             saveError = "Erreur de décodage"
            case .unauthorized:         saveError = "Session expirée"
            case .subscriptionRequired: saveError = "Abonnement requis"
            }
        } catch {
            saveError = error.localizedDescription
        }
    }
}
