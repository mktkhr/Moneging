import SwiftUI

/// A single row inside `RecordMenuSheet`: a leading icon tile, then the
/// option's title and subtitle, matching
/// `scratchpad/design/project/RecordMenu.dc.html`.
///
/// Sized by its content plus padding tokens (never a fixed height), with
/// the HIG minimum tap target as its floor. The icon tile and its glyph
/// scale together with Dynamic Type (`@ScaledMetric` relative to `.body`,
/// the glyph's own text style), so the glyph never outgrows its tile; at
/// accessibility text sizes the tile stacks above the text instead of
/// squeezing it into a narrow column.
internal struct RecordOptionRow: View {
    internal let option: RecordOption

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize: DynamicTypeSize

    @ScaledMetric(relativeTo: .body)
    private var tileSize: CGFloat = Theme.iconTileSize

    @ScaledMetric(relativeTo: .body)
    private var tileRadius: CGFloat = Theme.iconTileRadius

    private var layout: AnyLayout {
        if self.dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.medium))
        } else {
            AnyLayout(HStackLayout(spacing: Theme.Spacing.medium))
        }
    }

    internal var body: some View {
        self.layout {
            RoundedRectangle(cornerRadius: self.tileRadius)
                .fill(Theme.accent)
                .frame(width: self.tileSize, height: self.tileSize)
                .overlay {
                    Image(systemName: self.option.systemImage)
                        .font(.body)
                        .foregroundStyle(Theme.onAccent)
                        .accessibilityHidden(true)
                }
            VStack(alignment: .leading, spacing: Theme.Spacing.extraExtraSmall) {
                Text(self.option.title)
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.text)
                Text(self.option.subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Theme.Spacing.large)
        .padding(.vertical, Theme.Spacing.medium)
        .frame(minHeight: Theme.minimumTapTarget)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
    }
}

#Preview {
    RecordOptionRow(option: .manual)
}
