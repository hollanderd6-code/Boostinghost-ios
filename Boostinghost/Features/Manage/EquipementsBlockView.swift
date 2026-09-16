import SwiftUI

// MARK: - Draft

private struct EquipDraft {
    // Amenities — all 8 keys always sent
    var draps: Bool
    var serviettes: Bool
    var cuisineEquipee: Bool
    var laveLinge: Bool
    var laveVaisselle: Bool
    var television: Bool
    var parking: Bool
    var climatisation: Bool
    var customEquip: [String]

    // House rules — 4 nullable booleans + custom
    var animaux: Bool?
    var fumeurs: Bool?
    var fetes: Bool?
    var enfants: Bool?
    var customRules: [String]

    init(from p: Property) {
        let a = p.amenities
        draps         = a?.draps         ?? false
        serviettes    = a?.serviettes    ?? false
        cuisineEquipee = a?.cuisineEquipee ?? false
        laveLinge     = a?.laveLinge     ?? false
        laveVaisselle = a?.laveVaisselle ?? false
        television    = a?.television    ?? false
        parking       = a?.parking       ?? false
        climatisation = a?.climatisation ?? false
        customEquip   = (a?.custom ?? []).filter { !$0.isEmpty }

        let r = p.houseRules
        animaux     = r?.animaux
        fumeurs     = r?.fumeurs
        fetes       = r?.fetes
        enfants     = r?.enfants
        customRules = (r?.custom ?? []).filter { !$0.isEmpty }
    }

    // ALL 8 boolean keys + custom — instruction "toutes les clés du relevé"
    func amenitiesJSON() -> String? {
        var dict: [String: Any] = [
            "draps":          draps,
            "serviettes":     serviettes,
            "cuisineEquipee": cuisineEquipee,
            "laveLinge":      laveLinge,
            "laveVaisselle":  laveVaisselle,
            "television":     television,
            "parking":        parking,
            "climatisation":  climatisation,
        ]
        let filtered = customEquip.filter { !$0.isEmpty }
        if !filtered.isEmpty { dict["custom"] = filtered }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str  = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    // ALL 4 rule keys (nil → NSNull) + custom
    func houseRulesJSON() -> String? {
        var dict: [String: Any] = [
            "animaux": animaux.map { $0 as Any } ?? NSNull(),
            "fumeurs": fumeurs.map { $0 as Any } ?? NSNull(),
            "fetes":   fetes.map   { $0 as Any } ?? NSNull(),
            "enfants": enfants.map { $0 as Any } ?? NSNull(),
        ]
        let filtered = customRules.filter { !$0.isEmpty }
        if !filtered.isEmpty { dict["custom"] = filtered }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str  = String(data: data, encoding: .utf8) else { return nil }
        return str
    }
}

// MARK: - Bloc "Équipements & règles" — LIVRET

struct EquipementsBlockView: View {
    @Environment(\.dismiss) private var dismiss

    private let onUpdate: (Property) -> Void

    @State private var displayed: Property
    @State private var draft: EquipDraft
    @State private var isEditing = false
    @State private var isSaving  = false
    @State private var saveError: String?

    init(property: Property, onUpdate: @escaping (Property) -> Void = { _ in }) {
        self.onUpdate = onUpdate
        self._displayed = State(initialValue: property)
        self._draft = State(initialValue: EquipDraft(from: property))
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
                            equipEditCard
                            reglementEditCard
                        } else {
                            if hasEquipements { equipementsCard }
                            if hasReglement   { reglementCard   }
                            if !hasEquipements && !hasReglement { emptyCard }
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

    // MARK: - Nav bar

    private var navBar: some View {
        ZStack {
            VStack(spacing: 1) {
                Text(displayed.internalName ?? displayed.name)
                    .font(.bhSurTitre).foregroundStyle(Color.bhAttenue)
                    .lineLimit(1).truncationMode(.tail)
                Text("Équipements & règles")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.bhEncre)
            }
            .padding(.horizontal, 96)
            HStack {
                if isEditing {
                    Button {
                        draft = EquipDraft(from: displayed)
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
                        draft = EquipDraft(from: displayed)
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
            Text("Les équipements et le règlement partent directement dans le livret d'accueil. Tu ne les saisis qu'ici.")
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

    private var hasEquipements: Bool {
        displayed.amenities?.hasAny == true || (displayed.amenities?.custom?.isEmpty == false)
    }

    private var equipementItems: [String] {
        guard let a = displayed.amenities else { return [] }
        var items: [String] = []
        if a.draps          == true { items.append("Draps fournis") }
        if a.serviettes     == true { items.append("Serviettes fournies") }
        if a.cuisineEquipee == true { items.append("Cuisine équipée") }
        if a.laveLinge      == true { items.append("Lave-linge") }
        if a.laveVaisselle  == true { items.append("Lave-vaisselle") }
        if a.television     == true { items.append("Télévision") }
        if a.parking        == true { items.append("Parking") }
        if a.climatisation  == true { items.append("Climatisation") }
        items += (a.custom ?? []).filter { !$0.isEmpty }
        return items
    }

    private var equipementsCard: some View {
        let items = equipementItems
        return ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "house.fill", label: "Équipements", showSeparator: !items.isEmpty)
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    CardRow(showSeparator: idx < items.count - 1) {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.bhOccupe).frame(width: 16, alignment: .center)
                            Text(item).font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                        }
                    }
                }
            }
        }
    }

    private var hasReglement: Bool {
        displayed.houseRules?.isDefined == true || (displayed.houseRules?.custom?.isEmpty == false)
    }

    private var reglementItems: [(label: String, allowed: Bool)] {
        guard let r = displayed.houseRules else { return [] }
        var items: [(String, Bool)] = []
        if let v = r.animaux { items.append(("Animaux", v)) }
        if let v = r.fumeurs { items.append(("Fumeurs", v)) }
        if let v = r.fetes   { items.append(("Fêtes", v)) }
        if let v = r.enfants { items.append(("Enfants", v)) }
        return items
    }

    private var reglementCard: some View {
        let rules = reglementItems
        let customs = (displayed.houseRules?.custom ?? []).filter { !$0.isEmpty }
        let total = rules.count + customs.count
        return ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "hand.raised.fill", label: "Règlement", showSeparator: total > 0)
                ForEach(Array(rules.enumerated()), id: \.offset) { idx, rule in
                    CardRow(showSeparator: idx < total - 1) {
                        HStack(spacing: 10) {
                            Image(systemName: rule.allowed ? "checkmark" : "xmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(rule.allowed ? Color.bhOccupe : Color.bhTerracotta)
                                .frame(width: 16, alignment: .center)
                            Text(rule.allowed
                                 ? "\(rule.label) accepté\(rule.label == "Fêtes" ? "es" : "s")"
                                 : "\(rule.label) non autorisé\(rule.label == "Fêtes" ? "es" : "s")")
                                .font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                        }
                    }
                }
                ForEach(Array(customs.enumerated()), id: \.offset) { idx, custom in
                    CardRow(showSeparator: idx < customs.count - 1) {
                        Text(custom).font(.system(size: 15)).lineSpacing(8)
                            .foregroundStyle(Color.bhEncre)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var emptyCard: some View {
        ListCard {
            CardRow(showSeparator: false) {
                Text("Aucun équipement ni règlement renseigné.")
                    .font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Cartes édition

    private var equipEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "house.fill", label: "Équipements", showSeparator: true)
                toggleRow("Draps fournis",     isOn: $draft.draps,         showSep: true)
                toggleRow("Serviettes fournies", isOn: $draft.serviettes,  showSep: true)
                toggleRow("Cuisine équipée",   isOn: $draft.cuisineEquipee, showSep: true)
                toggleRow("Lave-linge",        isOn: $draft.laveLinge,     showSep: true)
                toggleRow("Lave-vaisselle",    isOn: $draft.laveVaisselle, showSep: true)
                toggleRow("Télévision",        isOn: $draft.television,    showSep: true)
                toggleRow("Parking",           isOn: $draft.parking,       showSep: true)
                toggleRow("Climatisation",     isOn: $draft.climatisation, showSep: !draft.customEquip.isEmpty)
                ForEach(draft.customEquip.indices, id: \.self) { idx in
                    let isLast = idx == draft.customEquip.count - 1
                    CardRow(showSeparator: !isLast) {
                        HStack(spacing: 10) {
                            TextField("Équipement personnalisé", text: $draft.customEquip[idx])
                                .font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                            Spacer(minLength: 4)
                            Button {
                                draft.customEquip.remove(at: idx)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 17)).foregroundStyle(Color.bhTerracotta)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                CardRow(showSeparator: false) {
                    Button { draft.customEquip.append("") } label: {
                        Label("Ajouter un équipement", systemImage: "plus.circle.fill")
                            .font(.system(size: 14.5)).foregroundStyle(Color.bhVert)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var reglementEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "hand.raised.fill", label: "Règlement", showSeparator: true)
                ruleRow("Animaux", value: $draft.animaux,  showSep: true)
                ruleRow("Fumeurs", value: $draft.fumeurs,  showSep: true)
                ruleRow("Fêtes",   value: $draft.fetes,    showSep: true)
                ruleRow("Enfants", value: $draft.enfants,  showSep: !draft.customRules.isEmpty)
                ForEach(draft.customRules.indices, id: \.self) { idx in
                    let isLast = idx == draft.customRules.count - 1
                    CardRow(showSeparator: !isLast) {
                        HStack(spacing: 10) {
                            TextField("Règle personnalisée", text: $draft.customRules[idx])
                                .font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                            Spacer(minLength: 4)
                            Button {
                                draft.customRules.remove(at: idx)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 17)).foregroundStyle(Color.bhTerracotta)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                CardRow(showSeparator: false) {
                    Button { draft.customRules.append("") } label: {
                        Label("Ajouter une règle", systemImage: "plus.circle.fill")
                            .font(.system(size: 14.5)).foregroundStyle(Color.bhVert)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Row helpers

    @ViewBuilder
    private func toggleRow(_ label: String, isOn: Binding<Bool>, showSep: Bool) -> some View {
        CardRow(showSeparator: showSep) {
            Toggle(label, isOn: isOn)
                .font(.system(size: 15)).foregroundStyle(Color.bhEncre).tint(Color.bhVert)
        }
    }

    @ViewBuilder
    private func ruleRow(_ label: String, value: Binding<Bool?>, showSep: Bool) -> some View {
        CardRow(showSeparator: showSep) {
            HStack {
                Text(label).font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                Spacer()
                Picker("", selection: value) {
                    Text("Non précisé").tag(Bool?.none)
                    Text("Autorisé").tag(Bool?.some(true))
                    Text("Non autorisé").tag(Bool?.some(false))
                }
                .pickerStyle(.menu)
                .tint(Color.bhVert)
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

        guard let amenJSON = draft.amenitiesJSON(),
              let rulesJSON = draft.houseRulesJSON() else {
            saveError = "Erreur de sérialisation"
            return
        }

        let fields: [(String, String)] = [
            ("internalName", displayed.internalName ?? ""),
            ("ownerId",      displayed.ownerId      ?? ""),
            ("photoUrl",     displayed.photoUrl     ?? ""),
            ("amenities",    amenJSON),
            ("houseRules",   rulesJSON),
        ]

        do {
            let r: PropertyUpdateResponse = try await APIClient.shared.putMultipart(
                Endpoint.property(displayed.id), fields: fields, agencyAll: true
            )
            displayed = r.property
            onUpdate(r.property)
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
