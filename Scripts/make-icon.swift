#!/usr/bin/env swift
// Renders a simple Mr Clean app icon into an .iconset directory.
// Usage: swift Scripts/make-icon.swift <output.iconset>

import AppKit

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
let outputURL = URL(fileURLWithPath: outputPath)
try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let inset = size * 0.06
    let body = rect.insetBy(dx: inset, dy: inset)
    let corner = size * 0.22

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.29, green: 0.62, blue: 0.98, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.34, blue: 0.82, alpha: 1),
    ])
    let path = NSBezierPath(roundedRect: body, xRadius: corner, yRadius: corner)
    gradient?.draw(in: path, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: size * 0.5, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let tinted = NSImage(size: symbol.size)
        tinted.lockFocus()
        NSColor.white.set()
        NSRect(origin: .zero, size: symbol.size).fill()
        symbol.draw(at: .zero, from: .zero, operation: .destinationIn, fraction: 1)
        tinted.unlockFocus()

        let target = NSRect(
            x: (size - symbol.size.width) / 2,
            y: (size - symbol.size.height) / 2,
            width: symbol.size.width,
            height: symbol.size.height
        )
        tinted.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)
    }

    return image
}

func write(_ image: NSImage, pixels: Int, to url: URL) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return }
    rep.size = NSSize(width: pixels, height: pixels)
    guard let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: url)
}

let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for variant in variants {
    let image = drawIcon(size: CGFloat(variant.pixels))
    write(image, pixels: variant.pixels, to: outputURL.appendingPathComponent("\(variant.name).png"))
}
