import SharedLogic
import SwiftUI
import UIKit

/// The card of a draft's 店名, 日付 and 合計 (`Draft5.dc.html`).
///
/// Each is editable and marked 要確認 while the scanner was not sure of it
/// and the user has not changed it.
internal struct DraftFieldsCard: View {
    internal let form: Binding<DraftFormState>

    @State private var isDatePickerShown: Bool = false

    internal var body: some View {
        let current: DraftFormState = self.form.wrappedValue
        return VStack(spacing: 0) {
            self.row(name: "店名", field: "store", confidence: current.storeConfidence) {
                self.storeField
            }
            Divider()
            self.row(name: "日付", field: "date", confidence: current.dateConfidence) {
                self.dateField
            }
            if self.isDatePickerShown {
                self.datePicker
            }
            Divider()
            self.row(name: "合計", field: "total", confidence: current.totalConfidence) {
                self.totalField
            }
        }
        .padding(.horizontal, Theme.Spacing.large)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Scanning.cardRadius))
    }

    private var storeField: some View {
        TextField("店名", text: self.certain(\.store, confidence: \.storeConfidence))
            .foregroundStyle(Theme.text)
            .accessibilityLabel("店名")
            .accessibilityIdentifier("draft-store")
    }

    // The date, `2026年2月14日`; chosen, it opens a calendar below its row.
    private var dateField: some View {
        Button {
            self.isDatePickerShown.toggle()
        } label: {
            HStack(spacing: Theme.Spacing.small) {
                Text(IsoDate.longText(from: self.form.wrappedValue.date))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: self.isDatePickerShown ? "chevron.up" : "chevron.down")
                    .foregroundStyle(Theme.mutedText)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Theme.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("日付 \(IsoDate.longText(from: self.form.wrappedValue.date))")
        .accessibilityHint("カレンダーで日付を変えます")
        .accessibilityIdentifier("draft-date")
    }

    private var datePicker: some View {
        DatePicker(
            "日付",
            selection: self.certain(\.date, confidence: \.dateConfidence),
            displayedComponents: .date,
        )
        .datePickerStyle(.graphical)
        .tint(Theme.accent)
        .labelsHidden()
    }

    private var totalField: some View {
        HStack(spacing: Theme.Spacing.extraSmall) {
            AmountTextField(
                placeholder: "0",
                text: self.certain(\.totalText, confidence: \.totalConfidence),
                identifier: "draft-total",
                label: "合計",
                font: UIFont.preferredFont(forTextStyle: .body),
                color: UIColor(Theme.text),
                alignment: .left,
            )
            Text("円")
                .foregroundStyle(Theme.text)
        }
    }

    private func row(
        name: String,
        field: String,
        confidence: Double,
        @ViewBuilder value: () -> some View,
    ) -> some View {
        HStack(spacing: Theme.Spacing.medium) {
            Text(name)
                .font(.subheadline)
                .foregroundStyle(Theme.mutedText)
                .frame(minWidth: Theme.Scanning.fieldNameWidth, alignment: .leading)
                .accessibilityHidden(true)
            value()
            if needsReview(confidence: confidence) {
                ReviewMark(field: field)
            }
        }
        .frame(minHeight: Theme.minimumTapTarget)
    }

    // A binding to the form's `path` that makes it certain once changed.
    private func certain<Value: Equatable>(
        _ path: WritableKeyPath<DraftFormState, Value>,
        confidence: WritableKeyPath<DraftFormState, Double>,
    ) -> Binding<Value> {
        Binding(
            get: { self.form.wrappedValue[keyPath: path] },
            set: { value in
                guard value != self.form.wrappedValue[keyPath: path] else {
                    return
                }
                self.form.wrappedValue[keyPath: path] = value
                self.form.wrappedValue[keyPath: confidence] = Theme.Scanning.certain
            },
        )
    }
}
