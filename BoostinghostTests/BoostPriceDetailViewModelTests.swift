import Foundation
import Testing
@testable import Boostinghost

struct BoostPriceDetailViewModelTests {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - Decode helpers

    private func config(
        mode: String = "auto",
        isActive: Bool = true,
        priceMin: Double = 60,
        priceMax: Double = 180,
        strategy: Int = 50
    ) throws -> DynamicPricingConfig {
        let json = """
        {
          "id": "cfg_p1",
          "property_id": "p1",
          "property_name": "Studio Bastille",
          "mode": "\(mode)",
          "is_active": \(isActive),
          "price_min": \(priceMin),
          "price_max": \(priceMax),
          "strategy": \(strategy)
        }
        """.data(using: .utf8)!
        return try decoder.decode(DynamicPricingConfig.self, from: json)
    }

    private func historyItem(id: Int = 42, status: String = "pending") throws -> DynamicPricingHistoryItem {
        let json = """
        {
          "id": \(id),
          "property_id": "p1",
          "status": "\(status)",
          "price_before": 100,
          "price_calculated": 130,
          "factor_market": 1.18,
          "factor_self": 0.97,
          "factor_season": 1.05,
          "tension_label": "Forte demande"
        }
        """.data(using: .utf8)!
        return try decoder.decode(DynamicPricingHistoryItem.self, from: json)
    }

    // MARK: - currentStatusLabel

    @Test("auto + isActive → Automatique")
    func statusAutomatic() {
        let label = boostPriceCurrentStatus(isActive: true, mode: .auto, externalPricing: false)
        #expect(label == "Automatique")
    }

    @Test("manual + isActive → Sur recommandation")
    func statusManual() {
        let label = boostPriceCurrentStatus(isActive: true, mode: .manual, externalPricing: false)
        #expect(label == "Sur recommandation")
    }

    @Test("suggestion + isActive → Sur recommandation")
    func statusSuggestion() {
        let label = boostPriceCurrentStatus(isActive: true, mode: .suggestion, externalPricing: false)
        #expect(label == "Sur recommandation")
    }

    @Test("isActive false → Inactif")
    func statusInactive() {
        let label = boostPriceCurrentStatus(isActive: false, mode: .auto, externalPricing: false)
        #expect(label == "Inactif")
    }

    @Test("externalPricing → Tarification externe (overrides all)")
    func statusExternal() {
        let label = boostPriceCurrentStatus(isActive: true, mode: .auto, externalPricing: true)
        #expect(label == "Tarification externe")
    }

    @Test("externalPricing + inactive → still Tarification externe")
    func statusExternalInactive() {
        let label = boostPriceCurrentStatus(isActive: false, mode: .manual, externalPricing: true)
        #expect(label == "Tarification externe")
    }

    // MARK: - strategyLabel

    @Test("strategy 0 → Priorité occupation")
    func strategyLow() {
        #expect(boostPriceStrategyLabel(0) == "Priorité occupation")
    }

    @Test("strategy 29 → Priorité occupation")
    func strategyLowBoundary() {
        #expect(boostPriceStrategyLabel(29) == "Priorité occupation")
    }

    @Test("strategy 50 → Équilibré")
    func strategyMid() {
        #expect(boostPriceStrategyLabel(50) == "Équilibré")
    }

    @Test("strategy 71 → Priorité revenu")
    func strategyHigh() {
        #expect(boostPriceStrategyLabel(71) == "Priorité revenu")
    }

    @Test("strategy 100 → Priorité revenu")
    func strategyMax() {
        #expect(boostPriceStrategyLabel(100) == "Priorité revenu")
    }

    // MARK: - Validation

    @Test("valid prices → no errors")
    func validateOK() {
        let r = boostPriceValidate(minText: "60", maxText: "180")
        #expect(r.minError == nil)
        #expect(r.maxError == nil)
    }

    @Test("priceMin 0 → minError set")
    func validateMinZero() {
        let r = boostPriceValidate(minText: "0", maxText: "180")
        #expect(r.minError != nil)
    }

    @Test("empty priceMin → minError set")
    func validateMinEmpty() {
        let r = boostPriceValidate(minText: "", maxText: "180")
        #expect(r.minError != nil)
    }

    @Test("priceMax 0 → maxError set")
    func validateMaxZero() {
        let r = boostPriceValidate(minText: "60", maxText: "0")
        #expect(r.maxError != nil)
    }

    @Test("min >= max → maxError set")
    func validateMinGeMax() {
        let r = boostPriceValidate(minText: "180", maxText: "60")
        #expect(r.maxError != nil)
        #expect(r.minError == nil)
    }

    @Test("comma decimal separator parsed correctly")
    func validateCommaDecimal() {
        let r = boostPriceValidate(minText: "85,50", maxText: "150,00")
        #expect(r.minError == nil)
        #expect(r.maxError == nil)
    }

    @Test("parsePriceText handles comma as decimal separator")
    func parsePriceComma() {
        #expect(boostPriceParsePriceText("85,50") == 85.5)
    }

    @Test("parsePriceText handles period as decimal separator")
    func parsePricePeriod() {
        #expect(boostPriceParsePriceText("85.50") == 85.5)
    }

    @Test("parsePriceText empty string returns 0")
    func parsePriceEmpty() {
        #expect(boostPriceParsePriceText("") == 0)
    }

    // MARK: - boostPriceInitForm

    @Test("auto config → mode is .auto")
    func initFormAutoMode() throws {
        let f = boostPriceInitForm(from: try config(mode: "auto"))
        #expect(f.mode == .auto)
    }

    @Test("manual config → mode is .manual")
    func initFormManualMode() throws {
        let f = boostPriceInitForm(from: try config(mode: "manual"))
        #expect(f.mode == .manual)
    }

    @Test("suggestion config → mode mapped to .manual for form")
    func initFormSuggestionMode() throws {
        let f = boostPriceInitForm(from: try config(mode: "suggestion"))
        #expect(f.mode == .manual)
    }

    @Test("off config → mode defaults to .auto (isActive controls the toggle)")
    func initFormOffMode() throws {
        let f = boostPriceInitForm(from: try config(mode: "off", isActive: false))
        #expect(f.mode == .auto)
        #expect(f.isActive == false)
    }

    @Test("priceMin 0 in config → empty text field")
    func initFormPriceMinZero() throws {
        let f = boostPriceInitForm(from: try config(priceMin: 0))
        #expect(f.priceMinText == "")
    }

    @Test("strategy forwarded from config")
    func initFormStrategy() throws {
        let f = boostPriceInitForm(from: try config(strategy: 75))
        #expect(f.strategy == 75)
    }

    // MARK: - DynamicPricingHistoryItem decoding

    @Test("history item id decoded as Int")
    func historyItemIdDecoding() throws {
        let item = try historyItem(id: 42)
        #expect(item.id == 42)
        #expect(item.status == "pending")
    }

    @Test("history item factors decoded")
    func historyItemFactors() throws {
        let item = try historyItem()
        #expect(item.factorMarket == 1.18)
        #expect(item.factorSelf == 0.97)
    }

    // MARK: - DynamicPricingMode .manual case

    @Test("manual mode decodes from JSON")
    func manualModeDecoding() throws {
        let cfg = try config(mode: "manual")
        #expect(cfg.mode == .manual)
    }

    // MARK: - DynamicPricingConfig.strategy is Int?

    @Test("strategy decoded as Int from config")
    func strategyIntDecoding() throws {
        let cfg = try config(strategy: 80)
        #expect(cfg.strategy == 80)
    }

    // MARK: - boostPriceNeedsHistoryFallback

    @Test("needsHistoryFallback nil entry → false")
    func needsFallbackNilEntry() {
        #expect(boostPriceNeedsHistoryFallback(nil) == false)
    }

    @Test("needsHistoryFallback status applied → false")
    func needsFallbackStatusApplied() throws {
        let json = #"{"status":"applied"}"#.data(using: .utf8)!
        let entry = try decoder.decode(DynamicPricingHistoryEntry.self, from: json)
        #expect(boostPriceNeedsHistoryFallback(entry) == false)
    }

    @Test("needsHistoryFallback status declined → false")
    func needsFallbackStatusDeclined() throws {
        let json = #"{"status":"declined"}"#.data(using: .utf8)!
        let entry = try decoder.decode(DynamicPricingHistoryEntry.self, from: json)
        #expect(boostPriceNeedsHistoryFallback(entry) == false)
    }

    @Test("needsHistoryFallback pending + no historyId → true (old backend)")
    func needsFallbackPendingNoId() throws {
        let json = #"{"status":"pending","price_before":100}"#.data(using: .utf8)!
        let entry = try decoder.decode(DynamicPricingHistoryEntry.self, from: json)
        #expect(boostPriceNeedsHistoryFallback(entry) == true)
    }

    @Test("needsHistoryFallback pending + historyId present → false (new backend)")
    func needsFallbackPendingWithId() throws {
        let json = #"{"history_id":42,"status":"pending"}"#.data(using: .utf8)!
        let entry = try decoder.decode(DynamicPricingHistoryEntry.self, from: json)
        #expect(boostPriceNeedsHistoryFallback(entry) == false)
    }

    // MARK: - boostPricePreferHistoryId

    @Test("preferHistoryId uses dashEntry historyId when present")
    func preferIdDashEntryWins() throws {
        let json = #"{"history_id":42,"status":"pending"}"#.data(using: .utf8)!
        let entry = try decoder.decode(DynamicPricingHistoryEntry.self, from: json)
        let fallback = try [historyItem(id: 99, status: "pending")]
        let result = boostPricePreferHistoryId(dashEntry: entry, fallbackItems: fallback)
        #expect(result == 42)
    }

    @Test("preferHistoryId falls back to history item id when dashEntry has no historyId")
    func preferIdFallbackUsed() throws {
        let json = #"{"status":"pending"}"#.data(using: .utf8)!
        let entry = try decoder.decode(DynamicPricingHistoryEntry.self, from: json)
        let fallback = try [historyItem(id: 7, status: "pending")]
        let result = boostPricePreferHistoryId(dashEntry: entry, fallbackItems: fallback)
        #expect(result == 7)
    }

    @Test("preferHistoryId returns nil when dashEntry nil and fallback empty")
    func preferIdBothEmpty() {
        let result = boostPricePreferHistoryId(dashEntry: nil, fallbackItems: [])
        #expect(result == nil)
    }

    @Test("preferHistoryId ignores non-pending items in fallback")
    func preferIdIgnoresApplied() throws {
        let json = #"{"status":"pending"}"#.data(using: .utf8)!
        let entry = try decoder.decode(DynamicPricingHistoryEntry.self, from: json)
        let fallback = try [historyItem(id: 5, status: "applied")]
        let result = boostPricePreferHistoryId(dashEntry: entry, fallbackItems: fallback)
        #expect(result == nil)
    }

    @Test("preferHistoryId with nil dashEntry uses fallback pending item")
    func preferIdNilDashEntry() throws {
        let fallback = try [historyItem(id: 13, status: "pending")]
        let result = boostPricePreferHistoryId(dashEntry: nil, fallbackItems: fallback)
        #expect(result == 13)
    }

    @Test("preferHistoryId picks first pending from mixed fallback list")
    func preferIdFirstPendingInMixedList() throws {
        let applied = try historyItem(id: 1, status: "applied")
        let pending = try historyItem(id: 2, status: "pending")
        let result = boostPricePreferHistoryId(dashEntry: nil, fallbackItems: [applied, pending])
        #expect(result == 2)
    }

    // MARK: - DynamicPricingHistoryEntry.historyId decoding

    @Test("historyEntry historyId decoded when present")
    func historyEntryHistoryIdPresent() throws {
        let json = #"{"history_id":99,"status":"pending","price_before":100}"#.data(using: .utf8)!
        let entry = try decoder.decode(DynamicPricingHistoryEntry.self, from: json)
        #expect(entry.historyId == 99)
        #expect(entry.status == "pending")
    }

    @Test("historyEntry historyId nil when absent (backward compat)")
    func historyEntryHistoryIdAbsent() throws {
        let json = #"{"status":"pending","price_before":100}"#.data(using: .utf8)!
        let entry = try decoder.decode(DynamicPricingHistoryEntry.self, from: json)
        #expect(entry.historyId == nil)
    }

    @Test("full IOS-BP-03C flow: new backend → uses dashEntry historyId directly")
    func fullFlowNewBackend() throws {
        let json = #"{"history_id":55,"status":"pending","price_before":120,"price_calculated":145}"#.data(using: .utf8)!
        let entry = try decoder.decode(DynamicPricingHistoryEntry.self, from: json)
        let needsFallback = boostPriceNeedsHistoryFallback(entry)
        let resolvedId    = boostPricePreferHistoryId(dashEntry: entry, fallbackItems: [])
        #expect(needsFallback == false)
        #expect(resolvedId == 55)
    }

    @Test("full IOS-BP-03C flow: old backend → resolves via fallback items")
    func fullFlowOldBackend() throws {
        let dashJson = #"{"status":"pending","price_before":120}"#.data(using: .utf8)!
        let entry    = try decoder.decode(DynamicPricingHistoryEntry.self, from: dashJson)
        let fallback = try [historyItem(id: 77, status: "pending")]
        let needsFallback = boostPriceNeedsHistoryFallback(entry)
        let resolvedId    = boostPricePreferHistoryId(dashEntry: entry, fallbackItems: fallback)
        #expect(needsFallback == true)
        #expect(resolvedId == 77)
    }
}
