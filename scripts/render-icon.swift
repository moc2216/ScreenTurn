import AppKit
import Foundation

let arguments = CommandLine.arguments

guard arguments.count == 3 else {
    fputs("Usage: render-icon.swift <source-art.png> <output.png>\n", stderr)
    exit(1)
}

let sourceURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fputs("Unable to read source art: \(sourceURL.path)\n", stderr)
    exit(1)
}

let canvasSize = NSSize(width: 1024, height: 1024)
let canvas = NSImage(size: canvasSize)
canvas.lockFocus()

let tile = NSRect(x: 64, y: 64, width: 896, height: 896)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 204, yRadius: 204)
NSColor.white.setFill()
tilePath.fill()

NSColor(calibratedRed: 0.906, green: 0.922, blue: 0.949, alpha: 1).setStroke()
tilePath.lineWidth = 8
tilePath.stroke()

NSGraphicsContext.current?.imageInterpolation = .high
sourceImage.draw(
    in: tile,
    from: NSRect(origin: .zero, size: sourceImage.size),
    operation: .sourceOver,
    fraction: 1,
    respectFlipped: true,
    hints: [.interpolation: NSImageInterpolation.high]
)

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode output PNG.\n", stderr)
    exit(1)
}

try png.write(to: outputURL)
