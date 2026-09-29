import SwiftUI

/// Asks before deleting a recurring rule (`RecurringDelete2.dc.html`): what
/// deleting does, then 削除 (`recurring-delete-confirm`); × keeps it.
///
/// A sheet sized to its content, as `ArchiveCategorySheet`, so its buttons
/// are plain, individually identified controls.
internal struct DeleteRecurringRuleSheet: View {
    /// The rule as `毎月25日 80,000円 住居`.
    internal let summary: String
    internal let onConfirm: () -> Void

    @Environment(\.dismiss)
    private var dismiss: DismissAction

    internal var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            self.header
            Text("\(self.summary) を一覧から消します。これまでに記録された取引は残ります。")
                .font(.subheadline)
                .foregroundStyle(Theme.mutedText)
            Button {
                self.dismiss()
                self.onConfirm()
            } label: {
                Text("削除")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Recording.destructive)
            .accessibilityIdentifier("recurring-delete-confirm")
        }
        .padding(Theme.Spacing.extraLarge)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.small) {
            Button("キャンセル", systemImage: "xmark", role: .close) {
                self.dismiss()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .tint(Theme.text)
            .frame(minWidth: Theme.minimumTapTarget, minHeight: Theme.minimumTapTarget)
            .accessibilityIdentifier("recurring-delete-cancel")
            Text("この定期を削除しますか？")
                .font(.headline)
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            // Balances × so the title stays centred.
            Spacer()
                .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
                .accessibilityHidden(true)
        }
    }
}
