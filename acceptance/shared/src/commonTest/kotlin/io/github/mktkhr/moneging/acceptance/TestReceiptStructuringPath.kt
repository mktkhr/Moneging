package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.scan.OnDeviceLlm
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

/**
 * AC-B-511 — Recognised text is structured by the on-device LLM when there is
 * one, else by the rule-based parser.
 *
 * Given the recorded text `seven-eleven.txt` and a fake on-device LLM
 * answering `seven-eleven.llm.json`. When the text is structured, then the
 * draft is the fake's answer and the rule-based parser is not used. Given the
 * fake reporting that the device has no on-device LLM, when the same text is
 * structured, then the draft is the rule-based parser's, equal to
 * `seven-eleven.rule.json`, and the job's result has the same shape either
 * way.
 */
class TestReceiptStructuringPath {
    /** With an LLM the draft is its answer and the parser stays unused; without one it is the parser's. */
    @Test
    fun llmWhenThereIsOneElseRuleBasedParser(): TestResult = runTest { assertBothPaths() }

    private suspend fun assertBothPaths() {
        val text = recordedText(name = SEVEN_ELEVEN)
        val withLlmParser = CountingParser()
        val llm = FakeOnDeviceLlm(answer = llmDraft(name = SEVEN_ELEVEN))
        val viaLlm = ReceiptStructuring(llm = llm, ruleBased = withLlmParser).structure(text = text)

        assertEquals(expected = llmDraft(name = SEVEN_ELEVEN), actual = viaLlm, message = "LLM があるのに下書きが LLM の答えでない")
        assertEquals(expected = listOf(text), actual = llm.requests, message = "LLM に読み取った文字が渡っていない")
        assertEquals(expected = 0, actual = withLlmParser.calls, message = "LLM があるのにルールベースの解析を使った")

        val withoutLlmParser = CountingParser()
        val noLlm = FakeOnDeviceLlm(answer = null)
        val viaRules = ReceiptStructuring(llm = noLlm, ruleBased = withoutLlmParser).structure(text = text)

        assertEquals(
            expected = ruleBasedDraft(name = SEVEN_ELEVEN),
            actual = viaRules,
            message = "LLM がないのに下書きが seven-eleven.rule.json と違う",
        )
        assertEquals(expected = 1, actual = withoutLlmParser.calls, message = "LLM がないのにルールベースの解析を 1 度使っていない")
        assertEquals(expected = emptyList<String>(), actual = noLlm.requests, message = "LLM がないのに LLM に構造化を頼んだ")

        assertSameJobShape(text = text)
    }

    // The job's draft has the same store, date, total and items (names and amounts) either way.
    private suspend fun assertSameJobShape(text: String) {
        val viaLlm =
            draftShape(scope = scannedScope(llm = FakeOnDeviceLlm(answer = llmDraft(name = SEVEN_ELEVEN)), text = text))
        val viaRules = draftShape(scope = scannedScope(llm = FakeOnDeviceLlm(answer = null), text = text))
        assertEquals(expected = viaLlm, actual = viaRules, message = "ジョブの結果の形が LLM の有無で違う")
        assertEquals(
            expected = listOf("セブン-イレブン", "2026-02-14", "1180", "おにぎり:380", "弁当:800"),
            actual = viaRules,
            message = "ジョブの下書きが セブン-イレブン 2026-02-14 1,180円 おにぎり 380円 弁当 800円 でない",
        )
    }

    private suspend fun scannedScope(
        llm: OnDeviceLlm,
        text: String,
    ): LedgerScope {
        val scanner =
            TextRecognizingReceiptScanner(
                recognizer = { text },
                structuring = ReceiptStructuring(llm = llm, ruleBased = RuleBasedReceiptParser()),
            )
        val scope = scanningLedger(scanner = scanner).scope
        val job = scope.scanUntilFinished(photo = scope.addReceiptPhoto(name = SEVEN_ELEVEN))
        assertEquals(
            expected = ScanState.SUCCEEDED,
            actual = job.state,
            message = "スキャンが succeeded にならない: ${job.failureReason}",
        )
        return scope
    }

    private suspend fun draftShape(scope: LedgerScope): List<String> {
        val draft = assertNotNull(actual = scope.waitingDrafts().singleOrNull(), message = "確認待ちの下書きが 1 件でない")
        return listOf(draft.store.value, draft.date.value.toString(), draft.total.value.toString()) +
            draft.items.map { item -> "${item.name}:${item.amount}" }
    }
}

// An on-device LLM that answers [answer], or reports that the device has none when it is null.
private class FakeOnDeviceLlm(
    private val answer: ReceiptReading?,
) : OnDeviceLlm {
    // The texts it was asked to structure.
    val requests: MutableList<String> = mutableListOf()

    override val isAvailable: Boolean
        get() = answer != null

    override suspend fun structure(text: String): ReceiptReading {
        requests += text
        return checkNotNull(answer) { "この端末に端末内 LLM はない" }
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
