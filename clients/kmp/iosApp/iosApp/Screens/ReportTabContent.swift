import SharedLogic
import SwiftUI

/// レポート tab root content (`Report3.dc.html`): the month in view's
/// spending by category as a ring with its list beside it, largest first,
/// then the twelve months ending with it as bars with their list below.
///
/// Every chart shows its figures as text: the share's rows are
/// `report-share-<category id>` (`食費 3,000円 50%`), the trend's
/// `report-trend-<yyyy-MM>` (`2025年4月 1,000円`). Income is never charted.
internal struct ReportTabContent: View {
    // Held here (the tab root's own content view); see `HomeTabContent`'s
    // own doc comment on `lifecycle` for why.
    @State private var lifecycle: TabRootLifecycle = TabRootLifecycle(screenID: "report")

    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize: DynamicTypeSize

    @ScaledMetric(relativeTo: .footnote)
    private var percentWidth: CGFloat = Theme.Reports.percentWidth

    // Whether the records shown are the ledger in view's.
    private var isShowingLedgerInView: Bool {
        let state: LedgerUiState = self.ledgerStore.state
        return state.isLoaded && (state.ledgerId ?? "") == self.store.selectedLedgerId
    }

    private var shareLayout: AnyLayout {
        if self.dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .center, spacing: Theme.Spacing.medium))
        } else {
            AnyLayout(HStackLayout(alignment: .center, spacing: Theme.Spacing.medium))
        }
    }

    internal var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            if let message = self.ledgerStore.state.loadErrorMessage {
                Text(message)
                    .foregroundStyle(Theme.mutedText)
            }
            if self.isShowingLedgerInView, let report = self.ledgerStore.state.monthReport() {
                self.card {
                    self.share(report)
                }
                self.card {
                    self.trend(report)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(Theme.Spacing.large)
        .tabRootLifecycleHook(screenID: "report", creationCount: self.lifecycle.creationCount)
    }

    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            content()
        }
        .padding(Theme.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius)
                .strokeBorder(Theme.line)
        }
    }

    private func heading(_ title: String, _ note: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Theme.mutedText)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.extraExtraSmall) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Theme.mutedText)
            }
        }
    }

    @ViewBuilder
    private func share(_ report: MonthReport) -> some View {
        self.heading(report.shareTitle, "支出のみ")
        if report.shares.isEmpty {
            Text("この月の支出はまだありません")
                .font(.subheadline)
                .foregroundStyle(Theme.mutedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.large)
        } else {
            self.shareLayout {
                ShareRing(shares: report.shares, expenseText: report.expenseText)
                VStack(spacing: Theme.Spacing.extraSmall) {
                    ForEach(report.shares, id: \.categoryId) { share in
                        self.shareRow(share)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func shareRow(_ share: ShareRow) -> some View {
        HStack(spacing: Theme.Spacing.small) {
            RoundedRectangle(cornerRadius: Theme.Reports.swatchRadius)
                .fill(ShareRing.color(defaultIndex: share.iconIndex))
                .frame(width: Theme.Reports.swatchSize, height: Theme.Reports.swatchSize)
            Text(share.name)
                .font(.subheadline)
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(share.amountText)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.text)
            Text(share.percentText)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Theme.mutedText)
                .frame(minWidth: self.percentWidth, alignment: .trailing)
        }
        .frame(minHeight: Theme.Reports.shareRowMinHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(share.accessibilityLabel)
        .accessibilityIdentifier("report-share-\(share.categoryId)")
    }

    @ViewBuilder
    private func trend(_ report: MonthReport) -> some View {
        self.heading("12か月の推移", report.trendRange)
        TrendBars(trend: report.trend)
        Divider()
            .overlay(Theme.line)
        VStack(spacing: 0) {
            ForEach(report.trend, id: \.month) { month in
                self.trendRow(month)
            }
        }
    }

    private func trendRow(_ month: TrendRow) -> some View {
        HStack {
            Text(month.title)
                .foregroundStyle(Theme.mutedText)
            Spacer()
            Text(month.amountText)
                .monospacedDigit()
                .foregroundStyle(Theme.text)
        }
        .font(.footnote.weight(month.isMonthInView ? .bold : .regular))
        .padding(.vertical, Theme.Spacing.extraSmall)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(month.accessibilityLabel)
        .accessibilityIdentifier("report-trend-\(month.month)")
    }
}

#Preview {
    ScrollView {
        ReportTabContent()
    }
}
