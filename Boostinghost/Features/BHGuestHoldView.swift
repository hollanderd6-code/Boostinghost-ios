import SwiftUI

// MARK: - BHGuestHoldView

struct BHGuestHoldView: View {
    let vm:         CalendarViewModel
    let property:   PropertySummary
    let onComplete: () -> Void

    @State private var start:     Date
    @State private var end:       Date
    @State private var priceText  = ""
    @State private var phone      = ""
    @State private var email      = ""

    @State private var result:      HoldResult?
    @State private var isLoading   = false
    @State private var error:      String?
    @State private var linkCopied  = false

    private struct HoldResult {
        let url:     URL
        let smsSent: Bool
    }

    init(vm:           CalendarViewModel,
         property:     PropertySummary,
         start:        Date,
         end:          Date,
         prefillPhone: String? = nil,
         prefillEmail: String? = nil,
         onComplete:   @escaping () -> Void) {
        self.vm         = vm
        self.property   = property
        self.onComplete = onComplete
        _start = State(initialValue: start)
        _end   = State(initialValue: end)
        if let p = prefillPhone, !p.isEmpty { _phone = State(initialValue: p) }
        if let e = prefillEmail, !e.isEmpty { _email = State(initialValue: e) }
    }

    var body: some View {
        Group {
            if let res = result {
                resultForm(res: res)
            } else {
                inputForm
            }
        }
        .navigationTitle("BHGuest")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView().tint(Color.bhTerracotta)
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

    // MARK: - Input form

    private var inputForm: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.bhTerracotta)
                        .frame(width: 28)
                    Text("Envoyez un lien : le voyageur paie en ligne, les dates se bloquent. 3 % seulement — bien moins que les ~15 % des OTA.")
                        .font(.subheadline)
                        .foregroundStyle(Color.bhEncre)
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.bhTerracottaFond)
            }

            Section("Logement") {
                LabeledContent("Logement", value: property.displayName)
            }

            Section("Dates") {
                DatePicker("Arrivée", selection: $start, displayedComponents: .date)
                DatePicker("Départ",  selection: $end,   displayedComponents: .date)
                    .onChange(of: start) { _, new in
                        if end <= new {
                            end = vm.utcCal.date(byAdding: .day, value: 1, to: new) ?? new
                        }
                    }
            }

            Section {
                HStack {
                    TextField("Prix fixé", text: $priceText)
                        .keyboardType(.decimalPad)
                    Text("€").foregroundStyle(Color.bhAttenue)
                }
            } header: {
                Text("Tarif fixé (facultatif)")
            } footer: {
                Text("Si renseigné, le voyageur ne peut pas modifier le montant.")
            }

            Section("Voyageur (facultatif)") {
                HStack {
                    Image(systemName: "phone").foregroundStyle(Color.bhAttenue)
                    TextField("Téléphone", text: $phone)
                        .keyboardType(.phonePad)
                }
                HStack {
                    Image(systemName: "envelope").foregroundStyle(Color.bhAttenue)
                    TextField("E-mail", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
            }

            Section {
                Button {
                    Task { await performHold(sendSms: false) }
                } label: {
                    Label("Générer et partager moi-même", systemImage: "square.and.arrow.up")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(Color.bhTerracotta)
            }

            Section {
                Button {
                    Task { await performHold(sendSms: true) }
                } label: {
                    Label("Envoyer automatiquement par SMS", systemImage: "message")
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(phone.trimmingCharacters(in: .whitespaces).isEmpty ? Color.bhAttenue : Color.bhEncre)
                .disabled(phone.trimmingCharacters(in: .whitespaces).isEmpty)
            } footer: {
                Text("Le serveur envoie le SMS au numéro renseigné ci-dessus.")
            }
        }
    }

    // MARK: - Result form

    @ViewBuilder
    private func resultForm(res: HoldResult) -> some View {
        Form {
            if res.smsSent {
                Section {
                    Label("SMS envoyé au voyageur.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.bhTerracotta)
                        .listRowBackground(Color.bhTerracottaFond)
                }
            }

            Section("Lien de paiement") {
                Text(res.url.absoluteString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.bhEncre)
                    .lineLimit(3)
                    .truncationMode(.middle)

                Button {
                    UIPasteboard.general.string = res.url.absoluteString
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    linkCopied = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        linkCopied = false
                    }
                } label: {
                    Label(
                        linkCopied ? "Lien copié !" : "Copier le lien",
                        systemImage: linkCopied ? "checkmark" : "doc.on.doc"
                    )
                    .frame(maxWidth: .infinity)
                    .animation(.easeInOut(duration: 0.15), value: linkCopied)
                }
                .foregroundStyle(linkCopied ? Color.bhVert.opacity(0.6) : Color.bhVert)

                ShareLink(item: res.url) {
                    Label("Partager…", systemImage: "square.and.arrow.up")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(Color.bhTerracotta)
            }

            Section {
                Label(
                    "Ce lien expire dans 4 h. Les dates sont bloquées entre-temps.",
                    systemImage: "clock"
                )
                .font(.footnote)
                .foregroundStyle(Color.secondary)
                .listRowBackground(Color.clear)
            }

            Section {
                Button {
                    onComplete()
                } label: {
                    Text("Fermer").frame(maxWidth: .infinity)
                }
                .foregroundStyle(Color.bhVert)
            }
        }
    }

    // MARK: - Network

    private func performHold(sendSms: Bool) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await vm.createGuestHold(
                propertyId: property.id,
                checkin:    start,
                checkout:   end,
                fixedPrice: parsedPrice,
                guestPhone: nonEmpty(phone),
                guestEmail: nonEmpty(email),
                sendSms:    sendSms
            )
            guard let token = response.token ?? response.holdToken,
                  let url   = buildLink(token: token) else {
                error = "Le serveur n'a pas renvoyé de lien valide."
                return
            }
            await vm.reloadMonthData()
            result = HoldResult(url: url, smsSent: response.smsSent ?? false)
        } catch {
            self.error = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }

    // MARK: - Helpers

    private var parsedPrice: Double? {
        Double(priceText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    private func nonEmpty(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
    }

    private func buildLink(token: String) -> URL? {
        let base = "https://www.boostinghost.fr/guest-app/public"
        guard var comps = URLComponents(string: base) else { return nil }
        var items: [URLQueryItem] = [
            .init(name: "property", value: property.id),
            .init(name: "checkin",  value: CalendarViewModel.dayKey(for: start)),
            .init(name: "checkout", value: CalendarViewModel.dayKey(for: end)),
        ]
        if let fp = parsedPrice {
            items.append(.init(name: "fixed_price", value: String(Int(fp.rounded()))))
        }
        if let p = nonEmpty(phone) { items.append(.init(name: "guest_phone", value: p)) }
        if let e = nonEmpty(email) { items.append(.init(name: "guest_email", value: e)) }
        items.append(.init(name: "hold_token", value: token))
        comps.queryItems = items
        return comps.url
    }
}
