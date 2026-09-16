import SwiftUI

// Reusable sheet to pick a property when a setup step needs to target a specific logement.
// onSelect is called on the main actor after the user taps a row.
struct PropertyPickerSheet: View {
    let title: String
    let properties: [Property]
    let onSelect: (Property) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ListCard {
                            ForEach(Array(properties.enumerated()), id: \.element.id) { idx, prop in
                                CardRow(showSeparator: idx < properties.count - 1) {
                                    Button {
                                        onSelect(prop)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 14) {
                                            Image(systemName: "building.2")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(Color.bhVert)
                                                .frame(width: 22)
                                            Text(prop.name.isEmpty ? "Logement" : prop.name)
                                                .font(.system(size: 15.5))
                                                .foregroundStyle(Color.bhEncre)
                                            Spacer(minLength: 8)
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(Color.bhAttenue.opacity(0.55))
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                    }
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            SheetHandle()
            HStack {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(Color.bhEncre)
                Spacer()
                Button("Fermer") { dismiss() }
                    .font(.system(size: 16.5, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }
}
