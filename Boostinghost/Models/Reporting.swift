import Foundation

// MARK: - Response envelope

struct ReportingResponse: Decodable {
    let summary:    ReportingSummary
    let monthly:    [MonthlyData]?
    let platforms:  [PlatformRevenuStat]?
    let byProperty: [PropertyRevenuStat]?
}

// MARK: - Summary
// All field names documented in 03-api-contracts.md.
// All amounts decoded tolerantly — backend may send Double, Int, or String.

struct ReportingSummary: Decodable {
    // Monetary aggregates: nil when backend returns null (mixed currencies — cross-currency sum not meaningful).
    // Non-nil when mono-currency or legacy backend (treated as EUR).
    let totalGrossRevenue:   Double?
    let totalNetRevenue:     Double?
    let totalOwnerRevenue:   Double?
    let totalConcierge:      Double?
    let totalOtaCommission:  Double?
    let totalCleaningFee:    Double?
    let totalTouristTax:     Double?
    let totalBookings:       Int
    let totalNights:         Int
    let avgNightsPerBooking: Double
    let pendingGrossRevenue: Double?
    let pendingBookings:     Int
    // nil currencies = legacy backend (field absent from JSON).
    // singleCurrency nil + currencies non-empty = mixed currencies.
    let singleCurrency: String?
    let currencies:     [String]?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Monetary fields are nullable when multi-currency; flexDouble returns nil for JSON null.
        totalGrossRevenue   = c.flexDouble(forKey: .totalGrossRevenue)
        totalNetRevenue     = c.flexDouble(forKey: .totalNetRevenue)
        totalOwnerRevenue   = c.flexDouble(forKey: .totalOwnerRevenue)
        totalConcierge      = c.flexDouble(forKey: .totalConcierge)
        totalOtaCommission  = c.flexDouble(forKey: .totalOtaCommission)
        totalCleaningFee    = c.flexDouble(forKey: .totalCleaningFee)
        totalTouristTax     = c.flexDouble(forKey: .totalTouristTax)
        totalBookings       = c.flexInt(forKey: .totalBookings)          ?? 0
        totalNights         = c.flexInt(forKey: .totalNights)            ?? 0
        avgNightsPerBooking = c.flexDouble(forKey: .avgNightsPerBooking) ?? 0
        pendingGrossRevenue = c.flexDouble(forKey: .pendingGrossRevenue)
        pendingBookings     = c.flexInt(forKey: .pendingBookings)        ?? 0
        singleCurrency      = try? c.decodeIfPresent(String.self,   forKey: .singleCurrency)
        currencies          = try? c.decodeIfPresent([String].self,  forKey: .currencies)
    }

    private enum CodingKeys: String, CodingKey {
        case totalGrossRevenue, totalNetRevenue, totalOwnerRevenue, totalConcierge
        case totalOtaCommission, totalCleaningFee, totalTouristTax
        case totalBookings, totalNights, avgNightsPerBooking
        case pendingGrossRevenue, pendingBookings
        case singleCurrency, currencies
    }
}

// MARK: - Platform stat

struct PlatformRevenuStat: Decodable, Identifiable {
    let id                = UUID()
    let name:             String?
    let revenue:          Double?
    let revenueByCurrency: [String: Double]?
    let pendingRevenue:   Double
    let pct:              Double
    let nights:           Int
    let bookings:         Int

    init(from decoder: Decoder) throws {
        let c             = try decoder.container(keyedBy: CodingKeys.self)
        name              = try? c.decodeIfPresent(String.self, forKey: .name)
        revenue           = c.flexDouble(forKey: .revenue)
        revenueByCurrency = try? c.decodeIfPresent([String: Double].self, forKey: .revenueByCurrency)
        pendingRevenue    = c.flexDouble(forKey: .pendingRevenue) ?? 0
        pct               = c.flexDouble(forKey: .pct)            ?? 0
        nights            = c.flexInt(forKey: .nights)            ?? 0
        bookings          = c.flexInt(forKey: .bookings)          ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case name, revenue, revenueByCurrency, pendingRevenue, pct, nights, bookings
    }
}

// MARK: - Property stat

struct PropertyRevenuStat: Decodable, Identifiable {
    let id:                  String
    let name:                String
    let colorHex:            String?
    let currency:            String?
    let nights:              Int
    let grossRevenue:        Double
    let pendingGrossRevenue: Double
    let pendingBookings:     Int

    init(from decoder: Decoder) throws {
        let c               = try decoder.container(keyedBy: CodingKeys.self)
        id                  = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        name                = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "—"
        colorHex            = try? c.decodeIfPresent(String.self, forKey: .color)
        currency            = try? c.decodeIfPresent(String.self, forKey: .currency)
        nights              = c.flexInt(forKey: .nights)              ?? 0
        grossRevenue        = c.flexDouble(forKey: .grossRevenue)        ?? 0
        pendingGrossRevenue = c.flexDouble(forKey: .pendingGrossRevenue) ?? 0
        pendingBookings     = c.flexInt(forKey: .pendingBookings)        ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, color, currency, nights, grossRevenue, pendingGrossRevenue, pendingBookings
    }
}

// MARK: - Monthly data (received, not displayed in app v1)

struct MonthlyData: Decodable {
    let month:   Int
    let revenue: Double

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        month   = c.flexInt(forKey: .month)     ?? 0
        revenue = c.flexDouble(forKey: .revenue) ?? c.flexDouble(forKey: .grossRevenue) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case month, revenue, grossRevenue
    }
}

// MARK: - Reporting currency state

enum ReportingCurrencyState {
    /// All amounts in this period share one currency — safe to display.
    case single(String)
    /// Amounts span multiple currencies — suppress monetary display.
    case mixed([String])
    /// Backend pre-dates currency metadata, or period has no reservations — treat as EUR.
    case legacyEUR

    init(summary: ReportingSummary) {
        guard let allCurrencies = summary.currencies else {
            self = .legacyEUR; return
        }
        if allCurrencies.isEmpty {
            self = .legacyEUR; return
        }
        if let code = summary.singleCurrency {
            self = .single(Formatters.normalizeCurrency(code))
        } else {
            self = .mixed(allCurrencies)
        }
    }

    /// Currency code when safe; nil when mixed.
    var currencyCode: String? {
        switch self {
        case .single(let c): return c
        case .legacyEUR:     return "EUR"
        case .mixed:         return nil
        }
    }

    /// Format `amount` in the appropriate currency, or "—" when mixed.
    func format(_ amount: Double) -> String {
        guard let code = currencyCode else { return "—" }
        return Formatters.amount(amount, currency: code)
    }

    /// Format an optional amount; nil (multi-currency null from backend) displays as "—".
    func format(_ amount: Double?) -> String {
        guard let amount else { return "—" }
        return format(amount)
    }
}
