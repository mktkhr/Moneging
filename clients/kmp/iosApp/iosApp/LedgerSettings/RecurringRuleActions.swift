import SwiftUI

/// What the sheet changing a recurring rule adds below the form
/// (`RecurringModify2.dc.html`): that changes apply to the months not yet
/// recorded, この定期を終了 (`recurring-end`, while the rule has not ended)
/// and 削除 (`recurring-delete`), and what each does.
internal struct RecurringRuleActions: View {
    /// The rule's next date (`2月25日`), or `nil` when it has ended.
    internal let nextDate: String?
    internal let onEnd: () -> Void
    internal let onDelete: () -> Void

    internal var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            self.note("変更は、まだ記録していない月から反映されます。記録済みの取引はそのまま残ります。")
            self.buttons
            if let nextDate = self.nextDate {
                self.note("終了: 次回（\(nextDate)）から記録しません。一覧に「終了」として残ります。")
            }
            self.note("削除: 一覧から消します。記録済みの取引は残ります。")
        }
    }

    private var buttons: some View {
        VStack(spacing: 0) {
            if self.nextDate != nil {
                Button(action: self.onEnd) {
                    Text("この定期を終了")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("recurring-end")
                Divider()
            }
            Button(action: self.onDelete) {
                Text("削除")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.Recording.destructive)
                    .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recurring-delete")
        }
        .padding(.horizontal, Theme.Spacing.large)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
        .padding(.top, Theme.Spacing.small)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Theme.mutedText)
            .padding(.horizontal, Theme.Spacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
