#!/usr/bin/env swift
import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "build/release/dmg-background.png"
let outputURL = URL(fileURLWithPath: outputPath)

let width = 720
let height = 420
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

func drawText(_ text: String, at point: NSPoint, font: NSFont, color: NSColor, width: CGFloat? = nil) {
  let paragraph = NSMutableParagraphStyle()
  paragraph.lineBreakMode = .byWordWrapping
  let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: color,
    .paragraphStyle: paragraph
  ]
  let attributed = NSAttributedString(string: text, attributes: attributes)
  let maxWidth = width ?? canvas.width
  let bounds = attributed.boundingRect(
    with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude),
    options: [.usesLineFragmentOrigin, .usesFontLeading]
  )
  attributed.draw(in: rectTop(point.x, point.y, maxWidth, ceil(bounds.height)))
}

func strokePath(_ path: NSBezierPath, color: NSColor, width: CGFloat) {
  color.setStroke()
  path.lineWidth = width
  path.lineCapStyle = .round
  path.lineJoinStyle = .round
  path.stroke()
}

let image = NSImage(size: canvas)
image.lockFocus()

color(0xf8f3e8).setFill()
NSRect(origin: .zero, size: canvas).fill()

let wash = NSGradient(colors: [
  color(0xfffbf1, alpha: 0.95),
  color(0xf2ead8, alpha: 0.88)
])
wash?.draw(in: NSRect(origin: .zero, size: canvas), angle: 25)

let glow = NSBezierPath(ovalIn: rectTop(420, -40, 380, 260))
color(0xffffff, alpha: 0.42).setFill()
glow.fill()

// Oversized open-book line art. It is intentionally quiet so Finder icons remain dominant.
let pageFill = color(0xfffbf1, alpha: 0.54)
let pageStroke = color(0xd5c9ae, alpha: 0.48)

let leftPage = NSBezierPath()
leftPage.move(to: NSPoint(x: 360, y: y(344)))
leftPage.curve(
  to: NSPoint(x: 86, y: y(304)),
  controlPoint1: NSPoint(x: 258, y: y(318)),
  controlPoint2: NSPoint(x: 160, y: y(318))
)
leftPage.curve(
  to: NSPoint(x: 82, y: y(132)),
  controlPoint1: NSPoint(x: 64, y: y(244)),
  controlPoint2: NSPoint(x: 62, y: y(186))
)
leftPage.curve(
  to: NSPoint(x: 360, y: y(166)),
  controlPoint1: NSPoint(x: 172, y: y(122)),
  controlPoint2: NSPoint(x: 275, y: y(136))
)
leftPage.close()
pageFill.setFill()
leftPage.fill()
strokePath(leftPage, color: pageStroke, width: 1.2)

let rightPage = NSBezierPath()
rightPage.move(to: NSPoint(x: 360, y: y(344)))
rightPage.curve(
  to: NSPoint(x: 638, y: y(300)),
  controlPoint1: NSPoint(x: 452, y: y(314)),
  controlPoint2: NSPoint(x: 566, y: y(312))
)
rightPage.curve(
  to: NSPoint(x: 630, y: y(128)),
  controlPoint1: NSPoint(x: 658, y: y(236)),
  controlPoint2: NSPoint(x: 658, y: y(176))
)
rightPage.curve(
  to: NSPoint(x: 360, y: y(166)),
  controlPoint1: NSPoint(x: 536, y: y(124)),
  controlPoint2: NSPoint(x: 438, y: y(138))
)
rightPage.close()
pageFill.setFill()
rightPage.fill()
strokePath(rightPage, color: pageStroke, width: 1.2)

let spine = NSBezierPath()
spine.move(to: NSPoint(x: 360, y: y(154)))
spine.curve(
  to: NSPoint(x: 360, y: y(352)),
  controlPoint1: NSPoint(x: 354, y: y(214)),
  controlPoint2: NSPoint(x: 354, y: y(288))
)
strokePath(spine, color: color(0xc8b990, alpha: 0.42), width: 1.2)

for i in 0..<6 {
  let top = CGFloat(174 + i * 21)
  let leftLine = NSBezierPath()
  leftLine.move(to: NSPoint(x: 132, y: y(top)))
  leftLine.curve(
    to: NSPoint(x: 308, y: y(top + 6)),
    controlPoint1: NSPoint(x: 188, y: y(top - 6)),
    controlPoint2: NSPoint(x: 246, y: y(top - 4))
  )
  strokePath(leftLine, color: color(0xb8a57d, alpha: 0.28), width: 1.4)

  let rightLine = NSBezierPath()
  rightLine.move(to: NSPoint(x: 414, y: y(top + 5)))
  rightLine.curve(
    to: NSPoint(x: 592, y: y(top - 1)),
    controlPoint1: NSPoint(x: 468, y: y(top - 2)),
    controlPoint2: NSPoint(x: 532, y: y(top - 4))
  )
  strokePath(rightLine, color: color(0xb8a57d, alpha: 0.28), width: 1.4)
}

let highlight = NSBezierPath()
highlight.move(to: NSPoint(x: 248, y: y(282)))
highlight.curve(
  to: NSPoint(x: 470, y: y(274)),
  controlPoint1: NSPoint(x: 322, y: y(294)),
  controlPoint2: NSPoint(x: 398, y: y(262))
)
strokePath(highlight, color: color(0x7dab52, alpha: 0.22), width: 18)

drawText(
  "Install Lexi",
  at: NSPoint(x: 48, y: 42),
  font: NSFont.systemFont(ofSize: 28, weight: .semibold),
  color: color(0x2f332a)
)

drawText(
  "Drag Lexi into Applications",
  at: NSPoint(x: 50, y: 78),
  font: NSFont.systemFont(ofSize: 15, weight: .medium),
  color: color(0x62695c)
)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 282, y: y(224)))
arrow.line(to: NSPoint(x: 438, y: y(224)))
strokePath(arrow, color: color(0x6fa642), width: 4)

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 438, y: y(224)))
arrowHead.line(to: NSPoint(x: 424, y: y(214)))
arrowHead.move(to: NSPoint(x: 438, y: y(224)))
arrowHead.line(to: NSPoint(x: 424, y: y(234)))
strokePath(arrowHead, color: color(0x6fa642), width: 4)

drawText(
  "Move once, read anywhere.",
  at: NSPoint(x: 286, y: 252),
  font: NSFont.systemFont(ofSize: 12, weight: .medium),
  color: color(0x7b806f),
  width: 170
)

drawText(
  "macOS 26.4+",
  at: NSPoint(x: 50, y: 360),
  font: NSFont.systemFont(ofSize: 12, weight: .regular),
  color: color(0x8d907f),
  width: 160
)

drawText(
  "Accessibility permission may be requested for global selection translation.",
  at: NSPoint(x: 360, y: 360),
  font: NSFont.systemFont(ofSize: 12, weight: .regular),
  color: color(0x8d907f),
  width: 310
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
