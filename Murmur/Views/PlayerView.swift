//
//  PlayerView.swift
//  Full-screen murmur player: a waveform scrubber, transport, and a collapsible
//  on-device transcript, with a "murmur back" call to action.
//

import SwiftUI
import SwiftData
import AVFoundation
import Translation

struct PlayerView: View {
    let murmur: Murmur
    var onReply: () -> Void = {}
    var onPlaybackStarted: () -> Void = {}

    @ObservedObject private var theme = Theme.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var controller = AudioPlayerController()
    @State private var showTranscript = true
    @State private var isTranscribing = false
    @State private var transcribeError: String?
    @State private var confirmDelete = false

    // On-device translation (optional). Picking a language sets a fresh
    // configuration, which drives the .translationTask below.
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var translatedText: String?
    @State private var translatedLanguage: String?
    @State private var translateLanguageCode: String?
    @State private var isTranslating = false
    @State private var translateError: String?
    @State private var showLanguagePicker = false
    @State private var warmupConfig: TranslationSession.Configuration?

    /// Pre-download the phone's language pack only once per app run.
    private static var didWarmUp = false

    private let transcriber = TranscriptionService()

    private var bars: [Double] { murmur.displayWaveform(barCount: 52) }
    private var partner: String { murmur.isOutgoing ? ProfileStore.shared.partnerName : murmur.senderName }

    var body: some View {
        ZStack {
            MurmurColor.background
                .overlay(glow, alignment: .top)
                .clipped()
                .ignoresSafeArea()
            VStack(spacing: 0) {
                header
                playerCard
                reactionBar
                transcript
                Spacer(minLength: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            MurmurPlaybackController.shared.stop()   // hand off from inline chat playback
            warmUpDeviceLanguage()
        }
        .onDisappear { controller.stop() }
        .sheet(isPresented: $showLanguagePicker) {
            TranslationLanguagePicker(selected: translateLanguageCode) { code, name in
                startTranslation(to: code, name: name)
            }
        }
        .translationTask(translationConfig) { session in
            guard let text = murmur.transcript, !text.isEmpty else { return }
            do {
                // Downloads the language pack on first use, then translates
                // entirely on-device (works offline afterwards).
                try await session.prepareTranslation()
                let response = try await session.translate(text)
                await MainActor.run {
                    translatedText = response.targetText
                    isTranslating = false
                }
            } catch {
                await MainActor.run {
                    translateError = "Couldn't translate — the language may still be downloading. Try again in a moment."
                    isTranslating = false
                }
            }
        }
        .translationTask(warmupConfig) { session in
            // Quietly pre-download the phone's language pack so the default
            // translation is ready and offline.
            try? await session.prepareTranslation()
        }
    }

    private var glow: some View {
        Circle()
            .fill(RadialGradient(colors: [MurmurColor.accent.opacity(0.18), .clear],
                                 center: .center, startRadius: 0, endRadius: 170))
            .frame(width: 360, height: 260)
            .blur(radius: 6)
            .offset(y: -120)
            .allowsHitTesting(false)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            GlassButton(systemName: "chevron.left", tint: MurmurColor.inkPrimary) { dismiss() }
            MurmurAvatar(initial: murmur.avatarInitial, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(murmur.isOutgoing ? "You" : murmur.senderName)
                    .font(MurmurFont.rounded(15, weight: .semibold))
                    .foregroundStyle(MurmurColor.inkPrimary)
                Text(dayTimeLabel)
                    .font(MurmurFont.serifItalic(13))
                    .foregroundStyle(MurmurColor.inkTertiary)
            }
            Spacer()
            GlassButton(systemName: "trash", tint: MurmurColor.inkSecondary) { confirmDelete = true }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .confirmationDialog("Delete this murmur?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteMurmur() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Player card

    private var playerCard: some View {
        VStack(spacing: 18) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    WaveformView(bars: bars, progress: controller.progress,
                                 height: 62, gap: 2.5, minHeight: 4)
                        .frame(maxWidth: .infinity)
                    Rectangle()
                        .fill(.white)
                        .frame(width: 2)
                        .shadow(color: .white.opacity(0.8), radius: 8)
                        .offset(x: geo.size.width * controller.progress - 1)
                        .frame(maxHeight: .infinity)
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    controller.seek(toFraction: max(0, min(1, location.x / geo.size.width)),
                                    url: murmur.audioFileURL)
                }
            }
            .frame(height: 70)

            HStack(spacing: 16) {
                Button {
                    if controller.isPlaying { controller.pause() }
                    else { controller.play(url: murmur.audioFileURL); onPlaybackStarted() }
                } label: {
                    Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(MurmurColor.background)
                        .frame(width: 56, height: 56)
                        .background(MurmurColor.accentGradient, in: Circle())
                        .shadow(color: MurmurColor.accentDeep.opacity(0.4), radius: 12, y: 6)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)

                VStack(spacing: 8) {
                    HStack {
                        Text(timeString(murmur.duration * controller.progress))
                            .font(MurmurFont.rounded(14, weight: .semibold).monospacedDigit())
                            .foregroundStyle(MurmurColor.inkPrimary)
                        Spacer()
                        Text(murmur.durationLabel)
                            .font(MurmurFont.rounded(13).monospacedDigit())
                            .foregroundStyle(MurmurColor.inkTertiary)
                    }
                    progressBar
                }
            }
        }
        .padding(20)
        .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(MurmurColor.hairline, lineWidth: 1))
        .padding(.horizontal, 18)
        .padding(.top, 24)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(MurmurColor.waveInactive).frame(height: 4)
                Capsule().fill(MurmurColor.accentGradient)
                    .frame(width: geo.size.width * controller.progress, height: 4)
                Circle().fill(.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: MurmurColor.accentDeep.opacity(0.8), radius: 5)
                    .offset(x: geo.size.width * controller.progress - 6)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                controller.seek(toFraction: max(0, min(1, value.location.x / geo.size.width)),
                                url: murmur.audioFileURL)
            })
        }
        .frame(height: 14)
    }

    // MARK: Reactions

    private var reactionBar: some View {
        let loved = murmur.reaction == MurmurReaction.heart
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                murmur.reaction = loved ? nil : MurmurReaction.heart
            }
            try? modelContext.save()
            // Sync the heart to the partner's record (and let them know).
            Task {
                await CloudKitService.shared.pushReaction(murmur)
                await SyncBridge.shared.sync()
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: loved ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolEffect(.bounce, value: loved)
                Text(loved ? "Loved" : "Tap to love")
                    .font(MurmurFont.rounded(14.5, weight: .semibold))
            }
            .foregroundStyle(loved ? MurmurColor.background : MurmurColor.inkSecondary)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(loved ? AnyShapeStyle(MurmurColor.accentGradient)
                              : AnyShapeStyle(MurmurColor.surface), in: Capsule())
            .overlay(Capsule().strokeBorder(loved ? Color.clear : MurmurColor.hairline, lineWidth: 1))
            .shadow(color: loved ? MurmurColor.accentDeep.opacity(0.4) : .clear, radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .padding(.horizontal, 18)
    }

    // MARK: Transcript

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showTranscript.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill").font(.system(size: 13)).foregroundStyle(MurmurColor.accent)
                    Text("On-device transcript")
                        .font(MurmurFont.rounded(12, weight: .semibold)).tracking(0.7).textCase(.uppercase)
                        .foregroundStyle(MurmurColor.inkSecondary)
                    Rectangle().fill(MurmurColor.hairline).frame(height: 1)
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MurmurColor.inkTertiary)
                        .rotationEffect(.degrees(showTranscript ? 0 : -90))
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, 14)

            if showTranscript {
                if let text = murmur.transcript, !text.isEmpty {
                    Text(text)
                        .font(MurmurFont.display(18))
                        .lineSpacing(5)
                        .foregroundStyle(MurmurColor.inkPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(MurmurColor.inkTertiary)
                        Text("Transcribed privately on your iPhone · never uploaded")
                            .font(MurmurFont.rounded(11.5)).foregroundStyle(MurmurColor.inkTertiary)
                    }
                    .padding(.top, 16)
                    translateSection
                } else if isTranscribing {
                    HStack(spacing: 10) {
                        ProgressView().tint(MurmurColor.accent)
                        Text("Transcribing on device…")
                            .font(MurmurFont.display(17)).foregroundStyle(MurmurColor.inkSecondary)
                    }
                    .padding(.top, 4)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        if let transcribeError {
                            Text(transcribeError)
                                .font(MurmurFont.rounded(13))
                                .foregroundStyle(MurmurColor.recordingDot)
                        }
                        Button { runTranscription() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "text.bubble.fill").font(.system(size: 14, weight: .semibold))
                                Text(transcribeError == nil ? "Transcribe this murmur" : "Try again")
                                    .font(MurmurFont.rounded(14, weight: .semibold))
                            }
                            .foregroundStyle(MurmurColor.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
            }

            Button { dismiss(); onReply() } label: {
                HStack(spacing: 9) {
                    Image(systemName: "mic.fill").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MurmurColor.accent)
                    Text("Murmur back to \(partner.isEmpty ? "them" : partner)")
                        .font(MurmurFont.rounded(14.5, weight: .semibold))
                        .foregroundStyle(MurmurColor.inkPrimary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(MurmurColor.accentGradientSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(MurmurColor.accent.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 22)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
    }

    // MARK: Helpers

    private var dayTimeLabel: String {
        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(murmur.createdAt) { day = "Today" }
        else if calendar.isDateInYesterday(murmur.createdAt) { day = "Yesterday" }
        else { day = murmur.createdAt.formatted(.dateTime.month(.abbreviated).day()) }
        return "\(day) · \(murmur.createdAt.formatted(.dateTime.hour().minute()))"
    }

    private func timeString(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func deleteMurmur() {
        controller.stop()
        try? FileManager.default.removeItem(at: murmur.audioFileURL)
        modelContext.delete(murmur)
        try? modelContext.save()
        dismiss()
    }

    private func runTranscription() {
        isTranscribing = true
        transcribeError = nil
        Task {
            do {
                let text = try await transcriber.transcribe(fileURL: murmur.audioFileURL)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    transcribeError = "No speech detected in this murmur."
                } else {
                    murmur.transcript = trimmed
                    try? modelContext.save()
                }
            } catch {
                transcribeError = "Couldn't transcribe: \((error as NSError).localizedDescription)"
            }
            isTranscribing = false
        }
    }

    // MARK: Translation (on-device, optional)

    @ViewBuilder
    private var translateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Button { showLanguagePicker = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "globe").font(.system(size: 14, weight: .semibold))
                        Text(translatedText == nil ? "Translate" : "Translate to…")
                            .font(MurmurFont.rounded(14, weight: .semibold))
                    }
                    .foregroundStyle(MurmurColor.accent)
                }
                .buttonStyle(.plain)

                if translatedText != nil || translateError != nil {
                    Button { clearTranslation() } label: {
                        Text("Hide").font(MurmurFont.rounded(14, weight: .semibold))
                            .foregroundStyle(MurmurColor.inkTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if isTranslating {
                HStack(spacing: 10) {
                    ProgressView().tint(MurmurColor.accent)
                    Text("Translating on device…")
                        .font(MurmurFont.rounded(13)).foregroundStyle(MurmurColor.inkSecondary)
                }
            } else if let translateError {
                Text(translateError)
                    .font(MurmurFont.rounded(13)).foregroundStyle(MurmurColor.recordingDot)
            } else if let translatedText {
                VStack(alignment: .leading, spacing: 10) {
                    Text(translatedText)
                        .font(MurmurFont.display(18))
                        .lineSpacing(5)
                        .foregroundStyle(MurmurColor.inkPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    HStack(spacing: 7) {
                        Image(systemName: "globe").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(MurmurColor.inkTertiary)
                        Text("Translated privately on your iPhone\(translatedLanguage.map { " · \($0)" } ?? "")")
                            .font(MurmurFont.rounded(11.5)).foregroundStyle(MurmurColor.inkTertiary)
                    }
                }
                .padding(14)
                .background(MurmurColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(MurmurColor.hairline, lineWidth: 1))
            }
        }
        .padding(.top, 14)
    }

    private func startTranslation(to code: String, name: String) {
        translatedText = nil
        translateError = nil
        translatedLanguage = name
        translateLanguageCode = code
        isTranslating = true
        // A fresh configuration each time re-runs the .translationTask.
        translationConfig = TranslationSession.Configuration(source: nil,
                                                             target: Locale.Language(identifier: code))
    }

    private func clearTranslation() {
        translatedText = nil
        translateError = nil
        translatedLanguage = nil
        translateLanguageCode = nil
        isTranslating = false
        translationConfig = nil
    }

    /// Pre-downloads the phone's language pack (paired with the most likely other
    /// language) so the default translation is ready and works offline. Runs at
    /// most once per app launch, and only if there's something to translate.
    private func warmUpDeviceLanguage() {
        guard !Self.didWarmUp,
              let text = murmur.transcript, !text.isEmpty else { return }
        Self.didWarmUp = true
        let device = Locale.current.language.languageCode?.identifier ?? "en"
        let counterpart = (device == "en") ? "es" : "en"
        warmupConfig = TranslationSession.Configuration(
            source: Locale.Language(identifier: counterpart),
            target: Locale.Language(identifier: device))
    }
}

// MARK: - Playback controller

@MainActor
final class AudioPlayerController: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func play(url: URL) {
        if player == nil {
            configureSession()
            player = try? AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
        }
        player?.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
    }

    func seek(toFraction fraction: Double, url: URL) {
        if player == nil { play(url: url); pause() }
        guard let player else { return }
        player.currentTime = fraction * player.duration
        progress = fraction
    }

    func stop() {
        player?.stop(); player = nil
        isPlaying = false; progress = 0
        timer?.invalidate(); timer = nil
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

extension AudioPlayerController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 0
            self.timer?.invalidate()
        }
    }
}

// MARK: - Translation language picker

/// A searchable language chooser styled like the app. The phone's language is
/// pinned at the top and labelled, with the languages we use suggested next.
struct TranslationLanguagePicker: View {
    var selected: String?
    var onSelect: (_ code: String, _ name: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    /// Languages Apple's on-device Translation framework supports.
    private static let allCodes = [
        "ar", "zh-Hans", "zh-Hant", "nl", "en", "fr", "de", "hi", "id", "it",
        "ja", "ko", "pl", "pt", "ru", "es", "th", "tr", "uk", "vi"
    ]

    private var deviceCode: String { Locale.current.language.languageCode?.identifier ?? "en" }

    private func nativeName(_ code: String) -> String {
        Locale(identifier: code).localizedString(forLanguageCode: code)?.localizedCapitalized ?? code
    }
    private func englishName(_ code: String) -> String {
        Locale(identifier: "en").localizedString(forLanguageCode: code)?.localizedCapitalized ?? code
    }

    private func matches(_ code: String) -> Bool {
        guard !search.isEmpty else { return true }
        let q = search.lowercased()
        return nativeName(code).lowercased().contains(q)
            || englishName(code).lowercased().contains(q)
            || code.lowercased().contains(q)
    }

    private var suggested: [String] {
        var seen = Set<String>()
        return [deviceCode, "en", "es", "ar"].filter {
            Self.allCodes.contains($0) && seen.insert($0).inserted && matches($0)
        }
    }
    private var others: [String] {
        Self.allCodes.filter { !suggested.contains($0) && matches($0) }
            .sorted { englishName($0) < englishName($1) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !suggested.isEmpty {
                    Section("Suggested") {
                        ForEach(suggested, id: \.self) { row($0, isDevice: $0 == deviceCode) }
                    }
                }
                if !others.isEmpty {
                    Section("All languages") {
                        ForEach(others, id: \.self) { row($0, isDevice: false) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(MurmurColor.background.ignoresSafeArea())
            .navigationTitle("Translate to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .searchable(text: $search, prompt: "Search languages")
        }
        .preferredColorScheme(.dark)
    }

    private func row(_ code: String, isDevice: Bool) -> some View {
        Button {
            onSelect(code, nativeName(code))
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(nativeName(code))
                            .font(MurmurFont.rounded(16, weight: .medium))
                            .foregroundStyle(MurmurColor.inkPrimary)
                        if isDevice {
                            Text("Your language")
                                .font(MurmurFont.rounded(10, weight: .semibold))
                                .foregroundStyle(MurmurColor.accent)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(MurmurColor.accent.opacity(0.15), in: Capsule())
                        }
                    }
                    if englishName(code) != nativeName(code) {
                        Text(englishName(code))
                            .font(MurmurFont.rounded(12))
                            .foregroundStyle(MurmurColor.inkTertiary)
                    }
                }
                Spacer()
                if selected == code {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MurmurColor.accent)
                }
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(MurmurColor.surface)
    }
}
