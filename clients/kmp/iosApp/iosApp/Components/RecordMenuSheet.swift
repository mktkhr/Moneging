import SwiftUI

/// 記録する: the sheet the floating record button presents (`RecordMenu5.dc.html`).
///
/// 手で入力する opens the entry sheet, レシートを撮る the document scanner
/// and 写真を選ぶ the photo library. The two receipt rows work only while
/// reading from photos is enabled; otherwise they are shown disabled,
/// saying where to turn it on.
internal struct RecordMenuSheet: View {
    internal let isPhotoReadingEnabled: Bool
    internal let onChoose: (RecordOption) -> Void

    internal var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("記録する")
                .font(.title2.weight(.bold))
                .accessibilityIdentifier("record-sheet-title")
            VStack(spacing: Theme.Spacing.small) {
                ForEach(RecordOption.sheetOrder, id: \.self) { option in
                    let isAvailable: Bool = option.isAvailable(
                        isPhotoReadingEnabled: self.isPhotoReadingEnabled,
                    )
                    Button {
                        self.onChoose(option)
                    } label: {
                        RecordOptionRow(option: option, isAvailable: isAvailable)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isAvailable)
                    .accessibilityIdentifier("record-option-\(option.identifier)")
                }
            }
        }
        .padding(Theme.Spacing.extraLarge)
        // `.contain`, not the default: exposes this whole content view as
        // its own accessibility element (so a UI test can compare its frame
        // with the presented sheet's, checking `fittedSheet()`) while keeping the
        // title/row buttons individually accessible underneath it.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("record-sheet-content")
    }
}

#Preview {
    RecordMenuSheet(isPhotoReadingEnabled: true) { _ in
        // No-op for preview.
    }
}
