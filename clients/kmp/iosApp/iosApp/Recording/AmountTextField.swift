import SharedLogic
import SwiftUI
import UIKit

/// A number-pad field for whole yen or a day of the month.
///
/// It takes digits only, shows them grouped by thousands while they are
/// typed (`1,200`, PRODUCT.md §5), and puts the caret after the last digit
/// whenever it starts editing, so deleting always removes what is there,
/// wherever it was tapped. The binding holds the digits alone.
internal struct AmountTextField: UIViewRepresentable {
    /// The coordinator relaying the field's edits to the binding.
    internal final class Coordinator: NSObject, UITextFieldDelegate {
        internal var text: Binding<String>

        internal init(text: Binding<String>) {
            self.text = text
        }

        // Puts the caret after the `count`th digit of the field's text.
        private static func placeCaret(in field: UITextField, afterDigits count: Int) {
            var seen: Int = 0
            var offset: Int = 0
            for character in field.text ?? "" where seen < count {
                offset += character.utf16.count
                if character.isNumber {
                    seen += 1
                }
            }
            if let position = field.position(from: field.beginningOfDocument, offset: offset) {
                field.selectedTextRange = field.textRange(from: position, to: position)
            }
        }

        @objc
        internal func editingChanged(_ field: UITextField) {
            self.text.wrappedValue = (field.text ?? "").filter(\.isNumber)
        }

        internal func textFieldDidBeginEditing(_ textField: UITextField) {
            Task { @MainActor in
                let end: UITextPosition = textField.endOfDocument
                textField.selectedTextRange = textField.textRange(from: end, to: end)
            }
        }

        // Applies the edit to the digits and shows them grouped again, the
        // caret staying after the same digit. Deleting only a separator
        // deletes the digit before it.
        internal func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String,
        ) -> Bool {
            let current: String = textField.text ?? ""
            guard
                string.allSatisfy({ character in character.isASCII && character.isNumber }),
                let replaced = Range(range, in: current)
            else {
                return false
            }
            var start: String.Index = replaced.lowerBound
            let isSeparatorDeleted: Bool =
                string.isEmpty && !replaced.isEmpty
                && current[replaced].allSatisfy { character in !character.isNumber }
            if isSeparatorDeleted, start > current.startIndex {
                start = current.index(before: start)
            }
            let before: String = current[..<start].filter(\.isNumber)
            let after: String = current[replaced.upperBound...].filter(\.isNumber)
            let digits: String = before + string + after
            let grouped: String = AmountText.shared.grouped(text: digits)
            textField.text = grouped
            Self.placeCaret(in: textField, afterDigits: before.count + string.count)
            self.text.wrappedValue = digits
            return false
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
        let grouped: String = AmountText.shared.grouped(text: self.text.wrappedValue)
        if uiView.text != grouped {
            uiView.text = grouped
        }
    }

    private func configure(_ field: UITextField) {
        field.font = self.font
        field.textColor = self.color
        field.textAlignment = self.alignment
    }
}
