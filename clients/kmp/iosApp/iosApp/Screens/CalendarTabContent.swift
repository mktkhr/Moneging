import SwiftUI

/// カレンダー tab root content: placeholder only, scrollable.
internal struct CalendarTabContent: View {
    // Held here (the tab root's own content view); see `HomeTabContent`'s
    // own doc comment on `lifecycle` for why.
    @State private var lifecycle: TabRootLifecycle = TabRootLifecycle(screenID: "calendar")

    internal var body: some View {
        GenericPlaceholderTabContent(
            screenID: "calendar",
            creationCount: self.lifecycle.creationCount,
            rowTitle: "日別の記録",
        )
    }
}

#Preview {
    ScrollView {
        CalendarTabContent()
    }
}
