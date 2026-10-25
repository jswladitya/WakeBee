import Foundation

/// Validated in both the app and the privileged helper. Battery use is opt-in.
public struct ClosedLidPolicy: Equatable, Sendable {
    public static let batteryCutoffs = Array(stride(from: 20, through: 80, by: 5))
    /// Battery time is always limited. The longest choice is the hard ceiling.
    public static let batteryDurations = [15, 30, 45, 60, 90, 120, 180, 240]
    /// Earlier builds saved 0 for "no battery timer". It now means the ceiling.
    static let legacyNoBatteryTimeLimit = 0
    public static let standard = ClosedLidPolicy()
    public let allowsBattery: Bool
    public let minimumBatteryPercent: Int
    public let maximumBatteryMinutes: Int

    private init() {
        allowsBattery = false
        minimumBatteryPercent = 30
        maximumBatteryMinutes = 30
    }

    public init(allowsBattery: Bool, minimumBatteryPercent: Int, maximumBatteryMinutes: Int) throws {
        let minutes = maximumBatteryMinutes == Self.legacyNoBatteryTimeLimit
            ? Self.batteryDurations[Self.batteryDurations.count - 1] : maximumBatteryMinutes
        guard Self.batteryCutoffs.contains(minimumBatteryPercent), Self.batteryDurations.contains(minutes)
        else { throw ClosedLidStopReason.invalidPolicy }
        self.allowsBattery = allowsBattery
        self.minimumBatteryPercent = minimumBatteryPercent
        self.maximumBatteryMinutes = minutes
    }

    public func stopReason(for power: ClosedLidPowerState) -> ClosedLidStopReason? {
        guard power.thermalSafe else { return .thermalPressure }
        guard power.source != .unknown else { return .powerUnknown }
        if let percentage = power.batteryPercent, !(0...100).contains(percentage) { return .powerUnknown }
        if power.source == .battery {
            guard allowsBattery else { return .powerRequired }
            guard let percentage = power.batteryPercent else { return .powerUnknown }
            if percentage <= minimumBatteryPercent { return .lowBattery(minimumBatteryPercent) }
        } else if let percentage = power.batteryPercent, percentage <= 20 {
            return .lowBattery(20)
        }
        return nil
    }
}

public struct ClosedLidPowerState: Sendable {
    public enum Source: Sendable { case adapter, battery, unknown }
    public let source: Source
    public let batteryPercent: Int?
    public let thermalSafe: Bool

    public init(source: Source, batteryPercent: Int?, thermalSafe: Bool = true) {
        self.source = source
        self.batteryPercent = batteryPercent
        self.thermalSafe = thermalSafe
    }
}

public enum ClosedLidStopReason: LocalizedError, Equatable, Sendable {
    case powerRequired, powerUnknown, thermalPressure, contactLost, invalidPolicy
    case lowBattery(Int), batteryTimeLimit(Int)

    public var errorDescription: String? {
        switch self {
        case .powerRequired: "Power was disconnected. Connect a charger or allow battery use in Closed Lid settings."
        case .powerUnknown: "Battery or power status is unavailable. Keep the lid open and try again."
        case .thermalPressure: "Your Mac needs to cool down. Keep the lid open and turn this mode on again once it has cooled."
        case .contactLost: "WakeBee lost its connection. Keep the lid open and turn closed-lid mode on again."
        case .invalidPolicy: "Choose a battery level from 20–80% and one of the available time limits."
        case .lowBattery(let cutoff): "Battery reached \(cutoff)%. Connect a charger before turning closed-lid mode on again."
        case .batteryTimeLimit(let minutes):
            "Closed-lid mode reached its \(minutes % 60 == 0 ? "\(minutes / 60)-hour" : "\(minutes)-minute") limit on battery."
        }
    }
}
