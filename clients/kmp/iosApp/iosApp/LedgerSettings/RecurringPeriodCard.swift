import SharedLogic
import SwiftUI

/// The rule sheet's memo and period: the start month
/// (`recurring-start-month`, the month of today until changed) and the
/// optional end month (`recurring-end-month`, なし until changed).
internal struct RecurringPeriodCard: View {
    internal let memo: Binding<String>
    /// The start month, ISO (`2026-02`).
    internal let startMonth: Binding<String>
    /// The end month, ISO, or `nil` for none.
    internal let endMonth: Binding<String?>
    /// The months offered, ISO.
    internal let months: [String]

    internal var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.medium) {
                Text("メモ")
                    .foregroundStyle(Theme.mutedText)
                    .accessibilityHidden(true)
                TextField("例: 家賃", text: self.memo)
                    .foregroundStyle(Theme.text)
                    .submitLabel(.done)
                    .accessibilityLabel("メモ")
                    .accessibilityIdentifier("recurring-memo")
            }
            .frame(minHeight: Theme.minimumTapTarget)
            Divider()
            self.startRow
            Divider()
            self.endRow
        }
        .padding(.horizontal, Theme.Spacing.large)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
    }

    private var startRow: some View {
        self.monthRow(
            name: String(localized: "開始"),
            value: IsoFormats.shared.month(iso: self.startMonth.wrappedValue),
            identifier: "recurring-start-month",
        ) {
            ForEach(self.months, id: \.self) { month in
                Button(IsoFormats.shared.month(iso: month)) {
                    self.startMonth.wrappedValue = month
                }
            }
        }
    }

    private var endRow: some View {
        let value: String =
            self.endMonth.wrappedValue.map { IsoFormats.shared.month(iso: $0) }
            ?? String(localized: "なし")
        return self.monthRow(
            name: String(localized: "終了"),
            value: value,
            identifier: "recurring-end-month",
        ) {
            Button("なし") {
                self.endMonth.wrappedValue = nil
            }
            ForEach(self.months, id: \.self) { month in
                Button(IsoFormats.shared.month(iso: month)) {
                    self.endMonth.wrappedValue = month
                }
            }
        }
    }

    private func monthRow<Choices: View>(
        name: String,
        value: String,
        identifier: String,
        @ViewBuilder choices: () -> Choices,
    ) -> some View {
        Menu {
            choices()
        } label: {
            HStack(spacing: Theme.Spacing.medium) {
                Text(name)
                    .foregroundStyle(Theme.mutedText)
                Text(value)
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(Theme.mutedText)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Theme.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("\(name) \(value)")
        .accessibilityIdentifier(identifier)
    }
}
