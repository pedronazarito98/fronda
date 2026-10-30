import AppKit
import SwiftUI

enum FrondaTheme {
    static let accent = adaptive("Accent", light: 0x526048, dark: 0xBDCCA7)
    static let canvas = adaptive("Canvas", light: 0xF5F3ED, dark: 0x191D18)
    static let surface = adaptive("Surface", light: 0xFCFBF7, dark: 0x242A21)
    static let surfaceRaised = adaptive("SurfaceRaised", light: 0xFFFFFF, dark: 0x2E352B)
    static let border = adaptive("Border", light: 0xDFE1D6, dark: 0x3F473A)
    static let textMuted = adaptive("TextMuted", light: 0x656D5F, dark: 0xACB4A4)
    static let success = adaptive("Success", light: 0x356540, dark: 0xA7CC99)
    static let warning = adaptive("Warning", light: 0x8E5A21, dark: 0xE3BD7E)
    static let danger = adaptive("Danger", light: 0xA7443F, dark: 0xF0A49D)
    static let clay = adaptive("Clay", light: 0x8E6143, dark: 0xD6AF89)
    static let sage = Color(red: 0.74, green: 0.80, blue: 0.65)
    static let spacing: CGFloat = 24
    static let cornerRadius: CGFloat = 18

    private static func adaptive(_ name: String, light: UInt32, dark: UInt32) -> Color {
        Color(
            nsColor: NSColor(name: NSColor.Name("Fronda" + name)) { appearance in
                let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
                return NSColor(
                    srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                    green: CGFloat((value >> 8) & 0xFF) / 255,
                    blue: CGFloat(value & 0xFF) / 255, alpha: 1)
            })
    }
}
