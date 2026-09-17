import SwiftUI

// MARK: - Draft

private struct IaDraft {
    struct QREdit: Identifiable { let id = UUID(); var keywords: String; var response: String }
    struct ReplyEdit: Identifiable { let id = UUID(); var title: String; var text: String }

    var autoResponsesEnabled: Bool
    var customAutoResponses: [QREdit]
    var quickReplies: [ReplyEdit]

    init(from p: Property) {
        autoResponsesEnabled = p.autoResponsesEnabled ?? true
        customAutoResponses = (p.customAutoResponses ?? []).map {
            QREdit(keywords: $0.keywords, response: $0.response)
        }
        quickReplies = (p.quickReplies ?? []).map {
            ReplyEdit(title: $0.title, text: $0.text)
        }
    }

    func customAutoResponsesJSON() -> String? {
        let arr = customAutoResponses.map { ["keywords": $0.keywords, "response": $0.response] }
        guard let data = try? JSONSerialization.data(withJSONObject: arr),
              let str  = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    func quickRepliesJSON() -> String? {
        let arr = quickReplies.prefix(5).map { ["title": $0.title, "text": $0.text] }
        guard let data = try? JSONSerialization.data(withJSONObject: arr),
              let str  = String(data: data, encoding: .utf8) else { return nil }
        return str
    }
}

// MARK: - Bloc "Assistant IA"

struct AssistantIABlockView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TipCoordinator.self) private var tipCoordinator

    private let onUpdate: (Property) -> Void

    @State private var displayed: Property
    @State private var draft: IaDraft
    @State private var isEditing   = false
    @State private var isSaving    = false
    @State private var saveError: String?

    @State private var facts: [PropertyFact] = []
    @State private var factsLoading = false
    @State private var factsLoaded  = false

    @State private var factError: String?
    @State private var isAddingFact   = false
    @State private var newFactQuestion = ""
    @State private var newFactAnswer   = true
    @State private var newFactDetail   = ""
    @State private var factSaving      = false

    init(property: Property, onUpdate: @escaping (Property) -> Void = { _ in }) {
        self.onUpdate = onUpdate
        self._displayed = State(initialValue: property)
        self._draft = State(initialValue: IaDraft(from: property))
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        statutCard
                        qrCard
                        if tipCoordinator.presentedTip == .assistantIAFacts {
                            ContextualTipView(
                                title: "L'IA retient vos informations",
                                message: "Ajoutez les informations propres à ce logement : consignes, particularités ou règles. L'IA pourra les utiliser dans ses réponses.",
                                onDismiss: { tipCoordinator.dismiss() }
                            )
                            .transition(.opacity)
                        }
                        faitsCard
                            .simultaneousGesture(TapGesture().onEnded {
                                guard tipCoordinator.presentedTip == .assistantIAFacts else { return }
                                TipCoordinator.shared.markSeen(.assistantIAFacts)
                            })
                        raccourcisCard
                    }
                    .animation(.easeInOut(duration: 0.25), value: tipCoordinator.presentedTip)
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task {
            await loadFacts()
            TipCoordinator.shared.tryPresent(.assistantIAFacts)
        }
        .onDisappear {
            TipCoordinator.shared.releaseIfPresented(.assistantIAFacts)
        }
        .alert("Erreur", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: { Text(saveError ?? "") }
        .alert("Erreur (fait)", isPresented: Binding(
            get: { factError != nil },
            set: { if !$0 { factError = nil } }
        )) {
            Button("OK") { factError = nil }
        } message: { Text(factError ?? "") }
    }

    // MARK: - Chargement des faits

    private func loadFacts() async {
        guard !factsLoaded else { return }
        factsLoading = true
        if let response: PropertyFactsResponse = try? await APIClient.shared.get(
            Endpoint.propertyFacts(displayed.id)
        ) {
            facts = response.facts
        }
        factsLoading = false
        factsLoaded = true
    }

    // MARK: - Nav bar

    private var navBar: some View {
        ZStack {
            VStack(spacing: 1) {
                Text(displayed.internalName ?? displayed.name)
                    .font(.bhSurTitre).foregroundStyle(Color.bhAttenue)
                    .lineLimit(1).truncationMode(.tail)
                Text("Assistant IA")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.bhEncre)
            }
            .padding(.horizontal, 96)
            HStack {
                if isEditing {
                    Button {
                        draft = IaDraft(from: displayed)
                        isEditing = false
                        isAddingFact = false
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
                        draft = IaDraft(from: displayed)
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

    // MARK: - Carte Statut

    private var statutCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "sparkles", label: "Statut", showSeparator: true)
                if isEditing {
                    CardRow(showSeparator: false) {
                        Toggle("Auto-réponses actives", isOn: $draft.autoResponsesEnabled)
                            .font(.system(size: 15)).foregroundStyle(Color.bhEncre).tint(Color.bhVert)
                    }
                } else {
                    CardRow(showSeparator: false) {
                        switch displayed.autoResponsesEnabled {
                        case .some(true):
                            Label("Actif", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 15)).foregroundStyle(Color.bhOccupe)
                        case .some(false):
                            Text("Inactif").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                        case .none:
                            Text("—").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Carte Q&R personnalisées

    private var qrCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "questionmark.bubble", label: "Q&R personnalisées",
                            showSeparator: isEditing || !(displayed.customAutoResponses ?? []).isEmpty)
                if isEditing {
                    ForEach(draft.customAutoResponses.indices, id: \.self) { idx in
                        qrEditRow(idx: idx)
                    }
                    CardRow(showSeparator: false) {
                        Button {
                            draft.customAutoResponses.append(
                                IaDraft.QREdit(keywords: "", response: "")
                            )
                        } label: {
                            Label("Ajouter une Q&R", systemImage: "plus.circle.fill")
                                .font(.system(size: 14.5)).foregroundStyle(Color.bhVert)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    let qrs = displayed.customAutoResponses ?? []
                    if qrs.isEmpty {
                        CardRow(showSeparator: false) {
                            Text("Aucune Q&R personnalisée.")
                                .font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        ForEach(Array(qrs.enumerated()), id: \.offset) { idx, qr in
                            CardRow(showSeparator: idx < qrs.count - 1) { qrReadEntry(qr) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func qrEditRow(idx: Int) -> some View {
        let isLast = idx == draft.customAutoResponses.count - 1
        CardRow(showSeparator: !isLast || true) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Mots-clés")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.bhAttenue)
                    Spacer()
                    Button {
                        draft.customAutoResponses.remove(at: idx)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 17)).foregroundStyle(Color.bhTerracotta)
                    }
                    .buttonStyle(.plain)
                }
                TextField("piscine, pool, wifi…", text: $draft.customAutoResponses[idx].keywords)
                    .font(.system(size: 14)).foregroundStyle(Color.bhEncre)
                Text("Réponse")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.bhAttenue)
                TextField("La réponse à envoyer au voyageur",
                          text: $draft.customAutoResponses[idx].response, axis: .vertical)
                    .font(.system(size: 14)).foregroundStyle(Color.bhEncre).lineLimit(2...6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func qrReadEntry(_ qr: CustomAutoResponse) -> some View {
        let keywords = qr.keywords.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return VStack(alignment: .leading, spacing: 8) {
            if !keywords.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Mots-clés")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.bhAttenue)
                    ForEach(keywords, id: \.self) { kw in
                        HStack(alignment: .center, spacing: 8) {
                            Circle().fill(Color.bhAttenue).frame(width: 4, height: 4)
                            Text(kw).font(.system(size: 13.5)).foregroundStyle(Color.bhEncre)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Réponse")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.bhAttenue)
                Text(qr.response).font(.system(size: 13.5)).lineSpacing(4).foregroundStyle(Color.bhEncre)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Carte Faits mémorisés (opérations immédiates)

    private var faitsCard: some View {
        ListCard {
            VStack(spacing: 0) {
                let showSep = factsLoading || !facts.isEmpty || isEditing
                fieldHeader(icon: "brain", label: "Faits mémorisés", showSeparator: showSep)
                if factsLoading {
                    CardRow(showSeparator: false) {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text("Chargement…").font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
                        }
                    }
                } else if facts.isEmpty && !isEditing {
                    CardRow(showSeparator: false) {
                        Text("Aucun fait mémorisé.")
                            .font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ForEach(Array(facts.enumerated()), id: \.element.id) { idx, fact in
                        CardRow(showSeparator: idx < facts.count - 1 || isEditing) {
                            factRow(fact)
                        }
                    }
                    if isEditing {
                        if isAddingFact {
                            newFactForm
                        } else {
                            CardRow(showSeparator: false) {
                                Button {
                                    newFactQuestion = ""
                                    newFactAnswer = true
                                    newFactDetail = ""
                                    isAddingFact = true
                                } label: {
                                    Label("Ajouter un fait", systemImage: "plus.circle.fill")
                                        .font(.system(size: 14.5)).foregroundStyle(Color.bhVert)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func factRow(_ fact: PropertyFact) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(fact.question).font(.system(size: 14.5)).foregroundStyle(Color.bhEncre)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if fact.answer == true {
                        Label("Oui", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13.5)).foregroundStyle(Color.bhOccupe).fixedSize()
                    } else if fact.answer == false {
                        Label("Non", systemImage: "xmark.circle.fill")
                            .font(.system(size: 13.5)).foregroundStyle(Color.bhAttenue).fixedSize()
                    } else {
                        Text("—").font(.system(size: 13.5)).foregroundStyle(Color.bhAttenue)
                    }
                }
                if let detail = fact.detail, !detail.isEmpty {
                    Text(detail).font(.system(size: 12.5)).lineSpacing(3).foregroundStyle(Color.bhAttenue)
                }
            }
            if isEditing {
                Button { Task { await deleteFact(fact.id) } } label: {
                    Image(systemName: "trash").font(.system(size: 15)).foregroundStyle(Color.bhTerracotta)
                }
                .buttonStyle(.plain).disabled(factSaving)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var newFactForm: some View {
        CardRow(showSeparator: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Nouveau fait")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.bhAttenue)
                TextField("Question (ex: Y a-t-il une piscine ?)", text: $newFactQuestion)
                    .font(.system(size: 14)).foregroundStyle(Color.bhEncre)
                Toggle("Réponse", isOn: $newFactAnswer)
                    .font(.system(size: 14)).foregroundStyle(Color.bhEncre).tint(Color.bhVert)
                TextField("Précision (optionnel)", text: $newFactDetail, axis: .vertical)
                    .font(.system(size: 13.5)).foregroundStyle(Color.bhEncre).lineLimit(1...4)
                HStack(spacing: 12) {
                    Button("Annuler") { isAddingFact = false }
                        .font(.system(size: 14)).foregroundStyle(Color.bhAttenue)
                        .buttonStyle(.plain)
                    Spacer()
                    Button {
                        Task { await addFact() }
                    } label: {
                        if factSaving {
                            ProgressView().controlSize(.small).tint(Color.bhVert)
                        } else {
                            Text("Ajouter").font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(newFactQuestion.isEmpty ? Color.bhAttenue : Color.bhVert)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(newFactQuestion.isEmpty || factSaving)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Carte Raccourcis

    private var raccourcisCard: some View {
        ListCard {
            VStack(spacing: 0) {
                let replies = isEditing ? draft.quickReplies : (displayed.quickReplies ?? []).map {
                    IaDraft.ReplyEdit(title: $0.title, text: $0.text)
                }
                fieldHeader(icon: "bolt.fill", label: "Raccourcis (max 5)",
                            showSeparator: !replies.isEmpty || isEditing)
                if replies.isEmpty && !isEditing {
                    CardRow(showSeparator: false) {
                        Text("Aucun raccourci configuré.")
                            .font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if isEditing {
                    ForEach(draft.quickReplies.indices, id: \.self) { idx in
                        replyEditRow(idx: idx)
                    }
                    if draft.quickReplies.count < 5 {
                        CardRow(showSeparator: false) {
                            Button {
                                draft.quickReplies.append(IaDraft.ReplyEdit(title: "", text: ""))
                            } label: {
                                Label("Ajouter un raccourci", systemImage: "plus.circle.fill")
                                    .font(.system(size: 14.5)).foregroundStyle(Color.bhVert)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    ForEach(Array(replies.enumerated()), id: \.offset) { idx, reply in
                        CardRow(showSeparator: idx < replies.count - 1) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(reply.title).font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.bhEncre)
                                Text(reply.text).font(.system(size: 13.5)).lineSpacing(4)
                                    .foregroundStyle(Color.bhAttenue)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func replyEditRow(idx: Int) -> some View {
        let isLast = idx == draft.quickReplies.count - 1
        CardRow(showSeparator: !isLast || draft.quickReplies.count < 5) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Titre").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.bhAttenue)
                    Spacer()
                    Text("\(draft.quickReplies[idx].title.count)/50")
                        .font(.system(size: 11)).foregroundStyle(
                            draft.quickReplies[idx].title.count > 50 ? Color.bhTerracotta : Color.bhAttenue
                        )
                    Button {
                        draft.quickReplies.remove(at: idx)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 17)).foregroundStyle(Color.bhTerracotta)
                    }
                    .buttonStyle(.plain)
                }
                TextField("Libellé du bouton", text: $draft.quickReplies[idx].title)
                    .font(.system(size: 14)).foregroundStyle(Color.bhEncre)
                    .onChange(of: draft.quickReplies[idx].title) { _, v in
                        if v.count > 50 { draft.quickReplies[idx].title = String(v.prefix(50)) }
                    }
                HStack {
                    Text("Message").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.bhAttenue)
                    Spacer()
                    Text("\(draft.quickReplies[idx].text.count)/200")
                        .font(.system(size: 11)).foregroundStyle(
                            draft.quickReplies[idx].text.count > 200 ? Color.bhTerracotta : Color.bhAttenue
                        )
                }
                TextField("Message envoyé au voyageur",
                          text: $draft.quickReplies[idx].text, axis: .vertical)
                    .font(.system(size: 13.5)).foregroundStyle(Color.bhEncre).lineLimit(2...6)
                    .onChange(of: draft.quickReplies[idx].text) { _, v in
                        if v.count > 200 { draft.quickReplies[idx].text = String(v.prefix(200)) }
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

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

    // MARK: - Opérations immédiates sur les faits

    private func addFact() async {
        guard !newFactQuestion.isEmpty else { return }
        factSaving = true
        defer { factSaving = false }
        struct FactBody: Encodable { let question: String; let answer: Bool; let detail: String? }
        let body = FactBody(
            question: newFactQuestion,
            answer: newFactAnswer,
            detail: newFactDetail.isEmpty ? nil : newFactDetail
        )
        do {
            let r: PropertyFactAddResponse = try await APIClient.shared.post(
                Endpoint.propertyFacts(displayed.id), body: body
            )
            facts.append(r.fact)
            newFactQuestion = ""; newFactDetail = ""; newFactAnswer = true
            isAddingFact = false
        } catch {
            factError = (error as? APIError).flatMap {
                if case .server(_, let m) = $0 { return m }
                return nil
            } ?? error.localizedDescription
        }
    }

    private func deleteFact(_ factId: Int) async {
        factSaving = true
        defer { factSaving = false }
        do {
            try await APIClient.shared.delete(Endpoint.propertyFact(displayed.id, factId: factId))
            facts.removeAll { $0.id == factId }
        } catch {
            factError = (error as? APIError).flatMap {
                if case .server(_, let m) = $0 { return m }
                return nil
            } ?? error.localizedDescription
        }
    }

    // MARK: - Sauvegarde principale

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        guard let qrJSON      = draft.customAutoResponsesJSON(),
              let repliesJSON = draft.quickRepliesJSON() else {
            saveError = "Erreur de sérialisation"
            return
        }

        let enabledStr = draft.autoResponsesEnabled ? "true" : "false"

        let fields: [(String, String)] = [
            ("internalName",         displayed.internalName ?? ""),
            ("ownerId",              displayed.ownerId      ?? ""),
            ("photoUrl",             displayed.photoUrl     ?? ""),
            ("autoResponsesEnabled", enabledStr),
            ("customAutoResponses",  qrJSON),
            ("quickReplies",         repliesJSON),
        ]

        do {
            let r: PropertyUpdateResponse = try await APIClient.shared.putMultipart(
                Endpoint.property(displayed.id), fields: fields, agencyAll: true
            )
            displayed = r.property
            onUpdate(r.property)
            isEditing = false
            isAddingFact = false
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
