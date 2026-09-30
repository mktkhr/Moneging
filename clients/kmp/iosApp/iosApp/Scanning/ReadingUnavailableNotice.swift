import SwiftUI

/// The notice shown before a scan when the chosen AI cannot be used.
///
/// `ReadingUnavailable5.dc.html`: `Apple Intelligence が使えません`, why, and
/// the choices `AI を使わずに読み取る`, `設定を開く` and `やめる`. Nothing is
/// kept or read until the user chooses (the spec's Reading method).
internal struct ReadingUnavailableNotice: View {
    internal let title: String
    internal let reason: String?
    internal let onReadWithoutAi: () -> Void
    internal let onOpenSettings: () -> Void
    internal let onCancel: () -> Void

    internal var body: some View {
        ZStack {
            Theme.Scanning.noticeScrim
                .ignoresSafeArea()
                .accessibilityHidden(true)
            VStack(spacing: Theme.Spacing.small) {
                Text(self.title)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                Text(self.message)
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedText)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, Theme.Spacing.extraSmall)
                self.readWithoutAiButton
                self.openSettingsButton
                self.cancelButton
            }
            .padding(Theme.Spacing.large)
            .background(
                Theme.surface,
                in: RoundedRectangle(cornerRadius: Theme.Scanning.unusableNoticeRadius),
            )
            .padding(.horizontal, Theme.Scanning.unusableNoticeInset)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(self.title)
            .accessibilityAddTraits(.isModal)
            .accessibilityIdentifier("reading-unavailable-notice")
        }
    }

    private var readWithoutAiButton: some View {
        Button(action: self.onReadWithoutAi) {
            Text("AI を使わずに読み取る")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity, minHeight: Theme.Scanning.unusableNoticeButtonHeight)
                .background(Theme.accent, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("reading-unavailable-without-ai")
    }

    private var openSettingsButton: some View {
        Button(action: self.onOpenSettings) {
            Text("設定を開く")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
                .background(Theme.background, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("reading-unavailable-open-settings")
    }

    private var cancelButton: some View {
        Button(action: self.onCancel) {
            Text("やめる")
                .font(.subheadline)
                .foregroundStyle(Theme.mutedText)
                .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("reading-unavailable-cancel")
    }

    private var message: String {
        (self.reason ?? "") + String(localized: "AI を使わずに読み取るか、設定を変えてください。")
    }
}
