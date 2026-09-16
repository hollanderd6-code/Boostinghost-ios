import SwiftUI
import PDFKit
import Observation

// MARK: - ViewModel

@MainActor
@Observable
final class ReservationInvoiceViewModel {

    enum LoadState { case loading, loaded, error(String) }

    struct ResendFeedback {
        let invoiceId: String
        let message: String
        let isError: Bool
    }

    struct PdfPayload: Identifiable {
        let id: String    // invoiceNumber — utilisé dans le nom du fichier partagé
        let data: Data
    }

    let reservationUid: String
    let propertyName: String
    let startDate: String
    let endDate: String

    var loadState: LoadState = .loading
    var invoices: [Invoice] = []

    // Renvoi
    var confirmResend: Invoice? = nil
    var resendingId: String? = nil
    var resendFeedback: ResendFeedback? = nil

    // PDF
    var loadingPdfFor: String? = nil
    var pdfPayload: PdfPayload? = nil
    var pdfErrorFor: String? = nil
    var pdfError: String? = nil

    init(reservationUid: String, propertyName: String, startDate: String, endDate: String) {
        self.reservationUid = reservationUid
        self.propertyName = propertyName
        self.startDate = startDate
        self.endDate = endDate
    }

    func load() async {
        if case .loaded = loadState {} else { loadState = .loading }
        do {
            let resp: InvoiceHistoryResponse = try await APIClient.shared.get(Endpoint.invoiceHistory)

            // Primary: reservationUid (populated only when sent via conversation).
            // Fallback: propertyName + dates (email-only invoices have null reservationUid).
            invoices = resp.invoices.filter { inv in
                if let uid = inv.reservationUid, !uid.isEmpty {
                    return uid == reservationUid
                }
                guard !startDate.isEmpty, !endDate.isEmpty else { return false }
                return inv.propertyName == propertyName
                    && inv.checkinDate == startDate
                    && inv.checkoutDate == endDate
            }

            loadState = .loaded
        } catch {
            loadState = .error((error as? APIError)?.userMessage ?? error.localizedDescription)
        }
    }

    func triggerResend(_ invoice: Invoice) {
        confirmResend = invoice
    }

    func resend(_ invoice: Invoice) async {
        guard let number = invoice.invoiceNumber else { return }
        resendingId   = invoice.id
        resendFeedback = nil
        defer { resendingId = nil }

        struct Body: Encodable { let invoiceNumber: String }
        struct Response: Decodable { let success: Bool?; let message: String? }

        do {
            let resp: Response = try await APIClient.shared.post(
                Endpoint.resendInvoice, body: Body(invoiceNumber: number)
            )
            resendFeedback = ResendFeedback(
                invoiceId: invoice.id,
                message:   resp.message ?? "Facture renvoyée.",
                isError:   false
            )
        } catch {
            resendFeedback = ResendFeedback(
                invoiceId: invoice.id,
                message:   (error as? APIError)?.userMessage ?? error.localizedDescription,
                isError:   true
            )
        }
    }

    func openPdf(invoiceNumber: String) async {
        loadingPdfFor = invoiceNumber
        pdfErrorFor   = nil
        pdfError      = nil
        defer { loadingPdfFor = nil }
        do {
            let data = try await APIClient.shared.getData(
                Endpoint.invoiceDownloadByNumber(invoiceNumber)
            )
            pdfPayload = PdfPayload(id: invoiceNumber, data: data)
        } catch {
            pdfErrorFor = invoiceNumber
            pdfError    = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }
}

// MARK: - Feuille principale

struct ReservationInvoiceSheet: View {
    let guestName: String

    @Environment(\.dismiss) private var dismiss
    @State private var vm: ReservationInvoiceViewModel

    init(reservationUid: String, guestName: String, propertyName: String, startDate: String, endDate: String) {
        self.guestName = guestName
        _vm = State(initialValue: ReservationInvoiceViewModel(
            reservationUid: reservationUid,
            propertyName:   propertyName,
            startDate:      startDate,
            endDate:        endDate
        ))
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        mainContent
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .refreshable { await vm.load() }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.load() }
        .confirmationDialog(
            "Renvoyer la facture ?",
            isPresented: Binding(
                get:  { vm.confirmResend != nil },
                set:  { if !$0 { vm.confirmResend = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Renvoyer par mail") {
                if let inv = vm.confirmResend {
                    vm.confirmResend = nil
                    Task { await vm.resend(inv) }
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            if let email = vm.confirmResend?.clientEmail, !email.isEmpty {
                Text("La facture sera envoyée à \(email).")
            }
        }
        .sheet(item: $vm.pdfPayload) { payload in
            InvoicePdfSheet(data: payload.data, invoiceNumber: payload.id)
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
                    Text(guestName)
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(1)
                    Text("Factures")
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

    // MARK: - Contenu principal

    @ViewBuilder
    private var mainContent: some View {
        switch vm.loadState {
        case .loading:
            VStack {
                Spacer(minLength: 60)
                ProgressView().scaleEffect(1.2)
            }
            .frame(maxWidth: .infinity)

        case .error(let msg):
            VStack(spacing: 12) {
                Spacer(minLength: 40)
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.bhAttenue)
                Text(msg)
                    .font(.bhCorps)
                    .foregroundStyle(Color.bhAttenue)
                    .multilineTextAlignment(.center)
                Button("Réessayer") { Task { await vm.load() } }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
            }
            .frame(maxWidth: .infinity)

        case .loaded:
            if vm.invoices.isEmpty {
                emptyView
            } else {
                invoiceListCard
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 40)
            Text("Aucune facture pour cette réservation.")
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var invoiceListCard: some View {
        ListCard {
            VStack(spacing: 0) {
                ForEach(Array(vm.invoices.enumerated()), id: \.element.id) { idx, inv in
                    CardRow(showSeparator: idx < vm.invoices.count - 1) {
                        invoiceRow(inv)
                    }
                }
            }
        }
    }

    // MARK: - Ligne facture

    @ViewBuilder
    private func invoiceRow(_ inv: Invoice) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(inv.clientName ?? guestName)
                        .font(.bhTitreLigne)
                        .foregroundStyle(Color.bhEncre)
                    if let d = inv.createdAt {
                        Text("Créée le \(Formatters.day(d))")
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhAttenue)
                    }
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 3) {
                    if let total = inv.total {
                        Text(Formatters.amount(total))
                            .font(.bhTitreLigne)
                            .foregroundStyle(Color.bhEncre)
                    }
                    if let num = inv.invoiceNumber {
                        Text(num)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.bhAttenue)
                    }
                }
            }

            invoiceActions(inv)

            // Résultat du renvoi (succès ou erreur)
            if let fb = vm.resendFeedback, fb.invoiceId == inv.id {
                Text(fb.message)
                    .font(.bhMeta)
                    .foregroundStyle(fb.isError ? Color.bhTerracotta : Color.bhVert)
            }

            // Erreur de téléchargement PDF
            if let errFor = vm.pdfErrorFor, errFor == inv.invoiceNumber,
               let err = vm.pdfError {
                Text(err)
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhTerracotta)
            }
        }
    }

    @ViewBuilder
    private func invoiceActions(_ inv: Invoice) -> some View {
        let isResending   = vm.resendingId == inv.id
        let isLoadingPdf  = vm.loadingPdfFor == inv.invoiceNumber && inv.invoiceNumber != nil
        let anyBusy       = isResending || isLoadingPdf

        let hasPdf    = inv.invoiceNumber != nil
        let hasResend = inv.canResend

        if hasPdf || hasResend {
            HStack(spacing: 8) {
                if let number = inv.invoiceNumber {
                    Button {
                        Task { await vm.openPdf(invoiceNumber: number) }
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
                        .padding(.vertical, 10)
                        .glassEffect(in: .rect(cornerRadius: 12))
                        .specularEdge(cornerRadius: 12)
                    }
                    .buttonStyle(.plain)
                    .disabled(anyBusy)
                }

                if hasResend {
                    Button { vm.triggerResend(inv) } label: {
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
                        .padding(.vertical, 10)
                        .background(Color.bhVert,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(anyBusy)
                }
            }
        }
    }
}

// MARK: - Feuille de visualisation PDF

private struct InvoicePdfSheet: View {
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
            InvoicePdfView(data: data)
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
                                preview: SharePreview("\(invoiceNumber).pdf",
                                                     image: Image(systemName: "doc.pdf"))
                            )
                            .foregroundStyle(Color.bhVert)
                        }
                    }
                }
        }
    }
}

// MARK: - Visionneuse PDFKit (même pattern que ContractDetailView)

private struct InvoicePdfView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        if let doc = PDFDocument(data: data) {
            pdfView.document = doc
        }
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
