import SwiftUI

enum ButtonVariant {
    case primary, secondary, ghost, danger, light

    var bg: Color {
        switch self {
        case .primary: return Palette.black
        case .secondary: return Palette.white
        case .ghost: return .clear
        case .danger: return Palette.danger
        case .light: return Palette.white
        }
    }

    var fg: Color {
        switch self {
        case .primary, .danger: return Palette.white
        case .secondary, .ghost, .light: return Palette.ink
        }
    }

    var border: Color {
        switch self {
        case .secondary: return Palette.border
        default: return .clear
        }
    }
}

enum ButtonSize {
    case lg, md, sm

    var height: CGFloat {
        switch self {
        case .lg: return 56
        case .md: return 48
        case .sm: return 38
        }
    }

    var font: Font {
        switch self {
        case .lg, .md: return AppFont.bodyB
        case .sm: return AppFont.smallB
        }
    }
}

struct PrimaryButton<Leading: View, Trailing: View>: View {
    let label: String
    let variant: ButtonVariant
    let size: ButtonSize
    let fullWidth: Bool
    let action: () -> Void
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    @State private var isPressed = false

    init(
        _ label: String,
        variant: ButtonVariant = .primary,
        size: ButtonSize = .lg,
        fullWidth: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.label = label
        self.variant = variant
        self.size = size
        self.fullWidth = fullWidth
        self.action = action
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        Button {
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred()
            action()
        } label: {
            HStack(spacing: 8) {
                leading()
                Text(label).font(size.font).lineLimit(1)
                trailing()
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: size.height)
            .padding(.horizontal, 24)
            .foregroundStyle(variant.fg)
            .background(variant.bg, in: RoundedRectangle(cornerRadius: Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl)
                    .stroke(variant.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
