package io.github.mktkhr.moneging.domain

import java.text.BreakIterator

// java.text.BreakIterator follows extended grapheme clusters (Unicode UAX
// #29) on Android and on the JDK the host tests run on.
internal actual fun userPerceivedLength(text: String): Int {
    val iterator = BreakIterator.getCharacterInstance()
    iterator.setText(text)
    var count = 0
    while (iterator.next() != BreakIterator.DONE) {
        count++
    }
    return count
}
