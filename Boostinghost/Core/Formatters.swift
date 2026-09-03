import Foundation

enum Formatters {

    // MARK: - Currency  →  "42 380 €"  (narrow non-breaking space, zero decimals)

    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale              = Locale(identifier: "fr_FR")
        f.numberStyle         = .decimal
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        // fr_FR locale already uses U+202F as thousands separator
        return f
    }()

    static func amount(_ value: Double) -> String {
        let s = amountFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        return "\(s)\u{202F}€"
    }

    static func amount(_ value: String?) -> String {
        guard let value, let d = Double(value) else { return "—" }
        return amount(d)
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
