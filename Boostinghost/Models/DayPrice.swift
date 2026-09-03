import Foundation

// MARK: - DayPriceResponse
//
// GET /api/host/pricing/calendar/:propertyId
// Returns a top-level dict {"YYYY-MM-DD": <Double or String>}.
// The server stores prices as NUMERIC; some records arrive unparsed (String).
//
// TEST: price as String — decode {"2026-09-19":"150.00"} → prices["2026-09-19"] == 150.0

struct DayPriceResponse: Decodable {
    let prices: [String: Double]

    init(from decoder: Decoder) throws {
        let c   = try decoder.singleValueContainer()
        let raw = try c.decode([String: FlexPrice].self)
        prices  = raw.compactMapValues { $0.value }
    }
}

private enum FlexPrice: Decodable {
    case number(Double)
    case text(String)

    var value: Double? {
        switch self {
        case .number(let d): return d
        case .text(let s):   return Double(s)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) { self = .number(d); return }
        let s = try c.decode(String.self)
        self = .text(s)
    }
}

// MARK: - POST /api/pricing/overrides

struct PriceOverrideBody: Encodable {
    let property_id: String   // snake_case — matches server expectation
    let date:        String   // "YYYY-MM-DD"
    let price:       Double
}
