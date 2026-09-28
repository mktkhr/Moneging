import SwiftUI

/// A generic placeholder detail screen, used for every leaf destination
/// this shell does not implement yet.
internal struct PlaceholderScreen: View {
    /// The subtitle shown when a call site has nothing more specific to say.
    internal static let defaultSubtitle: String = "この画面はまだ準備中です"

    private static let contentSpacing: CGFloat = 8

    internal let title: String
    internal let subtitle: String

    internal var body: some View {
        VStack(spacing: Self.contentSpacing) {
            Text(self.title)
                .font(.title2.weight(.bold))
            Text(self.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle(self.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PlaceholderScreen(title: "見た目", subtitle: PlaceholderScreen.defaultSubtitle)
    }
}
