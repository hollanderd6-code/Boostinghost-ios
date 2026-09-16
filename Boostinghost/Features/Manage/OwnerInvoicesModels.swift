import Foundation

// MARK: - Filter

enum OwnerInvoiceFilter: String, CaseIterable, Hashable {
    case all      = "all"
    case draft    = "draft"
    case invoiced = "invoiced"
    case sent     = "sent"
    case paid     = "paid"

    var label: String {
        switch self {
        case .all:      return "Toutes"
        case .draft:    return "Brouillons"
        case .invoiced: return "Finalisées"
        case .sent:     return "Envoyées"
        case .paid:     return "Payées"
        }
    }
}

// MARK: - Extension sur OwnerInvoice (défini dans OwnersModels.swift)

extension OwnerInvoice {
    var statusLabel: String {
        if isCreditNote == true { return "Avoir" }
        switch status {
        case "draft":    return "Brouillon"
        case "invoiced": return "Finalisée"
        case "sent":     return "Envoyée"
        case "paid":     return "Payée"
        default:         return status ?? "—"
        }
    }

    var statusPillStyle: PillStyle {
        if isCreditNote == true { return .or }
        switch status {
        case "draft":    return .neutre
        case "invoiced": return .or
        case "sent":     return .or
        case "paid":     return .vert
        default:         return .neutre
        }
    }
}

// MARK: - Réponse détail GET /api/owner-invoices/:id

struct OwnerInvoiceDetailResponse: Decodable {
    let invoice: OwnerInvoiceDetail
    let items: [OwnerInvoiceItem]
    let properties: [OwnerInvoiceProperty]

    init(invoice: OwnerInvoiceDetail, items: [OwnerInvoiceItem], properties: [OwnerInvoiceProperty]) {
        self.invoice = invoice
        self.items = items
        self.properties = properties
    }

    init(from decoder: Decoder) throws {
        let c      = try decoder.container(keyedBy: CodingKeys.self)
        invoice    = (try? c.decode(OwnerInvoiceDetail.self,          forKey: .invoice))    ?? OwnerInvoiceDetail()
        items      = (try? c.decode([OwnerInvoiceItem].self,          forKey: .items))      ?? []
        properties = (try? c.decode([OwnerInvoiceProperty].self,      forKey: .properties)) ?? []
    }

    private enum CodingKeys: CodingKey { case invoice, items, properties }
}

// MARK: - Facture complète

struct OwnerInvoiceDetail: Decodable {
    let id: String?
    let invoiceNumber: String?
    let status: String?
    let isCreditNote: Bool?
    let originalInvoiceId: String?

    // Client
    let clientId: String?
    let clientName: String?
    let clientAddress: String?
    let clientSiret: String?
    let clientEmail: String?
    let clientPhone: String?

    // Dates / période
    let issueDate: String?
    let dueDate: String?
    let periodStart: String?
    let periodEnd: String?

    // Montants (NUMERIC → flexDouble)
    let subtotalHt: Double?
    let deboursTotal: Double?
    let discountAmount: Double?
    let tvaRate: Double?
    let tvaAmount: Double?
    let totalTtc: Double?

    // Conditions de paiement
    let paymentDelay: Int?
    let paymentMode: String?
    let lateInterestRate: Double?

    // Notes
    let notes: String?

    // Timestamps
    let createdAt: String?
    let updatedAt: String?

    init() {
        id = nil; invoiceNumber = nil; status = nil; isCreditNote = nil
        originalInvoiceId = nil; clientId = nil; clientName = nil
        clientAddress = nil; clientSiret = nil; clientEmail = nil; clientPhone = nil
        issueDate = nil; dueDate = nil; periodStart = nil; periodEnd = nil
        subtotalHt = nil; deboursTotal = nil; discountAmount = nil
        tvaRate = nil; tvaAmount = nil; totalTtc = nil
        paymentDelay = nil; paymentMode = nil; lateInterestRate = nil
        notes = nil; createdAt = nil; updatedAt = nil
    }

    private enum CodingKeys: CodingKey {
        case id, invoiceNumber, status, isCreditNote, originalInvoiceId
        case clientId, clientName, clientAddress, clientSiret, clientEmail, clientPhone
        case issueDate, dueDate, periodStart, periodEnd
        case subtotalHt, deboursTotal, discountAmount, tvaRate, tvaAmount, totalTtc
        case paymentDelay, paymentMode, lateInterestRate
        case notes, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c             = try decoder.container(keyedBy: CodingKeys.self)
        id                = c.flexString(forKey: .id)
        invoiceNumber     = try? c.decodeIfPresent(String.self, forKey: .invoiceNumber)
        status            = try? c.decodeIfPresent(String.self, forKey: .status)
        isCreditNote      = try? c.decodeIfPresent(Bool.self,   forKey: .isCreditNote)
        originalInvoiceId = c.flexString(forKey: .originalInvoiceId)
        clientId          = c.flexString(forKey: .clientId)
        clientName        = try? c.decodeIfPresent(String.self, forKey: .clientName)
        clientAddress     = try? c.decodeIfPresent(String.self, forKey: .clientAddress)
        clientSiret       = try? c.decodeIfPresent(String.self, forKey: .clientSiret)
        clientEmail       = try? c.decodeIfPresent(String.self, forKey: .clientEmail)
        clientPhone       = try? c.decodeIfPresent(String.self, forKey: .clientPhone)
        issueDate         = try? c.decodeIfPresent(String.self, forKey: .issueDate)
        dueDate           = try? c.decodeIfPresent(String.self, forKey: .dueDate)
        periodStart       = try? c.decodeIfPresent(String.self, forKey: .periodStart)
        periodEnd         = try? c.decodeIfPresent(String.self, forKey: .periodEnd)
        subtotalHt        = c.flexDouble(forKey: .subtotalHt)
        deboursTotal      = c.flexDouble(forKey: .deboursTotal)
        discountAmount    = c.flexDouble(forKey: .discountAmount)
        tvaRate           = c.flexDouble(forKey: .tvaRate)
        tvaAmount         = c.flexDouble(forKey: .tvaAmount)
        totalTtc          = c.flexDouble(forKey: .totalTtc)
        paymentDelay      = c.flexInt(forKey: .paymentDelay)
        paymentMode       = try? c.decodeIfPresent(String.self, forKey: .paymentMode)
        lateInterestRate  = c.flexDouble(forKey: .lateInterestRate)
        notes             = try? c.decodeIfPresent(String.self, forKey: .notes)
        createdAt         = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt         = try? c.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    var statusLabel: String {
        if isCreditNote == true { return "Avoir" }
        switch status {
        case "draft":    return "Brouillon"
        case "invoiced": return "Finalisée"
        case "sent":     return "Envoyée"
        case "paid":     return "Payée"
        default:         return status ?? "—"
        }
    }

    var statusPillStyle: PillStyle {
        if isCreditNote == true { return .or }
        switch status {
        case "draft":    return .neutre
        case "invoiced": return .or
        case "sent":     return .or
        case "paid":     return .vert
        default:         return .neutre
        }
    }
}

// MARK: - Ligne de facture

struct OwnerInvoiceItem: Decodable, Identifiable {
    var id: String { "\(orderIndex ?? 0)-\(itemDescription ?? "")" }

    let itemType: String?
    let itemDescription: String?
    let rentalAmount: Double?
    let commissionRate: Double?
    let quantity: Double?
    let unitPrice: Double?
    let total: Double?
    let orderIndex: Int?
    let isDebours: Bool?
    let deboursId: String?

    private enum CodingKeys: String, CodingKey {
        case itemType
        case itemDescription = "description"
        case rentalAmount, commissionRate, quantity, unitPrice, total, orderIndex, isDebours, deboursId
    }

    init(from decoder: Decoder) throws {
        let c            = try decoder.container(keyedBy: CodingKeys.self)
        itemType         = try? c.decodeIfPresent(String.self, forKey: .itemType)
        itemDescription  = try? c.decodeIfPresent(String.self, forKey: .itemDescription)
        rentalAmount     = c.flexDouble(forKey: .rentalAmount)
        commissionRate   = c.flexDouble(forKey: .commissionRate)
        quantity         = c.flexDouble(forKey: .quantity)
        unitPrice        = c.flexDouble(forKey: .unitPrice)
        total            = c.flexDouble(forKey: .total)
        orderIndex       = c.flexInt(forKey: .orderIndex)
        isDebours        = try? c.decodeIfPresent(Bool.self,   forKey: .isDebours)
        deboursId        = c.flexString(forKey: .deboursId)
    }
}

// MARK: - Logement associé

struct OwnerInvoiceProperty: Decodable, Identifiable {
    let id: String
    let name: String?
    let address: String?

    private enum CodingKeys: CodingKey { case id, name, address }

    init(from decoder: Decoder) throws {
        let c   = try decoder.container(keyedBy: CodingKeys.self)
        id      = c.flexString(forKey: .id) ?? ""
        name    = try? c.decodeIfPresent(String.self, forKey: .name)
        address = try? c.decodeIfPresent(String.self, forKey: .address)
    }
}
