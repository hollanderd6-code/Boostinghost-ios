import SwiftUI

// MARK: - Keyboard toolbar with OK button + select-all on focus

struct NumericKeyboardBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)
            ) { notif in
                guard let tf = notif.object as? UITextField,
                      tf.keyboardType == .decimalPad || tf.keyboardType == .numberPad
                else { return }
                DispatchQueue.main.async { tf.selectAll(nil) }
            }
    }
}

extension View {
    func numericKeyboardBar() -> some View {
        modifier(NumericKeyboardBarModifier())
    }
}
