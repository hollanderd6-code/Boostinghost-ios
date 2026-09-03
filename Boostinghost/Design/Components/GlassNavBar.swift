import SwiftUI

// MARK: - Barre de navigation en verre

/// Barre haute : sur-titre + grand titre + actions à droite.
/// Ancrée sous la safe area supérieure, le contenu défile dessous.
struct GlassNavBar<Trailing: View>: View {
    let superTitle: String
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(superTitle)
                    .font(.bhSurTitre)
                    .foregroundStyle(Color.bhAttenue)
                Text(title)
                    .bhGrandTitre()
            }
            Spacer(minLength: 12)
            trailing()
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }
}

// MARK: - Bouton circulaire en verre (loupe, etc.)

struct GlassCircleButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void

    init(icon: String, size: CGFloat = 38, action: @escaping () -> Void) {
        self.icon = icon
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .imageScale(.medium)
                .foregroundStyle(Color.bhEncre)
                .frame(width: size, height: size)
                .glassEffect(in: .circle)
                .specularEdge(cornerRadius: size / 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Rond d'initiales (ouvre Mon compte)

struct InitialsButton: View {
    @Environment(AuthStore.self) var authStore
    let action: () -> Void

    private var isDelegating: Bool {
        guard case .delegating = authStore.agencyContext else { return false }
        return true
    }

    private var initials: String {
        let words = (authStore.session?.displayName ?? "").split(separator: " ").prefix(2)
        return words.compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    var body: some View {
        Button(action: action) {
            Text(initials.isEmpty ? "?" : initials)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isDelegating ? Color.white : Color.bhVert)
                .frame(width: 38, height: 38)
                .background(isDelegating ? Color.bhTerracotta : Color(hex: "#DCE8E1"), in: Circle())
        }
        .buttonStyle(.plain)
    }
}
