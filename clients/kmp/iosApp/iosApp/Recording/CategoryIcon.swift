import SwiftUI

/// A category's icon tile: a default category's own symbol and colour
/// (`Theme.Recording`, by `Category.defaultIndex`), a generic one for a
/// category the ledger added, or an income's arrow.
///
/// Scales with Dynamic Type; hidden from VoiceOver (the row or tile around
/// it names the category).
internal struct CategoryIcon: View {
    /// The default category shown (`Category.defaultIndex`), or `nil` for
    /// an added one.
    internal let defaultIndex: Int?
    /// Whether it stands for an income rather than a category.
    internal var isIncome: Bool = false

    @ScaledMetric(relativeTo: .body)
    private var size: CGFloat = Theme.Recording.iconSize

    @ScaledMetric(relativeTo: .body)
    private var radius: CGFloat = Theme.Recording.iconRadius

    private var symbol: String {
        if self.isIncome {
            return Theme.Recording.incomeSymbol
        }
        guard let index = self.knownIndex else {
            return Theme.Recording.addedCategorySymbol
        }
        return Theme.Recording.categorySymbols[index]
    }

    private var foreground: Color {
        if self.isIncome {
            return Theme.income
        }
        guard let index = self.knownIndex else {
            return Theme.Recording.addedCategoryForeground
        }
        return Theme.Recording.categoryForegrounds[index]
    }

    private var background: Color {
        if self.isIncome {
            return Theme.Recording.incomeBackground
        }
        guard let index = self.knownIndex else {
            return Theme.Recording.addedCategoryBackground
        }
        return Theme.Recording.categoryBackgrounds[index]
    }

    private var knownIndex: Int? {
        guard let index = self.defaultIndex, Theme.Recording.categorySymbols.indices.contains(index)
        else {
            return nil
        }
        return index
    }

    // Grows with the text, up to twice its default size.
    private var side: CGFloat {
        min(self.size, Theme.Recording.iconSize * Theme.Recording.iconMaximumScale)
    }

    internal var body: some View {
        RoundedRectangle(cornerRadius: self.radius)
            .fill(self.background)
            .frame(width: self.side, height: self.side)
            .overlay {
                Image(systemName: self.symbol)
                    .font(.body.weight(.semibold))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .foregroundStyle(self.foreground)
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        CategoryIcon(defaultIndex: 0)
        CategoryIcon(defaultIndex: nil)
        CategoryIcon(defaultIndex: nil, isIncome: true)
    }
}
