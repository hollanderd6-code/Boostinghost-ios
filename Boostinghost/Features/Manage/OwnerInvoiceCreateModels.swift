import Foundation

// MARK: - GET /api/reservations/invoice-summary

struct InvoiceSummaryResponse: Decodable {
    let summary: [InvoiceSummaryBucket]
    let reservations: [InvoiceSummaryReservation]

    init(from decoder: Decoder) throws {
        let c        = try decoder.container(keyedBy: CodingKeys.self)
        summary      = (try? c.decodeIfPresent([InvoiceSummaryBucket].self,      forKey: .summary))      ?? []
        reservations = (try? c.decodeIfPresent([InvoiceSummaryReservation].self, forKey: .reservations)) ?? []
    }

    private enum CodingKeys: CodingKey { case summary, reservations }
}

struct InvoiceSummaryBucket: Decodable, Identifiable {
    let platform: String
    let currency: String
    let count: Int
    let totalNet: Double
    let totalBrut: Double
    let totalCleaning: Double
    let totalTaxes: Double
    let totalOtaCom: Double
    let bookingPayout: Double

    var id: String { "\(platform)::\(currency)" }

    private enum CodingKeys: CodingKey {
        case platform, currency, count, totalNet, totalBrut, totalCleaning, totalTaxes, totalOtaCom, bookingPayout
    }

    init(from decoder: Decoder) throws {
        let c         = try decoder.container(keyedBy: CodingKeys.self)
        platform      = (try? c.decodeIfPresent(String.self, forKey: .platform)) ?? ""
        currency      = Formatters.normalizeCurrency(try? c.decodeIfPresent(String.self, forKey: .currency))
        count         = c.flexInt(forKey: .count) ?? 0
        totalNet      = c.flexDouble(forKey: .totalNet) ?? 0
        totalBrut     = c.flexDouble(forKey: .totalBrut) ?? 0
        totalCleaning = c.flexDouble(forKey: .totalCleaning) ?? 0
        totalTaxes    = c.flexDouble(forKey: .totalTaxes) ?? 0
        totalOtaCom   = c.flexDouble(forKey: .totalOtaCom) ?? 0
        bookingPayout = c.flexDouble(forKey: .bookingPayout) ?? 0
    }
}

struct InvoiceSummaryReservation: Decodable, Identifiable {
    let id: String
    let guestName: String?
    let dateFrom: String?
    let dateTo: String?
    let platform: String?
    let currency: String?
    let totalBrut: Double?
    let totalNet: Double?

    private enum CodingKeys: CodingKey {
        case id, guestName, dateFrom, dateTo, platform, currency, totalBrut, totalNet
    }

    init(from decoder: Decoder) throws {
        let c     = try decoder.container(keyedBy: CodingKeys.self)
        id        = c.flexString(forKey: .id) ?? UUID().uuidString
        guestName = try? c.decodeIfPresent(String.self, forKey: .guestName)
        dateFrom  = try? c.decodeIfPresent(String.self, forKey: .dateFrom)
        dateTo    = try? c.decodeIfPresent(String.self, forKey: .dateTo)
        platform  = try? c.decodeIfPresent(String.self, forKey: .platform)
        currency  = try? c.decodeIfPresent(String.self, forKey: .currency)
        totalBrut = c.flexDouble(forKey: .totalBrut)
        totalNet  = c.flexDouble(forKey: .totalNet)
    }
}

// MARK: - Ligne de brouillon (modèle local mutable)

struct OwnerInvoiceDraftItem: Identifiable {
    let id: UUID
    let isImported: Bool        // true = vient de invoice-summary
    var itemType: String        // "commission" | "cleaning" | "other" | type inconnu préservé
    var description: String
    // Commission
    var rentalAmount: Double
    var commissionRate: Double
    // Forfait / autre
    var quantity: Double
    var unitPrice: Double
    // Devise transportée pour INTL-4.4B
    var currency: String
    // false = ligne visible mais exclue de la facture (devise historique incompatible)
    var isIncluded: Bool
    // Débours — préservés tels quels en PUT (pas d'éditeur dans cette version)
    var isDebours: Bool
    var deboursId: String?

    init(importedFrom bucket: InvoiceSummaryBucket, commissionRate: Double, isCompatible: Bool) {
        id              = UUID()
        isImported      = true
        itemType        = "commission"
        description     = "Commissions \(bucket.platform) — \(bucket.count) séjour\(bucket.count > 1 ? "s" : "")"
        rentalAmount    = bucket.bookingPayout
        self.commissionRate = commissionRate
        quantity        = 1
        unitPrice       = 0
        currency        = bucket.currency
        isIncluded      = isCompatible
        isDebours       = false
        deboursId       = nil
    }

    init(itemType: String, currency: String) {
        id              = UUID()
        isImported      = false
        self.itemType   = itemType
        description     = itemType == "commission" ? "Loyer du" : (itemType == "cleaning" ? "Frais de ménage" : "Autre prestation")
        rentalAmount    = 0
        commissionRate  = 20
        quantity        = 1
        unitPrice       = 0
        self.currency   = currency
        isIncluded      = true
        isDebours       = false
        deboursId       = nil
    }

    // Charge un item depuis la DB (mode édition d'un brouillon existant).
    // Les items DB n'ont pas leur propre devise : ils héritent de invoice.currency.
    init(fromExisting item: OwnerInvoiceItem, invoiceCurrency: String) {
        id              = UUID()
        isImported      = false
        itemType        = item.itemType ?? "other"
        description     = item.itemDescription ?? ""
        commissionRate  = item.commissionRate ?? 20
        quantity        = item.quantity ?? 1
        currency        = invoiceCurrency
        isIncluded      = true
        isDebours       = item.isDebours ?? false
        deboursId       = item.deboursId
        // Débours : unitPrice = total DB → lineTotal sera exact
        // Commission : rentalAmount calculé depuis total
        if item.isDebours == true {
            rentalAmount = 0
            unitPrice    = item.total ?? 0
        } else if item.itemType == "commission" {
            rentalAmount = item.rentalAmount ?? 0
            unitPrice    = 0
        } else {
            rentalAmount = item.rentalAmount ?? 0
            unitPrice    = item.unitPrice ?? 0
        }
    }

    var lineTotal: Double {
        if isDebours { return (quantity * unitPrice).rounded(decimals: 2) }
        if itemType == "commission" { return (rentalAmount * commissionRate / 100.0).rounded(decimals: 2) }
        return (quantity * unitPrice).rounded(decimals: 2)
    }
}

// MARK: - GET /api/owner-invoices/:id — champs d'édition

// Séparé de OwnerInvoiceDetail pour capturer les champs d'édition sans
// perturber le modèle existant (vatApplicable, discountType, internalNotes absents du modèle détail).
struct OwnerInvoiceEditFields: Decodable {
    let id: String
    let status: String?
    let currency: String?
    let clientId: String?
    let clientName: String?
    let issueDate: String?
    let dueDate: String?
    let periodStart: String?
    let periodEnd: String?
    let vatApplicable: Bool?
    let vatRate: Double?
    let discountType: String?
    let discountValue: Double?
    let notes: String?
    let internalNotes: String?

    private enum CodingKeys: CodingKey {
        case id, status, currency, clientId, clientName
        case issueDate, dueDate, periodStart, periodEnd
        case vatApplicable, vatRate
        case discountType, discountValue
        case notes, internalNotes
    }

    init(from decoder: Decoder) throws {
        let c          = try decoder.container(keyedBy: CodingKeys.self)
        id             = c.flexString(forKey: .id) ?? ""
        status         = try? c.decodeIfPresent(String.self, forKey: .status)
        currency       = try? c.decodeIfPresent(String.self, forKey: .currency)
        clientId       = c.flexString(forKey: .clientId)
        clientName     = try? c.decodeIfPresent(String.self, forKey: .clientName)
        issueDate      = try? c.decodeIfPresent(String.self, forKey: .issueDate)
        dueDate        = try? c.decodeIfPresent(String.self, forKey: .dueDate)
        periodStart    = try? c.decodeIfPresent(String.self, forKey: .periodStart)
        periodEnd      = try? c.decodeIfPresent(String.self, forKey: .periodEnd)
        vatApplicable  = try? c.decodeIfPresent(Bool.self,   forKey: .vatApplicable)
        vatRate        = c.flexDouble(forKey: .vatRate)
        discountType   = try? c.decodeIfPresent(String.self, forKey: .discountType)
        discountValue  = c.flexDouble(forKey: .discountValue)
        notes          = try? c.decodeIfPresent(String.self, forKey: .notes)
        internalNotes  = try? c.decodeIfPresent(String.self, forKey: .internalNotes)
    }
}

struct OwnerInvoiceEditLoadResponse: Decodable {
    let invoice: OwnerInvoiceEditFields
    let items: [OwnerInvoiceItem]
    let properties: [OwnerInvoiceProperty]

    init(from decoder: Decoder) throws {
        let c      = try decoder.container(keyedBy: CodingKeys.self)
        invoice    = try c.decode(OwnerInvoiceEditFields.self, forKey: .invoice)
        items      = (try? c.decode([OwnerInvoiceItem].self,         forKey: .items))      ?? []
        properties = (try? c.decode([OwnerInvoiceProperty].self,     forKey: .properties)) ?? []
    }

    private enum CodingKeys: CodingKey { case invoice, items, properties }
}

// MARK: - POST /api/owner-invoices — request (CREATE)

struct CreateOwnerInvoiceRequest: Encodable {
    let clientId: String
    let periodStart: String?
    let periodEnd: String?
    let issueDate: String
    let dueDate: String
    let propertyIds: [String]
    let items: [CreateOwnerInvoiceItemRequest]
    let vatApplicable: Bool
    let vatRate: Double
    let discountType: String
    let discountValue: Double
    let notes: String?
    let internalNotes: String?
}

// MARK: - PUT /api/owner-invoices/:id — request (EDIT)
// discountType: "none" | "percent" | "fixed". Backend normalise "percentage" → "percent".
// Dates: COALESCE côté serveur — nil = conserver existante, valeur = mettre à jour.

struct UpdateOwnerInvoiceRequest: Encodable {
    let items: [CreateOwnerInvoiceItemRequest]
    let vatApplicable: Bool
    let vatRate: Double
    let discountType: String
    let discountValue: Double
    let notes: String?
    let internalNotes: String?
    // Dates: nil → clé absente → COALESCE conserve la valeur existante côté serveur
    let issueDate: String?
    let dueDate: String?
    let periodStart: String?
    let periodEnd: String?

    private enum CodingKeys: String, CodingKey {
        case items, vatApplicable, vatRate, discountType, discountValue
        case notes, internalNotes
        case issueDate, dueDate, periodStart, periodEnd
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(items,           forKey: .items)
        try c.encode(vatApplicable,   forKey: .vatApplicable)
        try c.encode(vatRate,         forKey: .vatRate)
        try c.encode(discountType,    forKey: .discountType)
        try c.encode(discountValue,   forKey: .discountValue)
        try c.encodeIfPresent(notes,          forKey: .notes)
        try c.encodeIfPresent(internalNotes,  forKey: .internalNotes)
        try c.encodeIfPresent(issueDate,      forKey: .issueDate)
        try c.encodeIfPresent(dueDate,        forKey: .dueDate)
        try c.encodeIfPresent(periodStart,    forKey: .periodStart)
        try c.encodeIfPresent(periodEnd,      forKey: .periodEnd)
    }
}

struct UpdateOwnerInvoiceResponse: Decodable {
    let success: Bool?
    let message: String?

    init(from decoder: Decoder) throws {
        let c   = try decoder.container(keyedBy: CodingKeys.self)
        success = try? c.decodeIfPresent(Bool.self,   forKey: .success)
        message = try? c.decodeIfPresent(String.self, forKey: .message)
    }

    private enum CodingKeys: CodingKey { case success, message }
}

// MARK: - Shared item request (POST + PUT)

// itemType: "commission" | "cleaning" | "other" | type DB préservé
// currency envoyé pour validation INTL-4.4B (non stocké par article en DB)

struct CreateOwnerInvoiceItemRequest: Encodable {
    let itemType: String
    let description: String
    let rentalAmount: Double
    let commissionRate: Double
    let quantity: Double
    let unitPrice: Double
    let total: Double
    let isDebours: Bool
    let deboursId: String?
    let currency: String?
}

// MARK: - POST /api/owner-invoices — response { invoice: ... }

struct CreateOwnerInvoiceResponse: Decodable {
    let invoice: OwnerInvoice?

    init(from decoder: Decoder) throws {
        let c   = try decoder.container(keyedBy: CodingKeys.self)
        invoice = try? c.decode(OwnerInvoice.self, forKey: .invoice)
    }

    private enum CodingKeys: CodingKey { case invoice }
}

// MARK: - Double rounding helper

private extension Double {
    func rounded(decimals: Int) -> Double {
        let factor = pow(10.0, Double(decimals))
        return (self * factor).rounded() / factor
    }
}
