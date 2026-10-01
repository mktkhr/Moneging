package io.github.mktkhr.moneging.scan

import kotlinx.coroutines.delay
import kotlin.time.Duration

/**
 * Reads one receipt photo into a [ReceiptReading], entirely on the device
 * (PRODUCT.md §3, Scanner). A photo it cannot read is refused with
 * [IllegalStateException], whose message is the human-readable reason the
 * failed job carries.
 */
interface ReceiptScanner {
    /** The reading of the photo [image], structured by [method]. */
    suspend fun read(
        image: ByteArray,
        method: ReadingMethod,
    ): ReceiptReading

    /**
     * The reading of the photo [image], structured by [method]; the text it
     * recognised is given to [onText] first, as it is given to the
     * structuring. A scanner that recognises no text gives nothing.
     */
    suspend fun read(
        image: ByteArray,
        method: ReadingMethod,
        onText: suspend (String) -> Unit,
    ): ReceiptReading = read(image = image, method = method)
}

/**
 * The on-device LLM: Foundation Models on iOS devices with Apple
 * Intelligence, Gemini Nano on Android devices that support it.
 */
interface OnDeviceLlm {
    /** Whether this device has one and it can be used now; when not, [structure] is never asked. */
    val isAvailable: Boolean

    /** Why it cannot be used (`設定で Apple Intelligence がオフになっています`), or `null` to say nothing more. */
    val unavailableReason: String?
        get() = null

    /** The reading the LLM structures [text] (recognised from a receipt) into. */
    suspend fun structure(text: String): ReceiptReading
}

/** Recognises the text of a receipt photo, one receipt row per line (Vision on iOS, ML Kit on Android). */
fun interface TextRecognizer {
    /** The text of the photo [image]; refuses one without text with [IllegalStateException]. */
    suspend fun recognize(image: ByteArray): String
}

/**
 * Structures recognised text into a reading by the reading method given
 * (PRODUCT.md §3, Reading method): the device's AI [llm], or the rule-based
 * parser [ruleBased]. Nothing falls back on its own: when the AI cannot be
 * used or fails on a text, the reading fails with the reason, and the user
 * chooses what to do. Either way a reading has the same shape.
 */
class ReceiptStructuring(
    private val llm: OnDeviceLlm,
    private val ruleBased: ReceiptTextParser,
) {
    /** The reading of [text] by [method]; refuses with [IllegalStateException] when the AI cannot read it. */
    suspend fun structure(
        text: String,
        method: ReadingMethod,
    ): ReceiptReading =
        when (method) {
            ReadingMethod.NO_AI -> {
                ruleBased.parse(text = text)
            }

            ReadingMethod.DEVICE_AI -> {
                check(llm.isAvailable) { llm.unavailableReason ?: DEVICE_AI_UNUSABLE }
                try {
                    llm.structure(text = text)
                } catch (malformed: IllegalArgumentException) {
                    throw IllegalStateException(AI_ANSWER_UNREADABLE, malformed)
                }
            }
        }
}

private const val DEVICE_AI_UNUSABLE = "この端末の AI が使えません"
private const val AI_ANSWER_UNREADABLE = "AI の答えを読み取れませんでした"

/** The scanner of the product: text recognition by [recognizer], then [structuring]. */
class TextRecognizingReceiptScanner(
    private val recognizer: TextRecognizer,
    private val structuring: ReceiptStructuring,
) : ReceiptScanner {
    override suspend fun read(
        image: ByteArray,
        method: ReadingMethod,
    ): ReceiptReading = read(image = image, method = method, onText = {})

    override suspend fun read(
        image: ByteArray,
        method: ReadingMethod,
        onText: suspend (String) -> Unit,
    ): ReceiptReading {
        val text = recognizer.recognize(image = image)
        onText(text)
        check(text.isNotBlank()) { "文字が見つかりませんでした" }
        return structuring.structure(text = text, method = method)
    }
}

/** A picture the fixture scanner knows ([image], its bytes), and the reading it answers for it. */
class FixtureReceipt(
    private val image: ByteArray,
    /** What reading it gives. */
    val reading: ReceiptReading,
) {
    /** Whether [photo] is this picture, byte for byte. */
    fun isPictureOf(photo: ByteArray): Boolean = image.contentEquals(photo)
}

/**
 * The scanner that reads fixtures deterministically (PRODUCT.md §6,
 * determinism in tests): for a photo byte-identical to one of [receipts] it
 * answers that receipt's reading, after [duration]; any other photo is not
 * read, whatever the reading method. With [failure], every photo fails with
 * that reason instead.
 */
class FixtureReceiptScanner(
    private val receipts: List<FixtureReceipt>,
    private val duration: Duration = Duration.ZERO,
    private val failure: String? = null,
) : ReceiptScanner {
    override suspend fun read(
        image: ByteArray,
        method: ReadingMethod,
    ): ReceiptReading {
        if (duration.isPositive()) delay(duration)
        check(failure == null) { failure.orEmpty() }
        val receipt = receipts.firstOrNull { it.isPictureOf(photo = image) }
        return checkNotNull(receipt) { "このレシートは読み取れませんでした" }.reading
    }
}

/** The scanner of a store given none: nothing can be read. */
internal object NoReceiptScanner : ReceiptScanner {
    override suspend fun read(
        image: ByteArray,
        method: ReadingMethod,
    ): ReceiptReading = error("この端末ではレシートを読み取れません")
}
