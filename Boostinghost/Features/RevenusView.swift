import SwiftUI

// MARK: - Vue principale Revenus

struct RevenusView: View {
    var vm: CalendarViewModel

    var body: some View {
        Group {
            switch vm.reportingState {
            case .idle, .loading:
                ProgressView()
                    .padding(.top, 80)
                    .tint(Color.bhVert)

            case .error(let msg):
                ContentUnavailableView(msg, systemImage: "wifi.exclamationmark")
                    .padding(.top, 60)

            case .loaded:
                if let data = vm.reportingData {
                    RevenusContent(data: data, vm: vm)
                }
            }
        }
        .task { await vm.loadReporting() }
        .onChange(of: vm.selectedMonthKey) {
            vm.clearReporting()
            Task { await vm.loadReporting() }
        }
        .onChange(of: vm.displayMode) {
            vm.clearReporting()
            Task { await vm.loadReporting() }
        }
    }
}

// MARK: - Contenu (visible uniquement à l'état .loaded)

private struct RevenusContent: View {
    let data: ReportingResponse
    var vm:   CalendarViewModel

    private var currencyState: ReportingCurrencyState {
        ReportingCurrencyState(summary: data.summary)
    }

    var body: some View {
        LazyVStack(spacing: 12) {
            if case .mixed(let codes) = currencyState {
                MixedCurrencyBanner(currencies: codes)
            }
            GrossCard(summary: data.summary, currencyState: currencyState)
            NetCard(summary: data.summary, currencyState: currencyState)
            IndicatorsGrid(summary: data.summary, currencyState: currencyState)

            if let platforms = data.platforms, !platforms.isEmpty {
                PlatformsCard(platforms: platforms, currencyState: currencyState)
            }
            if let byProp = data.byProperty, !byProp.isEmpty {
                TopPropertiesCard(
                    properties: Array(byProp.sorted { $0.grossRevenue > $1.grossRevenue }.prefix(4)),
                    currencyState: currencyState
                )
            }

            ExportRow(vm: vm, data: data, currencyState: currencyState)

            Color.clear.frame(height: 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Bannière devises mixtes

private struct MixedCurrencyBanner: View {
    let currencies: [String]

    var body: some View {
        ListCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.bhOr)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Devises mixtes (\(currencies.joined(separator: ", ")))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                    Text("Les montants couvrent plusieurs devises et ne peuvent pas être comparés.")
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }
}

// MARK: - 1. CA brut (carte héro)

private struct GrossCard: View {
    let summary: ReportingSummary
    let currencyState: ReportingCurrencyState

    var body: some View {
        ListCard(heroFill: true) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "CA brut")
                    .padding(.bottom, 2)
                Text(currencyState.format(summary.totalGrossRevenue))
                    .bhValeurHero()
                Text("dont \(currencyState.format(summary.totalCleaningFee)) ménage · \(currencyState.format(summary.totalTouristTax)) taxe de séjour")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
                if let pendingGross = summary.pendingGrossRevenue, pendingGross > 0 {
                    Text("dont \(summary.pendingBookings) réservation\(summary.pendingBookings > 1 ? "s" : "") en attente d'approbation · \(currencyState.format(pendingGross))")
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhOr)
                }
                Text("Revenus à la date d'encaissement · Booking après le checkout, Airbnb après le check-in.")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
                    .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 2. Revenu net (carte héro + deux sous-blocs)

private struct NetCard: View {
    let summary: ReportingSummary
    let currencyState: ReportingCurrencyState

    var body: some View {
        ListCard(heroFill: true) {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Revenu net")
                    .padding(.bottom, 2)
                Text(currencyState.format(summary.totalNetRevenue))
                    .bhValeurHero(color: .bhVert)

                HStack(spacing: 10) {
                    subBlock(
                        label:      "Conciergerie",
                        amount:     summary.totalConcierge,
                        background: Color.bhMentheFond,
                        textColor:  Color.bhOccupeFonce
                    )
                    subBlock(
                        label:      "Propriétaires",
                        amount:     summary.totalOwnerRevenue,
                        background: Color.white.opacity(0.55),
                        textColor:  Color.bhEncre
                    )
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func subBlock(label: String, amount: Double?,
                          background: Color, textColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textColor.opacity(0.65))
            Text(currencyState.format(amount))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - 3. Quatre indicateurs (grille 2×2)

private struct IndicatorsGrid: View {
    let summary: ReportingSummary
    let currencyState: ReportingCurrencyState

    private var avgPerNight: String {
        guard let gross = summary.totalGrossRevenue, summary.totalNights > 0 else { return "—" }
        return currencyState.format(gross / Double(summary.totalNights))
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
        ) {
            IndicatorTile(label: "Réservations",    value: "\(summary.totalBookings)")
            IndicatorTile(label: "Nuits louées",    value: "\(summary.totalNights)")
            IndicatorTile(label: "Commissions OTA", value: currencyState.format(summary.totalOtaCommission),
                          valueColor: .bhTerracotta)
            IndicatorTile(label: "Moy. par nuit",  value: avgPerNight)
        }
    }
}

private struct IndicatorTile: View {
    let label:      String
    let value:      String
    var valueColor: Color = .bhEncre

    var body: some View {
        ListCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 4. Répartition par plateforme

private struct PlatformsCard: View {
    let platforms: [PlatformRevenuStat]
    let currencyState: ReportingCurrencyState

    var body: some View {
        ListCard {
            VStack(spacing: 0) {
                CardRow(verticalPadding: 10, showSeparator: true) {
                    SectionLabel(text: "Par plateforme")
                }
                ForEach(Array(platforms.enumerated()), id: \.element.id) { idx, stat in
                    CardRow(showSeparator: idx < platforms.count - 1) {
                        PlatformStatRow(stat: stat, currencyState: currencyState)
                    }
                }
            }
        }
    }
}

private struct PlatformStatRow: View {
    let stat: PlatformRevenuStat
    let currencyState: ReportingCurrencyState

    private var isPendingOnly: Bool { (stat.revenue ?? 0) == 0 && stat.pendingRevenue > 0 }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.platform(stat.name))
                    .frame(width: 8, height: 8)
                Text(Color.platformLabel(stat.name))
                    .font(.system(size: 14.5))
                    .foregroundStyle(Color.bhEncre)
                Spacer()
                if isPendingOnly {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(currencyState.format(stat.pendingRevenue))
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(Color.bhOr)
                        Text("en attente")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.bhOr.opacity(0.75))
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(currencyState.format(stat.revenue))
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(Color.bhEncre)
                        Text("\(Int(stat.pct.rounded())) %")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.bhAttenue)
                    }
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.platform(stat.name).opacity(0.18))
                        .frame(height: 6)
                    if !isPendingOnly {
                        Capsule()
                            .fill(Color.platform(stat.name))
                            .frame(width: max(6, geo.size.width * stat.pct / 100), height: 6)
                    }
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - 5. Meilleurs logements (4 premiers)

private struct TopPropertiesCard: View {
    let properties: [PropertyRevenuStat]
    let currencyState: ReportingCurrencyState

    var body: some View {
        ListCard {
            VStack(spacing: 0) {
                CardRow(verticalPadding: 10, showSeparator: true) {
                    SectionLabel(text: "Meilleurs logements")
                }
                ForEach(Array(properties.enumerated()), id: \.element.id) { idx, prop in
                    CardRow(showSeparator: idx < properties.count - 1) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(prop.colorHex.map { Color(hex: $0) } ?? Color.bhVert)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(prop.name)
                                    .font(.system(size: 14.5, weight: .semibold))
                                    .foregroundStyle(Color.bhEncre)
                                Text("\(prop.nights) nuit\(prop.nights > 1 ? "s" : "")")
                                    .font(.bhMeta)
                                    .foregroundStyle(Color.bhAttenue)
                            }
                            Spacer()
                            Text(currencyState.format(prop.grossRevenue))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.bhEncre)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 6. Export comptable

private struct ExportRow: View {
    var vm:   CalendarViewModel
    var data: ReportingResponse
    let currencyState: ReportingCurrencyState

    private var exportText: String {
        let s = data.summary
        let avg: String = {
            guard let gross = s.totalGrossRevenue, s.totalNights > 0 else { return "—" }
            return currencyState.format(gross / Double(s.totalNights))
        }()
        return """
        Rapport \(vm.monthTitle)
        CA brut : \(currencyState.format(s.totalGrossRevenue))
          dont ménage : \(currencyState.format(s.totalCleaningFee))
          dont taxe de séjour : \(currencyState.format(s.totalTouristTax))
        Revenu net : \(currencyState.format(s.totalNetRevenue))
          Conciergerie : \(currencyState.format(s.totalConcierge))
          Propriétaires : \(currencyState.format(s.totalOwnerRevenue))
        Réservations : \(s.totalBookings)
        Nuits louées : \(s.totalNights)
        Commissions OTA : \(currencyState.format(s.totalOtaCommission))
        Moy. par nuit : \(avg)
        """
    }

    var body: some View {
        ShareLink(item: exportText) {
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .imageScale(.medium)
                Text("Export comptable")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .imageScale(.small)
                    .foregroundStyle(Color.bhAttenue)
            }
            .foregroundStyle(Color.bhEncreDouce)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassEffect(in: .rect(cornerRadius: 15))
            .specularEdge(cornerRadius: 15)
        }
        .buttonStyle(.plain)
    }
}
