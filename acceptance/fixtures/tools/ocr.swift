// Reads the text of a receipt picture with Vision, one row of the receipt per
// output line, from the top of the picture down.
//
// Usage: swift ocr.swift <image.jpg>
//
// recognitionLevel .accurate, recognitionLanguages ["ja-JP", "en-US"], language
// correction left at its default. The output is what receipt-text/*.txt
// records.
import Foundation
import Vision

/// Recognises the text of a picture.
internal enum Ocr {
    /// The exit status for a wrong command line.
    private static let usageStatus: Int32 = 2

    /// The row a group of observations shares: those whose vertical centres
    /// are within half of a line of each other are one row.
    private static func rows(of observations: [VNRecognizedTextObservation])
        -> [[VNRecognizedTextObservation]]
    {
        var rows: [[VNRecognizedTextObservation]] = []
        for observation in observations {
            if let first = rows.last?.first,
                abs(first.boundingBox.midY - observation.boundingBox.midY)
                    < first.boundingBox.height / 2
            {
                rows[rows.count - 1].append(observation)
            } else {
                rows.append([observation])
            }
        }
        return rows
    }

    /// Prints the rows of the picture named on the command line.
    internal static func run() throws {
        guard CommandLine.arguments.count == 2 else {
            FileHandle.standardError.write(Data("usage: swift ocr.swift <image.jpg>\n".utf8))
            exit(Self.usageStatus)
        }
        let request: VNRecognizeTextRequest = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ja-JP", "en-US"]
        try VNImageRequestHandler(url: URL(fileURLWithPath: CommandLine.arguments[1]))
            .perform([request])

        // Vision returns the left and the right of a receipt row (a name and its
        // amount) as separate observations, in no reliable order: they are joined
        // left to right with a space.
        let observations: [VNRecognizedTextObservation] = (request.results ?? [])
            .sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        for row in Self.rows(of: observations) {
            let texts: [String] = row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                .compactMap { $0.topCandidates(1).first?.string }
            print(texts.joined(separator: " "))
        }
    }
}

try Ocr.run()
