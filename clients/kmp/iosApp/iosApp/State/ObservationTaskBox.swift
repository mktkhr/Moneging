/// A `Task` handle `SharedStateStore.deinit` can cancel without main-actor
/// isolation.
///
/// `@unchecked Sendable`: `task` is written once, from `init`
/// (main-actor), before `SharedStateStore` ever hands this box out (it
/// never does - `SharedStateStore.observationTask` is private), and read
/// once, from `deinit`, which only ever runs after every other reference to
/// the owning `SharedStateStore` (and so to this box) is gone; those two
/// accesses cannot race with each other or with anything else.
internal final class ObservationTaskBox: @unchecked Sendable {
    internal var task: Task<Void, Never>?

    internal init() {
        // No setup needed; explicit per the project's lint policy.
    }

    deinit {
        // No teardown needed; explicit per the project's lint policy.
    }
}
