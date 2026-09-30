import SharedLogic
import SwiftUI

/// 下書きを確認 (`Draft5.dc.html`): a waiting draft, every field editable.
///
/// ✓ (`draft-confirm`) saves the corrections and confirms the draft into an
/// expense; × closes it as it was; discarding it asks first. The form is
/// `DraftContent`.
internal struct DraftSheet: View {
    internal let draftId: String

    @Environment(ScanStore.self)
    private var scanStore: ScanStore

    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    @Environment(\.dismiss)
    private var dismiss: DismissAction

    @State private var photoId: String?
    @State private var draft: DraftFormState?
    @State private var isWorking: Bool = false
    @State private var isDiscardConfirmationShown: Bool = false

    internal var body: some View {
        NavigationStack {
            ScrollView {
                self.content
                    .padding(.horizontal, Theme.Spacing.large)
                    .padding(.bottom, Theme.Spacing.extraLarge)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle("下書きを確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                self.toolbar
            }
            .confirmationDialog(
                "この下書きを捨てますか？",
                isPresented: self.$isDiscardConfirmationShown,
                titleVisibility: .visible,
            ) {
                Button("捨てる", role: .destructive, action: self.discard)
                    .accessibilityIdentifier("draft-discard-confirm")
            }
        }
        .tint(Theme.accent)
        .presentationDetents([.large])
        .scanFailureAlert()
        .task(id: self.draftId) {
            await self.open()
        }
    }

    @ViewBuilder private var content: some View {
        if let editing = Binding(self.$draft) {
            DraftContent(
                form: editing,
                photoId: self.photoId,
                categories: self.ledgerStore.state.activeCategories,
            ) {
                self.isDiscardConfirmationShown = true
            }
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
    }

    private func open() async {
        guard let editing = await self.scanStore.openDraft(id: self.draftId) else {
            self.dismiss()
            return
        }
        self.photoId = editing.photoId
        self.draft = DraftFormState.from(editing)
    }

    private func confirm() {
        guard let form = self.draft?.form else {
            return
        }
        self.isWorking = true
        Task {
            let isConfirmed: Bool = await self.scanStore.confirm(draftId: self.draftId, form: form)
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
