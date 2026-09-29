import SwiftUI
import UIKit

/// A number-pad field for whole yen or a day of the month: it takes digits
/// only, and puts the caret after the last digit whenever it starts
/// editing, so deleting always removes what is there, wherever it was
/// tapped.
internal struct AmountTextField: UIViewRepresentable {
    /// The coordinator relaying the field's edits to the binding.
    internal final class Coordinator: NSObject, UITextFieldDelegate {
        internal var text: Binding<String>

        internal init(text: Binding<String>) {
            self.text = text
        }

        @objc
        internal func editingChanged(_ field: UITextField) {
            self.text.wrappedValue = field.text ?? ""
        }

        internal func textFieldDidBeginEditing(_ textField: UITextField) {
            Task { @MainActor in
                let end: UITextPosition = textField.endOfDocument
                textField.selectedTextRange = textField.textRange(from: end, to: end)
            }
        }

        internal func textField(
            _: UITextField,
            shouldChangeCharactersIn _: NSRange,
            replacementString string: String,
        ) -> Bool {
            string.allSatisfy { character in character.isASCII && character.isNumber }
        }

        deinit {
            // No teardown needed; explicit per the project's lint policy.
        }
    }

    internal let placeholder: String
    internal let text: Binding<String>
    internal let identifier: String
    /// The accessibility label (the field's name: 金額, 日).
    internal let label: String
    internal let font: UIFont
    internal let color: UIColor
    internal var alignment: NSTextAlignment = .right

    internal func makeCoordinator() -> Coordinator {
        Coordinator(text: self.text)
    }

    internal func makeUIView(context: Context) -> UITextField {
        let field: UITextField = UITextField()
        field.placeholder = self.placeholder
        field.keyboardType = .numberPad
        field.adjustsFontForContentSizeCategory = true
        field.accessibilityIdentifier = self.identifier
        field.accessibilityLabel = self.label
        field.delegate = context.coordinator
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged,
        )
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        self.configure(field)
        return field
    }

    internal func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.text = self.text
        self.configure(uiView)
        if uiView.text != self.text.wrappedValue {
            uiView.text = self.text.wrappedValue
        }
    }

    private func configure(_ field: UITextField) {
        field.font = self.font
        field.textColor = self.color
        field.textAlignment = self.alignment
    }
}
