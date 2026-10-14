import AppKit
import Testing
@testable import WakeBee

@Suite struct LaunchPresentationTests {
    @Test func manualLaunchShowsPopover() {
        #expect(LaunchPresentation.shouldShowPopover(for: openEvent()))
        #expect(LaunchPresentation.shouldShowPopover(for: nil))
    }

    @Test(arguments: [keyAELaunchedAsLogInItem, keyAELaunchedAsServiceItem])
    func backgroundLaunchStaysQuiet(reason: AEKeyword) {
        let event = openEvent()
        event.setParam(NSAppleEventDescriptor(enumCode: reason), forKeyword: keyAEPropData)
        #expect(!LaunchPresentation.shouldShowPopover(for: event))
    }

    @Test func automationLinkLaunchStaysQuiet() {
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kInternetEventClass), eventID: AEEventID(kAEGetURL),
            targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        #expect(!LaunchPresentation.shouldShowPopover(for: event))
    }

    private func openEvent() -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(
            eventClass: kCoreEventClass, eventID: kAEOpenApplication,
            targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
    }
}
