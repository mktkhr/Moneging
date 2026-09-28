import SwiftUI

/// レポート tab root content: placeholder only, scrollable.
internal struct ReportTabContent: View {
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
