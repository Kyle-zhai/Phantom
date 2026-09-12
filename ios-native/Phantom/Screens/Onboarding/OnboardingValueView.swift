import SwiftUI

private struct ValueItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let body: String
}

private let items: [ValueItem] = [
    ValueItem(icon: "applelogo", title: "Find them in about a minute",
             body: "Start from the Apple subscriptions list iOS already keeps, or scan a statement / CSV. No bank login."),
    ValueItem(icon: "checklist", title: "Cancel with a checklist",
             body: "Verified cancel pages, phone numbers, and in-person instructions — then save the confirmation on this iPhone."),
    ValueItem(icon: "envelope", title: "Fight the charge",
             body: "EFTA/ROSCA letter first. If they ignore you, a chargeback script for the number on the back of your card."),
    ValueItem(icon: "bell", title: "Don't get surprised again",
             body: "Trial endings, price hikes, and a reminder to re-scan next month's statement."),
]

struct OnboardingValueView: View {
    @State private var goNext = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("2 / 4").font(AppFont.smallB).foregroundStyle(Palette.mute).padding(.top, 12)
                Text("Here's how you\nget the money back.")
                    .font(AppFont.h1)
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 18) {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 16) {
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .fill(Palette.surface)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: item.icon)
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundStyle(Palette.ink)
                                )
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                                Text(item.body).font(AppFont.small).foregroundStyle(Palette.mute)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.top, 28)

                PrimaryButton("Continue") { goNext = true }
                    .padding(.top, 32)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Palette.white)
        // Straight to the import step — we no longer gate activation behind a
        // name+email form. That data is only needed to sign dispute letters, so
        // it's collected at that moment instead (DisputeLetterView), keeping the
        // pre-value funnel friction-free.
        .navigationDestination(isPresented: $goNext) {
            OnboardingSignInView()
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
