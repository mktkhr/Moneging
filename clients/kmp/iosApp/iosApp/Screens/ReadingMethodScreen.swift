import SharedLogic
import SwiftUI

/// 読み取りの方法: the device's reading method.
///
/// `ReadingMethod5.dc.html`: Apple Intelligence or `AI を使わない`, the
/// chosen one checked. A method the device cannot use
/// is listed but cannot be chosen, and says why; `AI を使わない` can always
/// be chosen.
internal struct ReadingMethodScreen: View {
    @Environment(ReadingMethodStore.self)
    private var readingMethods: ReadingMethodStore

    internal var body: some View {
        List {
            Section {
                self.option(
                    .deviceAi,
                    description: String(
                        localized: "この端末の AI（Apple Intelligence）が、読んだ文字から店名・日付・合計・明細を組み立てます。"
                    ),
                    reason: self.readingMethods.isDeviceAiUsable
                        ? nil : self.readingMethods.deviceAiUnavailableReason,
                    identifier: "ai",
                )
                self.option(
                    .noAi,
                    description: String(
                        localized: "読んだ文字を、レシートによくある書き方の決まりに沿って組み立てます。どの端末でも使えます。"
                    ),
                    reason: nil,
                    identifier: "none",
                )
            } footer: {
                Text(
                    """
                    どちらも、写真と文字はこの端末の外に出ません。
                    選んだ方法が使えないときは、読み取りを始める前にお知らせします。
                    各下書きには、どちらで読み取ったかが出ます。
                    """
                )
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("読み取りの方法")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            self.readingMethods.refresh()
        }
    }

    private func option(
        _ method: ReadingMethod,
        description: String,
        reason: String?,
        identifier: String,
    ) -> some View {
        let isUsable: Bool = reason == nil
        let name: String = self.readingMethods.name(of: method)
        return VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
            Button {
                self.readingMethods.choose(method)
            } label: {
                self.optionLabel(method, name: name, description: description)
            }
            .buttonStyle(.plain)
            .opacity(isUsable ? 1 : Theme.Scanning.unusableOpacity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(name)
            .accessibilityAddTraits(
                self.readingMethods.chosen == method ? [.isButton, .isSelected] : .isButton
            )
            .accessibilityIdentifier("reading-method-option-\(identifier)")
            .disabled(!isUsable)
            if let reason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(Theme.Scanning.review)
                    .accessibilityIdentifier("reading-method-reason-\(identifier)")
            }
        }
        .listRowBackground(Theme.surface)
    }

    private func optionLabel(
        _ method: ReadingMethod,
        name: String,
        description: String,
    ) -> some View {
        HStack(spacing: Theme.Spacing.medium) {
            VStack(alignment: .leading, spacing: Theme.Spacing.extraExtraSmall) {
                Text(name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.text)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Theme.mutedText)
            }
            Spacer(minLength: Theme.Spacing.small)
            if self.readingMethods.chosen == method {
                Image(systemName: "checkmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }
}
