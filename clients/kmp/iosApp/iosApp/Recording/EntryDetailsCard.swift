import SwiftUI

/// The card of the entry sheet under the amount and category: 日付, then
/// 店名 (an expense's only) and メモ.
///
/// The fields are `entry-store` and `entry-memo`; return closes the
/// keyboard.
internal struct EntryDetailsCard: View {
    internal let date: Binding<Date>
    internal let storeName: Binding<String>
    internal let memo: Binding<String>
    internal let isIncome: Bool
    internal let todayIso: String

    @FocusState private var focusedField: EntryField?

    internal var body: some View {
        VStack(spacing: 0) {
            EntryDateRow(date: self.date, todayIso: self.todayIso)
            Divider()
            if !self.isIncome {
                self.textRow(
                    name: "店名",
                    placeholder: "例: セブン-イレブン",
                    text: self.storeName,
                    field: .storeName,
                    identifier: "entry-store",
                )
                Divider()
            }
            self.textRow(
                name: "メモ",
                placeholder: "メモ",
                text: self.memo,
                field: .memo,
                identifier: "entry-memo",
            )
        }
        .padding(.horizontal, Theme.Spacing.large)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
    }

    private func textRow(
        name: String,
        placeholder: String,
        text: Binding<String>,
        field: EntryField,
        identifier: String,
    ) -> some View {
        HStack(spacing: Theme.Spacing.medium) {
            Text(name)
                .foregroundStyle(Theme.mutedText)
                .accessibilityHidden(true)
            TextField(placeholder, text: text)
                .foregroundStyle(Theme.text)
                .focused(self.$focusedField, equals: field)
                .submitLabel(.done)
                .onSubmit {
                    self.focusedField = nil
                }
                .accessibilityLabel(name)
                .accessibilityIdentifier(identifier)
        }
        .frame(minHeight: Theme.minimumTapTarget)
    }
}
