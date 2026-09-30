import SwiftUI
import WidgetKit

/// The app's widget extension: for now, the Live Activity of the scans in
/// flight (`ScanLiveActivity`).
@main
internal struct MonegingWidgetsBundle: WidgetBundle {
    internal var body: some Widget {
        ScanLiveActivity()
    }
}
