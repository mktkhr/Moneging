import SharedLogic
import SwiftUI

/// Asks before archiving a category: what archiving does, then
/// アーカイブする (`category-archive-confirm`) or キャンセル.
///
/// A sheet sized to its content rather than an alert, so its buttons are
/// plain, individually identified controls.
internal struct ArchiveCategorySheet: View {
    internal let category: SharedLogic.Category
    internal let onConfirm: () -> Void

    @Environment(\.dismiss)
    private var dismiss: DismissAction

    internal var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("「\(self.category.name)」をアーカイブしますか？")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
            Text("これまでの記録には残りますが、新しい記録では選べなくなります。")
                .font(.subheadline)
                .foregroundStyle(Theme.mutedText)
            Button {
                self.onConfirm()
                self.dismiss()
            } label: {
                Text("アーカイブする")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Recording.destructive)
            .accessibilityIdentifier("category-archive-confirm")
            Button {
                self.dismiss()
            } label: {
                Text("キャンセル")
                    .font(.body)
                    .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
            }
            .buttonStyle(.bordered)
            .tint(Theme.text)
            .accessibilityIdentifier("category-archive-cancel")
        }
        .padding(Theme.Spacing.extraLarge)
    }
}
