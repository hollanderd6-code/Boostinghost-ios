import SwiftUI

struct BoostPriceDetailView: View {
    let target: BoostPriceNavTarget

    @State private var vm: BoostPriceDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(target: BoostPriceNavTarget) {
        self.target = target
        self._vm = State(initialValue: BoostPriceDetailViewModel(
            propertyId:      target.propertyId,
            propertyName:    target.propertyName,
            externalPricing: target.externalPricing
        ))
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                navBar

                switch vm.loadState {
                case .idle, .loading:
                    Spacer()
                    ProgressView()
                    Spacer()
                case .error(let msg):
                    errorView(msg)
                case .loaded:
                    loadedContent
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { await vm.load() }
        .onChange(of: vm.actionState) { _, new in
            if case .success(_) = new {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    if case .success(_) = vm.actionState { vm.actionState = .idle }
                }
            }
        }
    }

    // MARK: - Nav bar

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
                Text("BoostPrice")
                    .font(.bhSurTitre)
                    .foregroundStyle(Color.bhAttenue)
                Text(target.propertyName)
                    .bhGrandTitre()
                    .lineLimit(1)
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

    // MARK: - Error

    @ViewBuilder
    private func errorView(_ msg: String) -> some View {
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
    }

    // MARK: - Loaded content

    private var loadedContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                statusCard
                if target.externalPricing {
                    externalPricingBanner
                } else {
                    activationSection
                    if vm.isActive {
                        modeSection
                        priceRangeSection
                        strategySection
                    }
                    if vm.hasPendingSuggestion {
                        pendingSuggestionCard
                    }
                    if let market = vm.dashProp?.market {
                        marketContextCard(market)
                    }
                    if vm.isActive && !target.externalPricing {
                        saveButton
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 48)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await vm.load() }
    }

    // MARK: - Status card

    private var statusCard: some View {
        ListCard {
            HStack(spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(statusIconColor)
                    .frame(width: 48, height: 48)
                    .background(statusIconBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.currentStatusLabel)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                    if let min = vm.config?.priceMin, let max = vm.config?.priceMax,
                       min > 0, max > 0 {
                        Text("\(Formatters.amount(min, currency: vm.currency)) – \(Formatters.amount(max, currency: vm.currency))")
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhAttenue)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("BoostPrice : \(vm.currentStatusLabel)")
    }

    private var statusIconColor: Color {
        if target.externalPricing                  { return Color.bhBleu }
        if !vm.isActive                            { return Color.bhAttenue }
        return Color.bhOccupe
    }

    private var statusIconBg: Color {
        if target.externalPricing { return Color.bhBleuFond }
        if !vm.isActive           { return Color.white.opacity(0.45) }
        return Color(hex: "#DCE8E1")
    }

    // MARK: - External pricing banner

    private var externalPricingBanner: some View {
        ListCard {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.bhBleu)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Tarification externe active")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                    Text("Les prix de ce logement sont gérés par un outil tiers. BoostPrice est désactivé.")
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .accessibilityLabel("Tarification externe active. BoostPrice est désactivé pour ce logement.")
    }

    // MARK: - Activation toggle

    private var activationSection: some View {
        ListCard {
            CardRow(showSeparator: false) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BoostPrice actif")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.bhEncre)
                        Text("Active ou désactive la tarification dynamique")
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhAttenue)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { vm.isActive },
                        set: { vm.isActive = $0; vm.markDirty() }
                    ))
                    .tint(Color.bhOccupe)
                    .accessibilityLabel("Activer BoostPrice")
                }
            }
        }
    }

    // MARK: - Mode selector

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Mode de fonctionnement")

            ListCard {
                VStack(spacing: 0) {
                    modeRow(
                        title: "Automatique",
                        subtitle: "Les prix sont appliqués sans intervention",
                        icon: "bolt.fill",
                        isSelected: vm.selectedMode == .auto,
                        isLast: false
                    ) {
                        vm.selectedMode = .auto
                        vm.markDirty()
                    }
                    modeRow(
                        title: "Sur recommandation",
                        subtitle: "Vous approuvez chaque ajustement de prix",
                        icon: "hand.raised.fill",
                        isSelected: vm.selectedMode != .auto,
                        isLast: true
                    ) {
                        vm.selectedMode = .manual
                        vm.markDirty()
                    }
                }
            }
        }
    }

    private func modeRow(
        title: String,
        subtitle: String,
        icon: String,
        isSelected: Bool,
        isLast: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            CardRow(showSeparator: !isLast) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? Color.bhOccupeFonce : Color.bhAttenue)
                        .frame(width: 32, height: 32)
                        .background(
                            isSelected ? Color.bhMentheFond : Color.white.opacity(0.35),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(Color.bhEncre)
                        Text(subtitle)
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhAttenue)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.bhOccupeFonce)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel("\(title). \(subtitle).\(isSelected ? " Sélectionné." : "")")
    }

    // MARK: - Price range

    private var priceRangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Fourchette de prix")

            ListCard {
                VStack(spacing: 0) {
                    priceField(
                        label: "Prix minimum",
                        placeholder: "ex : 60",
                        text: Binding(
                            get: { vm.priceMinText },
                            set: { vm.priceMinText = $0; vm.priceMinError = nil; vm.markDirty() }
                        ),
                        error: vm.priceMinError,
                        isLast: false
                    )
                    priceField(
                        label: "Prix maximum",
                        placeholder: "ex : 180",
                        text: Binding(
                            get: { vm.priceMaxText },
                            set: { vm.priceMaxText = $0; vm.priceMaxError = nil; vm.markDirty() }
                        ),
                        error: vm.priceMaxError,
                        isLast: true
                    )
                }
            }
        }
    }

    private func priceField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        error: String?,
        isLast: Bool
    ) -> some View {
        CardRow(showSeparator: !isLast) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.bhEncreDouce)
                    Spacer()
                    HStack(spacing: 4) {
                        TextField(placeholder, text: text)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.bhEncre)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(vm.currency)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.bhAttenue)
                    }
                }
                if let error {
                    Text(error)
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhTerracotta)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label)\(error != nil ? ", erreur : \(error!)" : "")")
    }

    // MARK: - Strategy slider

    private var strategySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Stratégie de prix")

            ListCard {
                CardRow(showSeparator: false) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Stratégie")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.bhEncreDouce)
                            Spacer()
                            Text(vm.strategyLabel)
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhAttenue)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(vm.strategy) },
                                set: { vm.strategy = Int($0.rounded()); vm.markDirty() }
                            ),
                            in: 0...100,
                            step: 1
                        )
                        .tint(Color.bhOccupe)
                        .accessibilityLabel("Stratégie de prix : \(vm.strategyLabel)")
                        .accessibilityValue("\(vm.strategy) sur 100")

                        HStack {
                            Text("Occupation")
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhAttenue)
                            Spacer()
                            Text("Revenu")
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhAttenue)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Pending suggestion card

    private var pendingSuggestionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Recommandation en attente")

            ListCard {
                VStack(spacing: 0) {
                    CardRow(showSeparator: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(Color.bhOr)
                                Text("Suggestion de prix")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.bhEncre)
                                StatusPill(text: "En attente", style: .or)
                            }

                            if let item = vm.pendingHistoryItem {
                                HStack(spacing: 16) {
                                    if let before = item.priceBefore {
                                        priceChange(label: "Avant", value: before)
                                    }
                                    if let calc = item.priceCalculated {
                                        priceChange(label: "Suggéré", value: calc)
                                    }
                                }

                                if let reason = item.reason, !reason.isEmpty {
                                    Text(reason)
                                        .font(.bhMeta)
                                        .foregroundStyle(Color.bhAttenue)
                                }

                                factorsView(item)
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            Task { await vm.declineSuggestion() }
                        } label: {
                            Text("Refuser")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.bhAttenue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(actionIsWorking)
                        .accessibilityLabel("Refuser la suggestion de prix")

                        Button {
                            Task { await vm.acceptSuggestion() }
                        } label: {
                            Text("Appliquer")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.bhOccupeFonce, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(actionIsWorking)
                        .accessibilityLabel("Appliquer la suggestion de prix")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func priceChange(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
            Text(Formatters.amount(value, currency: vm.currency))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bhEncre)
        }
    }

    @ViewBuilder
    private func factorsView(_ item: DynamicPricingHistoryItem) -> some View {
        let factors: [(name: String, value: Double, key: String)] = [
            ("Marché",      item.factorMarket  ?? 1.0, "market"),
            ("Historique",  item.factorSelf    ?? 1.0, "self"),
            ("Saisonnalité", item.factorSeason ?? 1.0, "season"),
        ].filter { abs($0.value - 1.0) > 0.01 }

        if !factors.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(factors, id: \.key) { f in
                    HStack(spacing: 6) {
                        Image(systemName: f.value > 1 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .foregroundStyle(f.value > 1 ? Color.bhOccupeFonce : Color.bhTerracotta)
                            .imageScale(.small)
                        Text(boostPriceFactorLabel(value: f.value, factor: f.key))
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhEncreDouce)
                    }
                }
            }
        }
    }

    // MARK: - Market context card

    private func marketContextCard(_ market: DynamicPricingMarket) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Contexte marché")

            ListCard {
                VStack(spacing: 0) {
                    if let label = market.tensionLabel, !label.isEmpty {
                        CardRow(showSeparator: true) {
                            HStack {
                                Text("Tension")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.bhAttenue)
                                Spacer()
                                Text(label)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(tensionColor(market.tensionLevel))
                            }
                        }
                        .accessibilityLabel("Tension du marché : \(label)")
                    }
                    if let median = market.medianPrice, median > 0 {
                        CardRow(showSeparator: true) {
                            HStack {
                                Text("Prix médian")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.bhAttenue)
                                Spacer()
                                Text(Formatters.amount(median, currency: vm.currency))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.bhEncre)
                            }
                        }
                        .accessibilityLabel("Prix médian du marché : \(Formatters.amount(median, currency: vm.currency))")
                    }
                    if let p25 = market.priceP25, let p75 = market.priceP75,
                       p25 > 0, p75 > 0 {
                        CardRow(showSeparator: market.occupancyRate != nil) {
                            HStack {
                                Text("Fourchette")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.bhAttenue)
                                Spacer()
                                Text("\(Formatters.amount(p25, currency: vm.currency)) – \(Formatters.amount(p75, currency: vm.currency))")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.bhEncre)
                            }
                        }
                        .accessibilityLabel("Fourchette de marché : \(Formatters.amount(p25, currency: vm.currency)) à \(Formatters.amount(p75, currency: vm.currency))")
                    }
                    if let occ = market.occupancyRate, occ > 0 {
                        CardRow(showSeparator: false) {
                            HStack {
                                Text("Taux d'occupation")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.bhAttenue)
                                Spacer()
                                Text("\(Int((occ * 100).rounded())) %")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.bhEncre)
                            }
                        }
                        .accessibilityLabel("Taux d'occupation : \(Int((occ * 100).rounded())) pourcent")
                    }
                }
            }
        }
    }

    private func tensionColor(_ level: String?) -> Color {
        switch level {
        case "high":   return Color.bhOccupeFonce
        case "medium": return Color.bhOrClair
        case "low":    return Color.bhAttenue
        default:       return Color.bhEncre
        }
    }

    // MARK: - Save button

    private var saveButton: some View {
        VStack(spacing: 8) {
            if case .error(let msg) = vm.actionState {
                Text(msg)
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhTerracotta)
                    .multilineTextAlignment(.center)
            }
            if case .success(let msg) = vm.actionState {
                Text(msg)
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhOccupeFonce)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await vm.save() }
            } label: {
                HStack(spacing: 8) {
                    if actionIsWorking {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(actionIsWorking ? "Enregistrement…" : "Enregistrer")
                        .font(.system(size: 16.5, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.bhVert, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(actionIsWorking || !vm.isDirty)
            .opacity(vm.isDirty ? 1 : 0.5)
            .accessibilityLabel(actionIsWorking ? "Enregistrement en cours" : "Enregistrer la configuration")
        }
    }

    private var actionIsWorking: Bool {
        if case .working = vm.actionState { return true }
        return false
    }
}
