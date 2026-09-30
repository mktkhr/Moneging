import SharedLogic
import SwiftUI

/// Asks before closing the month offered (`MonthClose4.dc.html`): each
/// budget's leftover (a negative one does not move), the carry-over policy
/// (`budget-close-policy`: 繰り越す / 貯金にする, kept for the ledger only
/// when the month is closed) with what the chosen one does, then `<月>を締める`
/// (`budget-close-confirm`); × keeps the month open.
///
/// A sheet sized to its content, as `DeleteRecurringRuleSheet`.
internal struct MonthCloseSheet: View {
    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    @Environment(\.dismiss)
    private var dismiss: DismissAction

    /// The month closed, as it was when the sheet opened: closing it takes
    /// it out of the ledger's state before the sheet has gone.
    @State private var shown: CloseSheet?
    @State private var policy: CarryOverPolicy = .carry
    @State private var isClosing: Bool = false

    internal var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            self.header
            if let sheet = self.shown {
                self.content(sheet)
            }
        }
        .padding(Theme.Spacing.extraLarge)
        .background(Theme.background)
        .fittedSheet(maxHeight: nil)
        .ledgerFailureAlert()
        .onAppear(perform: self.load)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.small) {
            Button("キャンセル", systemImage: "xmark", role: .close) {
                self.dismiss()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .tint(Theme.text)
            .frame(minWidth: Theme.minimumTapTarget, minHeight: Theme.minimumTapTarget)
            .accessibilityIdentifier("budget-close-cancel")
            Text(self.shown?.title ?? "")
                .font(.headline)
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            // Balances × so the title stays centred.
            Spacer()
                .frame(width: Theme.minimumTapTarget, height: Theme.minimumTapTarget)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func content(_ sheet: CloseSheet) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraExtraSmall) {
            Text(sheet.intro)
                .font(.subheadline)
                .foregroundStyle(Theme.text)
            Text("締めた月の予算は変えられなくなります。")
                .font(.footnote)
                .foregroundStyle(Theme.mutedText)
        }
        self.lines(sheet.lines)
        self.policySection(sheet)
        Button(action: self.close) {
            Text(sheet.title)
                .font(.body.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: Theme.Budgets.confirmHeight)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(Theme.accent)
        .disabled(self.isClosing)
        .accessibilityIdentifier("budget-close-confirm")
    }

    private func lines(_ lines: [CloseLine]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.element.title) { index, line in
                if index > 0 {
                    Divider()
                        .overlay(Theme.line)
                        .padding(.leading, Theme.Spacing.medium)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(line.title)
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text(line.amountText)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(line.isMoving ? Theme.text : Theme.mutedText)
                        .multilineTextAlignment(.trailing)
                }
                .font(.subheadline)
                .padding(Theme.Spacing.medium)
                .accessibilityElement(children: .combine)
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius)
                .strokeBorder(Theme.line)
        }
    }

    private func policySection(_ sheet: CloseSheet) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text("残りの扱い（この家計簿で共通）")
                .font(.footnote)
                .foregroundStyle(Theme.mutedText)
            Picker("残りの扱い", selection: self.$policy) {
                Text("繰り越す").tag(CarryOverPolicy.carry)
                Text("貯金にする").tag(CarryOverPolicy.save)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("budget-close-policy")
            Text(self.policy == .carry ? sheet.carryNote : sheet.saveNote)
                .font(.caption)
                .foregroundStyle(Theme.mutedText)
        }
    }

    private func load() {
        guard self.shown == nil else {
            return
        }
        self.shown = self.ledgerStore.state.closeSheet(todayIso: self.store.todayIso)
        self.policy = self.ledgerStore.state.carryOverPolicy
    }

    private func close() {
        guard let month = self.shown?.month else {
            return
        }
        self.isClosing = true
        let chosen: CarryOverPolicy = self.policy
        Task {
            let isClosed: Bool = await self.ledgerStore.closeMonth(month, policy: chosen)
            self.isClosing = false
            if isClosed {
                self.dismiss()
            }
        }
    }
}
