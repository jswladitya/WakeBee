import WakeBeeCore
import SwiftUI

struct SessionSetupView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            SessionModePicker(selection: $model.sessionMode)
            .onChange(of: model.sessionMode) { _, mode in
                if mode == .untilTime && model.sessionEndDate <= .now {
                    model.sessionEndDate = .now.addingTimeInterval(30 * 60)
                }
            }

            switch model.sessionMode {
            case .duration:
                DurationEditor(draft: $model.durationDraft, onSubmit: model.start)
            case .untilTime:
                SessionEndTimeEditor(selection: $model.sessionEndDate)
            case .untilStopped:
                VStack(spacing: 8) {
                    Image(systemName: "infinity")
                        .font(.system(size: 36, weight: .light))
                        .accessibilityHidden(true)
                    Text("Until you stop it")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 6)
            }

            ProcessWatchPicker(model: model)

            TimelineView(.periodic(from: .now, by: model.isPopoverVisible && model.sessionMode == .untilTime ? 1 : 3600)) { context in
                Button(action: model.start) {
                    Label("Start session", systemImage: "play.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 28)
                }
                .awakeGlassButton(prominent: true)
                .buttonBorderShape(.capsule)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
                .disabled(!(model.requestedSession?.isValid(at: context.date) ?? false) || !model.license.isUnlocked || model.updates.isUpdateInProgress)
            }

            if model.updates.isUpdateInProgress {
                Text("Finish or dismiss the update to start a session.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        }
    }
}
