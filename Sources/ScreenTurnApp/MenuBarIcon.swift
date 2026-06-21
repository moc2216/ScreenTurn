import AppKit

enum MenuBarIcon {
    static func makeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        let strokeWidth: CGFloat = 1.45
        NSColor.black.setStroke()

        let landscape = NSBezierPath(
            roundedRect: NSRect(x: 1.1, y: 5.4, width: 10.2, height: 6.5),
            xRadius: 1,
            yRadius: 1
        )
        landscape.lineWidth = strokeWidth
        landscape.stroke()

        let landscapeStand = NSBezierPath()
        landscapeStand.lineCapStyle = .round
        landscapeStand.lineWidth = strokeWidth
        landscapeStand.move(to: NSPoint(x: 6.2, y: 5.3))
        landscapeStand.line(to: NSPoint(x: 6.2, y: 3.2))
        landscapeStand.move(to: NSPoint(x: 4.6, y: 3.2))
        landscapeStand.line(to: NSPoint(x: 7.8, y: 3.2))
        landscapeStand.stroke()

        let portrait = NSBezierPath(
            roundedRect: NSRect(x: 10.4, y: 5.4, width: 5.5, height: 10.3),
            xRadius: 1,
            yRadius: 1
        )
        portrait.lineWidth = strokeWidth
        portrait.stroke()

        let portraitStand = NSBezierPath()
        portraitStand.lineCapStyle = .round
        portraitStand.lineWidth = strokeWidth
        portraitStand.move(to: NSPoint(x: 13.15, y: 5.3))
        portraitStand.line(to: NSPoint(x: 13.15, y: 3.2))
        portraitStand.move(to: NSPoint(x: 11.75, y: 3.2))
        portraitStand.line(to: NSPoint(x: 14.55, y: 3.2))
        portraitStand.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
