import SwiftUI

/// Sélecteur de vue en verre (Planning/Revenus, filtres, etc.)
struct SegmentedGlass<T: Hashable>: View {
    let options: [(label: String, value: T)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let selected = selection == option.value
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(.system(size: 14.5, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Color.bhEncre : Color.bhAttenue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(Color.white.opacity(0.85))
                                    .shadow(
                                        color: Color(red: 20/255, green: 32/255, blue: 27/255).opacity(0.08),
                                        radius: 4, x: 0, y: 2
                                    )
                            }
                        }
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.18), value: selection)
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.28))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(Color.white.opacity(0.50), lineWidth: 1)
                }
        }
    }
}
