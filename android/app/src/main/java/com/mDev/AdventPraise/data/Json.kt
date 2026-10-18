package com.mDev.AdventPraise.data

/**
 * A small JSON reader and writer, so the shared data files (hymnals, the
 * extras, the sheet music manifest and sync chunks) and the saved
 * playlists decode the same in the app and in plain JVM unit tests, where
 * android's org.json is only a stub.
 *
 * Objects decode to `Map<String, Any?>` (insertion order kept), arrays to
 * `List<Any?>`, numbers to `Long` when integral and `Double` otherwise,
 * plus `String`, `Boolean` and `null`.
 */
object Json {
    class ParseException(message: String) : Exception(message)

    fun parse(text: String): Any? {
        val parser = Parser(text)
        parser.skipSpace()
        val value = parser.value()
        parser.skipSpace()
        if (parser.i != text.length) throw ParseException("Trailing characters at ${parser.i}")
        return value
    }

    fun parseOrNull(text: String): Any? = runCatching { parse(text) }.getOrNull()

    /** Writes maps, lists, strings, numbers, booleans and null. */
    fun write(value: Any?): String = StringBuilder().also { write(value, it) }.toString()

    private fun write(value: Any?, out: StringBuilder) {
        when (value) {
            null -> out.append("null")
            is String -> quote(value, out)
            is Boolean -> out.append(value)
            is Int, is Long, is Short, is Byte -> out.append(value)
            is Double -> if (value % 1.0 == 0.0 && kotlin.math.abs(value) < 1e15) out.append(value.toLong()) else out.append(value)
            is Float -> write(value.toDouble(), out)
            is Number -> out.append(value)
            is Map<*, *> -> {
                out.append('{')
                var first = true
                for ((k, v) in value) {
                    if (!first) out.append(',')
                    first = false
                    quote(k.toString(), out)
                    out.append(':')
                    write(v, out)
                }
                out.append('}')
            }
            is Iterable<*> -> {
                out.append('[')
                var first = true
                for (v in value) {
                    if (!first) out.append(',')
                    first = false
                    write(v, out)
                }
                out.append(']')
            }
            is Array<*> -> write(value.toList(), out)
            is IntArray -> write(value.toList(), out)
            else -> quote(value.toString(), out)
        }
    }

    private fun quote(s: String, out: StringBuilder) {
        out.append('"')
        for (c in s) {
            when (c) {
                '"' -> out.append("\\\"")
                '\\' -> out.append("\\\\")
                '\n' -> out.append("\\n")
                '\r' -> out.append("\\r")
                '\t' -> out.append("\\t")
                '\b' -> out.append("\\b")
                '\u000C' -> out.append("\\f")
                else -> if (c < ' ') out.append(String.format("\\u%04x", c.code)) else out.append(c)
            }
        }
        out.append('"')
    }

    private class Parser(val s: String) {
        var i = 0

        fun skipSpace() {
            while (i < s.length && (s[i] == ' ' || s[i] == '\n' || s[i] == '\r' || s[i] == '\t')) i++
        }

        fun value(): Any? {
            if (i >= s.length) throw ParseException("Unexpected end")
            return when (val c = s[i]) {
                '{' -> obj()
                '[' -> array()
                '"' -> string()
                't' -> literal("true", true)
                'f' -> literal("false", false)
                'n' -> literal("null", null)
                else -> if (c == '-' || c in '0'..'9') number() else throw ParseException("Unexpected '$c' at $i")
            }
        }

        private fun literal(word: String, value: Any?): Any? {
            if (!s.startsWith(word, i)) throw ParseException("Expected $word at $i")
            i += word.length
            return value
        }

        private fun obj(): Map<String, Any?> {
            i++
            val map = LinkedHashMap<String, Any?>()
            skipSpace()
            if (i < s.length && s[i] == '}') { i++; return map }
            while (true) {
                skipSpace()
                if (i >= s.length || s[i] != '"') throw ParseException("Expected a key at $i")
                val key = string()
                skipSpace()
                if (i >= s.length || s[i] != ':') throw ParseException("Expected ':' at $i")
                i++
                skipSpace()
                map[key] = value()
                skipSpace()
                if (i >= s.length) throw ParseException("Unterminated object")
                when (s[i]) {
                    ',' -> i++
                    '}' -> { i++; return map }
                    else -> throw ParseException("Expected ',' or '}' at $i")
                }
            }
        }

        private fun array(): List<Any?> {
            i++
            val list = ArrayList<Any?>()
            skipSpace()
            if (i < s.length && s[i] == ']') { i++; return list }
            while (true) {
                skipSpace()
                list += value()
                skipSpace()
                if (i >= s.length) throw ParseException("Unterminated array")
                when (s[i]) {
                    ',' -> i++
                    ']' -> { i++; return list }
                    else -> throw ParseException("Expected ',' or ']' at $i")
                }
            }
        }

        private fun string(): String {
            i++
            val start = i
            // Fast path: no escapes.
            while (i < s.length && s[i] != '"' && s[i] != '\\') i++
            if (i < s.length && s[i] == '"') return s.substring(start, i).also { i++ }
            val out = StringBuilder().append(s, start, i)
            while (true) {
                if (i >= s.length) throw ParseException("Unterminated string")
                val c = s[i++]
                when (c) {
                    '"' -> return out.toString()
                    '\\' -> {
                        if (i >= s.length) throw ParseException("Bad escape")
                        when (val e = s[i++]) {
                            '"' -> out.append('"')
                            '\\' -> out.append('\\')
                            '/' -> out.append('/')
                            'b' -> out.append('\b')
                            'f' -> out.append('\u000C')
                            'n' -> out.append('\n')
                            'r' -> out.append('\r')
                            't' -> out.append('\t')
                            'u' -> {
                                if (i + 4 > s.length) throw ParseException("Bad unicode escape")
                                out.append(s.substring(i, i + 4).toInt(16).toChar())
                                i += 4
                            }
                            else -> throw ParseException("Bad escape '\\$e'")
                        }
                    }
                    else -> out.append(c)
                }
            }
        }

        private fun number(): Any {
            val start = i
            if (s[i] == '-') i++
            while (i < s.length && s[i] in '0'..'9') i++
            var integral = true
            if (i < s.length && s[i] == '.') {
                integral = false
                i++
                while (i < s.length && s[i] in '0'..'9') i++
            }
            if (i < s.length && (s[i] == 'e' || s[i] == 'E')) {
                integral = false
                i++
                if (i < s.length && (s[i] == '+' || s[i] == '-')) i++
                while (i < s.length && s[i] in '0'..'9') i++
            }
            val text = s.substring(start, i)
            if (integral) text.toLongOrNull()?.let { return it }
            return text.toDoubleOrNull() ?: throw ParseException("Bad number '$text'")
        }
    }
}

// Typed reads from decoded JSON.

@Suppress("UNCHECKED_CAST")
internal fun Any?.jsonObject(): Map<String, Any?>? = this as? Map<String, Any?>
internal fun Any?.jsonArray(): List<Any?>? = this as? List<Any?>
internal fun Any?.jsonInt(): Int? = (this as? Number)?.toInt()
internal fun Any?.jsonDouble(): Double? = (this as? Number)?.toDouble()
internal fun Any?.jsonString(): String? = this as? String
