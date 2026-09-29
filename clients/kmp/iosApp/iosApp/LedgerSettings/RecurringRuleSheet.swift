import SharedLogic
import SwiftUI
import UIKit

/// The rule sheet adding a monthly recurring rule (`RecurringEdit2.dc.html`).
///
/// 支出 / 収入, the amount, the day (1-31 or 月末) and what happens on a
/// weekend or holiday, the category (an expense's), the memo, and the start
/// and optional end month. Saving records the months whose date has come.
/// The amount and the day sit at the top, so both stay in view while the
/// number pad is up.
internal struct RecurringRuleSheet: View {
    private static let monthsBefore: Int32 = 12
    private static let monthsAfter: Int32 = 24

    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    @Environment(\.dismiss)
    private var dismiss: DismissAction

    @State private var isIncome: Bool = false
    @State private var amountText: String = ""
    @State private var dayText: String = ""
    @State private var isMonthEnd: Bool = false
    @State private var adjustment: BusinessDayAdjustment = .keep
    @State private var categoryId: String?
    @State private var memo: String = ""
    @State private var startMonth: String = ""
    @State private var endMonth: String?
    @State private var isSaving: Bool = false

    @ScaledMetric(relativeTo: .largeTitle)
    private var amountSize: CGFloat = Theme.Recording.amountFontSize

    private var isDayValid: Bool {
        guard let day = Int(self.dayText) else {
            return false
        }
        return (Theme.Recording.firstDay...Theme.Recording.lastDay).contains(day)
    }

    private var canSave: Bool {
        (Int64(self.amountText) ?? 0) > 0
            && (self.isMonthEnd || self.isDayValid)
            && (self.isIncome || self.categoryId != nil)
    }

    private var months: [String] {
        IsoFormats.shared.monthsAround(
            center: self.store.todayMonthIso,
            before: Self.monthsBefore,
            after: Self.monthsAfter,
        )
    }

    internal var body: some View {
        NavigationStack {
            ScrollView {
                self.content
                    .padding(.horizontal, Theme.Spacing.large)
                    .padding(.bottom, Theme.Spacing.extraLarge)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle("定期を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                self.toolbar
            }
        }
        .tint(Theme.accent)
        .presentationDetents([.large])
        .ledgerFailureAlert()
        .onAppear {
            if self.startMonth.isEmpty {
                self.startMonth = self.store.todayMonthIso
            }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("閉じる", systemImage: "xmark", role: .close) {
                self.dismiss()
            }
            .tint(Theme.text)
            .accessibilityIdentifier("recurring-cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("保存", systemImage: "checkmark", role: .confirm, action: self.save)
                .disabled(!self.canSave || self.isSaving)
                .accessibilityIdentifier("recurring-save")
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            Picker("支出か収入か", selection: self.$isIncome) {
                Text("支出").tag(false)
                Text("収入").tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("recurring-direction")
            self.amountRow
            RecurringDayCard(
                dayText: self.$dayText,
                isMonthEnd: self.$isMonthEnd,
                adjustment: self.$adjustment,
            )
            self.categorySection
            RecurringPeriodCard(
                memo: self.$memo,
                startMonth: Binding(
                    get: { self.startMonth.isEmpty ? self.store.todayMonthIso : self.startMonth },
                    set: { month in self.startMonth = month },
                ),
                endMonth: self.$endMonth,
                months: self.months,
            )
        }
    }

    @ViewBuilder private var categorySection: some View {
        if self.isIncome {
            Text("収入には分類を付けません")
                .font(.footnote)
                .foregroundStyle(Theme.mutedText)
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text("分類")
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedText)
                    .accessibilityAddTraits(.isHeader)
                CategoryTileGrid(
                    categories: self.ledgerStore.state.activeCategories,
                    selection: self.$categoryId,
                )
            }
        }
    }

    private var amountRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.extraSmall) {
            Text("金額")
                .font(.footnote)
                .foregroundStyle(Theme.mutedText)
                .accessibilityHidden(true)
            AmountTextField(
                placeholder: "0",
                text: self.$amountText,
                identifier: "recurring-amount",
                label: "金額",
                font: UIFont.systemFont(ofSize: self.amountSize, weight: .bold),
                color: UIColor(self.isIncome ? Theme.income : Theme.text),
            )
            .fixedSize(horizontal: false, vertical: true)
            Text("円")
                .font(.title2.weight(.bold))
                .foregroundStyle(self.isIncome ? Theme.income : Theme.text)
                .accessibilityHidden(true)
        }
    }

    private func save() {
        self.isSaving = true
        let draft: RecurringRuleDraft = RecurringRuleDraft(
            isIncome: self.isIncome,
            amountText: self.amountText,
            categoryId: self.isIncome ? nil : self.categoryId,
            dayText: self.isMonthEnd ? nil : self.dayText,
            adjustment: self.adjustment,
            startMonth: self.startMonth.isEmpty ? self.store.todayMonthIso : self.startMonth,
            endMonth: self.endMonth,
            memo: self.memo,
        )
        Task {
            let isSaved: Bool = await self.ledgerStore.createRecurringRule(draft)
            self.isSaving = false
            if isSaved {
                self.dismiss()
            }
        }
    }
}
