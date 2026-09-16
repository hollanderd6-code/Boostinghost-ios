import SwiftUI

struct InvoiceCreationSheet: View {
    let arrivee: Arrivee
    let reservation: Reservation?

    @Environment(\.dismiss) private var dismiss

    // Client
    @State private var clientName: String
    @State private var clientEmail: String
    @State private var clientNationality: String
    @State private var clientAddress: String
    @State private var clientPostalCode: String
    @State private var clientCity: String
    @State private var isProfessional: Bool
    @State private var clientCompany: String
    @State private var clientSiret: String
    @State private var freeNote: String

    // Séjour
    @State private var checkinDate: Date
    @State private var checkoutDate: Date

    // Montants
    @State private var rentAmount: String
    @State private var touristTaxAmount: String
    @State private var cleaningFee: String
    @State private var withVat: Bool
    @State private var vatRate: String

    // Sending
    @State private var isSending: Bool
    @State private var feedback: (message: String, isError: Bool)?
    @State private var createdInvoiceNumber: String?

    init(arrivee: Arrivee, reservation: Reservation?) {
        self.arrivee = arrivee
        self.reservation = reservation

        let r = reservation
        let firstName = r?.guestFirstName ?? ""
        let lastName  = r?.guestLastName  ?? ""
        let fullName  = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)

        _clientName        = State(initialValue: fullName.isEmpty ? (r?.guestName ?? arrivee.guestName ?? "Voyageur") : fullName)
        _clientEmail       = State(initialValue: r?.guestEmail ?? "")
        _clientNationality = State(initialValue: Self.nationalityLabel(from: r?.guestCountry ?? ""))
        _clientAddress     = State(initialValue: "")
        _clientPostalCode  = State(initialValue: "")
        _clientCity        = State(initialValue: "")
        _isProfessional    = State(initialValue: false)
        _clientCompany     = State(initialValue: "")
        _clientSiret       = State(initialValue: "")
        _freeNote          = State(initialValue: "")

        let checkin: Date = {
            guard let s = r?.startDate, let d = Self.isoFormatter.date(from: s) else { return Date() }
            return d
        }()
        let checkout: Date = {
            guard let s = r?.endDate, let d = Self.isoFormatter.date(from: s) else {
                return Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            }
            return d
        }()
        _checkinDate  = State(initialValue: checkin)
        _checkoutDate = State(initialValue: checkout)

        _rentAmount       = State(initialValue: Self.fmtOpt(r?.amountRooms ?? r?.amountTotal))
        _touristTaxAmount = State(initialValue: Self.fmtOpt(r?.amountTaxes))
        _cleaningFee      = State(initialValue: Self.fmtOpt(r?.amountCleaning))
        _withVat          = State(initialValue: false)
        _vatRate          = State(initialValue: "10")

        _isSending            = State(initialValue: false)
        _feedback             = State(initialValue: nil)
        _createdInvoiceNumber = State(initialValue: nil)
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                if let number = createdInvoiceNumber {
                    successView(invoiceNumber: number)
                } else {
                    mainContent
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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
                    Text(arrivee.propertyName)
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(1)
                    Text("Générer une facture")
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

    // MARK: - Main content

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    clientSection
                    sejourSection
                    montantsSection
                    noteSection
                    disclaimer
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            actionBar
        }
    }

    // MARK: - Client section

    private var clientSection: some View {
        Group {
            SectionLabel(text: "Client")
            ListCard {
                VStack(spacing: 0) {
                    CardRow(showSeparator: true) {
                        fieldRow(label: "Nom *", binding: $clientName, placeholder: "Nom du client")
                    }
                    CardRow(showSeparator: true) {
                        fieldRow(label: "E-mail", binding: $clientEmail,
                                 placeholder: "email@exemple.com", keyboard: .emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    CardRow(showSeparator: true) {
                        nationalityRow
                    }
                    CardRow(showSeparator: true) {
                        fieldRow(label: "Adresse", binding: $clientAddress, placeholder: "Rue et numéro")
                    }
                    CardRow(showSeparator: true) {
                        fieldRow(label: "Code postal", binding: $clientPostalCode,
                                 placeholder: "75001", keyboard: .numberPad)
                    }
                    CardRow(showSeparator: true) {
                        fieldRow(label: "Ville", binding: $clientCity, placeholder: "Paris")
                    }
                    CardRow(showSeparator: isProfessional) {
                        Toggle("Professionnel", isOn: $isProfessional)
                            .font(.bhTitreLigne)
                            .foregroundStyle(Color.bhEncre)
                            .tint(Color.bhVert)
                    }
                    if isProfessional {
                        CardRow(showSeparator: true) {
                            fieldRow(label: "Société", binding: $clientCompany,
                                     placeholder: "Nom de la société")
                        }
                        CardRow(showSeparator: false) {
                            fieldRow(label: "SIRET", binding: $clientSiret,
                                     placeholder: "00000000000000", keyboard: .numberPad)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var nationalityRow: some View {
        HStack {
            Text("Nationalité")
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
            Spacer()
            Menu {
                Button("—") { clientNationality = "" }
                ForEach(Self.nationalityOptions, id: \.self) { nat in
                    Button(nat.capitalized) { clientNationality = nat }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(clientNationality.isEmpty ? "—" : clientNationality.capitalized)
                        .font(.bhTitreLigne)
                        .foregroundStyle(clientNationality.isEmpty ? Color.bhAttenue : Color.bhEncre)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.bhAttenue)
                }
            }
        }
    }

    // MARK: - Séjour section

    private var sejourSection: some View {
        Group {
            SectionLabel(text: "Séjour")
            ListCard {
                VStack(spacing: 0) {
                    CardRow(showSeparator: true) {
                        HStack {
                            Text("Logement")
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhAttenue)
                            Spacer()
                            Text(arrivee.propertyName)
                                .font(.bhTitreLigne)
                                .foregroundStyle(Color.bhEncre)
                                .lineLimit(1)
                        }
                    }
                    CardRow(showSeparator: true) {
                        HStack {
                            Text("Arrivée")
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhAttenue)
                            Spacer()
                            DatePicker("", selection: $checkinDate, displayedComponents: .date)
                                .labelsHidden()
                                .tint(Color.bhVert)
                        }
                    }
                    CardRow(showSeparator: true) {
                        HStack {
                            Text("Départ")
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhAttenue)
                            Spacer()
                            DatePicker("", selection: $checkoutDate,
                                       in: checkinDate..., displayedComponents: .date)
                                .labelsHidden()
                                .tint(Color.bhVert)
                        }
                    }
                    CardRow(showSeparator: false) {
                        HStack {
                            Text("Durée")
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhAttenue)
                            Spacer()
                            Text(nightsLabel)
                                .font(.bhTitreLigne)
                                .foregroundStyle(Color.bhEncre)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Montants section

    private var montantsSection: some View {
        Group {
            SectionLabel(text: "Montants")
            ListCard {
                VStack(spacing: 0) {
                    CardRow(showSeparator: true) {
                        amountRow(label: "Loyer", binding: $rentAmount)
                    }
                    CardRow(showSeparator: true) {
                        amountRow(label: "Taxe de séjour", binding: $touristTaxAmount)
                    }
                    CardRow(showSeparator: true) {
                        amountRow(label: "Ménage", binding: $cleaningFee)
                    }
                    CardRow(showSeparator: withVat) {
                        Toggle("TVA", isOn: $withVat)
                            .font(.bhTitreLigne)
                            .foregroundStyle(Color.bhEncre)
                            .tint(Color.bhVert)
                    }
                    if withVat {
                        CardRow(showSeparator: false) {
                            HStack {
                                Text("Taux")
                                    .font(.bhMeta)
                                    .foregroundStyle(Color.bhAttenue)
                                Spacer()
                                Picker("", selection: $vatRate) {
                                    Text("10 %").tag("10")
                                    Text("20 %").tag("20")
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 130)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Note libre

    private var noteSection: some View {
        Group {
            SectionLabel(text: "Note libre")
            ListCard {
                CardRow(showSeparator: false) {
                    TextField("Texte ajouté en bas de la facture…", text: $freeNote, axis: .vertical)
                        .font(.bhCorps)
                        .foregroundStyle(Color.bhEncre)
                        .lineLimit(3...6)
                }
            }
        }
    }

    // MARK: - Disclaimer

    private var disclaimer: some View {
        Text("La facture sera générée et envoyée par e-mail. Elle ne pourra pas être modifiée après envoi.")
            .font(.bhMeta)
            .foregroundStyle(Color.bhAttenue)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 4)
    }

    // MARK: - Action bar

    private var actionBar: some View {
        VStack(spacing: 8) {
            if let fb = feedback {
                Text(fb.message)
                    .font(.bhMeta)
                    .foregroundStyle(fb.isError ? Color.bhTerracotta : Color.bhVert)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
            Button {
                Task { await send() }
            } label: {
                Group {
                    if isSending {
                        ProgressView().tint(.white)
                    } else {
                        Text("Envoyer par e-mail")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    canSend ? Color.bhVert : Color(white: 0.65),
                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSend || isSending)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Success view

    private func successView(invoiceNumber: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.bhVert)
            Text("Facture \(invoiceNumber)")
                .font(.bhTitreLigneL)
                .foregroundStyle(Color.bhEncre)
            Text("Générée et envoyée par e-mail au client.")
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
            Button("Fermer") { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.bhVert,
                            in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.horizontal, 18)
            Spacer()
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Send

    private func send() async {
        feedback = nil
        isSending = true
        defer { isSending = false }

        struct Body: Encodable {
            let clientName: String
            let clientNationality: String?
            let clientEmail: String?
            let clientAddress: String?
            let clientPostalCode: String?
            let clientCity: String?
            let clientCompany: String?
            let clientSiret: String?
            let freeNote: String?
            let platform: String?
            let propertyName: String
            let propertyAddress: String?
            let checkinDate: String
            let checkoutDate: String
            let nights: Int?
            let rentAmount: Double
            let touristTaxAmount: Double
            let cleaningFee: Double
            let vatRate: Double?
            let sendEmail: Bool
        }
        struct Response: Decodable {
            let success: Bool?
            let invoiceNumber: String?
            let message: String?
        }

        let n = nights
        let body = Body(
            clientName:        opt(clientName) ?? clientName,
            clientNationality: opt(clientNationality),
            clientEmail:       opt(clientEmail),
            clientAddress:     opt(clientAddress),
            clientPostalCode:  opt(clientPostalCode),
            clientCity:        opt(clientCity),
            clientCompany:     isProfessional ? opt(clientCompany) : nil,
            clientSiret:       isProfessional ? opt(clientSiret)   : nil,
            freeNote:          opt(freeNote),
            platform:          arrivee.platform.flatMap { $0.isEmpty ? nil : $0 },
            propertyName:      arrivee.propertyName,
            propertyAddress:   arrivee.propertyAddress.flatMap { $0.isEmpty ? nil : $0 },
            checkinDate:       Self.isoFormatter.string(from: checkinDate),
            checkoutDate:      Self.isoFormatter.string(from: checkoutDate),
            nights:            n > 0 ? n : nil,
            rentAmount:        parseAmount(rentAmount),
            touristTaxAmount:  parseAmount(touristTaxAmount),
            cleaningFee:       parseAmount(cleaningFee),
            vatRate:           withVat ? Double(vatRate) : nil,
            sendEmail:         true
        )
        do {
            let resp: Response = try await APIClient.shared.post(Endpoint.createInvoice, body: body)
            if let number = resp.invoiceNumber {
                createdInvoiceNumber = number
            } else {
                feedback = (resp.message ?? "Facture générée.", false)
            }
        } catch {
            feedback = ((error as? APIError)?.userMessage ?? error.localizedDescription, true)
        }
    }

    // MARK: - Helpers

    private var canSend: Bool {
        !clientName.trimmingCharacters(in: .whitespaces).isEmpty
            && !clientEmail.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var nights: Int {
        let diff = Calendar.current.dateComponents([.day], from: checkinDate, to: checkoutDate)
        return max(0, diff.day ?? 0)
    }

    private var nightsLabel: String {
        let n = nights
        return n == 1 ? "1 nuit" : "\(n) nuits"
    }

    private func opt(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
    }

    private func parseAmount(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    @ViewBuilder
    private func fieldRow(label: String, binding: Binding<String>,
                          placeholder: String = "", keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
                .fixedSize()
            Spacer(minLength: 8)
            TextField(placeholder, text: binding)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .font(.bhTitreLigne)
                .foregroundStyle(Color.bhEncre)
        }
    }

    private func amountRow(label: String, binding: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
            Spacer()
            TextField("0", text: binding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.bhTitreLigne)
                .foregroundStyle(Color.bhEncre)
                .frame(width: 90)
            Text("€")
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
        }
    }

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func fmtOpt(_ value: Double?) -> String {
        guard let v = value, v > 0 else { return "" }
        if v.truncatingRemainder(dividingBy: 1) == 0 { return String(format: "%.0f", v) }
        return String(format: "%.2f", v)
    }

    // MARK: - Nationality

    static func nationalityLabel(from code: String) -> String {
        let map: [String: String] = [
            "FR": "française",     "BE": "belge",          "CH": "suisse",
            "CA": "canadienne",    "LU": "luxembourgeoise", "DE": "allemande",
            "GB": "britannique",   "US": "américaine",      "ES": "espagnole",
            "IT": "italienne",     "PT": "portugaise",      "NL": "néerlandaise",
            "AU": "australienne",  "NZ": "néo-zélandaise",  "BR": "brésilienne",
            "AR": "argentine",     "MX": "mexicaine",       "CO": "colombienne",
            "JP": "japonaise",     "CN": "chinoise",        "KR": "coréenne",
            "IN": "indienne",      "RU": "russe",           "TR": "turque",
            "MA": "marocaine",     "TN": "tunisienne",      "DZ": "algérienne",
            "SN": "sénégalaise",   "ZA": "sud-africaine",   "EG": "égyptienne",
            "SA": "saoudienne",    "AE": "émiratie",        "PL": "polonaise",
            "SE": "suédoise"
        ]
        return map[code.uppercased()] ?? ""
    }

    static let nationalityOptions: [String] = [
        "française", "belge", "suisse", "canadienne", "luxembourgeoise",
        "allemande", "britannique", "américaine", "espagnole", "italienne",
        "portugaise", "néerlandaise", "australienne", "néo-zélandaise",
        "brésilienne", "argentine", "mexicaine", "colombienne", "japonaise",
        "chinoise", "coréenne", "indienne", "russe", "turque", "marocaine",
        "tunisienne", "algérienne", "sénégalaise", "sud-africaine", "égyptienne",
        "saoudienne", "émiratie", "polonaise", "suédoise"
    ]
}
