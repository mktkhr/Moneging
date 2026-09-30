import SharedLogic
import SwiftUI
import UIKit

/// One item of a draft (`Draft5.dc.html`).
///
/// Its 品名 and 金額 are editable in place, marked 要確認 when the scanner
/// was not sure of it; its カテゴリ is below, and a button removes it.
/// Changing it makes it certain.
internal struct DraftItemRow: View {
    internal let item: Binding<DraftItemState>
    /// Its position among the items, from 0: `draft-item-*-<index>`.
    internal let index: Int
    internal let categories: [SharedLogic.Category]
    internal let onRemove: () -> Void

    internal var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.medium) {
            VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                self.nameAndAmount
                DraftCategoryMenu(
                    selection: self.certain(\.categoryId),
                    categories: self.categories,
                    identifier: "draft-item-category-\(self.index)",
                )
            }
            self.removeButton
        }
        .padding(.horizontal, Theme.Spacing.large)
        .padding(.vertical, Theme.Spacing.small)
    }

    private var nameAndAmount: some View {
        HStack(spacing: Theme.Spacing.small) {
            TextField("品名", text: self.certain(\.name))
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.text)
                .accessibilityLabel("品名")
                .accessibilityIdentifier("draft-item-name-\(self.index)")
            if self.item.wrappedValue.needsReview {
                ReviewMark(field: "item-\(self.index)")
            }
            AmountTextField(
                placeholder: "0",
                text: self.certain(\.amountText),
                identifier: "draft-item-amount-\(self.index)",
                label: "金額",
                font: UIFont.preferredFont(forTextStyle: .body),
                color: UIColor(Theme.text),
            )
            .fixedSize(horizontal: false, vertical: true)
            Text("円")
                .foregroundStyle(Theme.text)
        }
    }

    private var removeButton: some View {
        Button(action: self.onRemove) {
            Image(systemName: "minus.circle")
                .foregroundStyle(Theme.mutedText)
                .frame(minWidth: Theme.minimumTapTarget, minHeight: Theme.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(self.item.wrappedValue.name)を消す")
        .accessibilityIdentifier("draft-item-remove-\(self.index)")
    }

    // A binding to the item's `path` that makes the item certain once changed.
    private func certain<Value: Equatable>(
        _ path: WritableKeyPath<DraftItemState, Value>,
    ) -> Binding<Value> {
        Binding(
            get: { self.item.wrappedValue[keyPath: path] },
            set: { value in
                guard value != self.item.wrappedValue[keyPath: path] else {
                    return
                }
                self.item.wrappedValue[keyPath: path] = value
                self.item.wrappedValue.confidence = Theme.Scanning.certain
            },
        )
    }
}
