import Foundation

// MARK: - GET /api/reservations-with-deposits (tableau nu, pas enveloppé)

struct ReservationWithDeposit: Decodable {
    let deposit: Deposit?

    struct Deposit: Decodable {
        let status: String?
    }
}

// MARK: - GET /api/subscription/status (périmètre compte propre, sans agency=all)

struct SubscriptionStatus: Decodable {
    let planType: String?
    let propertiesUsed: Int?
    let propertiesLimit: Int?
}
