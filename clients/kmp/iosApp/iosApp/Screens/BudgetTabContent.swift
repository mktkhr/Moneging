import SwiftUI

/// 予算 tab root content: placeholder only, scrollable.
internal struct BudgetTabContent: View {
    internal let lifecycle: TabRootLifecycle

    internal var body: some View {
        GenericPlaceholderTabContent(
            screenID: "budget",
            creationCount: self.lifecycle.creationCount,
            rowTitle: "カテゴリ別の予算",
        )
    }
}

#Preview {
    ScrollView {
        BudgetTabContent(lifecycle: TabRootLifecycle(screenID: "budget"))
    }
}
