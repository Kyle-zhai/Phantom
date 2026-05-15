import SwiftUI
import PhotosUI
import UIKit

/// The end-to-end "snap your bank statement → SubSpy figures it out" flow.
struct ImportScreenshotView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var parsedTxs: [ParsedTransaction] = []
    @State private var step: Step = .pick
    @State private var error: String?

    enum Step {
        case pick, processing, review
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                hero
                switch step {
                case .pick:        pickStep
                case .processing:  processingStep
                case .review:      reviewStep
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(Palette.white)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: pickedItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await processPicked(newItems) }
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
            Text("IMPORT FROM SCREENSHOTS").font(AppFont.smallB).foregroundStyle(Palette.mute)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 4)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Snap your statement.\nSubSpy reads it.")
                .font(AppFont.h1).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Take screenshots of your bank app, Apple Wallet, or credit-card statement. We'll OCR them on-device and detect every recurring charge. **Nothing leaves your phone.**")
                .font(AppFont.body).foregroundStyle(Palette.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 16)
    }

    private var pickStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            tipsBox.padding(.top, 24)

            PhotosPicker(
                selection: $pickedItems,
                maxSelectionCount: 20,
                matching: .images
            ) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Pick screenshots").font(AppFont.bodyB)
                }
                .foregroundStyle(Palette.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Palette.black, in: RoundedRectangle(cornerRadius: Radius.xl))
            }
            .padding(.top, 16)

            PrimaryButton("Enter manually instead", variant: .secondary) {
                dismiss()
                // The settings/manual entry route can be opened from the radar
            } leading: {
                Image(systemName: "pencil")
            }
            .padding(.top, 4)

            if let err = error {
                Text(err).font(AppFont.small).foregroundStyle(Palette.danger).padding(.top, 12)
            }
        }
    }

    private var tipsBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            tipRow(icon: "wallet.bifold", text: "Apple Wallet → tap card → screenshot transactions")
            tipRow(icon: "building.columns", text: "Chase / BofA / Wells Fargo / Amex app — transactions tab")
            tipRow(icon: "envelope", text: "Email receipts work too (Netflix charge confirmation, etc.)")
            tipRow(icon: "shield.lefthalf.filled", text: "Vision OCR runs entirely on your iPhone. No upload.")
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md))
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Palette.ink).font(.system(size: 16))
                .frame(width: 22)
            Text(text).font(AppFont.small).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var processingStep: some View {
        VStack(spacing: 22) {
            Spacer().frame(height: 40)
            ProgressView().scaleEffect(1.5).tint(Palette.ink)
            Text("Reading \(pickedItems.count) screenshot\(pickedItems.count == 1 ? "" : "s")…")
                .font(AppFont.bodyB).foregroundStyle(Palette.ink)
            Text("Vision OCR is processing on-device. ~2 seconds per image.")
                .font(AppFont.small).foregroundStyle(Palette.mute)
        }
        .frame(maxWidth: .infinity)
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FOUND \(parsedTxs.count) CHARGES").font(AppFont.smallB).foregroundStyle(Palette.success)
                    let recurring = RecurrenceDetector.detect(in: parsedTxs + existingTxs())
                    Text("\(recurring.count) look like subscriptions")
                        .font(AppFont.h2).foregroundStyle(Palette.ink)
                }
                Spacer()
            }
            .padding(.top, 24)

            VStack(spacing: 0) {
                ForEach(parsedTxs.prefix(30)) { tx in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.merchant).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                            if let d = tx.date {
                                Text(fmtRelDate(d)).font(AppFont.small).foregroundStyle(Palette.mute)
                            }
                        }
                        Spacer()
                        Text(fmtUSD(tx.amount)).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    if tx.id != parsedTxs.prefix(30).last?.id {
                        Rectangle().fill(Palette.border).frame(height: 1)
                    }
                }
            }
            .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))

            if parsedTxs.count > 30 {
                Text("Showing first 30. \(parsedTxs.count - 30) more will be saved.")
                    .font(AppFont.small).foregroundStyle(Palette.mute)
            }

            PrimaryButton("Add these to my SubSpy") {
                commit()
            } leading: {
                Image(systemName: "checkmark.circle.fill")
            }
            .padding(.top, 8)

            PrimaryButton("Scan more screenshots", variant: .secondary) {
                pickedItems = []
                step = .pick
            } leading: {
                Image(systemName: "plus.rectangle.on.rectangle")
            }
        }
    }

    private func processPicked(_ items: [PhotosPickerItem]) async {
        step = .processing
        error = nil
        var all: [ParsedTransaction] = []
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let img = UIImage(data: data) else { continue }
                let lines = try await OCR.recognizeText(in: img)
                let txs = TransactionParser.parse(lines: lines)
                all.append(contentsOf: txs)
            } catch {
                self.error = "Couldn't read one of the images: \(error.localizedDescription)"
            }
        }
        parsedTxs = dedupe(all)
        step = parsedTxs.isEmpty ? .pick : .review
        if parsedTxs.isEmpty {
            error = "No charges detected. Try a screenshot that shows merchant names + amounts clearly (Apple Wallet works best)."
        }
    }

    private func dedupe(_ txs: [ParsedTransaction]) -> [ParsedTransaction] {
        var seen = Set<String>()
        return txs.filter { tx in
            let key = "\(tx.merchant.lowercased())|\(tx.amount)|\(tx.date?.timeIntervalSince1970 ?? 0)"
            return seen.insert(key).inserted
        }
    }

    private func existingTxs() -> [ParsedTransaction] {
        // Future: pull from PersistentTransaction. Empty for v1 (first import).
        []
    }

    private func commit() {
        let detected = RecurrenceDetector.detect(in: parsedTxs + existingTxs())
        store.mergeImported(subs: detected, transactions: parsedTxs)
        dismiss()
    }
}
