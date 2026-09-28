import SharedLogic
import SwiftUI

internal struct ContentView: View {
    private static let iconSize: CGFloat = 200
    private static let contentSpacing: CGFloat = 16

    @State private var showContent: Bool = false

    internal var body: some View {
        VStack {
            Button("Click me!") {
                withAnimation {
                    self.showContent.toggle()
                }
            }

            if self.showContent {
                VStack(spacing: Self.contentSpacing) {
                    Image(systemName: "swift")
                        .font(.system(size: Self.iconSize))
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true)
                    Text("SwiftUI: \(Greeting().greet())")
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding()
    }
}

#Preview {
    ContentView()
}
