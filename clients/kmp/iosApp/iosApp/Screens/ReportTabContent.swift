import SwiftUI

/// レポート tab root content: placeholder only, scrollable.
internal struct ReportTabContent: View {
    internal let lifecycle: TabRootLifecycle

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
        ReportTabContent(lifecycle: TabRootLifecycle(screenID: "report"))
    }
}
