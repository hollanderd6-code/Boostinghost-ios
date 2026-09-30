import Foundation
import Testing
@testable import Boostinghost

struct PricingCalendarBoostPriceTests {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - PricingSource decoding

    @Test("PricingSource manual_override decodes to .manualOverride")
    func pricingSourceManualOverride() throws {
        let data = #""manual_override""#.data(using: .utf8)!
        let src  = try decoder.decode(PricingSource.self, from: data)
        #expect(src == .manualOverride)
    }

    @Test("PricingSource boostprice decodes to .boostprice")
    func pricingSourceBoostprice() throws {
        let data = #""boostprice""#.data(using: .utf8)!
        let src  = try decoder.decode(PricingSource.self, from: data)
        #expect(src == .boostprice)
    }

    @Test("PricingSource period_rule decodes to .periodRule")
    func pricingSourcePeriodRule() throws {
        let data = #""period_rule""#.data(using: .utf8)!
        let src  = try decoder.decode(PricingSource.self, from: data)
        #expect(src == .periodRule)
    }

    @Test("PricingSource weekday_rule decodes to .weekdayRule")
    func pricingSourceWeekdayRule() throws {
        let data = #""weekday_rule""#.data(using: .utf8)!
        let src  = try decoder.decode(PricingSource.self, from: data)
        #expect(src == .weekdayRule)
    }

    @Test("PricingSource weekend_price decodes to .weekendPrice")
    func pricingSourceWeekendPrice() throws {
        let data = #""weekend_price""#.data(using: .utf8)!
        let src  = try decoder.decode(PricingSource.self, from: data)
        #expect(src == .weekendPrice)
    }

    @Test("PricingSource base_price decodes to .basePrice")
    func pricingSourceBasePrice() throws {
        let data = #""base_price""#.data(using: .utf8)!
        let src  = try decoder.decode(PricingSource.self, from: data)
        #expect(src == .basePrice)
    }

    @Test("PricingSource none decodes to .none")
    func pricingSourceNone() throws {
        let data = #""none""#.data(using: .utf8)!
        let src  = try decoder.decode(PricingSource.self, from: data)
        #expect(src == .none)
    }

    @Test("PricingSource unknown value is forward-compatible")
    func pricingSourceUnknownForwardCompat() throws {
        let data = #""future_source""#.data(using: .utf8)!
        let src  = try decoder.decode(PricingSource.self, from: data)
        #expect(src == .unknown("future_source"))
    }

    // MARK: - BoostPriceScheduleStatus decoding

    @Test("BoostPriceScheduleStatus pending decodes correctly")
    func scheduleStatusPending() throws {
        let data = #""pending""#.data(using: .utf8)!
        let s    = try decoder.decode(BoostPriceScheduleStatus.self, from: data)
        #expect(s == .pending)
    }

    @Test("BoostPriceScheduleStatus applied decodes correctly")
    func scheduleStatusApplied() throws {
        let data = #""applied""#.data(using: .utf8)!
        let s    = try decoder.decode(BoostPriceScheduleStatus.self, from: data)
        #expect(s == .applied)
    }

    @Test("BoostPriceScheduleStatus declined decodes correctly")
    func scheduleStatusDeclined() throws {
        let data = #""declined""#.data(using: .utf8)!
        let s    = try decoder.decode(BoostPriceScheduleStatus.self, from: data)
        #expect(s == .declined)
    }

    @Test("BoostPriceScheduleStatus unknown value is forward-compatible")
    func scheduleStatusUnknown() throws {
        let data = #""future_status""#.data(using: .utf8)!
        let s    = try decoder.decode(BoostPriceScheduleStatus.self, from: data)
        #expect(s == .unknown("future_status"))
    }

    // MARK: - BoostPriceScheduleEntry decoding

    @Test("BoostPriceScheduleEntry decodes status and price")
    func scheduleEntryDecodes() throws {
        let json = #"{"status":"pending","price":150}"#.data(using: .utf8)!
        let e    = try decoder.decode(BoostPriceScheduleEntry.self, from: json)
        #expect(e.status == .pending)
        #expect(e.price == 150)
    }

    @Test("BoostPriceScheduleEntry price coerced from string via flexDouble")
    func scheduleEntryFlexPrice() throws {
        let json = #"{"status":"applied","price":"180.5"}"#.data(using: .utf8)!
        let e    = try decoder.decode(BoostPriceScheduleEntry.self, from: json)
        #expect(e.status == .applied)
        #expect(e.price == 180.5)
    }

    // MARK: - PricingCalendarProperty with new fields

    @Test("PricingCalendarProperty decodes boostprice fields from snake_case JSON")
    func calendarPropertyNewFieldsPresent() throws {
        let json = """
        {
          "base_price": 100,
          "currency": "EUR",
          "boostprice_enabled": true,
          "sources": {"2026-10-01": "boostprice", "2026-10-02": "manual_override"},
          "bp_schedule": {
            "2026-10-01": {"status": "applied", "price": 130},
            "2026-10-02": {"status": "pending", "price": 145}
          }
        }
        """.data(using: .utf8)!
        let p = try decoder.decode(PricingCalendarProperty.self, from: json)
        #expect(p.boostpriceEnabled == true)
        #expect(p.sources?["2026-10-01"] == .boostprice)
        #expect(p.sources?["2026-10-02"] == .manualOverride)
        #expect(p.bpSchedule?["2026-10-01"]?.status == .applied)
        #expect(p.bpSchedule?["2026-10-01"]?.price == 130)
    }

    // MARK: - isBoostPriceEffective — derives from sources, NOT bpSchedule

    @Test("isBoostPriceEffective true when sources[date] == boostprice")
    func isBoostPriceEffectiveTrue() throws {
        let json = """
        {"sources": {"2026-10-01": "boostprice"}}
        """.data(using: .utf8)!
        let p = try decoder.decode(PricingCalendarProperty.self, from: json)
        #expect(p.isBoostPriceEffective(for: "2026-10-01") == true)
    }

    @Test("isBoostPriceEffective false when source is manual_override, even if bpSchedule says applied")
    func isBoostPriceEffectiveFalseWhenManual() throws {
        let json = """
        {
          "sources": {"2026-10-01": "manual_override"},
          "bp_schedule": {"2026-10-01": {"status": "applied", "price": 130}}
        }
        """.data(using: .utf8)!
        let p = try decoder.decode(PricingCalendarProperty.self, from: json)
        #expect(p.isBoostPriceEffective(for: "2026-10-01") == false)
    }

    @Test("isBoostPriceEffective false when sources absent")
    func isBoostPriceEffectiveFalseWhenAbsent() throws {
        let json = #"{"base_price": 100}"#.data(using: .utf8)!
        let p    = try decoder.decode(PricingCalendarProperty.self, from: json)
        #expect(p.isBoostPriceEffective(for: "2026-10-01") == false)
    }

    @Test("hasPendingRecommendation true when bpSchedule[date].status == pending")
    func hasPendingRecommendationTrue() throws {
        let json = """
        {"bp_schedule": {"2026-10-01": {"status": "pending", "price": 145}}}
        """.data(using: .utf8)!
        let p = try decoder.decode(PricingCalendarProperty.self, from: json)
        #expect(p.hasPendingRecommendation(for: "2026-10-01") == true)
        #expect(p.hasPendingRecommendation(for: "2026-10-02") == false)
    }

    @Test("boostPriceRecommendation returns price when entry exists")
    func boostPriceRecommendationValue() throws {
        let json = """
        {"bp_schedule": {"2026-10-01": {"status": "pending", "price": 145}}}
        """.data(using: .utf8)!
        let p = try decoder.decode(PricingCalendarProperty.self, from: json)
        #expect(p.boostPriceRecommendation(for: "2026-10-01") == 145)
        #expect(p.boostPriceRecommendation(for: "2026-10-02") == nil)
    }

    @Test("PricingCalendarProperty without boostprice fields decodes cleanly (legacy compat)")
    func calendarPropertyLegacyCompatibility() throws {
        let json = """
        {"base_price": 80, "weekend_price": 100, "currency": "EUR"}
        """.data(using: .utf8)!
        let p = try decoder.decode(PricingCalendarProperty.self, from: json)
        #expect(p.basePrice == 80)
        #expect(p.boostpriceEnabled == nil)
        #expect(p.sources == nil)
        #expect(p.bpSchedule == nil)
        #expect(p.isBoostPriceEnabled == false)
    }

    // MARK: - DynamicPricingMode

    @Test("DynamicPricingMode unknown value is forward-compatible")
    func dynamicPricingModeUnknown() throws {
        let data = #""hybrid""#.data(using: .utf8)!
        let m    = try decoder.decode(DynamicPricingMode.self, from: data)
        #expect(m == .unknown("hybrid"))
    }

    // MARK: - DynamicPricingConfig

    @Test("DynamicPricingConfigResponse decodes configs array")
    func dynamicPricingConfigDecodes() throws {
        let json = """
        {
          "configs": [{
            "id": "cfg1",
            "property_id": "prop123",
            "property_name": "Studio Bastille",
            "price_min": 60,
            "price_max": 200,
            "mode": "suggestion",
            "is_active": true,
            "notify_push": true,
            "bedrooms": 1,
            "strategy": "balanced"
          }]
        }
        """.data(using: .utf8)!
        let r = try decoder.decode(DynamicPricingConfigResponse.self, from: json)
        #expect(r.configs.count == 1)
        let c = r.configs[0]
        #expect(c.id == "cfg1")
        #expect(c.propertyId == "prop123")
        #expect(c.propertyName == "Studio Bastille")
        #expect(c.priceMin == 60)
        #expect(c.priceMax == 200)
        #expect(c.mode == .suggestion)
        #expect(c.isActive == true)
        #expect(c.bedrooms == 1)
        #expect(c.strategy == "balanced")
    }

    @Test("DynamicPricingConfigResponse missing configs key yields empty array")
    func dynamicPricingConfigEmptyFallback() throws {
        let json = #"{}"#.data(using: .utf8)!
        let r    = try decoder.decode(DynamicPricingConfigResponse.self, from: json)
        #expect(r.configs.isEmpty)
    }

    // MARK: - DynamicPricingDashboardResponse

    @Test("DynamicPricingDashboardResponse decodes full payload")
    func dynamicPricingDashboardDecodes() throws {
        let json = """
        {
          "week_start": "2026-09-28",
          "pending_count": 3,
          "weekly_gain_by_currency": {"EUR": 420.5, "ILS": 800},
          "properties": [{
            "property_id": "prop123",
            "property_name": "Studio Bastille",
            "mode": "auto",
            "price_min": 70,
            "price_max": 220,
            "property_currency": "EUR",
            "market": {
              "median_price": 150,
              "tension_level": "high",
              "comparable_count": 12
            },
            "history": {
              "status": "applied",
              "price_before": 100,
              "price_applied": 148,
              "applied_at": "2026-09-28T06:00:00Z"
            }
          }]
        }
        """.data(using: .utf8)!
        let r = try decoder.decode(DynamicPricingDashboardResponse.self, from: json)
        #expect(r.weekStart == "2026-09-28")
        #expect(r.pendingCount == 3)
        #expect(r.weeklyGainByCurrency?["EUR"] == 420.5)
        #expect(r.properties.count == 1)
        let p = r.properties[0]
        #expect(p.propertyId == "prop123")
        #expect(p.mode == .auto)
        #expect(p.propertyCurrency == "EUR")
        #expect(p.market?.medianPrice == 150)
        #expect(p.market?.tensionLevel == "high")
        #expect(p.market?.comparableCount == 12)
        #expect(p.history?.status == "applied")
        #expect(p.history?.priceApplied == 148)
    }

    @Test("DynamicPricingDashboardResponse missing properties yields empty array")
    func dynamicPricingDashboardEmptyFallback() throws {
        let json = #"{}"#.data(using: .utf8)!
        let r    = try decoder.decode(DynamicPricingDashboardResponse.self, from: json)
        #expect(r.properties.isEmpty)
        #expect(r.pendingCount == 0)
    }
}
