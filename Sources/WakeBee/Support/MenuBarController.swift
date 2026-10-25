import AppKit
import Observation
import SwiftUI

/// Owns presentation independently of SwiftUI view updates. MenuBarExtra's
/// automatic dismissal can close its window when controls or sheets take focus.
@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var iconStyle: MenuBarIconStyle
    private var idleIcon: NSImage
    private var activeIcon: NSImage
    private let activityDot = MenuBarActivityDot()
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var deactivateObserver: NSObjectProtocol?
    private var stopped = false

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        iconStyle = model.preferences.menuBarIconStyle
        idleIcon = MenuBarStatusIcon.make(active: false, style: iconStyle)
        activeIcon = MenuBarStatusIcon.make(active: true, style: iconStyle)
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
        activityDot.isHidden = true
        // The image stays centered as the item resizes, so keep the dot's right margin.
        activityDot.autoresizingMask = [.minXMargin, .minYMargin, .maxYMargin]
        statusItem.button?.addSubview(activityDot)
        observeStatus()
    }

    @objc private func toggle() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            let quit = NSMenuItem(title: "Quit WakeBee", action: #selector(quitApp), keyEquivalent: "q")
            quit.target = self
            menu.addItem(quit)
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

    @objc private func quitApp() { NSApp.terminate(nil) }

    func show() {
        guard !stopped, !popover.isShown, let button = statusItem.button else { return }
        // Let the status-item popover take keyboard focus without activating
        // the app, which also raises its background Settings window.
        model.isPopoverVisible = true
        model.closedLid.refresh()
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
            let style = model.preferences.menuBarIconStyle
            if style != iconStyle {
                iconStyle = style
                idleIcon = MenuBarStatusIcon.make(active: false, style: style)
                activeIcon = MenuBarStatusIcon.make(active: true, style: style)
            }
            let button = statusItem.button
            button?.title = ""
            let icon = active ? activeIcon : idleIcon
            if button?.image !== icon { button?.image = icon }
            activityDot.isHidden = !(active && style == .monochrome)
            if !activityDot.isHidden, let button { activityDot.frame = MenuBarStatusIcon.activityDotFrame(in: button) }
            let unlocked = model.license.isUnlocked
            button?.setAccessibilityLabel(active ? "WakeBee.app, session active" : unlocked ? "WakeBee.app, inactive" : "WakeBee.app, activation required")
            button?.toolTip = active ? "WakeBee.app — keeping your Mac awake" : unlocked ? "WakeBee.app — start a session" : "WakeBee.app — activate your license"
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.observeStatus() }
        }
    }

    func stop() {
        stopped = true
        popover.close()
        removeEventMonitors()
        NSStatusBar.system.removeStatusItem(statusItem)
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
