import SwiftUI

enum Palette {
    static let ink         = Color(red: 0.039, green: 0.039, blue: 0.039)
    static let black       = Color.black
    static let white       = Color.white
    static let mute        = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let mute2       = Color(red: 0.61, green: 0.64, blue: 0.69)
    static let border      = Color(red: 0.898, green: 0.906, blue: 0.922)
    static let surface     = Color(red: 0.957, green: 0.957, blue: 0.961)
    static let surface2    = Color(red: 0.98, green: 0.98, blue: 0.98)
    static let success     = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let successSoft = Color(red: 0.82, green: 0.98, blue: 0.91)
    static let danger      = Color(red: 0.937, green: 0.267, blue: 0.267)
    static let dangerSoft  = Color(red: 0.996, green: 0.894, blue: 0.886)
    static let warn        = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let warnSoft    = Color(red: 0.996, green: 0.953, blue: 0.776)
    static let info        = Color(red: 0.231, green: 0.510, blue: 0.965)
    static let infoSoft    = Color(red: 0.859, green: 0.918, blue: 0.996)
    static let zombieFg    = Color(red: 0.6, green: 0.106, blue: 0.110)
    static let reviewFg    = Color(red: 0.573, green: 0.251, blue: 0.055)
    static let keepFg      = Color(red: 0.024, green: 0.373, blue: 0.275)
    static let infoFg      = Color(red: 0.118, green: 0.251, blue: 0.686)
}

enum Radius {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let pill: CGFloat = 999
}

enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

enum AppFont {
    static let display = Font.system(size: 44, weight: .heavy)
    static let h1      = Font.system(size: 32, weight: .heavy)
    static let h2      = Font.system(size: 24, weight: .bold)
    static let h3      = Font.system(size: 18, weight: .bold)
    static let body    = Font.system(size: 16, weight: .regular)
    static let bodyB   = Font.system(size: 16, weight: .semibold)
    static let small   = Font.system(size: 13, weight: .regular)
    static let smallB  = Font.system(size: 13, weight: .semibold)
    static let micro   = Font.system(size: 11, weight: .bold)
}

extension Text {
    func micro() -> some View {
        self.font(AppFont.micro)
            .tracking(0.4)
            .textCase(.uppercase)
    }
}

func fmtUSD(_ amount: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "USD"
    f.locale = Locale(identifier: "en_US")
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    return f.string(from: NSNumber(value: amount)) ?? "$\(amount)"
}

func fmtRelDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US")
    f.dateFormat = "MMM d, yyyy"
    return f.string(from: date)
}
