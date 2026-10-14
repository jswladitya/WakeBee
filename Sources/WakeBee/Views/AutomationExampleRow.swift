import AppKit
import SwiftUI

struct AutomationExample: Identifiable {
    let title: String
    let command: String
    var id: String { command }

    static let all = [
        AutomationExample(title: "Until this shell exits", command: #"open "wakebee://start?pid=$$""#),
        AutomationExample(title: "For 90 minutes", command: #"open "wakebee://start?minutes=90""#),
        AutomationExample(title: "Until 5:30 PM", command: #"open "wakebee://start?until=17:30""#),
        AutomationExample(title: "Add 30 minutes", command: #"open "wakebee://extend?minutes=30""#),
        AutomationExample(title: "End the session", command: #"open "wakebee://end""#),
    ]
}

struct AutomationExampleRow: View {
    let example: AutomationExample
    @State private var copied = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(example.title).font(.callout)
                Text(example.command)
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 4)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(example.command, forType: .string)
                copied = true
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Copy command: \(example.title)")
            .help("Copy to the clipboard")
            .task(id: copied) {
                guard copied else { return }
                try? await Task.sleep(for: .seconds(1.5))
                copied = false
            }
        }
    }
}
