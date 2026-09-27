package io.github.mktkhr.moneging

interface Platform {
    val name: String
}

expect fun getPlatform(): Platform