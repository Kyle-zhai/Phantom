import SwiftUI

/// Step 2.5: capture the user's name and email so dispute letters and
/// retention scripts are personalized. Data lives only in the device's
/// SwiftData store — never sent to any server.
struct OnboardingProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var name = ""
    @State private var email = ""
    @State private var goNext = false

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && email.contains("@") && email.contains(".")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Almost there.").font(AppFont.smallB).foregroundStyle(Palette.mute).padding(.top, 12)
                Text("Who should we write\nyour letters as?")
                    .font(AppFont.h1).foregroundStyle(Palette.ink)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
                Text("We sign every dispute letter and retention message with your real name and email. Both are stored on your device and never sent to us.")
                    .font(AppFont.body).foregroundStyle(Palette.mute)
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)

                field(label: "Full name", text: $name, placeholder: "As it appears on your card", keyboard: .default)
                field(label: "Email", text: $email, placeholder: "you@example.com", keyboard: .emailAddress)

                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill").foregroundStyle(Palette.success)
                    Text("On-device only. We never see your name or email.")
                        .font(AppFont.small).foregroundStyle(Palette.ink)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.successSoft, in: RoundedRectangle(cornerRadius: Radius.md))
                .padding(.top, 22)

                PrimaryButton("Continue") {
                    store.setProfile(name: name.trimmingCharacters(in: .whitespaces),
                                     email: email.trimmingCharacters(in: .whitespaces))
                    goNext = true
                }
                .disabled(!valid)
                .opacity(valid ? 1 : 0.4)
                .padding(.top, 32)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Palette.white)
        .navigationDestination(isPresented: $goNext) {
            OnboardingConnectView()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func field(label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(AppFont.smallB).foregroundStyle(Palette.mute)
            TextField(placeholder, text: text)
                .font(AppFont.body)
                .foregroundStyle(Palette.ink)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .autocorrectionDisabled(keyboard == .emailAddress)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(Palette.border, lineWidth: 1))
        }
        .padding(.top, 18)
    }
}
