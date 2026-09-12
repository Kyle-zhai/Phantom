import SwiftUI

/// "What you already have" — the memberships, carrier plans, cards and Apple
/// One tier the user pays for. Phantom cross-checks every subscription against
/// their inclusions on-device; nothing is sent anywhere.
struct OwnedBundlesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var inferred: Set<String> { store.inferredBundleIds }

    private var groups: [(title: String, caption: String, bundles: [AlternativesCatalog.Bundle])] {
        let all = store.catalog.bundles
        func of(_ types: [String]) -> [AlternativesCatalog.Bundle] {
            all.filter { types.contains($0.type) }.sorted { $0.name < $1.name }
        }
        return [
            ("Memberships", "Prime, Walmart+, YouTube Premium and similar.", of(["membership", "retail", "software"])),
            ("Apple One", "Any tier includes Music, TV, Arcade and iCloud.", of(["apple"])),
            ("Carrier & internet plans", "Streaming perks depend on the plan — tick only what your plan includes.", of(["telecom"])),
            ("Credit cards", "Statement credits usually need one-time enrollment on the card's site.", of(["card"])),
        ].filter { !$0.2.isEmpty }.map { ($0.0, $0.1, $0.2) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                Text("What you already have")
                    .font(AppFont.h1).foregroundStyle(Palette.ink).padding(.top, 18)
                Text("Tick what you pay for. Phantom checks — on this iPhone only — whether any of your subscriptions are already included or reimbursed.")
                    .font(AppFont.body).foregroundStyle(Palette.mute).padding(.top, 6)
                    .fixedSize(horizontal: false, vertical: true)

                if store.catalog.bundles.isEmpty {
                    Card {
                        Text("The bundle catalog hasn't loaded yet. Open Phantom with a connection once and try again.")
                            .font(AppFont.small).foregroundStyle(Palette.mute)
                    }
                    .padding(.top, 20)
                }

                ForEach(groups, id: \.title) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(group.title, caption: group.caption)
                        VStack(spacing: 0) {
                            ForEach(Array(group.bundles.enumerated()), id: \.element.id) { i, bundle in
                                if i > 0 { Rectangle().fill(Palette.border).frame(height: 1).padding(.leading, 16) }
                                bundleRow(bundle)
                            }
                        }
                        .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Palette.border, lineWidth: 1))
                    }
                    .padding(.top, 28)
                }

                Text("Phantom takes no commission and never recommends a product for a fee.")
                    .font(AppFont.small).foregroundStyle(Palette.mute2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 28)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Palette.white)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func bundleRow(_ bundle: AlternativesCatalog.Bundle) -> some View {
        let detected = inferred.contains(bundle.id)
        let isOn = Binding<Bool>(
            get: { detected || store.ownedBundleIds.contains(bundle.id) },
            set: { store.setBundleOwned(bundle.id, $0) }
        )
        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(bundle.name).font(AppFont.bodyB).foregroundStyle(Palette.ink)
                    if detected {
                        Text("DETECTED").micro()
                            .foregroundStyle(Palette.keepFg)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Palette.successSoft, in: Capsule())
                    }
                }
                let included = bundle.includes.map(\.brandId).compactMap { BrandRegistry.displayName(for: $0) }
                if !included.isEmpty {
                    Text("Includes " + included.prefix(4).joined(separator: ", ") + (included.count > 4 ? "…" : ""))
                        .font(AppFont.small).foregroundStyle(Palette.mute)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let note = bundle.note, !note.isEmpty {
                    Text(note).font(AppFont.small).foregroundStyle(Palette.mute2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(Palette.ink).disabled(detected)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
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
            Text("ALREADY COVERED").font(AppFont.smallB).foregroundStyle(Palette.mute)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 4)
    }
}
