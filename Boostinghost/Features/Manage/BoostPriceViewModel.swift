import Foundation
import Observation

// MARK: - Property status

enum BoostPriceStatus: Comparable {
    case automatic       // mode == .auto && isActive
    case suggestion      // mode == .suggestion && isActive
    case active          // other mode && isActive
    case inactive        // isActive == false
    case externalPricing // externalPricing == true — overrides everything

    var sortOrder: Int {
        switch self {
        case .automatic:       return 0
        case .suggestion:      return 1
        case .active:          return 2
        case .inactive:        return 3
        case .externalPricing: return 4
        }
    }

    static func < (lhs: BoostPriceStatus, rhs: BoostPriceStatus) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Row model

struct BoostPricePropertyRow: Identifiable, Equatable {
    let id: String
    let name: String
    let currency: String
    let status: BoostPriceStatus
    let priceMin: Double?
    let priceMax: Double?
    let pendingSuggestions: Int
}

// MARK: - Row builder (free function — nonisolated, testable without async)

func buildBoostPriceRows(
    configs: [DynamicPricingConfig],
    dashboard: DynamicPricingDashboardResponse?,
    properties: [Property]
) -> [BoostPricePropertyRow] {
    let propById: [String: Property] = Dictionary(
        properties.compactMap { p in p.id.isEmpty ? nil : (p.id, p) },
        uniquingKeysWith: { first, _ in first }
    )
    let dashPropById: [String: DynamicPricingDashboardProperty] = Dictionary(
        (dashboard?.properties ?? []).map { ($0.propertyId, $0) },
        uniquingKeysWith: { first, _ in first }
    )

    let built = configs.map { config -> BoostPricePropertyRow in
        let prop     = propById[config.propertyId]
        let dashProp = dashPropById[config.propertyId]

        let currency = Formatters.normalizeCurrency(
            prop?.currency ?? dashProp?.propertyCurrency
        )

        let status: BoostPriceStatus
        if prop?.externalPricing == true {
            status = .externalPricing
        } else if config.isActive != true {
            status = .inactive
        } else {
            switch config.mode {
            case .auto:       status = .automatic
            case .suggestion: status = .suggestion
            case .off:        status = .inactive
            default:          status = .active
            }
        }

        let pending: Int = (dashProp?.history?.status == "pending") ? 1 : 0

        let priceMin: Double? = (config.priceMin ?? 0) > 0 ? config.priceMin : nil
        let priceMax: Double? = (config.priceMax ?? 0) > 0 ? config.priceMax : nil

        return BoostPricePropertyRow(
            id: config.propertyId,
            name: config.propertyName ?? config.propertyId,
            currency: currency,
            status: status,
            priceMin: priceMin,
            priceMax: priceMax,
            pendingSuggestions: pending
        )
    }

    return built.sorted {
        if $0.status != $1.status { return $0.status < $1.status }
        return $0.name.localizedCompare($1.name) == .orderedAscending
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class BoostPriceViewModel {

    enum LoadState { case idle, loading, loaded, error(String) }

    var loadState: LoadState = .idle
    var rows: [BoostPricePropertyRow] = []

    func load() async {
        if case .loaded = loadState {} else { loadState = .loading }

        async let configTask: DynamicPricingConfigResponse = APIClient.shared.get(Endpoint.dynamicPricingConfig)
        async let dashboardTask: DynamicPricingDashboardResponse = APIClient.shared.get(Endpoint.dynamicPricingDashboard)
        async let propertiesTask: PropertiesResponse = APIClient.shared.get(Endpoint.properties, agencyAll: true)

        let config: DynamicPricingConfigResponse
        do {
            config = try await configTask
        } catch {
            loadState = .error("Impossible de charger la configuration BoostPrice.")
            return
        }

        let dashboard = try? await dashboardTask
        let propertiesResponse = try? await propertiesTask

        rows = buildBoostPriceRows(
            configs: config.configs,
            dashboard: dashboard,
            properties: propertiesResponse?.properties ?? []
        )
        loadState = .loaded
    }
}
