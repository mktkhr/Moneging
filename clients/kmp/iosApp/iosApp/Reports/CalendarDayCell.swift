import SharedLogic
import SwiftUI

/// One day of the calendar (`Calendar3.dc.html`).
///
/// Its number, then its spending in full (`4,000`) or the NMD badge.
/// Sundays are red, Saturdays blue, future days muted; today is outlined
/// and the chosen day tinted.
///
/// One accessibility element, `calendar-day-<yyyy-MM-dd>`, labelled
/// `2月3日 4,000円`, `2月4日 NMD` or the date alone.
internal struct CalendarDayCell: View {
    internal let day: CalendarDay
    internal let isChosen: Bool
    internal let choose: () -> Void

    @ScaledMetric(relativeTo: .body)
    private var height: CGFloat = Theme.Reports.dayCellHeight

    private var numberColor: Color {
        if self.day.isToday {
            return Theme.accent
        }
        if self.day.isFuture {
            return Theme.Reports.futureDay
        }
        if self.day.isSunday {
            return Theme.Reports.sunday
        }
        if self.day.isSaturday {
            return Theme.Reports.saturday
        }
        return Theme.text
    }

    internal var body: some View {
        Button(action: self.choose) {
            VStack(spacing: Theme.Spacing.extraExtraSmall) {
                Text(self.day.dayNumber)
                    .font(.subheadline.weight(self.day.isToday || self.isChosen ? .bold : .medium))
                    .foregroundStyle(self.numberColor)
                if let amount = self.day.amountText {
                    Text(amount)
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(Theme.Reports.dayAmountMinimumScale)
                } else if self.day.isNoMoneyDay {
                    NmdBadge(size: Theme.Reports.badgeSize)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, Theme.Spacing.extraSmall)
            .frame(maxWidth: .infinity, minHeight: self.height, maxHeight: self.height)
            .background(
                self.isChosen ? Theme.accentTint : Theme.surface,
                in: RoundedRectangle(cornerRadius: Theme.Reports.dayCellRadius),
            )
            .overlay {
                if self.day.isToday {
                    RoundedRectangle(cornerRadius: Theme.Reports.dayCellRadius)
                        .strokeBorder(Theme.accent, lineWidth: Theme.Reports.todayBorderWidth)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.day.accessibilityLabel)
        .accessibilityAddTraits(self.isChosen ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("calendar-day-\(self.day.date)")
    }
}
