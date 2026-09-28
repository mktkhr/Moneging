package io.github.mktkhr.moneging.state

/**
 * A household ledger ("家計簿"). Placeholder data: no persistence backs this
 * yet, only the shape the shared UI state exposes to the clients.
 */
data class Ledger(
    /** Stable identifier used to select this ledger. */
    val id: String,
    /** Display name shown as the tab screens' large title. */
    val name: String,
)
