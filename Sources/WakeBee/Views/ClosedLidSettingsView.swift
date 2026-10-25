import AppKit
import SwiftUI

struct ClosedLidSettingsView: View {
    let model: AppModel
    @State private var detailsCopied = false

    var body: some View {
        SettingsScrollPage {
            if model.closedLid.isRegistered && !model.closedLid.needsApproval {
                ClosedLidControl(model: model, showsSettingsButton: false, openSetup: {})
            } else {
                setup
            }
            if !model.closedLid.isRegistered || model.closedLid.canRepair,
               let issue = model.closedLid.issueMessage {
                SettingsGlassSection(title: "Setup details") {
                    Text(issue)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    Button(detailsCopied ? "Details copied" : "Copy setup details") {
                        NSPasteboard.general.clearContents()
                        detailsCopied = NSPasteboard.general.setString(model.closedLid.setupDiagnostics, forType: .string)
                    }
                    .awakeGlassButton().buttonBorderShape(.capsule)
                }
                .onChange(of: issue, initial: true) { detailsCopied = false }
            }
            ClosedLidBatterySettings(preferences: model.preferences,
                                     modeEnabled: model.closedLid.isActive || model.closedLid.isBusy)
                .onChange(of: model.preferences.sessionPowerPolicy) { model.refreshPowerSettings() }
            VStack(alignment: .leading, spacing: 12) {
                Text("On a charger, closed-lid mode lasts as long as your session. It turns off if your Mac gets too warm or reaches a battery limit.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                DisclosureGroup("How it works") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("This mode runs only during a session. It starts off each time you open WakeBee.")
                        Text("When a limit is reached or WakeBee loses its connection, this mode turns off and macOS sleep settings are restored. If the lid is closed, your Mac goes to sleep. Turn it on again when you’re ready.")
                        Text("While plugged in, the battery must stay above 20%. On battery, it runs for up to the time you choose, 4 hours at most. Time on battery adds up within a session; plugging in does not reset it.")
                        Text("Keep your Mac on a hard surface with room for airflow, never in a bag or sleeve, and check that it stays awake before leaving work unattended.")
                    }
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 10)
                }
            }
            .padding(.horizontal, 4)
            if model.closedLid.isRegistered {
                DisclosureGroup("Advanced") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Remove closed-lid setup from this Mac. You can set it up again later.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Remove closed-lid setup…") { model.closedLid.uninstall() }
                            .awakeGlassButton().buttonBorderShape(.capsule)
                            .disabled(model.closedLid.isBusy)
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var setup: some View {
        SettingsGlassSection(title: "Closed-lid mode") {
            Label(model.closedLid.isBusy ? "Getting ready" : model.closedLid.needsApproval ? "One step left" : "Keep working with the lid closed", systemImage: "laptopcomputer")
                .font(.headline)
            Text(setupDescription).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !model.closedLid.signedBuild {
                Text("Use the signed version of WakeBee to set up this feature.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if model.closedLid.isBusy {
                ProgressView().controlSize(.small)
                    .accessibilityLabel("Setting up closed-lid mode")
            } else if let action = model.closedLid.setupAction {
                Button(action == .setUp && model.closedLid.issueMessage != nil ? "Try setup again" : action.title,
                       action: model.setupClosedLid)
                    .awakeGlassButton(prominent: true).buttonBorderShape(.capsule)
                    .disabled(!model.license.isUnlocked)
            }
        }
    }

    private var setupDescription: String {
        if model.closedLid.isBusy { return "Keep the lid open while WakeBee finishes setup." }
        if model.closedLid.needsApproval { return "Allow WakeBee under Login Items & Extensions, then return here." }
        if model.closedLid.issueMessage != nil { return "Closed-lid mode isn’t ready yet. Keep the lid open. The setup details below can help us find out why." }
        return "Set up once. If macOS asks, allow WakeBee to run in the background. Closed-lid mode will turn on when you return; then start a session."
    }
}
