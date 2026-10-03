import AppKit

let output = CommandLine.arguments[1]
let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let canvas = NSRect(x: 0, y: 0, width: size, height: size)
NSColor.clear.setFill()
canvas.fill()
let base = canvas.insetBy(dx: 72, dy: 72)
let shape = NSBezierPath(roundedRect: base, xRadius: 205, yRadius: 205)
let gradient = NSGradient(starting: NSColor(calibratedRed: 0.11, green: 0.56, blue: 1, alpha: 1), ending: NSColor(calibratedRed: 0.07, green: 0.25, blue: 0.79, alpha: 1))!
gradient.draw(in: shape, angle: -55)
let shine = NSBezierPath(roundedRect: base.insetBy(dx: 4, dy: 4), xRadius: 201, yRadius: 201)
NSColor.white.withAlphaComponent(0.22).setStroke()
shine.lineWidth = 8
shine.stroke()
if let pin = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "PinTop")?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 510, weight: .semibold).applying(NSImage.SymbolConfiguration(paletteColors: [.white]))) {
    let rect = NSRect(x: 282, y: 252, width: 460, height: 520)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.shadowBlurRadius = 26
    shadow.set()
    pin.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
