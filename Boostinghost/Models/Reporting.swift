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
    let totalGrossRevenue:   Double
    let totalNetRevenue:     Double
    let totalOwnerRevenue:   Double
    let totalConcierge:      Double
    let totalOtaCommission:  Double
    let totalCleaningFee:    Double
    let totalTouristTax:     Double
    let totalBookings:       Int
    let totalNights:         Int
    let avgNightsPerBooking: Double
    let pendingGrossRevenue: Double
    let pendingBookings:     Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalGrossRevenue   = c.flexDouble(forKey: .totalGrossRevenue)   ?? 0
        totalNetRevenue     = c.flexDouble(forKey: .totalNetRevenue)     ?? 0
        totalOwnerRevenue   = c.flexDouble(forKey: .totalOwnerRevenue)   ?? 0
        totalConcierge      = c.flexDouble(forKey: .totalConcierge)      ?? 0
        totalOtaCommission  = c.flexDouble(forKey: .totalOtaCommission)  ?? 0
        totalCleaningFee    = c.flexDouble(forKey: .totalCleaningFee)    ?? 0
        totalTouristTax     = c.flexDouble(forKey: .totalTouristTax)     ?? 0
        totalBookings       = c.flexInt(forKey: .totalBookings)          ?? 0
        totalNights         = c.flexInt(forKey: .totalNights)            ?? 0
        avgNightsPerBooking = c.flexDouble(forKey: .avgNightsPerBooking) ?? 0
        pendingGrossRevenue = c.flexDouble(forKey: .pendingGrossRevenue) ?? 0
        pendingBookings     = c.flexInt(forKey: .pendingBookings)        ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case totalGrossRevenue, totalNetRevenue, totalOwnerRevenue, totalConcierge
        case totalOtaCommission, totalCleaningFee, totalTouristTax
        case totalBookings, totalNights, avgNightsPerBooking
        case pendingGrossRevenue, pendingBookings
    }
}

// MARK: - Platform stat

struct PlatformRevenuStat: Decodable, Identifiable {
    let id             = UUID()
    let name:          String?
    let revenue:       Double
    let pendingRevenue: Double
    let pct:           Double
    let nights:        Int
    let bookings:      Int

    init(from decoder: Decoder) throws {
        let c          = try decoder.container(keyedBy: CodingKeys.self)
        name           = try? c.decodeIfPresent(String.self, forKey: .name)
        revenue        = c.flexDouble(forKey: .revenue)        ?? 0
        pendingRevenue = c.flexDouble(forKey: .pendingRevenue) ?? 0
        pct            = c.flexDouble(forKey: .pct)            ?? 0
        nights         = c.flexInt(forKey: .nights)            ?? 0
        bookings       = c.flexInt(forKey: .bookings)          ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case name, revenue, pendingRevenue, pct, nights, bookings
    }
}

// MARK: - Property stat

struct PropertyRevenuStat: Decodable, Identifiable {
    let id:                  String
    let name:                String
    let colorHex:            String?
    let nights:              Int
    let grossRevenue:        Double
    let pendingGrossRevenue: Double
    let pendingBookings:     Int

    init(from decoder: Decoder) throws {
        let c               = try decoder.container(keyedBy: CodingKeys.self)
        id                  = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        name                = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "—"
        colorHex            = try? c.decodeIfPresent(String.self, forKey: .color)
        nights              = c.flexInt(forKey: .nights)              ?? 0
        grossRevenue        = c.flexDouble(forKey: .grossRevenue)        ?? 0
        pendingGrossRevenue = c.flexDouble(forKey: .pendingGrossRevenue) ?? 0
        pendingBookings     = c.flexInt(forKey: .pendingBookings)        ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, color, nights, grossRevenue, pendingGrossRevenue, pendingBookings
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
