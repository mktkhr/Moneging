import SwiftUI

/// A single row inside `RecordMenuSheet`.
internal struct RecordOptionRow: View {
    internal let option: RecordOption

    internal var body: some View {
        HStack(spacing: Theme.spacing14) {
            RoundedRectangle(cornerRadius: Theme.chipRadius)
                .fill(Theme.accent)
                .frame(width: Theme.iconSize, height: Theme.iconSize)
                .overlay {
                    Image(systemName: self.option.systemImage)
                        .foregroundStyle(Theme.onAccent)
                        .accessibilityHidden(true)
                }
            VStack(alignment: .leading, spacing: Theme.spacing2) {
                Text(self.option.title)
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.text)
                Text(self.option.subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedText)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.spacing16)
        .frame(minHeight: Theme.recordOptionRowMinHeight)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
    }
}

#Preview {
    RecordOptionRow(option: .manual)
}
