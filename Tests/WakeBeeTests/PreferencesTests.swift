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

    @Test func menuBarCountdownIsOptInAndPersists() throws {
        let suite = "WakeBeeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        #expect(!preferences.showsMenuBarCountdown)
        preferences.showsMenuBarCountdown = true
        #expect(Preferences(defaults: defaults).showsMenuBarCountdown)
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
}
