import SwiftUI

struct BoostPriceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = BoostPriceViewModel()

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                navBar
                contentArea
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { await vm.load() }
    }

    // MARK: - Navigation bar

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
                Text("Tarification dynamique")
                    .font(.bhSurTitre)
                    .foregroundStyle(Color.bhAttenue)
                Text("BoostPrice")
                    .bhGrandTitre()
            }
            .padding(.leading, 12)

            Spacer(minLength: 12)
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

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        switch vm.loadState {
        case .idle, .loading:
            Spacer()
            ProgressView()
            Spacer()
        case .error(let msg):
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.bhAttenue)
                Text(msg)
                    .font(.bhCorps)
                    .foregroundStyle(Color.bhAttenue)
                    .multilineTextAlignment(.center)
                Button("Réessayer") { Task { await vm.load() } }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
            }
            .padding(.horizontal, 24)
            Spacer()
        case .loaded:
            loadedContent
        }
    }

    private var loadedContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if vm.rows.isEmpty {
                    emptyState
                } else {
                    descriptionText
                    propertiesList
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .refreshable { await vm.load() }
    }

    private var descriptionText: some View {
        Text("Vos logements avec tarification dynamique activée.")
            .font(.bhCorps)
            .foregroundStyle(Color.bhAttenue)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.slash")
                .font(.system(size: 36))
                .foregroundStyle(Color.bhAttenue)
            Text("Aucun logement configuré")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.bhEncre)
            Text("Activez BoostPrice depuis l'interface web pour commencer.")
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var propertiesList: some View {
        ListCard {
            ForEach(Array(vm.rows.enumerated()), id: \.element.id) { idx, row in
                NavigationLink(value: BoostPriceNavTarget(
                    propertyId: row.id,
                    propertyName: row.name,
                    externalPricing: row.status == .externalPricing
                )) {
                    CardRow(showSeparator: idx < vm.rows.count - 1) {
                        propertyRow(row)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationDestination(for: BoostPriceNavTarget.self) { target in
            BoostPriceDetailView(target: target)
        }
    }

    // MARK: - Property row

    private func propertyRow(_ row: BoostPricePropertyRow) -> some View {
        HStack(spacing: 14) {
            iconView(for: row.status)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    statusPill(for: row.status)
                    if row.pendingSuggestions > 0 {
                        StatusPill(
                            text: "\(row.pendingSuggestions) suggestion\(row.pendingSuggestions > 1 ? "s" : "")",
                            style: .or
                        )
                    }
                }

                if let min = row.priceMin, let max = row.priceMax {
                    Text("\(Formatters.amount(min, currency: row.currency)) – \(Formatters.amount(max, currency: row.currency))")
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bhAttenue.opacity(0.55))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: row))
    }

    private func iconView(for status: BoostPriceStatus) -> some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(iconForeground(for: status))
            .frame(width: 40, height: 40)
            .background(
                iconBackground(for: status),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
    }

    private func iconForeground(for status: BoostPriceStatus) -> Color {
        switch status {
        case .automatic, .suggestion, .active: return Color.bhOccupe
        case .inactive:                        return Color.bhAttenue
        case .externalPricing:                 return Color.bhBleu
        }
    }

    private func iconBackground(for status: BoostPriceStatus) -> Color {
        switch status {
        case .automatic, .suggestion, .active: return Color(hex: "#DCE8E1")
        case .inactive:                        return Color.white.opacity(0.45)
        case .externalPricing:                 return Color.bhBleuFond
        }
    }

    private func statusPill(for status: BoostPriceStatus) -> some View {
        switch status {
        case .automatic:
            return StatusPill(text: "Automatique", style: .vert, icon: "bolt.fill")
        case .suggestion:
            return StatusPill(text: "Sur recommandation", style: .vert)
        case .active:
            return StatusPill(text: "BoostPrice actif", style: .vert)
        case .inactive:
            return StatusPill(text: "Inactif", style: .neutre)
        case .externalPricing:
            return StatusPill(text: "Tarification externe", style: .neutre)
        }
    }

    private func accessibilityLabel(for row: BoostPricePropertyRow) -> String {
        var parts = [row.name, statusLabel(for: row.status)]
        if let min = row.priceMin, let max = row.priceMax {
            parts.append("\(Formatters.amount(min, currency: row.currency)) à \(Formatters.amount(max, currency: row.currency))")
        }
        if row.pendingSuggestions > 0 {
            parts.append("\(row.pendingSuggestions) suggestion\(row.pendingSuggestions > 1 ? "s" : "") en attente")
        }
        return parts.joined(separator: ", ")
    }

    private func statusLabel(for status: BoostPriceStatus) -> String {
        switch status {
        case .automatic:       return "Automatique"
        case .suggestion:      return "Sur recommandation"
        case .active:          return "BoostPrice actif"
        case .inactive:        return "Inactif"
        case .externalPricing: return "Tarification externe"
        }
    }
}

