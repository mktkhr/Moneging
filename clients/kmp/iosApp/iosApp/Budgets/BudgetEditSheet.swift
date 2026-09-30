import SharedLogic
import SwiftUI
import UIKit

/// The budget sheet (`BudgetEdit4.dc.html`): the whole month's or a
/// category's budget, or a new one for a category chosen from the tiles
/// (`category-tile-<category id>`).
///
/// The amount (`budget-amount`, a number pad) and from which month it
/// holds (いつから, the month in view until changed); ✓ (`budget-save`)
/// sets it from that month on. A budget set for the month in view can
/// instead be removed from that month on (`<月>から予算をなくす`).
internal struct BudgetEditSheet: View {
    private static let monthsBefore: Int32 = 12
    private static let monthsAfter: Int32 = 24

    internal let request: BudgetSheetRequest
    /// The month in view, ISO (`2026-02`).
    internal let monthIso: String

    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    @Environment(\.dismiss)
    private var dismiss: DismissAction

    @State private var amountText: String = ""
    @State private var fromMonth: String = ""
    @State private var chosenCategoryId: String?
    @State private var isSaving: Bool = false
    @State private var isLoaded: Bool = false

    @ScaledMetric(relativeTo: .largeTitle)
    private var amountSize: CGFloat = Theme.Budgets.amountFontSize

    private var isAdding: Bool {
        self.request == .add
    }

    private var categoryId: String? {
        self.isAdding ? self.chosenCategoryId : self.request.categoryId
    }

    private var sheet: BudgetSheet {
        self.ledgerStore.state.budgetSheet(categoryId: self.request.categoryId)
    }

    private var chosenMonth: String {
        self.fromMonth.isEmpty ? self.monthIso : self.fromMonth
    }

    private var canSave: Bool {
        (Int64(self.amountText) ?? 0) > 0 && (!self.isAdding || self.chosenCategoryId != nil)
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
            .navigationTitle(self.isAdding ? String(localized: "予算を追加") : self.sheet.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                self.toolbar
            }
        }
        .tint(Theme.accent)
        .presentationDetents([.large])
        .ledgerFailureAlert()
        .onAppear(perform: self.load)
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("閉じる", systemImage: "xmark", role: .close) {
                self.dismiss()
            }
            .tint(Theme.text)
            .accessibilityIdentifier("budget-cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("保存", systemImage: "checkmark", role: .confirm, action: self.save)
                .disabled(!self.canSave || self.isSaving)
                .accessibilityIdentifier("budget-save")
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            if let name = self.sheet.categoryName, !self.isAdding {
                self.categoryCard(name: name)
            }
            self.amountRow
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                self.monthRow
                Text("この月から毎月同じ額が続きます。締めた月の予算は変えられません。")
                    .font(.caption)
                    .foregroundStyle(Theme.mutedText)
                    .padding(.horizontal, Theme.Spacing.extraSmall)
            }
            if self.isAdding {
                self.categorySection
            } else if self.sheet.hasBudget {
                self.removeSection
            }
        }
        .padding(.top, Theme.Spacing.large)
    }

    private var amountRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraExtraSmall) {
            Text("毎月の予算")
                .font(.caption)
                .foregroundStyle(Theme.mutedText)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.extraSmall) {
                AmountTextField(
                    placeholder: "0",
                    text: self.$amountText,
                    identifier: "budget-amount",
                    label: String(localized: "毎月の予算"),
                    font: UIFont.systemFont(ofSize: self.amountSize, weight: .bold),
                    color: UIColor(Theme.text),
                )
                .fixedSize(horizontal: false, vertical: true)
                Text("円")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.text)
                    .accessibilityHidden(true)
            }
        }
    }

    private var monthRow: some View {
        let months: [String] = IsoFormats.shared.monthsAround(
            center: self.monthIso,
            before: Self.monthsBefore,
            after: Self.monthsAfter,
        )
        let value: String = BudgetTexts.shared.fromMonth(fromMonthIso: self.chosenMonth)
        return Menu {
            ForEach(months, id: \.self) { month in
                Button(IsoFormats.shared.month(iso: month)) {
                    self.fromMonth = month
                }
            }
        } label: {
            HStack(spacing: Theme.Spacing.medium) {
                Text("いつから")
                    .foregroundStyle(Theme.mutedText)
                Text(value)
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(Theme.mutedText)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Theme.minimumTapTarget)
            .padding(.horizontal, Theme.Spacing.large)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
            .contentShape(Rectangle())
        }
        .accessibilityLabel("いつから \(value)")
        .accessibilityIdentifier("budget-from-month")
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text("分類")
                .font(.footnote)
                .foregroundStyle(Theme.mutedText)
                .accessibilityAddTraits(.isHeader)
            CategoryTileGrid(
                categories: self.ledgerStore.state.activeCategories,
                selection: self.$chosenCategoryId,
            )
        }
    }

    private var removeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Button(role: .destructive, action: self.remove) {
                Text(
                    BudgetTexts.shared.removeTitle(
                        fromMonthIso: self.chosenMonth,
                        todayIso: self.store.todayIso,
                    )
                )
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.Recording.destructive)
                .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(self.isSaving)
            .accessibilityIdentifier("budget-remove")
            Text("前の月の予算はそのまま残ります。")
                .font(.caption)
                .foregroundStyle(Theme.mutedText)
                .padding(.horizontal, Theme.Spacing.extraSmall)
        }
    }

    private func categoryCard(name: String) -> some View {
        HStack(spacing: Theme.Spacing.medium) {
            CategoryIcon(defaultIndex: self.sheet.iconIndex.map { Int(truncating: $0) })
            Text(name)
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.text)
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.medium)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
        .accessibilityElement(children: .combine)
    }

    // Fills the amount set for the month in view, once.
    private func load() {
        guard !self.isLoaded else {
            return
        }
        self.isLoaded = true
        self.amountText = self.isAdding ? "" : self.sheet.amountText
        self.fromMonth = self.monthIso
    }

    private func save() {
        self.isSaving = true
        let budgetCategoryId: String? = self.categoryId
        let typed: String = self.amountText
        let month: String = self.chosenMonth
        Task {
            let isSaved: Bool = await self.ledgerStore.setBudget(
                categoryId: budgetCategoryId,
                amountText: typed,
                fromMonth: month,
            )
            self.isSaving = false
            if isSaved {
                self.dismiss()
            }
        }
    }

    private func remove() {
        self.isSaving = true
        let budgetCategoryId: String? = self.categoryId
        let month: String = self.chosenMonth
        Task {
            let isRemoved: Bool = await self.ledgerStore.removeBudget(
                categoryId: budgetCategoryId,
                fromMonth: month,
            )
            self.isSaving = false
            if isRemoved {
                self.dismiss()
            }
        }
    }
}
