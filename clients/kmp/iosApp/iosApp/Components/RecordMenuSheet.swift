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
            VStack(spacing: Self.rowSpacing) {
                ForEach(RecordOption.allCases, id: \.self) { option in
                    Button {
                        self.onChoose(option)
                    } label: {
                        RecordOptionRow(option: option)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Self.padding)
        .presentationDetents([.medium])
    }
}

#Preview {
    RecordMenuSheet { _ in
        // No-op for preview.
    }
}
