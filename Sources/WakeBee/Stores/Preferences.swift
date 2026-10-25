import WakeBeeCore
import Foundation
import Observation

@MainActor @Observable
final class Preferences {
    private let defaults: UserDefaults
    var rememberDuration: Bool { didSet { defaults.set(rememberDuration, forKey: "rememberDuration") } }
    var keepDisplayAwake: Bool { didSet { defaults.set(keepDisplayAwake, forKey: "keepDisplayAwake") } }
    var allowClosedLidOnBattery: Bool { didSet { defaults.set(allowClosedLidOnBattery, forKey: "allowClosedLidOnBattery") } }
    var closedLidBatteryCutoff: Int { didSet { defaults.set(closedLidBatteryCutoff, forKey: "closedLidBatteryCutoff") } }
    var closedLidBatteryMinutes: Int { didSet { defaults.set(closedLidBatteryMinutes, forKey: "closedLidBatteryMinutes") } }
    var endSessionOnLowBattery: Bool { didSet { defaults.set(endSessionOnLowBattery, forKey: "endSessionOnLowBattery") } }
    var requirePowerAdapter: Bool { didSet { defaults.set(requirePowerAdapter, forKey: "requirePowerAdapter") } }
    var menuBarIconStyle: MenuBarIconStyle { didSet { defaults.set(menuBarIconStyle.rawValue, forKey: "menuBarIconStyle") } }
    private var savedMinutes: Int { didSet { defaults.set(savedMinutes, forKey: "savedMinutes") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        for key in ["agentProtectionEnabled", "notificationsEnabled", "maximumAgentHours", "cooldownSeconds",
                    "appWatchingEnabled", "taskApplications", "watchedApplications"] {
            defaults.removeObject(forKey: key)
        }
        defaults.register(defaults: ["rememberDuration": true, "savedMinutes": 30,
                                    "keepDisplayAwake": false,
                                    "allowClosedLidOnBattery": false, "closedLidBatteryCutoff": 30,
                                    "closedLidBatteryMinutes": 30, "endSessionOnLowBattery": true,
                                    "requirePowerAdapter": true,
                                    "menuBarIconStyle": MenuBarIconStyle.color.rawValue])
        rememberDuration = defaults.bool(forKey: "rememberDuration")
        keepDisplayAwake = defaults.bool(forKey: "keepDisplayAwake")
        savedMinutes = defaults.integer(forKey: "savedMinutes")
        let policy = (try? ClosedLidPolicy(allowsBattery: defaults.bool(forKey: "allowClosedLidOnBattery"),
                                           minimumBatteryPercent: defaults.integer(forKey: "closedLidBatteryCutoff"),
                                           maximumBatteryMinutes: defaults.integer(forKey: "closedLidBatteryMinutes"))) ?? .standard
        allowClosedLidOnBattery = policy.allowsBattery
        closedLidBatteryCutoff = policy.minimumBatteryPercent
        closedLidBatteryMinutes = policy.maximumBatteryMinutes
        endSessionOnLowBattery = defaults.bool(forKey: "endSessionOnLowBattery")
        requirePowerAdapter = defaults.bool(forKey: "requirePowerAdapter")
        menuBarIconStyle = defaults.string(forKey: "menuBarIconStyle").flatMap { MenuBarIconStyle(rawValue: $0) } ?? .color
    }

    func setClosedLidBatteryUse(_ enabled: Bool) {
        allowClosedLidOnBattery = enabled
        if enabled { requirePowerAdapter = false }
    }

    var sessionPowerPolicy: SessionPowerPolicy {
        SessionPowerPolicy(batteryCutoff: endSessionOnLowBattery ? closedLidBatteryCutoff : nil,
                           requiresAdapter: requirePowerAdapter)
    }

    var closedLidPolicy: ClosedLidPolicy {
        (try? ClosedLidPolicy(allowsBattery: allowClosedLidOnBattery,
                             minimumBatteryPercent: closedLidBatteryCutoff,
                             maximumBatteryMinutes: closedLidBatteryMinutes)) ?? .standard
    }

    var initialMinutes: Int {
        guard rememberDuration, (1...SessionDuration.maximumMinutes).contains(savedMinutes) else { return 30 }
        return savedMinutes
    }

    func remember(_ duration: SessionDuration) {
        guard rememberDuration else { return }
        if case .minutes(let minutes) = duration { savedMinutes = minutes }
    }
}

enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case color, monochrome
    var id: Self { self }
    var label: String {
        switch self {
        case .color: "Color"
        case .monochrome: "Monochrome"
        }
    }
}
