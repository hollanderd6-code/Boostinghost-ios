import Foundation

// MARK: - Local line model

struct AttestationLine: Identifiable {
    let id: UUID
    var label: String
    var heures: String
    var taux: String

    init(id: UUID = UUID(), label: String = "", heures: String = "", taux: String = "") {
        self.id = id; self.label = label; self.heures = heures; self.taux = taux
    }

    var totalDecimal: Decimal? {
        guard let h = Decimal(string: heures.replacingOccurrences(of: ",", with: ".")),
              let t = Decimal(string: taux.replacingOccurrences(of: ",", with: ".")) else { return nil }
        let product = h * t
        var rounded = Decimal(); var source = product
        NSDecimalRound(&rounded, &source, 2, .plain)
        return rounded
    }

    var totalSendString: String {
        guard let d = totalDecimal else { return "0.00" }
        return AttestationDraft.sendString(d)
    }

    var isComplete: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty
            && Decimal(string: heures.replacingOccurrences(of: ",", with: ".")) != nil
            && Decimal(string: taux.replacingOccurrences(of: ",", with: ".")) != nil
    }
}

// MARK: - Local monthly row model

struct AttestationMonthRow: Identifiable {
    let id: UUID
    var mois: String
    var heures: String
    var montant: String

    init(id: UUID = UUID(), mois: String = "", heures: String = "", montant: String = "") {
        self.id = id; self.mois = mois; self.heures = heures; self.montant = montant
    }

    var montantDecimal: Decimal? {
        Decimal(string: montant.replacingOccurrences(of: ",", with: "."))
    }
}

// MARK: - Draft

struct AttestationDraft {
    var clientId: String = ""
    var year: Int        = Calendar.current.component(.year, from: Date()) - 1
    var ville: String    = ""
    var date: Date       = Date()

    var emitterCompany:    String = ""
    var emitterAddress:    String = ""
    var emitterPostalCode: String = ""
    var emitterCity:       String = ""
    var emitterSiret:      String = ""
    var emitterEmail:      String = ""

    var lines:       [AttestationLine]      = [AttestationLine()]
    var monthlyRows: [AttestationMonthRow]  = []

    var signatureData: String = ""

    // MARK: Computed

    var grandTotalDecimal: Decimal {
        lines.compactMap(\.totalDecimal).reduce(Decimal(0), +)
    }

    var monthlyTotalDecimal: Decimal {
        monthlyRows.compactMap(\.montantDecimal).reduce(Decimal(0), +)
    }

    var monthlyExceedsAnnual: Bool {
        !monthlyRows.isEmpty && monthlyTotalDecimal > grandTotalDecimal
    }

    var hasAtLeastOneCompleteLine: Bool {
        lines.contains { $0.isComplete }
    }

    var availableYears: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array(2024...max(2024, current)).reversed()
    }

    var dateStr: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: date)
    }

    // MARK: String for API (decimal point, 2 places, no grouping)

    static func sendString(_ d: Decimal) -> String {
        var rounded = Decimal(); var source = d
        NSDecimalRound(&rounded, &source, 2, .plain)
        let n = NSDecimalNumber(decimal: rounded)
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ""
        return f.string(from: n) ?? "0.00"
    }
}

// MARK: - API request bodies

struct AttestationEmitterBody: Encodable {
    let company:    String
    let address:    String
    let postalCode: String
    let city:       String
    let siret:      String
    let email:      String
}

struct AttestationLineBody: Encodable {
    let label:  String
    let heures: String
    let taux:   String
    let total:  String
}

struct AttestationMonthRowBody: Encodable {
    let mois:    String
    let heures:  String
    let montant: String
}

struct AttestationRequestBody: Encodable {
    let clientId:      String
    let year:          String
    let ville:         String
    let dateStr:       String
    let emitter:       AttestationEmitterBody
    let lines:         [AttestationLineBody]
    let monthlyRows:   [AttestationMonthRowBody]
    let grandTotal:    String
    let signatureData: String
}

// MARK: - API response

struct AttestationSendResponse: Decodable {
    let success: Bool?
    let message: String?
}
