import SwiftUI

/// The NMD (No Money Day) badge the calendar shows on a past day with no
/// spending: the default illustration, にっこり硬貨 (a smiling coin).
///
/// Hidden from VoiceOver: the day around it says `NMD`.
internal struct NmdBadge: View {
    /// The side of the square it is drawn in.
    internal let size: CGFloat

    internal var body: some View {
        Canvas { context, canvasSize in
            let unit: CGFloat = canvasSize.width / Theme.NmdCoin.canvas
            Self.draw(in: &context, unit: unit)
        }
        .frame(width: self.size, height: self.size)
        .accessibilityHidden(true)
    }

    private static func circle(center: CGPoint, radius: CGFloat, unit: CGFloat) -> Path {
        Path(
            ellipseIn: CGRect(origin: Self.scaled(center, unit), size: .zero)
                .insetBy(dx: -radius * unit, dy: -radius * unit),
        )
    }

    private static func scaled(_ point: CGPoint, _ unit: CGFloat) -> CGPoint {
        CGPoint(x: point.x * unit, y: point.y * unit)
    }

    private static func draw(in context: inout GraphicsContext, unit: CGFloat) {
        let coin: Theme.NmdCoin.Type = Theme.NmdCoin.self
        let center: CGPoint = CGPoint(x: coin.center, y: coin.center)
        let leftEye: CGPoint = CGPoint(x: coin.leftEyeX, y: coin.eyeY)
        let rightEye: CGPoint = CGPoint(x: coin.rightEyeX, y: coin.eyeY)

        let face: Path = Self.circle(center: center, radius: coin.radius, unit: unit)
        context.fill(face, with: .color(Theme.Reports.coinFill))
        context.stroke(face, with: .color(Theme.Reports.coinRim), lineWidth: coin.rimWidth * unit)

        let inner: Path = Self.circle(center: center, radius: coin.innerRadius, unit: unit)
        context.stroke(
            inner,
            with: .color(Theme.Reports.coinInnerRing),
            lineWidth: coin.innerWidth * unit,
        )

        for eye in [leftEye, rightEye] {
            let path: Path = Self.circle(center: eye, radius: coin.eyeRadius, unit: unit)
            context.fill(path, with: .color(Theme.Reports.coinFace))
        }

        var smile: Path = Path()
        smile.move(to: Self.scaled(CGPoint(x: coin.smileStartX, y: coin.smileY), unit))
        smile.addQuadCurve(
            to: Self.scaled(CGPoint(x: coin.smileEndX, y: coin.smileY), unit),
            control: Self.scaled(CGPoint(x: coin.center, y: coin.smileControlY), unit),
        )
        context.stroke(
            smile,
            with: .color(Theme.Reports.coinFace),
            style: StrokeStyle(lineWidth: coin.smileWidth * unit, lineCap: .round),
        )
    }
}

#Preview {
    NmdBadge(size: Theme.Reports.badgeSize)
}
