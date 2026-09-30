package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.scan.ReceiptReading
import io.github.mktkhr.moneging.scan.RuleBasedReceiptParser
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals

private const val SEVEN_ELEVEN_TOTAL = 1_180L
private const val RICE_BALL = 380L
private const val BENTO = 800L
private const val CORNER_DELI_TOTAL = 980L
private const val FRIED_CHICKEN_BENTO = 680L
private const val GREEN_TEA = 150L

/**
 * AC-B-510 — The rule-based parser reads recorded receipt text into drafts,
 * deterministically.
 *
 * Given the recorded texts `seven-eleven.txt` and `corner-deli.txt`. When each
 * is parsed by the rule-based parser, then the draft equals the one recorded
 * beside it, every field, item and confidence included; for
 * `seven-eleven.txt` that draft has store `セブン-イレブン`, date 2026-02-14,
 * total 1,180 and the items おにぎり 380 and 弁当 800. When each is parsed
 * again, then the draft is identical to the first.
 */
class TestRuleBasedReceiptParser {
    /** Each recorded text parses into the draft recorded beside it, and parses again into the same. */
    @Test
    fun recordedTextsParseIntoTheRecordedDrafts() {
        val parser = RuleBasedReceiptParser()
        val sevenEleven = parser.parse(text = recordedText(name = SEVEN_ELEVEN))
        val cornerDeli = parser.parse(text = recordedText(name = CORNER_DELI))

        assertEquals(expected = "セブン-イレブン", actual = sevenEleven.store.value, message = "店名が セブン-イレブン でない")
        assertEquals(
            expected = LocalDate.parse("2026-02-14"),
            actual = sevenEleven.date.value,
            message = "日付が 2026-02-14 でない",
        )
        assertEquals(expected = SEVEN_ELEVEN_TOTAL, actual = sevenEleven.total.value, message = "合計が 1,180円 でない")
        assertEquals(
            expected = listOf("おにぎり" to RICE_BALL, "弁当" to BENTO),
            actual = sevenEleven.items.map { item -> item.name to item.amount },
            message = "明細が おにぎり 380円 と 弁当 800円 でない",
        )
        assertEquals(
            expected = ruleBasedDraft(name = SEVEN_ELEVEN),
            actual = sevenEleven,
            message = "seven-eleven.txt の解析結果が seven-eleven.rule.json と違う",
        )

        assertEquals(expected = "コーナーデリ", actual = cornerDeli.store.value, message = "店名が コーナーデリ でない")
        assertEquals(
            expected = LocalDate.parse("2026-02-13"),
            actual = cornerDeli.date.value,
            message = "日付が 2026-02-13 でない",
        )
        assertEquals(expected = CORNER_DELI_TOTAL, actual = cornerDeli.total.value, message = "合計が 980円 でない")
        assertEquals(
            expected = listOf("唐揚げ弁当" to FRIED_CHICKEN_BENTO, "緑茶" to GREEN_TEA),
            actual = cornerDeli.items.map { item -> item.name to item.amount },
            message = "明細が 唐揚げ弁当 680円 と 緑茶 150円 でない（+ LARGE RICE は品目でない）",
        )
        assertEquals(
            expected = ruleBasedDraft(name = CORNER_DELI),
            actual = cornerDeli,
            message = "corner-deli.txt の解析結果が corner-deli.rule.json と違う",
        )

        assertParsesTheSameAgain(parser = parser, name = SEVEN_ELEVEN, first = sevenEleven)
        assertParsesTheSameAgain(parser = parser, name = CORNER_DELI, first = cornerDeli)
    }
}

// Parsing the text of [name] once more gives [first] again.
private fun assertParsesTheSameAgain(
    parser: RuleBasedReceiptParser,
    name: String,
    first: ReceiptReading,
) {
    assertEquals(
        expected = first,
        actual = parser.parse(text = recordedText(name = name)),
        message = "$name をもう一度解析すると結果が変わる",
    )
}
