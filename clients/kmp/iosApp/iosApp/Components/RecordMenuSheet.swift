import SwiftUI

/// 記録する: the sheet the floating record button presents, matching
/// `scratchpad/design/project/RecordMenu.dc.html`.
internal struct RecordMenuSheet: View {
    private static let titleSpacing: CGFloat = 14
    private static let rowSpacing: CGFloat = 10
    private static let padding: CGFloat = 20

    internal let onChoose: (RecordOption) -> Void

    internal var body: some View {
        VStack(alignment: .leading, spacing: Self.titleSpacing) {
            Text("記録する")
                .font(.title2.weight(.bold))
                .accessibilityIdentifier("record-sheet-title")
            VStack(spacing: Self.rowSpacing) {
                ForEach(RecordOption.sheetOrder, id: \.self) { option in
                    Button {
                        self.onChoose(option)
                    } label: {
                        RecordOptionRow(option: option)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("record-option-\(option.identifier)")
                }
            }
        }
        .padding(Self.padding)
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
