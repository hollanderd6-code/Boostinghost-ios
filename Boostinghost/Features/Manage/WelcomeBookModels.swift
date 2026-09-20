import Foundation

// MARK: - WelcomeBook

struct WelcomeBook: Decodable {
    let uniqueId: String
    let propertyId: String?
    let publicUrl: String?
    let data: WelcomeBookData?
    let updatedAt: String?
    let legacyLink: Bool?
}

// MARK: - WelcomeBookData (champs propres au livret — non couverts par Property)

struct WelcomeBookData: Decodable, Equatable {
    let welcomeDescription: String?
    let checkoutInstructions: String?
    let contactPhone: String?
    let rooms: [WelcomeBookRoom]?
}

struct WelcomeBookRoom: Decodable, Identifiable, Equatable {
    let name: String
    let description: String?
    var id: String { name }
}

// MARK: - API responses

struct WelcomeBookResponse: Decodable {
    let success: Bool
    let exists: Bool
    let uniqueId: String?
    let propertyId: String?
    let publicUrl: String?
    let data: WelcomeBookData?
    let updatedAt: String?
    let legacyLink: Bool?
}

struct WelcomeBookCreateResponse: Decodable {
    let success: Bool
    let uniqueId: String?
    let propertyId: String?
    let publicUrl: String?
    let url: String?
    let urlConflict: Bool?
}

struct WelcomeBookExtrasResponse: Decodable {
    let success: Bool
    let uniqueId: String?
}

// MARK: - Request bodies

struct WelcomeBookCreateRequest: Encodable {
    let propertyId: String
}

struct WelcomeBookExtrasRequest: Encodable {
    let welcomeDescription: String?
    let checkoutInstructions: String?
}
