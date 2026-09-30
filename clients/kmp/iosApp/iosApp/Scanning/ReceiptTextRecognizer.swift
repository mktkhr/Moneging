import CoreImage
import Foundation
import Vision

/// Reads the text of a receipt photo with Vision, one row of the receipt per
/// line, from the top of the receipt down.
///
/// Ported from `acceptance/fixtures/tools/ocr.swift`, which recorded the
/// fixtures' text, so the rule-based parser reads the same shape of text on
/// the device. The photo is first straightened as the document scanner
/// straightens its pages: Vision finds the receipt's four corners
/// (VNDetectDocumentSegmentationRequest) and CIPerspectiveCorrection maps
/// them to an upright rectangle. A photo in which no receipt is found, or
/// whose receipt already fills it (a page of the document scanner, already
/// straightened), is read as it is. The text is then recognised with
/// recognitionLevel .accurate, recognitionLanguages ["ja-JP", "en-US"] and
/// language correction left at its default.
internal enum ReceiptTextRecognizer {
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
            guard let candidate = observation.topCandidates(1).first?.string else {
                return nil
            }
            let run: CGFloat = observation.topRight.x - observation.topLeft.x
            self.text = candidate
            self.minX = min(observation.topLeft.x, observation.bottomLeft.x)
            self.mid = CGPoint(x: observation.boundingBox.midX, y: observation.boundingBox.midY)
            self.slope = run > 0 ? (observation.topRight.y - observation.topLeft.y) / run : 0
            self.height = hypot(
                observation.topLeft.x - observation.bottomLeft.x,
                observation.topLeft.y - observation.bottomLeft.y
            )
        }
    }

    /// The languages recognised, Japanese first.
    private static let languages: [String] = ["ja-JP", "en-US"]

    /// How sure Vision must be that it found a receipt for the picture to be
    /// straightened; a drawn receipt, all paper, scores 0.
    private static let documentConfidence: VNConfidence = 0.5

    /// The share of the picture a receipt found in it must leave uncovered
    /// for the picture to be straightened: a page of the document scanner is
    /// the receipt edge to edge, already straightened, and is not again.
    private static let pageCoverage: CGFloat = 0.9

    /// The share of the picture's longer side a receipt found in it must
    /// span for the picture to be straightened: a receipt is photographed to
    /// fill the frame, and a smaller region found in it (the card slip at its
    /// foot, as the simulator's Vision finds) is a part, not the receipt.
    private static let receiptSpan: CGFloat = 0.6

    /// How far apart (a fraction of the picture's width) two pieces of a row
    /// must be for the tilt to be learnt from them.
    private static let tiltSpan: CGFloat = 0.25

    /// Half, for half a text height and the median.
    private static let half: CGFloat = 2

    /// The text of the photo `image`, one receipt row per line.
    internal static func text(of image: Data) throws -> String {
        guard let photo = CIImage(data: image, options: [.applyOrientationProperty: true]) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let receipt: CIImage = try Self.straightened(photo)
        guard let picture = CIContext().createCGImage(receipt, from: receipt.extent) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let request: VNRecognizeTextRequest = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = Self.languages
        try VNImageRequestHandler(cgImage: picture).perform([request])

        // Vision returns the left and the right of a receipt row (a name and its
        // amount) as separate observations: they are joined left to right with
        // a space.
        let pieces: [Piece] = (request.results ?? []).compactMap(Piece.init)
        return Self.rows(of: pieces)
            .map { row in row.map(\.text).joined(separator: " ") }
            .joined(separator: "\n")
    }

    /// The receipt in `image` straightened to an upright rectangle, or `image`
    /// when no receipt is found in it or the receipt already fills it.
    private static func straightened(_ image: CIImage) throws -> CIImage {
        let request: VNDetectDocumentSegmentationRequest = VNDetectDocumentSegmentationRequest()
        try VNImageRequestHandler(ciImage: image).perform([request])
        guard let receipt = request.results?.first,
            receipt.confidence >= Self.documentConfidence,
            Self.area(of: receipt) < Self.pageCoverage,
            Self.span(of: receipt, in: image.extent) >= Self.receiptSpan,
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

    /// The share of the picture the four corners of `receipt` enclose (the
    /// shoelace formula over its normalised corners).
    private static func area(of receipt: VNRectangleObservation) -> CGFloat {
        let corners: [CGPoint] = [
            receipt.topLeft, receipt.topRight, receipt.bottomRight, receipt.bottomLeft,
        ]
        let twice: CGFloat = corners.indices.reduce(0) { sum, index in
            let next: CGPoint = corners[(index + 1) % corners.count]
            return sum + corners[index].x * next.y - next.x * corners[index].y
        }
        return abs(twice) / Self.half
    }

    /// The longest side of `receipt` as a share of the longer side of
    /// `extent`, the picture it was found in.
    private static func span(of receipt: VNRectangleObservation, in extent: CGRect) -> CGFloat {
        let corners: [CGPoint] = [
            receipt.topLeft, receipt.topRight, receipt.bottomRight, receipt.bottomLeft,
        ]
        .map { corner in CGPoint(x: corner.x * extent.width, y: corner.y * extent.height) }
        let sides: [CGFloat] = corners.indices.map { index in
            let next: CGPoint = corners[(index + 1) % corners.count]
            return hypot(next.x - corners[index].x, next.y - corners[index].y)
        }
        let longest: CGFloat = sides.max() ?? 0
        let longer: CGFloat = max(extent.width, extent.height)
        return longer > 0 ? longest / longer : 0
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
}
