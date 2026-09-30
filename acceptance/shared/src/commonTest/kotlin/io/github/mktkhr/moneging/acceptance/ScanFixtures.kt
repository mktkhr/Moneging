package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.domain.Photo
import io.github.mktkhr.moneging.scan.FixtureReceipt
import io.github.mktkhr.moneging.scan.FixtureReceiptScanner
import io.github.mktkhr.moneging.scan.ReceiptReading
import io.github.mktkhr.moneging.scan.ReceiptScanner
import io.github.mktkhr.moneging.scan.ScanJob
import io.github.mktkhr.moneging.scan.ScanState
import kotlinx.coroutines.flow.first
import kotlin.time.Duration

// Fixtures shared by the Photos and scanning criteria (AC-B-501 to AC-B-511):
// the receipts of acceptance/fixtures and a ledger whose scanner reads them.

/** The fixture receipt whose items add up (`seven-eleven.jpg`). */
internal const val SEVEN_ELEVEN = "seven-eleven"

/** The fixture receipt whose items do not add up (`corner-deli.jpg`). */
internal const val CORNER_DELI = "corner-deli"

/** The content type of the fixture pictures. */
internal const val JPEG = "image/jpeg"

/** The picture of the fixture receipt [name]. */
internal fun receiptImage(name: String): ByteArray = readFixtureFile(relativePath = "receipts/$name.jpg")

/** The draft the fixture scanner answers for the receipt [name] (`receipts/<name>.json`). */
internal fun receiptDraft(name: String): ReceiptReading =
    ReceiptReading.fromJson(json = readFixtureText(relativePath = "receipts/$name.json"))

/** The text recognised from the receipt [name] (`receipt-text/<name>.txt`). */
internal fun recordedText(name: String): String = readFixtureText(relativePath = "receipt-text/$name.txt")

/** The draft the rule-based parser must produce from [recordedText] of [name] (`<name>.rule.json`). */
internal fun ruleBasedDraft(name: String): ReceiptReading =
    ReceiptReading.fromJson(json = readFixtureText(relativePath = "receipt-text/$name.rule.json"))

/** What the fake on-device LLM answers for [name] (`<name>.llm.json`). */
internal fun llmDraft(name: String): ReceiptReading =
    ReceiptReading.fromJson(json = readFixtureText(relativePath = "receipt-text/$name.llm.json"))

/**
 * The fixture scanner: it answers the draft beside each fixture picture, none for any other picture
 * (that scan fails). It takes [duration]; with [failure] it fails with that reason instead.
 */
internal fun fixtureScanner(
    duration: Duration = Duration.ZERO,
    failure: String? = null,
): FixtureReceiptScanner =
    FixtureReceiptScanner(
        receipts =
            listOf(SEVEN_ELEVEN, CORNER_DELI).map { name ->
                FixtureReceipt(image = receiptImage(name = name), reading = receiptDraft(name = name))
            },
        duration = duration,
        failure = failure,
    )

/** A store on the fixtures' clock and device `D` reading with [scanner], the ledger `家計` and its scope. */
internal class ScanningLedger(
    /** The store, whose photo storage the tests look into. */
    val store: LocalStore,
    /** The scope of the ledger `家計`. */
    val scope: LedgerScope,
)

/** A store reading with [scanner] and holding only the ledger `家計`. */
internal suspend fun scanningLedger(scanner: ReceiptScanner = fixtureScanner()): ScanningLedger {
    val store =
        LocalStore.inMemory(
            clock = ManualClock(current = FIXTURE_NOON),
            deviceId = FIXTURE_DEVICE_ID,
            scanner = scanner,
        )
    val ledger = store.createLedger(name = FIXTURE_LEDGER_NAME)
    return ScanningLedger(store = store, scope = store.ledger(id = ledger.id))
}

/** Keeps the picture of the fixture receipt [name] as a photo captured at the fixtures' noon. */
internal suspend fun LedgerScope.addReceiptPhoto(name: String): Photo =
    addPhoto(bytes = receiptImage(name = name), contentType = JPEG, capturedAt = FIXTURE_NOON)

/** Starts the scan of [photo] and waits until its job has succeeded or failed. */
internal suspend fun LedgerScope.scanUntilFinished(photo: Photo): ScanJob {
    val started = startScan(photoId = photo.id)
    return observeScanJob(jobId = started.id).first { job -> job.state.isFinished }
}

/** Whether the job can no longer move. */
internal val ScanState.isFinished: Boolean
    get() = this == ScanState.SUCCEEDED || this == ScanState.FAILED
