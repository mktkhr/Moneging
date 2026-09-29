import SharedLogic
import SwiftUI
import UIKit

/// The rule sheet's day: 毎月 N 日 (`recurring-day`) or 月末
/// (`recurring-month-end`), and what happens on a weekend or holiday
/// (`recurring-adjustment`: そのまま / 翌平日 / 前の平日).
internal struct RecurringDayCard: View {
    internal let dayText: Binding<String>
    internal let isMonthEnd: Binding<Bool>
    internal let adjustment: Binding<BusinessDayAdjustment>

    internal var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            self.dayRow
            Text("1日〜31日または月末。その月に無い日は末日になります。")
                .font(.caption)
                .foregroundStyle(Theme.mutedText)
            Text("土日祝のとき")
                .font(.footnote)
                .foregroundStyle(Theme.mutedText)
            Picker("土日祝のとき", selection: self.adjustment) {
                Text("そのまま").tag(BusinessDayAdjustment.keep)
                Text("翌平日").tag(BusinessDayAdjustment.nextBusinessDay)
                Text("前の平日").tag(BusinessDayAdjustment.previousBusinessDay)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("recurring-adjustment")
        }
        .padding(Theme.Spacing.large)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
    }

    private var dayRow: some View {
        HStack(spacing: Theme.Spacing.small) {
            Text("毎月")
                .foregroundStyle(Theme.mutedText)
            if self.isMonthEnd.wrappedValue {
                Text("末日")
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                AmountTextField(
                    placeholder: "25",
                    text: self.dayText,
                    identifier: "recurring-day",
                    label: "日",
                    font: UIFont.preferredFont(forTextStyle: .body),
                    color: UIColor(Theme.text),
                    alignment: .left,
                )
                .fixedSize(horizontal: false, vertical: true)
                Text("日")
                    .foregroundStyle(Theme.text)
                    .accessibilityHidden(true)
            }
            Button(self.isMonthEnd.wrappedValue ? "日を選ぶ" : "月末") {
                self.isMonthEnd.wrappedValue.toggle()
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .accessibilityIdentifier("recurring-month-end")
        }
        .frame(minHeight: Theme.minimumTapTarget)
    }
}
