import SwiftUI

/// Shows a refused or failed scan write (`ScanStore.failureMessage`) as an
/// alert, until dismissed; see `LedgerFailureAlert`.
internal struct ScanFailureAlert: ViewModifier {
    @Environment(ScanStore.self)
    private var scanStore: ScanStore

    internal func body(content: Content) -> some View {
        content
            .alert(
                "できませんでした",
                isPresented: Binding(
                    get: { self.scanStore.failureMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            self.scanStore.failureMessage = nil
                        }
                    },
                ),
            ) {
                Button("OK") {
                    self.scanStore.failureMessage = nil
                }
            } message: {
                Text(self.scanStore.failureMessage ?? "")
            }
    }
}

extension View {
    /// Shows the scans' refused or failed writes; see `ScanFailureAlert`.
    internal func scanFailureAlert() -> some View {
        self.modifier(ScanFailureAlert())
    }
}
