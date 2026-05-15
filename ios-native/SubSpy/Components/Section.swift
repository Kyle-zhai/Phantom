import SwiftUI

struct SectionHeader<Right: View>: View {
    let title: String?
    let caption: String?
    @ViewBuilder var right: () -> Right

    init(_ title: String? = nil, caption: String? = nil, @ViewBuilder right: @escaping () -> Right = { EmptyView() }) {
        self.title = title
        self.caption = caption
        self.right = right
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title).font(AppFont.h3).foregroundStyle(Palette.ink)
                }
                if let caption {
                    Text(caption).font(AppFont.small).foregroundStyle(Palette.mute)
                }
            }
            Spacer(minLength: 0)
            right()
        }
    }
}
