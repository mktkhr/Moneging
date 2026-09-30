import SwiftUI

/// How much of a budget is spent, as a bar.
///
/// The accent colour, or the overspent colour once more was spent than
/// budgeted. Decorative: the row around it says the same in words.
internal struct BudgetBar: View {
    /// How much is spent, 0 to 1.
    internal let progress: Double
    internal let isOver: Bool

    internal var body: some View {
        Capsule()
            .fill(Theme.Budgets.barTrack)
            .frame(height: Theme.Budgets.barHeight)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: Theme.Budgets.barRadius)
                        .fill(self.isOver ? Theme.Budgets.over : Theme.accent)
                        .frame(width: proxy.size.width * CGFloat(self.progress))
                }
            }
            .clipShape(Capsule())
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack {
        BudgetBar(progress: 0.6, isOver: false)
        BudgetBar(progress: 1, isOver: true)
    }
    .padding()
}
