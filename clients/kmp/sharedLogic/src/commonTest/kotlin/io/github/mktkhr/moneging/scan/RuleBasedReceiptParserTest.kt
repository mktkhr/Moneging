package io.github.mktkhr.moneging.scan

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

private const val THOUSANDS = 3_280L
private const val DISCOUNT = -198L
private const val LUNCH = 1_000L
private const val LUNCH_ALONE = 800L
private const val DISCOUNTED = 598L

/** The pieces of the rule-based parser the recorded receipts do not all show. */
class RuleBasedReceiptParserTest {
    /** An amount has a comma every three digits; anything else at a line's end is not one. */
    @Test
    fun amountsAreYenWithCommas() {
        assertEquals(expected = THOUSANDS, actual = amountOf(token = "3,280※"))
        assertEquals(expected = DISCOUNT, actual = amountOf(token = "-198"))
        assertEquals(expected = LUNCH, actual = amountOf(token = "*¥1,000"))
        listOf("6501", "50%", "15:48", "登録No0000", "¥", "1,00").forEach { token ->
            assertNull(actual = amountOf(token = token), message = token)
        }
    }

    /** A chain listed earlier wins a spelling found at the same place; no chain gives no name. */
    @Test
    fun chainsAreFoundFirstByPlace() {
        assertEquals(expected = "マルエツ プチ", actual = ReceiptChains.nameIn(lines = listOf("MARUETSU", "Petit")))
        assertEquals(expected = "マルエツ", actual = ReceiptChains.nameIn(lines = listOf("マルエツ 田町店")))
        assertEquals(expected = "ゴンチャ", actual = ReceiptChains.nameIn(lines = listOf("ゴンチャ", "ライフ商品券")))
        assertNull(actual = ReceiptChains.nameIn(lines = listOf("コーナーデリ")))
    }

    /** Included tax adds no item, and an added tax that would not be positive is not added. */
    @Test
    fun addedTaxIsOnlyWhatTheTotalAdds() {
        val receipt = listOf("店", "2026/02/14", "弁当 ¥800", "合計 ¥800")
        val included = RuleBasedReceiptParser().parse(text = (receipt + "（内消費税等 ¥59）").joinToString(separator = "\n"))
        val excluded = RuleBasedReceiptParser().parse(text = (receipt + "（外税 ¥0）").joinToString(separator = "\n"))

        assertEquals(expected = listOf(LUNCH_ALONE), actual = included.items.map { item -> item.amount })
        assertEquals(expected = listOf(LUNCH_ALONE), actual = excluded.items.map { item -> item.amount })
    }

    /** An amount below zero whose label was not recognised is still a discount of the item above. */
    @Test
    fun bareNegativeIsADiscount() {
        val text = listOf("店", "2026年09月28日", "大盛ペペロンチーノ *648", "-50", "合計 ¥598").joinToString(separator = "\n")

        val reading = RuleBasedReceiptParser().parse(text = text)

        assertEquals(expected = listOf("大盛ペペロンチーノ" to DISCOUNTED), actual = reading.items.map { it.name to it.amount })
    }
}
