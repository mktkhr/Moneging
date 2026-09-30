package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewTransaction
import io.github.mktkhr.moneging.scan.ScanState
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

private const val FAILURE_REASON = "provider unavailable"
private const val MANUAL_AMOUNT = 1_180L

/**
 * AC-B-506 — A failed scan leaves a reason, and the photo stays usable by
 * hand.
 *
 * Given the fixture scanner set to fail with the reason
 * `provider unavailable`. When a scan is started and completes, then the job
 * is `failed` with that reason and no draft, the failed jobs list it, the
 * photo is still listed, and a transaction may still be created by hand
 * linking to that photo.
 */
class TestScanFailureIsRecoverable {
    /** The job fails with the scanner's reason and no draft; the photo is kept and can be linked by hand. */
    @Test
    fun failedScanLeavesReasonAndPhoto(): TestResult =
        runTest {
            val scope = scanningLedger(scanner = fixtureScanner(failure = FAILURE_REASON)).scope
            val photo = scope.addReceiptPhoto(name = SEVEN_ELEVEN)

            val job = scope.scanUntilFinished(photo = photo)

            assertEquals(expected = ScanState.FAILED, actual = job.state, message = "スキャンが failed にならない")
            assertEquals(
                expected = FAILURE_REASON,
                actual = job.failureReason,
                message = "失敗の理由が provider unavailable でない",
            )
            assertNull(actual = job.draftId, message = "失敗したジョブに下書きがある")
            assertTrue(actual = scope.waitingDrafts().isEmpty(), message = "失敗したのに確認待ちの下書きがある")
            assertEquals(
                expected = listOf(job.id),
                actual = scope.scanJobs(state = ScanState.FAILED).map { failed -> failed.id },
                message = "失敗したジョブの一覧が今回のジョブ 1 件でない",
            )
            assertEquals(expected = listOf(photo), actual = scope.photos(), message = "失敗しても写真の一覧が変わった")

            val recorded =
                scope.recordTransaction(
                    transaction =
                        NewTransaction(
                            date = LocalDate.parse("2026-02-14"),
                            direction = Direction.EXPENSE,
                            amount = MANUAL_AMOUNT,
                            categoryId = scope.categoryIdNamed(name = "食費"),
                            photoId = photo.id,
                        ),
                )
            assertEquals(expected = photo.id, actual = recorded.photoId, message = "手で作った取引が写真に結び付かない")
            assertEquals(expected = MANUAL_AMOUNT, actual = recorded.amount, message = "手で作った取引が 1,180円 でない")
        }
}
