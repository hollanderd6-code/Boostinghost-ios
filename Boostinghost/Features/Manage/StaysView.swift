import SwiftUI

// MARK: - Segments

private enum StaysTab: Hashable {
    case cautions, factures
}

// MARK: - Écran Séjours

struct StaysView: View {
    @Environment(\.dismiss)   private var dismiss
    @State private var vm                        = DepositsViewModel()
    @State private var invoicesVm                = InvoicesViewModel()
    @State private var tab: StaysTab             = .cautions
    @State private var showExpired               = false
    @State private var selectedDeposit: ReservationWithDeposit? = nil
    @State private var selectedInvoice: Invoice? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                switch tab {
                case .cautions: cautionsContent
                case .factures: facturesContent
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            async let a: Void = vm.load()
            async let b: Void = invoicesVm.load()
            _ = await (a, b)
        }
        .sheet(item: $selectedDeposit) { dep in
            DepositDetailSheet(deposit: dep, vm: vm)
        }
        .sheet(item: $selectedInvoice) { inv in
            InvoiceDetailSheet(invoice: inv)
        }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        VStack(spacing: 0) {
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
                    Text(combinedSuperTitle)
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                    Text("Séjours")
                        .bhGrandTitre()
                }
                .padding(.leading, 12)

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 12)

            Picker("Vue séjours", selection: $tab) {
                Text(cautionsLabel).tag(StaysTab.cautions)
                Text(facturesLabel).tag(StaysTab.factures)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    private var combinedSuperTitle: String {
        let caut = vm.superTitle.trimmingCharacters(in: .whitespaces)
        return caut.isEmpty ? " " : caut
    }

    private var cautionsLabel: String {
        "Cautions · \(vm.activeCount)"
    }

    private var facturesLabel: String {
        guard case .loaded = invoicesVm.loadState else { return "Factures · —" }
        return "Factures · \(invoicesVm.invoiceCount)"
    }

    // MARK: - Contenu Cautions

    @ViewBuilder
    private var cautionsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                switch vm.loadState {
                case .idle, .loading:
                    loadingView
                case .error(let msg):
                    errorView(msg)
                case .loaded:
                    cautionsLoaded
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .refreshable { await vm.load() }
    }

    @ViewBuilder
    private var cautionsLoaded: some View {
        heroCard

        if !vm.toRelease.isEmpty {
            SectionLabel(text: "À RESTITUER")
            ForEach(vm.toRelease) { dep in
                toReleaseCard(dep)
            }
        }

        if !vm.inProgress.isEmpty {
            if !vm.toRelease.isEmpty {
                SectionLabel(text: "EN COURS")
            }
            inProgressCard
        }

        if !vm.expired.isEmpty {
            expiredSection
        }

        if vm.activeCount == 0 && vm.expired.isEmpty {
            emptyView
        }
    }

    // MARK: - Carte héro

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EMPREINTES EN COURS")
                .bhIntertitre()

            Text(Formatters.amount(vm.heroTotal))
                .bhValeurHero()
                .padding(.top, 2)

            Text("sur \(vm.heroSejourCount) séjour\(vm.heroSejourCount > 1 ? "s" : "")")
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background { GlassCardBackground(cornerRadius: 22, fillOpacity: 0.70) }
    }

    // MARK: - Carte urgente (à restituer) — ouvre la fiche au tap

    private func toReleaseCard(_ dep: ReservationWithDeposit) -> some View {
        Button { selectedDeposit = dep } label: {
            UrgentCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(dep.guestName ?? "Voyageur")
                            .font(.bhTitreLigneL)
                            .foregroundStyle(Color.bhEncre)
                        Spacer()
                        Text(dep.depositAmount.map { Formatters.amount($0) } ?? "—")
                            .font(.bhTitreLigneL)
                            .foregroundStyle(Color.bhEncre)
                    }

                    Text("\(dep.propertyName ?? "—") · \(dep.departurePrefix)")
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)

                    overdueLabel(dep)

                    if let label = dep.authExpiryLabel, !dep.expiresWithin48h {
                        Text(label)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.bhAttenue)
                    }

                    if dep.expiresWithin48h, let hours = dep.hoursUntilAuthExpiry {
                        expiryWarning(hours: hours)
                    }

                    HStack {
                        Spacer()
                        Text("Voir la fiche →")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.bhEncreDouce)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func overdueLabel(_ dep: ReservationWithDeposit) -> some View {
        let days = dep.overdueDays
        let label: String
        if days == 0 {
            label = "À restituer — délai dépassé"
        } else if days == 1 {
            label = "À restituer — délai dépassé de 1 jour"
        } else {
            label = "À restituer — délai dépassé de \(days) jours"
        }
        return Text(label)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.bhTerracotta)
    }

    private func expiryWarning(hours: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
            Text("expire dans \(hours) h — dernière chance de capturer")
                .font(.system(size: 12.5, weight: .medium))
        }
        .foregroundStyle(Color.bhTerracotta)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.bhTerracottaFond, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Carte empreintes en cours — chaque ligne ouvre la fiche

    private var inProgressCard: some View {
        ListCard {
            VStack(spacing: 0) {
                ForEach(Array(vm.inProgress.enumerated()), id: \.element.id) { idx, dep in
                    CardRow(showSeparator: idx < vm.inProgress.count - 1) {
                        Button { selectedDeposit = dep } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(dep.guestName ?? "Voyageur")
                                        .font(.bhTitreLigne)
                                        .foregroundStyle(Color.bhEncre)
                                    Text("\(dep.propertyName ?? "—") · \(dep.departurePrefix)")
                                        .font(.bhMeta)
                                        .foregroundStyle(Color.bhAttenue)
                                }
                                Spacer(minLength: 12)
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(dep.depositAmount.map { Formatters.amount($0) } ?? "—")
                                        .font(.bhTitreLigne)
                                        .foregroundStyle(Color.bhEncre)
                                    if let label = dep.authExpiryLabel {
                                        Text(label)
                                            .font(.system(size: 12))
                                            .foregroundStyle(dep.expiresWithin48h ? Color.bhTerracotta : Color.bhOccupeFonce)
                                    } else {
                                        Text("empreinte prise")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.bhOccupeFonce)
                                    }
                                    if dep.expiresWithin48h, let hours = dep.hoursUntilAuthExpiry {
                                        Text("dans \(hours) h")
                                            .font(.system(size: 11.5, weight: .medium))
                                            .foregroundStyle(Color.bhTerracotta)
                                    }
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.bhAttenue.opacity(0.55))
                                    .padding(.leading, 4)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Section expirées (repliée)

    private var expiredSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { showExpired.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text("EMPREINTES EXPIRÉES · \(vm.expiredCount)")
                        .bhIntertitre()
                    Spacer()
                    Text(Formatters.amount(vm.expiredTotal))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.bhAttenue)
                    Image(systemName: showExpired ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.bhAttenue)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if showExpired {
                ListCard {
                    VStack(spacing: 0) {
                        ForEach(Array(vm.expired.enumerated()), id: \.element.id) { idx, dep in
                            CardRow(showSeparator: idx < vm.expired.count - 1) {
                                Button { selectedDeposit = dep } label: {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(dep.guestName ?? "Voyageur")
                                                .font(.bhTitreLigne)
                                                .foregroundStyle(Color.bhEncre)
                                            Text(dep.propertyName ?? "—")
                                                .font(.bhMeta)
                                                .foregroundStyle(Color.bhAttenue)
                                        }
                                        Spacer(minLength: 12)
                                        Text(dep.depositAmount.map { Formatters.amount($0) } ?? "—")
                                            .font(.bhTitreLigne)
                                            .foregroundStyle(Color.bhAttenue)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color.bhAttenue.opacity(0.55))
                                            .padding(.leading, 4)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Contenu Factures

    @ViewBuilder
    private var facturesContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                switch invoicesVm.loadState {
                case .idle, .loading:
                    loadingView
                case .error(let msg):
                    errorView(msg)
                case .loaded:
                    facturesLoaded
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .refreshable { await invoicesVm.load() }
    }

    @ViewBuilder
    private var facturesLoaded: some View {
        if invoicesVm.all.isEmpty {
            emptyFacturesView
        } else {
            HStack(spacing: 8) {
                let n = invoicesVm.invoiceCount
                Text("HISTORIQUE · \(n) facture\(n > 1 ? "s" : "")")
                    .bhIntertitre()
                Spacer()
                if invoicesVm.historyTotal > 0 {
                    Text(Formatters.amount(invoicesVm.historyTotal))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.bhAttenue)
                }
            }
            invoicesListCard
        }
    }

    // MARK: - Liste des factures

    private var invoicesListCard: some View {
        ListCard {
            VStack(spacing: 0) {
                ForEach(Array(invoicesVm.all.enumerated()), id: \.element.id) { idx, inv in
                    CardRow(showSeparator: idx < invoicesVm.all.count - 1) {
                        Button { selectedInvoice = inv } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(inv.clientName ?? "Voyageur")
                                        .font(.bhTitreLigne)
                                        .foregroundStyle(Color.bhEncre)
                                    Text(inv.propertyName ?? "—")
                                        .font(.bhMeta)
                                        .foregroundStyle(Color.bhAttenue)
                                    if let period = invoicePeriod(inv) {
                                        Text(period)
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
                                    Text(inv.invoiceNumber ?? "—")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.bhAttenue)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.bhAttenue.opacity(0.55))
                                    .padding(.leading, 4)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - États intermédiaires (partagés)

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)
            ProgressView()
                .scaleEffect(1.2)
        }
        .frame(maxWidth: .infinity)
    }

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
            Button("Réessayer") {
                Task {
                    if tab == .cautions { await vm.load() }
                    else { await invoicesVm.load() }
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.bhVert)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 40)
            Text("Aucune empreinte active")
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyFacturesView: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 40)
            Text("Aucune facture")
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func invoicePeriod(_ inv: Invoice) -> String? {
        guard let ci = inv.checkinDate, let co = inv.checkoutDate else { return nil }
        return "du \(Formatters.day(ci)) au \(Formatters.day(co))"
    }
}
