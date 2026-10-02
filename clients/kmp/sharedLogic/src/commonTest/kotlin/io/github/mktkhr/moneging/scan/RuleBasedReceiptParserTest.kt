package io.github.mktkhr.moneging.scan

import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

private const val THOUSANDS = 3_280L
private const val DISCOUNT = -198L
private const val LUNCH = 1_000L
private const val LUNCH_ALONE = 800L
private const val DISCOUNTED = 598L
private const val PEPERONCINO = "大盛ペペロンチーノ"
private const val SET = 1_060L
private const val RECEIPT_DISCOUNT = 250L
private const val THREE_BOTTLES = 477L
private const val TWO_PACKS = 356L
private const val STICKER = 198L
private const val TEA = 1_010L
private const val SALAD = 300L
private const val RICE_BALL = 380L
private const val BREAD = 120L
private const val TAKEN_OFF = 30L

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

        assertEquals(expected = listOf(PEPERONCINO to DISCOUNTED), actual = reading.items.map { it.name to it.amount })
    }

    /** A quantity line is read whatever sign of multiplication, width or spacing the device recognised. */
    @Test
    fun quantityLinesOfEveryLook() {
        val bottles =
            listOf(
                "@159x 3 *477",
                "@159× 3 *477",
                "@159×3 *477",
                "@159 x 3 *477",
                "@159✕ 3 *477",
                "@159✖ 3 *477",
                "@159*3 *477",
                "@159＊3 ＊477",
                "@159Ｘ3 *477",
                "＠１５９× ３ ＊４７７",
            )
        bottles.forEach { quantity ->
            assertEquals(
                expected = listOf("キリンファイア600ml" to THREE_BOTTLES),
                actual = itemsOf("キリンファイア600ml", quantity, "合計 ¥477"),
                message = quantity,
            )
        }
        listOf("2コ✕単178 ¥356", "2コ×単178 ￥356", "2コ x 単178 ¥356", "２コ×単１７８ ¥３５６").forEach { quantity ->
            assertEquals(
                expected = listOf("緑豆はるさめ100" to TWO_PACKS),
                actual = itemsOf("＊緑豆はるさめ100", quantity, "合計 ¥356"),
                message = quantity,
            )
        }
    }

    /** A discount, an amount and the end of the items are read in their full-width and look-alike forms. */
    @Test
    fun fullWidthFormsReadAsHalfWidth() {
        assertEquals(
            expected = listOf("白菜" to STICKER),
            actual = itemsOf("*白菜", "2コ✕単198 ¥396", "シール割引 50％", "2コ×単－99 −198", "合計 ¥198"),
        )
        assertEquals(
            expected = listOf(PEPERONCINO to DISCOUNTED),
            actual = itemsOf("大盛ペペロンチーノ ＊６４８", "値引額 －５０", "（商品代金 ￥６４８）", "合計 ￥５９８"),
        )
        assertEquals(
            expected = listOf("アキタコマチ5" to THOUSANDS, "消費税" to 1L),
            actual = itemsOf("６５１ アキタコマチ5 ３，２８０※", "小計 ¥3,280", "8％外税額 ¥1", "合計 ¥3,281"),
        )
    }

    /** A discount below the sets, with nothing priced after it, is a discount item of its own. */
    @Test
    fun receiptDiscountIsItsOwnItem() {
        val reading =
            RuleBasedReceiptParser().parse(
                text =
                    listOf(
                        "マクドナルド三田駅前店",
                        "00レジNO 00 2026年10月1日 （木）19:00",
                        "（ジャガペッパーツキミLセット）＊1060 （1コ） ¥1,060",
                        "マックフライポテトL 1コ",
                        "ディスカウント ¥250",
                        "小計 ¥810",
                        "合計 ¥810",
                    ).joinToString(separator = "\n"),
            )

        assertEquals(expected = LocalDate(year = 2026, month = 10, day = 1), actual = reading.date.value)
        assertEquals(
            expected = listOf("ジャガペッパーツキミLセット" to SET, "ディスカウント" to -RECEIPT_DISCOUNT),
            actual = reading.items.map { item -> item.name to item.amount },
        )
    }

    /**
     * In a receipt that prints most prices with `¥` (a row joined at a lone
     * `¥` counts as one), a number with neither `¥` nor `-` is no amount; on a
     * tie every price is one.
     */
    @Test
    fun countsAreNoAmountsBesideYen() {
        assertEquals(
            expected = listOf("Milk JUICY Kyoho Tea" to TEA, "サラダ" to SALAD),
            actual = itemsOf("Milk JUICY ¥", "Kyoho Tea 1,010", "ポテト 11", "サラダ ¥300", "合計 ¥1,310"),
        )
        assertEquals(
            expected = listOf("おにぎり" to RICE_BALL, "パン" to BREAD),
            actual = itemsOf("おにぎり ¥380", "パン 120", "合計 ¥500"),
        )
    }

    /**
     * A discount's printed sign tells what it takes off: without `-` the whole
     * receipt, wherever it stands; with `-` the item above. A word of the
     * summary ends the items, with or without its opening parenthesis.
     */
    @Test
    fun discountSignAndSummaryWords() {
        assertEquals(
            expected = listOf("おにぎり" to RICE_BALL - TAKEN_OFF, "パン" to BREAD, "ディスカウント" to -RECEIPT_DISCOUNT),
            actual =
                itemsOf(
                    "おにぎり ¥380",
                    "割引 -30",
                    "ディスカウント ¥250",
                    "パン ¥120",
                    "商品代金 ¥250）",
                    "おまけ ¥50",
                    "合計 ¥250",
                ),
        )
        assertEquals(
            expected = listOf("パン" to BREAD),
            actual = itemsOf("パン ¥120", "（値引合計 -50）", "おまけ ¥50", "合計 ¥120"),
        )
    }

    /** A discount right below an item is taken off it, not kept as an item. */
    @Test
    fun itemDiscountStaysInItsItem() {
        assertEquals(
            expected = listOf(PEPERONCINO to DISCOUNTED),
            actual = itemsOf("大盛ペペロンチーノ *648", "値引額 -50", "合計 ¥598"),
        )
    }
}

// The items, as names and amounts, of a receipt whose item lines are [lines] (the total last).
internal fun itemsOf(vararg lines: String): List<Pair<String, Long>> =
    RuleBasedReceiptParser()
        .parse(text = (listOf("店", "2026／09／28") + lines).joinToString(separator = "\n"))
        .items
        .map { item -> item.name to item.amount }
