import SwiftUI

// MARK: - Draft

private struct PlateformesDraft {
    var icalUrls: [String]
    var externalPricing: Bool
    var markups: [String: String]   // code → pourcentage (String vide = pas de majoration)

    init(from property: Property, markupsResponse: PropertyMarkupsResponse?) {
        icalUrls = Self.decodeIcal(property.icalUrlsRaw)
        externalPricing = property.externalPricing ?? false
        var m: [String: String] = [:]
        if let resp = markupsResponse {
            for code in resp.codes.keys {
                if let pct = resp.markups[code] {
                    m[code] = formatPct(pct)
                } else {
                    m[code] = ""
                }
            }
        }
        markups = m
    }

    static func decodeIcal(_ raw: String?) -> [String] {
        guard let raw, !raw.isEmpty, raw != "[]",
              let data = raw.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return arr
    }

    func icalJSON() -> String {
        let filtered = icalUrls.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard let data = try? JSONSerialization.data(withJSONObject: filtered),
              let str  = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }
}

private func formatPct(_ value: Double) -> String {
    value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
}

// MARK: - Markup PATCH body

private struct MarkupBody: Encodable {
    let code: String
    let pct: Double
}

// MARK: - Bloc "Plateformes & prix"

struct PlateformesBlockView: View {
    @Environment(\.dismiss) private var dismiss

    private let onUpdate: (Property) -> Void

    @State private var displayed: Property
    @State private var draft: PlateformesDraft

    @State private var markupsResponse: PropertyMarkupsResponse?
    @State private var markupsLoading = false
    @State private var markupsLoaded  = false

    @State private var isEditing = false
    @State private var isSaving  = false
    @State private var saveError: String?

    init(property: Property, onUpdate: @escaping (Property) -> Void = { _ in }) {
        self.onUpdate = onUpdate
        self._displayed = State(initialValue: property)
        self._draft = State(initialValue: PlateformesDraft(from: property, markupsResponse: nil))
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        canalCard
                        if isEditing {
                            icalEditCard
                            pricingEditCard
                            if markupsLoaded, markupsResponse != nil { majorationsEditCard }
                        } else {
                            icalCard
                            if displayed.externalPricing != nil { pricingCard }
                            majorationsCard
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
        .task { await loadMarkups() }
        .numericKeyboardBar()
        .alert("Erreur", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: { Text(saveError ?? "") }
    }

    // MARK: - Chargement des majorations

    private func loadMarkups() async {
        guard !markupsLoaded else { return }
        markupsLoading = true
        markupsResponse = try? await APIClient.shared.get(Endpoint.propertyMarkups(displayed.id))
        markupsLoading = false
        markupsLoaded = true
        // Initialise le draft markups maintenant que la réponse est disponible
        draft = PlateformesDraft(from: displayed, markupsResponse: markupsResponse)
    }

    // MARK: - Nav bar

    private var navBar: some View {
        ZStack {
            VStack(spacing: 1) {
                Text(displayed.internalName ?? displayed.name)
                    .font(.bhSurTitre).foregroundStyle(Color.bhAttenue)
                    .lineLimit(1).truncationMode(.tail)
                Text("Plateformes & prix")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.bhEncre)
            }
            .padding(.horizontal, 96)
            HStack {
                if isEditing {
                    Button {
                        draft = PlateformesDraft(from: displayed, markupsResponse: markupsResponse)
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
                        draft = PlateformesDraft(from: displayed, markupsResponse: markupsResponse)
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

    private var canalCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "antenna.radiowaves.left.and.right",
                            label: "Diffusion", showSeparator: true)
                CardRow(showSeparator: false) {
                    if displayed.channexEnabled == true {
                        Label("Canal actif", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 15)).foregroundStyle(Color.bhOccupe)
                    } else {
                        Text("Non connecté").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                    }
                }
            }
        }
    }

    private var icalCard: some View {
        let urls = PlateformesDraft.decodeIcal(displayed.icalUrlsRaw)
        return ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "calendar", label: "Calendriers iCal",
                            showSeparator: !urls.isEmpty)
                if urls.isEmpty {
                    CardRow(showSeparator: false) {
                        Text("Aucun calendrier iCal importé.")
                            .font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                    }
                } else {
                    ForEach(Array(urls.enumerated()), id: \.offset) { idx, url in
                        CardRow(showSeparator: idx < urls.count - 1) {
                            Text(url).font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(Color.bhAttenue).lineLimit(1).truncationMode(.middle)
                        }
                    }
                }
            }
        }
    }

    private var pricingCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "chart.line.uptrend.xyaxis",
                            label: "Outil de pricing externe", showSeparator: true)
                CardRow(showSeparator: false) {
                    if displayed.externalPricing == true {
                        Label("Activé", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 15)).foregroundStyle(Color.bhOccupe)
                    } else {
                        Text("Inactif").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                    }
                }
            }
        }
    }

    private var majorationsCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "percent", label: "Majorations",
                            showSeparator: markupsLoading || markupsLoaded)
                if markupsLoading {
                    CardRow(showSeparator: false) {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text("Chargement…").font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
                        }
                    }
                } else if let resp = markupsResponse {
                    let sorted = resp.codes.sorted { $0.value < $1.value }
                    if sorted.isEmpty {
                        CardRow(showSeparator: false) {
                            Text("Aucune plateforme configurée.")
                                .font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        ForEach(Array(sorted.enumerated()), id: \.element.key) { idx, pair in
                            CardRow(showSeparator: idx < sorted.count - 1) {
                                HStack {
                                    Text(pair.value).font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                                    Spacer()
                                    if let pct = resp.markups[pair.key] {
                                        Text(displayPct(pct)).font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(Color.bhEncre)
                                    } else {
                                        Text("aucune majoration").font(.system(size: 14.5))
                                            .foregroundStyle(Color.bhAttenue)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    CardRow(showSeparator: false) {
                        Text("Impossible de charger les majorations.")
                            .font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: - Cartes édition

    private var icalEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "calendar", label: "Calendriers iCal",
                            showSeparator: !draft.icalUrls.isEmpty)
                ForEach(draft.icalUrls.indices, id: \.self) { idx in
                    let isLast = idx == draft.icalUrls.count - 1
                    CardRow(showSeparator: !isLast) {
                        HStack(spacing: 8) {
                            TextField("https://…", text: $draft.icalUrls[idx])
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(Color.bhEncre)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            Button {
                                draft.icalUrls.remove(at: idx)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 17)).foregroundStyle(Color.bhTerracotta)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                CardRow(showSeparator: false) {
                    Button { draft.icalUrls.append("") } label: {
                        Label("Ajouter une URL iCal", systemImage: "plus.circle.fill")
                            .font(.system(size: 14.5)).foregroundStyle(Color.bhVert)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var pricingEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "chart.line.uptrend.xyaxis",
                            label: "Outil de pricing externe", showSeparator: true)
                CardRow(showSeparator: false) {
                    Toggle("Activé", isOn: $draft.externalPricing)
                        .font(.system(size: 15)).foregroundStyle(Color.bhEncre).tint(Color.bhVert)
                }
            }
        }
    }

    private var majorationsEditCard: some View {
        guard let resp = markupsResponse else { return AnyView(EmptyView()) }
        let sorted = resp.codes.sorted { $0.value < $1.value }
        return AnyView(ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "percent", label: "Majorations par plateforme",
                            showSeparator: !sorted.isEmpty)
                ForEach(Array(sorted.enumerated()), id: \.element.key) { idx, pair in
                    let code = pair.key
                    CardRow(showSeparator: idx < sorted.count - 1) {
                        HStack {
                            Text(pair.value).font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                            Spacer()
                            TextField("0", text: Binding(
                                get: { draft.markups[code] ?? "" },
                                set: { draft.markups[code] = $0 }
                            ))
                            .font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                            .multilineTextAlignment(.trailing).keyboardType(.decimalPad).frame(width: 60)
                            Text("%").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                        }
                    }
                }
                CardRow(showSeparator: false) {
                    Text("Laisser vide ou saisir 0 pour supprimer la majoration.")
                        .font(.system(size: 12.5)).foregroundStyle(Color.bhAttenue)
                }
            }
        })
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

    private func displayPct(_ value: Double) -> String {
        let n = value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "fr_FR")))
        return "+\(n)\u{202F}%"
    }

    // MARK: - Sauvegarde

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        // 1. PUT des champs principaux
        let fields: [(String, String)] = [
            ("internalName",   displayed.internalName ?? ""),
            ("ownerId",        displayed.ownerId      ?? ""),
            ("photoUrl",       displayed.photoUrl     ?? ""),
            ("icalUrls",       draft.icalJSON()),
            ("externalPricing", draft.externalPricing ? "true" : "false"),
        ]

        do {
            let r: PropertyUpdateResponse = try await APIClient.shared.putMultipart(
                Endpoint.property(displayed.id), fields: fields, agencyAll: true
            )
            displayed = r.property
            onUpdate(r.property)
        } catch let err as APIError {
            switch err {
            case .server(_, let msg):   saveError = msg ?? "Erreur serveur"
            case .network:              saveError = "Erreur réseau"
            case .decoding:             saveError = "Erreur de décodage"
            case .unauthorized:         saveError = "Session expirée"
            case .subscriptionRequired: saveError = "Abonnement requis"
            }
            return
        } catch {
            saveError = error.localizedDescription
            return
        }

        // 2. PATCH des majorations modifiées
        if let resp = markupsResponse {
            for code in resp.codes.keys {
                let draftStr = (draft.markups[code] ?? "").trimmingCharacters(in: .whitespaces)
                let originalPct = resp.markups[code] ?? 0
                let draftPct = Double(draftStr) ?? 0

                let changed = abs(draftPct - originalPct) > 0.001
                    || (draftStr.isEmpty && originalPct != 0)
                guard changed else { continue }

                let body = MarkupBody(code: code, pct: draftPct)
                if let updated: MarkupSaveResponse = try? await APIClient.shared.patch(
                    Endpoint.propertyMarkups(displayed.id), body: body, agencyAll: true
                ) {
                    markupsResponse = PropertyMarkupsResponse(
                        markups: updated.markups,
                        codes: resp.codes
                    )
                }
            }
        }

        isEditing = false
    }
}
