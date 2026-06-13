# Murmur — CLAUDE.md

## What is this app?

Murmur is a private, two-person async voice messaging iOS app built for long-distance couples.
No group chats. No teams. No workspace. Just two people leaving each other voice messages
("murmurs") across time zones — whenever they feel like it, without the pressure of a live call.

This is a personal project by Vane (Madrid) for her and Manal (San Francisco / Boston).

---

## The problem it solves

Live calls across time zones are hard to coordinate. Voice notes in WhatsApp feel like an
afterthought buried in a chat. Murmur makes async voice the *primary* experience — tap, speak,
done. The other person listens when they're ready.

---

## Tech stack

- **Language**: Swift / SwiftUI
- **Minimum target**: iOS 26+ (raised from 17 to use SpeechAnalyzer on-device)
- **Audio recording**: AVAudioEngine or AVAudioRecorder
- **Transcription**: Apple SpeechAnalyzer (on-device, private) — same pattern as Parley
- **Storage**: SwiftData for local persistence
- **Backend / sync**: CloudKit (private iCloud container) — simplest path for two-device sync
  with zero backend infrastructure
- **Architecture**: MVVM

---

## Core features (MVP)

### 1. Record a Murmur
- Big, obvious record button on the home screen — tap to start, tap to stop
- No login wall, no friction
- Waveform visualizer while recording (AVAudioEngine amplitude)
- Max duration: 10 minutes (auto-saves at the cap; long enough for a voice letter)

### 2. Murmur inbox / timeline
- Chronological list of murmurs (sent + received), newest first
- Each row shows: sender avatar initial, timestamp, duration, played/unplayed indicator
- Tap to play inline with a simple waveform progress bar
- Swipe to delete (with confirmation)

### 3. Auto-transcription
- On-device transcription after recording using SpeechAnalyzer
- Transcript visible below the waveform player (collapsible)
- Supports Spanish and English (the partners speak both)
- Optional on-device translation (Apple Translation framework): a "Translate"
  control under the transcript translates it to a chosen language, privately
  and offline once the language pack is downloaded. Transcript text is also
  selectable so a single part can be translated via the system callout.

### 4. Push notifications
- CloudKit silent push when a new murmur arrives
- Local notification: "Manal left you a murmur" (hardcoded partner name for MVP)

### 5. Simple profile setup (first launch only)
- Enter your name
- Pick a color (used as your avatar — no photos needed for MVP)
- Enter partner's iCloud email to connect

---

## Design language

- **Aesthetic**: Warm, intimate, minimal. Not a productivity tool.
- **Background**: Deep warm dark (#1A1714) — like candlelight dark mode
- **Accent**: Dusty rose / terracotta (#C97D6E) for record button and unplayed indicators
- **Typography**: 
  - Display: "New York" (Apple serif, feels personal, like handwriting's dignified cousin)
  - Body/UI: "SF Pro Rounded" (soft, friendly)
- **Record button**: Large circle, center screen, pulsing ring animation while recording
- **No emojis anywhere** — use SF Symbols only
- **No tabbar** — single screen with a slide-up panel for settings

---

## What this is NOT (out of scope for MVP)

- No group messaging
- No video
- No reactions or emoji responses (keep it v2)
- No web version
- No Android
- No server — CloudKit only

---

## File / folder structure to create

```
Murmur/
├── MurmurApp.swift
├── CLAUDE.md  ← this file
├── Models/
│   └── Murmur.swift          # SwiftData model
├── ViewModels/
│   ├── MurmurListViewModel.swift
│   └── RecordViewModel.swift
├── Views/
│   ├── ContentView.swift     # Main screen / inbox
│   ├── RecordView.swift      # Recording sheet
│   ├── PlayerView.swift      # Inline waveform player
│   └── OnboardingView.swift  # First launch setup
├── Services/
│   ├── AudioService.swift    # AVAudioEngine wrapper
│   ├── TranscriptionService.swift  # SpeechAnalyzer wrapper
│   └── CloudKitService.swift # Sync logic
└── Assets.xcassets/
```

---

## Key implementation notes for Claude Code

- Use `@Model` (SwiftData) for `Murmur` — fields: id, senderName, audioFileURL (local),
  transcript (optional String), duration, createdAt, isPlayed, isOutgoing
- Audio files stored in app's Documents directory, filename = UUID
- CloudKit: use `CKContainer.default()` with a `privateCloudDatabase` + `sharedCloudDatabase`
  (shared DB for the partner's murmurs)
- SpeechAnalyzer: wrap in a Task, update transcript asynchronously after recording stops
- Do NOT use any third-party dependencies — pure Apple frameworks only
- All strings in English for MVP

---

## Vane's working style notes

- She directs, Claude codes. Explain what you're doing but don't ask permission for small decisions.
- Prefer explicit, readable code over clever one-liners.
- When something is complex (CloudKit sharing setup), explain the "why" briefly before the code.
- No emojis in code comments either.
- Commit-sized steps: get one feature working before starting the next.
- If something is iOS 18+ only, flag it.
