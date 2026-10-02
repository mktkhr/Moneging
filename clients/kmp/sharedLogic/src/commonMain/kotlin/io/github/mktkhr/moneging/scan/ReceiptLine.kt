package io.github.mktkhr.moneging.scan

import kotlin.math.abs

// An amount token: an optional reduced-tax mark, an optional yen sign, an
// optional minus, digits with a comma every three from the right, and an
// optional ※ (acceptance/fixtures/README.md, Items).
// The patterns below read a line's look-alikes as one (`readable`): a
// full-width letter, digit or sign as its half-width form, every sign of
// multiplication as `x`.
private val AMOUNT = Regex("""^\*?(¥?)(-?)(\d{1,3}(?:,\d{3})*)※?$""")
private val TOKEN_SEPARATOR = Regex("""[ \t]+""")
private const val YEN = "¥"
private const val REDUCED_TAX_SIGN = '*'

// The groups of an amount token's yen sign and minus sign.
private const val YEN_GROUP = 1
private const val MINUS_GROUP = 2

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
private val DISCOUNT_MARKS = listOf("ディスカウント", "値引", "割引")

/** A date: `yyyy/mm/dd`, or `yyyy年m月d日` with one or two digits for the month and the day. */
internal val DATE = Regex("""(\d{4})(?:/(\d{2})/(\d{2})|年(\d{1,2})月(\d{1,2})日)""")

// A register (`00レジNO 00`, `レジ #0`, `レジ0012`; not `レジ袋`) and a time (`19:00`).
private val REGISTER = Regex("""レジ\s*(?:No|NO|#|\d)""")
private val TIME = Regex("""(?<!\d)\d{1,2}:\d{2}(?!\d)""")

// An item printed in parentheses (a set): its name is inside the first pair.
private const val OPEN = '('
private const val CLOSE = ')'
private const val OPTION_PREFIX = "+"
private const val OPTION_MARK = "※"

// What is dropped from the start of an item's name, in this order.
private val CHECK_BOX = Regex("""^[ロ■□]\s?""")
private val REDUCED_TAX_MARK = Regex("""^\*""")
private val ITEM_CODE = Regex("""^\d{3}(?!\d)\s?""")

/**
 * One row of a receipt: its [text] before the amount, and the [amount] it
 * ends with, if any. In a receipt that prints its prices with `¥`
 * ([isYenPrinted]), a price printed with neither `¥` nor `-` is not an amount.
 */
internal class ReceiptLine(
    line: String,
    isYenPrinted: Boolean = false,
) {
    private val readableLine = readable(line)
    private val tokens = readableLine.split(TOKEN_SEPARATOR)
    private val price = AMOUNT.find(tokens.last())

    /** Whether it ends with a price, whether or not that is an amount. */
    val hasPrice: Boolean = price != null

    /** Whether the price it ends with is printed with `¥` or `￥`. */
    val isPricedWithYen: Boolean = hasGroup(match = price, group = YEN_GROUP)

    /** Whether the price it ends with is printed with `-`. */
    val isPricedWithMinus: Boolean = hasGroup(match = price, group = MINUS_GROUP)

    /** The yen amount of its last token, or `null` when that is not an amount. */
    val amount: Long? =
        price?.takeIf { !isYenPrinted || isPricedWithYen || isPricedWithMinus }?.let { amountOf(tokens.last()) }

    /** Its text before the amount, as recognised; the whole line when it has none. */
    val text: String = if (amount != null) line.dropLast(n = tokens.last().length).trimEnd() else line

    /** Whether it starts with a quantity and a unit price (`2コ✕単178 ¥356`, `@159× 3 *477`). */
    val isQuantity: Boolean = QUANTITY.containsMatchIn(readableLine)

    /** Whether its text names a discount (`ディスカウント`, `値引`, `割引`). */
    val isNamedDiscount: Boolean = DISCOUNT_MARKS.any { mark -> text.contains(mark) }

    /** Whether it is a discount on the whole receipt: one named, its amount printed without `-` (`ディスカウント ¥250`). */
    val isReceiptDiscount: Boolean = isNamedDiscount && amount != null && !isPricedWithMinus

    /**
     * Whether it is a discount (`値引額 -50`, `シール割引 50%`), or an amount
     * below zero whose label was not recognised (`-50`).
     */
    val isDiscount: Boolean = isNamedDiscount || amount ?: 0L < 0L

    /** Whether it is an option of the item above (`+ LARGE RICE ¥150`, `氷Ice※通常 ¥120`). */
    val isOption: Boolean = readableLine.startsWith(OPTION_PREFIX) || hasOptionMark(amount = amount, text = text)

    /** Whether it names the date, the register or the time, which is never an item. */
    val isNeverItem: Boolean =
        DATE.containsMatchIn(readableLine) || REGISTER.containsMatchIn(readableLine) ||
            TIME.containsMatchIn(readableLine)

    /** Its amount as a discount: below zero whatever its sign. */
    val discount: Long?
        get() = amount?.let { -abs(it) }

    /**
     * The name of the item it is: for a line in parentheses (a set), the text
     * inside the first pair; else [itemName] of its text before the amount.
     */
    fun itemName(isDelivery: Boolean): String {
        if (readableLine.firstOrNull() != OPEN) return itemName(text = text, isDelivery = isDelivery)
        val close = readableLine.indexOf(CLOSE)
        return if (close >
            0
        ) {
            text.substring(startIndex = 1, endIndex = minOf(a = close, b = text.length)).trim()
        } else {
            text
        }
    }
}

// Whether [group] of [match] matched something (a price's `¥` or `-`).
internal fun hasGroup(
    match: MatchResult?,
    group: Int,
): Boolean = match != null && match.groupValues[group].isNotEmpty()

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
    val (_, minus, digits) = match.destructured
    val yen = digits.replace(oldValue = ",", newValue = "").toLongOrNull()
    return if (minus.isEmpty()) yen else yen?.let { -it }
}

/**
 * The trimmed, non-empty rows of [text], a row that ends with a lone yen
 * sign joined to the next by a space, the sign moved to the price the
 * joined row ends with (`■ JUICY巨峰ミルクティー JUICY ¥` and
 * `Kyoho Grape Milk Tea 1,010` read `… Kyoho Grape Milk Tea ¥1,010`), so
 * that price counts as printed with `¥`.
 */
internal fun receiptRows(text: String): List<String> {
    val rows = mutableListOf<String>()
    var pending: String? = null
    for (line in text.lines().map { it.trim() }.filter { it.isNotEmpty() }) {
        val row = pending?.let { "$it ${withYen(line)}" } ?: line
        val tokens = readable(row).split(TOKEN_SEPARATOR)
        pending = if (tokens.size > 1 && tokens.last() == YEN) row.dropLast(n = 1).trimEnd() else null
        if (pending == null) rows += row
    }
    pending?.let { rows += it }
    return rows
}

// [line] with a yen sign before the price it ends with, when it ends with
// one printed without (`Kyoho Grape Milk Tea 1,010` reads `… ¥1,010`).
private fun withYen(line: String): String {
    val last = readable(line).split(TOKEN_SEPARATOR).last()
    val price = AMOUNT.find(last)
    if (price == null || hasGroup(match = price, group = YEN_GROUP)) return line
    // After the reduced-tax mark, if any; the readable text has the length of the line.
    val at = line.length - last.length + if (last.startsWith(REDUCED_TAX_SIGN)) 1 else 0
    return line.substring(startIndex = 0, endIndex = at) + YEN + line.substring(startIndex = at)
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
