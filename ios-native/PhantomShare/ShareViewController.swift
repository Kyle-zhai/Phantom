import UIKit
import UniformTypeIdentifiers

/// Share-sheet entry: copies the screenshot or CSV into the App Group inbox
/// and hops to the main app. No UI beyond a brief “Opening Phantom…”.
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "Opening Phantom…"
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .body)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        Task { await ingest() }
    }

    private func ingest() async {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    await load(provider, type: UTType.image, isCSV: false, name: "screenshot")
                } else if provider.hasItemConformingToTypeIdentifier(UTType.commaSeparatedText.identifier) {
                    await load(provider, type: UTType.commaSeparatedText, isCSV: true, name: "statement")
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    await load(provider, type: UTType.plainText, isCSV: true, name: "statement")
                } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    await loadFile(provider)
                }
            }
        }
        openHost()
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func load(_ provider: NSItemProvider, type: UTType, isCSV: Bool, name: String) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                if let data, !data.isEmpty {
                    IncomingInbox.write(data: data, suggestedName: name, isCSV: isCSV)
                }
                cont.resume()
            }
        }
    }

    private func loadFile(_ provider: NSItemProvider) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { cont.resume() }
                let url: URL? = {
                    if let u = item as? URL { return u }
                    if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
                    return nil
                }()
                guard let url, let data = try? Data(contentsOf: url), !data.isEmpty else { return }
                let ext = url.pathExtension.lowercased()
                let isCSV = ["csv", "txt", "tsv"].contains(ext)
                IncomingInbox.write(data: data, suggestedName: url.lastPathComponent, isCSV: isCSV)
            }
        }
    }

    private func openHost() {
        guard let url = URL(string: "phantom://import") else { return }
        var responder: UIResponder? = self
        while let current = responder {
            if let app = current as? UIApplication {
                app.open(url)
                return
            }
            responder = current.next
        }
        extensionContext?.open(url)
    }
}
