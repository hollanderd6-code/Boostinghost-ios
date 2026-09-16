import SwiftUI

// MARK: - État de connexion (configuration)

private enum ConnectionState: Equatable {
    case ota, ical, otaAndICal, none

    init(_ property: Property) {
        let hasChannex = property.channexEnabled == true && property.channexPropertyId != nil
        let hasICal = property.icalUrls?.isEmpty == false
                   || (property.icalUrlsRaw.map { $0 != "[]" && !$0.isEmpty } ?? false)
        switch (hasChannex, hasICal) {
        case (true, true):   self = .otaAndICal
        case (true, false):  self = .ota
        case (false, true):  self = .ical
        case (false, false): self = .none
        }
    }

    var label: String {
        switch self {
        case .ota:        return "OTA"
        case .ical:       return "iCal"
        case .otaAndICal: return "OTA · iCal"
        case .none:       return "Non relié"
        }
    }

    var textColor: Color {
        switch self {
        case .ota, .otaAndICal: return .bhBleu
        case .ical:             return .bhOccupe
        case .none:             return .bhGrisCnx
        }
    }

    var backgroundColor: Color {
        switch self {
        case .ota, .otaAndICal: return .bhBleuFond
        case .ical:             return .bhMentheFond
        case .none:             return .bhGrisCnxFond
        }
    }

    var isConnected: Bool {
        switch self {
        case .none: return false
        default:    return true
        }
    }
}

// MARK: - Liste des logements

struct PropertiesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = PropertiesViewModel()
    @State private var showNewPropertySheet = false

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                mainContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(for: Property.self) { property in
            PropertyDetailView(property: property, vm: vm)
        }
        .sheet(isPresented: $showNewPropertySheet) {
            NewPropertySheet {
                Task { await vm.load() }
            }
        }
        .task { await vm.load() }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        VStack(spacing: 0) {
            ZStack {
                VStack(spacing: 2) {
                    Text(surtitre)
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                    Text("Logements")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                }
                HStack {
                    GlassCircleButton(icon: "chevron.left") { dismiss() }
                    Spacer()
                    GlassCircleButton(icon: "plus") { showNewPropertySheet = true }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 10)

            if case .loaded = vm.loadState {
                groupPills
                    .padding(.bottom, 12)
            }
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    private var surtitre: String {
        guard case .loaded = vm.loadState else { return " " }
        let n = vm.properties.count
        return "\(n) logement\(n == 1 ? "" : "s")"
    }

    // MARK: - Puces de groupe

    private var groupPills: some View {
        let chips: [ScrollableFilterBar.Chip] = {
            var result: [ScrollableFilterBar.Chip] = [
                .init(id: "__all__", filterId: nil, label: "Tous · \(vm.properties.count)")
            ]
            for group in vm.groups {
                result.append(.init(id: group.id, filterId: group.id,
                                    label: "\(group.name) · \(vm.count(for: group.id))"))
            }
            let ung = vm.ungroupedCount()
            if ung > 0 {
                result.append(.init(id: "__ungrouped__", filterId: "__ungrouped__",
                                    label: "Non groupés · \(ung)"))
            }
            return result
        }()

        return ScrollableFilterBar(
            chips: chips,
            selectedId: vm.selectedGroupId,
            style: .light,
            onSelect: { vm.selectedGroupId = $0 }
        )
    }

    // MARK: - Contenu principal

    @ViewBuilder
    private var mainContent: some View {
        switch vm.loadState {
        case .loading:
            VStack {
                Spacer()
                ProgressView().tint(Color.bhAttenue)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed:
            VStack {
                Spacer()
                Text("Impossible de charger les logements.")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded:
            if vm.filteredProperties.isEmpty {
                VStack {
                    Spacer()
                    Text("Aucun logement dans ce groupe.")
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(vm.problemProperties) { property in
                            problemCard(property)
                        }
                        if !vm.normalProperties.isEmpty {
                            normalCard
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .refreshable { await vm.load() }
            }
        }
    }

    // MARK: - Badge de connexion

    private func connectionBadge(_ state: ConnectionState) -> some View {
        Text(state.label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(state.textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(state.backgroundColor)
            }
    }

    // MARK: - Carte problème (individuelle)

    private func problemCard(_ property: Property) -> some View {
        let diffusion = vm.diffusionByProperty[property.id]
        let urgent = diffusion.map { !$0.vendable } ?? false
        let cnx = ConnectionState(property)

        return NavigationLink(value: property) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(urgent ? Color.bhTerracotta : Color.bhOrClair)
                    .frame(width: 4)

                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(property.internalName ?? property.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.bhEncre)
                            .lineLimit(1)
                        Text(propertySubline(property))
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.bhAttenue)
                            .lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        connectionBadge(cnx)
                        if cnx.isConnected {
                            Text(urgent ? "À compléter" : "Incomplète")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(urgent ? Color.bhTerracotta : Color.bhOr)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(urgent ? Color.bhTerracottaFond : Color.bhOrFond)
                                }
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.bhAttenue.opacity(0.55))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .background {
                GlassCardBackground(cornerRadius: 22, fillOpacity: 0.62)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        urgent ? Color.bhTerracottaBd
                               : Color(red: 201/255, green: 161/255, blue: 91/255).opacity(0.35),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Carte normale (liste de lignes)

    private var normalCard: some View {
        ListCard {
            ForEach(Array(vm.normalProperties.enumerated()), id: \.element.id) { idx, property in
                CardRow(showSeparator: idx < vm.normalProperties.count - 1) {
                    NavigationLink(value: property) {
                        propertyRow(property)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func propertyRow(_ property: Property) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(property.internalName ?? property.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(propertySubline(property))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.bhAttenue)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            connectionBadge(ConnectionState(property))

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bhAttenue.opacity(0.55))
        }
    }

    // MARK: - Sous-ligne de propriété

    private func propertySubline(_ property: Property) -> String {
        var parts: [String] = []
        if let name = vm.groupName(for: property) { parts.append(name) }
        if let a = Formatters.time(property.arrivalTime),
           let d = Formatters.time(property.departureTime) {
            parts.append("\(a) → \(d)")
        }
        if let dep = property.depositAmount, dep > 0 { parts.append("caution") }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}
