import SharedLogic
import SwiftUI

/// 要確認の記録 (`Review7.dc.html`): every record of the ledger in view
/// marked needs-review, whatever its month, newest first, grouped by day.
///
/// Each is a row `review-list-row-<yyyy-MM-dd>-<id>`, labelled like home's
/// rows and carrying the 要確認 mark; choosing it opens its edit sheet, which
/// explains the mark and can mark it reviewed. With none left it says so.
internal struct ReviewRecordsScreen: View {
    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    @Environment(AppRouter.self)
    private var router: AppRouter

    internal var body: some View {
        List {
            Section {
                EmptyView()
            } header: {
                Text("月をまたいで、印が付いている記録をすべて表示します")
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedText)
                    .textCase(nil)
            }
            if self.ledgerStore.reviewSections.isEmpty {
                Section {
                    Text("要確認の記録はありません")
                        .font(.subheadline)
                        .foregroundStyle(Theme.mutedText)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Theme.background)
                }
            } else {
                ForEach(self.ledgerStore.reviewSections, id: \.date) { section in
                    Section(section.title) {
                        ForEach(section.rows, id: \.id) { row in
                            self.row(row)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("要確認の記録")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ row: TransactionRow) -> some View {
        Button {
            if let transaction = self.ledgerStore.transaction(id: row.id) {
                self.router.entrySheet = .edit(transaction)
            }
        } label: {
            TransactionRowView(row: row)
        }
        .buttonStyle(.plain)
        .listRowBackground(Theme.surface)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("review-list-row-\(row.date)-\(row.id)")
    }
}
