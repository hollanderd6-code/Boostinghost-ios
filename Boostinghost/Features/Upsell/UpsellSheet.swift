import SwiftUI

// MARK: - Kind

enum UpsellKind: String, CaseIterable, Identifiable {
    case lateCheckout  = "late_checkout"
    case earlyCheckin  = "early_checkin"
    case welcomeBasket = "welcome_basket"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lateCheckout:  return "Départ tardif"
        case .earlyCheckin:  return "Arrivée anticipée"
        case .welcomeBasket: return "Panier d'accueil"
        }
    }

    var showsTimeField: Bool { self != .welcomeBasket }

    var timeFieldFooter: String {
        self == .lateCheckout
            ? "Heure de départ souhaitée par le voyageur."
            : "Heure d'arrivée souhaitée par le voyageur."
    }
}

// MARK: - Sheet

struct UpsellSheet: View {
    let conversationId: Int

    @Environment(\.dismiss) private var dismiss

    @State private var kind         = UpsellKind.lateCheckout
    @State private var amountText   = ""
    @State private var reqLabel     = ""
    @State private var details      = ""
    @State private var isLoading    = false
    @State private var error: String?
    @State private var result: UpsellResult?
    @State private var showAutoShare = false

    var body: some View {
        NavigationStack {
            Group {
                if let r = result {
                    resultForm(r)
                } else {
                    inputForm
                }
            }
            .navigationTitle(result == nil ? "Prestation payante" : "Lien généré")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if result == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") { dismiss() }
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .overlay {
            if isLoading {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView()
            }
        }
        .alert("Erreur", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    // MARK: - Input

    private var inputForm: some View {
        Form {
            Section {
                Picker("Type", selection: $kind) {
                    ForEach(UpsellKind.allCases) { k in
                        Text(k.label).tag(k)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Type de prestation")
            }

            Section {
                HStack {
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                    Text("€")
                        .foregroundStyle(Color.bhAttenue)
                }
            } header: {
                Text("Montant")
            } footer: {
                Text("Montant total payé par le voyageur.")
            }

            if kind.showsTimeField {
                Section {
                    TextField("ex. 14 h 00", text: $reqLabel)
                } header: {
                    Text("Heure souhaitée (facultatif)")
                } footer: {
                    Text(kind.timeFieldFooter)
                }
            }

            Section("Description (facultatif)") {
                TextField("Détails de la prestation…", text: $details, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section {
                Button {
                    Task { await generate() }
                } label: {
                    Label("Générer le lien", systemImage: "link.badge.plus")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(canGenerate ? Color.bhVert : Color.bhAttenue)
                .disabled(!canGenerate)
            }
        }
        .onChange(of: kind) { _, newKind in
            if !newKind.showsTimeField { reqLabel = "" }
        }
    }

    private var canGenerate: Bool { parsedAmount != nil }

    private var parsedAmount: Double? {
        let t = amountText
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let v = Double(t), v > 0 else { return nil }
        return v
    }

    // MARK: - Result

    @ViewBuilder
    private func resultForm(_ r: UpsellResult) -> some View {
        Form {
            if r.sentChat {
                Section {
                    Label("Lien envoyé dans la conversation.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.bhVert)
                }
                .listRowBackground(Color.bhMentheFond)
            } else if r.sentEmail {
                Section {
                    Label("Lien envoyé par email au voyageur.", systemImage: "envelope.circle.fill")
                        .foregroundStyle(Color.bhVert)
                }
                .listRowBackground(Color.bhMentheFond)
            }

            Section("Lien de paiement") {
                Text(r.url.absoluteString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.bhEncre)
                    .lineLimit(4)
                    .truncationMode(.middle)

                Button {
                    UIPasteboard.general.string = r.url.absoluteString
                } label: {
                    Label("Copier le lien", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(Color.bhVert)

                ShareLink(item: r.url) {
                    Label("Partager…", systemImage: "square.and.arrow.up")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(Color.bhVert)
            }

            if r.feeCents > 0 {
                let fee = Double(r.feeCents) / 100
                let net = r.amountEuros - fee
                Section {
                    HStack {
                        Text("Commission BHGuest (3 %)")
                            .font(.footnote)
                            .foregroundStyle(Color.bhAttenue)
                        Spacer()
                        Text(Formatters.amountDecimal(fee))
                            .font(.footnote)
                            .foregroundStyle(Color.bhAttenue)
                    }
                    HStack {
                        Text("Vous recevrez")
                            .font(.footnote)
                            .foregroundStyle(Color.bhEncre)
                        Spacer()
                        Text(Formatters.amountDecimal(net))
                            .font(.footnote)
                            .foregroundStyle(Color.bhEncre)
                    }
                }
            }

            Section {
                Button { dismiss() } label: {
                    Text(r.sentChat ? "Revenir à la conversation" : "Fermer")
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(Color.bhVert)
            }
        }
        .task(id: r.url.absoluteString) {
            guard !r.sentChat, !r.sentEmail else { return }
            try? await Task.sleep(nanoseconds: 350_000_000)
            showAutoShare = true
        }
        .sheet(isPresented: $showAutoShare) {
            ActivityShareSheet(items: [r.url])
        }
    }

    // MARK: - Network

    private func generate() async {
        guard let amount = parsedAmount else { return }
        isLoading = true
        defer { isLoading = false }

        let body = UpsellRequest(
            kind:           kind.rawValue,
            amountEuros:    amount,
            conversationId: conversationId,
            reqLabel:       nonEmpty(reqLabel),
            details:        nonEmpty(details)
        )
        do {
            let r: UpsellResponse = try await APIClient.shared.post(
                Endpoint.upsellManual, body: body
            )
            guard let urlString = r.url, let url = URL(string: urlString) else {
                error = "Le serveur n'a pas renvoyé de lien valide."
                return
            }
            result = UpsellResult(
                url:         url,
                feeCents:    r.feeCents   ?? 0,
                sentChat:    r.sentChat   == true,
                sentEmail:   r.sentEmail  == true,
                amountEuros: amount
            )
        } catch {
            self.error = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }

    private func nonEmpty(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
    }
}

// MARK: - Private types

private struct UpsellResult {
    let url: URL
    let feeCents: Int
    let sentChat: Bool
    let sentEmail: Bool
    let amountEuros: Double
}

private struct UpsellRequest: Encodable {
    let kind: String
    let amountEuros: Double
    let conversationId: Int?
    let reqLabel: String?
    let details: String?

    enum CodingKeys: String, CodingKey {
        case kind, amountEuros, conversationId, reqLabel
        case details = "description"
    }
}

private struct UpsellResponse: Decodable {
    let success: Bool?
    let url: String?
    let feeCents: Int?
    let attached: Bool?
    let sentChat: Bool?
    let sentEmail: Bool?
}

// MARK: - UIActivityViewController wrapper (auto-share quand rien n'est parti)

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
