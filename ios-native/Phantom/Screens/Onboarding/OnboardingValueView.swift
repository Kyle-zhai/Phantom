import SwiftUI

private struct ValueItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let body: String
}

private let items: [ValueItem] = [
    ValueItem(icon: "dot.radiowaves.left.and.right", title: "Subscription Radar",
             body: "We scan every recurring charge — Netflix, Hulu, that gym you forgot about."),
    ValueItem(icon: "waveform.path.ecg", title: "Zombie Score",
             body: "0–100 score per subscription. You see exactly which ones are bleeding you dry."),
    ValueItem(icon: "envelope", title: "Dispute Letters",
             body: "One tap = an EFTA-compliant letter to claim back wrongful charges."),
    ValueItem(icon: "bell", title: "Price-Hike Alerts",
             body: "7 days before any price increase. No more surprise charges."),
]

struct OnboardingValueView: View {
    @State private var goNext = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("2 / 3").font(AppFont.smallB).foregroundStyle(Palette.mute).padding(.top, 12)
                Text("Here's what you\nget.")
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
        .navigationDestination(isPresented: $goNext) {
            OnboardingProfileView()
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
