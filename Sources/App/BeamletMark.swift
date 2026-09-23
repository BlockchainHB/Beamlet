import SwiftUI

/// Original nine-ray mark with an open eastern side and a short outbound beam.
struct BeamletMark: Shape {
    var connected = true
    static func menuBarImage(connected: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.addPath(BeamletMark(connected: connected).path(in: rect.insetBy(dx: 1, dy: 1)).cgPath)
            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(1.7)
            context.setLineCap(.round)
            context.strokePath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = connected ? "Beamlet online" : "Beamlet offline"
        return image
    }
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX - unit * 0.04, y: rect.midY)
        var path = Path()
        for index in 1...9 {
            let angle = Double(index) * .pi / 5
            let inner = unit * (connected ? 0.19 : 0.23)
            let outer = unit * (index.isMultiple(of: 2) ? 0.43 : 0.38)
            path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
            path.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
        }
        path.move(to: CGPoint(x: center.x + unit * 0.20, y: center.y))
        path.addLine(to: CGPoint(x: center.x + unit * (connected ? 0.5 : 0.32), y: center.y))
        return path
    }
}

enum BeamletStyle {
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 1, green: 0.51, blue: 0.36, alpha: 1)
            : NSColor(srgbRed: 0.80, green: 0.28, blue: 0.16, alpha: 1)
    })
    static let markStroke = StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
}
