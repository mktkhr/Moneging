import SwiftUI

/// A main tab's root, wrapping a `NavigationStack` and the shared header.
///
/// Bound to that tab's path, wrapped around the tab's scrollable
/// placeholder content and the shared header (`TabHeaderModifier`), with
/// the floating 記録する button floating above the tab bar. The sheet that
/// button opens lives once at the app root (`RootView`), so it is only
/// ever presented once regardless of which tab is active.
internal struct MainTabScreen<Content: View>: View {
    internal let path: Binding<NavigationPath>
    /// Whether this tab's root reports the tour's targets (ホーム's: the
    /// tour always runs over it).
    internal let isTourHost: Bool
    /// Whether the content is wrapped in a `ScrollView`; `false` for content
    /// that scrolls itself (ホーム's `List`).
    internal var wrapsContentInScrollView: Bool = true
    @ViewBuilder internal let content: () -> Content

    @Environment(AppRouter.self)
    private var router: AppRouter

    @Environment(ScanStore.self)
    private var scanStore: ScanStore

    internal var body: some View {
        NavigationStack(path: self.path) {
            Group {
                if self.wrapsContentInScrollView {
                    ScrollView {
                        self.content()
                    }
                } else {
                    self.content()
                }
            }
            .background(Theme.background)
            .tabHeader(isTourHost: self.isTourHost)
            .appNavigationDestinations()
            // The notice that photos were accepted, above the record button.
            .overlay(alignment: .bottom) {
                if let notice = self.scanStore.notice {
                    ScanAcceptedNotice(text: notice)
                        .padding(.bottom, Theme.Spacing.large)
                }
            }
            // Places the floating 記録する button in the tab root's own
            // bottom safe-area inset, right-aligned. Inside a tab, the tab
            // bar (whatever its current height: Liquid Glass's
            // collapsed/expanded states, Dynamic Type, device, orientation)
            // is already part of the bottom safe area, so the inset sits
            // above the whole tab bar - including the separate 検索 button -
            // without measuring anything; the padding is only the deliberate
            // gap around the button. The inset also shrinks the scroll
            // view's safe area by exactly the button's footprint, so the last
            // row can always scroll clear of it.
            //
            // Below the button, a line of no height marks the top of the tab
            // bar's area; the tour's reader of the tab bar's frame extends
            // down from it over that area.
            .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
                VStack(alignment: .trailing, spacing: 0) {
                    if self.router.isRecordButtonVisible {
                        self.recordButtonRow
                    }
                    Spacer(minLength: 0)
                        .frame(maxWidth: .infinity, maxHeight: 0)
                        .tabBarTourTarget(isReporting: self.isTourHost)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    // The floating 記録する button, right-aligned; in a UI test reading
    // receipts, ホーム's test controls on its left.
    private var recordButtonRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            #if DEBUG
                if self.isTourHost {
                    UITestScanControls()
                }
            #endif
            Spacer(minLength: 0)
            FloatingRecordButton {
                self.router.isRecordSheetPresented = true
            }
            .tourTarget(.recordButton, isReporting: self.isTourHost)
        }
        .padding([.horizontal, .bottom], Theme.Spacing.large)
    }
}
