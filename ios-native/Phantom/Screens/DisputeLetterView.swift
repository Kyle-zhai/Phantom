import SwiftUI
import MessageUI

private enum Step {
    case form, preview, sent
}

struct DisputeLetterView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let subId: String

    @State private var step: Step = .form
    @State private var form: DisputeForm
    @State private var copied = false
    @State private var showMail = false
    @State private var mailUnavailable = false
    @State private var showPaywall = false

    init(subId: String) {
        self.subId = subId
        let d = DateFormatter()
        d.dateFormat = "MMM d, yyyy"
        let chargeDate = d.string(from: Date().addingTimeInterval(-6 * 86_400))
        // Amount + profile populated in .onAppear once we have the store/sub
        _form = State(initialValue: DisputeForm(chargeDate: chargeDate, amount: 0))
    }

    var body: some View {
        Group {
            if let sub = store.subscription(byId: subId) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        topBar
                        HStack(spacing: 14) {
                            Avatar(label: sub.name, subscriptionId: sub.id, bg: sub.brandColor, fg: Palette.white, size: 56)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Refund from \(sub.name)").font(AppFont.h2).foregroundStyle(Palette.ink)
                                Text("We generate the letter — you send it. EFTA-compliant language.")
                                    .font(AppFont.small).foregroundStyle(Palette.mute)
                            }
                        }
                        .padding(.top, 20)

                        switch step {
                        case .form: formStep
                        case .preview: previewStep(for: sub)
                        case .sent: sentStep
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            } else {
                Text("Not found").font(AppFont.h2).foregroundStyle(Palette.ink)
            }
        }
        .background(Palette.white)
        .onAppear {
            // Seed amount + name + email from real data on first appear.
            if form.amount == 0, let sub = store.subscription(byId: subId) {
                form.amount = sub.amount
            }
            if form.fullName.isEmpty, let p = store.profile {
                form.fullName = p.fullName
                form.email = p.email
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
            Text("DISPUTE LETTER").font(AppFont.smallB).foregroundStyle(Palette.mute)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 4)
    }

    private var formStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepDots(active: 1)
            Text("Why are you disputing?").font(AppFont.h3).foregroundStyle(Palette.ink).padding(.top, 20)
            VStack(spacing: 10) {
                ForEach(DisputeReason.allCases) { r in
                    Button { form.reason = r } label: {
                        reasonRow(r)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.top, 12)

            Text("Charge details").font(AppFont.h3).foregroundStyle(Palette.ink).padding(.top, 28)
            FieldView(label: "Date of charge", text: $form.chargeDate, placeholder: "e.g. May 8, 2026")
            FieldView(label: "Amount disputed", text: amountBinding(), placeholder: "0.00", keyboard: .decimalPad, prefix: "$")
            FieldView(label: "Reference / Transaction ID (optional)", text: $form.referenceNumber, placeholder: "e.g. PMT-X92K-LL3")

            Text("Your contact info").font(AppFont.h3).foregroundStyle(Palette.ink).padding(.top, 28)
            FieldView(label: "Full name", text: $form.fullName, placeholder: "As on your card")
            FieldView(label: "Email", text: $form.email, placeholder: "you@example.com", keyboard: .emailAddress)

            if store.canGenerateDispute {
                PrimaryButton("Preview letter") {
                    step = .preview
                } trailing: {
                    Image(systemName: "arrow.right")
                }
                .padding(.top, 24)
                if !store.isPro {
                    Text("Free tier: \(store.disputesRemainingThisMonth) dispute remaining this month.")
                        .font(AppFont.small).foregroundStyle(Palette.mute)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
            } else {
                Card(background: Palette.surface, borderColor: Palette.surface) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { ProTag(); Spacer() }
                        Text("Free dispute already used this month")
                            .font(AppFont.bodyB).foregroundStyle(Palette.ink)
                        Text("Pro unlocks unlimited dispute letters. Next free letter resets on the 1st.")
                            .font(AppFont.small).foregroundStyle(Palette.mute)
                            .fixedSize(horizontal: false, vertical: true)
                        Button { showPaywall = true } label: {
                            Text("Unlock with Pro").font(AppFont.smallB)
                                .foregroundStyle(Palette.white)
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(Palette.ink, in: Capsule())
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 24)
            }
        }
    }

    private func previewStep(for sub: Subscription) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            stepDots(active: 2)
            VStack(alignment: .leading, spacing: 10) {
                Badge(form.reason.label, tone: .info)
                Text(fmtUSD(form.amount)).font(AppFont.h2).foregroundStyle(Palette.ink)
                Text("Dated \(form.chargeDate) · For \(sub.name)").font(AppFont.small).foregroundStyle(Palette.mute)
            }
            .padding(18)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md))
            .padding(.top, 20)

            ScrollView {
                Text(DisputeLetter.generate(for: sub, form: form))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Palette.ink)
                    .padding(18)
            }
            .frame(maxHeight: 360)
            .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Palette.border, lineWidth: 1))
            .padding(.top, 14)

            VStack(spacing: 10) {
                PrimaryButton("Send via Mail") {
                    if MailComposer.canSendMail {
                        showMail = true
                    } else {
                        // Fall back to the system mailto: handler
                        MailFallback.openMailto(
                            subject: "Refund request — \(sub.name)",
                            body: DisputeLetter.generate(for: sub, form: form),
                            to: nil
                        )
                        mailUnavailable = true
                    }
                } leading: {
                    Image(systemName: "envelope")
                }
                PrimaryButton(copied ? "Copied!" : "Copy to clipboard", variant: .secondary) {
                    UIPasteboard.general.string = DisputeLetter.generate(for: sub, form: form)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { copied = false }
                } leading: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                PrimaryButton("Edit details", variant: .ghost) { step = .form }
            }
            .padding(.top, 16)
            .sheet(isPresented: $showMail) {
                MailComposer(
                    subject: "Refund request — \(sub.name)",
                    body: DisputeLetter.generate(for: sub, form: form),
                    to: []
                ) { result, _ in
                    if result == .sent {
                        store.recordDisputeUsage()
                        step = .sent
                    }
                }
                .ignoresSafeArea()
            }
            .alert("Mail isn't set up", isPresented: $mailUnavailable) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Add a Mail account in Settings, or use 'Copy to clipboard' and paste into your email client.")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView().environment(store)
            }

            Button {
                step = .sent
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.success).font(.system(size: 16))
                    Text("I've sent it").font(AppFont.bodyB).foregroundStyle(Palette.ink)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 16)
        }
    }

    private var sentStep: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 32)
            Circle().fill(Palette.success).frame(width: 92, height: 92).overlay(
                Image(systemName: "checkmark").font(.system(size: 38, weight: .bold)).foregroundStyle(Palette.white)
            )
            Text("Letter sent.").font(AppFont.h1).foregroundStyle(Palette.ink).padding(.top, 24)
            Text("Most companies respond within 10 business days. We'll remind you in 7 days if you haven't heard back.")
                .font(AppFont.body).foregroundStyle(Palette.mute)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320).padding(.top, 8)

            Card {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("TYPICAL SUCCESS RATE").font(AppFont.smallB).foregroundStyle(Palette.mute)
                        Badge("EST", tone: .neutral)
                    }
                    Text("~\(form.reason.successRate)%").font(AppFont.display).foregroundStyle(Palette.success)
                    Text("Based on CFPB Consumer Complaint Database 2024: % of similar disputes that closed with monetary relief.")
                        .font(AppFont.small).foregroundStyle(Palette.mute)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 28)

            Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb").foregroundStyle(Palette.warn)
                        Text("IF THEY IGNORE YOU").font(AppFont.smallB).foregroundStyle(Palette.warn)
                    }
                    Text(form.reason.escalationTip)
                        .font(AppFont.small).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 12)

            VStack(spacing: 12) {
                PrimaryButton("Done") { dismiss() }
                PrimaryButton("Track this dispute", variant: .secondary) { dismiss() }
            }
            .padding(.top, 24)
        }
    }

    private func reasonRow(_ r: DisputeReason) -> some View {
        let active = form.reason == r
        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().stroke(active ? Palette.ink : Palette.mute2, lineWidth: 2).frame(width: 22, height: 22)
                if active { Circle().fill(Palette.ink).frame(width: 10, height: 10) }
            }
            .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.label).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                Text(r.subtext).font(AppFont.small).foregroundStyle(Palette.mute)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm)
                .stroke(active ? Palette.ink : Palette.border, lineWidth: active ? 2 : 1)
        )
    }

    private func stepDots(active: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(1...3, id: \.self) { i in
                Capsule()
                    .fill(i <= active ? Palette.ink : Palette.border)
                    .frame(width: 24, height: 4)
            }
            Text("Step \(active) of 3").font(AppFont.smallB).foregroundStyle(Palette.mute).padding(.leading, 8)
        }
        .padding(.top, 22)
    }

    private func amountBinding() -> Binding<String> {
        Binding(
            get: { String(format: "%.2f", form.amount) },
            set: { form.amount = Double($0) ?? 0 }
        )
    }
}

private struct FieldView: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default
    var prefix: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(AppFont.smallB).foregroundStyle(Palette.mute)
            HStack(spacing: 6) {
                if let prefix { Text(prefix).font(AppFont.body).foregroundStyle(Palette.mute) }
                TextField(placeholder, text: $text)
                    .font(AppFont.body)
                    .foregroundStyle(Palette.ink)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(Palette.border, lineWidth: 1))
        }
        .padding(.top, 14)
    }
}
