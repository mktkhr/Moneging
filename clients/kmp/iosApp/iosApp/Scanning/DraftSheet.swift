import SharedLogic
import SwiftUI

/// 下書きを確認 (`Draft5.dc.html`): a waiting draft, every field editable.
///
/// ✓ (`draft-confirm`) saves the corrections and confirms the draft into an
/// expense; × closes it as it was; discarding it asks first. The form is
/// `DraftContent`. While the items do not add up, ✓ first asks in the middle
/// of the screen (`Draft6Confirm.dc.html`): `このまま記録する` confirms it
/// accepting the mismatch, `戻って直す` returns to the draft.
internal struct DraftSheet: View {
    internal let draftId: String

    @Environment(ScanStore.self)
    private var scanStore: ScanStore

    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    @Environment(\.dismiss)
    private var dismiss: DismissAction

    @State private var photoId: String?
    @State private var readingMethodText: String?
    @State private var draft: DraftFormState?
    @State private var isWorking: Bool = false
    /// The mismatch asked about before confirming, while the question shows.
    @State private var askedMismatch: DraftMismatch?

    #if DEBUG
        @State private var isRecognizedTextShown: Bool = false
    #endif

    internal var body: some View {
        NavigationStack {
            self.content
                .background(Theme.background)
                .navigationTitle("下書きを確認")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    self.toolbar
                }
        }
        .tint(Theme.accent)
        .alert(
            self.askedMismatch?.questionTitle ?? "",
            isPresented: Binding(
                get: { self.askedMismatch != nil },
                set: { isShown in
                    if !isShown {
                        self.askedMismatch = nil
                    }
                },
            ),
            presenting: self.askedMismatch,
        ) { _ in
            Button("このまま記録する") {
                self.record(acceptMismatch: true)
            }
            .accessibilityIdentifier("draft-mismatch-accept")
            Button("戻って直す", role: .cancel) {
                self.askedMismatch = nil
            }
            .accessibilityIdentifier("draft-mismatch-decline")
        } message: { mismatch in
            Text(mismatch.questionMessage)
        }
        .presentationDetents([.large])
        .scanFailureAlert()
        .task(id: self.draftId) {
            await self.open()
        }
        #if DEBUG
            .sheet(isPresented: self.$isRecognizedTextShown) {
                RecognizedTextSheet(source: .draft(id: self.draftId))
            }
        #endif
    }

    @ViewBuilder private var content: some View {
        if let editing = Binding(self.$draft) {
            DraftContent(
                form: editing,
                photoId: self.photoId,
                readingMethodText: self.readingMethodText,
                categories: self.ledgerStore.state.activeCategories,
                onDiscard: self.discard,
            )
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.extraLarge)
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("閉じる", systemImage: "xmark", role: .close) {
                self.dismiss()
            }
            .tint(Theme.text)
            .accessibilityIdentifier("draft-cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("記録する", systemImage: "checkmark", role: .confirm, action: self.confirm)
                .disabled(!(self.draft?.canConfirm ?? false) || self.isWorking)
                .accessibilityIdentifier("draft-confirm")
        }
        #if DEBUG
            ToolbarItem(placement: .bottomBar) {
                Button("読み取った文字を見る", systemImage: "text.viewfinder") {
                    self.isRecognizedTextShown = true
                }
                .labelStyle(.titleAndIcon)
                .accessibilityIdentifier("draft-recognized-text")
            }
        #endif
    }

    private func open() async {
        guard let editing = await self.scanStore.openDraft(id: self.draftId) else {
            self.dismiss()
            return
        }
        self.photoId = editing.photoId
        self.readingMethodText = editing.methodText
        self.draft = DraftFormState.from(editing)
    }

    private func confirm() {
        if let mismatch = self.draft?.form.mismatch() {
            self.askedMismatch = mismatch
            return
        }
        self.record(acceptMismatch: false)
    }

    private func record(acceptMismatch: Bool) {
        guard let form = self.draft?.form else {
            return
        }
        self.isWorking = true
        Task {
            let isConfirmed: Bool = await self.scanStore.confirm(
                draftId: self.draftId,
                form: form,
                acceptMismatch: acceptMismatch,
            )
            self.isWorking = false
            if isConfirmed {
                self.dismiss()
            }
        }
    }

    private func discard() {
        Task {
            if await self.scanStore.discard(draftId: self.draftId) {
                self.dismiss()
            }
        }
    }
}
