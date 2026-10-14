import AppKit
import Observation
import SwiftUI
import WakeBeeCore

/// Owns presentation independently of SwiftUI view updates. MenuBarExtra's
/// automatic dismissal can close its window when controls or sheets take focus.
@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let idleIcon = MenuBarStatusIcon.make(active: false)
    private let activeIcon = MenuBarStatusIcon.make(active: true)
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var deactivateObserver: NSObjectProtocol?
    private var countdownTimer: Timer?
    private var stopped = false

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        // SwiftUI supplies the natural content height. Keep one width and let
        // AppKit position the compact popover against its status-item anchor.
        let content = NSHostingController(rootView: PopoverContent(model: model))
        content.sizingOptions = [.preferredContentSize]
        popover.contentViewController = content
        popover.contentSize = content.view.fittingSize
        popover.animates = false
        // Only our outside-click/Escape handlers dismiss this popover. Becoming
        // key, updating a control, or presenting a child sheet must not close it.
        popover.behavior = .applicationDefined
        popover.delegate = self
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggle)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.title = ""
        statusItem.button?.image = idleIcon
        observeStatus()
    }

    @objc private func toggle() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            if popover.isShown { close() }
            let menu = makeQuickMenu()
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
            return
        }
        if popover.isShown {
            // Keep an in-progress modal draft attached to its parent.
            if popover.contentViewController?.view.window?.attachedSheet == nil { close() }
        } else { show() }
    }

    /// Right-click shortcuts: start a common session or manage the current
    /// one without opening the popover.
    private func makeQuickMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let session = model.session
        if let current = session.session {
            let status: String
            if let remaining = current.remainingSeconds(at: .now) {
                status = "\(MenuBarCountdown.string(seconds: remaining)) left"
            } else if let watched = current.watchedProcess {
                status = "Awake until \(watched.name) exits"
            } else {
                status = "Awake until you stop it"
            }
            menu.addItem(ActionMenuItem(status, enabled: false) {})
            if let end = current.endsAt {
                let canExtend = model.license.isUnlocked
                    && end.timeIntervalSince(current.startedAt) < Double(SessionDuration.maximumMinutes) * 60
                menu.addItem(ActionMenuItem("Add 15 Minutes", enabled: canExtend) { [weak self] in
                    self?.model.extendSession(by: 15)
                })
                menu.addItem(ActionMenuItem("Add 1 Hour", enabled: canExtend) { [weak self] in
                    self?.model.extendSession(by: 60)
                })
            }
            menu.addItem(.separator())
            menu.addItem(ActionMenuItem("End Session") { [weak self] in self?.model.end() })
        } else {
            let canStart = model.license.isUnlocked && model.updates.allowsStartingSession
            let header = ActionMenuItem("Keep Awake", enabled: false) {}
            menu.addItem(header)
            let presets: [(String, SessionDuration)] = [
                ("15 Minutes", .minutes(15)), ("30 Minutes", .minutes(30)), ("1 Hour", .minutes(60)),
                ("2 Hours", .minutes(120)), ("4 Hours", .minutes(240)), ("Until Stopped", .indefinitely),
            ]
            for (title, duration) in presets {
                menu.addItem(ActionMenuItem(title, enabled: canStart) { [weak self] in
                    guard let self, !self.model.startSession(duration) else { return }
                    // Show why the session could not start, such as a missing charger.
                    DispatchQueue.main.async { self.show() }
                })
            }
        }
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Settings…") { [weak self] in
            guard let self else { return }
            self.model.showSettings(.general)
            // Let the menu finish tracking before presenting the popover.
            DispatchQueue.main.async { self.show() }
        })
        menu.addItem(ActionMenuItem("Quit WakeBee", keyEquivalent: "q") { [weak self] in
            self?.model.shutdown()
            NSApp.terminate(nil)
        })
        return menu
    }

    func show() {
        guard !stopped, !popover.isShown, let button = statusItem.button else { return }
        // Let the status-item popover take keyboard focus without activating
        // the app, which also raises its background Settings window.
        model.isPopoverVisible = true
        model.closedLid.refresh()
        if !model.session.isActive { model.refreshWatchCandidates() }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        installEventMonitors()
    }

    private func close() {
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        model.isPopoverVisible = false
        removeEventMonitors()
    }

    func popoverShouldDetach(_ popover: NSPopover) -> Bool { false }

    private func installEventMonitors() {
        removeEventMonitors()
        deactivateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: NSApp, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self,
                      self.popover.contentViewController?.view.window?.attachedSheet == nil else { return }
                self.close()
            }
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self,
                      self.popover.contentViewController?.view.window?.attachedSheet == nil else { return }
                self.close()
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            let handled = MainActor.assumeIsolated {
                guard let self, let root = self.popover.contentViewController?.view.window else { return false }
                // Native sheets and their open panels own Escape and all clicks
                // until they finish. Never tear down the parent underneath them.
                guard root.attachedSheet == nil else { return false }
                if event.type == .keyDown {
                    if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "q" {
                        NSApp.terminate(nil)
                        return true
                    }
                    if event.keyCode == 53, event.window === root {
                        self.close()
                        return true
                    }
                } else if let window = event.window,
                          window !== self.statusItem.button?.window,
                          !Self.belongsToPopover(window, root: root),
                          window.canBecomeMain {
                    // Menus and other transient AppKit panels are not main
                    // windows. Clicking a picker must leave its parent open.
                    self.close()
                }
                return false
            }
            return handled ? nil : event
        }
    }

    private static func belongsToPopover(_ window: NSWindow, root: NSWindow) -> Bool {
        var current: NSWindow? = window
        while let candidate = current {
            if candidate === root { return true }
            current = candidate.sheetParent ?? candidate.parent
        }
        return false
    }

    private func removeEventMonitors() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let deactivateObserver { NotificationCenter.default.removeObserver(deactivateObserver) }
        localMonitor = nil
        globalMonitor = nil
        deactivateObserver = nil
    }

    private func observeStatus() {
        guard !stopped else { return }
        withObservationTracking {
            let active = model.session.isActive
            let button = statusItem.button
            let icon = active ? activeIcon : idleIcon
            if button?.image !== icon { button?.image = icon }
            let showsCountdown = active && model.preferences.showsMenuBarCountdown
                && model.session.session?.endsAt != nil
            updateCountdown(enabled: showsCountdown)
            let unlocked = model.license.isUnlocked
            button?.setAccessibilityLabel(active ? "WakeBee.app, session active" : unlocked ? "WakeBee.app, inactive" : "WakeBee.app, activation required")
            button?.toolTip = active ? "WakeBee.app — keeping your Mac awake" : unlocked ? "WakeBee.app — start a session" : "WakeBee.app — activate your license"
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.observeStatus() }
        }
    }

    /// The countdown changes with the clock rather than observed state, so a
    /// light timer drives it only while it is visible.
    private func updateCountdown(enabled: Bool) {
        if enabled, countdownTimer == nil {
            let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.renderCountdown() }
            }
            timer.tolerance = 1
            countdownTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        } else if !enabled {
            countdownTimer?.invalidate()
            countdownTimer = nil
        }
        renderCountdown()
    }

    private func renderCountdown() {
        guard let button = statusItem.button else { return }
        let remaining = countdownTimer == nil ? nil : model.session.session?.remainingSeconds(at: .now)
        let title = remaining.map { " " + MenuBarCountdown.string(seconds: $0) } ?? ""
        guard button.title != title else { return }
        if title.isEmpty {
            button.title = ""
            button.imagePosition = .imageOnly
        } else {
            button.attributedTitle = NSAttributedString(string: title, attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .medium)
            ])
            button.imagePosition = .imageLeading
        }
    }

    func stop() {
        stopped = true
        countdownTimer?.invalidate()
        countdownTimer = nil
        popover.close()
        removeEventMonitors()
        NSStatusBar.system.removeStatusItem(statusItem)
    }
}

/// Menu items that run a closure. The menu retains each item, and each item
/// is its own target, so no separate selector plumbing is needed.
private final class ActionMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(_ title: String, enabled: Bool = true, keyEquivalent: String = "",
         handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: keyEquivalent)
        target = self
        isEnabled = enabled
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func run() {
        MainActor.assumeIsolated { handler() }
    }
}

private struct PopoverContent: View {
    let model: AppModel
    var body: some View {
        WakeBeeRootView(model: model)
            .frame(width: 340, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)
            .background(.ultraThinMaterial)
    }
}
