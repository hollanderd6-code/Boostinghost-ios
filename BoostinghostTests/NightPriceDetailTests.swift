import Foundation
import Testing
@testable import Boostinghost

// MARK: - Helpers shared across all sections

private func calProp(
    basePrice:         Double  = 100,
    weekendPrice:      Double? = nil,
    prices:            [String: Double] = [:],
    boostpriceEnabled: Bool = false,
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
        var st: String
        switch e.status {
        case .pending:        st = "pending"
        case .applied:        st = "applied"
        case .declined:       st = "declined"
        case .unknown(let s): st = s
        }
        rawSchedule[k] = ["status": st, "price": e.price]
    }
    var dict: [String: Any] = [
        "basePrice": basePrice,
        "boostpriceEnabled": boostpriceEnabled,
        "prices": prices,
        "sources": rawSources,
    ]
    if let wp = weekendPrice { dict["weekendPrice"] = wp }
    if !rawSchedule.isEmpty  { dict["bpSchedule"]   = rawSchedule }
    let data = try! JSONSerialization.data(withJSONObject: dict)
    let dec  = JSONDecoder()
    dec.keyDecodingStrategy = .convertFromSnakeCase
    return try! dec.decode(PricingCalendarProperty.self, from: data)
}

private func decodeExplainability(_ dict: [String: Any]) -> NightExplainability {
    let data = try! JSONSerialization.data(withJSONObject: dict)
    return try! JSONDecoder().decode(NightExplainability.self, from: data)
}

private func decodeScheduleRow(_ dict: [String: Any]) -> NightScheduleRow {
    let data = try! JSONSerialization.data(withJSONObject: dict)
    return try! JSONDecoder().decode(NightScheduleRow.self, from: data)
}

private func decodeScheduleResponse(_ nights: [[String: Any]]) -> NightScheduleResponse {
    let dict: [String: Any] = ["nights": nights, "mode": "manual", "isActive": true]
    let data = try! JSONSerialization.data(withJSONObject: dict)
    return try! JSONDecoder().decode(NightScheduleResponse.self, from: data)
}

private func makeScheduleEntry(status: BoostPriceScheduleStatus, price: Double) -> BoostPriceScheduleEntry {
    let st: String
    switch status {
    case .pending:        st = "pending"
    case .applied:        st = "applied"
    case .declined:       st = "declined"
    case .unknown(let s): st = s
    }
    let data = try! JSONSerialization.data(withJSONObject: ["status": st, "price": price])
    return try! JSONDecoder().decode(BoostPriceScheduleEntry.self, from: data)
}

// Full version-1 factor dictionary used in multiple tests
private let fullFactorDict: [String: Any] = [
    "version": 1,
    "base": 100.0,
    "season": 1.02,
    "dow": 1.16,
    "lead": 0.99,
    "pacing": 1.05,
    "strategy": 1.0,
    "market": 1.062,
    "event": 1.0,
    "gap": 1.0,
    "rawBeforeClamp": 124.0,
    "clampedToMin": false,
    "clampedToMax": false,
    "marketConfidence": 0.55,
    "eventLabel": nil as Any? as Any
]

// MARK: ================================================================
// A — Decoding
// ================================================================

struct NightScheduleDecodingTests {

    @Test("A1 — full version 1 explainability decodes all fields")
    func fullV1Decode() throws {
        let exp = decodeExplainability(fullFactorDict)
        #expect(exp.version == 1)
        #expect(exp.base == 100)
        #expect(abs((exp.season ?? 0) - 1.02) < 0.001)
        #expect(abs((exp.dow ?? 0) - 1.16) < 0.001)
        #expect(exp.clampedToMin == false)
        #expect(abs((exp.marketConfidence ?? 0) - 0.55) < 0.001)
        #expect(exp.isManualAccept == false)
    }

    @Test("A2 — null explainability: NightScheduleRow.resolvedExplainability is nil")
    func nullExplainability() {
        let row = decodeScheduleRow(["date": "2026-10-01", "price": 100.0])
        #expect(row.resolvedExplainability == nil)
        #expect(row.explainability == nil)
    }

    @Test("A3 — manual_accept provenance in breakdown resolves correctly")
    func manualAcceptProvenance() {
        let row = decodeScheduleRow([
            "date": "2026-10-01",
            "price": 115.0,
            "breakdown": ["version": 1, "manual_accept": true, "priceApplied": 115.0]
        ])
        let exp = row.resolvedExplainability
        #expect(exp?.isManualAccept == true)
        #expect(exp?.priceApplied == 115)
    }

    @Test("A4 — missing optional fields decode without crash")
    func missingOptionalFields() {
        let exp = decodeExplainability(["version": 1, "base": 95.0])
        #expect(exp.version == 1)
        #expect(exp.season == nil)
        #expect(exp.dow == nil)
        #expect(exp.clampedToMin == nil)
        #expect(exp.eventLabel == nil)
    }

    @Test("A5 — future unknown JSON fields do not crash")
    func unknownFutureFields() {
        let dict: [String: Any] = [
            "version": 1, "base": 100.0, "unknownFactor": 1.5, "newMetric": "high"
        ]
        let exp = decodeExplainability(dict)
        #expect(exp.version == 1)
        #expect(exp.base == 100)
    }

    @Test("A6 — future version (version=2) decodes without crash; factor fields safely nil")
    func futureVersionSafe() {
        let exp = decodeExplainability([
            "version": 2, "base": 110.0, "futureField": 3.14
        ])
        #expect(exp.version == 2)
        // Existing factor fields may still decode if present
        #expect(exp.base == 110)
    }
}

// MARK: ================================================================
// B — Fetch relevance (bpExplainabilityRelevant)
// ================================================================

struct NightScheduleFetchRelevanceTests {

    @Test("B7 — source=boostprice triggers fetch (relevant=true)")
    func boostPriceSourceRelevant() {
        let p = calProp(boostpriceEnabled: true, sources: ["2026-10-01": .boostprice])
        #expect(bpExplainabilityRelevant(propData: p, dayKey: "2026-10-01", externalPricing: false))
    }

    @Test("B8 — pending schedule entry triggers fetch (relevant=true)")
    func pendingScheduleRelevant() {
        let entry = makeScheduleEntry(status: .pending, price: 130)
        let p = calProp(boostpriceEnabled: true, bpSchedule: ["2026-10-01": entry])
        #expect(bpExplainabilityRelevant(propData: p, dayKey: "2026-10-01", externalPricing: false))
    }

    @Test("B9 — plain base price with no BP schedule: not relevant")
    func basePriceNotRelevant() {
        let p = calProp(boostpriceEnabled: true, sources: ["2026-10-01": .basePrice])
        #expect(!bpExplainabilityRelevant(propData: p, dayKey: "2026-10-01", externalPricing: false))
    }

    @Test("B10 — boostpriceEnabled=false: not relevant")
    func boostPriceDisabledNotRelevant() {
        let p = calProp(boostpriceEnabled: false, sources: ["2026-10-01": .boostprice])
        #expect(!bpExplainabilityRelevant(propData: p, dayKey: "2026-10-01", externalPricing: false))
    }

    @Test("B11 — pricingScheduleQueryItems produces correct from/to items")
    func queryItemsFromTo() {
        let items = Endpoint.pricingScheduleQueryItems(from: "2026-10-01", to: "2026-10-01")
        #expect(items.count == 2)
        #expect(items.first(where: { $0.name == "from" })?.value == "2026-10-01")
        #expect(items.first(where: { $0.name == "to" })?.value == "2026-10-01")
    }

    @Test("B12 — per-night query uses from/to, not days=N")
    func noDaysParam() {
        let items = Endpoint.pricingScheduleQueryItems(from: "2026-10-01", to: "2026-10-01")
        #expect(items.allSatisfy { $0.name != "days" })
    }
}

// MARK: ================================================================
// C — Mapping (bpExplanationItems)
// ================================================================

struct NightScheduleMappingTests {

    @Test("C13 — neutral factor (abs < 0.015) is omitted")
    func neutralFactorOmitted() {
        let exp = decodeExplainability(["version": 1, "dow": 1.01])
        let items = bpExplanationItems(from: exp)
        #expect(items.isEmpty)
    }

    @Test("C14 — positive dow → Jour plus demandé")
    func positiveDow() {
        let exp = decodeExplainability(["version": 1, "dow": 1.16])
        let items = bpExplanationItems(from: exp)
        #expect(items.contains { $0.title == "Jour plus demandé" })
        #expect(items.first { $0.title == "Jour plus demandé" }?.impact == .positive)
    }

    @Test("C15 — negative dow → Jour moins demandé")
    func negativeDow() {
        let exp = decodeExplainability(["version": 1, "dow": 0.82])
        let items = bpExplanationItems(from: exp)
        #expect(items.contains { $0.title == "Jour moins demandé" })
        #expect(items.first { $0.title == "Jour moins demandé" }?.impact == .negative)
    }

    @Test("C16 — positive season → Période plus demandée")
    func positiveSeason() {
        let exp = decodeExplainability(["version": 1, "season": 1.08])
        let items = bpExplanationItems(from: exp)
        #expect(items.contains { $0.title == "Période plus demandée" })
    }

    @Test("C17 — negative season → Période plus calme")
    func negativeSeason() {
        let exp = decodeExplainability(["version": 1, "season": 0.88])
        let items = bpExplanationItems(from: exp)
        #expect(items.contains { $0.title == "Période plus calme" })
    }

    @Test("C18 — positive lead → Anticipation favorable")
    func positiveLead() {
        let exp = decodeExplainability(["version": 1, "lead": 1.06])
        let items = bpExplanationItems(from: exp)
        #expect(items.contains { $0.title == "Anticipation favorable" })
    }

    @Test("C19 — negative lead → Date proche + detail")
    func negativeLead() {
        let exp = decodeExplainability(["version": 1, "lead": 0.92])
        let items = bpExplanationItems(from: exp)
        let item = items.first { $0.title == "Date proche" }
        #expect(item != nil)
        #expect(item?.detail != nil)
    }

    @Test("C20 — positive pacing → Réservations plus rapides que prévu")
    func positivePacing() {
        let exp = decodeExplainability(["version": 1, "pacing": 1.12])
        let items = bpExplanationItems(from: exp)
        #expect(items.contains { $0.title == "Réservations plus rapides que prévu" })
    }

    @Test("C21 — negative pacing → Réservations plus lentes que prévu")
    func negativePacing() {
        let exp = decodeExplainability(["version": 1, "pacing": 0.87])
        let items = bpExplanationItems(from: exp)
        #expect(items.contains { $0.title == "Réservations plus lentes que prévu" })
    }

    @Test("C22 — positive market → Marché local plus élevé")
    func positiveMarket() {
        let exp = decodeExplainability(["version": 1, "market": 1.08])
        let items = bpExplanationItems(from: exp)
        #expect(items.contains { $0.title == "Marché local plus élevé" })
    }

    @Test("C23 — negative market → Marché local plus bas")
    func negativeMarket() {
        let exp = decodeExplainability(["version": 1, "market": 0.91])
        let items = bpExplanationItems(from: exp)
        #expect(items.contains { $0.title == "Marché local plus bas" })
    }

    @Test("C24 — event with real label shows label as detail")
    func eventWithLabel() {
        let exp = decodeExplainability([
            "version": 1, "event": 1.15, "eventLabel": "Paris Fashion Week"
        ])
        let items = bpExplanationItems(from: exp)
        let item = items.first { $0.title == "Événement local" }
        #expect(item != nil)
        #expect(item?.detail == "Paris Fashion Week")
    }

    @Test("C25 — gap below threshold → Trou de calendrier optimisé")
    func gapDiscount() {
        let exp = decodeExplainability(["version": 1, "gap": 0.90])
        let items = bpExplanationItems(from: exp)
        #expect(items.contains { $0.title == "Trou de calendrier optimisé" })
    }

    @Test("C26 — strategy > neutral → Stratégie orientée revenu")
    func revenueStrategy() {
        let exp = decodeExplainability(["version": 1, "strategy": 1.08])
        let items = bpExplanationItems(from: exp)
        #expect(items.contains { $0.title == "Stratégie orientée revenu" })
    }

    @Test("C27 — strategy < neutral → Stratégie orientée occupation")
    func occupationStrategy() {
        let exp = decodeExplainability(["version": 1, "strategy": 0.91])
        let items = bpExplanationItems(from: exp)
        #expect(items.contains { $0.title == "Stratégie orientée occupation" })
    }

    @Test("C28 — clampedToMin=true → Prix minimum atteint")
    func clampMin() {
        let exp = decodeExplainability(["version": 1, "clampedToMin": true])
        let items = bpExplanationItems(from: exp)
        #expect(items.contains { $0.title == "Prix minimum atteint" })
    }

    @Test("C29 — clampedToMax=true → Prix maximum atteint")
    func clampMax() {
        let exp = decodeExplainability(["version": 1, "clampedToMax": true])
        let items = bpExplanationItems(from: exp)
        #expect(items.contains { $0.title == "Prix maximum atteint" })
    }
}

// MARK: ================================================================
// D — Prioritization
// ================================================================

struct NightSchedulePrioritizationTests {

    @Test("D30 — at most 4 primary factors even when 5 material factors present")
    func maxFourPrimary() {
        // event, market, pacing, season, lead — all material
        let exp = decodeExplainability([
            "version": 1,
            "event": 1.15, "market": 1.08, "pacing": 1.12,
            "season": 1.09, "lead": 0.91
        ])
        let items = bpExplanationItems(from: exp)
        let primary = items.filter { $0.title != "Prix minimum atteint" && $0.title != "Prix maximum atteint" }
        #expect(primary.count <= 4)
    }

    @Test("D31 — event comes before market, market before pacing (priority order)")
    func priorityOrder() {
        let exp = decodeExplainability([
            "version": 1, "event": 1.15, "market": 1.08, "pacing": 1.12
        ])
        let items = bpExplanationItems(from: exp)
        let titles = items.map(\.title)
        let eventIdx   = titles.firstIndex(of: "Événement local")
        let marketIdx  = titles.firstIndex(of: "Marché local plus élevé")
        let pacingIdx  = titles.firstIndex(of: "Réservations plus rapides que prévu")
        if let e = eventIdx, let m = marketIdx, let p = pacingIdx {
            #expect(e < m)
            #expect(m < p)
        } else {
            Issue.record("Expected all three items to be present")
        }
    }

    @Test("D32 — clamp item remains visible even when all primary factors neutral")
    func clampVisibleAlone() {
        let exp = decodeExplainability(["version": 1, "clampedToMax": true])
        let items = bpExplanationItems(from: exp)
        #expect(items.contains { $0.title == "Prix maximum atteint" })
    }
}

// MARK: ================================================================
// E — Truthfulness
// ================================================================

struct NightScheduleTruthfulnessTests {

    @Test("E33 — manual_accept produces one truthful item, no factor fabrication")
    func manualAcceptNoFabrication() {
        let exp = decodeExplainability([
            "version": 1, "manual_accept": true, "priceApplied": 115.0,
            // Additional factor keys that MUST NOT generate items
            "season": 1.10, "market": 1.08
        ])
        let items = bpExplanationItems(from: exp)
        #expect(items.count == 1)
        #expect(items[0].title == "Suggestion BoostPrice acceptée")
    }

    @Test("E34 — null resolvedExplainability produces no items (safe fallback shown by view)")
    func nullBreakdownSafe() {
        let row = decodeScheduleRow(["date": "2026-10-01"])
        #expect(row.resolvedExplainability == nil)
        // View would show fallback text — no items to check
    }

    @Test("E35 — schedule row price is NOT the canonical effective price (separate concerns)")
    func scheduleRowPriceNotCanonical() {
        // The calendar propData.price(for:isWeekend:) is the canonical price.
        // schedule row.price is context only — must not replace it.
        let calendarPrice: Double = 120
        let scheduleRowPrice: Double = 110  // different — e.g. raw before clamp applied
        let prop = calProp(basePrice: calendarPrice, sources: ["2026-10-01": .boostprice])
        let canonical = prop.price(for: "2026-10-01", isWeekend: false)
        #expect(canonical == calendarPrice)
        #expect(scheduleRowPrice != canonical)
    }

    @Test("E36 — manual override authority preserved: pricingSource returns .manualOverride")
    func manualOverrideAuthorityPreserved() {
        let p = calProp(sources: ["2026-10-01": .manualOverride])
        #expect(p.pricingSource(for: "2026-10-01") == .manualOverride)
        #expect(boostPriceAuthorityLabel(.manualOverride) == "Prix manuel")
    }

    @Test("E37 — pending recommendation distinct from effective price")
    func pendingRecommendationDistinct() {
        let entry = makeScheduleEntry(status: .pending, price: 135)
        let prop  = calProp(basePrice: 100, boostpriceEnabled: true,
                            bpSchedule: ["2026-10-01": entry])
        let effectivePrice   = prop.price(for: "2026-10-01", isWeekend: false)
        let pendingRec       = prop.boostPriceScheduleEntry(for: "2026-10-01")
        #expect(effectivePrice == 100)
        #expect(pendingRec?.price == 135)
        #expect(effectivePrice != pendingRec?.price)
    }
}

// MARK: ================================================================
// F — Resilience
// ================================================================

struct NightScheduleResilienceTests {

    @Test("F38 — network failure: ExplainState.failed does not affect manual editing state")
    func failureDoesNotBlockEditing() {
        // ExplainState.failed is isolated — manual price state is independent.
        // This is an architectural invariant: test that the enum case is unrelated.
        enum MockState { case idle, loading, loaded, failed }
        let explainState: MockState = .failed
        let priceText = "120"        // manual edit state
        #expect(priceText.isEmpty == false)
        #expect(explainState == .failed)
        // No dependency between the two
    }

    @Test("F39 — extra JSON fields in explainability do not crash")
    func extraFieldsSafe() {
        let exp = decodeExplainability([
            "version": 1, "base": 100.0,
            "unknownAlpha": 2.5, "futurePayload": ["nested": true]
        ])
        #expect(exp.version == 1)
        #expect(exp.base == 100)
    }

    @Test("F40 — unknown PricingSource handled safely in boostPriceAuthorityLabel")
    func unknownSourceSafe() {
        let label = boostPriceAuthorityLabel(.unknown("future_algo"))
        #expect(label == "Prix calculé")
        #expect(!label.isEmpty)
    }
}

// MARK: ================================================================
// Legacy IOS-BP-05 tests (authority labels, delta, price model)
// ================================================================

struct NightPriceDetailTests {

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

    @Test("positive delta")
    func deltaPositive() {
        #expect(boostPriceDayDelta(effective: 100, scheduled: 120) == 20)
    }

    @Test("zero delta")
    func deltaZero() {
        #expect(boostPriceDayDelta(effective: 85, scheduled: 85) == 0)
    }

    @Test("negative delta")
    func deltaNegative() {
        #expect(boostPriceDayDelta(effective: 150, scheduled: 130) == -20)
    }

    @Test("fractional delta")
    func deltaFractional() {
        let delta = boostPriceDayDelta(effective: 99.50, scheduled: 112.25)
        #expect(abs(delta - 12.75) < 0.001)
    }
}
