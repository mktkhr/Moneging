import SharedLogic
import SwiftUI

/// 毎月の定期 of the ledger in view (`Recurring2.dc.html`,
/// `RecurringEnded2.dc.html`): each rule with its amount and category, when
/// it falls (`毎月25日・土日祝なら翌平日`) and its next date; the ended ones
/// below, under 終了した定期, with `2026年2月まで` instead. + opens the rule
/// sheet to add one; a row opens it to change, end or delete that rule.
///
/// Rows are `recurring-rule-<rule id>`, each one accessibility element
/// whose label reads the rule (`毎月25日 80,000円 住居、土日祝なら翌平日、次回
/// 3月25日（水）`); the heading of the ended ones is `recurring-ended-header`;
/// + is `recurring-add`.
internal struct RecurringRulesScreen: View {
    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    @State private var sheetRequest: RecurringRuleSheetRequest?

    private var rows: [RecurringRuleRow] {
        self.ledgerStore.state.recurringRuleRows(todayIso: self.store.todayIso)
    }

    private var activeRows: [RecurringRuleRow] {
        self.rows.filter { !$0.isEnded }
    }

    private var endedRows: [RecurringRuleRow] {
        self.rows.filter(\.isEnded)
    }

    internal var body: some View {
        List {
            Section {
                if self.rows.isEmpty {
                    Text("毎月の定期はまだありません")
                        .foregroundStyle(Theme.mutedText)
                        .listRowBackground(Theme.surface)
                }
                ForEach(self.activeRows, id: \.id) { row in
                    self.row(row)
                }
            } footer: {
                Text("その日になると自動で記録されます。記録には「定期」の印が付きます。")
            }
            if !self.endedRows.isEmpty {
                Section {
                    ForEach(self.endedRows, id: \.id) { row in
                        self.row(row)
                    }
                } header: {
                    Text("終了した定期")
                        .accessibilityIdentifier("recurring-ended-header")
                } footer: {
                    Text("終了した定期は記録されません。押すと修正・削除できます。")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("毎月の定期")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("定期を追加", systemImage: "plus") {
                    self.sheetRequest = .add
                }
                .accessibilityIdentifier("recurring-add")
            }
        }
        .sheet(item: self.$sheetRequest) { request in
            RecurringRuleSheet(ruleId: request.ruleId)
        }
    }

    private func row(_ row: RecurringRuleRow) -> some View {
        Button {
            self.sheetRequest = .change(row.id)
        } label: {
            self.label(row)
        }
        .buttonStyle(.plain)
        .listRowBackground(Theme.surface)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("recurring-rule-\(row.id)")
    }

    private func label(_ row: RecurringRuleRow) -> some View {
        HStack(spacing: Theme.Spacing.medium) {
            CategoryIcon(
                defaultIndex: row.iconIndex.map { Int(truncating: $0) },
                isIncome: row.isIncome,
            )
            VStack(alignment: .leading, spacing: Theme.Spacing.extraExtraSmall) {
                Text(row.title)
                    .font(.body.weight(row.isEnded ? .medium : .semibold))
                    .foregroundStyle(row.isEnded ? Theme.mutedText : Theme.text)
                Text(row.schedule)
                    .font(.caption)
                    .foregroundStyle(Theme.mutedText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            self.trailing(row)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func trailing(_ row: RecurringRuleRow) -> some View {
        if let next = row.nextDate {
            VStack(alignment: .trailing, spacing: Theme.Spacing.extraExtraSmall) {
                Text("次回")
                    .font(.caption2)
                    .foregroundStyle(Theme.mutedText)
                Text(next)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.text)
            }
        } else if let ended = row.endedText {
            VStack(alignment: .trailing, spacing: Theme.Spacing.extraExtraSmall) {
                Text("終了")
                    .font(.caption2)
                    .foregroundStyle(Theme.mutedText)
                Text(ended)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.mutedText)
            }
        }
    }
}
