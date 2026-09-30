package io.github.mktkhr.moneging.acceptance

import java.io.File

internal actual fun readFixtureFile(relativePath: String): ByteArray {
    val root =
        System.getenv(FIXTURES_ENVIRONMENT_VARIABLE)
            ?: findFixturesDirectory(start = File("").absolutePath) { path -> File(path, "receipts").isDirectory }
            ?: error("acceptance/fixtures が見つからない")
    return File(root, relativePath).readBytes()
}
