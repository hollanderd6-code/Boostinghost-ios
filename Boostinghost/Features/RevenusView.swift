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

    var body: some View {
        LazyVStack(spacing: 12) {
            GrossCard(summary: data.summary)
            NetCard(summary: data.summary)
            IndicatorsGrid(summary: data.summary)

            if let platforms = data.platforms, !platforms.isEmpty {
                PlatformsCard(platforms: platforms)
            }
            if let byProp = data.byProperty, !byProp.isEmpty {
                TopPropertiesCard(properties: Array(byProp.sorted { $0.grossRevenue > $1.grossRevenue }.prefix(4)))
            }

            ExportRow(vm: vm, data: data)

            Color.clear.frame(height: 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - 1. CA brut (carte héro)

private struct GrossCard: View {
    let summary: ReportingSummary

    var body: some View {
        ListCard(heroFill: true) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "CA brut")
                    .padding(.bottom, 2)
                Text(Formatters.amount(summary.totalGrossRevenue))
                    .bhValeurHero()
                Text("dont \(Formatters.amount(summary.totalCleaningFee)) ménage · \(Formatters.amount(summary.totalTouristTax)) taxe de séjour")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
                if summary.pendingGrossRevenue > 0 {
                    Text("dont \(summary.pendingBookings) réservation\(summary.pendingBookings > 1 ? "s" : "") en attente d'approbation · \(Formatters.amount(summary.pendingGrossRevenue))")
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

    var body: some View {
        ListCard(heroFill: true) {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Revenu net")
                    .padding(.bottom, 2)
                Text(Formatters.amount(summary.totalNetRevenue))
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

    private func subBlock(label: String, amount: Double,
                          background: Color, textColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textColor.opacity(0.65))
            Text(Formatters.amount(amount))
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

    private var avgPerNight: String {
        guard summary.totalNights > 0 else { return "—" }
        return Formatters.amount(summary.totalGrossRevenue / Double(summary.totalNights))
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
        ) {
            IndicatorTile(label: "Réservations",    value: "\(summary.totalBookings)")
            IndicatorTile(label: "Nuits louées",    value: "\(summary.totalNights)")
            IndicatorTile(label: "Commissions OTA", value: Formatters.amount(summary.totalOtaCommission),
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

    var body: some View {
        ListCard {
            VStack(spacing: 0) {
                CardRow(verticalPadding: 10, showSeparator: true) {
                    SectionLabel(text: "Par plateforme")
                }
                ForEach(Array(platforms.enumerated()), id: \.element.id) { idx, stat in
                    CardRow(showSeparator: idx < platforms.count - 1) {
                        PlatformStatRow(stat: stat)
                    }
                }
            }
        }
    }
}

private struct PlatformStatRow: View {
    let stat: PlatformRevenuStat

    private var isPendingOnly: Bool { stat.revenue == 0 && stat.pendingRevenue > 0 }

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
                        Text(Formatters.amount(stat.pendingRevenue))
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(Color.bhOr)
                        Text("en attente")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.bhOr.opacity(0.75))
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Formatters.amount(stat.revenue))
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
                            Text(Formatters.amount(prop.grossRevenue))
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

    private var exportText: String {
        let s = data.summary
        let avg = s.totalNights > 0
            ? Formatters.amount(s.totalGrossRevenue / Double(s.totalNights))
            : "—"
        return """
        Rapport \(vm.monthTitle)
        CA brut : \(Formatters.amount(s.totalGrossRevenue))
          dont ménage : \(Formatters.amount(s.totalCleaningFee))
          dont taxe de séjour : \(Formatters.amount(s.totalTouristTax))
        Revenu net : \(Formatters.amount(s.totalNetRevenue))
          Conciergerie : \(Formatters.amount(s.totalConcierge))
          Propriétaires : \(Formatters.amount(s.totalOwnerRevenue))
        Réservations : \(s.totalBookings)
        Nuits louées : \(s.totalNights)
        Commissions OTA : \(Formatters.amount(s.totalOtaCommission))
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
