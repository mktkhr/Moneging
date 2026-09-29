import SharedLogic
import SwiftUI

/// The onboarding tour's coach mark over the app itself: everything dimmed
/// except a spotlight around the step's control, and the step's callout
/// beside it with an arrow toward it (`OnbLedger.dc.html` and the steps
/// after it).
///
/// Laid over the whole window by `RootView`. The dimmed app stays in the
/// accessibility tree (the header still names the ledger in view); only the
/// dim itself is hidden, and it takes every touch, so the app cannot be
/// used around the callout.
internal struct TourOverlay: View {
    internal let tour: TourState

    @Environment(TourLayout.self)
    private var layout: TourLayout

    internal var body: some View {
        // The outer reader keeps to the safe area (the keyboard's included)
        // only to learn its insets; the tour itself covers the whole window.
        GeometryReader { safeArea in
            let insets: EdgeInsets = safeArea.safeAreaInsets
            GeometryReader { proxy in
                let screen: CGRect = CGRect(origin: .zero, size: proxy.size)
                let origin: CGPoint = proxy.frame(in: .global).origin
                let spotlight: CGRect? = self.spotlight(offsetBy: origin)
                ZStack(alignment: .topLeading) {
                    self.dim(screen: screen, spotlight: spotlight)
                    self.callout(screen: screen, insets: insets, spotlight: spotlight)
                }
            }
            .ignoresSafeArea()
        }
    }

    private var step: TourStep {
        self.tour.step
    }

    // The spotlight around the step's control, in this view's coordinates;
    // nil until the control has reported where it is.
    private func spotlight(offsetBy origin: CGPoint) -> CGRect? {
        guard let frame = self.layout.frames[self.step.target] else {
            return nil
        }
        let local: CGRect = frame.offsetBy(dx: -origin.x, dy: -origin.y)
        return local.insetBy(dx: -Theme.Tour.spotlightPadding, dy: -Theme.Tour.spotlightPadding)
    }

    private func spotlightPath(in rect: CGRect) -> Path {
        switch self.step.target {
        case .ledgerTitle:
            RoundedRectangle(cornerRadius: Theme.Tour.spotlightRadius).path(in: rect)

        case .recordButton, .tabBar:
            Capsule().path(in: rect)
        }
    }

    private func dim(screen: CGRect, spotlight: CGRect?) -> some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.addRect(screen)
                if let spotlight {
                    path.addPath(self.spotlightPath(in: spotlight))
                }
            }
            .fill(Theme.Tour.dim, style: FillStyle(eoFill: true))
            if let spotlight {
                self.spotlightPath(in: spotlight)
                    .stroke(Theme.Tour.spotlightRing, lineWidth: Theme.Tour.spotlightRingWidth)
            }
        }
        .frame(width: screen.width, height: screen.height)
        .contentShape(Rectangle())
        .onTapGesture {
            // Takes the touch: the dimmed app is not usable during the tour.
        }
        .accessibilityHidden(true)
    }

    // The callout below a spotlight in the upper half of the screen, above
    // one in the lower half, centred when there is none yet; it scrolls
    // when it does not fit in the room left (large text, the keyboard up).
    @ViewBuilder
    private func callout(screen: CGRect, insets: EdgeInsets, spotlight: CGRect?) -> some View {
        let isBelow: Bool =
            spotlight.map { $0.midY < screen.height * Theme.Tour.calloutBelowThreshold } ?? true
        let arrowX: CGFloat? = spotlight.map { $0.midX - Theme.Spacing.large }
        let top: CGFloat = insets.top + Theme.Spacing.small
        let bottom: CGFloat = screen.height - insets.bottom - Theme.Spacing.small
        let room: CGFloat =
            spotlight.map { spot in
                isBelow
                    ? bottom - spot.maxY - Theme.Tour.calloutGap
                    : spot.minY - Theme.Tour.calloutGap - top
            } ?? (bottom - top)
        let content: TourCallout = TourCallout(
            tour: self.tour,
            arrowEdge: spotlight == nil ? nil : (isBelow ? .top : .bottom),
            arrowX: arrowX,
            maxHeight: max(room, Theme.minimumTapTarget),
        )
        if let spotlight {
            if isBelow {
                content
                    .padding(.top, spotlight.maxY + Theme.Tour.calloutGap)
                    .padding(.horizontal, Theme.Spacing.large)
                    .frame(width: screen.width, height: screen.height, alignment: .top)
            } else {
                content
                    .padding(.bottom, screen.height - spotlight.minY + Theme.Tour.calloutGap)
                    .padding(.horizontal, Theme.Spacing.large)
                    .frame(width: screen.width, height: screen.height, alignment: .bottom)
            }
        } else {
            content
                .padding(.horizontal, Theme.Spacing.large)
                .frame(width: screen.width, height: screen.height, alignment: .center)
        }
    }
}
