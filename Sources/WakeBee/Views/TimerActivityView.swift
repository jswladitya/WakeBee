import WakeBeeCore
import SwiftUI

struct TimerActivityView: View {
    @Bindable var model: AppModel

    var body: some View {
        if let current = model.session.session {
            VStack(spacing: 12) {
                TimelineView(.periodic(from: .now, by: model.isPopoverVisible && current.endsAt != nil ? 1 : 3600)) { context in
                    VStack(spacing: 8) {
                        if let remaining = current.remainingSeconds(at: context.date), let end = current.endsAt {
                            Text(Countdown.string(seconds: remaining))
                                .font(.system(size: 40, weight: .light, design: .rounded))
                                .monospacedDigit()
                                .accessibilityLabel("Time remaining")
                                .accessibilityValue(Countdown.string(seconds: remaining))
                            Text("Until \(end.formatted(date: .abbreviated, time: .shortened))")
                                .font(.callout).foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "infinity")
                                .font(.system(size: 40, weight: .light)).accessibilityHidden(true)
                            Text(current.watchedProcess.map { "Until \($0.name) exits" } ?? "Until you stop it")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                if let watched = current.watchedProcess {
                    HStack(spacing: 6) {
                        Label(current.endsAt == nil ? "Watching \(watched.name) (\(watched.pid))"
                                                    : "Ends early if \(watched.name) exits",
                              systemImage: "eye")
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                        Button(action: model.stopWatchingProcess) {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel("Stop watching \(watched.name)")
                        .help(current.endsAt == nil ? "Keep the session running until you stop it"
                                                    : "Keep the session running until its timer ends")
                    }
                    .frame(maxWidth: .infinity)
                }
                HStack(spacing: 10) {
                    if let end = current.endsAt {
                        Button(action: model.extend) {
                            Text("+15 min").font(.callout.weight(.medium))
                                .frame(minHeight: 28)
                        }
                        .awakeGlassButton()
                        .accessibilityLabel("Add 15 minutes")
                        .disabled(!model.license.isUnlocked || end.timeIntervalSince(current.startedAt) >= Double(SessionDuration.maximumMinutes) * 60)
                    }
                    Button(action: model.end) {
                        Label("End session", systemImage: "stop.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .awakeGlassButton(prominent: true)
                    .keyboardShortcut(.return, modifiers: .command)
                }
                .buttonBorderShape(.capsule).controlSize(.regular)
            }
        } else {
            SessionSetupView(model: model)
        }
    }
}
