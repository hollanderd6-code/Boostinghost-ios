import SwiftUI

// MARK: - Model

struct ToastMessage: Equatable {
    enum Style { case success, warning }
    let text: String
    let style: Style
}

// MARK: - View

private struct ToastBannerView: View {
    let message: ToastMessage
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: message.style == .success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
            Text(message.text)
                .font(.system(size: 14, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(message.style == .success ? Color.bhOccupe : Color.bhTerracotta,
                    in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .onTapGesture { onDismiss() }
    }
}

// MARK: - View modifier

private struct ToastOverlayModifier: ViewModifier {
    @Binding var toast: ToastMessage?
    @State private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let msg = toast {
                ToastBannerView(message: msg) { dismiss() }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear { scheduleAutoDismiss() }
                    .onChange(of: msg) { scheduleAutoDismiss() }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toast)
    }

    private func scheduleAutoDismiss() {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    private func dismiss() {
        task?.cancel()
        task = nil
        toast = nil
    }
}

extension View {
    func toastOverlay(_ toast: Binding<ToastMessage?>) -> some View {
        modifier(ToastOverlayModifier(toast: toast))
    }
}
