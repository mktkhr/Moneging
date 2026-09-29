import SharedLogic
import SwiftUI

/// 毎月の定期 of the ledger in view (`Recurring2.dc.html`): each rule with
/// its amount and category, when it falls (`毎月25日・土日祝なら翌平日`) and
/// its next date. + opens the rule sheet.
///
/// Rows are `recurring-rule-<rule id>`, each one accessibility element
/// whose label reads the rule (`毎月25日 80,000円 住居、土日祝なら翌平日、次回
/// 3月25日（水）`); + is `recurring-add`.
internal struct RecurringRulesScreen: View {
    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    @State private var isRuleSheetPresented: Bool = false

    private var rows: [RecurringRuleRow] {
        self.ledgerStore.state.recurringRuleRows(todayIso: self.store.todayIso)
    }

    internal var body: some View {
        List {
            Section {
                if self.rows.isEmpty {
                    Text("毎月の定期はまだありません")
                        .foregroundStyle(Theme.mutedText)
                        .listRowBackground(Theme.surface)
                }
                ForEach(self.rows, id: \.id) { row in
                    self.row(row)
                }
            } footer: {
                Text("その日になると自動で記録されます。記録には「定期」の印が付きます。")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("毎月の定期")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("定期を追加", systemImage: "plus") {
                    self.isRuleSheetPresented = true
                }
                .accessibilityIdentifier("recurring-add")
            }
        }
        .sheet(isPresented: self.$isRuleSheetPresented) {
            RecurringRuleSheet()
        }
    }

    private func row(_ row: RecurringRuleRow) -> some View {
        HStack(spacing: Theme.Spacing.medium) {
            CategoryIcon(
                defaultIndex: row.iconIndex.map { Int(truncating: $0) },
                isIncome: row.isIncome,
            )
            VStack(alignment: .leading, spacing: Theme.Spacing.extraExtraSmall) {
                Text(row.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.text)
                Text(row.schedule)
                    .font(.caption)
                    .foregroundStyle(Theme.mutedText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let next = row.nextDate {
                VStack(alignment: .trailing, spacing: Theme.Spacing.extraExtraSmall) {
                    Text("次回")
                        .font(.caption2)
                        .foregroundStyle(Theme.mutedText)
                    Text(next)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.text)
                }
            }
        }
        .listRowBackground(Theme.surface)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityIdentifier("recurring-rule-\(row.id)")
    }
}
