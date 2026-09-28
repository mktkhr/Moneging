import SwiftUI

/// カレンダー tab root content: placeholder only, scrollable.
internal struct CalendarTabContent: View {
    internal let lifecycle: TabRootLifecycle

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
        CalendarTabContent(lifecycle: TabRootLifecycle(screenID: "calendar"))
    }
}
