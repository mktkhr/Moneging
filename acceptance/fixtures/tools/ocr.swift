// Reads the text of a receipt picture with Vision, one row of the receipt per
// output line, from the top of the receipt down.
//
// Usage: swift ocr.swift <image.jpg>
//
// The picture is first straightened as the document scanner straightens its
// pages: Vision finds the receipt's four corners
// (VNDetectDocumentSegmentationRequest) and CIPerspectiveCorrection maps them
// to an upright rectangle; a picture in which no receipt is found (a drawn
// receipt, all paper) is read as it is. The text is then recognised with
// recognitionLevel .accurate, recognitionLanguages ["ja-JP", "en-US"] and
// language correction left at its default. The output is what
// receipt-text/*.txt records.
import CoreImage
import Foundation
import Vision

/// Recognises the text of a picture.
internal enum Ocr {
    /// A piece of recognised text and where it lies, in Vision's normalised
    /// coordinates (origin bottom left).
    private struct Piece {
        /// The recognised text.
        let text: String
        /// The left edge.
        let minX: CGFloat
        /// The centre.
        let mid: CGPoint
        /// How much the text rises per unit of x (from the top-left to the top-right corner).
        let slope: CGFloat
        /// The height of the text (from the top-left to the bottom-left corner).
        let height: CGFloat

        init?(_ observation: VNRecognizedTextObservation) {
            guard let text = observation.topCandidates(1).first?.string else {
                return nil
            }
            let run: CGFloat = observation.topRight.x - observation.topLeft.x
            self.text = text
            minX = min(observation.topLeft.x, observation.bottomLeft.x)
            mid = CGPoint(x: observation.boundingBox.midX, y: observation.boundingBox.midY)
            slope = run > 0 ? (observation.topRight.y - observation.topLeft.y) / run : 0
            height = hypot(
                observation.topLeft.x - observation.bottomLeft.x,
                observation.topLeft.y - observation.bottomLeft.y
            )
        }
    }

    /// The exit status for a wrong command line or an unreadable picture.
    private static let usageStatus: Int32 = 2

    /// How sure Vision must be that it found a receipt for the picture to be
    /// straightened; a drawn receipt, all paper, scores 0.
    private static let documentConfidence: VNConfidence = 0.5

    /// How far apart (a fraction of the picture's width) two pieces of a row
    /// must be for the tilt to be learnt from them.
    private static let tiltSpan: CGFloat = 0.25

    /// Half, for half a text height and the median.
    private static let half: CGFloat = 2

    /// The arguments of a right command line: the script and the picture.
    private static let argumentCount: Int = 2

    /// The receipt in [image] straightened to an upright rectangle, or [image]
    /// when no receipt is found in it.
    private static func straightened(_ image: CIImage) throws -> CIImage {
        let request: VNDetectDocumentSegmentationRequest = VNDetectDocumentSegmentationRequest()
        try VNImageRequestHandler(ciImage: image).perform([request])
        guard let receipt = request.results?.first,
            receipt.confidence >= Self.documentConfidence,
            let filter = CIFilter(name: "CIPerspectiveCorrection")
        else { return image }
        let extent: CGRect = image.extent
        let corners: [(key: String, point: CGPoint)] = [
            ("inputTopLeft", receipt.topLeft), ("inputTopRight", receipt.topRight),
            ("inputBottomLeft", receipt.bottomLeft), ("inputBottomRight", receipt.bottomRight),
        ]
        filter.setValue(image, forKey: kCIInputImageKey)
        for corner in corners {
            let point: CIVector = CIVector(
                x: extent.minX + corner.point.x * extent.width,
                y: extent.minY + corner.point.y * extent.height
            )
            filter.setValue(point, forKey: corner.key)
        }
        return filter.outputImage ?? image
    }

    /// The rows of the receipt, top down, each left to right.
    ///
    /// A receipt row's name and amount are separate observations, and on a
    /// tilted or curled receipt the amount at the right edge sits above or
    /// below the name's centre, by more than half a line at the foot of a long
    /// curled receipt. So the pieces are taken top down, and a piece joins the
    /// row whose line (run from the row's first piece at the current tilt)
    /// passes within half a text height of its centre, the nearest such row,
    /// else it starts a row. The tilt starts at the median slope of the
    /// observations and is learnt again from each row that joins two pieces
    /// far apart, so it follows a receipt that curls as it goes down.
    private static func rows(of pieces: [Piece]) -> [[Piece]] {
        let slopes: [CGFloat] = pieces.map(\.slope).sorted()
        var tilt: CGFloat = slopes.isEmpty ? 0 : slopes[slopes.count / Int(Self.half)]
        var rows: [[Piece]] = []
        for piece in pieces.sorted(by: { $0.mid.y > $1.mid.y }) {
            let candidates: [(row: Int, distance: CGFloat)] = rows.indices.compactMap { index in
                let first: Piece = rows[index][0]
                let lineY: CGFloat = first.mid.y + tilt * (piece.mid.x - first.mid.x)
                let distance: CGFloat = abs(piece.mid.y - lineY)
                return distance < min(first.height, piece.height) / Self.half
                    ? (index, distance) : nil
            }
            guard let nearest = candidates.min(by: { $0.distance < $1.distance }) else {
                rows.append([piece])
                continue
            }
            let first: Piece = rows[nearest.row][0]
            if abs(piece.mid.x - first.mid.x) > Self.tiltSpan {
                tilt = (piece.mid.y - first.mid.y) / (piece.mid.x - first.mid.x)
            }
            rows[nearest.row].append(piece)
        }
        return rows.map { row in row.sorted { $0.minX < $1.minX } }
    }

    /// Prints the rows of the picture named on the command line.
    internal static func run() throws {
        guard CommandLine.arguments.count == Self.argumentCount,
            let image = CIImage(
                contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]),
                options: [.applyOrientationProperty: true]
            )
        else {
            FileHandle.standardError.write(Data("usage: swift ocr.swift <image.jpg>\n".utf8))
            exit(Self.usageStatus)
        }
        let receipt: CIImage = try Self.straightened(image)
        guard let picture = CIContext().createCGImage(receipt, from: receipt.extent) else {
            FileHandle.standardError.write(Data("cannot render \(CommandLine.arguments[1])\n".utf8))
            exit(Self.usageStatus)
        }
        let request: VNRecognizeTextRequest = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ja-JP", "en-US"]
        try VNImageRequestHandler(cgImage: picture).perform([request])

        // Vision returns the left and the right of a receipt row (a name and its
        // amount) as separate observations: they are joined left to right with
        // a space.
        let pieces: [Piece] = (request.results ?? []).compactMap(Piece.init)
        for row in Self.rows(of: pieces) {
            print(row.map(\.text).joined(separator: " "))
        }
    }
}

try Ocr.run()
