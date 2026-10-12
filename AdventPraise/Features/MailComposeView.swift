//
//  MailComposeView.swift
//  Advent Praise
//
//  "Send a correction" and "Request a hymnal or feature": a prefilled
//  MFMailComposeViewController, falling back to a mailto: link when Mail
//  isn't set up on the device.
//

import MessageUI
import SwiftUI
import UIKit

struct MailDraft {
    let kind: MailRequest.Kind
    let subject: String
    let body: String

    var mailtoURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppInfo.supportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        return components.url
    }

    @MainActor
    static func make(_ kind: MailRequest.Kind, hymnal: Hymnal, hymn: Hymn) -> MailDraft {
        let device = "Advent Praise \(AppInfo.version) (\(AppInfo.build)) · iOS \(UIDevice.current.systemVersion)"
        switch kind {
        case .correction:
            return MailDraft(
                kind: kind,
                subject: "Correction: \(hymnal.name) \(hymn.id) – \(hymn.title)",
                body: """
                Hymnal: \(hymnal.name) (\(hymnal.info.language))
                Hymn: \(hymn.id) – \(hymn.title)

                What needs fixing (verse and line, and the correct words):


                ——
                Current text:
                \(hymn.plainText(chorusLabel: hymnal.chorusLabel))

                \(device)
                """)
        case .request:
            return MailDraft(
                kind: kind,
                subject: "Request for Advent Praise",
                body: """
                I'd like to request (a hymnal, language or feature):


                Currently reading: \(hymnal.name) (\(hymnal.info.language))
                \(device)
                """)
        }
    }
}

struct MailComposeView: View {
    let draft: MailDraft
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var kind: MailKind { draft.kind == .correction ? .correction : .request }

    var body: some View {
        Group {
            if MFMailComposeViewController.canSendMail() {
                MailComposer(draft: draft) { result in
                    Analytics.track(.feedbackMailFinished(kind: kind, result: result))
                    dismiss()
                }
            } else {
                Color.clear.onAppear {
                    if let url = draft.mailtoURL { openURL(url) }
                    Analytics.track(.feedbackMailFinished(kind: kind, result: .handedOff))
                    dismiss()
                }
            }
        }
        .onAppear {
            Analytics.track(.feedbackMailOpened(kind: kind))
            Analytics.screen(.mail)
        }
    }
}

private struct MailComposer: UIViewControllerRepresentable {
    let draft: MailDraft
    let onFinish: @MainActor (MailResult) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([AppInfo.supportEmail])
        vc.setSubject(draft.subject)
        vc.setMessageBody(draft.body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: @MainActor (MailResult) -> Void
        init(onFinish: @escaping @MainActor (MailResult) -> Void) { self.onFinish = onFinish }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            let outcome: MailResult = switch result {
            case .sent: .sent
            case .saved: .saved
            case .cancelled: .cancelled
            default: .failed
            }
            onFinish(outcome)
        }
    }
}
