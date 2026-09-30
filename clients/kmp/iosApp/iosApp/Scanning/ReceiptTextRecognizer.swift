import Foundation
import Vision

/// Reads the text of a receipt photo with Vision, one row of the receipt
/// per line, from the top of the photo down.
///
/// Recognition level `.accurate`, languages `ja-JP` then `en-US`, language
/// correction at its default: the settings `acceptance/fixtures/tools/ocr.swift`
/// recorded the fixtures' text with, so the rule-based parser reads the
/// same shape of text on the device.
internal enum ReceiptTextRecognizer {
    /// The languages recognised, Japanese first.
    private static let languages: [String] = ["ja-JP", "en-US"]

    /// Half of a row's height: observations whose vertical centres are
    /// closer than this to a row's first are part of that row.
    private static let rowTolerance: CGFloat = 0.5

    /// The text of the photo `image`, one receipt row per line.
    internal static func text(of image: Data) throws -> String {
        let request: VNRecognizeTextRequest = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = Self.languages
        try VNImageRequestHandler(data: image).perform([request])

        // Vision returns the left and the right of a receipt row (a name and
        // its amount) as separate observations, in no reliable order: they
        // are joined left to right with a space.
        let observations: [VNRecognizedTextObservation] = (request.results ?? [])
            .sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        return Self.rows(of: observations)
            .map { row in
                row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")
            }
            .joined(separator: "\n")
    }

    /// The rows the observations make: those whose vertical centres are
    /// within half of a line of each other are one row.
    private static func rows(
        of observations: [VNRecognizedTextObservation],
    ) -> [[VNRecognizedTextObservation]] {
        var rows: [[VNRecognizedTextObservation]] = []
        for observation in observations {
            let isSameRow: Bool =
                rows.last?.first.map { first in
                    abs(first.boundingBox.midY - observation.boundingBox.midY)
                        < first.boundingBox.height * Self.rowTolerance
                } ?? false
            if isSameRow {
                rows[rows.count - 1].append(observation)
            } else {
                rows.append([observation])
            }
        }
        return rows
    }
}
