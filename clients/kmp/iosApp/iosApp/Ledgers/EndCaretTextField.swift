import UIKit

/// A text field whose text never reaches the trailing edge of the field.
///
/// A strip at the trailing edge (`Theme.nameFieldTrailingInsetFraction` of
/// the width) stays clear of the text, so a tap there is always past the
/// last character and puts the caret at the end of the text.
internal final class EndCaretTextField: UITextField {
    private static func clearingTrailingEdge(_ rect: CGRect, of bounds: CGRect) -> CGRect {
        let strip: CGFloat = bounds.width * Theme.nameFieldTrailingInsetFraction
        var cleared: CGRect = rect
        cleared.size.width = max(0, rect.width - strip)
        return cleared
    }

    override internal func textRect(forBounds bounds: CGRect) -> CGRect {
        Self.clearingTrailingEdge(super.textRect(forBounds: bounds), of: bounds)
    }

    override internal func editingRect(forBounds bounds: CGRect) -> CGRect {
        Self.clearingTrailingEdge(super.editingRect(forBounds: bounds), of: bounds)
    }

    override internal func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        Self.clearingTrailingEdge(super.placeholderRect(forBounds: bounds), of: bounds)
    }

    deinit {
        // No teardown needed; explicit per the project's lint policy.
    }
}
