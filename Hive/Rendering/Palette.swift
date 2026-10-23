import UIKit

enum Palette {
    static let background = UIColor(hex: 0x0B0A08)
    static let amber = UIColor(hex: 0xE8A33C)
    static let gold = UIColor(hex: 0xF2C14E)
    static let burntOrange = UIColor(hex: 0xB8641B)
    static let slate = UIColor(hex: 0x5E6B7A)
    static let violet = UIColor(hex: 0x7A4FA3)
    static let sicklyGreen = UIColor(hex: 0x6E8B3D)
    static let white = UIColor(hex: 0xFFFFFF)
    /// Slate-green beetle shell.
    static let beetle = UIColor(hex: 0x4F6B5A)
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
