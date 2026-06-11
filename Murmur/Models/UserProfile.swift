//
//  UserProfile.swift
//  First-launch profile (CLAUDE.md MVP #5): your name, your style, and your
//  partner's name, iCloud email, and city/time zone (for presence). Persisted
//  in UserDefaults via @Published properties so changes drive the UI.
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
        static let partnerCity = "murmur.profile.partnerCity"
        static let partnerTZ = "murmur.profile.partnerTimeZone"
        static let avatarColor = "murmur.profile.avatarColor"
    }

    @Published var isOnboarded: Bool { didSet { defaults.set(isOnboarded, forKey: Key.onboarded) } }
    @Published var userName: String { didSet { defaults.set(userName, forKey: Key.userName) } }
    @Published var partnerName: String { didSet { defaults.set(partnerName, forKey: Key.partnerName) } }
    @Published var partnerEmail: String { didSet { defaults.set(partnerEmail, forKey: Key.partnerEmail) } }
    @Published var partnerCity: String { didSet { defaults.set(partnerCity, forKey: Key.partnerCity) } }
    @Published var partnerTimeZoneID: String { didSet { defaults.set(partnerTimeZoneID, forKey: Key.partnerTZ) } }
    @Published var avatarColorValue: Int { didSet { defaults.set(avatarColorValue, forKey: Key.avatarColor) } }

    private init() {
        isOnboarded = defaults.bool(forKey: Key.onboarded)
        userName = defaults.string(forKey: Key.userName) ?? ""
        partnerName = defaults.string(forKey: Key.partnerName) ?? ""
        partnerEmail = defaults.string(forKey: Key.partnerEmail) ?? ""
        partnerCity = defaults.string(forKey: Key.partnerCity) ?? PartnerLocation.options.first!.city
        partnerTimeZoneID = defaults.string(forKey: Key.partnerTZ) ?? PartnerLocation.options.first!.timeZoneID
        avatarColorValue = (defaults.object(forKey: Key.avatarColor) as? Int) ?? Int(MurmurPalette.goldenHour.avatarHex)
    }

    var avatarColor: Color { Color(hex: UInt32(truncatingIfNeeded: avatarColorValue)) }

    func complete(userName: String, partnerName: String, partnerEmail: String,
                  location: PartnerLocation, colorHex: UInt32) {
        self.userName = userName
        self.partnerName = partnerName
        self.partnerEmail = partnerEmail
        self.partnerCity = location.city
        self.partnerTimeZoneID = location.timeZoneID
        self.avatarColorValue = Int(colorHex)
        self.isOnboarded = true
    }

    // MARK: - Partner presence (their local time, offset, day/night)

    var partnerTimeZone: TimeZone? { TimeZone(identifier: partnerTimeZoneID) }

    private var partnerHour: Int {
        guard let tz = partnerTimeZone else { return 12 }
        var calendar = Calendar.current
        calendar.timeZone = tz
        return calendar.component(.hour, from: Date())
    }

    var partnerLocalTime: String {
        guard let tz = partnerTimeZone else { return "" }
        let formatter = DateFormatter()
        formatter.timeZone = tz
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: Date())
    }

    var partnerOffsetLabel: String {
        guard let tz = partnerTimeZone else { return "" }
        let hours = (tz.secondsFromGMT() - TimeZone.current.secondsFromGMT()) / 3600
        if hours == 0 { return "same time" }
        return hours > 0 ? "+\(hours) HRS" : "\(hours) HRS"
    }

    var partnerIsNight: Bool { partnerHour >= 21 || partnerHour < 7 }

    var partnerStatus: String {
        switch partnerHour {
        case 22...23, 0..<6: return "asleep"
        case 6..<9: return "waking up"
        case 21: return "asleep soon"
        case 18..<21: return "evening there"
        default: return "in the day"
        }
    }
}

// MARK: - Partner location options

struct PartnerLocation: Identifiable, Hashable {
    let city: String
    let timeZoneID: String
    var id: String { city }

    static let options: [PartnerLocation] = [
        .init(city: "San Francisco", timeZoneID: "America/Los_Angeles"),
        .init(city: "Boston", timeZoneID: "America/New_York"),
        .init(city: "New York", timeZoneID: "America/New_York"),
        .init(city: "Chicago", timeZoneID: "America/Chicago"),
        .init(city: "Denver", timeZoneID: "America/Denver"),
        .init(city: "Mexico City", timeZoneID: "America/Mexico_City"),
        .init(city: "London", timeZoneID: "Europe/London"),
        .init(city: "Lisbon", timeZoneID: "Europe/Lisbon"),
        .init(city: "Madrid", timeZoneID: "Europe/Madrid"),
        .init(city: "Paris", timeZoneID: "Europe/Paris"),
        .init(city: "Berlin", timeZoneID: "Europe/Berlin"),
        .init(city: "Dubai", timeZoneID: "Asia/Dubai"),
        .init(city: "Mumbai", timeZoneID: "Asia/Kolkata"),
        .init(city: "Singapore", timeZoneID: "Asia/Singapore"),
        .init(city: "Tokyo", timeZoneID: "Asia/Tokyo"),
        .init(city: "Sydney", timeZoneID: "Australia/Sydney"),
    ]
}
