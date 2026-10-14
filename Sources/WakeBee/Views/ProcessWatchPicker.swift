import WakeBeeCore
import SwiftUI

/// Optionally ties the next session to a process, such as a coding agent,
/// so the Mac can sleep again as soon as the work finishes.
struct ProcessWatchPicker: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("End when it exits")
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Menu {
                Button("Don’t watch a process") { model.watchedProcess = nil }
                if !model.watchCandidates.terminal.isEmpty {
                    Section("Terminal") {
                        ForEach(model.watchCandidates.terminal) { process in
                            Button("\(process.name) (\(process.pid))") { model.watchedProcess = process }
                        }
                    }
                }
                if !model.watchCandidates.apps.isEmpty {
                    Section("Apps") {
                        ForEach(model.watchCandidates.apps) { process in
                            Button(process.name) { model.watchedProcess = process }
                        }
                    }
                }
                Divider()
                Button("Refresh List", systemImage: "arrow.clockwise", action: model.refreshWatchCandidates)
            } label: {
                Text(model.watchedProcess?.name ?? "No process")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Process to watch")
            .accessibilityValue(model.watchedProcess?.name ?? "None")
            .help("The session ends as soon as this process exits, even before its timer.")
        }
        .font(.callout)
        .padding(.horizontal, 4)
        .onAppear(perform: model.refreshWatchCandidates)
    }
}
