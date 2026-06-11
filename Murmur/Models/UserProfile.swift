//
//  UserProfile.swift
//  First-launch profile (CLAUDE.md MVP #5): your name, an avatar colour, and
//  your partner's iCloud email + name. Persisted in UserDefaults — it's tiny,
//  single-user, app-local state, so SwiftData would be overkill.
//
//  Note: we deliberately do NOT use @AppStorage here. @AppStorage only drives
//  SwiftUI updates from inside a View; inside an ObservableObject it would not
//  publish changes, so the onboarding -> home switch wouldn't react. Instead we
//  use @Published properties that persist to UserDefaults on change.
//

import SwiftUI

@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let onboarded = "murmur.profile.isOnboarded"
        static let userName = "murmur.profile.userName"
        static let partnerName = "murmur.profile.partnerName"
        static let partnerEmail = "murmur.profile.partnerEmail"
        static let avatarColor = "murmur.profile.avatarColor"
    }

    @Published var isOnboarded: Bool { didSet { defaults.set(isOnboarded, forKey: Key.onboarded) } }
    @Published var userName: String { didSet { defaults.set(userName, forKey: Key.userName) } }
    @Published var partnerName: String { didSet { defaults.set(partnerName, forKey: Key.partnerName) } }
    @Published var partnerEmail: String { didSet { defaults.set(partnerEmail, forKey: Key.partnerEmail) } }
    /// 0xRRGGBB colour literal, stored as Int.
    @Published var avatarColorValue: Int { didSet { defaults.set(avatarColorValue, forKey: Key.avatarColor) } }

    private init() {
        isOnboarded = defaults.bool(forKey: Key.onboarded)
        userName = defaults.string(forKey: Key.userName) ?? ""
        partnerName = defaults.string(forKey: Key.partnerName) ?? ""
        partnerEmail = defaults.string(forKey: Key.partnerEmail) ?? ""
        avatarColorValue = (defaults.object(forKey: Key.avatarColor) as? Int) ?? Int(AvatarColor.options.first!.hex)
    }

    /// The chosen avatar colour resolved to a SwiftUI Color.
    var avatarColor: Color { Color(hex: UInt32(truncatingIfNeeded: avatarColorValue)) }

    func complete(userName: String, partnerName: String, partnerEmail: String, colorHex: UInt32) {
        self.userName = userName
        self.partnerName = partnerName
        self.partnerEmail = partnerEmail
        self.avatarColorValue = Int(colorHex)
        self.isOnboarded = true
    }
}

// MARK: - Avatar colour choices

enum AvatarColor {
    struct Choice: Identifiable, Equatable {
        let hex: UInt32
        var id: UInt32 { hex }
        var color: Color { Color(hex: hex) }
    }

    /// A small warm-leaning palette — no photos needed for MVP.
    static let options: [Choice] = [
        Choice(hex: 0xC97D6E), // dusty rose / terracotta
        Choice(hex: 0xD9A05B), // amber
        Choice(hex: 0xC97DF0), // orchid
        Choice(hex: 0x7B9FFF), // periwinkle
        Choice(hex: 0x1AD4B8), // teal
        Choice(hex: 0xE0668A), // rose
    ]
}
