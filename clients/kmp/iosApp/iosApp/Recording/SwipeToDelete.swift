import SwiftUI

/// 削除 behind a row of a scroll view, revealed by swiping the row left.
///
/// A `List` has its own swipe actions; this is for rows outside one.
/// Swiping back or pressing the row hides it again. VoiceOver offers it as
/// the row's action 削除.
internal struct SwipeToDelete: ViewModifier {
    /// Whether the row can be removed at all.
    internal let isEnabled: Bool
    internal let onDelete: () -> Void
    /// Whether 削除 is shown, so pressing the row hides it instead of
    /// opening the row.
    internal let isOpen: Binding<Bool>

    @ScaledMetric(relativeTo: .body)
    private var actionWidth: CGFloat = Theme.Recording.swipeActionWidth

    @State private var dragOffset: CGFloat = 0

    private var restingOffset: CGFloat {
        self.isOpen.wrappedValue ? -self.actionWidth : 0
    }

    private var offset: CGFloat {
        min(0, max(-self.actionWidth, self.restingOffset + self.dragOffset))
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            self.isOpen.wrappedValue = false
            self.onDelete()
        } label: {
            Text("削除")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: self.actionWidth)
                .frame(maxHeight: .infinity)
                .background(Theme.Recording.destructive)
        }
        .buttonStyle(.plain)
        .opacity(self.offset < 0 ? 1 : 0)
        .accessibilityHidden(true)
    }

    internal func body(content: Content) -> some View {
        if self.isEnabled {
            content
                .offset(x: self.offset)
                .background(alignment: .trailing) {
                    self.deleteButton
                }
                .clipped()
                .gesture(
                    HorizontalPan(
                        onChange: { translation in self.dragOffset = translation },
                        onEnd: self.settle,
                    )
                )
                .accessibilityAction(named: "削除", self.onDelete)
        } else {
            content
        }
    }

    // Leaves 削除 shown when the row moved far enough left, hidden otherwise.
    private func settle(translation: CGFloat) {
        let shows: Bool =
            self.restingOffset + translation
            < -self.actionWidth * Theme.Recording.swipeOpenThreshold
        withAnimation(.snappy) {
            self.isOpen.wrappedValue = shows
            self.dragOffset = 0
        }
    }
}
