import SharedLogic
import SwiftUI

/// The 日付 row of the entry sheet: the date (`2月15日（今日）`), which,
/// tapped, opens a calendar to change it.
///
/// Identified `entry-date`; its label holds the date.
internal struct EntryDateRow: View {
    internal let date: Binding<Date>
    /// Today, ISO, to mark it 今日.
    internal let todayIso: String

    @State private var isPickerShown: Bool = false

    private var dateText: String {
        let iso: String = IsoDate.iso(from: self.date.wrappedValue)
        let text: String = IsoFormats.shared.date(iso: iso, withWeekday: true)
        return iso == self.todayIso ? "\(text)（今日）" : text
    }

    internal var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Button {
                self.isPickerShown.toggle()
            } label: {
                HStack(spacing: Theme.Spacing.medium) {
                    Text("日付")
                        .foregroundStyle(Theme.mutedText)
                    Text(self.dateText)
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: self.isPickerShown ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Theme.mutedText)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: Theme.minimumTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("日付 \(self.dateText)")
            .accessibilityHint("カレンダーで日付を変えます")
            .accessibilityIdentifier("entry-date")
            if self.isPickerShown {
                DatePicker("日付", selection: self.date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Theme.accent)
                    .environment(\.calendar, IsoDate.calendar)
                    .environment(\.timeZone, IsoDate.timeZone)
                    .labelsHidden()
            }
        }
    }
}
