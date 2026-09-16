import SwiftUI

// MARK: - Helpers

private func dateFromHHMM(_ s: String?) -> Date {
    let parts = (s ?? "").split(separator: ":").compactMap { Int($0) }
    var dc = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    if parts.count >= 2 { dc.hour = parts[0]; dc.minute = parts[1] }
    else { dc.hour = 15; dc.minute = 0 }
    return Calendar.current.date(from: dc) ?? Date()
}

private func hhmmFromDate(_ date: Date) -> String {
    let c = Calendar.current.dateComponents([.hour, .minute], from: date)
    return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
}

// MARK: - Draft

private struct SejourDraft {
    var arrivalEnabled: Bool
    var arrivalDate: Date
    var departureEnabled: Bool
    var departureDate: Date
    var maxGuests: String
    var minNights: String
    var arrivalMessage: String

    init(from p: Property) {
        let aTime = p.arrivalTime.flatMap { $0.isEmpty ? nil : $0 }
        let dTime = p.departureTime.flatMap { $0.isEmpty ? nil : $0 }
        arrivalEnabled   = aTime != nil
        arrivalDate      = dateFromHHMM(aTime ?? "15:00")
        departureEnabled = dTime != nil
        departureDate    = dateFromHHMM(dTime ?? "11:00")
        maxGuests        = p.maxGuests.map { String($0) } ?? ""
        minNights        = p.minNights.map { String($0) } ?? ""
        arrivalMessage   = p.arrivalMessage ?? ""
    }
}

// MARK: - Bloc "Séjour"

struct SejourBlockView: View {
    @Environment(\.dismiss) private var dismiss

    private let onUpdate: (Property) -> Void

    @State private var displayed: Property
    @State private var draft: SejourDraft
    @State private var isEditing = false
    @State private var isSaving  = false
    @State private var saveError: String?

    init(property: Property, onUpdate: @escaping (Property) -> Void = { _ in }) {
        self.onUpdate = onUpdate
        self._displayed = State(initialValue: property)
        self._draft = State(initialValue: SejourDraft(from: property))
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if isEditing {
                            horairesEditCard
                            capaciteEditCard
                            messageEditCard
                        } else {
                            horairesCard
                            if hasCapaciteData { capaciteCard }
                            if let n = displayed.minNights, n > 0 {
                                simpleCard(icon: "calendar", label: "Durée min",
                                           value: "\(n) nuit\(n == 1 ? "" : "s") minimum")
                            }
                            if let msg = displayed.arrivalMessage, !msg.isEmpty {
                                fieldCard(icon: "envelope.open", label: "Message d'arrivée", value: msg)
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
        .numericKeyboardBar()
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
                    .font(.bhSurTitre)
                    .foregroundStyle(Color.bhAttenue)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("Séjour")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
            }
            .padding(.horizontal, 96)
            HStack {
                if isEditing {
                    Button {
                        draft = SejourDraft(from: displayed)
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
                    Button { Task { await save() } } label: {
                        if isSaving {
                            ProgressView().tint(Color.bhVert)
                                .frame(width: 24, height: 24)
                                .padding(.horizontal, 18).padding(.vertical, 7)
                        } else {
                            Text("Enregistrer")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.bhVert)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .glassEffect(in: .rect(cornerRadius: 12))
                                .specularEdge(cornerRadius: 12)
                        }
                    }
                    .buttonStyle(.plain).disabled(isSaving)
                } else {
                    Button {
                        draft = SejourDraft(from: displayed)
                        isEditing = true
                    } label: {
                        Text("Modifier")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.bhVert)
                            .padding(.horizontal, 14).padding(.vertical, 7)
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

    private var horairesCard: some View {
        // flatMap filtre les chaînes vides (stockées par le serveur quand on efface l'heure)
        let arrive = Formatters.time(displayed.arrivalTime).flatMap { $0.isEmpty ? nil : $0 }
        let depart = Formatters.time(displayed.departureTime).flatMap { $0.isEmpty ? nil : $0 }
        return ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "clock", label: "Horaires", showSeparator: true)
                if let a = arrive {
                    CardRow(showSeparator: depart != nil) {
                        HStack {
                            Text("Arrivée").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                            Spacer()
                            Text("à partir de \(a)").font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                        }
                    }
                }
                if let d = depart {
                    CardRow(showSeparator: false) {
                        HStack {
                            Text("Départ").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                            Spacer()
                            Text("avant \(d)").font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                        }
                    }
                }
                if arrive == nil && depart == nil {
                    CardRow(showSeparator: false) {
                        Text("—").font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                    }
                }
            }
        }
    }

    private var hasCapaciteData: Bool {
        displayed.maxGuests != nil || displayed.bedrooms != nil
            || displayed.beds != nil || displayed.bathrooms != nil
    }

    private var capaciteCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "person.2", label: "Capacité", showSeparator: true)
                if let n = displayed.maxGuests {
                    CardRow(showSeparator: hasLogementDetail) {
                        Text("\(n) personne\(n == 1 ? "" : "s") maximum")
                            .font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if hasLogementDetail {
                    fieldHeader(icon: "bed.double", label: "Logement", showSeparator: true)
                    CardRow(showSeparator: false) {
                        Text(logementDetail)
                            .font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var hasLogementDetail: Bool {
        displayed.bedrooms != nil || displayed.beds != nil || displayed.bathrooms != nil
    }

    private var logementDetail: String {
        var parts: [String] = []
        if let b = displayed.bedrooms  { parts.append("\(b) chambre\(b == 1 ? "" : "s")") }
        if let b = displayed.beds      { parts.append("\(b) lit\(b == 1 ? "" : "s")") }
        if let b = displayed.bathrooms { parts.append("\(b) salle\(b == 1 ? "" : "s") de bain") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Cartes édition

    private var horairesEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "clock", label: "Horaires", showSeparator: true)
                CardRow(showSeparator: draft.arrivalEnabled) {
                    Toggle("Arrivée", isOn: $draft.arrivalEnabled)
                        .font(.system(size: 15)).foregroundStyle(Color.bhEncre).tint(Color.bhVert)
                }
                if draft.arrivalEnabled {
                    CardRow(showSeparator: true) {
                        HStack {
                            Text("à partir de")
                                .font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                            Spacer()
                            DatePicker("", selection: $draft.arrivalDate,
                                       displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "fr_FR"))
                        }
                    }
                }
                CardRow(showSeparator: draft.departureEnabled) {
                    Toggle("Départ", isOn: $draft.departureEnabled)
                        .font(.system(size: 15)).foregroundStyle(Color.bhEncre).tint(Color.bhVert)
                }
                if draft.departureEnabled {
                    CardRow(showSeparator: false) {
                        HStack {
                            Text("avant")
                                .font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                            Spacer()
                            DatePicker("", selection: $draft.departureDate,
                                       displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "fr_FR"))
                        }
                    }
                }
            }
        }
    }

    private var capaciteEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "person.2", label: "Capacité & logement", showSeparator: true)
                intRow(label: "Voyageurs max",    text: $draft.maxGuests, showSep: true)
                intRow(label: "Durée min (nuits)", text: $draft.minNights, showSep: false)
            }
        }
    }

    private var messageEditCard: some View {
        ListCard {
            VStack(spacing: 0) {
                fieldHeader(icon: "envelope.open", label: "Message d'arrivée", showSeparator: true)
                CardRow(showSeparator: false) {
                    TextField("Message envoyé automatiquement à l'arrivée",
                              text: $draft.arrivalMessage, axis: .vertical)
                        .font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                        .lineLimit(3...10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Helpers

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

    private func intRow(label: String, text: Binding<String>, showSep: Bool) -> some View {
        CardRow(showSeparator: showSep) {
            HStack {
                Text(label).font(.system(size: 15)).foregroundStyle(Color.bhAttenue)
                Spacer()
                TextField("—", text: text)
                    .font(.system(size: 15)).foregroundStyle(Color.bhEncre)
                    .multilineTextAlignment(.trailing).keyboardType(.numberPad).frame(width: 60)
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

        var fields: [(String, String)] = [
            ("internalName",   displayed.internalName ?? ""),
            ("ownerId",        displayed.ownerId      ?? ""),
            ("photoUrl",       displayed.photoUrl     ?? ""),
            ("arrivalMessage", draft.arrivalMessage),
            ("arrivalTime",    draft.arrivalEnabled  ? hhmmFromDate(draft.arrivalDate)   : ""),
            ("departureTime",  draft.departureEnabled ? hhmmFromDate(draft.departureDate) : ""),
        ]
        if !draft.maxGuests.isEmpty { fields.append(("maxGuests", draft.maxGuests)) }
        if !draft.minNights.isEmpty { fields.append(("minNights", draft.minNights)) }

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
