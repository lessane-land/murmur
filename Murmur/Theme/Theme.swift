//
//  Theme.swift
//  Murmur — design tokens.
//
//  Per CLAUDE.md the core aesthetic is a warm "candlelight" dark with a dusty
//  rose / terracotta accent. Three palettes ship and are switchable at runtime
//  from Settings; the default (Golden Hour) matches CLAUDE.md's warm dark
//  (#1A1714) + dusty rose (#C97D6E). Aurora and Deep Ocean are cooler
//  alternates. The active palette lives on `Theme.shared`, persists across
//  launches, and any view observing it recolors instantly.
//
//  Typography follows CLAUDE.md: New York (Apple serif) for display — the
//  wordmark and the recording timer — and SF Pro Rounded for body / UI.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Palette

struct MurmurPalette: Identifiable, Equatable {
    let id: String
    let name: String
    let accentStart: Color
    let accentMid: Color
    let accentEnd: Color
    let background: Color
    let backgroundWell: Color
    /// Inner tint of the recording sheet's radial background.
    let sheetTint: Color
    let recordingDot: Color
    /// A representative solid colour for avatars in this style.
    let avatarHex: UInt32
    /// Alternate app-icon name (nil = the primary icon).
    let alternateIconName: String?

    // Exact values from the design (Murmur.html palette variables).

    /// Golden Hour — terracotta → magenta on a warm near-black. The default.
    static let goldenHour = MurmurPalette(
        id: "golden", name: "Golden Hour",
        accentStart: Color(hex: 0xE07840), accentMid: Color(hex: 0xDF5A56), accentEnd: Color(hex: 0xDC4070),
        background: Color(hex: 0x140A0B), backgroundWell: Color(hex: 0x0C0506),
        sheetTint: Color(hex: 0x3A181A), recordingDot: Color(hex: 0xE07840), avatarHex: 0xE07840,
        alternateIconName: nil)

    /// Aurora — orchid → periwinkle on a cool near-black.
    static let aurora = MurmurPalette(
        id: "aurora", name: "Aurora",
        accentStart: Color(hex: 0xC97DF0), accentMid: Color(hex: 0x9B8DF7), accentEnd: Color(hex: 0x7B9FFF),
        background: Color(hex: 0x0A0A12), backgroundWell: Color(hex: 0x07070D),
        sheetTint: Color(hex: 0x281C42), recordingDot: Color(hex: 0xC97DF0), avatarHex: 0xC97DF0,
        alternateIconName: "AppIcon-Aurora")

    /// Deep Ocean — teal → cobalt on a cool near-black.
    static let deepOcean = MurmurPalette(
        id: "ocean", name: "Deep Ocean",
        accentStart: Color(hex: 0x1AD4B8), accentMid: Color(hex: 0x19A2CC), accentEnd: Color(hex: 0x1870E0),
        background: Color(hex: 0x06101A), backgroundWell: Color(hex: 0x040A11),
        sheetTint: Color(hex: 0x08202E), recordingDot: Color(hex: 0x1AD4B8), avatarHex: 0x1AD4B8,
        alternateIconName: "AppIcon-DeepOcean")

    static let all: [MurmurPalette] = [.goldenHour, .aurora, .deepOcean]

    var gradient: LinearGradient {
        LinearGradient(colors: [accentStart, accentMid, accentEnd],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Soft, low-opacity accent for fills behind icons / CTAs.
    var gradientSoft: LinearGradient {
        LinearGradient(colors: [accentStart.opacity(0.22), accentEnd.opacity(0.22)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Theme (runtime-switchable, persisted)

/// Not @MainActor: it's read by the nonisolated `MurmurColor` tokens and only
/// ever mutated from the UI, so plain ObservableObject is correct here.
final class Theme: ObservableObject {
    // Read by nonisolated colour tokens; only mutated from the UI.
    nonisolated(unsafe) static let shared = Theme()

    private static let storageKey = "murmur.selectedPalette"

    @Published var palette: MurmurPalette {
        didSet { UserDefaults.standard.set(palette.id, forKey: Self.storageKey) }
    }

    private init() {
        let savedID = UserDefaults.standard.string(forKey: Self.storageKey)
        palette = MurmurPalette.all.first { $0.id == savedID } ?? .goldenHour
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
    static var sheetTint: Color { p.sheetTint }
    static var recordingDot: Color { p.recordingDot }
    static var accentGradient: LinearGradient { p.gradient }
    static var accentGradientSoft: LinearGradient { p.gradientSoft }

    // Constant neutrals (read well on every near-black palette).
    static let surface = Color.white.opacity(0.045)
    static let surfaceHi = Color.white.opacity(0.07)
    static let hairline = Color.white.opacity(0.08)
    static let hairlineStrong = Color.white.opacity(0.14)
    static let inkPrimary = Color(hex: 0xF3F1FA)
    static let inkSecondary = Color(hex: 0xA8A4BE)
    static let inkTertiary = Color(hex: 0x6A6783)
    static let waveInactive = Color.white.opacity(0.16)
    /// Fixed live-recording pulse colour (matches the design).
    static let recordingPink = Color(hex: 0xFF5B7F)
}

// MARK: - Typography

enum MurmurFont {
    /// SF Pro Rounded — body and UI labels.
    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// New York serif — display text (transcript body, etc.).
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// New York serif *italic* — wordmark, timestamps, day labels, the timer.
    static func serifItalic(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif).italic()
    }

    /// Serif-italic wordmark.
    static func wordmark(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .serif).italic()
    }

    /// Large serif-italic monospaced-digit recording timer.
    static func timer(_ size: CGFloat = 60) -> Font {
        .system(size: size, weight: .regular, design: .serif).italic().monospacedDigit()
    }
}

// MARK: - Helpers

extension Color {
    /// Hex literal initialiser, e.g. `Color(hex: 0xC97D6E)`.
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
