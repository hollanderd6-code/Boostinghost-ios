import Foundation

enum Formatters {

    // MARK: - Currency normalization

    // Accepts any ISO 4217-like code, normalizes to uppercase.
    // nil / empty / non-3-letter strings → "EUR".
    static func normalizeCurrency(_ code: String?) -> String {
        let t = (code ?? "").trimmingCharacters(in: .whitespaces).uppercased()
        guard t.count == 3, t.allSatisfy(\.isLetter) else { return "EUR" }
        return t
    }

    // MARK: - Non-EUR formatter cache (keyed by "<CODE>_<maxFraction>")
    // nonisolated(unsafe): formatters are created/read exclusively from the main actor in practice;
    // NumberFormatter is not thread-safe but the existing static formatters follow the same pattern.
    nonisolated(unsafe) private static var fxCache: [String: NumberFormatter] = [:]

    private static func fxFormatter(code: String, maxFraction: Int) -> NumberFormatter {
        let key = "\(code)_\(maxFraction)"
        if let f = fxCache[key] { return f }
        let f = NumberFormatter()
        f.locale                = Locale(identifier: "fr_FR")
        f.numberStyle           = .currency
        f.currencyCode          = code
        f.maximumFractionDigits = maxFraction
        f.minimumFractionDigits = maxFraction
        fxCache[key] = f
        return f
    }

    // MARK: - Currency symbol for use in text labels

    static func currencySymbol(for currency: String) -> String {
        let code = normalizeCurrency(currency)
        if code == "EUR" { return "€" }
        return fxFormatter(code: code, maxFraction: 0).currencySymbol ?? code
    }

    // MARK: - Currency  →  "42 380 €"  (narrow non-breaking space, zero decimals)
    //
    // EUR path: exact legacy behavior preserved (fr_FR decimal + "€" suffix).
    // Non-EUR path: NumberFormatter .currency with fr_FR locale; symbol and placement
    //               are locale-determined — no hardcoded switch.

    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale              = Locale(identifier: "fr_FR")
        f.numberStyle         = .decimal
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        // fr_FR locale already uses U+202F as thousands separator
        return f
    }()

    static func amount(_ value: Double, currency: String = "EUR") -> String {
        let code = normalizeCurrency(currency)
        if code == "EUR" {
            let s = amountFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
            return "\(s)\u{202F}€"
        }
        return fxFormatter(code: code, maxFraction: 0).string(from: NSNumber(value: value))
            ?? "\(Int(value)) \(code)"
    }

    static func amount(_ value: String?) -> String {
        guard let value, let d = Double(value) else { return "—" }
        return amount(d)
    }

    // MARK: - Currency with decimals  →  "145,80 €"  (used in prix détaillé breakdown)

    private static let amountDecimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale                = Locale(identifier: "fr_FR")
        f.numberStyle           = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    static func amountDecimal(_ value: Double, currency: String = "EUR") -> String {
        let code = normalizeCurrency(currency)
        if code == "EUR" {
            let s = amountDecimalFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
            return "\(s)\u{202F}€"
        }
        return fxFormatter(code: code, maxFraction: 2).string(from: NSNumber(value: value))
            ?? String(format: "%.2f \(code)", value)
    }

    // MARK: - Compact amount for narrow calendar cells (0 decimals, currency always shown)

    static func amountCompact(_ value: Double, currency: String = "EUR") -> String {
        amount(value, currency: currency)
    }

    // MARK: - Time  →  "16 h"  /  "9 h 41"

    static func time(_ hhmm: String?) -> String? {
        guard let hhmm else { return nil }
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard let h = parts.first else { return hhmm }
        let m = parts.count > 1 ? parts[1] : 0
        // U+00A0 = non-breaking space around h
        return m == 0
            ? "\(h)\u{00A0}h"
            : "\(h)\u{00A0}h\u{00A0}\(String(format: "%02d", m))"
    }

    // MARK: - Date  →  "mardi 1 septembre"  (lowercase, no year)

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f
    }()

    private static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone   = TimeZone(identifier: "Europe/Paris")
        return f
    }()

    static func day(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func day(_ isoDate: String) -> String {
        guard let date = isoDateFormatter.date(from: String(isoDate.prefix(10))) else {
            return isoDate
        }
        return day(date)
    }

    // MARK: - Short date  →  "20 avr."  "3 sept."

    private static let dayShortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMM"
        return f
    }()

    static func dayShort(_ isoDate: String) -> String {
        guard let date = isoDateFormatter.date(from: String(isoDate.prefix(10))) else {
            return isoDate
        }
        return dayShortFormatter.string(from: date)
    }

    // MARK: - Full date with year  →  "mercredi 1 octobre 2026"

    private static let dayWithYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM yyyy"
        return f
    }()

    static func dayWithYear(_ isoDate: String) -> String {
        guard let date = isoDateFormatter.date(from: String(isoDate.prefix(10))) else {
            return isoDate
        }
        return dayWithYearFormatter.string(from: date)
    }

    // MARK: - Calendar day key  →  "yyyy-MM-dd" UTC  (clé interne des dictionnaires calendrier)

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone   = TimeZone(identifier: "UTC")
        return f
    }()

    static func dayKey(_ date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }

    // MARK: - Short date for bande calendrier  →  "1"  "3"  etc.

    static func dayNumber(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "fr_FR")
        f.dateFormat = "d"
        return f.string(from: date)
    }

    static func dayAbbrev(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE"  // "lun", "mar", etc.
        return f.string(from: date).prefix(3).lowercased()
    }
}
