//
//  Components.swift
//  Shared visual atoms that carry the design language: waveforms (static +
//  live), the gradient avatar, the glass icon button, and the breathing record
//  button (the emotional centre).
//

import SwiftUI
import CoreLocation
import AVFoundation
import MediaPlayer

// MARK: - Static waveform with progress

/// Bars 0...1 tall; bars before `progress` use the accent gradient, the rest
/// are muted. The visual signature of a murmur.
struct WaveformView: View {
    @ObservedObject private var theme = Theme.shared
    let bars: [Double]
    var progress: Double = 1
    var height: CGFloat = 40
    var gap: CGFloat = 2.5
    var minHeight: CGFloat = 3
    var activeStyle: AnyShapeStyle = AnyShapeStyle(MurmurColor.accentGradient)
    var inactiveColor: Color = MurmurColor.waveInactive

    var body: some View {
        // Bars fill the available width exactly, so the waveform can never
        // overflow its container regardless of how many samples there are.
        GeometryReader { geo in
            let n = max(bars.count, 1)
            let barW = max(1, (geo.size.width - CGFloat(n - 1) * gap) / CGFloat(n))
            let playIndex = Int((progress * Double(n)).rounded())
            HStack(alignment: .center, spacing: gap) {
                ForEach(bars.indices, id: \.self) { i in
                    Capsule()
                        .fill(i < playIndex ? activeStyle : AnyShapeStyle(inactiveColor))
                        .frame(width: barW, height: max(minHeight, CGFloat(bars[i]) * height))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
        }
        .frame(height: height)
    }
}

// MARK: - Live recording waveform

/// Animated bars that peak in the middle and breathe with the input `level`.
struct LiveWaveformView: View {
    @ObservedObject private var theme = Theme.shared
    var level: CGFloat
    var paused: Bool = false
    var barCount: Int = 33
    var height: CGFloat = 130

    var body: some View {
        TimelineView(.animation(paused: paused)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let barW: CGFloat = 4, gap: CGFloat = 4
                let totalW = CGFloat(barCount) * barW + CGFloat(barCount - 1) * gap
                let startX = (size.width - totalW) / 2
                let shading = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [MurmurColor.accentSoft, MurmurColor.accent, MurmurColor.accentDeep]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: size.width, y: 0))
                for i in 0..<barCount {
                    let mid = CGFloat(barCount - 1) / 2
                    let center = 1 - abs(CGFloat(i) - mid) / mid
                    let phase = t * 6.2
                    let wobble = (sin(phase * (0.7 + Double(i) * 0.05) + Double(i) * 0.9)
                                  + sin(phase * 1.9 + Double(i) * 2.1)) / 2
                    let base = 0.12 + (0.5 + 0.5 * CGFloat(wobble)) * (0.25 + center * 0.75)
                    let amp = paused ? 0.12 : min(1, base * (0.45 + level))
                    let h = max(6, amp * height)
                    let x = startX + CGFloat(i) * (barW + gap)
                    let rect = CGRect(x: x, y: (size.height - h) / 2, width: barW, height: h)
                    context.fill(Capsule().path(in: rect), with: shading)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Avatar

/// Gradient circle with a serif-italic initial and an optional night badge.
struct MurmurAvatar: View {
    @ObservedObject private var theme = Theme.shared
    var initial: String
    var size: CGFloat = 40
    /// Optional solid fill (e.g. your profile colour); defaults to the gradient.
    var solidColor: Color? = nil
    var night: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(solidColor.map { AnyShapeStyle($0) } ?? AnyShapeStyle(MurmurColor.accentGradient))
                .frame(width: size, height: size)
                .overlay(
                    Text(initial)
                        .font(MurmurFont.serifItalic(size * 0.46, weight: .medium))
                        .foregroundStyle(MurmurColor.background)
                )
                .shadow(color: MurmurColor.accentDeep.opacity(0.32), radius: 10, y: 4)

            if night {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: size * 0.22))
                    .foregroundStyle(MurmurColor.accentSoft)
                    .padding(size * 0.07)
                    .background(Circle().fill(MurmurColor.background))
                    .offset(x: 3, y: 3)
            }
        }
    }
}

// MARK: - Glass icon button

struct GlassButton: View {
    let systemName: String
    var size: CGFloat = 38
    var iconSize: CGFloat = 16
    var tint: Color = MurmurColor.inkPrimary
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(MurmurColor.hairlineStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Breathing record button (the emotional centre)

struct BreathingRecordButton: View {
    @ObservedObject private var theme = Theme.shared
    var size: CGFloat = 74
    var action: () -> Void
    @State private var breathe = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [MurmurColor.accentSoft.opacity(0.45),
                                 MurmurColor.accentDeep.opacity(0.15), .clear],
                        center: .center, startRadius: 4, endRadius: size * 0.85))
                    .frame(width: size * 1.7, height: size * 1.7)
                    .scaleEffect(breathe ? 1.12 : 1)
                    .opacity(breathe ? 1 : 0.85)

                Circle()
                    .fill(MurmurColor.accentGradient)
                    .frame(width: size, height: size)
                    .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 2).padding(4))
                    .shadow(color: MurmurColor.accentDeep.opacity(0.45), radius: 18, y: 10)

                Image(systemName: "mic.fill")
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(MurmurColor.background)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}

// MARK: - Location picker (search any city by name via geocoding)

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [GeoResult] = []
    @State private var isSearching = false
    @State private var message: String? = "Type a city and search."
    var onSelect: (PartnerLocation) -> Void

    private let geocoder = CLGeocoder()

    struct GeoResult: Identifiable {
        let id = UUID()
        let city: String
        let detail: String
        let timeZoneID: String
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                if let message {
                    Spacer()
                    Text(message)
                        .font(MurmurFont.rounded(14))
                        .foregroundStyle(MurmurColor.inkTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                } else {
                    List(results) { result in
                        Button {
                            onSelect(PartnerLocation(city: result.city, timeZoneID: result.timeZoneID))
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.city)
                                    .font(MurmurFont.rounded(16, weight: .medium))
                                    .foregroundStyle(MurmurColor.inkPrimary)
                                Text(result.detail)
                                    .font(MurmurFont.rounded(12))
                                    .foregroundStyle(MurmurColor.inkTertiary)
                            }
                        }
                        .listRowBackground(MurmurColor.surface)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(MurmurColor.background.ignoresSafeArea())
            .navigationTitle("Where are they?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(MurmurColor.inkTertiary)
            TextField("Type any city — San Francisco, Oakland…", text: $query)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .foregroundStyle(MurmurColor.inkPrimary)
                .onSubmit(search)
            if isSearching {
                ProgressView().tint(MurmurColor.accent)
            } else if !query.isEmpty {
                Button { search() } label: { Image(systemName: "arrow.right.circle.fill") }
                    .foregroundStyle(MurmurColor.accent)
            }
        }
        .padding(14)
        .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(MurmurColor.hairline, lineWidth: 1))
        .padding(16)
    }

    private func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        message = nil
        results = []
        geocoder.cancelGeocode()
        geocoder.geocodeAddressString(trimmed) { placemarks, error in
            isSearching = false
            if let error = error as NSError?,
               error.domain == kCLErrorDomain, error.code == CLError.network.rawValue {
                message = "Search failed — check your connection."
                return
            }
            guard let placemarks, !placemarks.isEmpty else {
                message = "No place called \u{201C}\(trimmed)\u{201D}."
                return
            }
            var seen = Set<String>()
            results = placemarks.compactMap { placemark -> GeoResult? in
                guard let tz = placemark.timeZone else { return nil }
                let city = placemark.locality ?? placemark.name ?? trimmed
                let detail = [placemark.administrativeArea, placemark.country]
                    .compactMap { $0 }.joined(separator: ", ")
                let key = "\(city)|\(tz.identifier)"
                guard !seen.contains(key) else { return nil }
                seen.insert(key)
                return GeoResult(city: city,
                                 detail: detail.isEmpty ? tz.identifier : detail,
                                 timeZoneID: tz.identifier)
            }
            if results.isEmpty { message = "Couldn't find a time zone for \u{201C}\(trimmed)\u{201D}." }
        }
    }
}

// MARK: - Pulsing rings (recording stop button)

struct PulsingRings: View {
    var diameter: CGFloat = 92
    var color: Color = MurmurColor.recordingPink

    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Ring(delay: Double(i) * 0.8, diameter: diameter, color: color)
            }
        }
    }

    private struct Ring: View {
        let delay: Double
        let diameter: CGFloat
        let color: Color
        @State private var animate = false

        var body: some View {
            Circle()
                .strokeBorder(color.opacity(0.55), lineWidth: 2)
                .frame(width: diameter, height: diameter)
                .scaleEffect(animate ? 2.0 : 1)
                .opacity(animate ? 0 : 0.55)
                .onAppear {
                    withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(delay)) {
                        animate = true
                    }
                }
        }
    }
}

// MARK: - Lock-screen "Now Playing"

/// A player that the lock screen / Control Center can drive remotely.
@MainActor
protocol NowPlayable: AnyObject {
    func remoteResume()
    func remotePause()
    func remoteToggle()
    func remoteSeek(to time: TimeInterval)
}

/// Bridges whichever player is active to the system Now Playing UI (lock screen,
/// Control Center, headphones). Both the inline chat player and the full-screen
/// player route through here, so long murmurs can be controlled without
/// unlocking. Requires the "audio" background mode.
@MainActor
final class NowPlayingCenter {
    static let shared = NowPlayingCenter()
    private weak var active: (any NowPlayable)?
    private var configured = false

    func setActive(_ player: any NowPlayable) {
        active = player
        configureCommands()
    }

    func update(title: String, duration: TimeInterval, elapsed: TimeInterval, isPlaying: Bool) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = "Murmur"
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func configureCommands() {
        guard !configured else { return }
        configured = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in self?.active?.remoteResume(); return .success }
        center.pauseCommand.addTarget { [weak self] _ in self?.active?.remotePause(); return .success }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in self?.active?.remoteToggle(); return .success }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.active?.remoteSeek(to: event.positionTime)
            return .success
        }
    }
}

// MARK: - Inline playback (play a murmur straight from the chat)

/// One shared audio player for the inbox, so tapping play on a bubble plays it
/// in place — and starting one murmur stops whatever was playing before. The
/// full-screen PlayerView uses its own controller; this is just for the list.
@MainActor
final class MurmurPlaybackController: NSObject, ObservableObject {
    static let shared = MurmurPlaybackController()

    @Published private(set) var currentID: UUID?
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var currentTitle = "Murmur"

    func isCurrent(_ murmur: Murmur) -> Bool { currentID == murmur.id }

    /// Play / pause / resume the given murmur.
    func toggle(_ murmur: Murmur) {
        if currentID == murmur.id {
            if isPlaying { pause() } else { resume() }
        } else {
            start(murmur)
        }
    }

    private func start(_ murmur: Murmur) {
        stop()
        configureSession()
        guard let player = try? AVAudioPlayer(contentsOf: murmur.audioFileURL) else { return }
        player.delegate = self
        player.prepareToPlay()
        player.play()
        self.player = player
        currentID = murmur.id
        currentTitle = murmur.isOutgoing ? "You" : murmur.senderName
        isPlaying = true
        progress = 0
        startTimer()
        NowPlayingCenter.shared.setActive(self)
        updateNowPlaying()
    }

    private func resume() {
        player?.play()
        isPlaying = true
        startTimer()
        updateNowPlaying()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
        updateNowPlaying()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        progress = 0
        currentID = nil
        timer?.invalidate()
        timer = nil
        NowPlayingCenter.shared.clear()
    }

    private func updateNowPlaying() {
        guard let player else { return }
        NowPlayingCenter.shared.update(title: currentTitle, duration: player.duration,
                                       elapsed: player.currentTime, isPlaying: isPlaying)
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player, player.duration > 0 else { return }
                self.progress = player.currentTime / player.duration
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}

extension MurmurPlaybackController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stop() }
    }
}

extension MurmurPlaybackController: NowPlayable {
    func remoteResume() { if !isPlaying { resume() } }
    func remotePause() { if isPlaying { pause() } }
    func remoteToggle() { if isPlaying { pause() } else { resume() } }
    func remoteSeek(to time: TimeInterval) {
        guard let player else { return }
        player.currentTime = max(0, min(time, player.duration))
        progress = player.duration > 0 ? player.currentTime / player.duration : 0
        updateNowPlaying()
    }
}
