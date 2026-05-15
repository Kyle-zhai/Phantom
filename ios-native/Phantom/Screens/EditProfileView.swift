import SwiftUI

/// Lets the user update the name + email used to sign dispute letters and
/// retention scripts. Mirrors the onboarding profile screen so the field
/// styles stay consistent across the app. Profile data lives only in
/// SwiftData — nothing is sent off-device.
struct EditProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var email: String = ""

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && email.contains("@") && email.contains(".")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                hero
                field(label: "Full name", text: $name,
                      placeholder: "As it appears on your card", keyboard: .default)
                field(label: "Email", text: $email,
                      placeholder: "you@example.com", keyboard: .emailAddress)

                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill").foregroundStyle(Palette.success)
                    Text("On-device only. We never see your name or email.")
                        .font(AppFont.small).foregroundStyle(Palette.ink)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.successSoft, in: RoundedRectangle(cornerRadius: Radius.md))
                .padding(.top, 22)

                PrimaryButton("Save changes") {
                    store.setProfile(
                        name: name.trimmingCharacters(in: .whitespaces),
                        email: email.trimmingCharacters(in: .whitespaces)
                    )
                    dismiss()
                }
                .disabled(!valid)
                .opacity(valid ? 1 : 0.4)
                .padding(.top, 28)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Palette.white)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            name = store.profile?.fullName ?? ""
            email = store.profile?.email ?? ""
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 40, height: 40)
                    .background(Palette.surface, in: Circle())
            }
            Spacer()
            Text("EDIT PROFILE").font(AppFont.smallB).foregroundStyle(Palette.mute)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 4)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Update your name\nor email.")
                .font(AppFont.h1).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Used on dispute letters and retention scripts. Stored only on this device.")
                .font(AppFont.body).foregroundStyle(Palette.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 16)
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
