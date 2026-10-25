# Developing WakeBee

WakeBee is a Swift Package Manager project. Use the bundle script for the native app: running the raw executable alone does not provide the app resources, embedded Sparkle framework, or helper registration files.

## Requirements

- Xcode with the macOS 26.1 SDK or newer and Swift 6 support. Select that Xcode installation as your active developer directory.
- Python 3 for the build destination checks and packaging scripts.
- Internet access for the first Sparkle dependency download.

The deployment target is macOS 14. Newer SwiftUI controls are guarded by availability checks.

## Build and run

```sh
./script/build_and_run.sh --build-only
open dist/WakeBee.app
```

The build stages a complete bundle, includes the WakeBee and Sparkle license texts, signs nested components, verifies the signature, and then replaces the destination. Quit a running copy at that destination before rebuilding.

For an everyday edit/build/run cycle:

```sh
./script/build_and_run.sh
```

That command quits an existing WakeBee process before launching the new build. End any session first. Build-only does not stop the running app; it refuses to replace its bundle.

The script also supports `--verify`, `--logs`, `--telemetry`, and `--debug`. These modes launch the app, so use them deliberately when you already have a session running.

## Signing and closed-lid development

Without a signing identity, the bundle uses an ad-hoc signature. You can build and inspect the interface, but the privileged helper refuses ad-hoc clients. The current app's activation requirement also remains in local builds.

To use an installed Apple signing identity:

```sh
WAKEBEE_SIGN_IDENTITY="YOUR_SIGNING_IDENTITY" \
  ./script/build_and_run.sh --build-only
```

The app and helper must share the same signing team. Registration also requires approval when macOS asks. Keep the lid open until the app explicitly confirms readiness.

The script can alternatively read the certificate fingerprint from a local `.signing-identity` file. That file is ignored by Git. No signing keys, notarization credentials, or real app-license keys belong in the repository.

Useful build variables:

| Variable | Purpose |
| --- | --- |
| `WAKEBEE_SIGN_IDENTITY` | Signing identity; `-` selects ad-hoc signing. |
| `WAKEBEE_DESTINATION` | Override the output app bundle path. |
| `WAKEBEE_BUILD_CONFIGURATION` | `debug` (default) or `release`. |
| `WAKEBEE_UNIVERSAL=1` | Build both Apple silicon and Intel architectures. |

The original bee artwork is in [`Resources/WakeBee.png`](../Resources/WakeBee.png). The build script regenerates the ICNS asset when the artwork or icon generator changes.

## Run checks

```sh
swift test --disable-sandbox
python3 -m unittest discover -s script -p 'test_*.py'
```

The Swift suites cover session timing, power rules, licensing, helper registration, recovery, and preferences. Helper policy tests use fake system settings; license tests use fake storage and responses. They do not require signing credentials, a purchased key, or a live Polar request.

The Python tests cover release-publication guards, build destinations, notarization-profile selection, and migration cleanup. They do not publish a release.

For UI changes, build the bundle and check all three session modes and the affected settings in the native app. Automated policy tests cannot establish real lid-close behavior on every Mac model. Power-management changes need a short physical test on the relevant hardware, including ending the session and confirming normal sleep is restored.

## Power-management boundaries

- Normal sessions own IOKit idle-sleep assertions; optional display assertions follow the display setting.
- The approved helper changes `pmset disablesleep` for closed-lid sessions. This is a system-wide setting.
- XPC authenticates the app's identifier and signing team. The helper exposes bounded operations, not arbitrary commands.
- A durable recovery journal records the previous setting before it changes.
- Leases expire after 30 seconds without renewal. The helper checks limits every second and restores the prior setting when no live lease remains.
- On a charger, closed-lid sessions last while the app renews the lease. Battery use has a cumulative limit of at most four hours; plugging in pauses that budget without resetting it. Battery, thermal, power-reading, and connection limits can stop a session earlier. Failed restoration keeps the journal for retry.
- Relaunch does not restart a session or automatically enable closed-lid mode.

Keep these guarantees intact when changing the helper, session controller, or shutdown flow.

## Updates and distribution

[`Resources/Info.plist`](../Resources/Info.plist) defines the app identity, version, build number, Sparkle feed, and public verification key. Published binaries and the signed update feed live in [WakeBee-Releases](https://github.com/jswladitya/WakeBee-Releases).

The local bundle script does not notarize builds. The maintainer's [`release_update.py`](../script/release_update.py) workflow prepares Developer ID-signed, notarized update archives and publishes them separately. [`build_dmg.py`](../script/build_dmg.py) packages the installer. Use each script's `--help` for its arguments.

Forks should configure their own bundle/helper identities, licensing configuration, update feed, and signing keys before distributing a separate product. Do not publish a fork to WakeBee's official update feed. Legacy identity strings in migration code are deliberate: removing them can break upgrades for existing installations.
