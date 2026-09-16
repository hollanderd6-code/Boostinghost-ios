import SwiftUI

// MARK: - Feuille de recherche globale

struct GlobalSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AuthStore.self) private var authStore

    @State private var vm = SearchViewModel()
    @State private var showExpiredAlert = false
    @FocusState private var searchFocused: Bool
    @State private var hasAutoFocused = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 0) {
                    header
                    contentArea
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SearchResultConversation.self) { result in
                ConversationDetailView(
                    conversation: Conversation(fromSearch: result),
                    ownerName: authStore.session?.displayName ?? ""
                )
            }
            .navigationDestination(for: SearchResultProperty.self) { result in
                SearchPropertyLoaderView(propertyId: result.id)
            }
            .navigationDestination(for: SearchResultOwnerInvoice.self) { result in
                OwnerInvoiceDetailView(invoiceId: result.id)
            }
            .navigationDestination(for: SearchResultOwnerClient.self) { result in
                OwnerClientDetailView(client: OwnerClient(fromSearch: result))
            }
            .navigationDestination(for: SearchResultReservation.self) { result in
                ReservationDetailView(arrivee: Arrivee(fromSearch: result))
            }
        }
        .task { vm.agencyAll = authStore.agencyAll }
        .alert("Lien expiré", isPresented: $showExpiredAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Ce lien de téléchargement n'est plus valide.")
        }
    }

    // MARK: - En-tête en verre

    private var header: some View {
        VStack(spacing: 0) {
            SheetHandle()

            HStack {
                Text("Recherche")
                    .bhGrandTitre()
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .imageScale(.medium)
                        .foregroundStyle(Color.bhEncre)
                        .frame(width: 38, height: 38)
                        .glassEffect(in: .circle)
                        .specularEdge(cornerRadius: 19)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            searchBar
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Champ de recherche

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.bhAttenue)
            TextField("Nom, logement, numéro de facture…", text: $vm.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($searchFocused)
                .onChange(of: vm.query) { vm.onQueryChange() }
            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.bhAttenue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            Color.white.opacity(0.55),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        }
        .onAppear {
            if !hasAutoFocused {
                searchFocused = true
                hasAutoFocused = true
            }
        }
    }

    // MARK: - Zone de contenu

    @ViewBuilder
    private var contentArea: some View {
        switch vm.state {
        case .idle:
            idleView
        case .searching:
            searchingView
        case .results(let r):
            resultsView(r)
        case .empty:
            emptyView
        case .error(let msg):
            errorView(msg)
        }
    }

    private var idleView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Color.bhAttenue)
            Text("Minimum 2 caractères")
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var searchingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Color.bhAttenue)
            Text("Aucun résultat")
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(Color.bhAttenue)
            Text(msg)
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Résultats groupés

    private func resultsView(_ r: SearchResults) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                if let items = r.reservations, !items.isEmpty {
                    searchSection(label: "Réservations") {
                        ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                            NavigationLink(value: item) {
                                CardRow(showSeparator: idx < items.count - 1) {
                                    reservationRow(item)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let items = r.conversations, !items.isEmpty {
                    searchSection(label: "Conversations") {
                        ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                            NavigationLink(value: item) {
                                CardRow(showSeparator: idx < items.count - 1) {
                                    conversationRow(item)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let items = r.properties, !items.isEmpty {
                    searchSection(label: "Logements") {
                        ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                            NavigationLink(value: item) {
                                CardRow(showSeparator: idx < items.count - 1) {
                                    propertyRow(item)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let items = r.ownerInvoices, !items.isEmpty {
                    searchSection(label: "Factures propriétaires") {
                        ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                            NavigationLink(value: item) {
                                CardRow(showSeparator: idx < items.count - 1) {
                                    ownerInvoiceRow(item)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let items = r.voyageurInvoices, !items.isEmpty {
                    searchSection(label: "Factures voyageurs") {
                        ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                            Button { openVoyageurInvoice(item) } label: {
                                CardRow(showSeparator: idx < items.count - 1) {
                                    voyageurInvoiceRow(item)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let items = r.ownerClients, !items.isEmpty {
                    searchSection(label: "Propriétaires") {
                        ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                            NavigationLink(value: item) {
                                CardRow(showSeparator: idx < items.count - 1) {
                                    ownerClientRow(item)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Conteneur de section

    private func searchSection<Content: View>(
        label: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: label)
            ListCard { content() }
        }
    }

    // MARK: - Lignes de résultats

    private func reservationRow(_ r: SearchResultReservation) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(r.guestName ?? "Voyageur")
                    .font(.bhTitreLigne)
                    .foregroundStyle(Color.bhEncre)
                if let start = r.startDate, let end = r.endDate {
                    Text(dateRange(start, end))
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                }
            }
            Spacer()
            if let platform = r.platform {
                PlatformBadge(platform: platform)
            }
        }
    }

    private func conversationRow(_ c: SearchResultConversation) -> some View {
        HStack {
            Text(c.guestName ?? "Voyageur")
                .font(.bhTitreLigne)
                .foregroundStyle(Color.bhEncre)
            Spacer()
            if let platform = c.platform {
                PlatformBadge(platform: platform)
            }
        }
    }

    private func propertyRow(_ p: SearchResultProperty) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(p.name ?? p.internalName ?? "Logement")
                    .font(.bhTitreLigne)
                    .foregroundStyle(Color.bhEncre)
                if let internal_name = p.internalName, p.name != nil && p.name != p.internalName {
                    Text(internal_name)
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bhAttenue.opacity(0.55))
        }
    }

    private func ownerInvoiceRow(_ inv: SearchResultOwnerInvoice) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(inv.invoiceNumber ?? "Facture")
                        .font(.bhTitreLigne)
                        .foregroundStyle(Color.bhEncre)
                    if let status = inv.status {
                        StatusPill(text: invoiceStatusLabel(status), style: invoiceStatusStyle(status))
                    }
                }
                if let client = inv.clientName {
                    Text(client)
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                }
            }
            Spacer()
            if let total = inv.totalTtc {
                Text(Formatters.amount(total))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.bhAttenue)
            }
        }
    }

    private func voyageurInvoiceRow(_ inv: SearchResultVoyageurInvoice) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(inv.invoiceNumber ?? "Facture")
                        .font(.bhTitreLigne)
                        .foregroundStyle(inv.expired == true ? Color.bhAttenue : Color.bhEncre)
                    if inv.expired == true {
                        StatusPill(text: "Expiré", style: .neutre)
                    }
                }
                if let client = inv.clientName {
                    Text(client)
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                }
            }
            Spacer()
            Image(systemName: inv.expired == true ? "xmark.circle" : "arrow.down.circle")
                .foregroundStyle(inv.expired == true ? Color.bhAttenue : Color.bhVert)
        }
    }

    private func ownerClientRow(_ c: SearchResultOwnerClient) -> some View {
        HStack(spacing: 12) {
            Text(c.initials)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bhVert)
                .frame(width: 38, height: 38)
                .background(Color(hex: "#DCE8E1"), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(c.displayName)
                    .font(.bhTitreLigne)
                    .foregroundStyle(Color.bhEncre)
                if let email = c.email, !email.isEmpty {
                    Text(email)
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bhAttenue.opacity(0.55))
        }
    }

    // MARK: - Actions

    private func openVoyageurInvoice(_ inv: SearchResultVoyageurInvoice) {
        if inv.expired == true {
            showExpiredAlert = true
            return
        }
        if let urlString = inv.downloadUrl, let url = URL(string: urlString) {
            openURL(url)
        }
    }

    // MARK: - Formatage

    private func dateRange(_ start: String, _ end: String) -> String {
        let iso = DateFormatter()
        iso.locale   = Locale(identifier: "en_US_POSIX")
        iso.dateFormat = "yyyy-MM-dd"
        iso.timeZone = TimeZone(identifier: "Europe/Paris")
        let display  = DateFormatter()
        display.locale = Locale(identifier: "fr_FR")
        display.dateFormat = "d MMM"
        guard let s = iso.date(from: String(start.prefix(10))),
              let e = iso.date(from: String(end.prefix(10))) else {
            return "\(start) → \(end)"
        }
        return "\(display.string(from: s)) → \(display.string(from: e))"
    }

    private func invoiceStatusLabel(_ status: String) -> String {
        switch status {
        case "draft": return "Brouillon"
        case "sent":  return "Envoyée"
        case "paid":  return "Payée"
        default:      return status
        }
    }

    private func invoiceStatusStyle(_ status: String) -> PillStyle {
        switch status {
        case "paid": return .vert
        default:     return .neutre
        }
    }
}

// MARK: - Chargeur de fiche logement

struct SearchPropertyLoaderView: View {
    let propertyId: String
    @Environment(AuthStore.self) private var authStore
    @State private var property: Property? = nil
    @State private var errorMessage: String? = nil
    @State private var propertiesVM = PropertiesViewModel()

    var body: some View {
        ZStack {
            AppBackground()
            if let property {
                PropertyDetailView(property: property, vm: propertiesVM)
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.bhAttenue)
                    Text(errorMessage)
                        .font(.bhCorps)
                        .foregroundStyle(Color.bhAttenue)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            let fetched: Property = try await APIClient.shared.get(
                Endpoint.property(propertyId),
                agencyAll: true
            )
            property = fetched
        } catch {
            errorMessage = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }
}
