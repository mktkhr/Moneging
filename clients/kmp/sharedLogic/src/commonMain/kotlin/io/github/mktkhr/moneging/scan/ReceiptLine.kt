package io.github.mktkhr.moneging.scan

import kotlin.math.abs

// An amount token: an optional reduced-tax mark, an optional yen sign, an
// optional minus, digits with a comma every three from the right, and an
// optional ※ (acceptance/fixtures/README.md, Items).
private val AMOUNT = Regex("""^[*＊]?[¥￥]?(-?)(\d{1,3}(?:,\d{3})*)※?$""")
private val TOKEN_SEPARATOR = Regex("""[ \t　]+""")
private val LONE_YEN = setOf("¥", "￥")

// A quantity and a unit price at the start of a line: `2コ✕単178`,
// `2コX単-99`, `@159x 3`.
private val QUANTITY = Regex("""^(?:\d+[^\s\d]{0,2}?[xX✕×]\s*単?\s*-?\d|@\s*-?\d+\s*[xX✕×]\s*\d)""")
private val DISCOUNT_MARKS = listOf("値引", "割引")
private const val OPTION_PREFIX = "+"
private const val OPTION_MARK = "※"

// What is dropped from the start of an item's name, in this order.
private val CHECK_BOX = Regex("""^[ロ■□]\s?""")
private val REDUCED_TAX_MARK = Regex("""^[*＊]""")
private val ITEM_CODE = Regex("""^\d{3}(?!\d)\s?""")

/** One row of a receipt: its [text] before the amount, and the [amount] it ends with, if any. */
internal class ReceiptLine(
    line: String,
) {
    private val tokens = line.split(TOKEN_SEPARATOR)

    /** The yen amount of its last token, or `null` when that is not an amount. */
    val amount: Long? = amountOf(tokens.last())

    /** Its text before the amount; the whole line when it has none. */
    val text: String = if (amount != null) line.dropLast(n = tokens.last().length).trimEnd() else line

    /** Whether it starts with a quantity and a unit price (`2コ✕単178 ¥356`). */
    val isQuantity: Boolean = QUANTITY.containsMatchIn(line)

    /**
     * Whether it is a discount (`値引額 -50`, `シール割引 50%`), or an amount
     * below zero whose label was not recognised (`-50`).
     */
    val isDiscount: Boolean = DISCOUNT_MARKS.any { mark -> text.contains(mark) } || amount ?: 0L < 0L

    /** Whether it is an option of the item above (`+ LARGE RICE ¥150`, `氷Ice※通常 ¥120`). */
    val isOption: Boolean = line.startsWith(OPTION_PREFIX) || hasOptionMark(amount = amount, text = text)

    /** Its amount as a discount: below zero whatever its sign. */
    val discount: Long?
        get() = amount?.let { -abs(it) }
}

// Whether the text before an [amount] carries the option mark (`氷Ice※通常 ¥120`).
internal fun hasOptionMark(
    amount: Long?,
    text: String,
): Boolean = amount != null && text.contains(OPTION_MARK)

/** The yen amount of [token] (`*¥-1,234※`), or `null` when it is not one. */
internal fun amountOf(token: String): Long? {
    val match = AMOUNT.find(token) ?: return null
    val (minus, digits) = match.destructured
    val yen = digits.replace(oldValue = ",", newValue = "").toLongOrNull()
    return if (minus.isEmpty()) yen else yen?.let { -it }
}

/**
 * The trimmed, non-empty rows of [text], a row that ends with a lone yen
 * sign joined to the next by a space, the sign dropped
 * (`■ JUICY巨峰ミルクティー JUICY ¥` and `Kyoho Grape Milk Tea 1,010`).
 */
internal fun receiptRows(text: String): List<String> {
    val rows = mutableListOf<String>()
    var pending: String? = null
    for (line in text.lines().map { it.trim() }.filter { it.isNotEmpty() }) {
        val row = pending?.let { "$it $line" } ?: line
        val tokens = row.split(TOKEN_SEPARATOR)
        pending = if (tokens.size > 1 && tokens.last() in LONE_YEN) row.dropLast(n = 1).trimEnd() else null
        if (pending == null) rows += row
    }
    pending?.let { rows += it }
    return rows
}

/**
 * The name of an item from the text of its line: a delivery order's check
 * box (when [isDelivery]), then the reduced-tax mark, then a three-digit
 * item code dropped from its start; the rest kept as recognised.
 */
internal fun itemName(
    text: String,
    isDelivery: Boolean,
): String {
    val unchecked = if (isDelivery) CHECK_BOX.replaceFirst(input = text, replacement = "") else text
    val unmarked = REDUCED_TAX_MARK.replaceFirst(input = unchecked, replacement = "")
    return ITEM_CODE.replaceFirst(input = unmarked, replacement = "")
}
