import SwiftUI

// MARK: - Fond d'écran (dégradé + halos)

struct AppBackground: View {
    /// true → halos élargis de l'écran de connexion (ø400 / ø380 au lieu de ø320 / ø330)
    var expandedHalos: Bool = false

    private var haloVert:  CGFloat { expandedHalos ? 400 : 320 }
    private var haloTerra: CGFloat { expandedHalos ? 380 : 330 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dégradé de base 168°
                LinearGradient(
                    stops: [
                        .init(color: .bhGradientTop,    location: 0),
                        .init(color: .bhGradientMid,    location: 0.46),
                        .init(color: .bhGradientBottom, location: 1),
                    ],
                    startPoint: UnitPoint(x: 0.55, y: 0),
                    endPoint:   UnitPoint(x: 0.45, y: 1)
                )

                // vert — haut-droite  blur 18
                Circle()
                    .fill(Color(red: 46/255, green: 139/255, blue: 98/255).opacity(0.42))
                    .frame(width: haloVert, height: haloVert)
                    .blur(radius: 18)
                    .position(x: geo.size.width - 20, y: 60)

                // terracotta — bas-gauche  blur 20
                Circle()
                    .fill(Color(red: 168/255, green: 69/255, blue: 42/255).opacity(0.30))
                    .frame(width: haloTerra, height: haloTerra)
                    .blur(radius: 20)
                    .position(x: 30, y: geo.size.height - 60)

                // vert bas — sous la barre d'onglets  ø280 blur 20
                Circle()
                    .fill(Color(red: 46/255, green: 139/255, blue: 98/255).opacity(0.34))
                    .frame(width: 280, height: 280)
                    .blur(radius: 20)
                    .position(x: geo.size.width / 2, y: geo.size.height + 30)

                // or — milieu-droite  ø240 blur 22
                Circle()
                    .fill(Color(red: 201/255, green: 161/255, blue: 91/255).opacity(0.30))
                    .frame(width: 240, height: 240)
                    .blur(radius: 22)
                    .position(x: geo.size.width + 30, y: geo.size.height * 0.52)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Carte de contenu (verre épais)

struct GlassCardBackground: View {
    var cornerRadius: CGFloat = 22
    /// 0.66–0.72 pour les cartes héro, 0.62 par défaut
    var fillOpacity: Double = 0.62

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(fillOpacity))
            }
            // Bordure externe 1px
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.70), lineWidth: 1)
            }
            // Arête spéculaire interne (haut)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.85), Color.clear],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.06)
                        )
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 1)
            }
            .shadow(
                color: Color(red: 20/255, green: 32/255, blue: 27/255).opacity(0.08),
                radius: 22, x: 0, y: 8
            )
    }
}

// MARK: - Arête spéculaire (pour le verre chrome via .glassEffect)

struct SpecularEdge: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.95), location: 0.00),
                            .init(color: .white.opacity(0.50), location: 0.08),
                            .init(color: .clear,               location: 0.45),
                            .init(color: .white.opacity(0.40), location: 0.92),
                            .init(color: .white.opacity(0.45), location: 1.00),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
        }
    }
}

extension View {
    func specularEdge(cornerRadius: CGFloat) -> some View {
        modifier(SpecularEdge(cornerRadius: cornerRadius))
    }
}

// MARK: - Ombre chrome

extension View {
    func chromeShadow() -> some View {
        shadow(
            color: Color(red: 20/255, green: 32/255, blue: 27/255).opacity(0.20),
            radius: 38, x: 0, y: 14
        )
    }
}
