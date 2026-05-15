import SwiftUI
import MessageUI

/// Real Mail.app composer for dispute letters. Falls back to mailto: URL when
/// the device has no Mail account configured.
struct MailComposer: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let to: [String]
    let onResult: (MFMailComposeResult, Error?) -> Void

    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        vc.setToRecipients(to)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onResult: (MFMailComposeResult, Error?) -> Void
        init(onResult: @escaping (MFMailComposeResult, Error?) -> Void) {
            self.onResult = onResult
        }
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true) { [self] in onResult(result, error) }
        }
    }
}

enum MailFallback {
    static func openMailto(subject: String, body: String, to: String?) {
        let s = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let b = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let recipient = to ?? ""
        let url = URL(string: "mailto:\(recipient)?subject=\(s)&body=\(b)")
        if let url, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
