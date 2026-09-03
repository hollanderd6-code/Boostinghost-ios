import SwiftUI

// MARK: - Hex initializer

extension Color {
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex = String(hex.dropFirst()) }
        var raw: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&raw)
        let r = Double((raw >> 16) & 0xFF) / 255
        let g = Double((raw >> 8)  & 0xFF) / 255
        let b = Double(raw          & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Fond

extension Color {
    static let bhGradientTop    = Color(hex: "#F5F2EA")
    static let bhGradientMid    = Color(hex: "#EBE7DC")
    static let bhGradientBottom = Color(hex: "#E2DDD0")
}

// MARK: - Texte

extension Color {
    /// Titres, valeurs, libellés de ligne
    static let bhEncre      = Color(hex: "#14201B")
    /// Libellés de bouton secondaire
    static let bhEncreDouce = Color(hex: "#2C3A33")
    /// Extraits de message
    static let bhCorps      = Color(hex: "#3E4A44")
    /// Sous-titres, métadonnées, unités — gris le plus clair autorisé (4,86:1)
    static let bhAttenue    = Color(hex: "#5E6B63")
}

// MARK: - Marque & états

extension Color {
    static let bhVert         = Color(hex: "#0E3B2E")
    static let bhVertClair    = Color(hex: "#8FD3B4")
    static let bhOccupe       = Color(hex: "#2E8B62")
    static let bhOccupeFonce  = Color(hex: "#1F6B4C")
    static let bhMentheFond   = Color(red: 46/255, green: 139/255, blue: 98/255).opacity(0.13)
    static let bhTerracotta   = Color(hex: "#A8452A")
    /// Bordure de carte urgente
    static let bhTerracottaBd = Color(red: 255/255, green: 222/255, blue: 210/255).opacity(0.90)
    /// Avertissement (texte)
    static let bhOr           = Color(hex: "#8A5B14")
    static let bhOrClair      = Color(hex: "#C9A15B")
    static let bhOrFond       = Color(red: 251/255, green: 243/255, blue: 226/255).opacity(0.90)
    static let bhDepart       = Color(hex: "#E8B48A")
}

// MARK: - Plateformes

extension Color {
    static let platformAirbnb  = Color(hex: "#FF5A5F")
    static let platformBooking = Color(hex: "#003580")
    static let platformExpedia = Color(hex: "#FFC72C")
    static let platformVrbo    = Color(hex: "#1A5276")
    static let platformDirect  = Color(hex: "#0E3B2E")
    static let platformBloque  = Color(hex: "#9CA3AF")

    /// Normalise les valeurs de plateforme renvoyées par le backend.
    static func platform(_ name: String?) -> Color {
        switch name?.lowercased().trimmingCharacters(in: .whitespaces) {
        case "airbnb":                        return .platformAirbnb
        case "booking", "booking.com":        return .platformBooking
        case "expedia":                       return .platformExpedia
        case "vrbo":                          return .platformVrbo
        case "direct", "manuel", "manual":    return .platformDirect
        case "block", "blocked", "bloque":    return .platformBloque
        default:                              return .platformBloque
        }
    }

    /// Libellé affiché (français, normalisé)
    static func platformLabel(_ name: String?) -> String {
        switch name?.lowercased().trimmingCharacters(in: .whitespaces) {
        case "airbnb":                        return "Airbnb"
        case "booking", "booking.com":        return "Booking.com"
        case "expedia":                       return "Expedia"
        case "vrbo":                          return "Vrbo"
        case "direct", "manuel", "manual":    return "Direct"
        case "block", "blocked", "bloque":    return "Bloqué"
        default:                              return name?.capitalized ?? "—"
        }
    }
}
