package io.github.mktkhr.moneging.scan

import kotlin.math.abs

// An amount token: an optional reduced-tax mark, an optional yen sign, an
// optional minus, digits with a comma every three from the right, and an
// optional ※ (acceptance/fixtures/README.md, Items).
// The patterns below read a line's look-alikes as one (`readable`): a
// full-width letter, digit or sign as its half-width form, every sign of
// multiplication as `x`.
private val AMOUNT = Regex("""^\*?¥?(-?)(\d{1,3}(?:,\d{3})*)※?$""")
private val TOKEN_SEPARATOR = Regex("""[ \t]+""")
private const val YEN = "¥"

// A quantity and a unit price at the start of a line: `2コ✕単178`,
// `2コX単-99`, `@159x 3`, `@159*3`.
private val QUANTITY = Regex("""^(?:\d+[^\s\d]{0,2}?\s*[xX*]\s*単?\s*-?\d|@\s*-?\d+\s*[xX*]\s*\d)""")

// The first and last full-width forms of the ASCII signs, letters and
// digits (`！` to `～`), and how far each is from its half-width form.
private const val FULL_WIDTH_FIRST = '\uFF01'
private const val FULL_WIDTH_LAST = '\uFF5E'
private const val FULL_WIDTH_OFFSET = 0xFEE0

// Look-alikes read as one sign: spaces, yen signs, minus signs, asterisks
// and the signs of multiplication (`×`, `✕`, `✖`, `⨯`).
private val LOOK_ALIKES: Map<Char, Char> =
    mapOf(
        '\u3000' to ' ',
        '\uFFE5' to '¥',
        '\u2212' to '-',
        '\u2010' to '-',
        '\u2011' to '-',
        '\u2013' to '-',
        '\u2217' to '*',
        '\u00D7' to 'x',
        '\u2715' to 'x',
        '\u2716' to 'x',
        '\u2A2F' to 'x',
    )
private val DISCOUNT_MARKS = listOf("値引", "割引")
private const val OPTION_PREFIX = "+"
private const val OPTION_MARK = "※"

// What is dropped from the start of an item's name, in this order.
private val CHECK_BOX = Regex("""^[ロ■□]\s?""")
private val REDUCED_TAX_MARK = Regex("""^\*""")
private val ITEM_CODE = Regex("""^\d{3}(?!\d)\s?""")

/** One row of a receipt: its [text] before the amount, and the [amount] it ends with, if any. */
internal class ReceiptLine(
    line: String,
) {
    private val readableLine = readable(line)
    private val tokens = readableLine.split(TOKEN_SEPARATOR)

    /** The yen amount of its last token, or `null` when that is not an amount. */
    val amount: Long? = amountOf(tokens.last())

    /** Its text before the amount, as recognised; the whole line when it has none. */
    val text: String = if (amount != null) line.dropLast(n = tokens.last().length).trimEnd() else line

    /** Whether it starts with a quantity and a unit price (`2コ✕単178 ¥356`, `@159× 3 *477`). */
    val isQuantity: Boolean = QUANTITY.containsMatchIn(readableLine)

    /**
     * Whether it is a discount (`値引額 -50`, `シール割引 50%`), or an amount
     * below zero whose label was not recognised (`-50`).
     */
    val isDiscount: Boolean = DISCOUNT_MARKS.any { mark -> text.contains(mark) } || amount ?: 0L < 0L

    /** Whether it is an option of the item above (`+ LARGE RICE ¥150`, `氷Ice※通常 ¥120`). */
    val isOption: Boolean = readableLine.startsWith(OPTION_PREFIX) || hasOptionMark(amount = amount, text = text)

    /** Its amount as a discount: below zero whatever its sign. */
    val discount: Long?
        get() = amount?.let { -abs(it) }
}

// Whether the text before an [amount] carries the option mark (`氷Ice※通常 ¥120`).
internal fun hasOptionMark(
    amount: Long?,
    text: String,
): Boolean = amount != null && text.contains(OPTION_MARK)

/**
 * [text] with each look-alike read as one sign, character for character (the
 * same length): `＠１５９× ３ ＊４７７` reads `@159x 3 *477`. A device's text
 * recognition picks among look-alikes differently from a Mac's.
 */
internal fun readable(text: String): String = text.map(::readableChar).toCharArray().concatToString()

// [char] as the sign it is read as.
private fun readableChar(char: Char): Char =
    if (char in FULL_WIDTH_FIRST..FULL_WIDTH_LAST) char - FULL_WIDTH_OFFSET else LOOK_ALIKES[char] ?: char

/** The yen amount of [token] (`*¥-1,234※`, `＊￥１，２３４`), or `null` when it is not one. */
internal fun amountOf(token: String): Long? {
    val match = AMOUNT.find(readable(token)) ?: return null
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
        val tokens = readable(row).split(TOKEN_SEPARATOR)
        pending = if (tokens.size > 1 && tokens.last() == YEN) row.dropLast(n = 1).trimEnd() else null
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
    // Each is found in the readable text and dropped from the text as recognised.
    var name = text
    val prefixes = listOfNotNull(CHECK_BOX.takeIf { isDelivery }, REDUCED_TAX_MARK, ITEM_CODE)
    for (prefix in prefixes) {
        val found = prefix.find(readable(name))
        if (found != null) name = name.drop(n = found.value.length)
    }
    return name
}
