import ActivityKit
import SwiftUI
import WidgetKit

/// The Live Activity of the scans in flight (`LiveActivity5.dc.html`): on
/// the lock screen, the ledger, a bar of how many of this run have finished,
/// and how many are being read and waiting; in the Dynamic Island, the
/// receipt and `1/3`.
internal struct ScanLiveActivity: Widget {
    private static let iconSize: CGFloat = 32
    private static let iconRadius: CGFloat = 8
    private static let spacing: CGFloat = 10
    private static let padding: CGFloat = 16
    private static let symbol: String = "scroll"

    internal var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScanActivityAttributes.self) { context in
            let accent: Color = ScanActivityPalette.accent(of: context.attributes)
            Self.lockScreen(context: context)
                .padding(Self.padding)
                .activitySystemActionForegroundColor(accent)
        } dynamicIsland: { context in
            let accent: Color = ScanActivityPalette.accent(of: context.attributes)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("読み取り中", systemImage: Self.symbol)
                        .foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.ledgerLabel)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Self.counts(context.state, accent: accent)
                }
            } compactLeading: {
                Image(systemName: Self.symbol)
                    .foregroundStyle(accent)
                    .accessibilityLabel("レシートを読み取り中")
            } compactTrailing: {
                Text("\(context.state.finished)/\(context.state.total)")
                    .foregroundStyle(accent)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: Self.symbol)
                    .foregroundStyle(accent)
                    .accessibilityLabel("レシートを読み取り中")
            }
        }
    }

    private static func lockScreen(
        context: ActivityViewContext<ScanActivityAttributes>,
    ) -> some View {
        let accent: Color = ScanActivityPalette.accent(of: context.attributes)
        return VStack(alignment: .leading, spacing: Self.spacing) {
            HStack(spacing: Self.spacing) {
                Image(systemName: Self.symbol)
                    .foregroundStyle(.white)
                    .frame(width: Self.iconSize, height: Self.iconSize)
                    .background(accent, in: RoundedRectangle(cornerRadius: Self.iconRadius))
                    .accessibilityHidden(true)
                Text("レシートを読み取り中")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(context.state.ledgerLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Self.counts(context.state, accent: accent)
        }
    }

    private static func counts(
        _ state: ScanActivityAttributes.ContentState,
        accent: Color,
    ) -> some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            ProgressView(value: Double(state.finished), total: Double(max(state.total, 1)))
                .tint(accent)
            HStack {
                Text("読み取り中 \(state.inFlight)件")
                Spacer()
                Text("確認待ち \(state.waiting)件")
            }
            .font(.footnote)
            .monospacedDigit()
        }
    }
}
