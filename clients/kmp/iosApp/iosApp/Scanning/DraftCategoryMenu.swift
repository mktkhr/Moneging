import SharedLogic
import SwiftUI

/// The カテゴリ control of a draft's item, or of a draft without items.
///
/// A menu of the ledger's categories and none (その他). Its value is the
/// chosen category's name, empty for none.
internal struct DraftCategoryMenu: View {
    internal let selection: Binding<String?>
    internal let categories: [SharedLogic.Category]
    internal let identifier: String
    /// Its accessible name.
    internal var accessibilityName: String = String(localized: "カテゴリ")

    private var chosen: SharedLogic.Category? {
        self.categories.first { $0.id.description == self.selection.wrappedValue }
    }

    internal var body: some View {
        Menu {
            Button("未選択（その他）") {
                self.selection.wrappedValue = nil
            }
            ForEach(self.categories, id: \.id) { category in
                Button(category.name) {
                    self.selection.wrappedValue = category.id.description
                }
            }
        } label: {
            HStack(spacing: Theme.Spacing.extraSmall) {
                Text("カテゴリ:")
                    .foregroundStyle(Theme.text)
                Text(self.chosen?.name ?? String(localized: "未選択（その他）"))
                    .foregroundStyle(self.chosen == nil ? Theme.mutedText : Theme.accent)
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(Theme.mutedText)
                    .accessibilityHidden(true)
            }
            .font(.caption)
            .frame(minHeight: Theme.minimumTapTarget)
        }
        .accessibilityLabel(self.accessibilityName)
        .accessibilityValue(self.chosen?.name ?? "")
        .accessibilityIdentifier(self.identifier)
    }
}
