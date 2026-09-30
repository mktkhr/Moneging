#if DEBUG
    import SharedLogic
    import SwiftUI

    /// Home's controls for UI tests that read receipts: the button that
    /// moves every unfinished scan job one state on (`scan-job-step`, with
    /// `-UITestJobStepping YES`), and the stand-in for the Live Activity
    /// (`progress-surface`, with `-UITestFakeProgressSurface YES`), present
    /// exactly while any scan of the ledger in view is in flight.
    internal struct UITestScanControls: View {
        internal var body: some View {
            HStack(spacing: Theme.Spacing.small) {
                if UITestScanning.isJobStepping {
                    Button("1段進める") {
                        stepScanJobsForUiTests()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("scan-job-step")
                }
                if UITestScanning.progressSurface?.isShown == true {
                    Text("読み取り中")
                        .font(.caption)
                        .foregroundStyle(Theme.mutedText)
                        .accessibilityIdentifier("progress-surface")
                }
            }
        }
    }
#endif
