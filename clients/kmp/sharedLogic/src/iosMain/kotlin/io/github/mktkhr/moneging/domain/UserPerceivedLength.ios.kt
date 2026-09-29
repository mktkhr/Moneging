package io.github.mktkhr.moneging.domain

import kotlinx.cinterop.BetaInteropApi
import kotlinx.cinterop.ExperimentalForeignApi
import platform.Foundation.NSMakeRange
import platform.Foundation.NSString
import platform.Foundation.NSStringEnumerationByComposedCharacterSequences
import platform.Foundation.create
import platform.Foundation.enumerateSubstringsInRange
import platform.Foundation.length

// Foundation's composed character sequences are the grapheme clusters Swift's
// String.count counts.
@OptIn(BetaInteropApi::class, ExperimentalForeignApi::class)
internal actual fun userPerceivedLength(text: String): Int {
    val string = NSString.create(string = text)
    var count = 0
    string.enumerateSubstringsInRange(
        range = NSMakeRange(loc = 0u, len = string.length),
        options = NSStringEnumerationByComposedCharacterSequences,
    ) { _, _, _, _ ->
        count++
    }
    return count
}
