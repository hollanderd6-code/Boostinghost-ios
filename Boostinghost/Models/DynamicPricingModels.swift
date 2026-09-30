import Foundation

// MARK: - Shared mode enum

enum DynamicPricingMode: Decodable, Equatable {
    case off
    case suggestion
    case auto
    case manual
    case unknown(String)

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "off":        self = .off
        case "suggestion": self = .suggestion
        case "auto":       self = .auto
        case "manual":     self = .manual
        default:           self = .unknown(raw)
        }
    }
}

// MARK: - GET /api/dynamic-pricing/config

struct DynamicPricingConfig: Decodable, Identifiable {
    let id:           String
    let propertyId:   String
    let propertyName: String?
    let priceMin:     Double?
    let priceMax:     Double?
    let mode:         DynamicPricingMode
    let isActive:     Bool?
    let notifyPush:   Bool?
    let notifyEmail:  Bool?
    let notifyAlert:  Bool?
    let zoneRadiusKm: Double?
    let propertyType: String?
    let bedrooms:     Int?
    let strategy:     Int?
    let createdAt:    String?
    let updatedAt:    String?

    init(from decoder: Decoder) throws {
        let c        = try decoder.container(keyedBy: CodingKeys.self)
        id           = c.flexString(forKey: .id) ?? ""
        propertyId   = c.flexString(forKey: .propertyId) ?? ""
        propertyName = try? c.decodeIfPresent(String.self, forKey: .propertyName)
        priceMin     = c.flexDouble(forKey: .priceMin)
        priceMax     = c.flexDouble(forKey: .priceMax)
        mode         = (try? c.decode(DynamicPricingMode.self, forKey: .mode)) ?? .off
        isActive     = try? c.decodeIfPresent(Bool.self, forKey: .isActive)
        notifyPush   = try? c.decodeIfPresent(Bool.self, forKey: .notifyPush)
        notifyEmail  = try? c.decodeIfPresent(Bool.self, forKey: .notifyEmail)
        notifyAlert  = try? c.decodeIfPresent(Bool.self, forKey: .notifyAlert)
        zoneRadiusKm = c.flexDouble(forKey: .zoneRadiusKm)
        propertyType = try? c.decodeIfPresent(String.self, forKey: .propertyType)
        bedrooms     = c.flexInt(forKey: .bedrooms)
        strategy     = c.flexInt(forKey: .strategy)
        createdAt    = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt    = try? c.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    private enum CodingKeys: CodingKey {
        case id, propertyId, propertyName, priceMin, priceMax, mode
        case isActive, notifyPush, notifyEmail, notifyAlert
        case zoneRadiusKm, propertyType, bedrooms, strategy, createdAt, updatedAt
    }
}

struct DynamicPricingConfigResponse: Decodable {
    let configs: [DynamicPricingConfig]

    init(from decoder: Decoder) throws {
        let c   = try decoder.container(keyedBy: CodingKeys.self)
        configs = (try? c.decode([DynamicPricingConfig].self, forKey: .configs)) ?? []
    }

    private enum CodingKeys: CodingKey {
        case configs
    }
}

// MARK: - GET /api/dynamic-pricing/dashboard

struct DynamicPricingMarket: Decodable {
    let weekStart:          String?
    let medianPrice:        Double?
    let priceP25:           Double?
    let priceP75:           Double?
    let occupancyRate:      Double?
    let comparableCount:    Int?
    let tensionLevel:       String?
    let tensionLabel:       String?
    let scrapedAt:          String?
    let currency:           String?
    let resolverStatus:     String?
    let usedForCalculation: Bool?
    let refreshRequired:    Bool?

    init(from decoder: Decoder) throws {
        let c              = try decoder.container(keyedBy: CodingKeys.self)
        weekStart          = try? c.decodeIfPresent(String.self, forKey: .weekStart)
        medianPrice        = c.flexDouble(forKey: .medianPrice)
        priceP25           = c.flexDouble(forKey: .priceP25)
        priceP75           = c.flexDouble(forKey: .priceP75)
        occupancyRate      = c.flexDouble(forKey: .occupancyRate)
        comparableCount    = c.flexInt(forKey: .comparableCount)
        tensionLevel       = try? c.decodeIfPresent(String.self, forKey: .tensionLevel)
        tensionLabel       = try? c.decodeIfPresent(String.self, forKey: .tensionLabel)
        scrapedAt          = try? c.decodeIfPresent(String.self, forKey: .scrapedAt)
        currency           = try? c.decodeIfPresent(String.self, forKey: .currency)
        resolverStatus     = try? c.decodeIfPresent(String.self, forKey: .resolverStatus)
        usedForCalculation = try? c.decodeIfPresent(Bool.self, forKey: .usedForCalculation)
        refreshRequired    = try? c.decodeIfPresent(Bool.self, forKey: .refreshRequired)
    }

    private enum CodingKeys: CodingKey {
        case weekStart, medianPrice, priceP25, priceP75, occupancyRate
        case comparableCount, tensionLevel, tensionLabel, scrapedAt, currency
        case resolverStatus, usedForCalculation, refreshRequired
    }
}

struct DynamicPricingHistoryEntry: Decodable {
    let historyId:       Int?    // pricing_history.id — present on new backend, absent on old
    let status:          String?
    let priceBefore:     Double?
    let priceCalculated: Double?
    let priceApplied:    Double?
    let modeUsed:        String?
    let reason:          String?
    let factorMarket:    Double?
    let factorSelf:      Double?
    let factorSeason:    Double?
    let appliedAt:       String?

    init(from decoder: Decoder) throws {
        let c           = try decoder.container(keyedBy: CodingKeys.self)
        historyId       = c.flexInt(forKey: .historyId)
        status          = try? c.decodeIfPresent(String.self, forKey: .status)
        priceBefore     = c.flexDouble(forKey: .priceBefore)
        priceCalculated = c.flexDouble(forKey: .priceCalculated)
        priceApplied    = c.flexDouble(forKey: .priceApplied)
        modeUsed        = try? c.decodeIfPresent(String.self, forKey: .modeUsed)
        reason          = try? c.decodeIfPresent(String.self, forKey: .reason)
        factorMarket    = c.flexDouble(forKey: .factorMarket)
        factorSelf      = c.flexDouble(forKey: .factorSelf)
        factorSeason    = c.flexDouble(forKey: .factorSeason)
        appliedAt       = try? c.decodeIfPresent(String.self, forKey: .appliedAt)
    }

    private enum CodingKeys: CodingKey {
        case historyId, status, priceBefore, priceCalculated, priceApplied
        case modeUsed, reason, factorMarket, factorSelf, factorSeason, appliedAt
    }
}

struct DynamicPricingDashboardProperty: Decodable, Identifiable {
    let propertyId:       String
    let propertyName:     String?
    let address:          String?
    let mode:             DynamicPricingMode?
    let priceMin:         Double?
    let priceMax:         Double?
    let notifyPush:       Bool?
    let propertyCurrency: String?
    let market:           DynamicPricingMarket?
    let history:          DynamicPricingHistoryEntry?

    var id: String { propertyId }

    init(from decoder: Decoder) throws {
        let c            = try decoder.container(keyedBy: CodingKeys.self)
        propertyId       = c.flexString(forKey: .propertyId) ?? ""
        propertyName     = try? c.decodeIfPresent(String.self, forKey: .propertyName)
        address          = try? c.decodeIfPresent(String.self, forKey: .address)
        mode             = try? c.decodeIfPresent(DynamicPricingMode.self, forKey: .mode)
        priceMin         = c.flexDouble(forKey: .priceMin)
        priceMax         = c.flexDouble(forKey: .priceMax)
        notifyPush       = try? c.decodeIfPresent(Bool.self, forKey: .notifyPush)
        propertyCurrency = try? c.decodeIfPresent(String.self, forKey: .propertyCurrency)
        market           = try? c.decodeIfPresent(DynamicPricingMarket.self, forKey: .market)
        history          = try? c.decodeIfPresent(DynamicPricingHistoryEntry.self, forKey: .history)
    }

    private enum CodingKeys: CodingKey {
        case propertyId, propertyName, address, mode, priceMin, priceMax
        case notifyPush, propertyCurrency, market, history
    }
}

// MARK: - GET /api/dynamic-pricing/history

struct DynamicPricingHistoryItem: Decodable, Identifiable {
    let id:               Int
    let propertyId:       String
    let weekStart:        String?
    let priceBefore:      Double?
    let priceCalculated:  Double?
    let priceApplied:     Double?
    let status:           String?
    let reason:           String?
    let tensionLevel:     String?
    let tensionLabel:     String?
    let marketOccupancy:  Double?
    let factorMarket:     Double?
    let factorSelf:       Double?
    let factorSeason:     Double?
    let appliedAt:        String?
    let propertyCurrency: String?

    init(from decoder: Decoder) throws {
        let c            = try decoder.container(keyedBy: CodingKeys.self)
        id               = c.flexInt(forKey: .id) ?? 0
        propertyId       = c.flexString(forKey: .propertyId) ?? ""
        weekStart        = try? c.decodeIfPresent(String.self, forKey: .weekStart)
        priceBefore      = c.flexDouble(forKey: .priceBefore)
        priceCalculated  = c.flexDouble(forKey: .priceCalculated)
        priceApplied     = c.flexDouble(forKey: .priceApplied)
        status           = try? c.decodeIfPresent(String.self, forKey: .status)
        reason           = try? c.decodeIfPresent(String.self, forKey: .reason)
        tensionLevel     = try? c.decodeIfPresent(String.self, forKey: .tensionLevel)
        tensionLabel     = try? c.decodeIfPresent(String.self, forKey: .tensionLabel)
        marketOccupancy  = c.flexDouble(forKey: .marketOccupancy)
        factorMarket     = c.flexDouble(forKey: .factorMarket)
        factorSelf       = c.flexDouble(forKey: .factorSelf)
        factorSeason     = c.flexDouble(forKey: .factorSeason)
        appliedAt        = try? c.decodeIfPresent(String.self, forKey: .appliedAt)
        propertyCurrency = try? c.decodeIfPresent(String.self, forKey: .propertyCurrency)
    }

    private enum CodingKeys: CodingKey {
        case id, propertyId, weekStart, priceBefore, priceCalculated, priceApplied
        case status, reason, tensionLevel, tensionLabel, marketOccupancy
        case factorMarket, factorSelf, factorSeason, appliedAt, propertyCurrency
    }
}

struct DynamicPricingHistoryListResponse: Decodable {
    let history: [DynamicPricingHistoryItem]
    let total:   Int

    init(from decoder: Decoder) throws {
        let c   = try decoder.container(keyedBy: CodingKeys.self)
        history = (try? c.decode([DynamicPricingHistoryItem].self, forKey: .history)) ?? []
        total   = c.flexInt(forKey: .total) ?? 0
    }

    private enum CodingKeys: CodingKey { case history, total }
}

// MARK: - POST /api/dynamic-pricing/config response

struct BoostPriceSaveResponse: Decodable {
    let success: Bool
}

// MARK: - POST /api/dynamic-pricing/decision response

struct BoostPriceDecisionResponse: Decodable {
    let success:      Bool
    let action:       String?
    let priceApplied: Double?

    init(from decoder: Decoder) throws {
        let c        = try decoder.container(keyedBy: CodingKeys.self)
        success      = (try? c.decodeIfPresent(Bool.self, forKey: .success)) ?? false
        action       = try? c.decodeIfPresent(String.self, forKey: .action)
        priceApplied = c.flexDouble(forKey: .priceApplied)
    }

    private enum CodingKeys: CodingKey { case success, action, priceApplied }
}

// MARK: -

struct DynamicPricingDashboardResponse: Decodable {
    let properties:           [DynamicPricingDashboardProperty]
    let pendingCount:         Int
    let weeklyGainByCurrency: [String: Double]?
    let weekStart:            String?

    init(
        properties: [DynamicPricingDashboardProperty],
        pendingCount: Int,
        weeklyGainByCurrency: [String: Double]?,
        weekStart: String?
    ) {
        self.properties           = properties
        self.pendingCount         = pendingCount
        self.weeklyGainByCurrency = weeklyGainByCurrency
        self.weekStart            = weekStart
    }

    init(from decoder: Decoder) throws {
        let c                = try decoder.container(keyedBy: CodingKeys.self)
        properties           = (try? c.decode([DynamicPricingDashboardProperty].self, forKey: .properties)) ?? []
        pendingCount         = c.flexInt(forKey: .pendingCount) ?? 0
        weeklyGainByCurrency = c.flexDoubleDict(forKey: .weeklyGainByCurrency)
        weekStart            = try? c.decodeIfPresent(String.self, forKey: .weekStart)
    }

    private enum CodingKeys: CodingKey {
        case properties, pendingCount, weeklyGainByCurrency, weekStart
    }
}
