import SharedLogic
import SwiftUI

/// レシートの読み取り (`Drafts5.dc.html`): the scans of the ledger in view.
///
/// They are listed under 確認待ち (drafts, `draft-row-<id>`, opening the
/// draft), 読み取り中 and 読み取れなかったもの (the reason, with 手で入力する,
/// recording the expense by hand linked to the photo, and もう一度読む; a
/// scan the device's AI failed also offers AI を使わずに読む,
/// `DraftsAiFailed5.dc.html`).
/// Once nothing is left to show it goes back.
internal struct ScansScreen: View {
    @Environment(ScanStore.self)
    private var scanStore: ScanStore

    @Environment(AppRouter.self)
    private var router: AppRouter

    private var state: ScanUiState {
        self.scanStore.state
    }

    internal var body: some View {
        List {
            if !self.state.waiting.isEmpty {
                Section(self.state.waitingText) {
                    ForEach(self.state.waiting, id: \.id) { row in
                        self.waitingRow(row)
                    }
                }
            }
            if !self.state.inFlight.isEmpty {
                Section(self.state.inFlightText) {
                    ForEach(self.state.inFlight, id: \.id) { row in
                        self.inFlightRow(row)
                    }
                }
            }
            if !self.state.failed.isEmpty {
                Section(self.state.failedText) {
                    ForEach(self.state.failed, id: \.id) { row in
                        self.failedRow(row)
                    }
                }
            }
            Section {
                EmptyView()
            } footer: {
                Text("読み取りはこの端末の中だけで行います。写真はどこにも送られません。")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("レシートの読み取り")
        .navigationBarTitleDisplayMode(.inline)
        .scanFailureAlert()
        .onChange(of: self.state.hasAny) { _, hasAny in
            if !hasAny, self.router.draftSheet == nil {
                self.router.pop()
            }
        }
        .onChange(of: self.router.draftSheet) { _, sheet in
            if sheet == nil, !self.state.hasAny {
                self.router.pop()
            }
        }
    }

    private func waitingRow(_ row: WaitingDraftRow) -> some View {
        Button {
            self.router.draftSheet = DraftSheetRequest(draftId: row.id)
        } label: {
            HStack(spacing: Theme.Spacing.medium) {
                self.thumbnail(photoId: row.photoId)
                VStack(alignment: .leading, spacing: Theme.Spacing.extraExtraSmall) {
                    Text(row.store)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.text)
                    Text(row.dateText)
                        .font(.caption)
                        .foregroundStyle(Theme.mutedText)
                }
                Spacer(minLength: Theme.Spacing.small)
                Text(row.totalText)
                    .font(.body.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedText)
                    .accessibilityHidden(true)
            }
            // The whole row answers a tap, the gap before the total too: a
            // plain button hit-tests only what it draws.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Theme.surface)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("draft-row-\(row.id)")
    }

    private func inFlightRow(_ row: ScanJobRow) -> some View {
        HStack(spacing: Theme.Spacing.medium) {
            self.thumbnail(photoId: row.photoId)
            Text("読み取り中…")
                .foregroundStyle(Theme.mutedText)
            Spacer(minLength: Theme.Spacing.small)
            ProgressView()
                .tint(Theme.accent)
        }
        .listRowBackground(Theme.surface)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("scan-row-\(row.id)")
    }

    private func failedRow(_ row: ScanJobRow) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            HStack(spacing: Theme.Spacing.medium) {
                self.thumbnail(photoId: row.photoId)
                VStack(alignment: .leading, spacing: Theme.Spacing.extraExtraSmall) {
                    Text("読み取れませんでした")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.text)
                    Text(row.failureReason ?? "")
                        .font(.caption)
                        .foregroundStyle(Theme.mutedText)
                }
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: Theme.Spacing.small) {
                if row.isReadByDeviceAi {
                    let identifier: String = "scan-without-ai-\(row.id)"
                    self.failedAction(title: "AI を使わずに読む", identifier: identifier) {
                        Task {
                            _ = await self.scanStore.readWithoutAi(jobId: row.id)
                        }
                    }
                }
                self.failedAction(title: "手で入力する", identifier: "scan-manual-\(row.id)") {
                    self.router.entrySheet = .new(photoId: row.photoId)
                }
                self.failedAction(title: "もう一度読む", identifier: "scan-retry-\(row.id)") {
                    Task {
                        _ = await self.scanStore.readAgain(jobId: row.id)
                    }
                }
            }
        }
        .padding(.vertical, Theme.Spacing.extraSmall)
        .listRowBackground(Theme.surface)
        .accessibilityIdentifier("scan-failed-\(row.id)")
    }

    private func failedAction(
        title: String,
        identifier: String,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, minHeight: Theme.Scanning.actionHeight)
                .background(
                    Theme.background,
                    in: RoundedRectangle(cornerRadius: Theme.Scanning.actionRadius)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Scanning.actionRadius)
                        .strokeBorder(Theme.line)
                }
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier(identifier)
    }

    private func thumbnail(photoId: String) -> some View {
        ReceiptThumbnail(
            photoId: photoId,
            width: Theme.Scanning.rowThumbnailWidth,
            height: Theme.Scanning.rowThumbnailHeight,
        )
    }
}
