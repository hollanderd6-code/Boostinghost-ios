import SwiftUI

// MARK: - Draft

private func numStr(_ d: Double?) -> String {
    guard let d else { return "" }
    return d.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(d)) : String(d)
}

private struct ArgentDraft {
    var basePrice: String
    var weekendPrice: String
    var cleaningFee: String
    var touristTax: String
    var depositAmount: String
    var depositReleaseDays: String
    var conciergePct: String
    var airbnbCommissionPct: String
    var bookingCommissionPct: String

    init(from p: Property) {
        basePrice            = numStr(p.basePrice)
        weekendPrice         = numStr(p.weekendPrice)
        cleaningFee          = numStr(p.cleaningFee)
        touristTax           = numStr(p.touristTax)
        depositAmount        = numStr(p.depositAmount)
        depositReleaseDays   = p.depositReleaseDays.map { String($0) } ?? ""
        conciergePct         = numStr(p.conciergePct)
        airbnbCommissionPct  = numStr(p.airbnbCommissionPct)
        bookingCommissionPct = numStr(p.bookingCommissionPct)
    }
}

// MARK: - Focus state

private enum ArgentField: Int, CaseIterable {
    case basePrice, weekendPrice, cleaningFee, touristTax,
         depositAmount, depositReleaseDays,
         conciergePct, airbnbPct, bookingPct
}

// MARK: - Bloc "Argent"

struct ArgentBlockView: View {
    @Environment(\.dismiss) private var dismiss

    private let onUpdate: (Property) -> Void

    @State private var displayed: Property
    @State private var draft: ArgentDraft
    @State private var isEditing = false
    @State private var isSaving  = false
    @State private var saveError: String?

    @FocusState private var focusedField: ArgentField?

    init(property: Property, onUpdate: @escaping (Property) -> Void = { _ in }) {
        self.onUpdate = onUpdate
        self._displayed = State(initialValue: property)
        self._draft = State(initialValue: ArgentDraft(from: property))
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if isEditing {
                            prixEditCard
                            menageEditCard
                            taxeEditCard
                            cautionEditCard
                            commissionsEditCard
                            editNote
                        } else {
                            prixCard
                            if let fee = displayed.cleaningFee, fee > 0 {
                                simpleCard(icon: "sparkles", label: "Frais de ménage",
                                           value: Formatters.amount(fee))
                            }
                            if let tax = displayed.touristTax, tax > 0 {
                                simpleCard(icon: "building.2", label: "Taxe de séjour",
                                           value: "\(Formatters.amount(tax)) / nuit / pers.")
                            }
                            if hasCautionData { cautionCard }
                            if hasCommissionsData { commissionsCard }
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button {
                    if let i = focusedFieldIndex, i > 0 {
                        focusedField = ArgentField.allCases[i - 1]
                    }
                } label: { Image(systemName: "chevron.up") }
                .disabled(focusedFieldIndex.map { $0 == 0 } ?? true)

                Button {
                    if let i = focusedFieldIndex, i < ArgentField.allCases.count - 1 {
                        focusedField = ArgentField.allCases[i + 1]
                    }
                } label: { Image(systemName: "chevron.down") }
                .disabled(focusedFieldIndex.map { $0 == ArgentField.allCases.count - 1 } ?? true)

                Spacer()

                Button("OK") { focusedField = nil }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)
        ) { notif in
            guard let tf = notif.object as? UITextField,
                  tf.keyboardType == .decimalPad || tf.keyboardType == .numberPad
            else { return }
            DispatchQueue.main.async { tf.selectAll(nil) }
        }
        .alert("Erreur", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private var focusedFieldIndex: Int? {
        guard let f = focusedField else { return nil }
        return ArgentField.allCases.firstIndex(of: f)
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
                Text("Argent")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
            }
            .padding(.horizontal, 96)

            HStack {
                if isEditing {
                    Button {
                        draft = ArgentDraft(from: displayed)
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
                        draft = ArgentDraft(from: displayed)
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

    private var prixCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "eurosign.circle", label: "Prix", showSeparator: true)
                if let base = displayed.basePrice, base > 0 {
                    let hasWkd = (displayed.weekendPrice ?? 0) > 0
                    CardRow(showSeparator: hasWkd) {
                        prixRow(label: "Semaine", value: "\(Formatters.amount(base)) / nuit")
                    }
                    if let wkd = displayed.weekendPrice, wkd > 0 {
                        CardRow(showSeparator: false) {
                            prixRow(label: "Week-end", value: "\(Formatters.amount(wkd)) / nuit")
                        }
                    }
                } else {
                    CardRow(showSeparator: false) {
                        Text("—").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                    }
                }
            }
        }
    }

    private func prixRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
            Spacer()
            Text(value).font(.system(size: 15)).foregroundStyle(Color.bhEncre)
        }
    }

    private var hasCautionData: Bool { (displayed.depositAmount ?? 0) > 0 }

    private var cautionCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "lock.shield", label: "Caution", showSeparator: true)
                if let amt = displayed.depositAmount, amt > 0 {
                    CardRow(showSeparator: displayed.depositReleaseDays != nil) {
                        prixRow(label: "Montant", value: Formatters.amount(amt))
                    }
                }
                if let days = displayed.depositReleaseDays {
                    CardRow(showSeparator: false) {
                        prixRow(label: "Libération", value: "\(days) jour\(days == 1 ? "" : "s")")
                    }
                }
            }
        }
    }

    private var hasCommissionsData: Bool {
        displayed.conciergePct != nil || displayed.airbnbCommissionPct != nil || displayed.bookingCommissionPct != nil
    }

    private var commissionsCard: some View {
        ListCard {
            VStack(spacing: 0) {
                let rows = commissionRows
                fieldHeader(icon: "percent", label: "Commissions", showSeparator: !rows.isEmpty)
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    CardRow(showSeparator: idx < rows.count - 1) {
                        prixRow(label: row.label, value: row.value)
                    }
                }
            }
        }
    }

    private struct CommRow { let label: String; let value: String }

    private var commissionRows: [CommRow] {
        var rows: [CommRow] = []
        if let p = displayed.conciergePct,        p > 0 { rows.append(.init(label: "Conciergerie", value: pct(p))) }
        if let p = displayed.airbnbCommissionPct,  p > 0 { rows.append(.init(label: "Airbnb",       value: pct(p))) }
        if let p = displayed.bookingCommissionPct, p > 0 { rows.append(.init(label: "Booking.com",  value: pct(p))) }
        return rows
    }

    private func pct(_ v: Double) -> String { "\(Int(v)) %" }

    private func simpleCard(icon: String, label: String, value: String) -> some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: icon, label: label, showSeparator: true)
                CardRow(showSeparator: false) {
                    Text(value).font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Cartes édition

    private var prixEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "eurosign.circle", label: "Prix", showSeparator: true)
                euroRow(label: "Semaine (nuit)",  text: $draft.basePrice,   showSep: true,  focus: .basePrice)
                euroRow(label: "Week-end (nuit)", text: $draft.weekendPrice, showSep: false, focus: .weekendPrice)
            }
        }
    }

    private var menageEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "sparkles", label: "Frais de ménage", showSeparator: true)
                euroRow(label: "Montant forfaitaire", text: $draft.cleaningFee, showSep: false, focus: .cleaningFee)
            }
        }
    }

    private var taxeEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "building.2", label: "Taxe de séjour", showSeparator: true)
                euroRow(label: "Par nuit / personne", text: $draft.touristTax, showSep: false, focus: .touristTax)
            }
        }
    }

    private var cautionEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "lock.shield", label: "Caution", showSeparator: true)
                euroRow(label: "Montant",            text: $draft.depositAmount,     showSep: true,  focus: .depositAmount)
                intRow(label: "Libération (jours)",  text: $draft.depositReleaseDays, showSep: false, focus: .depositReleaseDays)
            }
        }
    }

    private var commissionsEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "percent", label: "Commissions", showSeparator: true)
                pctRow(label: "Conciergerie", text: $draft.conciergePct,         showSep: true,  focus: .conciergePct)
                pctRow(label: "Airbnb",       text: $draft.airbnbCommissionPct,  showSep: true,  focus: .airbnbPct)
                pctRow(label: "Booking.com",  text: $draft.bookingCommissionPct, showSep: false, focus: .bookingPct)
            }
        }
    }

    private var editNote: some View {
        Text("Saisir 0 efface un montant.\nUn champ vide conserve la valeur actuelle.")
            .font(.system(size: 12.5))
            .foregroundStyle(Color.bhAttenue)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
    }

    // MARK: - Row helpers

    private func euroRow(label: String, text: Binding<String>, showSep: Bool, focus: ArgentField) -> some View {
        CardRow(showSeparator: showSep) {
            HStack {
                Text(label).font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                Spacer()
                TextField("—", text: text)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.bhEncre)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: focus)
                    .frame(width: 80)
                Text("€").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
            }
        }
    }

    private func pctRow(label: String, text: Binding<String>, showSep: Bool, focus: ArgentField) -> some View {
        CardRow(showSeparator: showSep) {
            HStack {
                Text(label).font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                Spacer()
                TextField("—", text: text)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.bhEncre)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: focus)
                    .frame(width: 60)
                Text("%").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
            }
        }
    }

    private func intRow(label: String, text: Binding<String>, showSep: Bool, focus: ArgentField) -> some View {
        CardRow(showSeparator: showSep) {
            HStack {
                Text(label).font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                Spacer()
                TextField("—", text: text)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.bhEncre)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: focus)
                    .frame(width: 60)
            }
        }
    }

    // MARK: - Helpers

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

    // MARK: - Sauvegarde

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        var fields: [(String, String)] = [
            ("internalName", displayed.internalName ?? ""),
            ("ownerId",      displayed.ownerId      ?? ""),
            ("photoUrl",     displayed.photoUrl     ?? ""),
        ]

        let numericFields: [(String, String)] = [
            ("basePrice",            draft.basePrice),
            ("weekendPrice",         draft.weekendPrice),
            ("cleaningFee",          draft.cleaningFee),
            ("touristTaxPerNight",   draft.touristTax),
            ("depositAmount",        draft.depositAmount),
            ("depositReleaseDays",   draft.depositReleaseDays),
            ("conciergePct",         draft.conciergePct),
            ("airbnbCommissionPct",  draft.airbnbCommissionPct),
            ("bookingCommissionPct", draft.bookingCommissionPct),
        ]
        for (key, val) in numericFields where !val.isEmpty {
            fields.append((key, val))
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
