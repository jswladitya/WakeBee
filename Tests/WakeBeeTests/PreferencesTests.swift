import Foundation
import Testing
@testable import WakeBee

@MainActor @Suite struct PreferencesTests {
    @Test func newInstallRequiresAdapterAndOptOutSurvivesRelaunch() throws {
        let suite = "WakeBeeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let fresh = Preferences(defaults: defaults)
        #expect(fresh.requirePowerAdapter)
        #expect(fresh.sessionPowerPolicy.requiresAdapter)
        fresh.requirePowerAdapter = false
        let restored = Preferences(defaults: defaults)
        #expect(!restored.requirePowerAdapter)
        #expect(!restored.sessionPowerPolicy.requiresAdapter)
    }

    @Test func batteryChoiceUpdatesBothPoliciesAndPersists() throws {
        let suite = "WakeBeeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        preferences.setClosedLidBatteryUse(true)
        #expect(!preferences.sessionPowerPolicy.requiresAdapter)
        #expect(preferences.closedLidPolicy.allowsBattery)
        let restored = Preferences(defaults: defaults)
        #expect(!restored.requirePowerAdapter)
        #expect(restored.allowClosedLidOnBattery)
        restored.setClosedLidBatteryUse(false)
        #expect(!restored.closedLidPolicy.allowsBattery)
        #expect(!restored.requirePowerAdapter)
    }

    @Test func upgradePreservesExistingAdapterChoices() throws {
        for savedChoice in [false, true] {
            let suite = "WakeBeeTests.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            defaults.set(savedChoice, forKey: "requirePowerAdapter")
            #expect(Preferences(defaults: defaults).requirePowerAdapter == savedChoice)
        }
    }

    @Test func legacyNoBatteryTimerUpgradesToFourHours() throws {
        let suite = "WakeBeeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "allowClosedLidOnBattery")
        defaults.set(0, forKey: "closedLidBatteryMinutes")
        let preferences = Preferences(defaults: defaults)
        #expect(preferences.closedLidBatteryMinutes == 240)
        #expect(preferences.closedLidPolicy.maximumBatteryMinutes == 240)
        #expect(preferences.closedLidPolicy.allowsBattery)
    }

    @Test func menuBarIconDefaultsToColorAndPersistsChoice() throws {
        let suite = "WakeBeeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let fresh = Preferences(defaults: defaults)
        #expect(fresh.menuBarIconStyle == .color)
        fresh.menuBarIconStyle = .monochrome
        #expect(Preferences(defaults: defaults).menuBarIconStyle == .monochrome)
        defaults.set("sparkly", forKey: "menuBarIconStyle")
        #expect(Preferences(defaults: defaults).menuBarIconStyle == .color)
    }
}
