import Foundation
import Testing
@testable import Boostinghost

struct NightPriceDetailTests {

    // MARK: - Helpers

    private func property(
        basePrice:         Double  = 100,
        weekendPrice:      Double? = nil,
        prices:            [String: Double]  = [:],
        boostpriceEnabled: Bool    = false,
        sources:           [String: PricingSource] = [:],
        bpSchedule:        [String: BoostPriceScheduleEntry] = [:]
    ) -> PricingCalendarProperty {
        var rawSources: [String: String] = [:]
        for (k, v) in sources {
            switch v {
            case .manualOverride: rawSources[k] = "manual_override"
            case .boostprice:     rawSources[k] = "boostprice"
            case .periodRule:     rawSources[k] = "period_rule"
            case .weekdayRule:    rawSources[k] = "weekday_rule"
            case .weekendPrice:   rawSources[k] = "weekend_price"
            case .basePrice:      rawSources[k] = "base_price"
            case .none:           rawSources[k] = "none"
            case .unknown(let s): rawSources[k] = s
            }
        }
        var rawSchedule: [String: [String: Any]] = [:]
        for (k, e) in bpSchedule {
            var statusStr: String
            switch e.status {
            case .pending:       statusStr = "pending"
            case .applied:       statusStr = "applied"
            case .declined:      statusStr = "declined"
            case .unknown(let s): statusStr = s
            }
            rawSchedule[k] = ["status": statusStr, "price": e.price]
        }
        var dict: [String: Any] = [
            "basePrice":         basePrice,
            "boostpriceEnabled": boostpriceEnabled,
            "prices":            prices,
            "sources":           rawSources,
        ]
        if let wp = weekendPrice { dict["weekendPrice"] = wp }
        if !rawSchedule.isEmpty  { dict["bpSchedule"]   = rawSchedule }
        let data = try! JSONSerialization.data(withJSONObject: dict)
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        return try! dec.decode(PricingCalendarProperty.self, from: data)
    }

    private func makeRawEntry(status: BoostPriceScheduleStatus, price: Double) -> BoostPriceScheduleEntry {
        let rawStatus: String
        switch status {
        case .pending:        rawStatus = "pending"
        case .applied:        rawStatus = "applied"
        case .declined:       rawStatus = "declined"
        case .unknown(let s): rawStatus = s
        }
        let data = try! JSONSerialization.data(withJSONObject: ["status": rawStatus, "price": price])
        return try! JSONDecoder().decode(BoostPriceScheduleEntry.self, from: data)
    }

    // MARK: - boostPriceAuthorityLabel

    @Test("manualOverride → Prix manuel")
    func labelManualOverride() {
        #expect(boostPriceAuthorityLabel(.manualOverride) == "Prix manuel")
    }

    @Test("boostprice → Prix BoostPrice")
    func labelBoostprice() {
        #expect(boostPriceAuthorityLabel(.boostprice) == "Prix BoostPrice")
    }

    @Test("periodRule → Règle de période")
    func labelPeriodRule() {
        #expect(boostPriceAuthorityLabel(.periodRule) == "Règle de période")
    }

    @Test("weekdayRule → Règle hebdomadaire")
    func labelWeekdayRule() {
        #expect(boostPriceAuthorityLabel(.weekdayRule) == "Règle hebdomadaire")
    }

    @Test("weekendPrice → Prix weekend")
    func labelWeekendPrice() {
        #expect(boostPriceAuthorityLabel(.weekendPrice) == "Prix weekend")
    }

    @Test("basePrice → Prix de base")
    func labelBasePrice() {
        #expect(boostPriceAuthorityLabel(.basePrice) == "Prix de base")
    }

    @Test("none → Prix de base")
    func labelNone() {
        #expect(boostPriceAuthorityLabel(.none) == "Prix de base")
    }

    @Test("unknown → Prix calculé")
    func labelUnknown() {
        #expect(boostPriceAuthorityLabel(.unknown("custom_algo")) == "Prix calculé")
    }

    @Test("nil source → Prix de base")
    func labelNilSource() {
        #expect(boostPriceAuthorityLabel(nil) == "Prix de base")
    }

    // MARK: - boostPriceDayDelta

    @Test("positive delta: scheduled > effective")
    func deltaPositive() {
        #expect(boostPriceDayDelta(effective: 100, scheduled: 120) == 20)
    }

    @Test("zero delta: scheduled == effective")
    func deltaZero() {
        #expect(boostPriceDayDelta(effective: 85, scheduled: 85) == 0)
    }

    @Test("negative delta: scheduled < effective")
    func deltaNegative() {
        #expect(boostPriceDayDelta(effective: 150, scheduled: 130) == -20)
    }

    @Test("large values maintain precision")
    func deltaLargeValues() {
        #expect(boostPriceDayDelta(effective: 5000, scheduled: 7500) == 2500)
    }

    @Test("fractional prices")
    func deltaFractional() {
        let delta = boostPriceDayDelta(effective: 99.50, scheduled: 112.25)
        #expect(abs(delta - 12.75) < 0.001)
    }

    // MARK: - Price calculation

    @Test("weekday cell uses basePrice when no override")
    func priceWeekdayUsesBasePrice() {
        let prop = property(basePrice: 100, weekendPrice: 150)
        #expect(prop.price(for: "2026-09-29", isWeekend: false) == 100)
    }

    @Test("weekend cell uses weekendPrice when present")
    func priceWeekendUsesWeekendPrice() {
        let prop = property(basePrice: 100, weekendPrice: 150)
        #expect(prop.price(for: "2026-09-27", isWeekend: true) == 150)
    }

    @Test("manual override in prices dict takes precedence over base")
    func priceManualOverrideUsesCustomPrice() {
        let prop = property(basePrice: 100, prices: ["2026-10-01": 200])
        #expect(prop.price(for: "2026-10-01", isWeekend: false) == 200)
    }

    // MARK: - pricingSource

    @Test("pricingSource returns boostprice when set")
    func pricingSourceBoostprice() {
        let prop = property(sources: ["2026-10-01": .boostprice])
        #expect(prop.pricingSource(for: "2026-10-01") == .boostprice)
    }

    @Test("pricingSource returns nil for absent date")
    func pricingSourceAbsent() {
        let prop = property(sources: ["2026-10-02": .boostprice])
        #expect(prop.pricingSource(for: "2026-10-01") == nil)
    }

    @Test("pricingSource returns manualOverride correctly")
    func pricingSourceManualOverride() {
        let prop = property(sources: ["2026-10-01": .manualOverride])
        #expect(prop.pricingSource(for: "2026-10-01") == .manualOverride)
    }

    // MARK: - isBoostPriceEnabled

    @Test("isBoostPriceEnabled true when set")
    func boostPriceEnabledTrue() {
        let prop = property(boostpriceEnabled: true)
        #expect(prop.isBoostPriceEnabled == true)
    }

    @Test("isBoostPriceEnabled false when not set")
    func boostPriceEnabledFalse() {
        let prop = property(boostpriceEnabled: false)
        #expect(prop.isBoostPriceEnabled == false)
    }

    // MARK: - boostPriceScheduleEntry

    @Test("pending entry returned when schedule has pending entry")
    func scheduleEntryPending() {
        let entry = makeRawEntry(status: .pending, price: 130)
        let prop  = property(bpSchedule: ["2026-10-01": entry])
        let e     = prop.boostPriceScheduleEntry(for: "2026-10-01")
        #expect(e?.status == .pending)
        #expect(e?.price == 130)
    }

    @Test("applied entry returned when schedule has applied entry")
    func scheduleEntryApplied() {
        let entry = makeRawEntry(status: .applied, price: 120)
        let prop  = property(bpSchedule: ["2026-10-01": entry])
        let e     = prop.boostPriceScheduleEntry(for: "2026-10-01")
        #expect(e?.status == .applied)
    }

    @Test("declined entry returned when schedule has declined entry")
    func scheduleEntryDeclined() {
        let entry = makeRawEntry(status: .declined, price: 115)
        let prop  = property(bpSchedule: ["2026-10-01": entry])
        let e     = prop.boostPriceScheduleEntry(for: "2026-10-01")
        #expect(e?.status == .declined)
    }

    @Test("nil returned when schedule has no entry for date")
    func scheduleEntryAbsent() {
        let prop = property()
        #expect(prop.boostPriceScheduleEntry(for: "2026-10-01") == nil)
    }

    // MARK: - Night detail section visibility conditions

    @Test("night detail hidden when canViewPricing false: price(for:) still returns value (view gates it)")
    func priceAvailableEvenWhenPricingHidden() {
        // The gating is done by the view (canViewPricing), not the model.
        // The model always returns the price — this test verifies model is not nil.
        let prop = property(basePrice: 100)
        #expect(prop.price(for: "2026-10-01", isWeekend: false) != nil)
    }

    @Test("night detail hidden when propData nil: price(for:) returns nil on empty property")
    func priceNilWhenNoPriceDataAtAll() {
        // A property with nil basePrice and no prices dict entry returns nil.
        let data = try! JSONSerialization.data(withJSONObject: ["boostpriceEnabled": false])
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        let prop = try! dec.decode(PricingCalendarProperty.self, from: data)
        #expect(prop.price(for: "2026-10-01", isWeekend: false) == nil)
    }

    @Test("boostprice row condition: source == .boostprice is true only for boostprice source")
    func boostPriceRowCondition() {
        let propBP = property(sources: ["d": .boostprice])
        let propMO = property(sources: ["d": .manualOverride])
        #expect(propBP.pricingSource(for: "d") == .boostprice)
        #expect(propMO.pricingSource(for: "d") != .boostprice)
    }

    @Test("pending row shown only when status pending AND price > 0")
    func pendingRowCondition() {
        let entryPendingNonZero  = makeRawEntry(status: .pending,  price: 120)
        let entryPendingZero     = makeRawEntry(status: .pending,  price: 0)
        let entryAppliedNonZero  = makeRawEntry(status: .applied,  price: 120)

        let prop1 = property(bpSchedule: ["d": entryPendingNonZero])
        let prop2 = property(bpSchedule: ["d": entryPendingZero])
        let prop3 = property(bpSchedule: ["d": entryAppliedNonZero])

        let e1 = prop1.boostPriceScheduleEntry(for: "d")
        let e2 = prop2.boostPriceScheduleEntry(for: "d")
        let e3 = prop3.boostPriceScheduleEntry(for: "d")

        #expect(e1?.status == .pending && (e1?.price ?? 0) > 0)
        #expect(!(e2?.status == .pending && (e2?.price ?? 0) > 0))
        #expect(!(e3?.status == .pending && (e3?.price ?? 0) > 0))
    }
}
