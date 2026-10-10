import SharedLogic
import SwiftUI

/// Marks the record edited reviewed as it is, under its items.
///
/// `このままで確認済みにする` (`review-mark-reviewed`, `RecordReview7.dc.html`)
/// and what clears the mark. Pressing it saves the record as it is, unmarked, then
/// `onReviewed` runs (the sheet closes). Nothing for a record that is not
/// marked.
internal struct MarkReviewedSection: View {
    /// The record edited, or `nil` for a new one.
    internal let transaction: SharedLogic.Transaction?
    internal let onReviewed: () -> Void

    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    @State private var isSaving: Bool = false

    private var markedId: String? {
        guard let id = self.transaction?.id.description,
            self.ledgerStore.reviewExplanation(id: id) != nil
        else {
            return nil
        }
        return id
    }

    internal var body: some View {
        if let id = self.markedId {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Button {
                    self.markReviewed(id: id)
                } label: {
                    Text("このままで確認済みにする")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
                        .background(Theme.surface, in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(Theme.line)
                        }
                }
                .buttonStyle(.plain)
                .disabled(self.isSaving)
                .accessibilityIdentifier("review-mark-reviewed")
                Text("「差額」をなくして保存するか「確認済みにする」を押すと、要確認の印が消えます")
                    .font(.caption)
                    .foregroundStyle(Theme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func markReviewed(id: String) {
        self.isSaving = true
        Task {
            let isSaved: Bool = await self.ledgerStore.markReviewed(id: id)
            self.isSaving = false
            if isSaved {
                self.onReviewed()
            }
        }
    }
}
