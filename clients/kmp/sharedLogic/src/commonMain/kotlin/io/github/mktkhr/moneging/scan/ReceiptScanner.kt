package io.github.mktkhr.moneging.scan

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlin.time.Duration

/**
 * Reads one receipt photo into a [ReceiptReading], entirely on the device
 * (PRODUCT.md §3, Scanner). A photo it cannot read is refused with
 * [IllegalStateException], whose message is the human-readable reason the
 * failed job carries.
 */
interface ReceiptScanner {
    /** The reading of the photo [image]. */
    suspend fun read(image: ByteArray): ReceiptReading
}

/**
 * The on-device LLM: Foundation Models on iOS devices with Apple
 * Intelligence, Gemini Nano on Android devices that support it.
 */
interface OnDeviceLlm {
    /** Whether this device has one; when not, [structure] is never asked. */
    val isAvailable: Boolean

    /** The reading the LLM structures [text] (recognised from a receipt) into. */
    suspend fun structure(text: String): ReceiptReading
}

/** Recognises the text of a receipt photo, one receipt row per line (Vision on iOS, ML Kit on Android). */
fun interface TextRecognizer {
    /** The text of the photo [image]; refuses one without text with [IllegalStateException]. */
    suspend fun recognize(image: ByteArray): String
}

/**
 * Structures recognised text into a reading: by the on-device LLM when the
 * device has one, else by the rule-based parser [ruleBased]. When the LLM
 * fails on a text (a guardrail, a context too long, a malformed answer),
 * the rule-based parser reads it instead. Either way the reading has the
 * same shape.
 */
class ReceiptStructuring(
    private val llm: OnDeviceLlm,
    private val ruleBased: ReceiptTextParser,
) {
    /** The reading of [text]. */
    suspend fun structure(text: String): ReceiptReading {
        if (!llm.isAvailable) return ruleBased.parse(text = text)
        return try {
            llm.structure(text = text)
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (ignoredFailure: IllegalStateException) {
            ruleBased.parse(text = text)
        } catch (ignoredMalformed: IllegalArgumentException) {
            ruleBased.parse(text = text)
        }
    }
}

/** The scanner of the product: text recognition by [recognizer], then [structuring]. */
class TextRecognizingReceiptScanner(
    private val recognizer: TextRecognizer,
    private val structuring: ReceiptStructuring,
) : ReceiptScanner {
    override suspend fun read(image: ByteArray): ReceiptReading {
        val text = recognizer.recognize(image = image)
        check(text.isNotBlank()) { "文字が見つかりませんでした" }
        return structuring.structure(text = text)
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
 * read. With [failure], every photo fails with that reason instead.
 */
class FixtureReceiptScanner(
    private val receipts: List<FixtureReceipt>,
    private val duration: Duration = Duration.ZERO,
    private val failure: String? = null,
) : ReceiptScanner {
    override suspend fun read(image: ByteArray): ReceiptReading {
        if (duration.isPositive()) delay(duration)
        check(failure == null) { failure.orEmpty() }
        val receipt = receipts.firstOrNull { it.isPictureOf(photo = image) }
        return checkNotNull(receipt) { "このレシートは読み取れませんでした" }.reading
    }
}

/** The scanner of a store given none: nothing can be read. */
internal object NoReceiptScanner : ReceiptScanner {
    override suspend fun read(image: ByteArray): ReceiptReading = error("この端末ではレシートを読み取れません")
}
