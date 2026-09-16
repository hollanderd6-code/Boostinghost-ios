import Foundation

// MARK: - GET /api/invoice/history
//
// Réponse enveloppée : { invoices: [...] }
// Champs de base : invoiceNumber, createdAt, clientName, clientEmail,
//   propertyName, checkinDate, checkoutDate, total, conversationId, reservationUid.
// Champs détail (ajoutés au même endpoint) : rentAmount, touristTaxAmount,
//   cleaningFee, vatRate, vatAmount, nights, clientNationality, clientAddress,
//   clientPostalCode, clientCity, clientCompany, clientSiret, platform.
// Les montants peuvent arriver en Double, Int ou String → flexDouble.
// Une ligne sans invoiceNumber vient du chemin de repli owner_invoices ;
// elle s'affiche sans bouton « Renvoyer » (resend exige un vrai numéro).

struct Invoice: Decodable, Identifiable {
    let id: String
    let invoiceNumber: String?
    let clientName: String?
    let clientEmail: String?
    let clientCompany: String?
    let clientSiret: String?
    let clientAddress: String?
    let clientPostalCode: String?
    let clientCity: String?
    let clientNationality: String?
    let propertyName: String?
    let checkinDate: String?
    let checkoutDate: String?
    let nights: Int?
    let platform: String?
    let rentAmount: Double?
    let touristTaxAmount: Double?
    let cleaningFee: Double?
    let vatRate: Double?
    let vatAmount: Double?
    let total: Double?
    let createdAt: String?
    let conversationId: Int?
    let reservationUid: String?

    var hasEmail: Bool {
        guard let e = clientEmail else { return false }
        return !e.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var canResend: Bool { invoiceNumber != nil && hasEmail }
    var canSendToConversation: Bool { conversationId != nil || reservationUid != nil }

    private enum CodingKeys: String, CodingKey {
        case invoiceNumber, clientName, clientEmail
        case clientCompany, clientSiret, clientAddress
        case clientPostalCode, clientCity, clientNationality
        case propertyName, checkinDate, checkoutDate
        case nights, platform
        case rentAmount, touristTaxAmount, cleaningFee
        case vatRate, vatAmount, total, createdAt
        case conversationId, reservationUid
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        invoiceNumber     = try? c.decodeIfPresent(String.self, forKey: .invoiceNumber)
        clientName        = try? c.decodeIfPresent(String.self, forKey: .clientName)
        clientEmail       = try? c.decodeIfPresent(String.self, forKey: .clientEmail)
        clientCompany     = try? c.decodeIfPresent(String.self, forKey: .clientCompany)
        clientSiret       = try? c.decodeIfPresent(String.self, forKey: .clientSiret)
        clientAddress     = try? c.decodeIfPresent(String.self, forKey: .clientAddress)
        clientPostalCode  = try? c.decodeIfPresent(String.self, forKey: .clientPostalCode)
        clientCity        = try? c.decodeIfPresent(String.self, forKey: .clientCity)
        clientNationality = try? c.decodeIfPresent(String.self, forKey: .clientNationality)
        propertyName      = try? c.decodeIfPresent(String.self, forKey: .propertyName)
        checkinDate       = try? c.decodeIfPresent(String.self, forKey: .checkinDate)
        checkoutDate      = try? c.decodeIfPresent(String.self, forKey: .checkoutDate)
        nights            = c.flexInt(forKey: .nights)
        platform          = try? c.decodeIfPresent(String.self, forKey: .platform)
        rentAmount        = c.flexDouble(forKey: .rentAmount)
        touristTaxAmount  = c.flexDouble(forKey: .touristTaxAmount)
        cleaningFee       = c.flexDouble(forKey: .cleaningFee)
        vatRate           = c.flexDouble(forKey: .vatRate)
        vatAmount         = c.flexDouble(forKey: .vatAmount)
        total             = c.flexDouble(forKey: .total)
        createdAt         = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        conversationId    = try? c.decodeIfPresent(Int.self, forKey: .conversationId)
        reservationUid    = try? c.decodeIfPresent(String.self, forKey: .reservationUid)
        id = invoiceNumber ?? createdAt ?? UUID().uuidString
    }
}

// Réponse toujours enveloppée { invoices: [...] }.
struct InvoiceHistoryResponse: Decodable {
    let invoices: [Invoice]
    private enum CodingKeys: CodingKey { case invoices }
}
