import SwiftUI

/// 予算 tab root content: placeholder only, scrollable.
internal struct BudgetTabContent: View {
    // Held here (the tab root's own content view); see `HomeTabContent`'s
    // own doc comment on `lifecycle` for why.
    @State private var lifecycle: TabRootLifecycle = TabRootLifecycle(screenID: "budget")

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
        BudgetTabContent()
    }
}
