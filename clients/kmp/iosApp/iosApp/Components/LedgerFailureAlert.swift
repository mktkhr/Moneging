import SwiftUI

/// Shows a refused or failed write of the ledger in view
/// (`LedgerStore.failureMessage`) as an alert, until dismissed.
///
/// Applied to every screen and sheet that writes, so the alert shows over
/// whichever is presented.
internal struct LedgerFailureAlert: ViewModifier {
    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    internal func body(content: Content) -> some View {
        content
            .alert(
                "保存できませんでした",
                isPresented: Binding(
                    get: { self.ledgerStore.failureMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            self.ledgerStore.failureMessage = nil
                        }
                    },
                ),
            ) {
                Button("OK") {
                    self.ledgerStore.failureMessage = nil
                }
            } message: {
                Text(self.ledgerStore.failureMessage ?? "")
            }
    }
}

extension View {
    /// Shows the ledger's refused or failed writes; see `LedgerFailureAlert`.
    internal func ledgerFailureAlert() -> some View {
        self.modifier(LedgerFailureAlert())
    }
}
