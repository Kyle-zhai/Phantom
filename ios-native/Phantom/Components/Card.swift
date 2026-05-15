import SwiftUI

struct Card<Content: View>: View {
    let padded: Bool
    let background: Color
    let borderColor: Color
    @ViewBuilder var content: () -> Content

    init(padded: Bool = true, background: Color = Palette.white, borderColor: Color = Palette.border, @ViewBuilder content: @escaping () -> Content) {
        self.padded = padded
        self.background = background
        self.borderColor = borderColor
        self.content = content
    }

    var body: some View {
        content()
            .padding(padded ? 20 : 0)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}
