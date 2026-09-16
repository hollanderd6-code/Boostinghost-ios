import SwiftUI

// MARK: - Barre de navigation en verre

/// Barre haute : sur-titre + grand titre + actions à droite.
/// Ancrée sous la safe area supérieure, le contenu défile dessous.
/// Le paramètre `footer` (optionnel) permet d'insérer un contrôle
/// supplémentaire (Picker, filterStrip…) dans le même fond en verre.
struct GlassNavBar<Trailing: View, Footer: View>: View {
    let superTitle: String
    let title: String
    let headerBottomPadding: CGFloat
    let trailing: () -> Trailing
    let footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
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
            .padding(.bottom, headerBottomPadding)

            footer()
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }
}

// MARK: - Initialiseurs

/// Sans footer — compatibilité descendante, padding bas 16 pt.
extension GlassNavBar where Footer == EmptyView {
    init(
        superTitle: String,
        title: String,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.superTitle = superTitle
        self.title = title
        self.headerBottomPadding = 16
        self.trailing = trailing
        self.footer = { EmptyView() }
    }
}

/// Avec footer — padding bas du header 12 pt, footer dans le même fond verre.
extension GlassNavBar {
    init(
        superTitle: String,
        title: String,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.superTitle = superTitle
        self.title = title
        self.headerBottomPadding = 12
        self.trailing = trailing
        self.footer = footer
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

    private var initials: String {
        let words = (authStore.session?.displayName ?? "").split(separator: " ").prefix(2)
        return words.compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    var body: some View {
        Button(action: action) {
            Text(initials.isEmpty ? "?" : initials)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(textColor)
                .frame(width: 38, height: 38)
                .background(bgColor, in: Circle())
                .overlay {
                    if case .allAccounts = authStore.agencyContext {
                        Circle().strokeBorder(Color.bhVert, lineWidth: 2.5)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var bgColor: Color {
        switch authStore.agencyContext {
        case .delegating: return Color.bhTerracotta
        default:          return Color(hex: "#DCE8E1")
        }
    }

    private var textColor: Color {
        switch authStore.agencyContext {
        case .delegating: return .white
        default:          return Color.bhVert
        }
    }
}
