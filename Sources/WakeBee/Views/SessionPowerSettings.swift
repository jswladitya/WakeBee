import WakeBeeCore
import SwiftUI

struct SessionPowerSettings: View {
    @Bindable var preferences: Preferences
    let closedLidEnabled: Bool

    var body: some View {
        SettingsGlassSection(title: "Battery & Power", detail: "Closed-lid mode uses the same battery level.") {
            Toggle("Require a power adapter", isOn: $preferences.requirePowerAdapter)
                .help("Ends the session when you unplug. Turn off to allow sessions on battery.")
            Text(preferences.requirePowerAdapter ? "Sessions end when you unplug." : "Sessions can continue on battery.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Toggle("End sessions on low battery", isOn: $preferences.endSessionOnLowBattery)
            Divider()
            HStack {
                Text("Battery cutoff")
                Spacer()
                SettingsMenuPicker(title: "Battery cutoff", selection: $preferences.closedLidBatteryCutoff,
                                   value: "\(preferences.closedLidBatteryCutoff)%", width: 90) {
                    ForEach(ClosedLidPolicy.batteryCutoffs, id: \.self) { cutoff in
                        Text("\(cutoff)%").tag(cutoff)
                    }
                }
                .disabled(closedLidEnabled)
            }
            if closedLidEnabled {
                Text("Turn off closed-lid mode to change the battery level.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
