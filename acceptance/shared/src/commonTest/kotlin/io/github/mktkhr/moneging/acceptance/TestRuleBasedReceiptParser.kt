package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.scan.ReceiptReading
import io.github.mktkhr.moneging.scan.RuleBasedReceiptParser
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals

private const val SEVEN_ELEVEN_TOTAL = 1_180L
private const val RICE_BALL = 380L
private const val BENTO = 800L

private const val MARUETSU_PETIT = "maruetsu-petit"
private const val SEVEN_ELEVEN_SHIBA = "seven-eleven-shiba"
private const val LIFE = "life"
private const val UBEREATS_GONGCHA = "ubereats-gongcha"
private const val MCDONALDS = "mcdonalds"
private const val MCDONALDS_DEVICE = "mcdonalds-device"
private const val SEVEN_ELEVEN_SHIBA_DEVICE = "seven-eleven-shiba-device"

private const val MARUETSU_PETIT_TOTAL = 5_653L
private const val SEVEN_ELEVEN_SHIBA_TOTAL = 2_309L
private const val LIFE_TOTAL = 5_315L
private const val UBEREATS_GONGCHA_TOTAL = 2_330L
private const val MCDONALDS_TOTAL = 2_420L

/**
 * AC-B-510 — The rule-based parser reads recorded receipt text into drafts,
 * deterministically.
 *
 * Given the recorded texts `seven-eleven.txt` and `corner-deli.txt`, and those
 * recorded from real receipts with what identifies a person or a payment
 * masked (`maruetsu-petit.txt`, `seven-eleven-shiba.txt`, `life.txt`,
 * `ubereats-gongcha.txt`, a fast-food order of sets with a discount on the
 * whole receipt, `mcdonalds.txt`, and the same convenience-store and fast-food
 * receipts read by Vision on the device, `seven-eleven-shiba-device.txt` and
 * `mcdonalds-device.txt`). When each is parsed by the rule-based
 * parser, then the draft equals the one recorded beside it, every field, item
 * and confidence included, and each real receipt's items add up to its total;
 * for `seven-eleven.txt` that draft has store `セブン-イレブン`, date
 * 2026-02-14, total 1,180 and the items おにぎり 380 and 弁当 800. When each is
 * parsed again, then the draft is identical to the first.
 */
class TestRuleBasedReceiptParser {
    private val parser = RuleBasedReceiptParser()

    /** `seven-eleven.txt` reads as セブン-イレブン, 2026-02-14, 1,180: おにぎり 380 and 弁当 800. */
    @Test
    fun sevenElevenReadsItsItems() {
        val sevenEleven = parser.parse(text = recordedText(name = SEVEN_ELEVEN))

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
    }

    /** Each of the nine recorded texts parses into the draft recorded beside it, and parses again into the same. */
    @Test
    fun eachTextParsesIntoItsDraft() {
        val names =
            listOf(
                SEVEN_ELEVEN,
                CORNER_DELI,
                MARUETSU_PETIT,
                SEVEN_ELEVEN_SHIBA,
                LIFE,
                UBEREATS_GONGCHA,
                MCDONALDS,
                SEVEN_ELEVEN_SHIBA_DEVICE,
                MCDONALDS_DEVICE,
            )
        for (name in names) {
            val first = parser.parse(text = recordedText(name = name))
            assertEquals(
                expected = ruleBasedDraft(name = name),
                actual = first,
                message = "$name.txt の解析結果が $name.rule.json と違う",
            )
            assertParsesTheSameAgain(parser = parser, name = name, first = first)
        }
    }

    /** Each real receipt reads its total, and its items, a discount item below zero included, add up to it. */
    @Test
    fun realReceiptsAddUp() {
        val totals =
            listOf(
                MARUETSU_PETIT to MARUETSU_PETIT_TOTAL,
                SEVEN_ELEVEN_SHIBA to SEVEN_ELEVEN_SHIBA_TOTAL,
                LIFE to LIFE_TOTAL,
                UBEREATS_GONGCHA to UBEREATS_GONGCHA_TOTAL,
                MCDONALDS to MCDONALDS_TOTAL,
                SEVEN_ELEVEN_SHIBA_DEVICE to SEVEN_ELEVEN_SHIBA_TOTAL,
                MCDONALDS_DEVICE to MCDONALDS_TOTAL,
            )
        for ((name, total) in totals) {
            val draft = parser.parse(text = recordedText(name = name))
            assertEquals(expected = total, actual = draft.total.value, message = "$name の合計が ${total}円 でない")
            assertEquals(
                expected = total,
                actual = draft.items.sumOf { item -> item.amount },
                message = "$name の明細の和が合計 ${total}円 と合わない",
            )
        }
    }
}

// Parsing the text of [name] once more gives [first] again.
internal fun assertParsesTheSameAgain(
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
