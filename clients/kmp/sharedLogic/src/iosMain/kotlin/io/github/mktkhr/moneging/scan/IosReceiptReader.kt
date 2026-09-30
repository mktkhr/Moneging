package io.github.mktkhr.moneging.scan

import io.github.mktkhr.moneging.data.nsData
import kotlinx.coroutines.suspendCancellableCoroutine
import platform.Foundation.NSData
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

private const val NOT_READ = "読み取れませんでした"

/**
 * What the iOS app reads receipts with, implemented in Swift: Vision's text
 * recognition and, on a device with Apple Intelligence, Foundation Models.
 * Each answers through its completion exactly once: the result, or `null`
 * and the human-readable reason it could not.
 */
interface IosReceiptReader {
    /** Whether this device has Foundation Models available. */
    val hasOnDeviceLlm: Boolean

    /** Recognises the text of the photo [image], one receipt row per line. */
    fun recognizeText(
        image: NSData,
        completion: (text: String?, failure: String?) -> Unit,
    )

    /**
     * Structures [text] with Foundation Models into a draft in the JSON
     * format of `ReceiptReading.fromJson`.
     */
    fun structureText(
        text: String,
        completion: (json: String?, failure: String?) -> Unit,
    )
}

/** The product's scanner on iOS: Vision, then Foundation Models or the rule-based parser. */
internal fun iosReceiptScanner(reader: IosReceiptReader): ReceiptScanner =
    TextRecognizingReceiptScanner(
        recognizer = { image ->
            answer { completion -> reader.recognizeText(image = nsData(image), completion = completion) }
        },
        structuring = ReceiptStructuring(llm = FoundationModelsLlm(reader), ruleBased = RuleBasedReceiptParser()),
    )

private class FoundationModelsLlm(
    private val reader: IosReceiptReader,
) : OnDeviceLlm {
    override val isAvailable: Boolean
        get() = reader.hasOnDeviceLlm

    override suspend fun structure(text: String): ReceiptReading =
        ReceiptReading.fromJson(
            json =
                answer { completion ->
                    reader.structureText(text = text, completion = completion)
                },
        )
}

// Waits for the one answer [ask] gives its completion; a failure is thrown
// as IllegalStateException, the job's reason.
private suspend fun answer(ask: ((String?, String?) -> Unit) -> Unit): String =
    suspendCancellableCoroutine { continuation ->
        ask { result, failure ->
            if (continuation.isActive) {
                if (result != null) {
                    continuation.resume(result)
                } else {
                    continuation.resumeWithException(IllegalStateException(failure ?: NOT_READ))
                }
            }
        }
    }
