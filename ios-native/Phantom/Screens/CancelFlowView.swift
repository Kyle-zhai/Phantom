import SwiftUI
import PhotosUI

/// Guided cancel: open the real vendor path, then store proof on-device.
struct CancelFlowView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let subId: String

    private enum Step { case plan, doIt, evidence, done }
    @State private var step: Step = .plan
    @State private var confirmation = ""
    @State private var notes = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var screenshot: UIImage?
    @State private var awaitingReturn = false
    @State private var showDispute = false

    private var sub: Subscription? { store.subscription(byId: subId) }

    var body: some View {
        Group {
            if let sub {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        topBar
                        switch step {
                        case .plan: planStep(sub)
                        case .doIt: doItStep(sub)
                        case .evidence: evidenceStep(sub)
                        case .done: doneStep(sub)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            } else {
                Text("Not found").font(AppFont.h2).foregroundStyle(Palette.ink)
            }
        }
        .background(Palette.white)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showDispute) {
            DisputeLetterView(subId: subId).environment(store)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && awaitingReturn {
                awaitingReturn = false
                step = .evidence
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    screenshot = img
                }
            }
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
            Text("CANCEL").font(AppFont.smallB).foregroundStyle(Palette.mute)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 4)
    }

    private func planStep(_ sub: Subscription) -> some View {
        let path = CancellationRegistry.path(forSubscriptionId: sub.id, fallbackName: sub.name, billedViaApple: sub.billedVia == .apple)
        let steps = path.checklist(name: sub.name)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Avatar(label: sub.name, subscriptionId: sub.id, bg: sub.brandColor, fg: Palette.white, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cancel \(sub.name)").font(AppFont.h2).foregroundStyle(Palette.ink)
                    Text("Saves \(fmtUSD(sub.monthlyAmount))/mo · \(fmtUSD(sub.yearlyAmount))/yr")
                        .font(AppFont.small).foregroundStyle(Palette.mute)
                }
            }
            .padding(.top, 20)

            Text("Phantom opens the real cancel path. You finish it. Then we keep the proof on this iPhone so you can fight a charge that shouldn't have happened.")
                .font(AppFont.body).foregroundStyle(Palette.mute)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, text in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle().fill(Palette.ink).frame(width: 26, height: 26)
                            Text("\(i + 1)").font(AppFont.smallB).foregroundStyle(Palette.white)
                        }
                        Text(text).font(AppFont.body).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md))
            .padding(.top, 24)

            PrimaryButton("Start the checklist") { step = .doIt }
                .padding(.top, 24)
            PrimaryButton("I already cancelled — save proof", variant: .ghost) { step = .evidence }
                .padding(.top, 8)
        }
    }

    private func doItStep(_ sub: Subscription) -> some View {
        let path = CancellationRegistry.path(forSubscriptionId: sub.id, fallbackName: sub.name, billedViaApple: sub.billedVia == .apple)
        return VStack(alignment: .leading, spacing: 0) {
            Text("Do it now.")
                .font(AppFont.h1).foregroundStyle(Palette.ink)
                .padding(.top, 16)
            if let hint = path.hint {
                Text(hint)
                    .font(AppFont.body).foregroundStyle(Palette.mute)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            } else {
                Text("We'll open \(sub.name). Come back when you have a confirmation — or even if you don't.")
                    .font(AppFont.body).foregroundStyle(Palette.mute)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }

            if path.url != nil {
                PrimaryButton(path.actionLabel) {
                    if let url = path.url {
                        UIApplication.shared.open(url, options: [:]) { _ in }
                        awaitingReturn = true
                    }
                } leading: {
                    Image(systemName: path.isAppleManaged ? "applelogo" : (path.isPhone ? "phone.fill" : "arrow.up.right"))
                }
                .padding(.top, 24)
            }

            PrimaryButton("I'm back — save proof", variant: .secondary) { step = .evidence }
                .padding(.top, 12)
            PrimaryButton("It didn't work — dispute this charge", variant: .ghost) {
                showDispute = true
            }
            .padding(.top, 8)
        }
    }

    private func evidenceStep(_ sub: Subscription) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Keep the proof.")
                .font(AppFont.h1).foregroundStyle(Palette.ink)
                .padding(.top, 16)
            Text("Confirmation numbers and screenshots stay on this iPhone. If they charge you again, the dispute letter and chargeback packet can cite them.")
                .font(AppFont.body).foregroundStyle(Palette.mute)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            evidenceField("Confirmation number", text: $confirmation, placeholder: "Optional — e.g. CXL-48291")
            evidenceField("Notes", text: $notes, placeholder: "Optional — who you spoke to, what they promised")

            PhotosPicker(selection: $photoItem, matching: .images) {
                HStack(spacing: 12) {
                    if let screenshot {
                        Image(uiImage: screenshot)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: Radius.xs).fill(Palette.surface).frame(width: 56, height: 56)
                            Image(systemName: "camera").foregroundStyle(Palette.ink)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(screenshot == nil ? "Add confirmation screenshot" : "Replace screenshot")
                            .font(AppFont.bodyB).foregroundStyle(Palette.ink)
                        Text("Stays on this iPhone.").font(AppFont.small).foregroundStyle(Palette.mute)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
            }
            .padding(.top, 16)

            PrimaryButton("Mark cancelled") {
                commit(sub)
            }
            .padding(.top, 24)
            PrimaryButton("Skip proof — just mark cancelled", variant: .ghost) {
                commit(sub)
            }
            .padding(.top, 8)
        }
    }

    private func doneStep(_ sub: Subscription) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Circle().fill(Palette.success).frame(width: 72, height: 72)
                .overlay(Image(systemName: "checkmark").font(.system(size: 28, weight: .bold)).foregroundStyle(Palette.white))
                .padding(.top, 28)
            Text("Marked cancelled.")
                .font(AppFont.h1).foregroundStyle(Palette.ink)
                .padding(.top, 20)
            Text("Phantom can't watch \(sub.name). We'll remind you in about 5 weeks to re-scan your statement. If they charge you anyway, generate a dispute letter — the proof you just saved will be in it.")
                .font(AppFont.body).foregroundStyle(Palette.mute)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
            SavingsShareButton(amountYearly: sub.yearlyAmount, kind: .saved)
                .padding(.top, 24)
            PrimaryButton("Done") { dismiss() }
                .padding(.top, 16)
        }
    }

    private func evidenceField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(AppFont.smallB).foregroundStyle(Palette.mute)
            TextField(placeholder, text: text)
                .font(AppFont.body)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(Palette.border, lineWidth: 1))
        }
        .padding(.top, 16)
    }

    private func commit(_ sub: Subscription) {
        let path = CancellationRegistry.path(forSubscriptionId: sub.id, fallbackName: sub.name, billedViaApple: sub.billedVia == .apple)
        let method: String = {
            if path.isAppleManaged { return "apple" }
            if path.isPhone { return "phone" }
            if path.url == nil { return "in-person" }
            return "web"
        }()
        var hasShot = false
        if let screenshot {
            hasShot = EvidenceLocker.saveScreenshot(screenshot, for: sub.id)
        }
        EvidenceLocker.save(EvidenceLocker.Record(
            id: sub.id,
            confirmationNumber: confirmation.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespaces),
            cancelledAt: Date(),
            method: method,
            hasScreenshot: hasShot
        ))
        store.confirmCancellation(sub.id)
        step = .done
    }
}
