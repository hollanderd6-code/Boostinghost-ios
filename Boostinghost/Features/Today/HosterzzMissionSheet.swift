import SwiftUI

struct HosterzzMissionSheet: View {
    let reservationId: String
    let propertyName:  String
    let guestName:     String
    let departureDate: String?
    let onSuccess: (String?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var enableHeure    = false
    @State private var heure          = Date()
    @State private var taskType       = "menage_approfondi"
    @State private var description    = ""
    @State private var isLoading      = false
    @State private var alertMessage:  String?
    @State private var alertIsPending  = false
    @State private var alertIsNotLinked = false
    @State private var showLinkSheet  = false

    private let taskTypes: [(value: String, label: String)] = [
        ("menage_standard",   "Ménage standard"),
        ("menage_approfondi", "Ménage de départ"),
        ("blanchisserie",     "Blanchisserie à domicile"),
        ("check_in",          "Entrée des voyageurs (check-in)"),
        ("check_out",         "Sortie des voyageurs (check-out)"),
        ("conciergerie",      "Conciergerie"),
    ]

    private var taskTypeLabel: String {
        taskTypes.first(where: { $0.value == taskType })?.label ?? ""
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        contextCard
                        formCard
                        PrimaryButton(title: isLoading ? "Création…" : "Créer la mission") {
                            Task { await submit() }
                        }
                        .disabled(isLoading)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Hosterzz", isPresented: Binding(
            get:  { alertMessage != nil },
            set:  { if !$0 { clearAlert() } }
        )) {
            if alertIsNotLinked {
                Button("Lier mon compte") {
                    clearAlert()
                    showLinkSheet = true
                }
                Button("Annuler", role: .cancel) { clearAlert() }
            } else {
                Button("OK") { clearAlert() }
            }
        } message: {
            Text(alertMessage ?? "")
        }
        .sheet(isPresented: $showLinkSheet) {
            HosterzzLinkSheet {
                Task { await submit() }
            }
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        VStack(spacing: 0) {
            SheetHandle()
            HStack(alignment: .bottom, spacing: 0) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                        .frame(width: 38, height: 38)
                        .glassEffect(in: .circle)
                        .specularEdge(cornerRadius: 19)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Image("hosterzz-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        Text("Hosterzz")
                            .font(.bhSurTitre)
                            .foregroundStyle(Color.bhAttenue)
                            .lineLimit(1)
                    }
                    Text("Nouvelle mission")
                        .bhGrandTitre()
                }
                .padding(.leading, 12)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Context (read-only)

    private var contextCard: some View {
        ListCard {
            CardRow(showSeparator: false) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(propertyName)
                        .font(.bhTitreLigne)
                        .foregroundStyle(Color.bhEncre)
                    if let dep = departureDate {
                        Text("départ le \(Formatters.day(dep))")
                            .font(.bhCorps)
                            .foregroundStyle(Color.bhAttenue)
                    }
                    Text(guestName)
                        .font(.bhCorps)
                        .foregroundStyle(Color.bhAttenue)
                }
            }
        }
    }

    // MARK: - Form

    private var formCard: some View {
        ListCard {
            VStack(spacing: 0) {
                // TYPE DE PRESTATION — même structure que menuRow dans MandatCreationView
                // pour que le libellé long puisse passer sur deux lignes sans déborder.
                CardRow(showSeparator: true) {
                    Menu {
                        ForEach(taskTypes, id: \.value) { t in
                            Button {
                                taskType = t.value
                            } label: {
                                if taskType == t.value {
                                    Label(t.label, systemImage: "checkmark")
                                } else {
                                    Text(t.label)
                                }
                            }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Text("TYPE DE PRESTATION").bhIntertitre()
                            Spacer(minLength: 8)
                            HStack(alignment: .top, spacing: 4) {
                                Text(taskTypeLabel)
                                    .font(.bhCorps)
                                    .foregroundStyle(Color.bhAttenue)
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: false, vertical: true)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.bhAttenue.opacity(0.6))
                            }
                        }
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                CardRow(showSeparator: true) {
                    Toggle(isOn: $enableHeure.animation()) {
                        Text("Heure de mission")
                            .font(.bhTitreLigne)
                            .foregroundStyle(Color.bhEncre)
                    }
                    .tint(Color.bhVert)
                }

                if enableHeure {
                    CardRow(showSeparator: true) {
                        HStack {
                            Text("Heure")
                                .font(.bhTitreLigne)
                                .foregroundStyle(Color.bhEncre)
                            Spacer()
                            DatePicker("", selection: $heure, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(Color.bhVert)
                        }
                    }
                }

                CardRow(showSeparator: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DESCRIPTION").bhIntertitre()
                        TextField("Optionnel", text: $description, axis: .vertical)
                            .font(.bhCorps)
                            .foregroundStyle(Color.bhEncre)
                            .lineLimit(3...6)
                    }
                }
            }
        }
    }

    // MARK: - Submit

    private func heureString() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: heure)
    }

    private func submit() async {
        isLoading = true
        defer { isLoading = false }

        let body = HosterzzMissionBody(
            reservationId: reservationId,
            heure:        enableHeure ? heureString() : nil,
            taskType:     taskType,
            description:  description.isEmpty ? nil : description
        )

        do {
            let response: HosterzzMissionResponse = try await APIClient.shared.post(
                Endpoint.hosterzzMissions, body: body
            )

            if response.pending == true {
                // 202: mission created in background — treat as deferred success.
                alertMessage  = "La mission est en cours de création par Hosterzz et sera disponible dans quelques instants."
                alertIsPending = true
            } else {
                // 200 ok == true, or already == true (dedup) — both are success.
                onSuccess(response.statut)
                dismiss()
            }
        } catch APIError.server(let statusCode, _) where statusCode == 409 {
            alertMessage    = "Votre compte n'est pas encore lié à Hosterzz."
            alertIsNotLinked = true
        } catch {
            alertMessage = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }

    private func clearAlert() {
        if alertIsPending {
            onSuccess(nil)
            dismiss()
        }
        alertMessage     = nil
        alertIsPending   = false
        alertIsNotLinked = false
    }
}

// MARK: - Feuille de liaison Hosterzz

private struct HosterzzLinkSheet: View {
    let onLinked: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var code         = ""
    @State private var isLoading    = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        codeCard
                        PrimaryButton(title: isLoading ? "Liaison…" : "Valider") {
                            Task { await link() }
                        }
                        .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var navBar: some View {
        VStack(spacing: 0) {
            SheetHandle()
            HStack(alignment: .bottom, spacing: 0) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                        .frame(width: 38, height: 38)
                        .glassEffect(in: .circle)
                        .specularEdge(cornerRadius: 19)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Image("hosterzz-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        Text("Hosterzz")
                            .font(.bhSurTitre)
                            .foregroundStyle(Color.bhAttenue)
                            .lineLimit(1)
                    }
                    Text("Lier mon compte")
                        .bhGrandTitre()
                }
                .padding(.leading, 12)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    private var codeCard: some View {
        ListCard {
            VStack(spacing: 0) {
                CardRow(showSeparator: errorMessage != nil) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CODE DE LIAISON").bhIntertitre()
                        TextField("XXXXXXXX", text: $code)
                            .font(.bhTitreLigne)
                            .foregroundStyle(Color.bhEncre)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Text("Retrouvez ce code dans votre espace Hosterzz.")
                            .font(.bhCorps)
                            .foregroundStyle(Color.bhAttenue)
                    }
                }
                if let err = errorMessage {
                    CardRow(showSeparator: false) {
                        Text(err)
                            .font(.bhCorps)
                            .foregroundStyle(Color.bhTerracotta)
                    }
                }
            }
        }
    }

    private func link() async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }

        let body = HosterzzLinkBody(code: code.trimmingCharacters(in: .whitespaces))
        do {
            let _: HosterzzLinkResponse = try await APIClient.shared.post(
                Endpoint.hosterzzLink, body: body
            )
            dismiss()
            onLinked()
        } catch {
            errorMessage = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }
}
