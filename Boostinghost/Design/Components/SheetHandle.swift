import SwiftUI

/// Poignée standard pour toutes les feuilles modales.
/// 38 × 5 pt, rayon 3, rgba(20,32,27,.18), 12 pt au-dessus, 14 pt en dessous.
struct SheetHandle: View {
    var body: some View {
        Capsule()
            .fill(Color.bhEncre.opacity(0.18))
            .frame(width: 38, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 14)
    }
}
