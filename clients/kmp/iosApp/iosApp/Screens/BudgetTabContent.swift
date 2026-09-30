import SharedLogic
import SwiftUI

/// 予算 tab root content (`Budget4.dc.html`): the month in view's budgets.
///
/// From the top: the offer to close the earliest ended month still open
/// (`budget-close-offer`, `2月を締めましょう`), the whole-month budget
/// (`budget-whole`, shown unset too), every category with a budget or with
/// spending in category order (`budget-row-<category id>`), and the ledger's
/// savings (`budget-savings`, `貯金 11,500円`). The whole month, a row or
/// ＋ 予算を追加 (`budget-add`) opens the budget sheet; the offer opens the
/// sheet that closes the month.
internal struct BudgetTabContent: View {
    // Held here (the tab root's own content view); see `HomeTabContent`'s
    // own doc comment on `lifecycle` for why.
    @State private var lifecycle: TabRootLifecycle = TabRootLifecycle(screenID: "budget")
    @State private var sheetRequest: BudgetSheetRequest?
    @State private var isClosing: Bool = false

    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    // The budgets, when the records shown are the ledger in view's.
    private var view: BudgetView? {
        let state: LedgerUiState = self.ledgerStore.state
        guard state.isLoaded, (state.ledgerId ?? "") == self.store.selectedLedgerId else {
            return nil
        }
        return state.budgetView(todayIso: self.store.todayIso)
    }

    internal var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            if let message = self.ledgerStore.state.loadErrorMessage {
                Text(message)
                    .foregroundStyle(Theme.mutedText)
            }
            if let view = self.view {
                self.content(view)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(Theme.Spacing.large)
        .tabRootLifecycleHook(screenID: "budget", creationCount: self.lifecycle.creationCount)
        .sheet(item: self.$sheetRequest) { request in
            BudgetEditSheet(
                request: request,
                monthIso: self.view?.month ?? self.store.todayMonthIso,
            )
        }
        .sheet(isPresented: self.$isClosing) {
            MonthCloseSheet()
        }
    }

    @ViewBuilder
    private func content(_ view: BudgetView) -> some View {
        if let offer = view.closeOffer {
            self.closeOffer(offer)
        }
        BudgetWholeCard(whole: view.whole) {
            self.sheetRequest = .whole
        }
        HStack(alignment: .firstTextBaseline) {
            Text("分類ごと")
                .font(.footnote)
                .foregroundStyle(Theme.mutedText)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button("＋ 予算を追加") {
                self.sheetRequest = .add
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.accent)
            .frame(minHeight: Theme.minimumTapTarget)
            .accessibilityIdentifier("budget-add")
        }
        .padding(.horizontal, Theme.Spacing.extraSmall)
        self.rows(view.rows)
        self.savings(view)
    }

    private func closeOffer(_ offer: CloseOffer) -> some View {
        Button {
            self.isClosing = true
        } label: {
            HStack(spacing: Theme.Spacing.medium) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: Theme.Spacing.extraExtraSmall) {
                    Text(offer.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.text)
                    Text(offer.note)
                        .font(.caption)
                        .foregroundStyle(Theme.mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("締める")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(Theme.Spacing.medium)
            .background(
                Theme.accentTint, in: RoundedRectangle(cornerRadius: Theme.Budgets.offerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Budgets.offerRadius)
                    .strokeBorder(Theme.accent.opacity(Theme.Budgets.offerBorderOpacity))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(offer.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("budget-close-offer")
    }

    @ViewBuilder
    private func rows(_ rows: [BudgetRow]) -> some View {
        if rows.isEmpty {
            Text("この月の予算と支出はまだありません")
                .font(.subheadline)
                .foregroundStyle(Theme.mutedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.large)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.categoryId) { index, row in
                    if index > 0 {
                        Divider()
                            .overlay(Theme.line)
                            .padding(.leading, Theme.Budgets.dividerInset)
                    }
                    BudgetRowView(row: row) {
                        if let categoryId = row.categoryId {
                            self.sheetRequest = .category(categoryId)
                        }
                    }
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius)
                    .strokeBorder(Theme.line)
            }
        }
    }

    private func savings(_ view: BudgetView) -> some View {
        HStack {
            Text("貯金")
                .font(.subheadline)
                .foregroundStyle(Theme.mutedText)
            Spacer()
            Text(view.savingsAmountText)
                .font(.body.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.text)
        }
        .padding(.horizontal, Theme.Spacing.medium)
        .padding(.vertical, Theme.Spacing.medium)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius)
                .strokeBorder(Theme.line)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(view.savingsText)
        .accessibilityIdentifier("budget-savings")
    }
}

#Preview {
    ScrollView {
        BudgetTabContent()
    }
}
