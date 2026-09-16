import SwiftUI
import PDFKit

// MARK: - Feuille de détail d'une facture voyageur
// Ouverte depuis la liste Séjours > Factures (chevron sur chaque ligne).
// Toutes les données arrivent directement depuis l'Invoice déjà chargé ;
// aucun appel réseau supplémentaire n'est nécessaire pour afficher la fiche.

struct InvoiceDetailSheet: View {
    let invoice: Invoice

    @Environment(\.dismiss) private var dismiss

    // PDF
    @State private var isLoadingPdf = false
    @State private var pdfPayload: InvoiceDetailPdfPayload? = nil
    @State private var pdfError: String? = nil

    // Renvoi par email
    @State private var showResendConfirm = false
    @State private var isResending = false
    @State private var resendFeedback: (message: String, isError: Bool)? = nil

    // Envoi dans la conversation
    @State private var showConvConfirm = false
    @State private var isSendingToConv = false
    @State private var convFeedback: (message: String, isError: Bool)? = nil

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ZStack(alignment: .bottom) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            heroCard
                            if !clientRows.isEmpty {
                                sectionCard(title: "Client", rows: clientRows)
                            }
                            if !sejourRows.isEmpty {
                                sectionCard(title: "Séjour", rows: sejourRows)
                            }
                            if !montantsRows.isEmpty {
                                sectionCard(title: "Montants", rows: montantsRows)
                            }
                            disclaimer
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, hasActions ? 120 : 40)
                    }
                    if hasActions {
                        actionBar
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Renvoyer la facture ?",
            isPresented: $showResendConfirm,
            titleVisibility: .visible
        ) {
            Button("Renvoyer par mail") { Task { await resend() } }
            Button("Annuler", role: .cancel) {}
        } message: {
            if let email = invoice.clientEmail, !email.isEmpty {
                Text("La facture sera envoyée à \(email).")
            }
        }
        .alert(
            "Envoyer la facture dans la conversation ?",
            isPresented: $showConvConfirm
        ) {
            Button("Envoyer") { Task { await sendToConversation() } }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Le voyageur va recevoir un message dans le fil de la conversation. Cette action est irréversible.")
        }
        .alert("Erreur PDF", isPresented: Binding(
            get: { pdfError != nil },
            set: { if !$0 { pdfError = nil } }
        )) {
            Button("OK") { pdfError = nil }
        } message: {
            Text(pdfError ?? "")
        }
        .sheet(item: $pdfPayload) { payload in
            InvoiceDetailPdfSheet(data: payload.data, invoiceNumber: payload.id)
        }
    }

    // MARK: - Barre de navigation

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
                    Text(invoice.invoiceNumber ?? (invoice.createdAt.map { Formatters.day($0) } ?? " "))
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(1)
                    Text(invoice.clientName ?? "Facture")
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

    // MARK: - Carte héro (montant total)

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let total = invoice.total {
                Text(Formatters.amount(total))
                    .bhValeurHero()
            } else {
                Text("—")
                    .bhValeurHero()
            }
            if let prop = invoice.propertyName, !prop.isEmpty {
                Text(prop)
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background { GlassCardBackground(cornerRadius: 22, fillOpacity: 0.70) }
    }

    // MARK: - Données des sections

    private struct InvoiceDetailRow: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        var isAccent: Bool = false
    }

    private var clientRows: [InvoiceDetailRow] {
        var rows: [InvoiceDetailRow] = []
        if let v = invoice.clientName,        !v.isEmpty { rows.append(.init(label: "Nom",         value: v)) }
        if let v = invoice.clientEmail,       !v.isEmpty { rows.append(.init(label: "Email",       value: v)) }
        if let v = invoice.clientCompany,     !v.isEmpty { rows.append(.init(label: "Entreprise",  value: v)) }
        if let v = invoice.clientSiret,       !v.isEmpty { rows.append(.init(label: "SIRET",       value: v)) }
        if let v = invoice.clientAddress,     !v.isEmpty { rows.append(.init(label: "Adresse",     value: v)) }
        let pc   = invoice.clientPostalCode ?? ""
        let city = invoice.clientCity ?? ""
        let loc  = [pc, city].filter { !$0.isEmpty }.joined(separator: " ")
        if !loc.isEmpty { rows.append(.init(label: "Ville", value: loc)) }
        if let v = invoice.clientNationality, !v.isEmpty { rows.append(.init(label: "Nationalité", value: v)) }
        return rows
    }

    private var sejourRows: [InvoiceDetailRow] {
        var rows: [InvoiceDetailRow] = []
        if let v = invoice.propertyName, !v.isEmpty { rows.append(.init(label: "Logement", value: v)) }
        if let ci = invoice.checkinDate  { rows.append(.init(label: "Arrivée", value: Formatters.day(ci))) }
        if let co = invoice.checkoutDate { rows.append(.init(label: "Départ",  value: Formatters.day(co))) }
        if let n  = invoice.nights {
            rows.append(.init(label: "Durée", value: n == 1 ? "1 nuit" : "\(n) nuits"))
        }
        if let p = invoice.platform, !p.isEmpty {
            rows.append(.init(label: "Canal", value: Color.platformLabel(p)))
        }
        return rows
    }

    private var montantsRows: [InvoiceDetailRow] {
        var rows: [InvoiceDetailRow] = []
        if let v = invoice.rentAmount,       v > 0 { rows.append(.init(label: "Loyer",          value: Formatters.amount(v))) }
        if let v = invoice.cleaningFee,      v > 0 { rows.append(.init(label: "Ménage",         value: Formatters.amount(v))) }
        if let v = invoice.touristTaxAmount, v > 0 { rows.append(.init(label: "Taxe de séjour", value: Formatters.amount(v))) }
        if let rate = invoice.vatRate, let vat = invoice.vatAmount, vat > 0 {
            let rateStr = rate.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(rate))\u{202F}%"
                : String(format: "%.2f", rate) + "\u{202F}%"
            rows.append(.init(label: "TVA (\(rateStr))", value: Formatters.amount(vat)))
        }
        if let v = invoice.total {
            rows.append(.init(label: "Total", value: Formatters.amount(v), isAccent: true))
        }
        return rows
    }

    // MARK: - Carte de section générique

    private func sectionCard(title: String, rows: [InvoiceDetailRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            ListCard {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                        CardRow(showSeparator: idx < rows.count - 1) {
                            HStack(alignment: .top, spacing: 8) {
                                Text(row.label)
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(Color.bhAttenue)
                                    .padding(.top, 1)
                                Spacer(minLength: 12)
                                Text(row.value)
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(row.isAccent ? Color.bhVert : Color.bhEncre)
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Mention d'immutabilité

    private var disclaimer: some View {
        Text("Les factures émises ne peuvent pas être modifiées.")
            .font(.system(size: 13))
            .foregroundStyle(Color.bhAttenue)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }

    // MARK: - Barre d'actions (fixe en bas)

    private var hasActions: Bool {
        invoice.invoiceNumber != nil || invoice.canResend || invoice.canSendToConversation
    }

    private var actionBar: some View {
        let busy = isResending || isSendingToConv || isLoadingPdf

        return VStack(spacing: 8) {
            if let fb = resendFeedback {
                Text(fb.message)
                    .font(.system(size: 13))
                    .foregroundStyle(fb.isError ? Color.bhTerracotta : Color.bhVert)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if let fb = convFeedback {
                Text(fb.message)
                    .font(.system(size: 13))
                    .foregroundStyle(fb.isError ? Color.bhTerracotta : Color.bhVert)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(spacing: 10) {
                if let number = invoice.invoiceNumber {
                    Button {
                        Task { await loadPdf(invoiceNumber: number) }
                    } label: {
                        Group {
                            if isLoadingPdf {
                                ProgressView()
                            } else {
                                Label("Voir le PDF", systemImage: "doc.pdf")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.bhEncreDouce)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .glassEffect(in: .rect(cornerRadius: 12))
                        .specularEdge(cornerRadius: 12)
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)
                }

                if invoice.canResend {
                    Button { showResendConfirm = true } label: {
                        Group {
                            if isResending {
                                ProgressView().tint(.white)
                            } else {
                                Text("Renvoyer")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.bhVert,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)
                }
            }

            if invoice.canSendToConversation {
                Button { showConvConfirm = true } label: {
                    Group {
                        if isSendingToConv {
                            ProgressView()
                        } else {
                            Text("Envoyer dans la conversation")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.bhEncreDouce)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .glassEffect(in: .rect(cornerRadius: 12))
                    .specularEdge(cornerRadius: 12)
                }
                .buttonStyle(.plain)
                .disabled(busy)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Actions réseau

    private func loadPdf(invoiceNumber: String) async {
        isLoadingPdf = true
        defer { isLoadingPdf = false }
        do {
            let data = try await APIClient.shared.getData(
                Endpoint.invoiceDownloadByNumber(invoiceNumber)
            )
            pdfPayload = InvoiceDetailPdfPayload(id: invoiceNumber, data: data)
        } catch {
            pdfError = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }

    private func resend() async {
        guard let number = invoice.invoiceNumber else { return }
        isResending = true
        resendFeedback = nil
        defer { isResending = false }

        struct Body: Encodable { let invoiceNumber: String }
        struct Response: Decodable { let success: Bool?; let message: String? }

        do {
            let resp: Response = try await APIClient.shared.post(
                Endpoint.resendInvoice, body: Body(invoiceNumber: number)
            )
            resendFeedback = (message: resp.message ?? "Facture renvoyée.", isError: false)
        } catch {
            resendFeedback = (
                message: (error as? APIError)?.userMessage ?? error.localizedDescription,
                isError: true
            )
        }
    }

    private func sendToConversation() async {
        isSendingToConv = true
        convFeedback = nil
        defer { isSendingToConv = false }

        struct ByConversation: Encodable { let conversationId: Int }
        struct ByReservation: Encodable { let reservationUid: String }
        struct SendResponse: Decodable { let invoiceNumber: String? }

        do {
            let resp: SendResponse
            if let cid = invoice.conversationId {
                resp = try await APIClient.shared.post(
                    Endpoint.sendInvoiceToConversation,
                    body: ByConversation(conversationId: cid),
                    agencyAll: true
                )
            } else if let uid = invoice.reservationUid {
                resp = try await APIClient.shared.post(
                    Endpoint.sendInvoiceToConversation,
                    body: ByReservation(reservationUid: uid),
                    agencyAll: true
                )
            } else {
                return
            }
            let num = resp.invoiceNumber ?? invoice.invoiceNumber
            convFeedback = (
                message: num.map { "Facture \($0) envoyée." } ?? "Facture envoyée.",
                isError: false
            )
        } catch {
            convFeedback = (
                message: (error as? APIError)?.userMessage ?? error.localizedDescription,
                isError: true
            )
        }
    }
}

// MARK: - Payload PDF (file-private pour éviter le conflit avec ReservationInvoiceViewModel.PdfPayload)

private struct InvoiceDetailPdfPayload: Identifiable {
    let id: String
    let data: Data
}

// MARK: - Feuille de visualisation PDF

private struct InvoiceDetailPdfSheet: View {
    let data: Data
    let invoiceNumber: String

    @Environment(\.dismiss) private var dismiss

    private var tempURL: URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(invoiceNumber).pdf")
        try? data.write(to: url)
        return url
    }

    var body: some View {
        NavigationStack {
            InvoiceDetailPdfView(data: data)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(invoiceNumber)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Fermer") { dismiss() }
                            .foregroundStyle(Color.bhVert)
                    }
                    if let url = tempURL {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            ShareLink(
                                item: url,
                                preview: SharePreview(
                                    "\(invoiceNumber).pdf",
                                    image: Image(systemName: "doc.pdf")
                                )
                            )
                            .foregroundStyle(Color.bhVert)
                        }
                    }
                }
        }
    }
}

private struct InvoiceDetailPdfView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales    = true
        v.displayMode   = .singlePageContinuous
        v.displayDirection = .vertical
        if let doc = PDFDocument(data: data) { v.document = doc }
        return v
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
