import Foundation

// MARK: - GET /api/reservations-with-deposits
//
// Réponse : tableau nu, tout camelCase.
// deposit : { id, amountCents, status, checkoutUrl, createdAt, authorizedAt, auth_expired } | null
// amountCents est en centimes — diviser par 100 pour l'affichage.
// L'expiration Stripe = authorizedAt + 7 jours.
// Si authorizedAt est absent, aucun signal d'expiration n'est calculé ni affiché.
// Champ endDate (ou checkOut) : date de départ du séjour.

struct ReservationWithDeposit: Decodable, Identifiable {

    // MARK: - Champs

    let id: String
    let depositId: String       // POST /api/deposits/:id/capture|release
    let guestName: String?
    let propertyName: String?
    let propertyId: String?
    let checkOut: String?               // ISO "YYYY-MM-DD" ou datetime complet (champ endDate ou checkOut)
    let amountCents: Int?               // centimes → /100 pour l'affichage
    let depositStatus: String?          // "authorized" | "auth_expired" | "captured" | "released"
    let depositReleaseDays: Int?        // champ du logement, renvoyé inline
    let authorizedAt: String?           // ISO 8601 — expiry Stripe = +7 jours
    let authExpired: Bool?              // commit 09c7074c — prioritaire sur depositStatus == "auth_expired"
    let checkoutUrl: String?            // URL Stripe de paiement (depuis deposit.checkoutUrl)
    let depositCreatedAt: String?       // date de création de la caution (depuis deposit.createdAt)

    // MARK: - Computed

    /// Montant en euros pour l'affichage.
    var depositAmount: Double? {
        amountCents.map { Double($0) / 100.0 }
    }

    /// Autorisation expirée — utilise le champ serveur si disponible, sinon le status.
    var isAuthExpired: Bool {
        authExpired ?? (depositStatus == "auth_expired")
    }

    /// Actions (libérer / retenir) disponibles uniquement si autorisée et non expirée.
    var canAct: Bool {
        depositStatus == "authorized" && !isAuthExpired
    }

    /// Libellé lisible du statut.
    var statusLabel: String {
        if isAuthExpired { return "Expirée" }
        switch depositStatus {
        case "authorized": return "Autorisée"
        case "captured":   return "Retenue"
        case "released":   return "Restituée"
        default:           return depositStatus ?? "—"
        }
    }

    /// Style de pastille associé au statut.
    var statusPillStyle: PillStyle {
        if isAuthExpired { return .neutre }
        switch depositStatus {
        case "authorized": return .vert
        case "captured":   return .terracotta
        case "released":   return .vert
        default:           return .neutre
        }
    }

    /// Délai de restitution dépassé (checkOut + depositReleaseDays < maintenant).
    var isOverdue: Bool {
        guard let co = checkOut, let days = depositReleaseDays,
              let date = Self.parseISODate(co) else { return false }
        let deadline = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        return Date.now > deadline
    }

    /// Nombre de jours de dépassement (0 si non dépassé).
    var overdueDays: Int {
        guard let co = checkOut, let days = depositReleaseDays,
              let date = Self.parseISODate(co) else { return 0 }
        let deadline = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        let comps = Calendar.current.dateComponents([.day], from: deadline, to: Date.now)
        return max(0, comps.day ?? 0)
    }

    /// Date d'expiration Stripe = authorizedAt + 7 jours (nil si authorizedAt absent).
    var authExpiryDate: Date? {
        guard let raw = authorizedAt, let auth = parseISO8601(raw) else { return nil }
        return auth.addingTimeInterval(7 * 24 * 3600)
    }

    /// "expire le mardi 14 septembre" — nil si authorizedAt absent.
    var authExpiryLabel: String? {
        guard let expiry = authExpiryDate else { return nil }
        return "expire le \(Formatters.day(expiry))"
    }

    /// Autorisation Stripe expire dans moins de 48 h (false si authorizedAt absent ou déjà expiré).
    var expiresWithin48h: Bool {
        guard let expiry = authExpiryDate else { return false }
        let remaining = expiry.timeIntervalSinceNow
        return remaining > 0 && remaining < 48 * 3600
    }

    /// Heures entières restantes avant expiration Stripe (nil si authorizedAt absent ou déjà expiré).
    var hoursUntilAuthExpiry: Int? {
        guard let expiry = authExpiryDate else { return nil }
        let remaining = expiry.timeIntervalSinceNow
        guard remaining > 0 else { return nil }
        return Int(remaining / 3600)
    }

    /// "hier 11 h", "mardi 2 septembre 11 h", etc.
    var departureSummary: String {
        guard let co = checkOut else { return "—" }
        let dayPart: String
        if let d = Self.parseISODate(co) {
            if Calendar.current.isDateInToday(d)     { dayPart = "aujourd'hui" }
            else if Calendar.current.isDateInYesterday(d) { dayPart = "hier" }
            else { dayPart = Formatters.day(String(co.prefix(10))) }
        } else {
            dayPart = String(co.prefix(10))
        }
        if co.contains("T"), let d = parseISO8601(co) {
            let h = Calendar.current.component(.hour,   from: d)
            let m = Calendar.current.component(.minute, from: d)
            if let t = Formatters.time("\(h):\(String(format: "%02d", m))") {
                return "\(dayPart) \(t)"
            }
        }
        return dayPart
    }

    /// "départ le mardi 2 septembre" (futur) ou "partie hier 11 h" (passé).
    var departurePrefix: String {
        guard let co = checkOut, let d = Self.parseISODate(co) else { return "départ —" }
        if d >= Calendar.current.startOfDay(for: Date.now) {
            return "départ le \(Formatters.day(String(co.prefix(10))))"
        }
        return "partie \(departureSummary)"
    }

    // MARK: - Decoding

    private enum CodingKeys: String, CodingKey {
        case _id = "_id", id
        case guestName
        case propertyName
        case propertyId
        case endDate            // nom réel renvoyé par le backend
        case checkOut           // fallback
        case depositReleaseDays
        case deposit
        case depositId
        case amountCents
        case depositStatus
        case authorizedAt
        case authExpired
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id           = c.flexString(forKey: ._id) ?? c.flexString(forKey: .id) ?? UUID().uuidString
        guestName    = try? c.decodeIfPresent(String.self, forKey: .guestName)
        propertyName = try? c.decodeIfPresent(String.self, forKey: .propertyName)
        propertyId   = try? c.decodeIfPresent(String.self, forKey: .propertyId)
        // endDate est le nom réel — checkOut comme repli pour la rétrocompatibilité
        checkOut     = (try? c.decodeIfPresent(String.self, forKey: .endDate))
                    ?? (try? c.decodeIfPresent(String.self, forKey: .checkOut))
        depositReleaseDays = c.flexInt(forKey: .depositReleaseDays)

        if let nested = try? c.decodeIfPresent(DepositNested.self, forKey: .deposit) {
            depositId       = nested.id
            amountCents     = nested.amountCents
            depositStatus   = nested.status
            authorizedAt    = nested.authorizedAt
            authExpired     = nested.authExpired
            checkoutUrl     = nested.checkoutUrl
            depositCreatedAt = nested.createdAt
        } else {
            depositId       = c.flexString(forKey: .depositId) ?? ""
            amountCents     = c.flexInt(forKey: .amountCents)
            depositStatus   = try? c.decodeIfPresent(String.self, forKey: .depositStatus)
            authorizedAt    = try? c.decodeIfPresent(String.self, forKey: .authorizedAt)
            authExpired     = try? c.decodeIfPresent(Bool.self, forKey: .authExpired)
            checkoutUrl     = nil
            depositCreatedAt = nil
        }
    }

    // MARK: - Helpers

    private static func parseISODate(_ raw: String) -> Date? {
        let f = DateFormatter()
        f.locale   = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Paris")
        return f.date(from: String(raw.prefix(10)))
    }
}

// Sous-objet `deposit` imbriqué.
private struct DepositNested: Decodable {
    let id: String
    let amountCents: Int?
    let status: String?
    let checkoutUrl: String?
    let createdAt: String?
    let authorizedAt: String?
    let authExpired: Bool?

    private enum CodingKeys: String, CodingKey {
        case _id = "_id", id
        case amountCents
        case status
        case checkoutUrl
        case createdAt
        case authorizedAt
        case authExpired
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = c.flexString(forKey: ._id) ?? c.flexString(forKey: .id) ?? ""
        amountCents  = c.flexInt(forKey: .amountCents)
        status       = try? c.decodeIfPresent(String.self, forKey: .status)
        checkoutUrl  = try? c.decodeIfPresent(String.self, forKey: .checkoutUrl)
        createdAt    = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        authorizedAt = try? c.decodeIfPresent(String.self, forKey: .authorizedAt)
        authExpired  = try? c.decodeIfPresent(Bool.self, forKey: .authExpired)
    }
}

// Enveloppe tolérante : tableau brut OU { reservations: [...] }.
struct ReservationsWithDepositsResponse: Decodable {
    let reservations: [ReservationWithDeposit]

    init(from decoder: Decoder) throws {
        if let arr = try? [ReservationWithDeposit](from: decoder) {
            reservations = arr
        } else if let c = try? decoder.container(keyedBy: CodingKeys.self),
                  let arr = try? c.decodeIfPresent([ReservationWithDeposit].self, forKey: .reservations) {
            reservations = arr ?? []
        } else {
            reservations = []
        }
    }
    private enum CodingKeys: CodingKey { case reservations }
}

// MARK: - Helpers ISO8601 (file-private)

private func parseISO8601(_ raw: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: raw) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: raw)
}
