import AppKit

enum LaunchPresentation {
    static func shouldShowPopover(for event: NSAppleEventDescriptor?) -> Bool {
        // A wakebee:// link runs its command quietly; failures open the popover separately.
        if event?.eventClass == AEEventClass(kInternetEventClass), event?.eventID == AEEventID(kAEGetURL) {
            return false
        }
        guard event?.eventID == kAEOpenApplication else { return true }
        // macOS describes login/service launches in the open-application event.
        let launchReason = event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue
        return launchReason != keyAELaunchedAsLogInItem && launchReason != keyAELaunchedAsServiceItem
    }
}
