import SharedLogic
import SwiftUI

/// The warning above a draft's items while they do not add up to 合計
/// (`Draft6.dc.html`), `draft-mismatch-warning`.
///
/// It names the items' sum (in the warning colour), the total and the
/// difference, ends `次のどちらかで直せます。`, and offers right below it the
/// two fixes: adding the item `差額` (`draft-mismatch-add-difference`, only
/// while the sum is below the total) and recording the total alone
/// (`draft-mismatch-total-only`).
internal struct DraftMismatchCard: View {
    internal let mismatch: DraftMismatch
    internal let onAddDifference: () -> Void
    internal let onTotalOnly: () -> Void

    // The warning with the items' sum (its first amount) bold in the warning colour.
    private var warning: AttributedString {
        var text: AttributedString = AttributedString(self.mismatch.warningText)
        if let sum = text.range(of: self.mismatch.itemsSumText) {
            text[sum].foregroundColor = Theme.Scanning.review
            text[sum].font = .subheadline.weight(.bold)
        }
        return text
    }

    // The warning and `次のどちらかで直せます。`, read as one element.
    private var warningHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.small) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Theme.Scanning.review)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.extraExtraSmall) {
                Text(self.warning)
                    .font(.subheadline)
                    .foregroundStyle(Theme.text)
                Text(self.mismatch.invitationText)
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedText)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.mismatch.warningText + self.mismatch.invitationText)
        .accessibilityIdentifier("draft-mismatch-warning")
    }

    internal var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            self.warningHeader
            if let addDifference = self.mismatch.addDifferenceText {
                self.fix(
                    addDifference,
                    isPrimary: true,
                    identifier: "draft-mismatch-add-difference",
                    action: self.onAddDifference,
                )
            }
            self.fix(
                self.mismatch.totalOnlyText,
                isPrimary: false,
                identifier: "draft-mismatch-total-only",
                action: self.onTotalOnly,
            )
        }
        .padding(Theme.Spacing.large)
        .background(
            Theme.Scanning.review.opacity(Theme.Scanning.mismatchTintOpacity),
            in: RoundedRectangle(cornerRadius: Theme.Scanning.mismatchRadius),
        )
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Scanning.mismatchRadius)
                .strokeBorder(
                    Theme.Scanning.review.opacity(Theme.Scanning.mismatchBorderOpacity),
                    lineWidth: Theme.Scanning.mismatchBorderWidth,
                )
        }
    }

    private func fix(
        _ title: String,
        isPrimary: Bool,
        identifier: String,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isPrimary ? .bold : .medium))
                .foregroundStyle(isPrimary ? Theme.accent : Theme.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.medium)
                .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
                .background(Theme.surface, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(
                            Theme.line,
                            lineWidth: Theme.Scanning.mismatchBorderWidth,
                        )
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }
}
