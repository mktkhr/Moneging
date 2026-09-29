import SwiftUI

/// 記録する: the sheet the floating record button presents, matching
/// `RecordMenu2.dc.html`: 手で入力する opens the entry sheet; reading a
/// receipt comes later, so its two rows are shown disabled, marked 準備中.
internal struct RecordMenuSheet: View {
    internal let onChoose: (RecordOption) -> Void

    internal var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("記録する")
                .font(.title2.weight(.bold))
                .accessibilityIdentifier("record-sheet-title")
            VStack(spacing: Theme.Spacing.small) {
                ForEach(RecordOption.sheetOrder, id: \.self) { option in
                    Button {
                        self.onChoose(option)
                    } label: {
                        RecordOptionRow(option: option)
                    }
                    .buttonStyle(.plain)
                    .disabled(!option.isAvailable)
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
    RecordMenuSheet { _ in
        // No-op for preview.
    }
}
