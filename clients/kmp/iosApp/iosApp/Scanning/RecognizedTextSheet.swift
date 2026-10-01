#if DEBUG
    import SwiftUI
    import UIKit

    /// 読み取った文字, in development builds only.
    ///
    /// The text recognised from a receipt photo, as given to the
    /// structuring, in full and monospaced, with コピー to put it on the
    /// pasteboard. It helps find out why a device reads a receipt
    /// differently from the Mac.
    internal struct RecognizedTextSheet: View {
        internal let source: RecognizedTextSource

        @Environment(ScanStore.self)
        private var scanStore: ScanStore

        @Environment(\.dismiss)
        private var dismiss: DismissAction

        @State private var text: String?
        @State private var isLoaded: Bool = false

        internal var body: some View {
            NavigationStack {
                self.content
                    .background(Theme.background)
                    .navigationTitle("読み取った文字")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる", systemImage: "xmark", role: .close) {
                                self.dismiss()
                            }
                            .tint(Theme.text)
                            .accessibilityIdentifier("recognized-text-close")
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("コピー", systemImage: "doc.on.doc") {
                                UIPasteboard.general.string = self.text
                            }
                            .disabled(self.text == nil)
                            .accessibilityIdentifier("recognized-text-copy")
                        }
                    }
            }
            .tint(Theme.accent)
            .task(id: self.source) {
                self.text = await self.load()
                self.isLoaded = true
            }
        }

        @ViewBuilder private var content: some View {
            if let text = self.text {
                ScrollView {
                    Text(text)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.medium)
                        .accessibilityIdentifier("recognized-text")
                }
            } else if self.isLoaded {
                Text("読み取った文字はありません")
                    .foregroundStyle(Theme.mutedText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }

        private func load() async -> String? {
            await self.scanStore.recognizedText(scanId: self.source.scanId)
        }
    }
#endif
