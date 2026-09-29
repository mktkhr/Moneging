import SwiftUI
import UIKit

/// A one-line text field whose text includes what is still being composed.
///
/// SwiftUI's `TextField` hands its binding only committed text, so while
/// Japanese input is being composed (marked text) a name looks shorter, or
/// empty, to whatever checks it. This field reports `UITextField.text`,
/// marked text included, on every edit, so the name rule and the header
/// see the name exactly as it is shown. Nothing typed is ever cut off.
///
/// The text stops short of the field's trailing edge
/// (`EndCaretTextField`), so a tap near that edge always lands after the
/// text and puts the caret at its end, however long the name is.
internal struct NameTextField: UIViewRepresentable {
    /// The coordinator relaying the field's edits to the binding.
    internal final class Coordinator: NSObject, UITextFieldDelegate {
        internal var text: Binding<String>
        internal var onSubmit: () -> Void

        internal init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self.text = text
            self.onSubmit = onSubmit
        }

        @objc
        internal func editingChanged(_ field: UITextField) {
            self.text.wrappedValue = field.text ?? ""
        }

        internal func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            self.onSubmit()
            return true
        }

        deinit {
            // No teardown needed; explicit per the project's lint policy.
        }
    }

    internal let placeholder: String
    internal let text: Binding<String>
    internal let identifier: String
    internal let onSubmit: () -> Void
    /// Whether the field takes the keyboard as soon as it appears.
    internal var isInitiallyFocused: Bool = false

    internal func makeCoordinator() -> Coordinator {
        Coordinator(text: self.text, onSubmit: self.onSubmit)
    }

    internal func makeUIView(context: Context) -> UITextField {
        let field: UITextField = EndCaretTextField()
        field.placeholder = self.placeholder
        field.font = UIFont.preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.textColor = UIColor(Theme.text)
        field.returnKeyType = .done
        field.accessibilityIdentifier = self.identifier
        field.delegate = context.coordinator
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged,
        )
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.text = self.text.wrappedValue
        if self.isInitiallyFocused {
            Task { @MainActor in
                field.becomeFirstResponder()
            }
        }
        return field
    }

    internal func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.text = self.text
        context.coordinator.onSubmit = self.onSubmit
        // Only a change from outside is written back: writing the same text
        // while it is being composed would end the composition.
        if uiView.text != self.text.wrappedValue {
            uiView.text = self.text.wrappedValue
        }
    }
}
