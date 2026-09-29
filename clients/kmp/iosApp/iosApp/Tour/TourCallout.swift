import SharedLogic
import SwiftUI

/// One tour step's callout: its heading and explanation, the first
/// ledger's name on the ledger step, the page dots and the step's buttons
/// (はじめる on the ledger step, which cannot be skipped; スキップ and 次へ on
/// every later one).
///
/// Its root carries `tour-step-<step>`, and its controls `tour-ledger-name`,
/// `tour-start`, `tour-skip` and `tour-next`.
internal struct TourCallout: View {
    internal let tour: TourState
    /// The edge the arrow sits on, toward the spotlight; `nil` for none.
    internal let arrowEdge: VerticalEdge?
    /// The arrow's centre, from the callout's leading edge.
    internal let arrowX: CGFloat?
    /// The most height the callout may take; beyond it, its content scrolls.
    internal let maxHeight: CGFloat

    // The content's own height, measured, so the callout hugs it.
    @State private var contentHeight: CGFloat = 0
    // Where the content is scrolled to; back at the top on every step.
    @State private var scrollPosition: ScrollPosition = ScrollPosition(edge: .top)

    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    internal var body: some View {
        ScrollView {
            self.content
                .padding(Theme.Tour.calloutPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    self.contentHeight = height
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollPosition(self.$scrollPosition)
        .onChange(of: self.tour.step) {
            self.scrollPosition.scrollTo(edge: .top)
        }
        .frame(height: min(self.contentHeight, self.maxHeight))
        .background(alignment: self.arrowEdge == .bottom ? .bottomLeading : .topLeading) {
            ZStack(alignment: self.arrowEdge == .bottom ? .bottomLeading : .topLeading) {
                RoundedRectangle(cornerRadius: Theme.Tour.calloutRadius)
                    .fill(Theme.Tour.calloutSurface)
                self.arrow
            }
            .shadow(
                color: Theme.Tour.calloutShadow,
                radius: Theme.Tour.calloutShadowRadius,
                y: Theme.Tour.calloutShadowY,
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tour-step-\(self.tour.step.identifier)")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text(self.tour.step.title)
                .font(.title3.bold())
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
            Text(self.tour.step.message)
                .font(.subheadline)
                .foregroundStyle(Theme.mutedText)
            if self.tour.step == .ledger {
                self.nameField
            }
            self.controls
        }
    }

    // The page dots and the buttons in one row when they fit on one line
    // each; otherwise stacked, the buttons full width with the primary one
    // on top, so no button's title ever breaks mid-word.
    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.small) {
                self.pageDots
                Spacer(minLength: Theme.Spacing.small)
                self.buttons(isStacked: false)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                self.pageDots
                self.buttons(isStacked: true)
            }
        }
    }

    private var isNameValid: Bool {
        SharedStateStore.isValidLedgerName(self.store.ledgerNameDraft)
    }

    @ViewBuilder private var arrow: some View {
        if let arrowEdge = self.arrowEdge, let arrowX = self.arrowX {
            GeometryReader { proxy in
                let clamped: CGFloat = min(
                    max(arrowX, Theme.Tour.arrowInset),
                    proxy.size.width - Theme.Tour.arrowInset,
                )
                RoundedRectangle(cornerRadius: Theme.Tour.arrowRadius)
                    .fill(Theme.Tour.calloutSurface)
                    .frame(width: Theme.Tour.arrowSize, height: Theme.Tour.arrowSize)
                    .rotationEffect(.degrees(Theme.Tour.arrowRotationDegrees))
                    .position(
                        x: clamped,
                        y: arrowEdge == .top ? 0 : proxy.size.height,
                    )
            }
            .accessibilityHidden(true)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
            Text("家計簿の名前")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.mutedText)
                .accessibilityHidden(true)
            NameTextField(
                placeholder: String(localized: "家計簿の名前"),
                text: Binding(
                    get: { self.store.ledgerNameDraft },
                    set: { self.store.changeLedgerNameDraft($0) },
                ),
                identifier: "tour-ledger-name",
                onSubmit: self.start,
            )
            .padding(.horizontal, Theme.Spacing.medium)
            .frame(minHeight: Theme.minimumTapTarget)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Tour.fieldRadius)
                    .strokeBorder(Theme.accent, lineWidth: Theme.Tour.fieldBorderWidth)
            }
        }
    }

    private var pageDots: some View {
        HStack(spacing: Theme.Tour.dotSpacing) {
            ForEach(0..<Int(self.tour.count), id: \.self) { index in
                let isCurrent: Bool = index == Int(self.tour.position)
                Capsule()
                    .fill(isCurrent ? Theme.accent : Theme.Tour.inactiveDot)
                    .frame(
                        width: isCurrent ? Theme.Tour.activeDotWidth : Theme.Tour.dotSize,
                        height: Theme.Tour.dotSize,
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(self.tour.position) + 1) / \(Int(self.tour.count))")
    }

    @ViewBuilder
    private func buttons(isStacked: Bool) -> some View {
        if self.tour.step == .ledger {
            Button("はじめる", action: self.start)
                .buttonStyle(TourPrimaryButtonStyle(isFullWidth: isStacked))
                .disabled(!self.isNameValid)
                .accessibilityIdentifier("tour-start")
        } else if isStacked {
            VStack(spacing: Theme.Spacing.extraSmall) {
                self.nextButton(isFullWidth: true)
                self.skipButton(isFullWidth: true)
            }
        } else {
            HStack(spacing: Theme.Spacing.extraSmall) {
                self.skipButton(isFullWidth: false)
                self.nextButton(isFullWidth: false)
            }
        }
    }

    private func skipButton(isFullWidth: Bool) -> some View {
        Button {
            self.store.skipTour()
        } label: {
            Text("スキップ")
                .font(.subheadline)
                .foregroundStyle(Theme.mutedText)
                .padding(.horizontal, Theme.Spacing.small)
                .frame(maxWidth: isFullWidth ? .infinity : nil, minHeight: Theme.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("tour-skip")
    }

    private func nextButton(isFullWidth: Bool) -> some View {
        Button("次へ") {
            self.store.advanceTour()
        }
        .buttonStyle(TourPrimaryButtonStyle(isFullWidth: isFullWidth))
        .accessibilityIdentifier("tour-next")
    }

    private func start() {
        guard self.isNameValid else {
            return
        }
        Task {
            await self.store.createFirstLedger()
        }
    }
}
