import SwiftUI

/// A single row inside `RecordMenuSheet`.
internal struct RecordOptionRow: View {
    private static let iconSize: CGFloat = 40
    private static let iconCornerRadius: CGFloat = 12
    private static let rowSpacing: CGFloat = 14
    private static let textSpacing: CGFloat = 2
    private static let horizontalPadding: CGFloat = 16
    private static let minHeight: CGFloat = 64
    private static let cornerRadius: CGFloat = 18

    internal let option: RecordOption

    internal var body: some View {
        HStack(spacing: Self.rowSpacing) {
            RoundedRectangle(cornerRadius: Self.iconCornerRadius)
                .fill(Theme.accent)
                .frame(width: Self.iconSize, height: Self.iconSize)
                .overlay {
                    Image(systemName: self.option.systemImage)
                        .foregroundStyle(Theme.onAccent)
                        .accessibilityHidden(true)
                }
            VStack(alignment: .leading, spacing: Self.textSpacing) {
                Text(self.option.title)
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.text)
                Text(self.option.subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedText)
            }
            Spacer()
        }
        .padding(.horizontal, Self.horizontalPadding)
        .frame(minHeight: Self.minHeight)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
    }
}

#Preview {
    RecordOptionRow(option: .manual)
}
