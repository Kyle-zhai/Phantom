import SwiftUI

/// Card-issuer chargeback packet. Shown after a dispute letter is sent, or
/// from a cancelled subscription that got billed anyway.
struct ChargebackGuideView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let subId: String

    @State private var copied = false

    private var sub: Subscription? { store.subscription(byId: subId) }
    private var record: AppStore.DisputeRecord? { store.disputeRecord(for: subId) }
    private var evidence: EvidenceLocker.Record? { EvidenceLocker.load(subId) }

    var body: some View {
        Group {
            if let sub {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        topBar
                        Text("If they ignore the letter.")
                            .font(AppFont.h1).foregroundStyle(Palette.ink)
                            .padding(.top, 16)
                        Text("Call the number on the back of your card. Read this. Don't file through the merchant again.")
                            .font(AppFont.body).foregroundStyle(Palette.mute)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 10)

                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(ChargebackPacket.checklist(reason: reason).enumerated()), id: \.offset) { i, text in
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

                        Text("What to say")
                            .font(AppFont.h3).foregroundStyle(Palette.ink)
                            .padding(.top, 28)
                        Text(script)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Palette.ink)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.md))
                            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
                            .padding(.top, 10)

                        PrimaryButton(copied ? "Copied" : "Copy script") {
                            UIPasteboard.general.string = script
                            copied = true
                        } leading: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        }
                        .padding(.top, 16)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("IF THE ISSUER STALLS").font(AppFont.smallB).foregroundStyle(Palette.warn)
                            Text("File a CFPB complaint. Companies typically respond within 15 days because the response rate is public. You can also report the merchant at reportfraud.ftc.gov.")
                                .font(AppFont.small).foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 10) {
                                linkChip("CFPB complaint", url: "https://www.consumerfinance.gov/complaint/")
                                linkChip("FTC fraud", url: "https://reportfraud.ftc.gov/")
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.warnSoft, in: RoundedRectangle(cornerRadius: Radius.md))
                        .padding(.top, 20)

                        Text("Phantom does not file the chargeback or talk to your bank. The script is yours to read.")
                            .font(AppFont.small).foregroundStyle(Palette.mute)
                            .padding(.top, 16)

                        PrimaryButton("Done", variant: .secondary) { dismiss() }
                            .padding(.top, 20)
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
    }

    private var reason: DisputeReason {
        if let raw = record?.reasonRaw, let r = DisputeReason(rawValue: raw) { return r }
        if store.cancelledIds.contains(subId) { return .cancelledStillCharged }
        return .unauthorizedCharge
    }

    private var script: String {
        ChargebackPacket.script(for: ChargebackPacket.Context(
            merchant: sub?.vendor ?? sub?.name ?? "the merchant",
            amount: record?.amount ?? sub?.amount ?? 0,
            chargeDate: record?.chargeDate ?? "the statement date",
            reason: reason,
            confirmationNumber: evidence?.confirmationNumber ?? "",
            letterSentAt: record?.sentAt,
            fullName: store.profile?.fullName ?? ""
        ))
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
            Text("CHARGEBACK PACKET").font(AppFont.smallB).foregroundStyle(Palette.mute)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 4)
    }

    private func linkChip(_ label: String, url: String) -> some View {
        Button {
            if let u = URL(string: url) { UIApplication.shared.open(u) }
        } label: {
            Text(label)
                .font(AppFont.smallB)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Palette.white, in: Capsule())
                .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
