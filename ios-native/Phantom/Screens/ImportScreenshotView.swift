import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

/// The end-to-end "snap your bank statement → Phantom figures it out" flow.
struct ImportScreenshotView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var parsedTxs: [ParsedTransaction] = []
    /// Subscriptions read from a screenshot of Settings › Subscriptions (the
    /// Apple list). Kept apart from bank charges: they have no transaction rows.
    @State private var appleSubs: [Subscription] = []
    @State private var step: Step = .pick
    @State private var error: String?
    @State private var showDiagnostic = false
    @State private var copiedAt: Date?
    @State private var showFilePicker = false
    @State private var ingestedInbox = false

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
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .utf8PlainText],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await processFiles(urls) }
            case .failure(let err):
                error = err.localizedDescription
            }
        }
        .onAppear { ingestPending() }
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
            Text("IMPORT").font(AppFont.smallB).foregroundStyle(Palette.mute)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 4)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Find the charges.\nKeep the proof on this phone.")
                .font(AppFont.h1).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Screenshot a statement, share a CSV from your bank app, or start with the Apple subscriptions list iOS already keeps. Vision reads it here. Nothing is uploaded.")
                .font(AppFont.body).foregroundStyle(Palette.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 16)
    }

    private var pickStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            bestResultsCard.padding(.top, 24)
            tipsBox.padding(.top, 4)

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

            PrimaryButton("Import a bank CSV", variant: .secondary) {
                showFilePicker = true
            } leading: {
                Image(systemName: "tablecells")
            }
            .padding(.top, 8)

            PrimaryButton("Enter manually instead", variant: .ghost) {
                dismiss()
            } leading: {
                Image(systemName: "pencil")
            }
            .padding(.top, 4)

            if let err = error {
                Text(err).font(AppFont.small).foregroundStyle(Palette.danger).padding(.top, 12)
            }
        }
    }

    private var bestResultsCard: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Palette.warn).frame(width: 38, height: 38)
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Palette.white)
                    .font(.system(size: 16, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Tip: upload last 3 months for best results")
                    .font(AppFont.bodyB)
                    .foregroundStyle(Palette.ink)
                Text("A single statement finds likely subscriptions; 3+ months lets Phantom confirm recurrence and catch yearly bills.")
                    .font(AppFont.small)
                    .foregroundStyle(Palette.mute)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.warnSoft, in: RoundedRectangle(cornerRadius: Radius.md))
    }

    private var tipsBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            tipRow(icon: "wallet.bifold", text: "Apple Wallet → tap card → screenshot transactions")
            tipRow(icon: "building.columns", text: "Chase / BofA / Wells Fargo / Amex app — transactions tab")
            tipRow(icon: "camera.viewfinder", text: "Screenshot (Power + Vol Up), don't photograph the screen with another phone.")
            tipRow(icon: "square.and.arrow.down", text: "From your bank's website: download transactions as CSV, then import here or share the file to Phantom.")
            tipRow(icon: "square.and.arrow.up", text: "In Photos or Files, tap Share → Phantom. The screenshot never leaves the phone.")
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
        let confirmed = RecurrenceDetector.detect(in: parsedTxs + existingTxs())
        let confirmedIds = Set(confirmed.map { $0.id })
        let likely = RecurrenceDetector.detectLikelyFromSingle(parsedTxs)
            .filter { !confirmedIds.contains($0.id) }
        let subs = combinedSubs(confirmed: confirmed, likely: likely)

        return VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SCAN COMPLETE").font(AppFont.smallB).foregroundStyle(Palette.success)
                    Text(parsedTxs.isEmpty
                         ? "\(subs.count) subscriptions"
                         : "\(parsedTxs.count) charges · \(subs.count) subscriptions")
                        .font(AppFont.h2).foregroundStyle(Palette.ink)
                    if !appleSubs.isEmpty {
                        Text("\(appleSubs.count) from your Apple subscriptions list — these are billed by Apple, so cancel or refund through Apple.")
                            .font(AppFont.small).foregroundStyle(Palette.mute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !likely.isEmpty {
                        Text("\(confirmed.count) confirmed (repeat charges) · \(likely.count) likely (1 sighting — upload next month to confirm)")
                            .font(AppFont.small).foregroundStyle(Palette.mute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
            }
            .padding(.top, 24)

            subscriptionsBox(subs)

            if !parsedTxs.isEmpty {
                allChargesBox
            }

            PrimaryButton("Scan more screenshots", variant: .secondary) {
                pickedItems = []
                step = .pick
            } leading: {
                Image(systemName: "plus.rectangle.on.rectangle")
            }
        }
    }

    private func subscriptionsBox(_ subs: [Subscription]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "repeat.circle.fill")
                    .foregroundStyle(Palette.success).font(.system(size: 14, weight: .bold))
                Text("SUBSCRIPTIONS DETECTED · \(subs.count)").font(AppFont.smallB).foregroundStyle(Palette.success)
                Spacer()
            }

            if subs.isEmpty {
                Text("No recurring charges spotted in this batch. Upload a few more months — Phantom needs to see the same charge repeat to confirm.")
                    .font(AppFont.small).foregroundStyle(Palette.mute)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md))
            } else {
                VStack(spacing: 0) {
                    ForEach(subs.prefix(30)) { s in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.name).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                                Text(cycleLabel(s.cycle)).font(AppFont.small).foregroundStyle(Palette.mute)
                            }
                            Spacer()
                            Text(fmtUSD(s.amount)).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        if s.id != subs.prefix(30).last?.id {
                            Rectangle().fill(Palette.border).frame(height: 1)
                        }
                    }
                }
                .background(Palette.successSoft, in: RoundedRectangle(cornerRadius: Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.success.opacity(0.4), lineWidth: 1))

                PrimaryButton("Add these \(subs.count) to my Phantom") {
                    commit()
                } leading: {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
        }
    }

    private var allChargesBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(Palette.mute).font(.system(size: 14, weight: .bold))
                Text("ALL CHARGES SCANNED · \(parsedTxs.count)").font(AppFont.smallB).foregroundStyle(Palette.mute)
                Spacer()
                Button {
                    showDiagnostic.toggle()
                } label: {
                    Text(showDiagnostic ? "Hide raw OCR" : "Show raw OCR")
                        .font(AppFont.smallB)
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Palette.surface, in: Capsule())
                }
            }

            Text("For reference. Phantom won't import these as subscriptions.")
                .font(AppFont.small).foregroundStyle(Palette.mute2)

            VStack(spacing: 0) {
                ForEach(parsedTxs.prefix(30)) { tx in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tx.merchant).font(AppFont.body).foregroundStyle(Palette.ink)
                                if let d = tx.date {
                                    Text(fmtRelDate(d)).font(AppFont.small).foregroundStyle(Palette.mute)
                                }
                            }
                            Spacer()
                            Text(fmtUSD(tx.amount)).font(AppFont.body).foregroundStyle(Palette.mute)
                        }
                        if showDiagnostic, !tx.rawRow.isEmpty {
                            Text("OCR: \(tx.rawRow)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Palette.mute2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
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
                Text("Showing first 30 of \(parsedTxs.count).")
                    .font(AppFont.small).foregroundStyle(Palette.mute)
            }

            Button {
                UIPasteboard.general.string = diagnosticReport
                copiedAt = Date()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: copiedAt != nil ? "checkmark.circle.fill" : "doc.on.doc")
                    Text(copiedAt != nil ? "Copied — paste in chat" : "Copy diagnostic to clipboard")
                        .font(AppFont.smallB)
                }
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var diagnosticReport: String {
        let confirmed = RecurrenceDetector.detect(in: parsedTxs + existingTxs())
        let confirmedIds = Set(confirmed.map { $0.id })
        let likely = RecurrenceDetector.detectLikelyFromSingle(parsedTxs)
            .filter { !confirmedIds.contains($0.id) }
        let subIds = Set((confirmed + likely).map { $0.id })

        var out = "=== Phantom OCR diagnostic ===\n"
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        out += "When: \(f.string(from: Date()))\n"
        out += "Total charges: \(parsedTxs.count)\n"
        out += "Subscriptions detected: \(subIds.count) (+\(appleSubs.count) from the Apple subscriptions list)\n"
        for a in appleSubs {
            out += "APPLE LIST: \(a.name) | $\(String(format: "%.2f", a.amount)) \(a.cycle.label.lowercased()) | \(a.rawDescriptor ?? "")\n"
        }
        out += "------------------------------\n"
        for (i, tx) in parsedTxs.enumerated() {
            let key = MerchantNormalizer.brandId(forNormalized: tx.merchant)
            let isSub = subIds.contains(key) || subIds.contains(tx.id)
            let mlScore = MerchantML.subscriptionProbability(for: tx.merchant)
            let txnal = MerchantNormalizer.isLikelyTransactional(tx.merchant)
            let amtMatch = MerchantNormalizer.isLikelySubscriptionAmount(tx.amount)
            let dateStr = tx.date.map { d -> String in
                let g = DateFormatter()
                g.dateFormat = "MM/dd"
                return g.string(from: d)
            } ?? "-"
            out += "\(i + 1). \(tx.merchant) | $\(String(format: "%.2f", tx.amount)) | \(dateStr) | \(isSub ? "SUB" : "not")\n"
            out += "   ml=\(String(format: "%.0f%%", mlScore * 100)) txnal=\(txnal) priceMatch=\(amtMatch)\n"
            out += "   raw: \(tx.rawRow)\n"
        }
        return out
    }

    private func cycleLabel(_ cycle: BillingCycle) -> String {
        cycle.label
    }

    private func ingestPending() {
        guard !ingestedInbox else { return }
        ingestedInbox = true
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--demo-csv") {
            let sample = Data(StatementCSV.debugChaseCSV.utf8)
            applyTransactions(StatementCSV.parse(sample))
            return
        }
        #endif
        let payload = IncomingInbox.consume()
        guard !payload.isEmpty else { return }
        Task { await processInbox(payload) }
    }

    private func processInbox(_ payload: IncomingInbox.Payload) async {
        step = .processing
        error = nil
        var all = parsedTxs
        for data in payload.csvs {
            all.append(contentsOf: StatementCSV.parse(data))
        }
        for data in payload.images {
            guard let img = UIImage(data: data) else { continue }
            do {
                let lines = try await OCR.recognizeText(in: img)
                ingest(lines: lines, into: &all)
            } catch {
                self.error = "Couldn't read a shared image: \(error.localizedDescription)"
            }
        }
        applyTransactions(all)
    }

    private func processFiles(_ urls: [URL]) async {
        step = .processing
        error = nil
        var all = parsedTxs
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { continue }
            let ext = url.pathExtension.lowercased()
            if ["png", "jpg", "jpeg", "heic", "webp"].contains(ext), let img = UIImage(data: data) {
                do {
                    let lines = try await OCR.recognizeText(in: img)
                    ingest(lines: lines, into: &all)
                } catch {
                    self.error = "Couldn't read \(url.lastPathComponent): \(error.localizedDescription)"
                }
            } else {
                all.append(contentsOf: StatementCSV.parse(data))
            }
        }
        applyTransactions(all)
    }

    /// Route one screenshot's OCR lines: the Apple subscriptions list has its
    /// own parser; everything else is a bank statement.
    private func ingest(lines: [OCR.Line], into all: inout [ParsedTransaction]) {
        if AppleSubscriptionsParser.looksLikeAppleList(lines) {
            let found = AppleSubscriptionsParser.parse(lines: lines)
            for sub in found where !appleSubs.contains(where: { $0.id == sub.id }) {
                appleSubs.append(sub)
            }
        } else {
            all.append(contentsOf: TransactionParser.parse(lines: lines))
        }
    }

    /// Apple-list subs join the detected ones unless a bank charge already
    /// confirmed the same id (the store reconciles amounts on commit).
    private func combinedSubs(confirmed: [Subscription], likely: [Subscription]) -> [Subscription] {
        let taken = Set((confirmed + likely).map(\.id))
        return confirmed + likely + appleSubs.filter { !taken.contains($0.id) }
    }

    private var nothingFound: Bool { parsedTxs.isEmpty && appleSubs.isEmpty }

    private func applyTransactions(_ txs: [ParsedTransaction]) {
        parsedTxs = dedupe(txs)
        step = nothingFound ? .pick : .review
        if nothingFound {
            error = "No charges detected. Try a CSV with Date, Description, and Amount columns, or a screenshot that shows merchant names and amounts."
        }
    }

    private func processPicked(_ items: [PhotosPickerItem]) async {
        step = .processing
        error = nil
        // Seed with what we already scanned so "Scan more screenshots" ACCUMULATES
        // across batches within this session. Earlier imports come back through
        // existingTxs() (the on-device ledger) when recurrence is computed.
        var all: [ParsedTransaction] = parsedTxs
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let img = UIImage(data: data) else { continue }
                let lines = try await OCR.recognizeText(in: img)
                ingest(lines: lines, into: &all)
            } catch {
                self.error = "Couldn't read one of the images: \(error.localizedDescription)"
            }
        }
        parsedTxs = dedupe(all)
        step = nothingFound ? .pick : .review
        if nothingFound {
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

    /// Everything imported before, from the on-device ledger — this is what
    /// lets a charge seen last month confirm the one seen this month.
    private func existingTxs() -> [ParsedTransaction] {
        store.ledgerTransactions()
    }

    private func commit() {
        let confirmed = RecurrenceDetector.detect(in: parsedTxs + existingTxs())
        let confirmedIds = Set(confirmed.map { $0.id })
        let likely = RecurrenceDetector.detectLikelyFromSingle(parsedTxs)
            .filter { !confirmedIds.contains($0.id) }
        store.mergeImported(subs: combinedSubs(confirmed: confirmed, likely: likely), transactions: parsedTxs)
        dismiss()
    }
}
