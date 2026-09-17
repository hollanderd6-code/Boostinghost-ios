import SwiftUI

struct ContextualTipView: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.bhOr)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#5E6B63"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.bhAttenue)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44, alignment: .topTrailing)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.22))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }
}
