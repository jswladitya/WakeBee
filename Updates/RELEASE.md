# WakeBee 0.15.6

Clearer screen controls and more compact settings.

- **Keep screen on:** the renamed setting includes the guidance “Recommended for agents that click and type (computer use).”
- **On by default:** new installations start with Keep screen on enabled. Existing saved choices are preserved.
- **Tighter settings:** descriptions sit closer to their controls throughout General, Closed Lid, and License settings.
- **Clearer closed-lid help:** apps that click or type may need the screen on, lid open, and Mac unlocked.

WakeBee 0.15.x users can update through **Check for Updates**. End your session and keep the lid open during installation.

## One-time upgrade from 0.14 or earlier

This release requires a manual installation because the app’s identity has changed.

1. Keep the lid open. In your existing app, end any running session.
2. If you previously set up closed-lid mode, go to **Settings → Closed Lid → Advanced → Remove closed-lid setup**. Wait for it to finish before continuing.
3. Turn off **Launch at login** in the old app, then quit it. Keep a backup until migration is complete.
4. Download **WakeBee-0.15.6.dmg**, drag **WakeBee.app** into **Applications**, and open it there.
5. Your saved preferences and Polar activation are imported on first launch. Allow Keychain access if macOS asks, and connect to the internet to verify the license. If access is denied, enter your existing license key again.
6. Set up closed-lid mode again if you use it, approve WakeBee in System Settings when prompted, and enable Launch at login again if desired.

The new app will not start closed-lid sessions while the previous helper or its pending recovery state remains. If you replaced the old app before removing its setup, reopen your backup and finish step 2. Do not run both versions at once.

Future updates use WakeBee’s new signed update feed. Older versions use a different feed and require the manual migration above.

## New installations

Drag WakeBee.app into Applications, open it, and enter the license key from your Polar purchase email. Closed-lid mode is optional and has its own setup.

Requires macOS 14 or later. Includes Apple silicon and Intel builds. Apple notarization does not establish closed-lid compatibility with every Mac; confirm readiness in the app before closing the lid.
