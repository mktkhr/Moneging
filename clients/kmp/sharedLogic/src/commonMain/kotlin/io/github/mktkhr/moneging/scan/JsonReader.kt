package io.github.mktkhr.moneging.scan

// A small reader of JSON text into Kotlin values, enough for the drafts the
// scanners exchange (acceptance/fixtures/README.md): objects as maps,
// arrays as lists, strings, numbers as Double, booleans and null. Malformed
// text is refused with IllegalArgumentException.

private const val HEX_RADIX = 16
private const val UNICODE_ESCAPE_LENGTH = 4
private const val NUMBER_SIGNS = "+-.eE"

/** The value of the JSON document [text]. */
internal fun readJson(text: String): Any? {
    val cursor = JsonCursor(text)
    val value = JsonValues(cursor).read()
    cursor.skipWhitespace()
    require(cursor.isAtEnd) { "JSON の後ろに余計な文字があります" }
    return value
}

// Where the reading of [text] stands, character by character.
private class JsonCursor(
    val text: String,
) {
    var position: Int = 0

    val isAtEnd: Boolean
        get() = position >= text.length

    fun peek(): Char? = text.getOrNull(position)

    fun next(): Char {
        require(!isAtEnd) { "JSON が途中で終わっています" }
        position += 1
        return text[position - 1]
    }

    fun expect(char: Char) {
        require(peek() == char) { "JSON の $position 文字目に $char がありません" }
        position += 1
    }

    fun consume(char: Char): Boolean {
        if (peek() != char) return false
        position += 1
        return true
    }

    fun skipWhitespace() {
        while (peek()?.isWhitespace() == true) {
            position += 1
        }
    }
}

// Reads JSON values at [cursor].
private class JsonValues(
    private val cursor: JsonCursor,
) {
    fun read(): Any? {
        cursor.skipWhitespace()
        val next = cursor.peek()
        return when {
            next == '{' -> readObject()
            next == '[' -> readArray()
            next == '"' -> readString()
            next == '-' || next?.isDigit() == true -> readNumber()
            else -> readLiteral()
        }
    }

    private fun readObject(): Map<String, Any?> {
        val members = linkedMapOf<String, Any?>()
        cursor.expect('{')
        cursor.skipWhitespace()
        if (cursor.consume('}')) return members
        do {
            cursor.skipWhitespace()
            val key = readString()
            cursor.skipWhitespace()
            cursor.expect(':')
            members[key] = read()
            cursor.skipWhitespace()
        } while (cursor.consume(','))
        cursor.expect('}')
        return members
    }

    private fun readArray(): List<Any?> {
        val elements = mutableListOf<Any?>()
        cursor.expect('[')
        cursor.skipWhitespace()
        if (cursor.consume(']')) return elements
        do {
            elements += read()
            cursor.skipWhitespace()
        } while (cursor.consume(','))
        cursor.expect(']')
        return elements
    }

    private fun readString(): String {
        cursor.expect('"')
        val builder = StringBuilder()
        var next = cursor.next()
        while (next != '"') {
            builder.append(if (next == '\\') readEscape() else next)
            next = cursor.next()
        }
        return builder.toString()
    }

    private fun readEscape(): Char =
        when (val escaped = cursor.next()) {
            '"', '\\', '/' -> escaped
            'b' -> '\b'
            'f' -> '\u000C'
            'n' -> '\n'
            'r' -> '\r'
            't' -> '\t'
            'u' -> readUnicodeEscape()
            else -> throw IllegalArgumentException("JSON のエスケープ \\$escaped が読めません")
        }

    private fun readUnicodeEscape(): Char {
        val hex = (1..UNICODE_ESCAPE_LENGTH).map { cursor.next() }.joinToString(separator = "")
        return requireNotNull(hex.toIntOrNull(radix = HEX_RADIX)) { "JSON の \\u が16進数でありません" }.toChar()
    }

    private fun readNumber(): Double {
        val start = cursor.position
        while (cursor.peek()?.let { it.isDigit() || it in NUMBER_SIGNS } == true) {
            cursor.next()
        }
        val number = cursor.text.substring(startIndex = start, endIndex = cursor.position)
        return requireNotNull(number.toDoubleOrNull()) { "JSON の数が読めません" }
    }

    private fun readLiteral(): Boolean? {
        val literal =
            LITERALS.entries.firstOrNull { (word, _) ->
                cursor.text.startsWith(word, startIndex = cursor.position)
            }
        requireNotNull(literal) { "JSON の ${cursor.position} 文字目が読めません" }
        cursor.position += literal.key.length
        return literal.value
    }

    private companion object {
        val LITERALS: Map<String, Boolean?> = mapOf("true" to true, "false" to false, "null" to null)
    }
}
