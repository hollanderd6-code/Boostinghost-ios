import SwiftUI
import QuickLook

struct OwnerInvoiceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: OwnerInvoiceDetailViewModel
    var onChanged: (() -> Void)? = nil

    @State private var isPdfLoading = false
    @State private var pdfURL: URL? = nil
    @State private var pdfError: String? = nil

    @State private var headerExpanded     = true
    @State private var clientExpanded     = true
    @State private var itemsExpanded      = true
    @State private var propertiesExpanded = false
    @State private var totalsExpanded     = true
    @State private var condExpanded       = false

    @State private var showFinalizeConfirm = false
    @State private var showSendConfirm     = false
    @State private var showDeleteConfirm   = false
    @State private var actionError: String? = nil

    init(invoiceId: String, onChanged: (() -> Void)? = nil) {
        _vm = State(initialValue: OwnerInvoiceDetailViewModel(invoiceId: invoiceId))
        self.onChanged = onChanged
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                switch vm.loadState {
                case .loading:
                    Spacer()
                    ProgressView().tint(Color.bhAttenue)
                    Spacer()
                case .error(let msg):
                    errorView(msg)
                case .loaded:
                    if let detail = vm.detail { loadedContent(detail) }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .task { await vm.load() }
        .quickLookPreview($pdfURL)
        .alert("Erreur PDF", isPresented: Binding(
            get: { pdfError != nil },
            set: { if !$0 { pdfError = nil } }
        )) {
            Button("OK") { pdfError = nil }
        } message: {
            Text(pdfError ?? "")
        }
        .alert("Erreur", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK") { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
        .alert("Valider cette facture ?", isPresented: $showFinalizeConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Valider") { Task { await doFinalize() } }
        } message: {
            Text("Un numéro définitif sera attribué et la facture ne pourra plus être modifiée.")
        }
        .alert("Envoyer cette facture ?", isPresented: $showSendConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Envoyer") { Task { await doSend() } }
        } message: {
            Text(vm.detail?.invoice.status == "draft"
                ? "La facture sera validée et envoyée au client par email."
                : "La facture sera envoyée au client par email.")
        }
        .alert("Supprimer ce brouillon ?", isPresented: $showDeleteConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) { Task { await doDelete() } }
        } message: {
            Text("Cette action est définitive.")
        }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
                    .frame(width: 38, height: 38)
                    .glassEffect(in: .circle)
                    .specularEdge(cornerRadius: 19)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(navSuperTitle)
                    .font(.bhSurTitre)
                    .foregroundStyle(Color.bhAttenue)
                Text(navTitle)
                    .bhGrandTitre()
            }
            .padding(.leading, 12)

            Spacer(minLength: 12)

            Button { Task { await fetchPdf() } } label: {
                Group {
                    if isPdfLoading {
                        ProgressView()
                            .tint(Color.bhVert)
                            .scaleEffect(0.75)
                    } else {
                        Image(systemName: "doc.text")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.bhVert)
                    }
                }
                .frame(width: 38, height: 38)
                .glassEffect(in: .circle)
                .specularEdge(cornerRadius: 19)
            }
            .buttonStyle(.plain)
            .disabled(isPdfLoading)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    private var navTitle: String {
        guard let inv = vm.detail?.invoice else { return "Facture" }
        if inv.isCreditNote == true { return "Avoir" }
        return inv.invoiceNumber.map { "N° \($0)" } ?? "Brouillon"
    }

    private var navSuperTitle: String {
        vm.detail?.invoice.statusLabel ?? " "
    }

    // MARK: - Contenu chargé

    private func loadedContent(_ response: OwnerInvoiceDetailResponse) -> some View {
        let inv = response.invoice
        return ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard(inv)
                    invoiceBody(response)
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }
            actionBar(inv)
        }
    }

    // MARK: - Carte en-tête (montant + statut)

    private func headerCard(_ inv: OwnerInvoiceDetail) -> some View {
        HStack(spacing: 8) {
            summaryBlock(
                value: inv.totalTtc.map { Formatters.amount($0) } ?? "—",
                label: "Total TTC",
                accent: true
            )
            summaryBlock(
                value: inv.subtotalHt.map { Formatters.amount($0) } ?? "—",
                label: "Sous-total HT",
                accent: false
            )
            summaryBlock(
                value: inv.tvaAmount.map { Formatters.amount($0) } ?? "—",
                label: "TVA",
                accent: false
            )
        }
    }

    private func summaryBlock(value: String, label: String, accent: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent ? Color.bhVert : Color.bhEncre)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.bhAttenue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background { GlassCardBackground(cornerRadius: 18, fillOpacity: 0.66) }
    }

    // MARK: - Corps de la facture

    private func invoiceBody(_ response: OwnerInvoiceDetailResponse) -> some View {
        let inv   = response.invoice
        let built = VStack(alignment: .leading, spacing: 0) {

            Text("FACTURE PROPRIÉTAIRE")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color.bhAttenue)
                .tracking(1.5)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 14)

            let headerBuilt = headerSection(inv)
            sectionCard("En-tête", isExpanded: $headerExpanded) { headerBuilt }

            dividerLine

            let clientBuilt = clientSection(inv)
            sectionCard("Client", isExpanded: $clientExpanded) { clientBuilt }

            dividerLine

            let itemsBuilt = itemsSection(response.items)
            sectionCard("Lignes", count: response.items.count, isExpanded: $itemsExpanded) { itemsBuilt }

            if !response.properties.isEmpty {
                dividerLine
                let propsBuilt = propertiesSection(response.properties)
                sectionCard("Logements", count: response.properties.count, isExpanded: $propertiesExpanded) { propsBuilt }
            }

            dividerLine

            let totalsBuilt = totalsSection(inv)
            sectionCard("Totaux", isExpanded: $totalsExpanded) { totalsBuilt }

            dividerLine

            let condBuilt = conditionsSection(inv)
            sectionCard("Conditions", isExpanded: $condExpanded) { condBuilt }
        }
        .padding(18)

        return built
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.72))
                    .shadow(
                        color: Color(red: 20/255, green: 32/255, blue: 27/255).opacity(0.08),
                        radius: 22, x: 0, y: 8
                    )
            )
    }

    private var dividerLine: some View {
        Rectangle().fill(Color.white.opacity(0.30)).frame(height: 0.5)
            .padding(.horizontal, -18)
    }

    // MARK: - Sections

    private func headerSection(_ inv: OwnerInvoiceDetail) -> some View {
        VStack(spacing: 0) {
            if let n = inv.invoiceNumber, !n.isEmpty {
                detailRow("Numéro",  value: n)
            }
            StatusPill(text: inv.statusLabel, style: inv.statusPillStyle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            if let v = inv.issueDate,  !v.isEmpty { detailRow("Émission",  value: Formatters.day(v)) }
            if let v = inv.dueDate,    !v.isEmpty { detailRow("Échéance",  value: Formatters.day(v)) }
            if let v = inv.periodStart, !v.isEmpty {
                let end = inv.periodEnd.map { " → \(Formatters.day($0))" } ?? ""
                detailRow("Période", value: "\(Formatters.day(v))\(end)", separator: false)
            }
        }
    }

    private func clientSection(_ inv: OwnerInvoiceDetail) -> some View {
        VStack(spacing: 0) {
            if let v = inv.clientName,    !v.isEmpty { detailRow("Nom",       value: v) }
            if let v = inv.clientAddress, !v.isEmpty { detailRow("Adresse",   value: v) }
            if let v = inv.clientSiret,   !v.isEmpty { detailRow("SIRET",     value: v) }
            if let v = inv.clientEmail,   !v.isEmpty { detailRow("Email",     value: v) }
            if let v = inv.clientPhone,   !v.isEmpty { detailRow("Téléphone", value: v, separator: false) }
        }
    }

    private func itemsSection(_ items: [OwnerInvoiceItem]) -> some View {
        VStack(spacing: 0) {
            if items.isEmpty {
                Text("Aucune ligne.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.bhAttenue)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    itemRow(item, separator: idx < items.count - 1)
                }
            }
        }
    }

    private func itemRow(_ item: OwnerInvoiceItem, separator: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.itemDescription ?? "—")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Color.bhEncre)
                        if item.isDebours == true {
                            Text("débours")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(Color.bhAttenue)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.bhAttenue.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    if let qty = item.quantity, let unit = item.unitPrice {
                        Text("\(formatDecimal(qty)) × \(Formatters.amount(unit))")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.bhAttenue)
                    }
                }
                Spacer(minLength: 8)
                if let total = item.total {
                    Text(Formatters.amount(total))
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                }
            }
            .padding(.vertical, 8)
            if separator {
                Rectangle().fill(Color.white.opacity(0.35)).frame(height: 0.5)
            }
        }
    }

    private func propertiesSection(_ props: [OwnerInvoiceProperty]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(props.enumerated()), id: \.element.id) { idx, prop in
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prop.name ?? "—")
                                .font(.system(size: 13.5))
                                .foregroundStyle(Color.bhEncre)
                            if let addr = prop.address, !addr.isEmpty {
                                Text(addr)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.bhAttenue)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    if idx < props.count - 1 {
                        Rectangle().fill(Color.white.opacity(0.35)).frame(height: 0.5)
                    }
                }
            }
        }
    }

    private func totalsSection(_ inv: OwnerInvoiceDetail) -> some View {
        VStack(spacing: 0) {
            if let v = inv.subtotalHt   { detailRow("Sous-total HT", value: Formatters.amount(v)) }
            if let v = inv.deboursTotal, v > 0 { detailRow("Débours",   value: Formatters.amount(v)) }
            if let v = inv.discountAmount, v > 0 { detailRow("Remise",  value: "− \(Formatters.amount(v))") }
            if let rate = inv.tvaRate, let amount = inv.tvaAmount {
                detailRow("TVA (\(formatDecimal(rate))\u{202F}%)", value: Formatters.amount(amount))
            }
            if let v = inv.totalTtc {
                detailRow("Total TTC", value: Formatters.amount(v), separator: false)
            }
        }
    }

    private func conditionsSection(_ inv: OwnerInvoiceDetail) -> some View {
        VStack(spacing: 0) {
            if let v = inv.paymentDelay {
                detailRow("Délai de paiement", value: v == 0 ? "À réception" : "\(v)\u{202F}jours")
            }
            if let v = inv.paymentMode, !v.isEmpty {
                detailRow("Mode de paiement", value: paymentModeLabel(v))
            }
            if let v = inv.lateInterestRate, v > 0 {
                detailRow("Intérêts de retard", value: "\(formatDecimal(v))\u{202F}%")
            }
            if let v = inv.notes, !v.isEmpty {
                detailRow("Notes", value: v, separator: false)
            }
        }
    }

    // MARK: - Section card helper

    private func sectionCard<Content: View>(
        _ title: String,
        count: Int? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let built = content()
        return DisclosureGroup(isExpanded: isExpanded) {
            Divider().padding(.top, 8).padding(.bottom, 4)
            built
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Color.bhAttenue)
                if let n = count {
                    Text("\(n)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(n > 0 ? Color.bhVert : Color.bhAttenue)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(n > 0 ? Color.bhMentheFond : Color.bhAttenue.opacity(0.12)))
                }
            }
        }
        .padding(.vertical, 14)
    }

    // MARK: - Barre d'action

    @ViewBuilder
    private func actionBar(_ inv: OwnerInvoiceDetail) -> some View {
        let status    = inv.status ?? ""
        let isRunning = vm.actionState == .running
        let hasEmail  = !(inv.clientEmail ?? "").isEmpty

        if status == "draft" || status == "invoiced" || status == "sent" {
            VStack(spacing: 6) {
                switch status {
                case "draft":
                    PrimaryButton(title: "Valider la facture") {
                        showFinalizeConfirm = true
                    }
                    .disabled(isRunning)
                    .opacity(isRunning ? 0.55 : 1)

                    Button {
                        showSendConfirm = true
                    } label: {
                        Text("Envoyer")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(hasEmail ? Color.bhVert : Color.bhAttenue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .disabled(isRunning || !hasEmail)

                    if !hasEmail {
                        Text("Aucune adresse email pour ce client")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.bhAttenue)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Group {
                            if isRunning {
                                ProgressView().tint(Color.bhTerracotta).scaleEffect(0.8)
                            } else {
                                Text("Supprimer")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.bhTerracotta)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .disabled(isRunning)

                case "invoiced":
                    PrimaryButton(title: "Envoyer") {
                        showSendConfirm = true
                    }
                    .disabled(isRunning || !hasEmail)
                    .opacity((isRunning || !hasEmail) ? 0.55 : 1)

                    if !hasEmail {
                        Text("Aucune adresse email pour ce client")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.bhAttenue)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Button {
                        Task { await doMarkPaid() }
                    } label: {
                        Text("Marquer payée")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.bhVert)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .disabled(isRunning)

                default: // "sent"
                    PrimaryButton(title: "Marquer payée") {
                        Task { await doMarkPaid() }
                    }
                    .disabled(isRunning)
                    .opacity(isRunning ? 0.55 : 1)
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
    }

    // MARK: - Actions

    private func doFinalize() async {
        let ok = await vm.finalize()
        if ok {
            onChanged?()
        } else if case .error(let msg) = vm.actionState {
            actionError = msg
            vm.actionState = .idle
        }
    }

    private func doSend() async {
        let ok = await vm.send()
        if ok {
            onChanged?()
        } else if case .error(let msg) = vm.actionState {
            actionError = msg
            vm.actionState = .idle
        }
    }

    private func doMarkPaid() async {
        let ok = await vm.markPaid()
        if ok {
            onChanged?()
        } else if case .error(let msg) = vm.actionState {
            actionError = msg
            vm.actionState = .idle
        }
    }

    private func doDelete() async {
        let ok = await vm.delete()
        if ok {
            onChanged?()
            dismiss()
        } else if case .error(let msg) = vm.actionState {
            actionError = msg
            vm.actionState = .idle
        }
    }

    // MARK: - Composants de ligne

    private func detailRow(_ label: String, value: String, separator: Bool = true) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Text(label)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.bhAttenue)
                    .padding(.top, 1)
                Spacer()
                Text(value.isEmpty ? "—" : value)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.bhEncre)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
            if separator {
                Rectangle().fill(Color.white.opacity(0.35)).frame(height: 0.5)
            }
        }
    }

    // MARK: - État erreur

    private func errorView(_ msg: String) -> some View {
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
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - PDF

    private func fetchPdf() async {
        isPdfLoading = true
        defer { isPdfLoading = false }
        do {
            let data = try await APIClient.shared.postData(
                Endpoint.ownerInvoicePdf(vm.invoiceId),
                agencyAll: true
            )
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("facture-\(vm.invoiceId).pdf")
            try data.write(to: tmp)
            pdfURL = tmp
        } catch {
            pdfError = (error as? APIError)?.userMessage
                ?? "Impossible de générer le PDF."
        }
    }

    // MARK: - Helpers

    private func formatDecimal(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(v))
            : String(format: "%.2f", v)
    }

    private func paymentModeLabel(_ v: String) -> String {
        switch v {
        case "virement":    return "Virement bancaire"
        case "cheque":      return "Chèque"
        case "especes":     return "Espèces"
        case "carte":       return "Carte bancaire"
        case "prelevement": return "Prélèvement automatique"
        default:            return v
        }
    }
}
