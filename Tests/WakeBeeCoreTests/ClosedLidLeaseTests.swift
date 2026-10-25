import Foundation
import Testing
@testable import WakeBeeCore

private final class MemorySleepSetting: SleepSettingManaging {
    var disabled = false
    var recovery: Bool?
    var failSave = false
    var failRestore = false
    var failAfterRestore = false
    var writes: [Bool] = []
    var sleepRequests = 0
    func readDisabled() throws -> Bool { disabled }
    func writeDisabled(_ value: Bool) throws {
        if !value && failRestore { throw Failure.denied }
        writes.append(value); disabled = value
        if !value && failAfterRestore { throw Failure.denied }
    }
    func saveRecovery(_ previousValue: Bool) throws {
        if failSave { throw Failure.denied }; recovery = previousValue
    }
    func loadRecovery() throws -> Bool? { recovery }
    func clearRecovery() throws { recovery = nil }
    func sleepIfLidClosed() { sleepRequests += 1 }
    enum Failure: Error { case denied }
}

@Suite struct ClosedLidLeaseTests {
    private let adapter = ClosedLidPowerState(source: .adapter, batteryPercent: 80)
    private let battery = ClosedLidPowerState(source: .battery, batteryPercent: 80)
    @Test func idlePollingStopsOnlyAfterRecoverySucceeds() throws {
        let setting = MemorySleepSetting(), client = UUID()
        let lease = ClosedLidLease(setting: setting)
        #expect(lease.needsMonitoring)
        try lease.recover()
        #expect(!lease.needsMonitoring)
        try lease.renew(client: client, now: 0, power: adapter)
        #expect(lease.needsMonitoring)
        setting.failRestore = true
        #expect(throws: MemorySleepSetting.Failure.self) { try lease.release(client: client) }
        #expect(lease.needsMonitoring)
        setting.failRestore = false
        try lease.tick(now: 1, power: adapter)
        #expect(!lease.needsMonitoring)
        #expect(!setting.disabled)
    }

    @Test func lostClientExpiresIn30SecondsAndRestores() throws {
        let setting = MemorySleepSetting(), client = UUID()
        let lease = ClosedLidLease(setting: setting)
        try lease.renew(client: client, now: 0, power: adapter)
        #expect(setting.disabled && setting.recovery == false)
        try lease.tick(now: 29, power: adapter)
        #expect(setting.disabled)
        try lease.tick(now: 30, power: adapter)
        #expect(!setting.disabled && setting.recovery == nil)
    }
    @Test func multipleClientsCannotReleaseEachOthersProtection() throws {
        let setting = MemorySleepSetting(), a = UUID(), b = UUID()
        let lease = ClosedLidLease(setting: setting)
        try lease.renew(client: a, now: 0, power: adapter)
        try lease.renew(client: b, now: 10, power: adapter)
        try lease.release(client: a)
        #expect(setting.disabled)
        try lease.release(client: b)
        #expect(!setting.disabled)
    }
    @Test func previousDisabledSettingIsPreserved() throws {
        let setting = MemorySleepSetting(), id = UUID()
        setting.disabled = true
        let lease = ClosedLidLease(setting: setting)
        try lease.renew(client: id, now: 0, power: adapter)
        try lease.release(client: id)
        #expect(setting.disabled && setting.recovery == nil)
    }
    @Test func crashRecoveryRestoresBeforeNewLease() throws {
        let setting = MemorySleepSetting()
        setting.recovery = false; setting.disabled = true
        let lease = ClosedLidLease(setting: setting)
        try lease.recover()
        #expect(!setting.disabled && setting.recovery == nil)
    }
    @Test func cannotChangeSettingWithoutDurableRecovery() {
        let setting = MemorySleepSetting()
        setting.failSave = true
        let lease = ClosedLidLease(setting: setting)
        #expect(throws: (any Error).self) { try lease.renew(client: UUID(), now: 0, power: adapter) }
        #expect(!setting.disabled && setting.writes.isEmpty)
    }
    @Test func failedRestorationRetainsJournalAndRetries() throws {
        let setting = MemorySleepSetting(), id = UUID()
        let lease = ClosedLidLease(setting: setting)
        try lease.renew(client: id, now: 0, power: adapter)
        setting.failRestore = true
        #expect(throws: (any Error).self) { try lease.release(client: id) }
        #expect(setting.recovery == false)
        setting.failRestore = false
        try lease.tick(now: 31, power: adapter)
        #expect(!setting.disabled && setting.recovery == nil)
    }
    @Test func unsafePowerOrTemperatureRevokesEveryLease() throws {
        let setting = MemorySleepSetting()
        let lease = ClosedLidLease(setting: setting)
        try lease.renew(client: UUID(), now: 0, power: adapter)
        try lease.tick(now: 1, power: battery)
        #expect(!setting.disabled)
        #expect(throws: (any Error).self) { try lease.renew(client: UUID(), now: 2, power: battery) }
    }
    @Test func unverifiedRestoreCannotBeReusedAsActiveProtection() throws {
        let setting = MemorySleepSetting(), id = UUID()
        let lease = ClosedLidLease(setting: setting)
        try lease.renew(client: id, now: 0, power: adapter)
        setting.failAfterRestore = true
        #expect(throws: (any Error).self) { try lease.release(client: id) }
        #expect(!setting.disabled)
        #expect(throws: (any Error).self) { try lease.renew(client: UUID(), now: 1, power: adapter) }
        #expect(!setting.disabled && setting.recovery == false)
    }
    @Test func adapterLeaseLastsAsLongAsTheAppRenews() throws {
        let setting = MemorySleepSetting(), id = UUID()
        let lease = ClosedLidLease(setting: setting)
        for second in stride(from: 0, through: 12 * 3600, by: 10) {
            try lease.renew(client: id, now: Double(second), power: adapter)
        }
        try lease.tick(now: 12 * 3600 + 1, power: adapter)
        #expect(setting.disabled)
        try lease.release(client: id)
        #expect(!setting.disabled && setting.recovery == nil && setting.sleepRequests == 0)
    }

    @Test func optedInSessionContinuesAfterUnplugging() throws {
        let setting = MemorySleepSetting(), id = UUID()
        let lease = ClosedLidLease(setting: setting)
        let policy = try ClosedLidPolicy(allowsBattery: true, minimumBatteryPercent: 30, maximumBatteryMinutes: 30)
        try lease.renew(client: id, now: 0, policy: policy, power: adapter)
        try lease.tick(now: 1, power: battery)
        try lease.renew(client: id, now: 10, policy: policy, power: battery)
        #expect(setting.disabled)
        try lease.release(client: id)
        #expect(!setting.disabled && setting.recovery == nil)
    }

    @Test func defaultUnplugStopCannotSilentlyResumeAfterReconnecting() throws {
        let setting = MemorySleepSetting(), id = UUID()
        let lease = ClosedLidLease(setting: setting)
        try lease.renew(client: id, now: 0, power: adapter)
        try lease.tick(now: 1, power: battery)
        #expect(!setting.disabled)
        #expect(throws: ClosedLidStopReason.powerRequired) {
            try lease.renew(client: id, now: 2, power: adapter)
        }
        #expect(!setting.disabled)
        try lease.release(client: id)
        try lease.renew(client: id, now: 3, power: adapter)
        #expect(setting.disabled)
    }

    @Test func watchdogEnforcesCutoffWithoutWaitingForAppRenewal() throws {
        let setting = MemorySleepSetting(), id = UUID()
        let lease = ClosedLidLease(setting: setting)
        let policy = try ClosedLidPolicy(allowsBattery: true, minimumBatteryPercent: 45, maximumBatteryMinutes: 30)
        try lease.renew(client: id, now: 0, policy: policy, power: battery)
        try lease.tick(now: 1, power: .init(source: .battery, batteryPercent: 45))
        #expect(!setting.disabled && setting.recovery == nil)
        #expect(throws: ClosedLidStopReason.lowBattery(45)) {
            try lease.renew(client: id, now: 2, policy: policy, power: adapter)
        }
    }

    @Test(arguments: ClosedLidPolicy.batteryDurations)
    func everyBatteryDurationExpiresAtBoundary(_ minutes: Int) throws {
        let setting = MemorySleepSetting(), id = UUID()
        let lease = ClosedLidLease(setting: setting)
        let policy = try ClosedLidPolicy(allowsBattery: true, minimumBatteryPercent: 30, maximumBatteryMinutes: minutes)
        for second in stride(from: 0, to: minutes * 60, by: 10) {
            try lease.renew(client: id, now: Double(second), policy: policy, power: battery)
        }
        try lease.tick(now: Double(minutes * 60 - 1), power: battery)
        #expect(setting.disabled)
        try lease.tick(now: Double(minutes * 60), power: battery)
        #expect(!setting.disabled)
        #expect(throws: ClosedLidStopReason.batteryTimeLimit(minutes)) {
            try lease.renew(client: id, now: Double(minutes * 60 + 1), policy: policy, power: battery)
        }
    }

    @Test func reconnectingPowerPausesButNeverResetsBatteryBudget() throws {
        let setting = MemorySleepSetting(), id = UUID()
        let lease = ClosedLidLease(setting: setting)
        let policy = try ClosedLidPolicy(allowsBattery: true, minimumBatteryPercent: 30, maximumBatteryMinutes: 15)
        for second in stride(from: 0, through: 440, by: 10) {
            try lease.renew(client: id, now: Double(second), policy: policy, power: battery)
        }
        // First 450 seconds on battery, then 1,000 seconds on the adapter.
        for second in stride(from: 450, through: 1_450, by: 10) {
            try lease.renew(client: id, now: Double(second), policy: policy, power: adapter)
        }
        for second in stride(from: 1_460, through: 1_890, by: 10) {
            try lease.renew(client: id, now: Double(second), policy: policy, power: battery)
        }
        #expect(setting.disabled)
        try lease.tick(now: 1_900, power: battery)
        #expect(!setting.disabled)
        #expect(throws: ClosedLidStopReason.batteryTimeLimit(15)) {
            try lease.renew(client: id, now: 1_901, policy: policy, power: battery)
        }
    }

    @Test func legacyNoBatteryTimerStopsAtFourHoursOnBattery() throws {
        let setting = MemorySleepSetting(), id = UUID()
        let lease = ClosedLidLease(setting: setting)
        let policy = try ClosedLidPolicy(allowsBattery: true, minimumBatteryPercent: 20,
                                        maximumBatteryMinutes: ClosedLidPolicy.legacyNoBatteryTimeLimit)
        for second in stride(from: 0, to: 4 * 3600, by: 10) {
            try lease.renew(client: id, now: Double(second), policy: policy, power: battery)
            #expect(setting.disabled)
        }
        try lease.tick(now: 4 * 3600 - 1, power: battery)
        #expect(setting.disabled)
        try lease.tick(now: 4 * 3600, power: battery)
        #expect(!setting.disabled && setting.recovery == nil)
        #expect(throws: ClosedLidStopReason.batteryTimeLimit(240)) {
            try lease.renew(client: id, now: 4 * 3600 + 1, policy: policy, power: adapter)
        }
    }

    @Test func chargerBreaksCannotStretchBatteryTimePastFourHours() throws {
        let setting = MemorySleepSetting(), id = UUID()
        let lease = ClosedLidLease(setting: setting)
        let policy = try ClosedLidPolicy(allowsBattery: true, minimumBatteryPercent: 20, maximumBatteryMinutes: 240)
        // Two hours on battery, three on the charger, then battery again. Each
        // switch counts its 10-second sample as battery time, so the ceiling
        // arrives 10 seconds before 7 hours.
        for second in stride(from: 0, to: 2 * 3600, by: 10) {
            try lease.renew(client: id, now: Double(second), policy: policy, power: battery)
        }
        for second in stride(from: 2 * 3600, to: 5 * 3600, by: 10) {
            try lease.renew(client: id, now: Double(second), policy: policy, power: adapter)
        }
        for second in stride(from: 5 * 3600, to: 7 * 3600 - 10, by: 10) {
            try lease.renew(client: id, now: Double(second), policy: policy, power: battery)
        }
        #expect(setting.disabled)
        try lease.tick(now: 7 * 3600 - 10, power: battery)
        #expect(!setting.disabled)
        #expect(throws: ClosedLidStopReason.batteryTimeLimit(240)) {
            try lease.renew(client: id, now: 7 * 3600, policy: policy, power: adapter)
        }
    }

    @Test func longestBatteryLimitStillStopsAndLatchesForUnsafePowerOrHeat() throws {
        let policy = try ClosedLidPolicy(allowsBattery: true, minimumBatteryPercent: 45, maximumBatteryMinutes: 240)
        let cases: [(ClosedLidPowerState, ClosedLidStopReason)] = [
            (.init(source: .battery, batteryPercent: 45), .lowBattery(45)),
            (.init(source: .battery, batteryPercent: 80, thermalSafe: false), .thermalPressure),
            (.init(source: .battery, batteryPercent: nil), .powerUnknown),
            (.init(source: .unknown, batteryPercent: nil), .powerUnknown)
        ]
        for (unsafePower, reason) in cases {
            let setting = MemorySleepSetting(), id = UUID()
            let lease = ClosedLidLease(setting: setting)
            try lease.renew(client: id, now: 0, policy: policy, power: battery)
            try lease.tick(now: 1, power: unsafePower)
            #expect(!setting.disabled && setting.recovery == nil)
            #expect(throws: reason) {
                try lease.renew(client: id, now: 2, policy: policy, power: adapter)
            }
        }
    }

    @Test func longestBatteryLimitStillExpiresWhenAppContactIsLost() throws {
        let setting = MemorySleepSetting(), id = UUID()
        let lease = ClosedLidLease(setting: setting)
        let policy = try ClosedLidPolicy(allowsBattery: true, minimumBatteryPercent: 45, maximumBatteryMinutes: 240)
        try lease.renew(client: id, now: 0, policy: policy, power: battery)
        try lease.tick(now: 29, power: battery)
        #expect(setting.disabled)
        try lease.tick(now: 30, power: battery)
        #expect(!setting.disabled && setting.recovery == nil)
        #expect(throws: ClosedLidStopReason.contactLost) {
            try lease.renew(client: id, now: 31, policy: policy, power: adapter)
        }
    }

    @Test func failedBatteryStopRetainsRecoveryAndRetries() throws {
        let setting = MemorySleepSetting(), id = UUID()
        let lease = ClosedLidLease(setting: setting)
        let policy = try ClosedLidPolicy(allowsBattery: true, minimumBatteryPercent: 30, maximumBatteryMinutes: 30)
        try lease.renew(client: id, now: 0, policy: policy, power: battery)
        setting.failRestore = true
        #expect(throws: (any Error).self) {
            try lease.tick(now: 1, power: .init(source: .battery, batteryPercent: 29))
        }
        #expect(setting.recovery == false)
        setting.failRestore = false
        try lease.tick(now: 2, power: battery)
        #expect(!setting.disabled && setting.recovery == nil)
    }

    @Test func separateClientCannotWeakenAnotherClientsPolicy() throws {
        let setting = MemorySleepSetting(), a = UUID(), b = UUID()
        let lease = ClosedLidLease(setting: setting)
        let policy = try ClosedLidPolicy(allowsBattery: true, minimumBatteryPercent: 30, maximumBatteryMinutes: 30)
        try lease.renew(client: a, now: 0, power: adapter)
        try lease.renew(client: b, now: 0, policy: policy, power: adapter)
        try lease.tick(now: 1, power: battery)
        #expect(setting.disabled) // Only the opted-in client still owns a lease.
        #expect(throws: ClosedLidStopReason.powerRequired) {
            try lease.renew(client: a, now: 2, power: battery)
        }
        try lease.release(client: b)
        #expect(!setting.disabled)
    }

    @Test func batteryPermissionCannotBypassHeatOrUnknownPower() throws {
        let policy = try ClosedLidPolicy(allowsBattery: true, minimumBatteryPercent: 20, maximumBatteryMinutes: 120)
        for unsafePower in [ClosedLidPowerState(source: .battery, batteryPercent: 100, thermalSafe: false),
                            .init(source: .unknown, batteryPercent: nil)] {
            let setting = MemorySleepSetting(), id = UUID()
            let lease = ClosedLidLease(setting: setting)
            try lease.renew(client: id, now: 0, policy: policy, power: battery)
            try lease.tick(now: 1, power: unsafePower)
            #expect(!setting.disabled)
            #expect(throws: (any Error).self) {
                try lease.renew(client: id, now: 2, policy: policy, power: battery)
            }
        }
    }

    @Test func batteryPermissionAddsNoTimeLimitOnTheCharger() throws {
        let setting = MemorySleepSetting(), id = UUID()
        let lease = ClosedLidLease(setting: setting)
        let policy = try ClosedLidPolicy(allowsBattery: true, minimumBatteryPercent: 30, maximumBatteryMinutes: 15)
        for second in stride(from: 0, through: 8 * 3600, by: 10) {
            try lease.renew(client: id, now: Double(second), policy: policy, power: adapter)
        }
        #expect(setting.disabled)
    }

    @Test func heatStillStopsALongChargerRunAndSleepsTheMac() throws {
        let setting = MemorySleepSetting(), id = UUID()
        let lease = ClosedLidLease(setting: setting)
        for second in stride(from: 0, through: 10 * 3600, by: 10) {
            try lease.renew(client: id, now: Double(second), power: adapter)
        }
        try lease.tick(now: 10 * 3600 + 1, power: .init(source: .adapter, batteryPercent: 100, thermalSafe: false))
        #expect(!setting.disabled && setting.recovery == nil && setting.sleepRequests == 1)
        #expect(throws: ClosedLidStopReason.thermalPressure) {
            try lease.renew(client: id, now: 10 * 3600 + 2, power: adapter)
        }
    }

    // MARK: Sleeping a closed Mac after a safety stop

    @Test(arguments: [
        ClosedLidPowerState(source: .battery, batteryPercent: 80),
        .init(source: .adapter, batteryPercent: 20),
        .init(source: .adapter, batteryPercent: 80, thermalSafe: false),
        .init(source: .unknown, batteryPercent: nil)
    ])
    func everySafetyStopRequestsSleepOnce(_ unsafePower: ClosedLidPowerState) throws {
        let setting = MemorySleepSetting(), id = UUID()
        let lease = ClosedLidLease(setting: setting)
        try lease.renew(client: id, now: 0, power: adapter)
        try lease.tick(now: 1, power: unsafePower)
        #expect(!setting.disabled && setting.sleepRequests == 1)
        // The latched stop never requests sleep again.
        #expect(throws: (any Error).self) { try lease.renew(client: id, now: 2, power: adapter) }
        try lease.tick(now: 3, power: unsafePower)
        try lease.release(client: id)
        #expect(setting.sleepRequests == 1)
    }

    @Test func lostAppContactRequestsSleep() throws {
        let setting = MemorySleepSetting(), id = UUID()
        let lease = ClosedLidLease(setting: setting)
        try lease.renew(client: id, now: 0, power: adapter)
        try lease.tick(now: 30, power: adapter)
        #expect(!setting.disabled && setting.sleepRequests == 1)
    }

    @Test func endingTheSessionNeverForcesSleep() throws {
        let setting = MemorySleepSetting(), id = UUID()
        let lease = ClosedLidLease(setting: setting)
        try lease.renew(client: id, now: 0, power: adapter)
        try lease.release(client: id)
        try lease.tick(now: 1, power: adapter)
        #expect(!setting.disabled && setting.sleepRequests == 0)
    }

    @Test func stopNeverSleepsWhenTheUserHadAlreadyDisabledSleep() throws {
        let setting = MemorySleepSetting(), id = UUID()
        setting.disabled = true
        let lease = ClosedLidLease(setting: setting)
        try lease.renew(client: id, now: 0, power: adapter)
        try lease.tick(now: 1, power: battery)
        #expect(setting.disabled && setting.recovery == nil && setting.sleepRequests == 0)
    }

    @Test func rejectedStartNeverForcesSleep() throws {
        let setting = MemorySleepSetting()
        let lease = ClosedLidLease(setting: setting)
        #expect(throws: ClosedLidStopReason.powerRequired) {
            try lease.renew(client: UUID(), now: 0, power: battery)
        }
        #expect(!setting.disabled && setting.writes.isEmpty && setting.sleepRequests == 0)
    }

    @Test func stopWhileAnotherLeaseIsLiveNeverForcesSleep() throws {
        let setting = MemorySleepSetting(), a = UUID(), b = UUID()
        let lease = ClosedLidLease(setting: setting)
        let policy = try ClosedLidPolicy(allowsBattery: true, minimumBatteryPercent: 30, maximumBatteryMinutes: 30)
        try lease.renew(client: a, now: 0, power: adapter)
        try lease.renew(client: b, now: 0, policy: policy, power: adapter)
        try lease.tick(now: 1, power: battery)
        #expect(setting.disabled && setting.sleepRequests == 0)
        try lease.release(client: b)
        #expect(!setting.disabled && setting.sleepRequests == 0)
    }

    @Test func failedRestoreSleepsOnlyOnceTheRetrySucceeds() throws {
        let setting = MemorySleepSetting(), id = UUID()
        let lease = ClosedLidLease(setting: setting)
        try lease.renew(client: id, now: 0, power: adapter)
        setting.failRestore = true
        #expect(throws: (any Error).self) { try lease.tick(now: 1, power: battery) }
        #expect(setting.disabled && setting.sleepRequests == 0)
        setting.failRestore = false
        try lease.tick(now: 2, power: battery)
        #expect(!setting.disabled && setting.sleepRequests == 1)
        try lease.tick(now: 3, power: battery)
        #expect(setting.sleepRequests == 1)
    }

    @Test func crashRecoveryNeverForcesSleep() throws {
        let setting = MemorySleepSetting()
        setting.recovery = false; setting.disabled = true
        let lease = ClosedLidLease(setting: setting)
        try lease.recover()
        #expect(!setting.disabled && setting.sleepRequests == 0)
    }
}
