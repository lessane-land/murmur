//
//  Theme.swift
//  Murmur — design tokens.
//
//  Warm dark, dusty-rose accent, SF Pro Rounded throughout. All colors and
//  fonts are accessed through `MurmurColor` / `MurmurFont` so views never touch
//  raw values.
//

import SwiftUI

// MARK: - Colors

enum MurmurColor {
    /// Warm near-black canvas.
    static let background = Color(hex: 0x1B1512)
    /// Slightly lifted surface for cards / wells.
    static let surface = Color(hex: 0x241C18)
    static let surfaceHi = Color.white.opacity(0.06)

    static let hairline = Color.white.opacity(0.08)
    static let hairlineStrong = Color.white.opacity(0.14)

    // Dusty rose accent ramp.
    static let accent = Color(hex: 0xC58B9B)
    static let accentDeep = Color(hex: 0xA86E80)
    static let accentSoft = Color(hex: 0xD9A3B1)

    /// The live "recording" pulse colour — a touch hotter than the accent.
    static let recordingDot = Color(hex: 0xE3899C)

    // Warm inks.
    static let inkPrimary = Color(hex: 0xF4ECEA)
    static let inkSecondary = Color(hex: 0xB8A9A4)
    static let inkTertiary = Color(hex: 0x7E726E)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accentSoft, accent, accentDeep],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Typography (SF Pro Rounded)

enum MurmurFont {
    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Large monospaced-digit timer face.
    static func timer(_ size: CGFloat = 60) -> Font {
        .system(size: size, weight: .medium, design: .rounded).monospacedDigit()
    }
}

// MARK: - Helpers

extension Color {
    /// Hex literal initialiser, e.g. `Color(hex: 0xC58B9B)`.
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

extension View {
    /// Small uppercase tracking label used for overlines.
    func murmurOverline() -> some View {
        self.font(MurmurFont.rounded(12, weight: .semibold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(MurmurColor.inkSecondary)
    }
}
