import Foundation
import Testing
@testable import Boostinghost

struct BoostPriceViewModelTests {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - Decoding helpers

    private func config(
        propertyId: String = "prop1",
        name: String = "Studio Bastille",
        mode: String = "auto",
        isActive: Bool = true,
        priceMin: Double = 60,
        priceMax: Double = 180
    ) throws -> DynamicPricingConfig {
        let json = """
        {
          "id": "cfg_\(propertyId)",
          "property_id": "\(propertyId)",
          "property_name": "\(name)",
          "mode": "\(mode)",
          "is_active": \(isActive),
          "price_min": \(priceMin),
          "price_max": \(priceMax)
        }
        """.data(using: .utf8)!
        return try decoder.decode(DynamicPricingConfig.self, from: json)
    }

    private func dashboardProp(
        propertyId: String = "prop1",
        currency: String = "EUR",
        historyStatus: String? = nil
    ) throws -> DynamicPricingDashboardProperty {
        var historyJSON = "null"
        if let s = historyStatus {
            historyJSON = """
            {"status": "\(s)", "price_before": 100, "price_applied": 130}
            """
        }
        let json = """
        {
          "property_id": "\(propertyId)",
          "property_name": "Studio Bastille",
          "mode": "auto",
          "price_min": 60,
          "price_max": 180,
          "property_currency": "\(currency)",
          "history": \(historyJSON)
        }
        """.data(using: .utf8)!
        return try decoder.decode(DynamicPricingDashboardProperty.self, from: json)
    }

    private func dashboard(
        props: [DynamicPricingDashboardProperty],
        pendingCount: Int = 0
    ) -> DynamicPricingDashboardResponse {
        DynamicPricingDashboardResponse(
            properties: props,
            pendingCount: pendingCount,
            weeklyGainByCurrency: nil,
            weekStart: nil
        )
    }

    private func property(
        id: String = "prop1",
        currency: String? = nil,
        externalPricing: Bool? = nil
    ) throws -> Property {
        var extras = ""
        if let c = currency { extras += #","currency": "\#(c)""# }
        if let e = externalPricing { extras += ",\"external_pricing\": \(e)" }
        let json = """
        {"_id": "\(id)", "name": "Studio Bastille"\(extras)}
        """.data(using: .utf8)!
        return try decoder.decode(Property.self, from: json)
    }

    // MARK: - Status derivation

    @Test("auto + isActive → .automatic")
    func statusAutomatic() throws {
        let rows = buildBoostPriceRows(
            configs: [try config(mode: "auto", isActive: true)],
            dashboard: nil, properties: []
        )
        #expect(rows.first?.status == .automatic)
    }

    @Test("suggestion + isActive → .suggestion")
    func statusSuggestion() throws {
        let rows = buildBoostPriceRows(
            configs: [try config(mode: "suggestion", isActive: true)],
            dashboard: nil, properties: []
        )
        #expect(rows.first?.status == .suggestion)
    }

    @Test("unknown mode + isActive → .active")
    func statusActiveUnknownMode() throws {
        let rows = buildBoostPriceRows(
            configs: [try config(mode: "hybrid", isActive: true)],
            dashboard: nil, properties: []
        )
        #expect(rows.first?.status == .active)
    }

    @Test("mode off → .inactive regardless of isActive")
    func statusOffMode() throws {
        let rows = buildBoostPriceRows(
            configs: [try config(mode: "off", isActive: true)],
            dashboard: nil, properties: []
        )
        #expect(rows.first?.status == .inactive)
    }

    @Test("isActive false → .inactive regardless of mode")
    func statusInactiveFlag() throws {
        let rows = buildBoostPriceRows(
            configs: [try config(mode: "auto", isActive: false)],
            dashboard: nil, properties: []
        )
        #expect(rows.first?.status == .inactive)
    }

    @Test("externalPricing true → .externalPricing overrides mode and isActive")
    func statusExternalPricingOverrides() throws {
        let prop = try property(id: "prop1", externalPricing: true)
        let rows = buildBoostPriceRows(
            configs: [try config(mode: "auto", isActive: true)],
            dashboard: nil, properties: [prop]
        )
        #expect(rows.first?.status == .externalPricing)
    }

    @Test("externalPricing false → status from config, not external")
    func statusExternalPricingFalsePassthrough() throws {
        let prop = try property(id: "prop1", externalPricing: false)
        let rows = buildBoostPriceRows(
            configs: [try config(mode: "auto", isActive: true)],
            dashboard: nil, properties: [prop]
        )
        #expect(rows.first?.status == .automatic)
    }

    // MARK: - Currency resolution

    @Test("property.currency takes priority over dashboard propertyCurrency")
    func currencyFromProperty() throws {
        let prop = try property(id: "prop1", currency: "ILS")
        let dp   = try dashboardProp(propertyId: "prop1", currency: "EUR")
        let rows = buildBoostPriceRows(
            configs: [try config()],
            dashboard: dashboard(props: [dp]),
            properties: [prop]
        )
        #expect(rows.first?.currency == "ILS")
    }

    @Test("dashboard propertyCurrency used when property not matched")
    func currencyFromDashboard() throws {
        let dp = try dashboardProp(propertyId: "prop1", currency: "ILS")
        let rows = buildBoostPriceRows(
            configs: [try config()],
            dashboard: dashboard(props: [dp]),
            properties: []
        )
        #expect(rows.first?.currency == "ILS")
    }

    @Test("no currency source falls back to EUR")
    func currencyFallbackEUR() throws {
        let rows = buildBoostPriceRows(
            configs: [try config()], dashboard: nil, properties: []
        )
        #expect(rows.first?.currency == "EUR")
    }

    // MARK: - Pending suggestions

    @Test("history status pending → pendingSuggestions == 1")
    func pendingSuggestionsOne() throws {
        let dp = try dashboardProp(propertyId: "prop1", historyStatus: "pending")
        let rows = buildBoostPriceRows(
            configs: [try config()],
            dashboard: dashboard(props: [dp], pendingCount: 1),
            properties: []
        )
        #expect(rows.first?.pendingSuggestions == 1)
    }

    @Test("history status applied → pendingSuggestions == 0")
    func pendingSuggestionsZeroApplied() throws {
        let dp = try dashboardProp(propertyId: "prop1", historyStatus: "applied")
        let rows = buildBoostPriceRows(
            configs: [try config()],
            dashboard: dashboard(props: [dp]),
            properties: []
        )
        #expect(rows.first?.pendingSuggestions == 0)
    }

    @Test("no dashboard → pendingSuggestions == 0")
    func pendingSuggestionsNoDashboard() throws {
        let rows = buildBoostPriceRows(
            configs: [try config()], dashboard: nil, properties: []
        )
        #expect(rows.first?.pendingSuggestions == 0)
    }

    // MARK: - Price range

    @Test("priceMin and priceMax forwarded from config when > 0")
    func priceRangeForwarded() throws {
        let rows = buildBoostPriceRows(
            configs: [try config(priceMin: 65, priceMax: 120)],
            dashboard: nil, properties: []
        )
        #expect(rows.first?.priceMin == 65)
        #expect(rows.first?.priceMax == 120)
    }

    @Test("priceMin == 0 treated as absent (nil)")
    func priceMinZeroIsNil() throws {
        let rows = buildBoostPriceRows(
            configs: [try config(priceMin: 0, priceMax: 120)],
            dashboard: nil, properties: []
        )
        #expect(rows.first?.priceMin == nil)
    }

    // MARK: - Sort order

    @Test("rows sorted: automatic < suggestion < active < inactive < external")
    func sortOrder() throws {
        let cfgs = [
            try config(propertyId: "p5", name: "E", mode: "hybrid",      isActive: true),
            try config(propertyId: "p3", name: "C", mode: "auto",        isActive: false),
            try config(propertyId: "p1", name: "A", mode: "auto",        isActive: true),
            try config(propertyId: "p4", name: "D", mode: "suggestion",  isActive: true),
            try config(propertyId: "p2", name: "B", mode: "auto",        isActive: true),
        ]
        let props = [try property(id: "p3", externalPricing: true)]
        let rows = buildBoostPriceRows(configs: cfgs, dashboard: nil, properties: props)
        let statuses = rows.map { $0.status }
        #expect(statuses == [.automatic, .automatic, .suggestion, .active, .externalPricing])
    }

    @Test("within same status, rows sorted alphabetically by name")
    func sortAlphaWithinGroup() throws {
        let cfgs = [
            try config(propertyId: "p2", name: "Zenith", mode: "auto", isActive: true),
            try config(propertyId: "p1", name: "Alpha",  mode: "auto", isActive: true),
        ]
        let rows = buildBoostPriceRows(configs: cfgs, dashboard: nil, properties: [])
        #expect(rows.map { $0.name } == ["Alpha", "Zenith"])
    }
}
