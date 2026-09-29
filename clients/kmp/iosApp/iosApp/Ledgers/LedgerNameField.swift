import SwiftUI

/// The name field of the sheet adding a ledger and of the editor renaming
/// one.
///
/// It keeps whatever is typed (nothing is cut off), and says the rule the
/// confirm button enforces.
internal struct LedgerNameField: View {
    internal let text: Binding<String>
    internal let identifier: String
    internal var isInitiallyFocused: Bool = false

    internal var body: some View {
        Section {
            NameTextField(
                placeholder: String(localized: "家計簿の名前"),
                text: self.text,
                identifier: self.identifier,
                onSubmit: {
                    // Confirming is the toolbar button's; return only closes the keyboard.
                },
                isInitiallyFocused: self.isInitiallyFocused,
            )
            .frame(minHeight: Theme.minimumTapTarget)
        } header: {
            Text("家計簿の名前")
        } footer: {
            Text("前後の空白を除いて1〜20文字。あとから変えられます。")
        }
    }
}
