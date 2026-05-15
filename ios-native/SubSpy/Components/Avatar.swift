import SwiftUI
import SVGView

/// Brand-aware avatar.
///
/// Renders the real CC0 brand SVG (from Resources/Brands/) on top of the brand
/// color background. Falls back to a first-letter avatar if no logo is known.
struct Avatar: View {
    let label: String
    let subscriptionId: String?
    var bg: Color
    var fg: Color
    var size: CGFloat

    init(
        label: String,
        subscriptionId: String? = nil,
        bg: Color? = nil,
        fg: Color = Palette.white,
        size: CGFloat = 44
    ) {
        self.label = label
        self.subscriptionId = subscriptionId
        self.fg = fg
        self.size = size

        if let id = subscriptionId, let brand = BrandRegistry.brand(for: id, fallbackName: label) {
            // Background is the brand's official hex, full saturation.
            self.bg = Color(hex: brand.hex) ?? bg ?? Palette.surface
        } else if let bg {
            self.bg = bg
        } else {
            self.bg = Palette.surface
        }
    }

    var body: some View {
        let brand = subscriptionId.flatMap { BrandRegistry.brand(for: $0, fallbackName: label) }
        let cornerRadius: CGFloat = size <= 28 ? Radius.sm : Radius.md

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius).fill(bg)
            if let brand,
               let url = Bundle.main.url(forResource: brand.svgName, withExtension: "svg") {
                SVGView(contentsOf: url)
                    .frame(width: size * 0.58, height: size * 0.58)
            } else {
                Text(String(label.first.map(String.init) ?? "?").uppercased())
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(fg)
            }
        }
        .frame(width: size, height: size)
    }
}
