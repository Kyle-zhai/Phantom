import SwiftUI
import AuthenticationServices

/// Step 3 of onboarding: attach an Apple account so everything Phantom finds
/// is saved to the user's own iCloud. Optional — the app works without it.
struct OnboardingSignInView: View {
    @Environment(AppStore.self) private var store
    @State private var account = AccountService.shared
    @State private var goNext = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("3 / 4").font(AppFont.smallB).foregroundStyle(Palette.mute).padding(.top, 12)
                Text("Keep it on\nevery iPhone.")
                    .font(AppFont.h1).foregroundStyle(Palette.ink).padding(.top, 8)
                Text("Sign in with Apple and everything Phantom finds — subscriptions, ratings, cancel proof, dispute letters — is saved to your own iCloud. There is no Phantom server; we never see it.")
                    .font(AppFont.body).foregroundStyle(Palette.mute).padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 14) {
                    benefit("arrow.triangle.2.circlepath", "Restored automatically on a new iPhone")
                    benefit("checkmark.shield", "Your name and email only sign dispute letters")
                    benefit("trash", "Delete your account and its data any time")
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                .padding(.top, 24)

                SignInWithAppleButton(.signIn) { request in
                    account.configure(request)
                } onCompletion: { result in
                    if account.handle(result) {
                        prefillProfile()
                        goNext = true
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                .padding(.top, 28)

                if let err = account.lastError {
                    Text(err).font(AppFont.small).foregroundStyle(Palette.danger).padding(.top, 10)
                }

                PrimaryButton("Continue without an account", variant: .ghost) { goNext = true }
                    .padding(.top, 12)
                Text("You can sign in later from Settings. Without an account, data stays on this iPhone only.")
                    .font(AppFont.small).foregroundStyle(Palette.mute2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Palette.white)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $goNext) {
            OnboardingConnectView()
        }
    }

    private func benefit(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Palette.ink).font(.system(size: 16, weight: .semibold)).frame(width: 24)
            Text(text).font(AppFont.body).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Apple only hands over name/email on the first authorization; use
    /// them for the dispute-letter signature unless the user already typed one.
    private func prefillProfile() {
        let name = (store.profile?.fullName ?? "").isEmpty ? account.displayName : (store.profile?.fullName ?? "")
        let email = (store.profile?.email ?? "").isEmpty ? account.email : (store.profile?.email ?? "")
        if !name.isEmpty || !email.isEmpty {
            store.setProfile(name: name, email: email)
        }
    }
}
