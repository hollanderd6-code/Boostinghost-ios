import Foundation

// MARK: - GET /api/pricing/schedule/:propertyId?from=YYYY-MM-DD&to=YYYY-MM-DD
//
// Backend commit 4df1aa76 — agency/delegation safe.
// For one night: from = to = selected date.
// Do NOT use legacy ?days=N for per-night explainability.

struct NightScheduleResponse: Decodable {
    let nights:     [NightScheduleRow]
    let mode:       String?
    let isActive:   Bool?
    let configured: Bool?

    init(from decoder: Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        nights    = (try? c.decode([NightScheduleRow].self, forKey: .nights)) ?? []
        mode      = try? c.decodeIfPresent(String.self, forKey: .mode)
        isActive  = try? c.decodeIfPresent(Bool.self, forKey: .isActive)
        configured = try? c.decodeIfPresent(Bool.self, forKey: .configured)
    }

    private enum CodingKeys: CodingKey {
        case nights, mode, isActive, configured
    }
}

struct NightScheduleRow: Decodable {
    let date:           String
    let price:          Double?
    let minStay:        Int?
    let reason:         String?
    let status:         String?
    // version-1 factor breakdown (nil on legacy rows and manual_accept rows)
    let explainability: NightExplainability?
    // manual_accept provenance payload  (nil on factor-based rows)
    let breakdown:      NightExplainability?

    init(from decoder: Decoder) throws {
        let c          = try decoder.container(keyedBy: CodingKeys.self)
        date           = (try? c.decodeIfPresent(String.self, forKey: .date)) ?? ""
        price          = c.flexDouble(forKey: .price)
        minStay        = c.flexInt(forKey: .minStay)
        reason         = try? c.decodeIfPresent(String.self, forKey: .reason)
        status         = try? c.decodeIfPresent(String.self, forKey: .status)
        explainability = try? c.decodeIfPresent(NightExplainability.self, forKey: .explainability)
        breakdown      = try? c.decodeIfPresent(NightExplainability.self, forKey: .breakdown)
    }

    // Authoritative explainability for this night.
    // Factor breakdown takes precedence; manual_accept provenance used only when
    // explainability is nil and breakdown carries manual_accept == true.
    var resolvedExplainability: NightExplainability? {
        if let e = explainability { return e }
        if let b = breakdown, b.isManualAccept { return b }
        return nil
    }

    private enum CodingKeys: CodingKey {
        case date, price, minStay, reason, status, explainability, breakdown
    }
}

// MARK: - NightExplainability
//
// Shared shape for both factor-based breakdown (version 1) and manual_accept
// provenance rows.  All fields optional — old/null rows must remain safe.
// Version guard: parse version 1 normally; unknown version: do not crash but
// factor fields will likely be absent.

struct NightExplainability: Decodable, Equatable {

    // Version guard
    let version:          Int?

    // Factor multipliers (absent on manual_accept rows)
    let base:             Double?
    let season:           Double?
    let dow:              Double?
    let lead:             Double?
    let pacing:           Double?
    let strategy:         Double?
    let market:           Double?
    let event:            Double?
    let gap:              Double?

    // Clamp metadata
    let rawBeforeClamp:   Double?
    let clampedToMin:     Bool?
    let clampedToMax:     Bool?

    // Market metadata
    let marketConfidence: Double?
    let eventLabel:       String?

    // Manual acceptance provenance (present only on manual_accept rows)
    let manualAccept:     Bool?
    let priceApplied:     Double?

    var isManualAccept: Bool { manualAccept == true }

    init(from decoder: Decoder) throws {
        let c            = try decoder.container(keyedBy: CodingKeys.self)
        version          = c.flexInt(forKey: .version)
        base             = c.flexDouble(forKey: .base)
        season           = c.flexDouble(forKey: .season)
        dow              = c.flexDouble(forKey: .dow)
        lead             = c.flexDouble(forKey: .lead)
        pacing           = c.flexDouble(forKey: .pacing)
        strategy         = c.flexDouble(forKey: .strategy)
        market           = c.flexDouble(forKey: .market)
        event            = c.flexDouble(forKey: .event)
        gap              = c.flexDouble(forKey: .gap)
        rawBeforeClamp   = c.flexDouble(forKey: .rawBeforeClamp)
        clampedToMin     = try? c.decodeIfPresent(Bool.self, forKey: .clampedToMin)
        clampedToMax     = try? c.decodeIfPresent(Bool.self, forKey: .clampedToMax)
        marketConfidence = c.flexDouble(forKey: .marketConfidence)
        eventLabel       = try? c.decodeIfPresent(String.self, forKey: .eventLabel)
        manualAccept     = try? c.decodeIfPresent(Bool.self, forKey: .manualAccept)
        priceApplied     = c.flexDouble(forKey: .priceApplied)
    }

    private enum CodingKeys: CodingKey {
        case version
        case base, season, dow, lead, pacing, strategy, market, event, gap
        case rawBeforeClamp, clampedToMin, clampedToMax
        case marketConfidence, eventLabel
        case manualAccept, priceApplied
    }
}
