import Foundation

// MARK: - Draft (state for rental contract creation UI)

struct RentalContractDraft {
    // INTL-RENTAL-CONTRACT — currency snapshot from property at creation time; EUR fallback
    var currency: String = "EUR"

    // Bailleur
    var ownerFirstName: String = ""
    var ownerLastName: String  = ""
    var ownerAddress: String   = ""
    var ownerEmail: String     = ""
    var ownerPhone: String     = ""

    // Logement
    var propertyName: String    = ""
    var propertyType: String    = ""
    var propertyAddress: String = ""

    // Dates
    var checkin: String      = ""
    var checkout: String     = ""
    var checkinTime: String  = "15:00"
    var checkoutTime: String = "11:00"
    var guestCount: String   = "1"

    // Locataire
    var guestFirstName: String   = ""
    var guestLastName: String    = ""
    var guestEmail: String       = ""
    var guestPhone: String       = ""
    var guestNationality: String = ""
    var guestAddress: String     = ""
    var guestDOB: String         = ""
    var guestIDNumber: String    = ""

    // Finances
    var totalPrice: String      = ""
    var cleaningFee: String     = ""
    var deposit: String         = ""
    var acompte: String         = ""
    var acompteDate: String     = ""
    var paymentMethod: String   = "virement"
    var priceNotes: String      = ""

    // Règles
    var regles: [String] = []

    // Conditions légales
    var inclAnnulation: Bool  = false
    var cancelDays1: String   = "30"
    var cancelPct1: String    = "50"
    var cancelDays2: String   = "7"
    var cancelPct2: String    = "0"
    var inclObligations: Bool = true
    var obligationsExtra: String = ""
    var inclAssurance: Bool   = false
    var inclEDL: Bool         = true
    var depositReturnDays: String = "7"

    // Signature
    var signatureData: String = ""
    var signatureDate: String = ""

    // Réservation / client liés (optionnel)
    var reservationUid: String? = nil
    var clientId: String?       = nil
}

extension RentalContractDraft {
    init(property: Property? = nil) {
        if let prop = property {
            propertyName    = prop.name
            propertyAddress = prop.address ?? ""
            currency        = Formatters.normalizeCurrency(prop.currency)
        }
    }
}

// MARK: - Request body (POST /api/contrat/send)

struct RentalContractSendBody: Encodable {
    // Devise — snapshot historique
    let currency: String

    // Bailleur
    let ownerFirstName: String
    let ownerLastName: String
    let ownerAddress: String
    let ownerEmail: String
    let ownerPhone: String

    // Logement
    let propertyName: String
    let propertyType: String
    let propertyAddress: String

    // Dates
    let checkin: String
    let checkout: String
    let checkinTime: String
    let checkoutTime: String
    let guestCount: String

    // Locataire
    let guestFirstName: String
    let guestLastName: String
    let guestEmail: String
    let guestPhone: String
    let guestNationality: String
    let guestAddress: String
    let guestDOB: String
    let guestIDNumber: String

    // Finances
    let totalPrice: String
    let cleaningFee: String
    let deposit: String
    let acompte: String
    let acompteDate: String
    let paymentMethod: String
    let priceNotes: String

    // Règles
    let regles: [String]

    // Conditions légales
    let inclAnnulation: Bool
    let cancelDays1: String
    let cancelPct1: String
    let cancelDays2: String
    let cancelPct2: String
    let inclObligations: Bool
    let obligationsExtra: String
    let inclAssurance: Bool
    let inclEDL: Bool
    let depositReturnDays: String

    // Signature
    let signatureData: String
    let signatureDate: String

    // Optionnels
    let reservationUid: String?
    let clientId: String?

    init(draft: RentalContractDraft) {
        currency         = draft.currency
        ownerFirstName   = draft.ownerFirstName
        ownerLastName    = draft.ownerLastName
        ownerAddress     = draft.ownerAddress
        ownerEmail       = draft.ownerEmail
        ownerPhone       = draft.ownerPhone
        propertyName     = draft.propertyName
        propertyType     = draft.propertyType
        propertyAddress  = draft.propertyAddress
        checkin          = draft.checkin
        checkout         = draft.checkout
        checkinTime      = draft.checkinTime
        checkoutTime     = draft.checkoutTime
        guestCount       = draft.guestCount
        guestFirstName   = draft.guestFirstName
        guestLastName    = draft.guestLastName
        guestEmail       = draft.guestEmail
        guestPhone       = draft.guestPhone
        guestNationality = draft.guestNationality
        guestAddress     = draft.guestAddress
        guestDOB         = draft.guestDOB
        guestIDNumber    = draft.guestIDNumber
        totalPrice       = draft.totalPrice
        cleaningFee      = draft.cleaningFee
        deposit          = draft.deposit
        acompte          = draft.acompte
        acompteDate      = draft.acompteDate
        paymentMethod    = draft.paymentMethod
        priceNotes       = draft.priceNotes
        regles           = draft.regles
        inclAnnulation   = draft.inclAnnulation
        cancelDays1      = draft.cancelDays1
        cancelPct1       = draft.cancelPct1
        cancelDays2      = draft.cancelDays2
        cancelPct2       = draft.cancelPct2
        inclObligations  = draft.inclObligations
        obligationsExtra = draft.obligationsExtra
        inclAssurance    = draft.inclAssurance
        inclEDL          = draft.inclEDL
        depositReturnDays = draft.depositReturnDays
        signatureData    = draft.signatureData
        signatureDate    = draft.signatureDate
        reservationUid   = draft.reservationUid
        clientId         = draft.clientId
    }
}

// MARK: - Response (POST /api/contrat/send)

struct RentalContractSendResponse: Decodable {
    let success: Bool?
    let message: String?
    let contractId: String?
    let signToken: String?
}
