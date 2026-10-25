import AppKit

/// Include room for the activity dot only while a session is running.
@MainActor enum MenuBarStatusIcon {
    static func make(active: Bool, style: MenuBarIconStyle = .color) -> NSImage {
        switch style {
        case .color: colorIcon(active: active)
        case .monochrome: monochromeIcon(active: active)
        }
    }

    private static func colorIcon(active: Bool) -> NSImage {
        let bee = NSApplication.shared.applicationIconImage.copy() as! NSImage
        let image = NSImage(size: NSSize(width: active ? 28 : 18, height: 18))
        image.lockFocus()
        bee.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
        if active {
            NSColor.systemGreen.setFill()
            NSBezierPath(ovalIn: NSRect(x: 22, y: 6, width: 6, height: 6)).fill()
        }
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    /// The app icon's bee head as a template glyph, so macOS tints it like
    /// its own menu bar items. A template cannot carry color, so while active it
    /// only leaves room for the green dot that MenuBarController draws over it.
    private static func monochromeIcon(active: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: active ? 28 : 18, height: 18), flipped: true) { _ in
            NSColor.black.set()
            let head = NSBezierPath()
            head.move(to: NSPoint(x: 1.5, y: 16.5))
            head.curve(to: NSPoint(x: 9, y: 6.2), controlPoint1: NSPoint(x: 1.5, y: 10.4),
                       controlPoint2: NSPoint(x: 4.6, y: 6.2))
            head.curve(to: NSPoint(x: 16.5, y: 16.5), controlPoint1: NSPoint(x: 13.4, y: 6.2),
                       controlPoint2: NSPoint(x: 16.5, y: 10.4))
            head.close()

            let antennae = NSBezierPath()
            antennae.move(to: NSPoint(x: 6.9, y: 7.2))
            antennae.curve(to: NSPoint(x: 4.5, y: 3.4), controlPoint1: NSPoint(x: 6.5, y: 5.6),
                           controlPoint2: NSPoint(x: 5.6, y: 4.3))
            antennae.move(to: NSPoint(x: 11.1, y: 7.2))
            antennae.curve(to: NSPoint(x: 13.5, y: 3.4), controlPoint1: NSPoint(x: 11.5, y: 5.6),
                           controlPoint2: NSPoint(x: 12.4, y: 4.3))
            antennae.lineWidth = 1.2
            antennae.lineCapStyle = .round
            antennae.stroke()
            NSBezierPath(ovalIn: NSRect(x: 2.6, y: 1.5, width: 3.2, height: 3.2)).fill()
            NSBezierPath(ovalIn: NSRect(x: 12.2, y: 1.5, width: 3.2, height: 3.2)).fill()
            head.fill()

            // Punch the face out of the filled head.
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSBezierPath(ovalIn: NSRect(x: 4.1, y: 11.0, width: 3, height: 3)).fill()
            NSBezierPath(ovalIn: NSRect(x: 10.9, y: 11.0, width: 3, height: 3)).fill()
            let smile = NSBezierPath()
            smile.move(to: NSPoint(x: 7.9, y: 14.3))
            smile.curve(to: NSPoint(x: 10.1, y: 14.3), controlPoint1: NSPoint(x: 8.4, y: 15.3),
                        controlPoint2: NSPoint(x: 9.6, y: 15.3))
            smile.lineWidth = 0.9
            smile.lineCapStyle = .round
            smile.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Matches the color icon's dot: 6 points, at x 22 of the 28-point image.
    static func activityDotFrame(in button: NSStatusBarButton) -> NSRect {
        let imageRect = button.cell?.imageRect(forBounds: button.bounds)
            ?? NSRect(x: button.bounds.midX - 14, y: button.bounds.midY - 9, width: 28, height: 18)
        return NSRect(x: imageRect.minX + 22, y: imageRect.midY - 3, width: 6, height: 6)
    }
}

/// The monochrome icon's activity dot. Drawn as its own view so it stays green.
final class MenuBarActivityDot: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemGreen.setFill()
        NSBezierPath(ovalIn: bounds).fill()
    }
}
