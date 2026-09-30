package io.github.mktkhr.moneging.scan

import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

// More than a Double holds exactly (2^53 + 1): read through a Double it would change.
private const val HUGE_YEN = 9_007_199_254_740_993L
private const val RICE_BALL = 380L
private const val CONFIDENCE = 0.95

/**
 * A draft's JSON is read with its amounts as whole yen straight from their
 * text, never through a floating-point type; and structuring falls back to
 * the rule-based parser when the on-device LLM fails.
 */
class ReceiptReadingTest {
    /** Amounts are read exactly, even beyond what a Double holds; confidences as numbers. */
    @Test
    fun amountsAreReadAsWholeYen() {
        val reading = ReceiptReading.fromJson(json = draftJson(total = HUGE_YEN.toString(), amount = "380"))

        assertEquals(expected = HUGE_YEN, actual = reading.total.value)
        assertEquals(expected = RICE_BALL, actual = reading.items.single().amount)
        assertEquals(expected = CONFIDENCE, actual = reading.store.confidence)
    }

    /** An amount that is not whole yen is refused, whatever its spelling. */
    @Test
    fun fractionalAmountsAreRefused() {
        listOf("1180.5", "1180.0", "1.18e3").forEach { total ->
            assertFailsWith<IllegalArgumentException>(message = total) {
                ReceiptReading.fromJson(json = draftJson(total = total, amount = "380"))
            }
        }
        assertFailsWith<IllegalArgumentException> {
            ReceiptReading.fromJson(json = draftJson(total = "1180", amount = "380.5"))
        }
    }

    /** When the on-device LLM fails, the rule-based parser reads the text instead. */
    @Test
    fun failingLlmFallsBackToRules(): TestResult =
        runTest {
            val text = listOf("セブン-イレブン", "2026/02/14", "おにぎり ¥380", "合計 ¥380").joinToString(separator = "\n")
            val failing =
                object : OnDeviceLlm {
                    override val isAvailable: Boolean = true

                    override suspend fun structure(text: String): ReceiptReading = error("ガードレールで止まった")
                }

            val reading = ReceiptStructuring(llm = failing, ruleBased = RuleBasedReceiptParser()).structure(text = text)

            assertEquals(expected = RuleBasedReceiptParser().parse(text = text), actual = reading)
        }
}

internal fun draftJson(
    total: String,
    amount: String,
): String =
    """{"store": {"value": "セブン-イレブン", "confidence": 0.95}, """ +
        """"date": {"value": "2026-02-14", "confidence": 0.9}, """ +
        """"total": {"value": $total, "confidence": 0.4}, """ +
        """"items": [{"name": "おにぎり", "amount": $amount, "category": "食費", "confidence": 0.9}]}"""
