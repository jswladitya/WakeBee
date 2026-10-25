import WakeBeeCore
import SwiftUI

struct ClosedLidBatterySettings: View {
    @Bindable var preferences: Preferences
    let modeEnabled: Bool

    var body: some View {
        SettingsGlassSection(title: "On battery", detail: batteryExplanation) {
            Toggle("Keep running on battery", isOn: Binding(
                get: { preferences.allowClosedLidOnBattery && !preferences.requirePowerAdapter },
                set: { preferences.setClosedLidBatteryUse($0) }))
                .accessibilityLabel("Keep running with the lid closed on battery")
            Text("Applies to your session and closed-lid mode. No other switch is needed.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                if preferences.allowClosedLidOnBattery {
                    Divider()
                    HStack {
                        Text("Stop at battery level")
                        Spacer()
                        SettingsMenuPicker(title: "Stop at battery level", selection: $preferences.closedLidBatteryCutoff,
                                           value: "\(preferences.closedLidBatteryCutoff)%", width: 90) {
                            ForEach(ClosedLidPolicy.batteryCutoffs, id: \.self) { cutoff in
                                Text("\(cutoff)%").tag(cutoff)
                            }
                        }
                    }
                    Divider()
                    HStack {
                        Text("Time on battery")
                        Spacer()
                        SettingsMenuPicker(title: "Maximum time on battery", selection: $preferences.closedLidBatteryMinutes,
                                           value: durationLabel(preferences.closedLidBatteryMinutes), width: 145) {
                            ForEach(ClosedLidPolicy.batteryDurations, id: \.self) { minutes in
                                Text(durationLabel(minutes)).tag(minutes)
                            }
                        }
                    }
                }
                if modeEnabled {
                    Text("End the current session before changing battery limits.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
        }
        .disabled(modeEnabled)
    }

    private var batteryExplanation: String? {
        guard !preferences.requirePowerAdapter else { return "Connect your charger, or enable battery use here before starting." }
        guard preferences.allowClosedLidOnBattery else {
            return "Closed-lid mode turns off when you unplug."
        }
        return "Turns off at \(preferences.closedLidBatteryCutoff)% battery or after \(durationLabel(preferences.closedLidBatteryMinutes)) on battery, whichever comes first. On a charger, it lasts as long as your session."
    }

    private func durationLabel(_ minutes: Int) -> String {
        switch minutes {
        case 60: "1 hour"
        case 90: "1½ hours"
        case let minutes where minutes % 60 == 0: "\(minutes / 60) hours"
        default: "\(minutes) minutes"
        }
    }
}
