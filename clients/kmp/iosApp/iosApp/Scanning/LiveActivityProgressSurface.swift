import ActivityKit
import UIKit

/// The progress of the scans in flight as a Live Activity, on the lock
/// screen and in the Dynamic Island (`LiveActivity5.dc.html`), ended at
/// once when no scan is in flight.
///
/// While any scan is in flight it also asks the system for time to finish
/// in the background, so a scan started just before the user leaves the
/// app completes rather than being cut off.
@MainActor
internal final class LiveActivityProgressSurface: ScanProgressSurface {
    private static let taskName: String = "scans"

    private var activity: Activity<ScanActivityAttributes>?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    internal init() {
        // Nothing is shown until a scan is in flight.
    }

    /// Starts, updates or ends the Live Activity.
    internal func show(progress: ScanActivityAttributes.ContentState?) {
        guard let progress else {
            self.end()
            return
        }
        self.holdBackgroundTime()
        let content: ActivityContent<ScanActivityAttributes.ContentState> = ActivityContent(
            state: progress,
            staleDate: nil,
        )
        if let activity = self.activity {
            Task {
                await activity.update(content)
            }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }
        let attributes: ScanActivityAttributes = ScanActivityAttributes(
            accentLightHex: Theme.accentLightHex,
            accentDarkHex: Theme.accentDarkHex,
        )
        // A Live Activity the system refuses (too many, turned off) is not
        // shown; the scans go on and the app shows them anyway.
        self.activity = try? Activity.request(attributes: attributes, content: content)
    }

    private func end() {
        self.endActivity()
        self.releaseBackgroundTime()
    }

    private func endActivity() {
        guard let activity = self.activity else {
            return
        }
        self.activity = nil
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func holdBackgroundTime() {
        guard self.backgroundTask == .invalid else {
            return
        }
        let expire: @MainActor @Sendable () -> Void = { [weak self] in self?.releaseBackgroundTime()
        }
        self.backgroundTask = UIApplication.shared.beginBackgroundTask(
            withName: Self.taskName,
            expirationHandler: expire,
        )
    }

    private func releaseBackgroundTime() {
        guard self.backgroundTask != .invalid else {
            return
        }
        UIApplication.shared.endBackgroundTask(self.backgroundTask)
        self.backgroundTask = .invalid
    }

    deinit {
        // The activity ends with the scans; nothing to release here.
    }
}
