# WakeBee 0.15.5

Longer closed-lid sessions on a charger and a quieter menu bar.

- **Keep working on a charger:** closed-lid mode lasts as long as your session. Select **Unlimited** to run until you stop, without the previous four-hour cutoff.
- **Battery limits remain:** choose up to four hours, including new three-hour and four-hour options. Plugging in pauses the battery timer without resetting it. Existing battery-cutoff, temperature, and connection safeguards remain active.
- **A quieter menu bar:** choose a color or monochrome bee in **Settings → General**. The green dot still indicates an active session.
- **Consistent settings:** icon and battery dropdowns now use WakeBee’s glass controls.
- **Closed-lid recovery:** after a safety stop restores normal sleep settings, the helper requests sleep if the lid is closed.

WakeBee 0.15.x users can update through **Check for Updates**. End your session and keep the lid open during installation.

## One-time upgrade from 0.14 or earlier

This release requires a manual installation because the app’s identity has changed.

1. Keep the lid open. In your existing app, end any running session.
2. If you previously set up closed-lid mode, go to **Settings → Closed Lid → Advanced → Remove closed-lid setup**. Wait for it to finish before continuing.
3. Turn off **Launch at login** in the old app, then quit it. Keep a backup until migration is complete.
4. Download **WakeBee-0.15.5.dmg**, drag **WakeBee.app** into **Applications**, and open it there.
5. Your saved preferences and Polar activation are imported on first launch. Allow Keychain access if macOS asks, and connect to the internet to verify the license. If access is denied, enter your existing license key again.
6. Set up closed-lid mode again if you use it, approve WakeBee in System Settings when prompted, and enable Launch at login again if desired.

The new app will not start closed-lid sessions while the previous helper or its pending recovery state remains. If you replaced the old app before removing its setup, reopen your backup and finish step 2. Do not run both versions at once.

Future updates use WakeBee’s new signed update feed. The old feed offers this release as a manual upgrade, without automatically replacing an app with a different bundle identifier.

## New installations

Drag WakeBee.app into Applications, open it, and enter the license key from your Polar purchase email. Closed-lid mode is optional and has its own setup.

Requires macOS 14 or later. Includes Apple silicon and Intel builds. Apple notarization does not establish closed-lid compatibility with every Mac; confirm readiness in the app before closing the lid.
