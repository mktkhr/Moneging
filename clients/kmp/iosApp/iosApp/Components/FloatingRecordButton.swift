import SwiftUI

/// The floating round 記録する button shown above the tab bar on the four
/// main tabs, matching `scratchpad/design/project/OptionB.dc.html`.
internal struct FloatingRecordButton: View {
    internal let action: () -> Void

    internal var body: some View {
        Button(action: self.action) {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: Theme.recordButtonDiameter, height: Theme.recordButtonDiameter)
                .background(Theme.accent, in: Circle())
                .shadow(
                    color: Theme.shadowColor,
                    radius: Theme.shadowBlurRadius,
                    y: Theme.shadowOffsetY,
                )
        }
        .accessibilityLabel("記録する")
        .accessibilityIdentifier("record-button")
        .frame(minWidth: Theme.minimumTapTarget, minHeight: Theme.minimumTapTarget)
    }
}

#Preview {
    FloatingRecordButton {
        // No-op for preview.
    }
}
