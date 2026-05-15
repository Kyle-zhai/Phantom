import SwiftUI

enum MeterSize {
    case sm, md, lg

    var height: CGFloat {
        switch self {
        case .sm: return 6
        case .md: return 8
        case .lg: return 10
        }
    }
}

struct ZombieMeter: View {
    let score: Int
    var size: MeterSize = .md
    var showLabel: Bool = true

    var color: Color {
        if score >= 80 { return Palette.danger }
        if score >= 50 { return Palette.warn }
        return Palette.success
    }

    var label: String {
        if score >= 80 { return "Zombie" }
        if score >= 50 { return "Review" }
        return "Keep"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.surface)
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, min(1, Double(score) / 100.0)) * geo.size.width)
                }
            }
            .frame(height: size.height)

            if size != .sm && showLabel {
                HStack {
                    Text(label).font(AppFont.smallB).foregroundStyle(color)
                    Spacer()
                    Text("\(score)/100").font(AppFont.smallB).foregroundStyle(Palette.mute)
                }
            }
        }
    }
}
