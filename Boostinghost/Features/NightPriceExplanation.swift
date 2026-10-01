import Foundation

// MARK: - Presentation model

struct BoostPriceExplanationItem: Equatable {
    enum Impact: Equatable { case positive, negative, neutral }

    let icon:   String   // SF symbol name
    let title:  String
    let detail: String?
    let impact: Impact
}

// MARK: - Materiality threshold
//
// Factors within ±1.5% of 1.0 are considered neutral and produce no explanation row.
// Exception: event and gap may be shown below this threshold when semantically relevant.
let bpExplanationThreshold: Double = 0.015

func bpIsNeutral(_ value: Double?) -> Bool {
    guard let v = value else { return true }
    return abs(v - 1.0) < bpExplanationThreshold
}

// MARK: - Fetch relevance
//
// Returns true when per-night explainability should be fetched for this cell.
// Must be deterministic and testable.

func bpExplainabilityRelevant(
    propData: PricingCalendarProperty?,
    dayKey: String,
    externalPricing: Bool
) -> Bool {
    guard !externalPricing else { return false }
    guard let propData, propData.isBoostPriceEnabled else { return false }
    let source     = propData.pricingSource(for: dayKey)
    let hasPending = propData.hasPendingRecommendation(for: dayKey)
    return source == .boostprice || hasPending
}

// MARK: - Explanation item mapping
//
// Derives presentation items from NightExplainability.
// Factor priority (spec §22): event, market, pacing, gap, dow, season, lead, strategy.
// At most 4 primary items; clamp appended separately when relevant.
// Manual_accept rows produce one truthful item only — no fabricated factors.

func bpExplanationItems(
    from exp: NightExplainability,
    date: Date? = nil
) -> [BoostPriceExplanationItem] {

    if exp.isManualAccept {
        return [BoostPriceExplanationItem(
            icon:   "checkmark.circle.fill",
            title:  "Suggestion BoostPrice acceptée",
            detail: "Ce tarif provient d'une recommandation que vous avez validée.",
            impact: .neutral
        )]
    }

    var primary: [BoostPriceExplanationItem] = []
    var clampItem: BoostPriceExplanationItem?

    // Clamp — kept separate; remains visible even when all factors are neutral.
    if exp.clampedToMin == true {
        clampItem = BoostPriceExplanationItem(
            icon:   "arrow.down.to.line",
            title:  "Prix minimum atteint",
            detail: "BoostPrice n'est pas descendu sous votre limite.",
            impact: .neutral
        )
    } else if exp.clampedToMax == true {
        clampItem = BoostPriceExplanationItem(
            icon:   "arrow.up.to.line",
            title:  "Prix maximum atteint",
            detail: "BoostPrice n'a pas dépassé votre limite.",
            impact: .neutral
        )
    }

    // 1. Event
    if let v = exp.event, !bpIsNeutral(v) {
        let label = exp.eventLabel.flatMap { $0.isEmpty ? nil : $0 }
        primary.append(BoostPriceExplanationItem(
            icon:   "calendar.badge.exclamationmark",
            title:  "Événement local",
            detail: label,
            impact: v > 1.0 ? .positive : .negative
        ))
    }

    // 2. Market
    if let v = exp.market, !bpIsNeutral(v) {
        primary.append(BoostPriceExplanationItem(
            icon:   "chart.bar.fill",
            title:  v > 1.0 ? "Marché local plus élevé" : "Marché local plus bas",
            detail: nil,
            impact: v > 1.0 ? .positive : .negative
        ))
    }

    // 3. Pacing
    if let v = exp.pacing, !bpIsNeutral(v) {
        primary.append(BoostPriceExplanationItem(
            icon:   v > 1.0 ? "arrow.up.right" : "arrow.down.right",
            title:  v > 1.0 ? "Réservations plus rapides que prévu" : "Réservations plus lentes que prévu",
            detail: nil,
            impact: v > 1.0 ? .positive : .negative
        ))
    }

    // 4. Gap (only when gap decreases price — semantic discount)
    if let v = exp.gap, v < (1.0 - bpExplanationThreshold) {
        primary.append(BoostPriceExplanationItem(
            icon:   "calendar.badge.minus",
            title:  "Trou de calendrier optimisé",
            detail: "Tarif ajusté pour favoriser la réservation de cette nuit.",
            impact: .negative
        ))
    }

    // 5. Day of week
    if let v = exp.dow, !bpIsNeutral(v) {
        let isFridayOrSaturday: Bool = {
            guard let d = date else { return false }
            var utcCal = Calendar(identifier: .gregorian)
            utcCal.timeZone = TimeZone(identifier: "UTC")!
            let w = utcCal.component(.weekday, from: d)
            return w == 6 || w == 7   // Fri=6, Sat=7 in Gregorian 1-based weekday
        }()
        let title: String
        if v > 1.0 {
            title = isFridayOrSaturday ? "Week-end plus demandé" : "Jour plus demandé"
        } else {
            title = "Jour moins demandé"
        }
        primary.append(BoostPriceExplanationItem(
            icon:   "calendar",
            title:  title,
            detail: nil,
            impact: v > 1.0 ? .positive : .negative
        ))
    }

    // 6. Season
    if let v = exp.season, !bpIsNeutral(v) {
        primary.append(BoostPriceExplanationItem(
            icon:   v > 1.0 ? "sun.max.fill" : "leaf.fill",
            title:  v > 1.0 ? "Période plus demandée" : "Période plus calme",
            detail: nil,
            impact: v > 1.0 ? .positive : .negative
        ))
    }

    // 7. Lead time
    if let v = exp.lead, !bpIsNeutral(v) {
        primary.append(BoostPriceExplanationItem(
            icon:   v > 1.0 ? "clock.badge.checkmark" : "clock.badge.exclamationmark",
            title:  v > 1.0 ? "Anticipation favorable" : "Date proche",
            detail: v < 1.0 ? "BoostPrice adapte le tarif selon la proximité de l'arrivée." : nil,
            impact: v > 1.0 ? .positive : .negative
        ))
    }

    // 8. Strategy
    if let v = exp.strategy, !bpIsNeutral(v) {
        primary.append(BoostPriceExplanationItem(
            icon:   "slider.horizontal.3",
            title:  v > 1.0 ? "Stratégie orientée revenu" : "Stratégie orientée occupation",
            detail: nil,
            impact: v > 1.0 ? .positive : .negative
        ))
    }

    let top4 = Array(primary.prefix(4))
    if let clamp = clampItem {
        return top4 + [clamp]
    }
    return top4
}
