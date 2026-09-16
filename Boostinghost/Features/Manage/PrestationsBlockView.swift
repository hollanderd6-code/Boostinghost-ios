import SwiftUI

// MARK: - Draft

private struct PrestationsDraft {
    var lcoEnabled: Bool
    var lcoTolerance: String
    var lcoPrice: String
    var lcoMax: String

    var eciEnabled: Bool
    var eciTolerance: String
    var eciPrice: String
    var eciMax: String

    var basketEnabled: Bool
    var basketPrice: String
    var basketDescription: String

    init(from p: Property) {
        lcoEnabled   = p.lateCheckoutEnabled  ?? false
        lcoTolerance = p.lateCheckoutToleranceMinutes.map { String($0) } ?? ""
        lcoPrice     = numStr(p.lateCheckoutPricePerHour)
        lcoMax       = p.lateCheckoutMaxMinutes.map { String($0) } ?? ""

        eciEnabled   = p.earlyCheckinEnabled   ?? false
        eciTolerance = p.earlyCheckinToleranceMinutes.map { String($0) } ?? ""
        eciPrice     = numStr(p.earlyCheckinPricePerHour)
        eciMax       = p.earlyCheckinMaxMinutes.map { String($0) } ?? ""

        basketEnabled      = p.welcomeBasketEnabled ?? false
        basketPrice        = numStr(p.welcomeBasketPrice)
        basketDescription  = p.welcomeBasketDescription ?? ""
    }
}

private func numStr(_ d: Double?) -> String {
    guard let d else { return "" }
    return d.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(d)) : String(d)
}

// MARK: - Encodable body for PUT /upsell

private struct UpsellBody: Encodable {
    let lateCheckoutEnabled: Bool
    let lateCheckoutToleranceMinutes: Int?
    let lateCheckoutPricePerHour: Double?
    let lateCheckoutMaxMinutes: Int?
    let earlyCheckinEnabled: Bool
    let earlyCheckinToleranceMinutes: Int?
    let earlyCheckinPricePerHour: Double?
    let earlyCheckinMaxMinutes: Int?
    let welcomeBasketEnabled: Bool
    let welcomeBasketPrice: Double?
    let welcomeBasketDescription: String?

    enum CodingKeys: String, CodingKey {
        case lateCheckoutEnabled           = "late_checkout_enabled"
        case lateCheckoutToleranceMinutes  = "late_checkout_tolerance_minutes"
        case lateCheckoutPricePerHour      = "late_checkout_price_per_hour"
        case lateCheckoutMaxMinutes        = "late_checkout_max_minutes"
        case earlyCheckinEnabled           = "early_checkin_enabled"
        case earlyCheckinToleranceMinutes  = "early_checkin_tolerance_minutes"
        case earlyCheckinPricePerHour      = "early_checkin_price_per_hour"
        case earlyCheckinMaxMinutes        = "early_checkin_max_minutes"
        case welcomeBasketEnabled          = "welcome_basket_enabled"
        case welcomeBasketPrice            = "welcome_basket_price"
        case welcomeBasketDescription      = "welcome_basket_description"
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(lateCheckoutEnabled,          forKey: .lateCheckoutEnabled)
        try c.encodeIfPresent(lateCheckoutToleranceMinutes, forKey: .lateCheckoutToleranceMinutes)
        try c.encodeIfPresent(lateCheckoutPricePerHour,     forKey: .lateCheckoutPricePerHour)
        try c.encodeIfPresent(lateCheckoutMaxMinutes,       forKey: .lateCheckoutMaxMinutes)
        try c.encode(earlyCheckinEnabled,          forKey: .earlyCheckinEnabled)
        try c.encodeIfPresent(earlyCheckinToleranceMinutes, forKey: .earlyCheckinToleranceMinutes)
        try c.encodeIfPresent(earlyCheckinPricePerHour,     forKey: .earlyCheckinPricePerHour)
        try c.encodeIfPresent(earlyCheckinMaxMinutes,       forKey: .earlyCheckinMaxMinutes)
        try c.encode(welcomeBasketEnabled,         forKey: .welcomeBasketEnabled)
        try c.encodeIfPresent(welcomeBasketPrice,           forKey: .welcomeBasketPrice)
        try c.encodeIfPresent(welcomeBasketDescription,     forKey: .welcomeBasketDescription)
    }
}

// MARK: - Bloc "Prestations payantes"

struct PrestationsBlockView: View {
    @Environment(\.dismiss) private var dismiss

    private let onUpdate: (Property) -> Void

    @State private var displayed: Property
    @State private var draft: PrestationsDraft
    @State private var isEditing = false
    @State private var isSaving  = false
    @State private var saveError: String?

    init(property: Property, onUpdate: @escaping (Property) -> Void = { _ in }) {
        self.onUpdate = onUpdate
        self._displayed = State(initialValue: property)
        self._draft = State(initialValue: PrestationsDraft(from: property))
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if isEditing {
                            lcoEditCard
                            eciEditCard
                            basketEditCard
                        } else {
                            if displayed.lateCheckoutEnabled  == true { lateCheckoutCard }
                            if displayed.earlyCheckinEnabled  == true { earlyCheckinCard }
                            if displayed.welcomeBasketEnabled == true { welcomeBasketCard }
                            if !hasAnyService { emptyCard }
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
        .numericKeyboardBar()
        .alert("Erreur", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: { Text(saveError ?? "") }
    }

    private var hasAnyService: Bool {
        displayed.lateCheckoutEnabled == true
            || displayed.earlyCheckinEnabled == true
            || displayed.welcomeBasketEnabled == true
    }

    // MARK: - Nav bar

    private var navBar: some View {
        ZStack {
            VStack(spacing: 1) {
                Text(displayed.internalName ?? displayed.name)
                    .font(.bhSurTitre).foregroundStyle(Color.bhAttenue)
                    .lineLimit(1).truncationMode(.tail)
                Text("Prestations payantes")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.bhEncre)
            }
            .padding(.horizontal, 96)
            HStack {
                if isEditing {
                    Button {
                        draft = PrestationsDraft(from: displayed)
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
                        draft = PrestationsDraft(from: displayed)
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

    // MARK: - Cartes lecture

    private var lateCheckoutCard: some View {
        let rows = lcoRows
        return ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "moon.zzz", label: "Check-out tardif", showSeparator: !rows.isEmpty)
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    CardRow(showSeparator: idx < rows.count - 1) {
                        HStack {
                            Text(row.0).font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                            Spacer()
                            Text(row.1).font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                        }
                    }
                }
            }
        }
    }

    private var lcoRows: [(String, String)] {
        var rows: [(String, String)] = []
        if let t = displayed.lateCheckoutToleranceMinutes, t > 0 { rows.append(("Tolérance gratuite", duration(t))) }
        if let p = displayed.lateCheckoutPricePerHour,     p > 0 { rows.append(("Tarif", "\(Formatters.amount(p)) / h")) }
        if let m = displayed.lateCheckoutMaxMinutes,        m > 0 { rows.append(("Maximum", duration(m))) }
        return rows
    }

    private var earlyCheckinCard: some View {
        let rows = eciRows
        return ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "sun.horizon.fill", label: "Check-in anticipé", showSeparator: !rows.isEmpty)
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    CardRow(showSeparator: idx < rows.count - 1) {
                        HStack {
                            Text(row.0).font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                            Spacer()
                            Text(row.1).font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                        }
                    }
                }
            }
        }
    }

    private var eciRows: [(String, String)] {
        var rows: [(String, String)] = []
        if let t = displayed.earlyCheckinToleranceMinutes, t > 0 { rows.append(("Tolérance gratuite", duration(t))) }
        if let p = displayed.earlyCheckinPricePerHour,     p > 0 { rows.append(("Tarif", "\(Formatters.amount(p)) / h")) }
        if let m = displayed.earlyCheckinMaxMinutes,        m > 0 { rows.append(("Maximum", duration(m))) }
        return rows
    }

    private var welcomeBasketCard: some View {
        ListCard {
            VStack(spacing: 0) {
                let hasDesc = !(displayed.welcomeBasketDescription ?? "").isEmpty
                let hasPrice = (displayed.welcomeBasketPrice ?? 0) > 0
                fieldHeader(icon: "gift", label: "Panier de bienvenue",
                            showSeparator: hasPrice || hasDesc)
                if let price = displayed.welcomeBasketPrice, price > 0 {
                    CardRow(showSeparator: hasDesc) {
                        HStack {
                            Text("Prix").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                            Spacer()
                            Text(Formatters.amount(price)).font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                        }
                    }
                }
                if let desc = displayed.welcomeBasketDescription, !desc.isEmpty {
                    CardRow(showSeparator: false) {
                        Text(desc).font(.system(size: 15)).lineSpacing(8)
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
                Text("Aucune prestation payante configurée.")
                    .font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Cartes édition

    private var lcoEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "moon.zzz", label: "Check-out tardif", showSeparator: true)
                CardRow(showSeparator: draft.lcoEnabled) {
                    Toggle("Activé", isOn: $draft.lcoEnabled)
                        .font(.system(size: 15)).foregroundStyle(Color.bhEncre).tint(Color.bhVert)
                }
                if draft.lcoEnabled {
                    minuteRow(label: "Tolérance gratuite", text: $draft.lcoTolerance, showSep: true)
                    euroRow(label: "Tarif / heure",        text: $draft.lcoPrice,     showSep: true)
                    minuteRow(label: "Durée max",          text: $draft.lcoMax,       showSep: false)
                }
            }
        }
    }

    private var eciEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "sun.horizon.fill", label: "Check-in anticipé", showSeparator: true)
                CardRow(showSeparator: draft.eciEnabled) {
                    Toggle("Activé", isOn: $draft.eciEnabled)
                        .font(.system(size: 15)).foregroundStyle(Color.bhEncre).tint(Color.bhVert)
                }
                if draft.eciEnabled {
                    minuteRow(label: "Tolérance gratuite", text: $draft.eciTolerance, showSep: true)
                    euroRow(label: "Tarif / heure",        text: $draft.eciPrice,     showSep: true)
                    minuteRow(label: "Durée max",          text: $draft.eciMax,       showSep: false)
                }
            }
        }
    }

    private var basketEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "gift", label: "Panier de bienvenue", showSeparator: true)
                CardRow(showSeparator: draft.basketEnabled) {
                    Toggle("Activé", isOn: $draft.basketEnabled)
                        .font(.system(size: 15)).foregroundStyle(Color.bhEncre).tint(Color.bhVert)
                }
                if draft.basketEnabled {
                    euroRow(label: "Prix", text: $draft.basketPrice, showSep: true)
                    CardRow(showSeparator: false) {
                        TextField("Description du panier", text: $draft.basketDescription,
                                  axis: .vertical)
                            .font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                            .lineLimit(2...6).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: - Row helpers

    private func euroRow(label: String, text: Binding<String>, showSep: Bool) -> some View {
        CardRow(showSeparator: showSep) {
            HStack {
                Text(label).font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                Spacer()
                TextField("—", text: text)
                    .font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                    .multilineTextAlignment(.trailing).keyboardType(.decimalPad).frame(width: 80)
                Text("€").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
            }
        }
    }

    private func minuteRow(label: String, text: Binding<String>, showSep: Bool) -> some View {
        CardRow(showSeparator: showSep) {
            HStack {
                Text(label).font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                Spacer()
                TextField("—", text: text)
                    .font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                    .multilineTextAlignment(.trailing).keyboardType(.numberPad).frame(width: 60)
                Text("min").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
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

    private func duration(_ minutes: Int) -> String {
        guard minutes > 0 else { return "—" }
        let h = minutes / 60; let m = minutes % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    // MARK: - Sauvegarde

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let body = UpsellBody(
            lateCheckoutEnabled:          draft.lcoEnabled,
            lateCheckoutToleranceMinutes: Int(draft.lcoTolerance),
            lateCheckoutPricePerHour:     Double(draft.lcoPrice),
            lateCheckoutMaxMinutes:       Int(draft.lcoMax),
            earlyCheckinEnabled:          draft.eciEnabled,
            earlyCheckinToleranceMinutes: Int(draft.eciTolerance),
            earlyCheckinPricePerHour:     Double(draft.eciPrice),
            earlyCheckinMaxMinutes:       Int(draft.eciMax),
            welcomeBasketEnabled:         draft.basketEnabled,
            welcomeBasketPrice:           Double(draft.basketPrice),
            welcomeBasketDescription:     draft.basketDescription.isEmpty ? nil : draft.basketDescription
        )

        do {
            try await APIClient.shared.putVoid(
                Endpoint.propertyUpsell(displayed.id),
                body: body,
                agencyAll: true
            )
            await reloadAndUpdate()
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

    private func reloadAndUpdate() async {
        guard let resp: PropertiesResponse = try? await APIClient.shared.get(
            Endpoint.properties, agencyAll: true
        ), let updated = (resp.properties ?? []).first(where: { $0.id == displayed.id }) else { return }
        displayed = updated
        onUpdate(updated)
    }
}
