import Foundation
import Observation
import SharedLogic
import UIKit

/// `@Observable` adapter over the shared Kotlin `ScanData` (the scans of the
/// ledger in view) and `ScanEditor` (accepting photos, confirming,
/// discarding and reading drafts again), consumed through SKIE's
/// `AsyncSequence` bridging of `StateFlow`.
///
/// Created once at the app root (`MonegingApp`) and shared through the
/// environment. A write returns whether it was done; a refusal is kept in
/// `failureMessage` for the screen to show. Accepting photos shows the
/// notice `N枚の読み取りを受け付けました` for a moment (`notice`). While any
/// scan of any ledger is in flight its progress is shown outside the app
/// (`progressSurface`), and that ends as soon as none is.
@MainActor
@Observable
internal final class ScanStore {
    /// The scans of the ledger in view.
    internal private(set) var state: ScanUiState
    /// The notice that photos were accepted, while it shows; `nil` otherwise.
    internal private(set) var notice: String?
    /// Why the last write was refused, or `nil`.
    internal var failureMessage: String?

    private let scanData: ScanData
    private let editor: ScanEditor
    private let progressSurface: any ScanProgressSurface
    /// Holds the observation loop; see `SharedStateStore.observationTask`.
    private let observationTask: ObservationTaskBox = ObservationTaskBox()
    /// Holds the loop observing the scans in flight in every ledger.
    private let progressTask: ObservationTaskBox = ObservationTaskBox()
    /// Hides the notice after `Theme.Scanning.noticeDuration`.
    private let noticeTask: ObservationTaskBox = ObservationTaskBox()

    internal init(
        scanData: ScanData,
        editor: ScanEditor,
        progressSurface: any ScanProgressSurface,
    ) {
        self.scanData = scanData
        self.editor = editor
        self.progressSurface = progressSurface
        self.state = scanData.uiState.value

        let stateFlow: SkieSwiftStateFlow<ScanUiState> = scanData.uiState
        let taskBox: ObservationTaskBox = self.observationTask
        taskBox.task = Task { [weak self] in
            for await published in stateFlow {
                guard let self else {
                    return
                }
                self.state = published
            }
        }
        let progressFlow: SkieSwiftStateFlow<ScanProgress> = scanData.progress
        let progressBox: ObservationTaskBox = self.progressTask
        progressBox.task = Task { [weak self] in
            for await progress in progressFlow {
                guard let self else {
                    return
                }
                self.show(progress: progress)
            }
        }
    }

    /// Keeps each of `photos` as it is and starts its scan by `method`, or
    /// by the chosen method when `nil`, then tells how many were accepted.
    internal func accept(_ photos: [ReceiptPhoto], method: ReadingMethod?) async {
        var accepted: Int = 0
        for (contentType, group) in Dictionary(grouping: photos, by: \.contentType) {
            do {
                let acceptance: ScanAcceptance = try await self.editor.acceptPhotos(
                    images: group.map { photo in byteArray(data: photo.data) },
                    contentType: contentType,
                    method: method,
                )
                accepted += Int(acceptance.acceptedCount)
                if let refusal = acceptance.failureMessage {
                    self.failureMessage = refusal
                }
            } catch {
                self.failureMessage = String(localized: "写真を保存できませんでした")
            }
        }
        if accepted > 0 {
            self.show(notice: scanAcceptedNotice(count: Int32(accepted)))
        }
    }

    /// The waiting draft `draftId` as its form opens it, or `nil` when it is gone.
    internal func openDraft(id draftId: String) async -> DraftEditing? {
        do {
            return try await self.editor.openDraft(draftId: draftId)
        } catch {
            self.failureMessage = String(localized: "下書きを読み込めませんでした")
            return nil
        }
    }

    /// Saves `form` into the draft `draftId` and confirms it; returns whether it was confirmed.
    internal func confirm(draftId: String, form: DraftForm) async -> Bool {
        await self.write { try await self.editor.confirmDraft(draftId: draftId, form: form) }
    }

    /// Discards the draft `draftId`; returns whether it was discarded.
    internal func discard(draftId: String) async -> Bool {
        await self.write { try await self.editor.discardDraft(draftId: draftId) }
    }

    /// Reads the photo of the failed scan `jobId` again; returns whether it started.
    internal func readAgain(jobId: String) async -> Bool {
        await self.write { try await self.editor.readAgain(jobId: jobId) }
    }

    /// Reads the photo of the failed scan `jobId` again without AI; returns whether it started.
    internal func readWithoutAi(jobId: String) async -> Bool {
        await self.write { try await self.editor.readWithoutAi(jobId: jobId) }
    }

    /// The photo `photoId` of the ledger in view, or `nil`.
    internal func photo(id photoId: String) async -> UIImage? {
        guard let bytes = try? await self.editor.photoBytes(photoId: photoId) else {
            return nil
        }
        return UIImage(data: nsData(bytes: bytes))
    }

    // Shows the scans in flight in every ledger outside the app, or ends
    // that when none is.
    private func show(progress: ScanProgress) {
        guard progress.isInFlight else {
            self.progressSurface.show(progress: nil)
            return
        }
        self.progressSurface.show(
            progress: ScanActivityAttributes.ContentState(
                inFlight: Int(progress.inFlight),
                waiting: Int(progress.waiting),
                finished: Int(progress.finishedInRun),
                total: Int(progress.totalInRun),
                ledgerLabel: progress.ledgerLabel,
            ),
        )
    }

    // Shows `notice` for a moment.
    private func show(notice: String) {
        self.notice = notice
        AccessibilityNotification.Announcement(notice).post()
        self.noticeTask.task?.cancel()
        self.noticeTask.task = Task { [weak self] in
            try? await Task.sleep(for: Theme.Scanning.noticeDuration)
            guard !Task.isCancelled else {
                return
            }
            self?.notice = nil
        }
    }

    // Runs a write; a refusal (a returned reason) or a failure is kept in
    // `failureMessage`.
    private func write(_ operation: () async throws -> String?) async -> Bool {
        do {
            if let refusal = try await operation() {
                self.failureMessage = refusal
                return false
            }
            return true
        } catch {
            self.failureMessage = String(localized: "保存できませんでした")
            return false
        }
    }

    deinit {
        self.observationTask.task?.cancel()
        self.progressTask.task?.cancel()
        self.noticeTask.task?.cancel()
    }
}
