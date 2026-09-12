import SwiftUI
import PhotosUI
import AuthenticationServices

// Picks — the public app leaderboard — was built but parked before release
// on 2026-09-11; tab 3 now holds the For-you recommendations. The whole
// feature is compiled out of Release so the shipping app contains no
// CloudKit *public* database code at all, which is what the privacy policy
// promises ("no part of Phantom is public"). It stays behind DEBUG rather
// than being deleted so `--screen-picks` and PickTests keep working, and so
// reviving it is a one-line change to this guard.
#if DEBUG

/// Submit an app to the Picks leaderboard. Needs an account (Sign in with
/// Apple + iCloud) so the submission belongs to someone and can be moderated.
struct SubmitPickView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var picks = PicksService.shared
    @State private var account = AccountService.shared
    @State private var form = PickSubmission()
    @State private var pickerItem: PhotosPickerItem?
    @State private var preview: UIImage?
    @State private var submitting = false
    @State private var error: String?
    @State private var done: AppPick?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                if let done {
                    successCard(done)
                } else if !account.isSignedIn {
                    signInFirst
                } else {
                    formBody
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Palette.white)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let prepared = PickScreenshot.prepare(data) {
                    form.screenshot = prepared
                    preview = UIImage(data: prepared)
                }
            }
        }
    }

    private var signInFirst: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sign in to submit").font(AppFont.h1).foregroundStyle(Palette.ink).padding(.top, 18)
            Text("Submissions are tied to your account so you can see their status and so the board can be moderated. Your name is never shown.")
                .font(AppFont.body).foregroundStyle(Palette.mute)
                .fixedSize(horizontal: false, vertical: true)
            SignInWithAppleButton(.signIn) { request in
                account.configure(request)
            } onCompletion: { result in
                _ = account.handle(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
            .padding(.top, 12)
            if let err = account.lastError {
                Text(err).font(AppFont.small).foregroundStyle(Palette.danger)
            }
        }
    }

    private var formBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Submit your app").font(AppFont.h1).foregroundStyle(Palette.ink).padding(.top, 18)
            Text("What it's for, one line, one screenshot, a link. It goes live after a quick review; ranking is purely by how many people open it.")
                .font(AppFont.body).foregroundStyle(Palette.mute).padding(.top, 6)
                .fixedSize(horizontal: false, vertical: true)

            field("App name", text: $form.name, placeholder: "e.g. Fitbod", limit: PickSubmission.nameLimit)

            VStack(alignment: .leading, spacing: 8) {
                Text("Category").font(AppFont.smallB).foregroundStyle(Palette.mute)
                Picker("", selection: $form.category) {
                    ForEach(PickCategory.allCases) { c in
                        Label(c.rawValue, systemImage: c.symbol).tag(c)
                    }
                }
                .pickerStyle(.menu).tint(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(Palette.border, lineWidth: 1))
            }
            .padding(.top, 16)

            field("One-line intro", text: $form.tagline, placeholder: "What it does, in a sentence", limit: PickSubmission.taglineLimit)
            field("Description (optional)", text: $form.details, placeholder: "Who it's for and why you'd pay for it", limit: PickSubmission.detailsLimit, multiline: true)
            field("Website", text: $form.urlText, placeholder: "example.com", keyboard: .URL)
            field("App Store link (optional)", text: $form.appStoreText, placeholder: "https://apps.apple.com/…", keyboard: .URL)

            VStack(alignment: .leading, spacing: 8) {
                Text("Screenshot").font(AppFont.smallB).foregroundStyle(Palette.mute)
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    if let preview {
                        Image(uiImage: preview).resizable().scaledToFit()
                            .frame(maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Choose one screenshot").font(AppFont.smallB)
                        }
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                    }
                }
            }
            .padding(.top, 16)

            if let error {
                Text(error).font(AppFont.small).foregroundStyle(Palette.danger).padding(.top, 12)
            }

            PrimaryButton(submitting ? "Submitting…" : "Submit for review") { Task { await submit() } }
                .disabled(submitting)
                .padding(.top, 24)
            Text("Public once approved. Please only submit apps you're allowed to promote. No personal data is shown.")
                .font(AppFont.small).foregroundStyle(Palette.mute2)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
        }
    }

    private func successCard(_ pick: AppPick) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 34)).foregroundStyle(Palette.success).padding(.top, 20)
            Text("Submitted").font(AppFont.h1).foregroundStyle(Palette.ink)
            Text("\(pick.name) is in review. It appears in \(pick.category.rawValue) once approved — usually within a day — and you can follow its status under “Your submissions”.")
                .font(AppFont.body).foregroundStyle(Palette.mute)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton("Done") { dismiss() }.padding(.top, 16)
        }
    }

    private func submit() async {
        error = nil
        submitting = true
        defer { submitting = false }
        do {
            done = try await picks.submit(form)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, limit: Int? = nil, keyboard: UIKeyboardType = .default, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(AppFont.smallB).foregroundStyle(Palette.mute)
                Spacer()
                if let limit {
                    Text("\(text.wrappedValue.count)/\(limit)")
                        .font(AppFont.micro).foregroundStyle(text.wrappedValue.count > limit ? Palette.danger : Palette.mute2)
                }
            }
            Group {
                if multiline {
                    TextField(placeholder, text: text, axis: .vertical).lineLimit(3...6)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(AppFont.body).foregroundStyle(Palette.ink)
            .keyboardType(keyboard)
            .textInputAutocapitalization(keyboard == .URL ? .never : .sentences)
            .autocorrectionDisabled(keyboard == .URL)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(Palette.border, lineWidth: 1))
        }
        .padding(.top, 16)
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
            Text("SUBMIT A PICK").font(AppFont.smallB).foregroundStyle(Palette.mute)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 4)
    }
}

#endif
