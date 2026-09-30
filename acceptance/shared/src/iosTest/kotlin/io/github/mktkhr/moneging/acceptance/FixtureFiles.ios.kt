package io.github.mktkhr.moneging.acceptance

import kotlinx.cinterop.ByteVar
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.allocArray
import kotlinx.cinterop.convert
import kotlinx.cinterop.memScoped
import kotlinx.cinterop.toKString
import kotlinx.cinterop.usePinned
import platform.posix.F_OK
import platform.posix.PATH_MAX
import platform.posix.SEEK_END
import platform.posix.SEEK_SET
import platform.posix.access
import platform.posix.fclose
import platform.posix.fopen
import platform.posix.fread
import platform.posix.fseek
import platform.posix.ftell
import platform.posix.getcwd
import platform.posix.getenv

@OptIn(ExperimentalForeignApi::class)
internal actual fun readFixtureFile(relativePath: String): ByteArray {
    val root =
        getenv(FIXTURES_ENVIRONMENT_VARIABLE)?.toKString()
            ?: findFixturesDirectory(start = workingDirectory()) { path -> access("$path/receipts", F_OK) == 0 }
            ?: error("acceptance/fixtures が見つからない")
    return readFile(path = "$root/$relativePath")
}

@OptIn(ExperimentalForeignApi::class)
private fun workingDirectory(): String =
    memScoped {
        val buffer = allocArray<ByteVar>(PATH_MAX)
        getcwd(buffer, PATH_MAX.convert())?.toKString().orEmpty()
    }

@OptIn(ExperimentalForeignApi::class)
private fun readFile(path: String): ByteArray {
    val file = fopen(path, "rb") ?: error("$path を開けない")
    try {
        fseek(file, 0, SEEK_END)
        val size = ftell(file).toInt()
        fseek(file, 0, SEEK_SET)
        val bytes = ByteArray(size)
        bytes.usePinned { pinned -> fread(pinned.addressOf(0), 1.convert(), size.convert(), file) }
        return bytes
    } finally {
        fclose(file)
    }
}
