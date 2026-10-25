<p align="center">
  <img src="Resources/WakeBee.png" width="96" alt="WakeBee bee icon">
</p>

<h1 align="center">WakeBee</h1>

<p align="center">
  <strong>Your agents, always on.</strong><br>
  Keep your Mac awake while your agents work—even with the lid closed.
</p>

<p align="center">
  Native macOS app · Swift &amp; SwiftUI · macOS 14+ · AGPL-3.0 licensed
</p>

<p align="center">
  <a href="https://www.wakebee.app">Website</a> ·
  <a href="https://github.com/jswladitya/WakeBee-Releases/releases/latest">Download for Mac</a> ·
  <a href="#build-from-source">Build from source</a> ·
  <a href="CONTRIBUTING.md">Contribute</a>
</p>

## See it in action

https://github.com/user-attachments/assets/a13aca2a-a054-4f82-886e-1181d099f33e

A 19-second look at WakeBee. Closed-lid mode requires setup and a confirmed active session.

## What it does

WakeBee lives in your menu bar and keeps your Mac awake for the work you choose: coding agents, downloads, builds, renders, or a long-running script. Start a session, set your limits, and get back to your work.

- **Three ways to stay awake.** Set a timer, pick an end time, or run until you stop.
- **Optional closed-lid mode.** Continue a session with your MacBook closed after a one-time helper setup.
- **Battery controls.** Require a charger, choose a battery cutoff, and set a limit for closed-lid use on battery.
- **A quiet menu bar.** Just the bee when idle, with a green dot while a session is running. Choose the color bee or a monochrome one that matches the system icons.
- **Display control.** Let the display sleep or keep it awake with your session.
- **Native Mac experience.** SwiftUI and AppKit, Liquid Glass on supported systems, launch at login, and Sparkle updates.

Sessions are started manually. WakeBee prevents sleep; it does not monitor your agents or restart their work.

## Get started

**Requires macOS 14 or later. Official downloads include Apple silicon and Intel support.**

1. Download the DMG from [the latest release](https://github.com/jswladitya/WakeBee-Releases/releases/latest).
2. Move **WakeBee.app** to **Applications** and open it.
3. Activate your license, then click the bee in your menu bar.
4. Choose **Timer**, **Until**, or **Unlimited**, and select **Start session**.

New installations require a charger by default. To run on battery, review **Settings → General → Battery & Power**. Ending a session or quitting releases normal sleep prevention; sessions do not resume automatically after relaunch or system sleep.

**Source license and app activation:** this repository uses the [GNU Affero General Public License v3.0](LICENSE) (`AGPL-3.0-only`). The current app uses Polar license activation, including unmodified builds from source. You can get an app license at [wakebee.app](https://www.wakebee.app). Automated tests use test doubles and do not require a purchased key. Purchasing an activation key supports the official app; it is not an additional condition on the rights granted by the source license.

Upgrading from version 0.14 or earlier? Follow the [one-time migration instructions](Updates/RELEASE.md#one-time-upgrade-from-014-or-earlier).

## Keep working with the lid closed

1. Keep the lid open and connect your charger.
2. Click **Set up…** beside **Closed-lid mode**. Follow the macOS approval prompt if it appears.
3. Start a session and wait for **Ready to close the lid** before closing your MacBook.

After setup, use the closed-lid switch for future sessions. Battery use is optional and configured in **Settings → Closed Lid**.

On a charger, closed-lid mode lasts as long as your session. On battery it stops at your battery cutoff or after the time you choose, 4 hours at most. It also stops if your Mac gets too warm, and a watchdog restores the previous sleep setting if contact with the app is lost. When it stops with the lid closed, your Mac goes to sleep. Use a ventilated surface, never a bag or sleeve. Behavior can vary by Mac and macOS version, so test a short session on your own hardware before relying on unattended work. The green menu-bar dot means a session is running; the closed-lid card confirms whether it is ready to close.

## Build from source

You'll need **Xcode with the macOS 26.1 SDK or newer**, the Swift 6 toolchain, and **Python 3**. The newer SDK is needed to compile the Liquid Glass controls; the app still runs on macOS 14 and later with fallback controls.

```sh
git clone https://github.com/jswladitya/WakeBee.git
cd WakeBee
./script/build_and_run.sh --build-only
open dist/WakeBee.app
```

Swift Package Manager resolves the pinned Sparkle dependency. The script bundles the app, helper, icons, and updater, then signs and verifies the result. Without a configured signing identity, it uses an ad-hoc signature.

**Closed-lid mode needs a real Apple signing identity** shared by the app and helper, plus macOS background-item approval. It is unavailable in ad-hoc builds. See the [development guide](docs/DEVELOPMENT.md) for signing options, testing, and packaging.

## How it's built

| Module | Responsibility |
| --- | --- |
| [`WakeBee`](Sources/WakeBee) | SwiftUI views, AppKit menu-bar popover, preferences, Keychain storage, and macOS services. |
| [`WakeBeeCore`](Sources/WakeBeeCore) | Session timing, power rules, license validation, and closed-lid lease and recovery logic. |
| [`WakeBeeHelper`](Sources/WakeBeeHelper) | Privileged helper that applies and restores the system sleep setting. |
| [`WakeBeeHelperProtocol`](Sources/WakeBeeHelperProtocol) | Shared XPC interface and signing requirements between the app and helper. |

Normal sessions use IOKit power assertions to prevent idle sleep. Closed-lid sessions use an approved `SMAppService` helper over authenticated XPC. That helper temporarily changes the system-wide sleep setting, records its previous value, and restores it when the session ends or a limit is reached.

Preferences stay in UserDefaults; app-license data stays in macOS Keychain. Polar handles license verification, and Sparkle checks for signed updates. See [the source](Sources) and [development guide](docs/DEVELOPMENT.md) for the implementation.

## A note from the maker

Hi, I'm Aditya. I'm new to open source and learning as I go. If you spot something I could improve in the code, documentation, or how I maintain this project, I'd love your feedback. Suggestions and contributions are welcome, whether you're experienced or just getting started too. Thanks for helping me make WakeBee better.

If you love WakeBee, consider [contributing to the project](CONTRIBUTING.md). If you can't contribute right now, you can support its development by [purchasing a license key](https://buy.polar.sh/polar_cl_HMkc1qGmstC5HhR91Tz3XMqlAbV2MLKp1JvyS2xPMrC). Starring the repo or sharing it with someone who might find it useful helps too. Thank you for your support!

## Contributing

Bug reports, documentation improvements, and pull requests are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow and what to include in a report.

For bugs, include your Mac model, macOS version, WakeBee version, and steps to reproduce. For closed-lid issues, also include the charger state and the message under **Setup details**. Leave license keys and personal information out of reports.

## License & acknowledgments

Copyright © 2026 Aditya Jaiswal.

WakeBee is licensed under the [GNU Affero General Public License, version 3 only](LICENSE) (`AGPL-3.0-only`). Third-party components retain their own licenses and notices.

Built with Apple's Swift, SwiftUI, AppKit, IOKit, and ServiceManagement frameworks. Automatic updates use [Sparkle](https://github.com/sparkle-project/Sparkle), whose license is included in packaged builds. App-license activation uses [Polar](https://polar.sh).
