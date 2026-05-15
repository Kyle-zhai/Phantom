import SwiftUI

/// In-app brand mark — the same ghost silhouette used in the App Store icon,
/// rendered as a SwiftUI Shape so it stays crisp at any size.
struct PhantomMark: View {
    let size: CGFloat
    var foreground: Color = Palette.white
    var background: Color = Palette.black

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22).fill(background)
            GhostShape()
                .fill(foreground)
                .frame(width: size * 0.56, height: size * 0.62)
                .offset(y: size * 0.02)
            GhostEyes(scale: size)
                .offset(y: -size * 0.07)
        }
        .frame(width: size, height: size)
    }
}

/// The ghost outline path — top semicircle + flat sides + wavy bottom (4 humps).
private struct GhostShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let topR = w / 2
        let shoulderY = topR
        let bottomY = h
        let humpCount: Int = 4
        let humpW = w / CGFloat(humpCount)
        let humpDepth = h * 0.07

        // Top semicircle bulging up
        path.move(to: CGPoint(x: 0, y: bottomY))
        path.addLine(to: CGPoint(x: 0, y: shoulderY))
        path.addArc(
            center: CGPoint(x: topR, y: shoulderY),
            radius: topR,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: w, y: bottomY))

        // Wavy bottom right → left, dipping UP into body
        for i in 0..<humpCount {
            let xRight = w - CGFloat(i) * humpW
            let xLeft = xRight - humpW
            let mid = (xRight + xLeft) / 2
            path.addQuadCurve(
                to: CGPoint(x: xLeft, y: bottomY),
                control: CGPoint(x: mid, y: bottomY - humpDepth)
            )
        }
        path.closeSubpath()
        return path
    }
}

/// Two solid eyes inside the ghost.
private struct GhostEyes: View {
    let scale: CGFloat
    var body: some View {
        HStack(spacing: scale * 0.14) {
            Circle().fill(Palette.black).frame(width: scale * 0.07, height: scale * 0.09)
            Circle().fill(Palette.black).frame(width: scale * 0.07, height: scale * 0.09)
        }
    }
}
