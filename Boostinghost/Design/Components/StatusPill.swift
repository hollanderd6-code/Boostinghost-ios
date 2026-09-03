import SwiftUI

// MARK: - Styles de pastille

enum PillStyle {
    case vert, or, terracotta, neutre

    var background: Color {
        switch self {
        case .vert:       return .bhMentheFond
        case .or:         return .bhOrFond
        case .terracotta: return Color(red: 253/255, green: 240/255, blue: 236/255).opacity(0.72)
        case .neutre:     return Color.white.opacity(0.45)
        }
    }

    var foreground: Color {
        switch self {
        case .vert:       return .bhOccupeFonce
        case .or:         return .bhOr
        case .terracotta: return .bhTerracotta
        case .neutre:     return .bhAttenue
        }
    }
}

// MARK: - Pastille d'état

struct StatusPill: View {
    let text: String
    var style: PillStyle = .neutre
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .imageScale(.small)
            }
            Text(text)
                .font(.bhMeta)
        }
        .foregroundStyle(style.foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(style.background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

// MARK: - Badge plateforme

struct PlatformBadge: View {
    let platform: String?

    var body: some View {
        Text(Color.platformLabel(platform))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.platform(platform), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Point de calendrier (ø4)

struct CalendarDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 4, height: 4)
    }
}
