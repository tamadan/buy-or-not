#!/usr/bin/env swift
/// アプリアイコン生成スクリプト
/// 実行: swift scripts/generate_app_icon.swift
/// 出力: BuyOrNot/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png

import Foundation
import AppKit
import CoreGraphics

// MARK: - Helpers

func hex(_ h: String) -> NSColor {
    let s = h.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var v: UInt64 = 0
    Scanner(string: s).scanHexInt64(&v)
    return NSColor(
        red:   CGFloat((v >> 16) & 0xFF) / 255,
        green: CGFloat((v >>  8) & 0xFF) / 255,
        blue:  CGFloat( v        & 0xFF) / 255,
        alpha: 1
    )
}

func drawGradient(in ctx: CGContext, rect: CGRect,
                  top: NSColor, bottom: NSColor) {
    let colors = [top.cgColor, bottom.cgColor] as CFArray
    let locs: [CGFloat] = [0, 1]
    let space = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: space, colors: colors, locations: locs)!
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: rect.midX, y: rect.maxY),
                           end:   CGPoint(x: rect.midX, y: rect.minY),
                           options: [])
}

// MARK: - Drawing

let S: CGFloat = 1024   // canvas size
let cx = S / 2          // center x
let cy = S / 2          // center y

// dolphin scale factor (relative to canvas)
let ds: CGFloat = 0.72  // dolphin fits in ~72% of canvas height

let bw = S * ds * 0.88  // body width
let bh = S * ds * 0.76  // body height
let bx = cx             // body center x
let by = cy + S * 0.04  // body center y (slightly below canvas center)

let image = NSImage(size: CGSize(width: S, height: S), flipped: false) { _ in

    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

    // ── Background ────────────────────────────────────────────────
    drawGradient(in: ctx, rect: CGRect(x: 0, y: 0, width: S, height: S),
                 top: hex("2A6FAD"), bottom: hex("163D6A"))

    // subtle radial glow at center
    let glowColors = [
        hex("4A90D9").withAlphaComponent(0.35).cgColor,
        hex("1A4A8A").withAlphaComponent(0.0).cgColor
    ] as CFArray
    let glowLocs: [CGFloat] = [0, 1]
    let space = CGColorSpaceCreateDeviceRGB()
    let glow = CGGradient(colorsSpace: space, colors: glowColors, locations: glowLocs)!
    ctx.drawRadialGradient(glow,
                           startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                           endCenter:   CGPoint(x: cx, y: cy), endRadius: S * 0.55,
                           options: [])

    // ── Dorsal Fin ────────────────────────────────────────────────
    let finW = bw * 0.30
    let finH = S * ds * 0.22
    let finOriginX = bx - finW * 0.5
    let finOriginY = by + bh * 0.5 + finH * 0.02   // just above body top

    ctx.saveGState()
    let finPath = CGMutablePath()
    finPath.move(to: CGPoint(x: finOriginX + finW * 0.12, y: finOriginY))
    finPath.addQuadCurve(
        to:      CGPoint(x: finOriginX + finW * 0.52, y: finOriginY + finH),
        control: CGPoint(x: finOriginX + finW * 0.08, y: finOriginY + finH * 0.8)
    )
    finPath.addQuadCurve(
        to:      CGPoint(x: finOriginX + finW * 0.88, y: finOriginY + finH * 0.1),
        control: CGPoint(x: finOriginX + finW * 0.82, y: finOriginY + finH * 0.88)
    )
    finPath.closeSubpath()

    let finColors = [hex("5BA3DC").cgColor, hex("3578B5").cgColor] as CFArray
    let finLocs: [CGFloat] = [0, 1]
    let finGrad = CGGradient(colorsSpace: space, colors: finColors, locations: finLocs)!

    ctx.addPath(finPath)
    ctx.clip()
    ctx.drawLinearGradient(finGrad,
                           start: CGPoint(x: finOriginX, y: finOriginY),
                           end:   CGPoint(x: finOriginX, y: finOriginY + finH),
                           options: [])
    ctx.restoreGState()

    // ── Main Body ────────────────────────────────────────────────
    ctx.saveGState()
    let bodyRect = CGRect(x: bx - bw/2, y: by - bh/2, width: bw, height: bh)
    let bodyPath = CGPath(ellipseIn: bodyRect, transform: nil)

    // shadow
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 24,
                  color: hex("1A3A6A").withAlphaComponent(0.55).cgColor)
    ctx.addPath(bodyPath)
    ctx.clip()
    ctx.setShadow(offset: .zero, blur: 0)

    let bodyColors = [hex("6DB8EC").cgColor, hex("3A7BBF").cgColor] as CFArray
    let bodyLocs: [CGFloat] = [0, 1]
    let bodyGrad = CGGradient(colorsSpace: space, colors: bodyColors, locations: bodyLocs)!
    ctx.drawLinearGradient(bodyGrad,
                           start: CGPoint(x: bx - bw * 0.4, y: by + bh * 0.5),
                           end:   CGPoint(x: bx + bw * 0.4, y: by - bh * 0.5),
                           options: [])
    ctx.restoreGState()

    // ── Belly ─────────────────────────────────────────────────────
    let bellyW = bw * 0.50
    let bellyH = bh * 0.52
    let bellyRect = CGRect(x: bx - bellyW/2,
                           y: by - bellyH/2 - bh * 0.06,
                           width: bellyW, height: bellyH)
    ctx.saveGState()
    ctx.addPath(CGPath(ellipseIn: bellyRect, transform: nil))
    ctx.clip()
    let bellyColors = [hex("D8EEFA").cgColor, hex("A8D5F0").cgColor] as CFArray
    let bellyLocs: [CGFloat] = [0, 1]
    let bellyGrad = CGGradient(colorsSpace: space, colors: bellyColors, locations: bellyLocs)!
    ctx.drawLinearGradient(bellyGrad,
                           start: CGPoint(x: bx, y: bellyRect.maxY),
                           end:   CGPoint(x: bx, y: bellyRect.minY),
                           options: [])
    ctx.restoreGState()

    // ── Pectoral Fins ─────────────────────────────────────────────
    // macOS coords: Y↑（高いY＝画面上方）
    // ボディ下寄りの側面から斜め下45度に張り出すパドル型
    let pFinAttachY  = by - bh * 0.12   // 付け根中心（ボディ下寄り）
    let pFinTopY     = pFinAttachY + bh * 0.08  // 付け根の上縁
    let pFinBotY     = pFinAttachY - bh * 0.09  // 付け根の下縁
    let pFinExtendX  = bw * 0.24        // 横方向の張り出し幅

    for sign: CGFloat in [-1, 1] {
        let attachX = bx + sign * bw * 0.42
        let tipX    = attachX + sign * pFinExtendX
        let tipMidY = pFinAttachY - bh * 0.20   // 45度斜め下（Y↑なので小さい値=画面下）

        let finPath = CGMutablePath()
        finPath.move(to: CGPoint(x: attachX, y: pFinTopY))
        // 外縁カーブ → 先端
        finPath.addQuadCurve(
            to:      CGPoint(x: tipX, y: tipMidY + bh * 0.04),
            control: CGPoint(x: attachX + sign * pFinExtendX * 0.42, y: pFinTopY - bh * 0.02)
        )
        // 先端の丸み
        finPath.addQuadCurve(
            to:      CGPoint(x: tipX, y: tipMidY - bh * 0.04),
            control: CGPoint(x: tipX + sign * bw * 0.04, y: tipMidY)
        )
        // 内縁カーブ → 付け根下縁
        finPath.addQuadCurve(
            to:      CGPoint(x: attachX, y: pFinBotY),
            control: CGPoint(x: attachX + sign * pFinExtendX * 0.42, y: tipMidY - bh * 0.06)
        )
        finPath.closeSubpath()

        ctx.saveGState()
        ctx.addPath(finPath)
        ctx.clip()
        let pFinColors = [hex("5BA3DC").cgColor, hex("3578B5").cgColor] as CFArray
        let pFinLocs: [CGFloat] = [0, 1]
        let pFinGrad = CGGradient(colorsSpace: space, colors: pFinColors, locations: pFinLocs)!
        ctx.drawLinearGradient(pFinGrad,
                               start: CGPoint(x: attachX, y: pFinTopY),
                               end:   CGPoint(x: tipX,    y: tipMidY),
                               options: [])
        ctx.restoreGState()
    }

    // ── Cheeks ────────────────────────────────────────────────────
    let cheekW = bw * 0.12
    let cheekH = bh * 0.08
    let cheekY = by - bh * 0.04
    let cheekOffset = bw * 0.22

    for sign: CGFloat in [-1, 1] {
        let cheekRect = CGRect(x: bx + sign * cheekOffset - cheekW/2,
                               y: cheekY - cheekH/2,
                               width: cheekW, height: cheekH)
        ctx.saveGState()
        ctx.addPath(CGPath(ellipseIn: cheekRect, transform: nil))
        ctx.clip()
        NSColor.systemPink.withAlphaComponent(0.40).setFill()
        ctx.fill(cheekRect)
        ctx.restoreGState()
    }

    // ── Eyes ──────────────────────────────────────────────────────
    let eyeSize: CGFloat = bw * 0.13
    let eyeY = by + bh * 0.10
    let eyeOffset = bw * 0.18

    for sign: CGFloat in [-1, 1] {
        let ex = bx + sign * eyeOffset
        let ey = eyeY

        // white sclera
        let scleraR = eyeSize * 0.6
        ctx.saveGState()
        ctx.addPath(CGPath(ellipseIn: CGRect(x: ex - scleraR, y: ey - scleraR,
                                              width: scleraR*2, height: scleraR*2), transform: nil))
        ctx.clip()
        NSColor.white.setFill()
        ctx.fill(CGRect(x: ex - scleraR, y: ey - scleraR, width: scleraR*2, height: scleraR*2))
        ctx.restoreGState()

        // pupil
        let pupilR = eyeSize * 0.40
        ctx.saveGState()
        ctx.addPath(CGPath(ellipseIn: CGRect(x: ex - pupilR, y: ey - pupilR,
                                              width: pupilR*2, height: pupilR*2), transform: nil))
        ctx.clip()
        hex("2C3E50").setFill()
        ctx.fill(CGRect(x: ex - pupilR, y: ey - pupilR, width: pupilR*2, height: pupilR*2))
        ctx.restoreGState()

        // highlight
        let hlR = eyeSize * 0.13
        ctx.saveGState()
        ctx.addPath(CGPath(ellipseIn: CGRect(x: ex - pupilR * 0.5 - hlR,
                                              y: ey + pupilR * 0.4 - hlR,
                                              width: hlR*2, height: hlR*2), transform: nil))
        ctx.clip()
        NSColor.white.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))
        ctx.restoreGState()
    }

    // ── Eyebrows ─────────────────────────────────────────────────
    // greeting mood: 眉が少し上がって嬉しそう (-8 / +8 deg)
    let browW = eyeSize * 1.1
    let browH = eyeSize * 0.22
    let browY = eyeY + eyeSize * 0.68

    for sign: CGFloat in [-1, 1] {
        let angle = sign * (-8.0) * .pi / 180   // greeting brow angle
        let ex = bx + sign * eyeOffset
        ctx.saveGState()
        ctx.translateBy(x: ex, y: browY)
        ctx.rotate(by: angle)
        let browRect = CGRect(x: -browW/2, y: -browH/2, width: browW, height: browH)
        let browPath = CGPath(roundedRect: browRect, cornerWidth: browH/2, cornerHeight: browH/2, transform: nil)
        ctx.addPath(browPath)
        ctx.clip()
        hex("2C3E50").setFill()
        ctx.fill(CGRect(x: -browW, y: -browH, width: browW*2, height: browH*2))
        ctx.restoreGState()
    }

    // ── Mouth (greeting smile) ────────────────────────────────────
    let mouthW = bw * 0.30
    let mouthY = by - bh * 0.13
    let mouthPath = CGMutablePath()
    mouthPath.move(to: CGPoint(x: bx - mouthW/2, y: mouthY))
    mouthPath.addQuadCurve(
        to:      CGPoint(x: bx + mouthW/2, y: mouthY),
        control: CGPoint(x: bx, y: mouthY - mouthW * 0.38)
    )
    ctx.saveGState()
    ctx.addPath(mouthPath)
    ctx.setStrokeColor(hex("2C3E50").cgColor)
    ctx.setLineWidth(S * 0.012)
    ctx.setLineCap(.round)
    ctx.strokePath()
    ctx.restoreGState()



    // ── Speech bubble with "?" ────────────────────────────────────
    let bubbleR: CGFloat = S * 0.115
    let bubbleX = bx + bw * 0.46
    let bubbleY = by + bh * 0.44

    ctx.saveGState()
    // circle background
    let bubbleRect = CGRect(x: bubbleX - bubbleR, y: bubbleY - bubbleR,
                             width: bubbleR*2, height: bubbleR*2)
    ctx.setShadow(offset: CGSize(width: 0, height: 3), blur: 10,
                  color: NSColor.black.withAlphaComponent(0.25).cgColor)
    ctx.addPath(CGPath(ellipseIn: bubbleRect, transform: nil))
    NSColor.white.withAlphaComponent(0.95).setFill()
    ctx.fillPath()
    ctx.restoreGState()

    // "?" text
    let paraStyle = NSMutableParagraphStyle()
    paraStyle.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: bubbleR * 1.05, weight: .heavy),
        .foregroundColor: hex("3A7BBF"),
        .paragraphStyle: paraStyle
    ]
    let qStr = NSAttributedString(string: "?", attributes: attrs)
    let qSize = qStr.size()
    qStr.draw(in: CGRect(x: bubbleX - qSize.width/2,
                          y: bubbleY - qSize.height/2 + 2,
                          width: qSize.width, height: qSize.height))

    return true
}

// MARK: - Save PNG

// #file でスクリプト自身のパスを取得し、実行ディレクトリに依存しないようにする
let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
let outputDir = scriptDir
    .deletingLastPathComponent()  // scripts/ の親 = プロジェクトルート
    .appendingPathComponent("BuyOrNot/Resources/Assets.xcassets/AppIcon.appiconset")
let outputURL = outputDir.appendingPathComponent("AppIcon.png")

// 出力ディレクトリが存在しない場合は作成（または明確なエラーで終了）
do {
    try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
} catch {
    print("❌ Output directory could not be created: \(outputDir.path)\n\(error)")
    exit(1)
}

if let tiffData = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let png = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) {
    do {
        try png.write(to: outputURL)
        print("✅ AppIcon.png saved to: \(outputURL.path)")
    } catch {
        print("❌ Failed to save: \(error)")
        exit(1)
    }
} else {
    print("❌ Failed to generate image data")
    exit(1)
}
