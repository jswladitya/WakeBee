import SwiftUI

struct GeneralSettingsView: View {
    let model: AppModel

    var body: some View {
        @Bindable var preferences = model.preferences
        SettingsScrollPage {
            SettingsGlassSection(title: "Startup", detail: "WakeBee opens in the menu bar. Sessions start when you choose.") {
                Toggle("Launch at login", isOn: Binding(get: { model.loginItem.isRegistered }, set: model.loginItem.setEnabled))
                if model.loginItem.needsApproval {
                    Button("Allow in System Settings…") { model.loginItem.openSystemSettings() }
                        .awakeGlassButton()
                }
                if let error = model.loginItem.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            SettingsGlassSection(title: "Sessions") {
                Toggle("Remember last duration", isOn: $preferences.rememberDuration)
                Divider()
                Toggle("Keep display awake", isOn: Binding(
                    get: { model.session.keepDisplayAwake }, set: model.setDisplayAwake))
                    .help("Keeps the display awake during an active session.")
                Divider()
                Toggle("Show time left in menu bar", isOn: $preferences.showsMenuBarCountdown)
                    .help("Shows the remaining time next to the bee during timed sessions.")
            }
            SessionPowerSettings(preferences: preferences, closedLidEnabled: model.closedLid.isEnabled || model.closedLid.isBusy)
            SettingsGlassSection(title: "Automation",
                                 detail: "Scripts and agents can control sessions with wakebee:// links. They follow the same license and power rules, and never turn on closed-lid mode.") {
                ForEach(AutomationExample.all) { example in
                    AutomationExampleRow(example: example)
                }
            }
            UpdateSettingsView(model: model)
            HStack {
                Link("WakeBee", destination: URL(string: "https://www.wakebee.app")!)
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
            }
            .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
        }
        .onChange(of: preferences.sessionPowerPolicy) { model.refreshPowerSettings() }
    }
}
