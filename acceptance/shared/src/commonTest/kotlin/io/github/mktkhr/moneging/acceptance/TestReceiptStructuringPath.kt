package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.scan.Draft
import io.github.mktkhr.moneging.scan.OnDeviceLlm
import io.github.mktkhr.moneging.scan.ReadingMethod
import io.github.mktkhr.moneging.scan.ReadingMethods
import io.github.mktkhr.moneging.scan.ReceiptReading
import io.github.mktkhr.moneging.scan.ReceiptStructuring
import io.github.mktkhr.moneging.scan.ReceiptTextParser
import io.github.mktkhr.moneging.scan.RuleBasedReceiptParser
import io.github.mktkhr.moneging.scan.ScanState
import io.github.mktkhr.moneging.scan.TextRecognizingReceiptScanner
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

private const val GENERATION_FAILED = "generation failed"

/**
 * AC-B-511 — Recognised text is structured by the reading method the user
 * chose, never falling back on its own.
 *
 * Given the recorded text `seven-eleven.txt` and a fake device AI answering
 * `seven-eleven.llm.json`. With the reading method set to the device's AI,
 * when the text is structured, then the draft is the fake's answer, the
 * rule-based parser is not used, and the draft records the AI as its method.
 * With the method set to `AI を使わない`, then the draft is the rule-based
 * parser's, equal to `seven-eleven.rule.json`, the fake is not asked, and the
 * draft records that method. With the device's AI chosen and the fake failing
 * with the reason `generation failed`, when a scan of `seven-eleven.jpg`
 * completes, then the job is `failed` with that reason and no draft; when it
 * is read again without AI, then its draft equals `seven-eleven.rule.json`. A
 * user who never chose has the device's AI when the fake reports one, and
 * `AI を使わない` when it reports none. The job's result has the same shape
 * whichever method made it.
 */
class TestReceiptStructuringPath {
    /** The chosen method structures the text; a failing AI fails the scan and nothing falls back. */
    @Test
    fun chosenMethodNeverFallsBack(): TestResult =
        runTest {
            val text = recordedText(name = SEVEN_ELEVEN)
            assertDeviceAiChosen(text = text)
            assertNoAiChosen(text = text)
            assertFailingAiFailsTheScan(text = text)
            assertMethodOfWhoNeverChose()
            assertSameJobShape(text = text)
        }

    private suspend fun assertDeviceAiChosen(text: String) {
        val parser = CountingParser()
        val llm = FakeOnDeviceLlm(answer = llmDraft(name = SEVEN_ELEVEN))
        val structuring = ReceiptStructuring(llm = llm, ruleBased = parser)
        val reading = structuring.structure(text = text, method = ReadingMethod.DEVICE_AI)

        assertEquals(expected = llmDraft(name = SEVEN_ELEVEN), actual = reading, message = "AI を選んだのに下書きが AI の答えでない")
        assertEquals(expected = listOf(text), actual = llm.requests, message = "AI に読み取った文字が渡っていない")
        assertEquals(expected = 0, actual = parser.calls, message = "AI を選んだのにルールベースの解析を使った")

        val scope = scannedScope(llm = llm, text = text, method = ReadingMethod.DEVICE_AI)
        assertEquals(
            expected = ReadingMethod.DEVICE_AI,
            actual = singleDraft(scope = scope).method,
            message = "AI で読んだ下書きが、方法として端末の AI を持たない",
        )
    }

    private suspend fun assertNoAiChosen(text: String) {
        val parser = CountingParser()
        val llm = FakeOnDeviceLlm(answer = llmDraft(name = SEVEN_ELEVEN))
        val structuring = ReceiptStructuring(llm = llm, ruleBased = parser)
        val reading = structuring.structure(text = text, method = ReadingMethod.NO_AI)

        assertEquals(
            expected = ruleBasedDraft(name = SEVEN_ELEVEN),
            actual = reading,
            message = "AI を使わないのに下書きが seven-eleven.rule.json と違う",
        )
        assertEquals(expected = 1, actual = parser.calls, message = "AI を使わないのにルールベースの解析を 1 度使っていない")
        assertEquals(expected = emptyList<String>(), actual = llm.requests, message = "AI を使わないのに AI に頼んだ")

        val scope = scannedScope(llm = llm, text = text, method = ReadingMethod.NO_AI)
        val draft = singleDraft(scope = scope)
        assertEquals(
            expected = ReadingMethod.NO_AI,
            actual = draft.method,
            message = "AI を使わずに読んだ下書きが、方法として AI を使わないを持たない",
        )
        assertDraftIsRuleBased(draft = draft)
        assertEquals(expected = emptyList<String>(), actual = llm.requests, message = "AI を使わないスキャンで AI に頼んだ")
    }

    private suspend fun assertFailingAiFailsTheScan(text: String) {
        val llm = FakeOnDeviceLlm(answer = llmDraft(name = SEVEN_ELEVEN), failure = GENERATION_FAILED)
        val scope = scanningScope(llm = llm, text = text, method = ReadingMethod.DEVICE_AI)
        val photo = scope.addReceiptPhoto(name = SEVEN_ELEVEN)

        val failed = scope.scanUntilFinished(photo = photo)
        assertEquals(expected = ScanState.FAILED, actual = failed.state, message = "AI が失敗したのにジョブが failed でない")
        assertEquals(expected = GENERATION_FAILED, actual = failed.failureReason, message = "失敗の理由が違う")
        assertNull(actual = failed.draftId, message = "AI が失敗したジョブに下書きがある")
        assertTrue(actual = scope.waitingDrafts().isEmpty(), message = "AI が失敗したのに、自分で切り替えて下書きを作った")

        val reread = scope.scanUntilFinished(photo = photo, method = ReadingMethod.NO_AI)
        assertEquals(expected = ScanState.SUCCEEDED, actual = reread.state, message = "AI を使わずに読み直しても succeeded でない")
        val draft = singleDraft(scope = scope)
        assertEquals(expected = ReadingMethod.NO_AI, actual = draft.method, message = "読み直した下書きの方法が AI を使わないでない")
        assertDraftIsRuleBased(draft = draft)
    }

    private fun assertMethodOfWhoNeverChose() {
        val answer = llmDraft(name = SEVEN_ELEVEN)
        assertEquals(
            expected = ReadingMethod.DEVICE_AI,
            actual = ReadingMethods(llm = FakeOnDeviceLlm(answer = answer)).chosen,
            message = "選んでいない人の方法が、AI があるのに端末の AI でない",
        )
        assertEquals(
            expected = ReadingMethod.NO_AI,
            actual = ReadingMethods(llm = FakeOnDeviceLlm(answer = answer, isAvailable = false)).chosen,
            message = "選んでいない人の方法が、AI がないのに AI を使わないでない",
        )
    }

    // The job's draft has the same store, date, total and items (names and amounts) whichever method made it.
    private suspend fun assertSameJobShape(text: String) {
        val llm = FakeOnDeviceLlm(answer = llmDraft(name = SEVEN_ELEVEN))
        val viaAi = scannedScope(llm = llm, text = text, method = ReadingMethod.DEVICE_AI)
        val viaRules = scannedScope(llm = llm, text = text, method = ReadingMethod.NO_AI)
        val aiShape = shapeOf(draft = singleDraft(scope = viaAi))
        val rulesShape = shapeOf(draft = singleDraft(scope = viaRules))
        assertEquals(expected = aiShape, actual = rulesShape, message = "ジョブの結果の形が方法で違う")
        assertEquals(
            expected = listOf("セブン-イレブン", "2026-02-14", "1180", "おにぎり:380", "弁当:800"),
            actual = rulesShape,
            message = "ジョブの下書きが セブン-イレブン 2026-02-14 1,180円 おにぎり 380円 弁当 800円 でない",
        )
    }

    private suspend fun scannedScope(
        llm: OnDeviceLlm,
        text: String,
        method: ReadingMethod,
    ): LedgerScope {
        val scope = scanningScope(llm = llm, text = text, method = method)
        val job = scope.scanUntilFinished(photo = scope.addReceiptPhoto(name = SEVEN_ELEVEN))
        assertEquals(
            expected = ScanState.SUCCEEDED,
            actual = job.state,
            message = "スキャンが succeeded にならない: ${job.failureReason ?: "理由なし"}",
        )
        return scope
    }

    private suspend fun scanningScope(
        llm: OnDeviceLlm,
        text: String,
        method: ReadingMethod,
    ): LedgerScope {
        val scanner =
            TextRecognizingReceiptScanner(
                recognizer = { text },
                structuring = ReceiptStructuring(llm = llm, ruleBased = RuleBasedReceiptParser()),
            )
        val readingMethods = ReadingMethods(llm = llm)
        readingMethods.choose(method = method)
        return scanningLedger(scanner = scanner, readingMethods = readingMethods).scope
    }

    private suspend fun singleDraft(scope: LedgerScope): Draft =
        assertNotNull(actual = scope.waitingDrafts().singleOrNull(), message = "確認待ちの下書きが 1 件でない")

    private fun shapeOf(draft: Draft): List<String> =
        listOf(draft.store.value, draft.date.value.toString(), draft.total.value.toString()) +
            draft.items.map { item -> "${item.name}:${item.amount}" }

    private fun assertDraftIsRuleBased(draft: Draft) {
        val rules = ruleBasedDraft(name = SEVEN_ELEVEN)
        assertEquals(
            expected =
                listOf(rules.store.value, rules.date.value.toString(), rules.total.value.toString()) +
                    rules.items.map { item -> "${item.name}:${item.amount}" },
            actual = shapeOf(draft = draft),
            message = "下書きが seven-eleven.rule.json と違う",
        )
        assertEquals(
            expected = rules.items.map { item -> item.confidence },
            actual = draft.items.map { item -> item.confidence },
            message = "下書きの明細の確からしさが seven-eleven.rule.json と違う",
        )
    }
}

// A device AI that answers [answer], is [isAvailable] or not, and fails with [failure] when it is given one.
private class FakeOnDeviceLlm(
    private val answer: ReceiptReading,
    override val isAvailable: Boolean = true,
    private val failure: String? = null,
) : OnDeviceLlm {
    // The texts it was asked to structure.
    val requests: MutableList<String> = mutableListOf()

    override suspend fun structure(text: String): ReceiptReading {
        requests += text
        check(failure == null) { failure.orEmpty() }
        return answer
    }
}

// The rule-based parser, counting how often it is used.
private class CountingParser : ReceiptTextParser {
    private val parser = RuleBasedReceiptParser()

    // How many texts it parsed.
    var calls: Int = 0
        private set

    override fun parse(text: String): ReceiptReading {
        calls += 1
        return parser.parse(text = text)
    }
}
