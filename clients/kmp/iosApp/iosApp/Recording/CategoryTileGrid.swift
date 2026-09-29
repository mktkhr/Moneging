import SharedLogic
import SwiftUI

/// The categories to choose from in the entry and rule sheets: one tile
/// per active category, four to a row (two at accessibility text sizes),
/// the chosen one outlined.
///
/// Each tile is a button labelled exactly with its category's name and
/// identified `category-tile-<category id>`.
internal struct CategoryTileGrid: View {
    internal let categories: [SharedLogic.Category]
    internal let selection: Binding<String?>

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize: DynamicTypeSize

    @ScaledMetric(relativeTo: .caption)
    private var tileMinHeight: CGFloat = Theme.Recording.tileMinHeight

    private var columns: [GridItem] {
        let count: Int =
            self.dynamicTypeSize.isAccessibilitySize
            ? Theme.Recording.accessibilityGridColumns : Theme.Recording.gridColumns
        return Array(
            repeating: GridItem(.flexible(), spacing: Theme.Spacing.extraSmall, alignment: .top),
            count: count,
        )
    }

    internal var body: some View {
        LazyVGrid(columns: self.columns, spacing: Theme.Spacing.extraSmall) {
            ForEach(self.categories, id: \.id) { category in
                self.tile(category)
            }
        }
    }

    private func tile(_ category: SharedLogic.Category) -> some View {
        let categoryId: String = category.id.description
        let isSelected: Bool = self.selection.wrappedValue == categoryId
        return Button {
            self.selection.wrappedValue = categoryId
        } label: {
            VStack(spacing: Theme.Spacing.extraSmall) {
                CategoryIcon(defaultIndex: category.defaultIndex.map { Int(truncating: $0) })
                Text(category.name)
                    .font(.caption)
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            .padding(.vertical, Theme.Spacing.extraSmall)
            .frame(maxWidth: .infinity, minHeight: self.tileMinHeight)
            .background {
                RoundedRectangle(cornerRadius: Theme.Recording.tileRadius)
                    .fill(isSelected ? Theme.surface : Theme.background)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Recording.tileRadius)
                    .strokeBorder(
                        isSelected ? Theme.accent : Theme.background,
                        lineWidth: Theme.Recording.tileBorderWidth,
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("category-tile-\(categoryId)")
    }
}
