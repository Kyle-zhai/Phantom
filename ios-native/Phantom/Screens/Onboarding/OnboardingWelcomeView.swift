import SwiftUI

struct OnboardingWelcomeView: View {
    @State private var goNext = false

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.black.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        PhantomMark(size: 36, foreground: Palette.black, background: Palette.white)
                        Text("Phantom").font(AppFont.h3).foregroundStyle(Palette.white)
                    }
                    .padding(.top, 16)

                    Spacer()

                    VStack(alignment: .leading, spacing: 20) {
                        Text("Find the\nmoney\nyou're losing.")
                            .font(AppFont.display)
                            .foregroundStyle(Palette.white)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("The average American pays for 4.5 subscriptions they never use. Phantom finds them, scores them, and helps you cancel — in seconds.")
                            .font(AppFont.body)
                            .foregroundStyle(Palette.mute2)
                            .frame(maxWidth: 320, alignment: .leading)
                    }

                    Spacer()

                    VStack(spacing: 14) {
                        PrimaryButton("Get started", variant: .light) {
                            goNext = true
                        }
                        Text("We don't sell your data. We don't push loans.")
                            .font(AppFont.small)
                            .foregroundStyle(Palette.mute)
                    }
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 20)
            }
            .navigationDestination(isPresented: $goNext) {
                OnboardingValueView()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    OnboardingWelcomeView()
        .environment(AppStore(purchaseService: PurchaseService.shared))
}
