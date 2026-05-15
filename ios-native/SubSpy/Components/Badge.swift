import SwiftUI

enum BadgeTone {
    case zombie, review, keep, warn, info, neutral

    var bg: Color {
        switch self {
        case .zombie: return Palette.dangerSoft
        case .review, .warn: return Palette.warnSoft
        case .keep: return Palette.successSoft
        case .info: return Palette.infoSoft
        case .neutral: return Palette.surface
        }
    }

    var fg: Color {
        switch self {
        case .zombie: return Palette.zombieFg
        case .review, .warn: return Palette.reviewFg
        case .keep: return Palette.keepFg
        case .info: return Palette.infoFg
        case .neutral: return Palette.ink
        }
    }
}

struct Badge: View {
    let label: String
    let tone: BadgeTone
    var icon: String? = nil

    init(_ label: String, tone: BadgeTone = .neutral, icon: String? = nil) {
        self.label = label
        self.tone = tone
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon).font(.system(size: 11, weight: .bold)) }
            Text(label).micro()
        }
        .foregroundStyle(tone.fg)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tone.bg, in: Capsule())
    }
}
