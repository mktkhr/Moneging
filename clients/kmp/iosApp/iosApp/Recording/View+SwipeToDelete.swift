import SwiftUI

extension View {
    /// 削除 behind the row, revealed by swiping it left (`SwipeToDelete`).
    internal func swipeToDelete(
        isEnabled: Bool,
        isOpen: Binding<Bool>,
        onDelete: @escaping () -> Void,
    ) -> some View {
        self.modifier(SwipeToDelete(isEnabled: isEnabled, onDelete: onDelete, isOpen: isOpen))
    }
}
