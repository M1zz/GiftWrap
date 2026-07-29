#!/usr/bin/env swift
//
// Draws the GiftWrap app icon — a wrapped present: ribbon bands crossing a
// gradient tile, with a bow where they meet.
//
// The palette is GiftTheme.sunrise, so the icon and the cards it makes are
// visibly the same product.
//
//   swift tools/appicon.swift [output-directory]
//
// Writes icon_16 … icon_1024.png. With no argument it fills the asset catalog
// slot the app already declares.
//

import AppKit
import CoreGraphics
import Foundation

// MARK: - Geometry, in a 1024 design space

/// macOS icons don't fill their canvas — the artwork sits on an 824pt tile with
/// the rest left to the shadow. Matching that keeps GiftWrap the same visual
/// weight as its neighbours in the Dock.
let canvas: CGFloat = 1024
let tileInset: CGFloat = 100
let tileSide: CGFloat = canvas - tileInset * 2
let tileRadius: CGFloat = 185

/// Ribbon bands, in tile coordinates.
let bandWidth: CGFloat = 132
/// The bands cross above the middle: dead centre reads as low once the bow sits on top.
let crossY: CGFloat = tileSide * 0.455

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

// GiftTheme.sunrise
let stops = [rgb(0xFF3D77), rgb(0xFF7A59), rgb(0xFFC15E)]
let bloomWarm = rgb(0xFFD98A)
let bloomPink = rgb(0xFF4FA3)

let space = CGColorSpaceCreateDeviceRGB()

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}

// MARK: - Ribbon shapes

/// One loop of the bow, mirrored by `side` (-1 left, +1 right). Drawn in tile
/// coordinates with y running downward.
func bowLoop(cx: CGFloat, cy: CGFloat, side: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let w: CGFloat = 208   // how far the loop reaches out
    let h: CGFloat = 196   // and up — a flat loop reads as a moustache, not a bow
    p.move(to: CGPoint(x: cx, y: cy))
    // up and over the top of the loop
    p.addCurve(
        to: CGPoint(x: cx + side * w, y: cy - h * 0.52),
        control1: CGPoint(x: cx + side * 22, y: cy - h * 0.92),
        control2: CGPoint(x: cx + side * w * 0.72, y: cy - h)
    )
    // and back under to the knot
    p.addCurve(
        to: CGPoint(x: cx, y: cy),
        control1: CGPoint(x: cx + side * w * 1.02, y: cy - h * 0.12),
        control2: CGPoint(x: cx + side * w * 0.40, y: cy + h * 0.06)
    )
    p.closeSubpath()
    return p
}

/// A ribbon tail falling from the knot.
func bowTail(cx: CGFloat, cy: CGFloat, side: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let len: CGFloat = 168
    p.move(to: CGPoint(x: cx, y: cy))
    p.addCurve(
        to: CGPoint(x: cx + side * 118, y: cy + len),
        control1: CGPoint(x: cx + side * 30, y: cy + len * 0.42),
        control2: CGPoint(x: cx + side * 78, y: cy + len * 0.66)
    )
    // the notched end a cut ribbon has
    p.addLine(to: CGPoint(x: cx + side * 78, y: cy + len * 0.90))
    p.addLine(to: CGPoint(x: cx + side * 44, y: cy + len))
    p.addCurve(
        to: CGPoint(x: cx, y: cy),
        control1: CGPoint(x: cx + side * 26, y: cy + len * 0.62),
        control2: CGPoint(x: cx + side * 6, y: cy + len * 0.34)
    )
    p.closeSubpath()
    return p
}

// MARK: - Drawing

func drawIcon(into ctx: CGContext, pixels: CGFloat) {
    let k = pixels / canvas
    ctx.saveGState()
    ctx.scaleBy(x: k, y: k)
    // Work with y running downward, the way the shapes above are written.
    ctx.translateBy(x: 0, y: canvas)
    ctx.scaleBy(x: 1, y: -1)

    let tile = CGRect(x: tileInset, y: tileInset, width: tileSide, height: tileSide)
    let tilePath = CGPath(
        roundedRect: tile, cornerWidth: tileRadius, cornerHeight: tileRadius, transform: nil
    )

    // Shadow, so the tile sits on the desktop rather than floating flat.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 18), blur: 44, color: rgb(0x2A0E1C, 0.34))
    ctx.setFillColor(rgb(0xFF3D77))
    ctx.addPath(tilePath)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()

    // Base wash — bottom-left to top-right, the same diagonal the cards use.
    ctx.drawLinearGradient(
        gradient(stops, [0, 0.52, 1]),
        start: CGPoint(x: tile.minX, y: tile.maxY),
        end: CGPoint(x: tile.maxX, y: tile.minY),
        options: []
    )

    // Two soft blooms, matching GiftTheme.sunrise.
    ctx.drawRadialGradient(
        gradient([bloomWarm.copy(alpha: 0.55)!, bloomWarm.copy(alpha: 0)!], [0, 1]),
        startCenter: CGPoint(x: tile.minX + tileSide * 0.16, y: tile.minY + tileSide * 0.12),
        startRadius: 0,
        endCenter: CGPoint(x: tile.minX + tileSide * 0.16, y: tile.minY + tileSide * 0.12),
        endRadius: tileSide * 0.72,
        options: []
    )
    ctx.drawRadialGradient(
        gradient([bloomPink.copy(alpha: 0.5)!, bloomPink.copy(alpha: 0)!], [0, 1]),
        startCenter: CGPoint(x: tile.maxX - tileSide * 0.06, y: tile.maxY - tileSide * 0.04),
        startRadius: 0,
        endCenter: CGPoint(x: tile.maxX - tileSide * 0.06, y: tile.maxY - tileSide * 0.04),
        endRadius: tileSide * 0.78,
        options: []
    )

    // Everything below is in tile coordinates.
    ctx.translateBy(x: tile.minX, y: tile.minY)

    let cx = tileSide / 2
    let bandX = cx - bandWidth / 2

    // Ribbon bands. A hair off-white so they read as ribbon, not as a hole.
    let ribbon = rgb(0xFFFFFF, 0.95)
    ctx.setFillColor(ribbon)
    ctx.fill(CGRect(x: bandX, y: 0, width: bandWidth, height: tileSide))
    ctx.fill(CGRect(x: 0, y: crossY - bandWidth / 2, width: tileSide, height: bandWidth))

    // A shadow line down each band edge gives the paper some thickness.
    ctx.setFillColor(rgb(0xD8365F, 0.18))
    ctx.fill(CGRect(x: bandX, y: 0, width: 9, height: tileSide))
    ctx.fill(CGRect(x: bandX + bandWidth - 9, y: 0, width: 9, height: tileSide))
    ctx.fill(CGRect(x: 0, y: crossY - bandWidth / 2, width: tileSide, height: 9))
    ctx.fill(CGRect(x: 0, y: crossY + bandWidth / 2 - 9, width: tileSide, height: 9))

    // The bow, sitting where the bands meet.
    let knot = CGPoint(x: cx, y: crossY)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 10), blur: 26, color: rgb(0x8E1B3C, 0.30))
    ctx.setFillColor(ribbon)
    for side in [CGFloat(-1), 1] {
        ctx.addPath(bowTail(cx: knot.x, cy: knot.y, side: side))
        ctx.fillPath()
    }
    for side in [CGFloat(-1), 1] {
        ctx.addPath(bowLoop(cx: knot.x, cy: knot.y, side: side))
        ctx.fillPath()
    }
    ctx.restoreGState()

    // Loop interiors, so the two loops don't merge into one white blob.
    ctx.setFillColor(rgb(0xE24A72, 0.28))
    for side in [CGFloat(-1), 1] {
        ctx.saveGState()
        ctx.addPath(bowLoop(cx: knot.x, cy: knot.y, side: side))
        ctx.clip()
        // The opening you see through: centred in the loop and tilted along the
        // sweep out to the tip. Left upright it reads as a pair of spectacles.
        var tilt = CGAffineTransform(translationX: knot.x + side * 112, y: knot.y - 86)
            .rotated(by: side * -0.42)
        ctx.addPath(CGPath(
            ellipseIn: CGRect(x: -56, y: -34, width: 112, height: 68), transform: &tilt
        ))
        ctx.fillPath()
        ctx.restoreGState()
    }

    // Knot last, covering where the loops and tails meet.
    ctx.setFillColor(ribbon)
    ctx.addPath(CGPath(
        roundedRect: CGRect(x: knot.x - 46, y: knot.y - 34, width: 92, height: 68),
        cornerWidth: 30, cornerHeight: 30, transform: nil
    ))
    ctx.fillPath()
    ctx.setFillColor(rgb(0xD8365F, 0.16))
    ctx.addPath(CGPath(
        roundedRect: CGRect(x: knot.x - 46, y: knot.y + 12, width: 92, height: 22),
        cornerWidth: 11, cornerHeight: 11, transform: nil
    ))
    ctx.fillPath()

    ctx.restoreGState()   // tile clip

    // Top gloss, laid over everything the way a laminated card catches light.
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([rgb(0xFFFFFF, 0.26), rgb(0xFFFFFF, 0)], [0, 1]),
        start: CGPoint(x: tile.midX, y: tile.minY),
        end: CGPoint(x: tile.midX, y: tile.minY + tileSide * 0.5),
        options: []
    )
    ctx.restoreGState()

    ctx.restoreGState()
}

// MARK: - Output

func png(at pixels: Int) -> Data {
    let side = CGFloat(pixels)
    guard let ctx = CGContext(
        data: nil, width: pixels, height: pixels,
        bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("컨텍스트를 만들지 못했습니다 (\(pixels)px)") }

    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high
    drawIcon(into: ctx, pixels: side)

    guard let image = ctx.makeImage() else { fatalError("이미지를 만들지 못했습니다") }
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: side, height: side)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG 인코딩에 실패했습니다")
    }
    return data
}

let defaultOut = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("GiftWrap/Assets.xcassets/AppIcon.appiconset")

let outDir = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : defaultOut

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// The catalog asks for these ten slots across seven distinct pixel sizes.
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let url = outDir.appendingPathComponent("icon_\(size).png")
    try png(at: size).write(to: url, options: .atomic)
    print("icon_\(size).png")
}
print("→ \(outDir.path)")
