import SwiftUI

/// Shows the on-device cancel proof for a subscription, and a path into the
/// chargeback packet if they billed after cancel.
struct EvidenceLockerView: View {
    let subId: String

    private var record: EvidenceLocker.Record? { EvidenceLocker.load(subId) }
    private var screenshot: UIImage? { EvidenceLocker.loadScreenshot(for: subId) }

    var body: some View {
        let rec = record
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Proof on this iPhone", caption: "Never uploaded. Used if they charge you after you cancelled.")
            VStack(alignment: .leading, spacing: 14) {
                if let rec {
                    row("Cancelled", value: fmtMedium(rec.cancelledAt))
                    if !rec.confirmationNumber.isEmpty {
                        row("Confirmation", value: rec.confirmationNumber)
                    }
                    row("How", value: methodLabel(rec.method))
                    if !rec.notes.isEmpty {
                        row("Notes", value: rec.notes)
                    }
                    if let screenshot {
                        Image(uiImage: screenshot)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                    } else if rec.hasScreenshot {
                        Text("Screenshot was saved, but can't be read on this device.")
                            .font(AppFont.small).foregroundStyle(Palette.mute)
                    }
                } else {
                    Text("No confirmation number or screenshot yet. If they bill you again, add proof from the cancel flow — or generate a dispute letter anyway.")
                        .font(AppFont.small).foregroundStyle(Palette.mute)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md))
        }
    }

    private func row(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(AppFont.smallB).foregroundStyle(Palette.mute)
            Text(value).font(AppFont.body).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func methodLabel(_ raw: String) -> String {
        switch raw {
        case "apple": return "iOS Subscriptions"
        case "phone": return "Phone"
        case "in-person": return "In person / mail"
        default: return "Vendor website"
        }
    }

    private func fmtMedium(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}
