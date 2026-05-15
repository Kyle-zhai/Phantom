import SwiftUI

struct Avatar: View {
    let label: String
    var bg: Color = Palette.surface
    var fg: Color = Palette.ink
    var size: CGFloat = 44

    var body: some View {
        let initial = String(label.first.map(String.init) ?? "?").uppercased()
        Text(initial)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(fg)
            .frame(width: size, height: size)
            .background(bg, in: RoundedRectangle(cornerRadius: size <= 28 ? Radius.sm : Radius.md))
    }
}
