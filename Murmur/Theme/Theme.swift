//
//  Theme.swift
//  Murmur — design tokens.
//
//  Three palettes ship and are switchable at runtime from Settings: Aurora
//  (default), Golden Hour, Deep Ocean. The active palette lives on
//  `Theme.shared`, is persisted across launches, and any view observing it
//  recolors instantly. Neutral inks/surfaces are constant across palettes.
//
//  Typography is SF Pro Rounded throughout. All colors and fonts are accessed
//  through `MurmurColor` / `MurmurFont` so views never touch raw values.
//

import SwiftUI

// MARK: - Palette

struct MurmurPalette: Identifiable, Equatable {
    let id: String
    let name: String
    let accentStart: Color
    let accentMid: Color
    let accentEnd: Color
    let background: Color
    let backgroundWell: Color
    let recordingDot: Color

    /// Aurora — orchid → periwinkle on a cool near-black. The default.
    static let aurora = MurmurPalette(
        id: "aurora", name: "Aurora",
        accentStart: Color(hex: 0xC97DF0), accentMid: Color(hex: 0x9B8DF7), accentEnd: Color(hex: 0x7B9FFF),
        background: Color(hex: 0x0A0A12), backgroundWell: Color(hex: 0x06060C),
        recordingDot: Color(hex: 0xFF5B7F))

    /// Golden Hour — terracotta → magenta on a warm near-black.
    static let goldenHour = MurmurPalette(
        id: "golden", name: "Golden Hour",
        accentStart: Color(hex: 0xE07840), accentMid: Color(hex: 0xDF5A56), accentEnd: Color(hex: 0xDC4070),
        background: Color(hex: 0x140A0B), backgroundWell: Color(hex: 0x0C0506),
        recordingDot: Color(hex: 0xFF6F91))

    /// Deep Ocean — teal → cobalt on a cool near-black.
    static let deepOcean = MurmurPalette(
        id: "ocean", name: "Deep Ocean",
        accentStart: Color(hex: 0x1AD4B8), accentMid: Color(hex: 0x19A2CC), accentEnd: Color(hex: 0x1870E0),
        background: Color(hex: 0x06101A), backgroundWell: Color(hex: 0x040A11),
        recordingDot: Color(hex: 0x4FD6C0))

    static let all: [MurmurPalette] = [.aurora, .goldenHour, .deepOcean]

    var gradient: LinearGradient {
        LinearGradient(colors: [accentStart, accentMid, accentEnd],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Theme (runtime-switchable, persisted)

@MainActor
final class Theme: ObservableObject {
    static let shared = Theme()

    private static let storageKey = "murmur.selectedPalette"

    @Published var palette: MurmurPalette {
        didSet { UserDefaults.standard.set(palette.id, forKey: Self.storageKey) }
    }

    private init() {
        let savedID = UserDefaults.standard.string(forKey: Self.storageKey)
        palette = MurmurPalette.all.first { $0.id == savedID } ?? .aurora
    }

    func select(_ palette: MurmurPalette) {
        self.palette = palette
    }
}

// MARK: - Color tokens

/// Accent + background read the active palette; neutrals are constant across
/// palettes (they read fine on every near-black).
enum MurmurColor {
    private static var p: MurmurPalette { Theme.shared.palette }

    // Palette-driven
    static var accentSoft: Color { p.accentStart }
    static var accent: Color { p.accentMid }
    static var accentDeep: Color { p.accentEnd }
    static var background: Color { p.background }
    static var backgroundWell: Color { p.backgroundWell }
    static var recordingDot: Color { p.recordingDot }
    static var accentGradient: LinearGradient { p.gradient }

    // Constant neutrals
    static let surface = Color.white.opacity(0.05)
    static let surfaceHi = Color.white.opacity(0.07)
    static let hairline = Color.white.opacity(0.08)
    static let hairlineStrong = Color.white.opacity(0.14)
    static let inkPrimary = Color(hex: 0xF3F1FA)
    static let inkSecondary = Color(hex: 0xA8A4BE)
    static let inkTertiary = Color(hex: 0x6A6783)
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
