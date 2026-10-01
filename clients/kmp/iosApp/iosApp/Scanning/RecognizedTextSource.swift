#if DEBUG
    /// Which scan's recognised text `RecognizedTextSheet` shows: a draft's or a failed job's.
    internal enum RecognizedTextSource: Identifiable, Hashable {
        case draft(id: String)
        case job(id: String)

        internal var id: String {
            switch self {
            case .draft(let id):
                "draft-\(id)"

            case .job(let id):
                "job-\(id)"
            }
        }

        /// The draft's or the job's id.
        internal var scanId: String {
            switch self {
            case .draft(let id), .job(let id):
                id
            }
        }
    }
#endif
