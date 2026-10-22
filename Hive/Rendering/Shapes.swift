import CoreGraphics

/// Shared vector paths.
enum Shapes {
    /// Regular hexagon centred on the origin. Flat-top: vertices at 0°, 60°, …; pointy-top: 30°, 90°, ….
    static func hexPath(circumradius r: CGFloat, pointyTop: Bool = false) -> CGPath {
        let path = CGMutablePath()
        let offset: CGFloat = pointyTop ? .pi / 6 : 0
        for i in 0..<6 {
            let a = offset + CGFloat(i) * .pi / 3
            let p = CGPoint(x: r * cos(a), y: r * sin(a))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }

    /// Rounded rectangle centred on the origin.
    static func roundedRect(_ size: CGSize, corner: CGFloat) -> CGPath {
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        let c = min(corner, size.width / 2, size.height / 2)
        return CGPath(roundedRect: rect, cornerWidth: c, cornerHeight: c, transform: nil)
    }
}
