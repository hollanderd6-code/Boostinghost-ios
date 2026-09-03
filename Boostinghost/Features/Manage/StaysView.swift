import SwiftUI

struct StaysView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackground()
            Text("Séjours — à construire")
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) { navBar }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var navBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
                    .frame(width: 36, height: 36)
                    .glassEffect(in: .circle)
                    .specularEdge(cornerRadius: 18)
            }
            .buttonStyle(.plain)

            Text("Séjours")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.bhEncre)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }
}
