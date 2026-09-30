import Foundation
import Observation

// MARK: - Save request

struct BoostPriceSaveRequest: Encodable {
    let propertyId:  String
    let priceMin:    Double
    let priceMax:    Double
    let mode:        String
    let isActive:    Bool
    let notifyPush:  Bool
    let notifyEmail: Bool
    let notifyAlert: Bool
    let bedrooms:    Int
    let strategy:    Int
}

// MARK: - Decision request

struct BoostPriceDecisionRequest: Encodable {
    let action: String
}

// MARK: - Free functions (nonisolated, testable)

func boostPriceStrategyLabel(_ value: Int) -> String {
    switch value {
    case 0..<30:   return "Priorité occupation"
    case 71...100: return "Priorité revenu"
    default:       return "Équilibré"
    }
}

func boostPriceCurrentStatus(isActive: Bool, mode: DynamicPricingMode, externalPricing: Bool) -> String {
    if externalPricing { return "Tarification externe" }
    guard isActive else { return "Inactif" }
    switch mode {
    case .auto:       return "Automatique"
    case .suggestion, .manual: return "Sur recommandation"
    default:          return "BoostPrice actif"
    }
}

func boostPriceParsePriceText(_ text: String) -> Double {
    Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
}

func boostPriceValidate(minText: String, maxText: String) -> (minError: String?, maxError: String?) {
    let minVal = boostPriceParsePriceText(minText)
    let maxVal = boostPriceParsePriceText(maxText)

    var minError: String? = nil
    var maxError: String? = nil

    if minVal <= 0 {
        minError = "Prix minimum requis"
    }
    if maxVal <= 0 {
        maxError = "Prix maximum requis"
    } else if minError == nil && minVal >= maxVal {
        maxError = "Doit être supérieur au prix minimum"
    }
    return (minError, maxError)
}

func boostPriceInitForm(from config: DynamicPricingConfig) -> (
    mode: DynamicPricingMode, priceMinText: String, priceMaxText: String,
    strategy: Int, isActive: Bool
) {
    let mode: DynamicPricingMode
    switch config.mode {
    case .auto:                    mode = .auto
    case .suggestion, .manual:     mode = .manual
    default:                       mode = .auto
    }

    func priceText(_ value: Double?) -> String {
        guard let v = value, v > 0 else { return "" }
        return v == Double(Int(v)) ? String(Int(v)) : String(format: "%.2f", v)
    }

    return (
        mode: mode,
        priceMinText: priceText(config.priceMin),
        priceMaxText: priceText(config.priceMax),
        strategy: config.strategy ?? 50,
        isActive: config.isActive ?? true
    )
}

func boostPriceFactorLabel(value: Double, factor: String) -> String {
    switch factor {
    case "market":
        if value > 1.10 { return "Forte demande sur le marché" }
        if value < 0.90 { return "Faible demande locale" }
        return "Marché stable"
    case "self":
        if value > 1.05 { return "Logement très demandé" }
        if value < 0.95 { return "Historique en baisse" }
        return "Historique stable"
    case "season":
        if value > 1.10 { return "Haute saison" }
        if value < 0.90 { return "Basse saison" }
        return "Saison normale"
    default:
        return ""
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class BoostPriceDetailViewModel {

    enum LoadState { case idle, loading, loaded, error(String) }
    enum ActionState: Equatable { case idle, working, success(String), error(String) }

    let propertyId:      String
    let propertyName:    String
    let externalPricing: Bool

    var loadState:   LoadState   = .idle
    var actionState: ActionState = .idle

    // Loaded data (read-only display)
    var config:             DynamicPricingConfig?
    var dashProp:           DynamicPricingDashboardProperty?
    var pendingHistoryItem: DynamicPricingHistoryItem?
    var currency:           String = "EUR"

    // Editable form state
    var isActive:      Bool               = false
    var selectedMode:  DynamicPricingMode = .auto
    var priceMinText:  String             = ""
    var priceMaxText:  String             = ""
    var strategy:      Int                = 50
    var isDirty:       Bool               = false

    // Validation
    var priceMinError: String? = nil
    var priceMaxError: String? = nil

    init(propertyId: String, propertyName: String, externalPricing: Bool = false) {
        self.propertyId      = propertyId
        self.propertyName    = propertyName
        self.externalPricing = externalPricing
    }

    // MARK: - Load

    func load() async {
        if case .loaded = loadState {} else { loadState = .loading }

        async let configTask: DynamicPricingConfigResponse   = APIClient.shared.get(Endpoint.dynamicPricingConfig)
        async let dashTask:   DynamicPricingDashboardResponse = APIClient.shared.get(Endpoint.dynamicPricingDashboard)

        let configResponse: DynamicPricingConfigResponse
        do {
            configResponse = try await configTask
        } catch {
            loadState = .error("Impossible de charger la configuration.")
            return
        }

        let dashResponse = try? await dashTask

        config   = configResponse.configs.first(where: { $0.propertyId == propertyId })
        dashProp = dashResponse?.properties.first(where: { $0.propertyId == propertyId })
        currency = Formatters.normalizeCurrency(dashProp?.propertyCurrency)

        if let cfg = config {
            let form = boostPriceInitForm(from: cfg)
            isActive     = form.isActive
            selectedMode = form.mode
            priceMinText = form.priceMinText
            priceMaxText = form.priceMaxText
            strategy     = form.strategy
        }
        isDirty = false

        let hasPending = dashProp?.history?.status == "pending"
        if hasPending {
            let histResp: DynamicPricingHistoryListResponse? = try? await APIClient.shared.get(
                Endpoint.dynamicPricingHistory,
                extraQueryItems: [
                    URLQueryItem(name: "propertyId", value: propertyId),
                    URLQueryItem(name: "limit",      value: "1")
                ]
            )
            pendingHistoryItem = histResp?.history.first(where: { $0.status == "pending" })
        } else {
            pendingHistoryItem = nil
        }

        loadState = .loaded
    }

    // MARK: - Save

    func save() async {
        guard case .idle = actionState else { return }

        let result = boostPriceValidate(minText: priceMinText, maxText: priceMaxText)
        priceMinError = result.minError
        priceMaxError = result.maxError
        guard result.minError == nil && result.maxError == nil else { return }

        actionState = .working

        let modeString: String = (selectedMode == .auto) ? "auto" : "manual"
        let request = BoostPriceSaveRequest(
            propertyId:  propertyId,
            priceMin:    boostPriceParsePriceText(priceMinText),
            priceMax:    boostPriceParsePriceText(priceMaxText),
            mode:        modeString,
            isActive:    isActive,
            notifyPush:  config?.notifyPush  ?? true,
            notifyEmail: config?.notifyEmail ?? true,
            notifyAlert: config?.notifyAlert ?? true,
            bedrooms:    config?.bedrooms    ?? 1,
            strategy:    strategy
        )

        do {
            let _: BoostPriceSaveResponse = try await APIClient.shared.post(
                Endpoint.dynamicPricingConfig, body: request
            )
            isDirty     = false
            actionState = .success("Configuration sauvegardée")
            await load()
        } catch {
            actionState = .error("Impossible de sauvegarder.")
        }
    }

    // MARK: - Decision

    func acceptSuggestion() async {
        guard let histId = pendingHistoryItem?.id else { return }
        guard case .idle = actionState else { return }

        actionState = .working
        do {
            let _: BoostPriceDecisionResponse = try await APIClient.shared.post(
                Endpoint.dynamicPricingDecision(histId),
                body: BoostPriceDecisionRequest(action: "apply")
            )
            actionState = .success("Prix appliqué")
            await load()
        } catch {
            actionState = .error("Impossible d'appliquer la suggestion.")
        }
    }

    func declineSuggestion() async {
        guard let histId = pendingHistoryItem?.id else { return }
        guard case .idle = actionState else { return }

        actionState = .working
        do {
            let _: BoostPriceDecisionResponse = try await APIClient.shared.post(
                Endpoint.dynamicPricingDecision(histId),
                body: BoostPriceDecisionRequest(action: "decline")
            )
            actionState = .success("Suggestion refusée")
            await load()
        } catch {
            actionState = .error("Impossible de refuser la suggestion.")
        }
    }

    // MARK: - Derived

    var strategyLabel: String { boostPriceStrategyLabel(strategy) }

    var currentStatusLabel: String {
        boostPriceCurrentStatus(isActive: isActive, mode: selectedMode, externalPricing: externalPricing)
    }

    var hasPendingSuggestion: Bool { pendingHistoryItem != nil }

    func markDirty() { isDirty = true }
}
