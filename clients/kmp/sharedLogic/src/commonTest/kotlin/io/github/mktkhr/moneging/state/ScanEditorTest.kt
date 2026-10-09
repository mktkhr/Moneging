package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.data.InMemoryPreferences
import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.scan.FixtureReceipt
import io.github.mktkhr.moneging.scan.FixtureReceiptScanner
import io.github.mktkhr.moneging.scan.OnDeviceLlm
import io.github.mktkhr.moneging.scan.ReadingMethod
import io.github.mktkhr.moneging.scan.ReceiptItem
import io.github.mktkhr.moneging.scan.ReceiptReading
import io.github.mktkhr.moneging.scan.ReceiptScanner
import io.github.mktkhr.moneging.scan.ReceiptStructuring
import io.github.mktkhr.moneging.scan.RuleBasedReceiptParser
import io.github.mktkhr.moneging.scan.ScannedValue
import io.github.mktkhr.moneging.scan.TextRecognizingReceiptScanner
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.time.Clock
import kotlin.time.Instant
import kotlin.uuid.Uuid

private const val SURE = 0.9
private const val UNSURE = 0.4
private const val RICE_BALL = 380L
private const val TOTAL = 380L
private val RECEIPT = byteArrayOf(1, 2, 3)
private val UNKNOWN_PICTURE = byteArrayOf(9, 9, 9)
private const val JPEG = "image/jpeg"

private object NoonClock : Clock {
    override fun now(): Instant = Instant.parse("2026-02-15T03:00:00Z")
}

/**
 * [ScanEditor] keeps photos and starts their scans, and [ScanData] shows the
 * scans of the ledger in view: in flight, waiting as drafts, or failed until
 * read again or recorded by hand.
 */
class ScanEditorTest {
    private val store =
        LocalStore.inMemory(
            clock = NoonClock,
            deviceId = "test-device",
            scanner =
                FixtureReceiptScanner(
                    receipts = listOf(FixtureReceipt(image = RECEIPT, reading = sevenElevenReading())),
                ),
        )
    private val appState = AppState(store = store, preferences = InMemoryPreferences(), clock = NoonClock)
    private val scanData = ScanData(store = store, appState = appState)
    private val editor = ScanEditor(store = store, appState = appState, clock = NoonClock)

    /** Stops the holders the test started. */
    @AfterTest
    fun tearDown() {
        scanData.close()
        appState.close()
    }

    /** Two photos are accepted at once, and read into drafts home counts as waiting. */
    @Test
    fun acceptedPhotosWait(): TestResult =
        runTest {
            ledgerInView()

            val accepted = editor.acceptPhotos(images = listOf(RECEIPT, RECEIPT), contentType = JPEG)

            assertEquals(expected = "2枚の読み取りを受け付けました", actual = accepted.noticeText)
            val shown = scanData.uiState.first { it.waitingCount == 2 }
            assertEquals(expected = "確認待ち 2件", actual = shown.statusText)
            assertEquals(expected = "セブン-イレブン 380円、2月14日", actual = shown.waiting.first().accessibilityLabel)
        }

    /** A draft opens with the scanner's values and confidences, and its confirmed form is recorded. */
    @Test
    fun draftIsOpenedAndConfirmed(): TestResult =
        runTest {
            val ledgerId = ledgerInView()
            editor.acceptPhotos(images = listOf(RECEIPT), contentType = JPEG)
            val row =
                scanData.uiState
                    .first { it.waitingCount == 1 }
                    .waiting
                    .single()

            val editing = assertNotNull(editor.openDraft(draftId = row.id))
            assertTrue(isReviewNeeded(editing.form.totalConfidence))
            assertEquals(
                expected = "380",
                actual =
                    editing.form.items
                        .single()
                        .amountText,
            )

            val confirmed = editing.form.copy(store = "セブンイレブン 新宿店", totalConfidence = 1.0)
            assertNull(editor.confirmDraft(draftId = row.id, form = confirmed, acceptMismatch = false))

            val transaction = store.ledger(ledgerId).transactions(YearMonth(year = 2026, month = 2)).single()
            assertEquals(expected = "セブンイレブン 新宿店", actual = transaction.storeName)
            assertEquals(expected = row.photoId, actual = transaction.photoId?.toString())
            assertEquals(expected = null, actual = scanData.uiState.first { it.waitingCount == 0 }.statusText)
        }

    /** A form whose items do not add up is refused, and recorded marked 要確認 only when the mismatch is accepted. */
    @Test
    fun mismatchNeedsAccepting(): TestResult =
        runTest {
            val ledgerId = ledgerInView()
            editor.acceptPhotos(images = listOf(RECEIPT), contentType = JPEG)
            val draftId =
                scanData.uiState
                    .first { it.waitingCount == 1 }
                    .waiting
                    .single()
                    .id
            val form = assertNotNull(editor.openDraft(draftId = draftId)).form.copy(totalText = "500")

            assertNotNull(editor.confirmDraft(draftId = draftId, form = form, acceptMismatch = false))
            assertNull(editor.confirmDraft(draftId = draftId, form = form, acceptMismatch = true))

            val transaction = store.ledger(ledgerId).transactions(YearMonth(year = 2026, month = 2)).single()
            assertEquals(expected = 500L, actual = transaction.amount)
            assertEquals(expected = listOf("おにぎり", "差額"), actual = transaction.items.map { it.name })
            assertTrue(transaction.isReviewNeeded)
            val row = LedgerUiState.EMPTY.transactionRow(transaction)
            assertTrue(row.isMarkedForReview)
            assertTrue(row.accessibilityLabel.endsWith("、要確認"), row.accessibilityLabel)
        }

    /** A draft whose item is in a category archived after the scan is refused until another is chosen. */
    @Test
    fun archivedCategoryIsRefused(): TestResult =
        runTest {
            val ledgerId = ledgerInView()
            editor.acceptPhotos(images = listOf(RECEIPT), contentType = JPEG)
            val draftId =
                scanData.uiState
                    .first { it.waitingCount == 1 }
                    .waiting
                    .single()
                    .id
            val scope = store.ledger(ledgerId)
            scope.archiveCategory(categoryId = scope.categories().first { it.name == "食費" }.id)
            val form = assertNotNull(editor.openDraft(draftId = draftId)).form

            assertEquals(
                expected = "アーカイブ済みのカテゴリには記録できません",
                actual = editor.confirmDraft(draftId = draftId, form = form, acceptMismatch = false),
            )
            assertTrue(scope.transactions(YearMonth(year = 2026, month = 2)).isEmpty())

            val chosen = form.copy(items = form.items.map { it.copy(categoryId = null) })
            assertNull(editor.confirmDraft(draftId = draftId, form = chosen, acceptMismatch = false))
            val transaction = scope.transactions(YearMonth(year = 2026, month = 2)).single()
            val category = transaction.items.single().categoryId
            assertEquals(expected = "その他", actual = scope.categories().single { it.id == category }.name)
        }

    /** A failed scan is listed with its reason until its photo is read again. */
    @Test
    fun failedScanIsListed(): TestResult =
        runTest {
            ledgerInView()
            editor.acceptPhotos(images = listOf(UNKNOWN_PICTURE), contentType = JPEG)
            val failed =
                scanData.uiState
                    .first { it.failed.isNotEmpty() }
                    .failed
                    .single()
            assertEquals(expected = "このレシートは読み取れませんでした", actual = failed.failureReason)

            assertNull(editor.readAgain(jobId = failed.id))

            val again = scanData.uiState.first { state -> state.failed.none { it.id == failed.id } }
            assertTrue(again.failed.size + again.inFlightCount == 1)
        }

    /** A scan read by the device's AI that failed may be read without AI, and its draft says so. */
    @Test
    fun failedAiScanIsReadWithoutAi(): TestResult =
        runTest {
            val aiStore = LocalStore.inMemory(clock = NoonClock, deviceId = "test-device", scanner = FailingAiScanner)
            val aiState = AppState(store = aiStore, preferences = InMemoryPreferences(), clock = NoonClock)
            val aiData = ScanData(store = aiStore, appState = aiState)
            val aiEditor = ScanEditor(store = aiStore, appState = aiState, clock = NoonClock)
            val ledger = aiStore.createLedger("家計")
            aiState.uiState.first { state -> state.ledgers.any { it.id == ledger.id } }
            aiState.onIntent(AppIntent.SelectLedger(ledgerId = ledger.id.toString()))

            aiEditor.acceptPhotos(images = listOf(RECEIPT), contentType = JPEG, method = ReadingMethod.DEVICE_AI)
            val failed =
                aiData.uiState
                    .first { it.failed.isNotEmpty() }
                    .failed
                    .single()
            assertEquals(expected = "組み立てられませんでした", actual = failed.failureReason)
            assertTrue(failed.isReadByDeviceAi)

            assertNull(aiEditor.readWithoutAi(jobId = failed.id))

            val draft =
                aiData.uiState
                    .first { it.waiting.isNotEmpty() }
                    .waiting
                    .single()
            assertEquals(
                expected = "AI を使わずに読み取りました",
                actual = assertNotNull(aiEditor.openDraft(draftId = draft.id)).methodText,
            )
            aiData.close()
            aiState.close()
        }

    /** The text recognised from a photo is kept for its draft, and for a scan that then failed. */
    @Test
    fun recognizedTextIsKept(): TestResult =
        runTest {
            val textStore =
                LocalStore.inMemory(
                    clock = NoonClock,
                    deviceId = TEXT_DEVICE,
                    scanner = recognizingScanner(),
                )
            val textState = AppState(store = textStore, preferences = InMemoryPreferences(), clock = NoonClock)
            val textData = ScanData(store = textStore, appState = textState)
            val textEditor = ScanEditor(store = textStore, appState = textState, clock = NoonClock)
            val ledger = textStore.createLedger("家計")
            textState.uiState.first { state -> state.ledgers.any { it.id == ledger.id } }
            textState.onIntent(AppIntent.SelectLedger(ledgerId = ledger.id.toString()))

            textEditor.acceptPhotos(images = listOf(RECEIPT), contentType = JPEG, method = ReadingMethod.NO_AI)
            val draft =
                textData.uiState
                    .first { it.waiting.isNotEmpty() }
                    .waiting
                    .single()
            assertEquals(expected = RECOGNIZED, actual = textEditor.recognizedText(scanId = draft.id))

            textEditor.acceptPhotos(images = listOf(RECEIPT), contentType = JPEG, method = ReadingMethod.DEVICE_AI)
            val failed =
                textData.uiState
                    .first { it.failed.isNotEmpty() }
                    .failed
                    .single()
            assertEquals(expected = RECOGNIZED, actual = textEditor.recognizedText(scanId = failed.id))
            textData.close()
            textState.close()
        }

    /** The progress outside the app counts every ledger's scans, whatever ledger is in view. */
    @Test
    fun progressCountsEveryLedger(): TestResult =
        runTest {
            ledgerInView()
            editor.acceptPhotos(images = listOf(RECEIPT), contentType = JPEG)
            val other = store.createLedger("旅行")
            appState.uiState.first { state -> state.ledgers.any { it.id == other.id } }
            appState.onIntent(AppIntent.SelectLedger(ledgerId = other.id.toString()))
            editor.acceptPhotos(images = listOf(RECEIPT), contentType = JPEG)

            val progress = scanData.progress.first { it.waiting == 2 }

            assertEquals(expected = 0, actual = progress.inFlight)
            assertEquals(expected = ScanProgress.NONE.copy(waiting = 2), actual = progress)
            assertEquals(
                expected = "2つの家計簿",
                actual = ScanProgress.NONE.copy(ledgerNames = listOf("家計", "旅行")).ledgerLabel,
            )
            assertEquals(expected = "家計", actual = ScanProgress.NONE.copy(ledgerNames = listOf("家計")).ledgerLabel)
        }

    private suspend fun ledgerInView(): Uuid {
        val ledger = store.createLedger("家計")
        appState.uiState.first { state -> state.ledgers.any { it.id == ledger.id } }
        appState.onIntent(AppIntent.SelectLedger(ledgerId = ledger.id.toString()))
        return ledger.id
    }
}

internal fun sevenElevenReading(): ReceiptReading =
    ReceiptReading(
        store = ScannedValue(value = "セブン-イレブン", confidence = SURE),
        date = ScannedValue(value = LocalDate(year = 2026, month = 2, day = 14), confidence = SURE),
        total = ScannedValue(value = TOTAL, confidence = UNSURE),
        items = listOf(ReceiptItem(name = "おにぎり", amount = RICE_BALL, category = "食費", confidence = SURE)),
    )

private const val TEXT_DEVICE = "text-device"
private val RECOGNIZED =
    listOf("セブン-イレブン", "2026年2月14日", "おにぎり ¥380", "合計 ¥380").joinToString(separator = "\n")

// Recognises [RECOGNIZED] from any photo; the device has no AI.
internal fun recognizingScanner(): ReceiptScanner =
    TextRecognizingReceiptScanner(
        recognizer = { RECOGNIZED },
        structuring = ReceiptStructuring(llm = NoAi, ruleBased = RuleBasedReceiptParser()),
    )

private object NoAi : OnDeviceLlm {
    override val isAvailable: Boolean = false

    override suspend fun structure(text: String): ReceiptReading = error("この端末の AI が使えません")
}

// Fails every scan by the device's AI; reads the fixture receipt without AI.
private object FailingAiScanner : ReceiptScanner {
    override suspend fun read(
        image: ByteArray,
        method: ReadingMethod,
    ): ReceiptReading {
        check(method == ReadingMethod.NO_AI) { "組み立てられませんでした" }
        return sevenElevenReading()
    }
}
