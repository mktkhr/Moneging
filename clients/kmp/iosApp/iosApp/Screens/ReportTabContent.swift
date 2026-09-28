import SwiftUI

/// レポート tab root content: placeholder only, scrollable.
internal struct ReportTabContent: View {
    // Held here (the tab root's own content view); see `HomeTabContent`'s
    // own doc comment on `lifecycle` for why.
    @State private var lifecycle: TabRootLifecycle = TabRootLifecycle(screenID: "report")

    internal var body: some View {
        GenericPlaceholderTabContent(
            screenID: "report",
            creationCount: self.lifecycle.creationCount,
            rowTitle: "カテゴリ別の集計",
        )
    }
}

#Preview {
    ScrollView {
        ReportTabContent()
    }
}
