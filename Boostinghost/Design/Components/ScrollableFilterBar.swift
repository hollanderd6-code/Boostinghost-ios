import SwiftUI

/// Barre de filtres horizontale scrollable — puces sélectionnables.
/// Deux styles : .light (fond blanc translucide) et .prominent (vert sur sélection).
struct ScrollableFilterBar: View {

    enum Style { case light, prominent }

    struct Chip: Identifiable {
        let id: String        // identité stable pour ForEach
        let filterId: String? // valeur transmise à onSelect (nil = « Tous »)
        let label: String
    }

    let chips: [Chip]
    let selectedId: String?
    let style: Style
    let onSelect: (String?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips) { chip in
                    Button {
                        onSelect(chip.filterId)
                    } label: {
                        chipLabel(chip: chip)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: selectedId)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    @ViewBuilder
    private func chipLabel(chip: Chip) -> some View {
        let selected = selectedId == chip.filterId
        switch style {
        case .light:
            Text(chip.label)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.bhEncre : Color.bhAttenue)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(selected ? Color.white.opacity(0.55) : Color.white.opacity(0.22))
                }
        case .prominent:
            if selected {
                Text(chip.label)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.bhVert, in: Capsule())
            } else {
                Text(chip.label)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.bhEncre)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .glassEffect(in: .rect(cornerRadius: 16))
            }
        }
    }
}
