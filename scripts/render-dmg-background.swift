#!/usr/bin/env swift
import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "build/release/dmg-background.png"
let outputURL = URL(fileURLWithPath: outputPath)

let width = 880
let height = 528
let canvas = NSSize(width: width, height: height)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
  let red = CGFloat((hex >> 16) & 0xff) / 255
  let green = CGFloat((hex >> 8) & 0xff) / 255
  let blue = CGFloat(hex & 0xff) / 255
  return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

func y(_ top: CGFloat) -> CGFloat {
  CGFloat(height) - top
}

func rectTop(_ x: CGFloat, _ top: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
  NSRect(x: x, y: CGFloat(height) - top - h, width: w, height: h)
}

func roundedRectTop(_ x: CGFloat, _ top: CGFloat, _ w: CGFloat, _ h: CGFloat, radius: CGFloat) -> NSBezierPath {
  NSBezierPath(roundedRect: rectTop(x, top, w, h), xRadius: radius, yRadius: radius)
}

func font(_ names: [String], size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
  for name in names {
    if let font = NSFont(name: name, size: size) {
      return font
    }
  }
  return NSFont.systemFont(ofSize: size, weight: weight)
}

func drawText(
  _ text: String,
  at point: NSPoint,
  font: NSFont,
  color: NSColor,
  width: CGFloat? = nil,
  alignment: NSTextAlignment = .left,
  lineHeight: CGFloat? = nil
) {
  let paragraph = NSMutableParagraphStyle()
  paragraph.lineBreakMode = .byWordWrapping
  paragraph.alignment = alignment
  if let lineHeight {
    paragraph.minimumLineHeight = lineHeight
    paragraph.maximumLineHeight = lineHeight
  }

  let attributed = NSAttributedString(string: text, attributes: [
    .font: font,
    .foregroundColor: color,
    .paragraphStyle: paragraph
  ])
  let maxWidth = width ?? canvas.width
  let bounds = attributed.boundingRect(
    with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude),
    options: [.usesLineFragmentOrigin, .usesFontLeading]
  )
  attributed.draw(in: rectTop(point.x, point.y, maxWidth, ceil(bounds.height) + 2))
}

func strokePath(_ path: NSBezierPath, color: NSColor, width: CGFloat, dash: [CGFloat]? = nil) {
  color.setStroke()
  path.lineWidth = width
  path.lineCapStyle = .round
  path.lineJoinStyle = .round
  if let dash {
    path.setLineDash(dash, count: dash.count, phase: 0)
  }
  path.stroke()
}

func fillPath(_ path: NSBezierPath, color: NSColor) {
  color.setFill()
  path.fill()
}

func drawPage(_ path: NSBezierPath, lineStartX: CGFloat, lineEndX: CGFloat) {
  fillPath(path, color: color(0xfffbf1, alpha: 0.18))
  NSGraphicsContext.saveGraphicsState()
  path.addClip()
  for top in stride(from: CGFloat(118), through: CGFloat(338), by: 25) {
    let line = NSBezierPath()
    line.move(to: NSPoint(x: lineStartX, y: y(top)))
    line.curve(
      to: NSPoint(x: lineEndX, y: y(top + 5)),
      controlPoint1: NSPoint(x: lineStartX + 90, y: y(top - 8)),
      controlPoint2: NSPoint(x: lineEndX - 94, y: y(top - 5))
    )
    strokePath(line, color: color(0xe3dccb, alpha: 0.56), width: 1.5)
  }
  NSGraphicsContext.restoreGraphicsState()
  strokePath(path, color: color(0xcfc6b1, alpha: 0.42), width: 1.3)
}

func drawChip(x: CGFloat, top: CGFloat, width: CGFloat, accent: Bool = false, icon: (CGFloat, CGFloat) -> Void, title: String, subtitle: String) {
  let chip = roundedRectTop(x, top, width, 46, radius: 8)
  fillPath(chip, color: accent ? color(0xb35c2c, alpha: 0.06) : color(0xfbf8f1, alpha: 0.90))
  strokePath(chip, color: accent ? color(0xb35c2c, alpha: 0.22) : color(0xe3dccb, alpha: 0.95), width: 0.75)
  icon(x + 14, top + 14)
  drawText(title, at: NSPoint(x: x + 39, y: top + 10), font: NSFont.systemFont(ofSize: 11.5, weight: .semibold), color: accent ? color(0xb35c2c) : color(0x1f1b15), width: width - 50)
  drawText(subtitle, at: NSPoint(x: x + 39, y: top + 25), font: font(["PingFang SC"], size: 10), color: color(0xa59c89), width: width - 50)
}

let image = NSImage(size: canvas)
image.lockFocus()

color(0xf5f1e8).setFill()
NSRect(origin: .zero, size: canvas).fill()

let wash = NSGradient(colors: [
  color(0xfbf8f1, alpha: 0.94),
  color(0xede7d8, alpha: 0.86)
])
wash?.draw(in: NSRect(origin: .zero, size: canvas), angle: 155)

let topGlow = NSBezierPath(ovalIn: rectTop(600, -126, 360, 360))
fillPath(topGlow, color: color(0xfffcf4, alpha: 0.62))

// Faint open-book spread from the HTML reference. It stays behind Finder icons.
let leftPage = NSBezierPath()
leftPage.move(to: NSPoint(x: 440, y: y(382)))
leftPage.curve(
  to: NSPoint(x: 86, y: y(360)),
  controlPoint1: NSPoint(x: 320, y: y(352)),
  controlPoint2: NSPoint(x: 176, y: y(356))
)
leftPage.curve(
  to: NSPoint(x: 84, y: y(116)),
  controlPoint1: NSPoint(x: 46, y: y(284)),
  controlPoint2: NSPoint(x: 46, y: y(178))
)
leftPage.curve(
  to: NSPoint(x: 440, y: y(158)),
  controlPoint1: NSPoint(x: 190, y: y(96)),
  controlPoint2: NSPoint(x: 326, y: y(122))
)
leftPage.close()
drawPage(leftPage, lineStartX: 170, lineEndX: 398)

let rightPage = NSBezierPath()
rightPage.move(to: NSPoint(x: 440, y: y(382)))
rightPage.curve(
  to: NSPoint(x: 794, y: y(350)),
  controlPoint1: NSPoint(x: 554, y: y(348)),
  controlPoint2: NSPoint(x: 692, y: y(348))
)
rightPage.curve(
  to: NSPoint(x: 782, y: y(108)),
  controlPoint1: NSPoint(x: 834, y: y(272)),
  controlPoint2: NSPoint(x: 824, y: y(174))
)
rightPage.curve(
  to: NSPoint(x: 440, y: y(158)),
  controlPoint1: NSPoint(x: 674, y: y(96)),
  controlPoint2: NSPoint(x: 546, y: y(124))
)
rightPage.close()
drawPage(rightPage, lineStartX: 498, lineEndX: 724)

let gutter = NSBezierPath()
gutter.move(to: NSPoint(x: 440, y: y(82)))
gutter.curve(
  to: NSPoint(x: 440, y: y(426)),
  controlPoint1: NSPoint(x: 433, y: y(178)),
  controlPoint2: NSPoint(x: 433, y: y(324))
)
strokePath(gutter, color: color(0xcfc6b1, alpha: 0.68), width: 1.1)

// Masthead.
let overlineY: CGFloat = 30
let overlineBar = roundedRectTop(52, overlineY + 7, 26, 2.2, radius: 1.1)
fillPath(overlineBar, color: color(0xb35c2c, alpha: 0.90))
drawText(
  "Install · 安 装",
  at: NSPoint(x: 88, y: overlineY),
  font: font(["SF Mono", "Menlo"], size: 10.5, weight: .semibold),
  color: color(0xb35c2c),
  width: 180
)

drawText(
  "Install Lexi",
  at: NSPoint(x: 52, y: 58),
  font: font(["Charter", "Iowan Old Style", "Georgia"], size: 39, weight: .semibold),
  color: color(0x1f1b15),
  width: 310,
  lineHeight: 40
)

drawText(
  "将 Lexi 拖入「应用程序」即可完成安装，一次移动，处处可读。",
  at: NSPoint(x: 52, y: 104),
  font: font(["PingFang SC"], size: 14.5),
  color: color(0x7a7163),
  width: 520,
  lineHeight: 22
)

// Connector between the real Finder icons.
let pathTop: CGFloat = 256
let dashed = NSBezierPath()
dashed.move(to: NSPoint(x: 304, y: y(pathTop)))
dashed.line(to: NSPoint(x: 584, y: y(pathTop)))
strokePath(dashed, color: color(0xb35c2c, alpha: 0.66), width: 2.8, dash: [2, 8.5])

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 596, y: y(pathTop)))
arrow.line(to: NSPoint(x: 620, y: y(pathTop + 14)))
arrow.line(to: NSPoint(x: 596, y: y(pathTop + 28)))
arrow.close()
fillPath(arrow, color: color(0xb35c2c, alpha: 0.92))

let target = roundedRectTop(622, 204, 158, 126, radius: 18)
strokePath(target, color: color(0xb35c2c, alpha: 0.24), width: 1.5, dash: [6, 6])

// Static ghost motion hint from the reference animation.
let ghostCircle = NSBezierPath(ovalIn: rectTop(388, pathTop - 20, 40, 40))
fillPath(ghostCircle, color: color(0xb35c2c, alpha: 0.07))
strokePath(ghostCircle, color: color(0xb35c2c, alpha: 0.14), width: 0.8)

let taglineTop: CGFloat = 292
let highlight = roundedRectTop(444, taglineTop + 22, 120, 8, radius: 4)
let transform = AffineTransform(rotationByDegrees: -0.8)
highlight.transform(using: transform)
fillPath(highlight, color: color(0xb35c2c, alpha: 0.12))

drawText(
  "Move once, read anywhere.",
  at: NSPoint(x: 310, y: taglineTop),
  font: font(["Charter", "Iowan Old Style", "Georgia"], size: 16.5),
  color: color(0x1f1b15),
  width: 260,
  alignment: .center
)
drawText(
  "一次安装，处处可读",
  at: NSPoint(x: 324, y: taglineTop + 25),
  font: font(["PingFang SC"], size: 12.5),
  color: color(0x7a7163),
  width: 230,
  alignment: .center
)

// Footer band.
strokePath(NSBezierPath(rect: rectTop(52, 430, 776, 0.5)), color: color(0xe3dccb, alpha: 0.95), width: 0.5)

drawChip(x: 52, top: 448, width: 136, accent: true, icon: { x, top in
  for (index, barHeight) in [6, 13, 18, 10, 7].enumerated() {
    let bar = roundedRectTop(x + CGFloat(index) * 4, top + (18 - CGFloat(barHeight)) / 2, 2.4, CGFloat(barHeight), radius: 1.2)
    fillPath(bar, color: color(0xb35c2c, alpha: 0.92))
  }
}, title: "Read aloud", subtitle: "朗读 · TTS")

drawChip(x: 198, top: 448, width: 148, icon: { x, top in
  let widths: [CGFloat] = [17, 12, 17, 10]
  for (index, lineWidth) in widths.enumerated() {
    let bar = roundedRectTop(x, top + CGFloat(index) * 5, lineWidth, 2.5, radius: 1.25)
    fillPath(bar, color: index % 2 == 0 ? color(0x7a7163) : color(0xb35c2c, alpha: 0.70))
  }
}, title: "Side-by-side", subtitle: "中英对照")

drawChip(x: 356, top: 448, width: 184, icon: { x, top in
  let select = roundedRectTop(x, top + 2, 16, 13, radius: 3)
  strokePath(select, color: color(0x7a7163), width: 1.6)
  let dot = NSBezierPath(ovalIn: rectTop(x + 12, top + 12, 7, 7))
  fillPath(dot, color: color(0xb35c2c))
}, title: "Select to translate", subtitle: "划词翻译")

drawText(
  "Requires macOS 26.4 or later",
  at: NSPoint(x: 584, y: 450),
  font: font(["SF Mono", "Menlo"], size: 10.5),
  color: color(0x7a7163),
  width: 244,
  alignment: .right
)
drawText(
  "为启用全局划词翻译，可能会请求「辅助功能」权限。",
  at: NSPoint(x: 574, y: 472),
  font: font(["PingFang SC"], size: 11),
  color: color(0xa59c89),
  width: 254,
  alignment: .right,
  lineHeight: 16
)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
  fputs("Failed to render DMG background PNG.\n", stderr)
  exit(1)
}

try FileManager.default.createDirectory(
  at: outputURL.deletingLastPathComponent(),
  withIntermediateDirectories: true
)
try png.write(to: outputURL)
print(outputURL.path)
