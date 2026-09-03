import SwiftUI

// MARK: - Carte de contenu générique

struct ListCard<Content: View>: View {
    var cornerRadius: CGFloat = 22
    var heroFill: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background {
                GlassCardBackground(
                    cornerRadius: cornerRadius,
                    fillOpacity: heroFill ? 0.70 : 0.62
                )
            }
    }
}

// MARK: - Ligne dans une carte (avec séparateur)

struct CardRow<Content: View>: View {
    var horizontalPadding: CGFloat = 16
    var verticalPadding: CGFloat   = 12
    var showSeparator: Bool        = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            if showSeparator {
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(height: 0.5)
                    .padding(.leading, horizontalPadding)
            }
        }
    }
}

// MARK: - Carte urgente (bordure terracotta + filet gauche)

struct UrgentCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            // Filet gauche 4px dégradé
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#C4552F"), Color(hex: "#A8452A")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 22,
                        bottomLeadingRadius: 22,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )

            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
        }
        .background {
            GlassCardBackground(cornerRadius: 22, fillOpacity: 0.62)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.bhTerracottaBd, lineWidth: 1)
        }
    }
}

// MARK: - Bouton primaire pleine largeur (vert)

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16.5, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.bhVert, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bouton secondaire (verre)

struct GlassButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .imageScale(.small)
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Color.bhEncreDouce)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassEffect(in: .rect(cornerRadius: 15))
            .specularEdge(cornerRadius: 15)
        }
        .buttonStyle(.plain)
    }
}
