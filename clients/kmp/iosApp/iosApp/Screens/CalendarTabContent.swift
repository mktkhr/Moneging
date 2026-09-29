import SharedLogic
import SwiftUI

/// カレンダー tab root content (`Calendar3.dc.html`): the month in view in
/// weeks starting on Sunday, each day with its spending in full or the NMD
/// badge, then the chosen day's transactions below the calendar.
///
/// The chosen day is today's when the month in view is today's, until a
/// day is chosen. Its transactions are rows of the same identifier and
/// label as home's (`transaction-row-<yyyy-MM-dd>-<id>`); tapping one opens
/// its edit sheet.
internal struct CalendarTabContent: View {
    private static let daysInWeek: Int = 7

    // Held here (the tab root's own content view); see `HomeTabContent`'s
    // own doc comment on `lifecycle` for why.
    @State private var lifecycle: TabRootLifecycle = TabRootLifecycle(screenID: "calendar")

    // The day the user chose (ISO), or `nil` before one is chosen.
    @State private var chosenDate: String?

    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    @Environment(AppRouter.self)
    private var router: AppRouter

    // Whether the records shown are the ledger in view's.
    private var isShowingLedgerInView: Bool {
        let state: LedgerUiState = self.ledgerStore.state
        return state.isLoaded && (state.ledgerId ?? "") == self.store.selectedLedgerId
    }

    private var calendar: CalendarMonth? {
        self.ledgerStore.state.calendarMonth(
            todayIso: self.store.todayIso,
            ledgerCreatedOnIso: self.store.selectedLedgerCreatedOnIso,
        )
    }

    private var legend: some View {
        HStack(spacing: Theme.Spacing.extraSmall) {
            NmdBadge(size: Theme.Reports.legendBadgeSize)
            Text("NMD = お金を使わなかった日")
                .font(.caption2)
                .foregroundStyle(Theme.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, Theme.Spacing.small)
        .accessibilityElement(children: .combine)
    }

    internal var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            if let message = self.ledgerStore.state.loadErrorMessage {
                Text(message)
                    .foregroundStyle(Theme.mutedText)
            }
            if self.isShowingLedgerInView, let calendar = self.calendar {
                self.calendarCard(calendar)
                self.chosenDay(calendar)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(Theme.Spacing.large)
        .tabRootLifecycleHook(screenID: "calendar", creationCount: self.lifecycle.creationCount)
    }

    // The days of `calendar` in weeks of seven cells, `nil` for a cell
    // before its first day or after its last.
    private static func weeks(of calendar: CalendarMonth) -> [[CalendarDay?]] {
        let blanks: [CalendarDay?] = Array(repeating: nil, count: Int(calendar.leadingBlankDays))
        let cells: [CalendarDay?] = blanks + calendar.days.map { Optional($0) }
        return stride(from: 0, to: cells.count, by: Self.daysInWeek).map { start in
            let end: Int = min(start + Self.daysInWeek, cells.count)
            let week: [CalendarDay?] = Array(cells[start..<end])
            return week + Array(repeating: nil, count: Self.daysInWeek - week.count)
        }
    }

    // The chosen day of `calendar`: the one chosen, else today, when in it.
    private func chosenDate(in calendar: CalendarMonth) -> String? {
        let dates: Set<String> = Set(calendar.days.map(\.date))
        if let chosen = self.chosenDate, dates.contains(chosen) {
            return chosen
        }
        return dates.contains(self.store.todayIso) ? self.store.todayIso : nil
    }

    private func calendarCard(_ calendar: CalendarMonth) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            HStack(alignment: .firstTextBaseline) {
                Text(calendar.title)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("支出 \(calendar.expenseText)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.mutedText)
            }
            .padding(.horizontal, Theme.Spacing.small)
            self.grid(calendar)
            self.legend
        }
        .padding(Theme.Spacing.small)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius)
                .strokeBorder(Theme.line)
        }
    }

    private func grid(_ calendar: CalendarMonth) -> some View {
        let chosen: String? = self.chosenDate(in: calendar)
        let weeks: [[CalendarDay?]] = Self.weeks(of: calendar)
        return Grid(horizontalSpacing: 0, verticalSpacing: Theme.Spacing.extraSmall) {
            GridRow {
                ForEach(Array(calendar.weekdayNames.enumerated()), id: \.offset) { index, name in
                    Text(name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(self.weekdayColor(index))
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
            }
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                GridRow {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        if let day {
                            CalendarDayCell(day: day, isChosen: day.date == chosen) {
                                self.chosenDate = day.date
                            }
                        } else {
                            Rectangle()
                                .hidden()
                                .frame(maxWidth: .infinity)
                                .gridCellUnsizedAxes(.vertical)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chosenDay(_ calendar: CalendarMonth) -> some View {
        if let date = self.chosenDate(in: calendar) {
            let section: DaySection? = self.ledgerStore.daySections.first { $0.date == date }
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                HStack {
                    Text(IsoFormats.shared.date(iso: date, withWeekday: true))
                    Spacer()
                    if let total = section?.totalText {
                        Text(total)
                            .monospacedDigit()
                    }
                }
                .font(.footnote)
                .foregroundStyle(Theme.mutedText)
                .padding(.horizontal, Theme.Spacing.extraSmall)
                if let section, !section.rows.isEmpty {
                    self.rows(section.rows)
                } else {
                    Text("この日の記録はありません")
                        .font(.subheadline)
                        .foregroundStyle(Theme.mutedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.large)
                }
            }
        } else {
            Text("日を選ぶと、その日の記録が並びます")
                .font(.subheadline)
                .foregroundStyle(Theme.mutedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.large)
        }
    }

    private func rows(_ rows: [TransactionRow]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Divider()
                        .overlay(Theme.line)
                }
                self.row(row)
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius)
                .strokeBorder(Theme.line)
        }
    }

    private func row(_ row: TransactionRow) -> some View {
        Button {
            if let transaction = self.ledgerStore.transaction(id: row.id) {
                self.router.entrySheet = .edit(transaction)
            }
        } label: {
            TransactionRowView(row: row)
                .padding(.horizontal, Theme.Spacing.medium)
                .padding(.vertical, Theme.Spacing.small)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("transaction-row-\(row.date)-\(row.id)")
    }

    private func weekdayColor(_ column: Int) -> Color {
        if column == 0 {
            return Theme.Reports.sunday
        }
        return column == Self.daysInWeek - 1 ? Theme.Reports.saturday : Theme.text
    }
}

#Preview {
    ScrollView {
        CalendarTabContent()
    }
}
