package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.scan.ScanState
import kotlinx.coroutines.flow.takeWhile
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.TimeSource

private val SCAN_DURATION = 200.milliseconds
private val START_DEADLINE = 100.milliseconds

/**
 * AC-B-503 — Starting a scan returns immediately with a job that completes
 * later.
 *
 * Given the fixture scanner set to take 200 ms. When a scan of
 * `seven-eleven.jpg` is started, then the call returns within 100 ms with a
 * job in state `queued`. When the job is observed, then it reaches
 * `succeeded` without ever moving back a state, and its draft id is set.
 */
class TestScanIsAsynchronous {
    /** The start returns at once with a queued job; the job then only moves on, to succeeded, with a draft. */
    @Test
    fun startReturnsAtOnceAndJobCompletesLater(): TestResult =
        runTest {
            val scope = scanningLedger(scanner = fixtureScanner(duration = SCAN_DURATION)).scope
            val photo = scope.addReceiptPhoto(name = SEVEN_ELEVEN)

            val startedAt = TimeSource.Monotonic.markNow()
            val started = scope.startScan(photoId = photo.id)
            val took = startedAt.elapsedNow()

            assertTrue(actual = took < START_DEADLINE, message = "スキャンの開始が 100ms 以内に戻らない: $took")
            assertEquals(expected = ScanState.QUEUED, actual = started.state, message = "開始直後のジョブが queued でない")
            assertEquals(expected = photo.id, actual = started.photoId, message = "ジョブが送った写真のものでない")

            val observed = scope.observeScanJob(jobId = started.id).takeWhile { job -> !job.state.isFinished }.toList()
            val finished = assertNotNull(actual = scope.findScanJob(id = started.id), message = "ジョブが読めない")
            val states = observed.map { job -> job.state } + finished.state
            assertEquals(expected = ScanState.SUCCEEDED, actual = finished.state, message = "ジョブが succeeded にならない")
            assertEquals(
                expected = states.sortedBy { state -> state.ordinal },
                actual = states,
                message = "ジョブの状態が前に戻った: $states",
            )
            val draftId = assertNotNull(actual = finished.draftId, message = "succeeded のジョブに下書きの id がない")
            assertNotNull(actual = scope.findDraft(id = draftId), message = "ジョブの下書きが読めない")
        }
}
