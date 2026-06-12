# Murmur — App Store Submission Packet

Everything you need to fill in App Store Connect, plus the order to do it in.
Copy/paste the fields; the checklist at the bottom is the path through the
bureaucracy.

---

## 1. The name problem (do this first)

"Murmur" is already taken as an App Store **listing name**. That's fine — the
name on the home screen (the icon label) can still be **Murmur**; only the App
Store *listing* name must be unique. Pick one:

- **Murmur — for two**  ← recommended
- Murmur: Voice for Two
- Murmur · Voice Letters
- Murmur Two

The icon/display name stays "Murmur" (it's set by the app, not the listing).

---

## 2. Listing copy (paste into App Store Connect)

**Subtitle** (max 30 chars):
> Voice messages for two

**Promotional text** (max 170 chars, editable anytime without review):
> Tap, speak, done. Murmur is a private place for two people to leave each other
> voice messages across time zones — no calls to schedule, no chat to wade through.

**Description:**
> Murmur is a quiet, private place for two people to leave each other voice
> messages — across time zones, whenever the feeling strikes.
>
> No group chats. No feeds. No pressure of a live call. Just you and one person,
> murmuring back and forth in your own voices.
>
> • Tap once to record, tap to send — up to ten minutes per murmur.
> • Hear each other on a warm, simple timeline with playback you can scrub.
> • Every murmur is transcribed privately on your device, in English or Spanish,
>   so you can read it when you can't listen.
> • Send a heart when something lands just right.
> • See your partner's local time, so you always know if they're awake.
>
> Built for privacy from the ground up: your murmurs live in your own iCloud and
> are shared only with the one person you invite. No servers, no ads, no
> tracking, nothing collected. Transcription happens entirely on your iPhone.
>
> For long-distance couples, for two people who miss each other's voices.

**Keywords** (max 100 chars, comma-separated, no spaces):
> voice,message,couple,long distance,private,voice note,partner,async,relationship,intimate

**Category:** Primary — Lifestyle. Secondary — Social Networking.

**Support URL:** a page you control (a GitHub repo README or a simple site).
**Marketing URL:** optional.

---

## 3. Privacy ("App Privacy" questionnaire)

Murmur can honestly answer **Data Not Collected** — a real selling point.

- Data collection: **No, we do not collect data from this app.**
- Reasoning to keep in mind if asked: murmurs and transcripts live in the
  user's *own* private iCloud (CloudKit), which the developer cannot access;
  transcription is on-device; there are no analytics or third-party SDKs.
- **Privacy Policy URL (required):** host `PRIVACY.md` from this repo. Easiest
  path: enable **GitHub Pages** on the repo (Settings → Pages), then the URL is
  e.g. `https://lessane-land.github.io/murmur/PRIVACY` — or just link the raw
  file. Any reachable URL with the policy text is accepted.

---

## 4. App Review notes (paste into "Notes" for the reviewer)

> Murmur is a private 1-to-1 voice messaging app. No account or login is needed.
>
> You can fully evaluate the core app on a SINGLE device:
> 1. Complete the short onboarding (enter any name; a partner name can be
>    anything — pairing is optional).
> 2. On the main screen, tap the large record button, speak for a few seconds,
>    tap again to stop. The murmur appears in the timeline.
> 3. Tap it to open the player: play it back, and read the transcript that is
>    generated on-device.
>
> The partner sync feature uses Apple CloudKit sharing and requires a second
> iCloud account on a second device; it is an enhancement on top of the core
> experience above and is not required to see the app function.
>
> Microphone is used only while recording. Speech Recognition runs on-device to
> transcribe; no audio leaves the phone.

**Age rating:** answer the questionnaire honestly; expect **4+** (no
objectionable content; all content is private 1-to-1 between two known people).

**Sign-in required:** No. **Demo account:** not needed (see notes above).

---

## 5. Export compliance

Already handled in the project: `ITSAppUsesNonExemptEncryption = NO` is set, so
you won't be asked the encryption question on every upload. (Murmur only uses
standard Apple transport/CloudKit encryption, which is exempt.)

---

## 6. THE critical gotcha — deploy CloudKit to Production

Your sync has been tested in the CloudKit **Development** environment. App Store
builds use the **Production** environment. If you don't promote the schema,
**sync will silently do nothing for real users.**

In the CloudKit Console (icloud.developer.apple.com) for the Murmur container:
1. Confirm the record type `Murmur` and the **`recordName` Queryable index**
   exist in Development.
2. Click **Deploy Schema to Production** and confirm.
3. Do this BEFORE submitting (and again any time the schema changes).

---

## 7. Screenshots

You need screenshots for the 6.9" iPhone size (and 6.5" if prompted). Easiest:
run the app in the iPhone 16/17 Pro Max simulator, record a couple of murmurs so
the timeline looks alive, and use Simulator → File → Save Screen (⌘S). Good
shots: the timeline with a few murmurs, the player with a transcript, and the
record screen mid-recording.

---

## Submission checklist (in order)

- [ ] Apple Developer Program active (you already have a team — done).
- [ ] CloudKit schema + `recordName` index **deployed to Production** (§6).
- [ ] In App Store Connect → My Apps → **＋** → New App: pick a unique listing
      name (§1), bundle ID = your app's, primary language, SKU (any string).
- [ ] Fill Subtitle, Description, Keywords, Promotional text (§2).
- [ ] Upload screenshots (§7) and the 1024px icon (already in the project).
- [ ] Complete **App Privacy** = Data Not Collected + Privacy Policy URL (§3).
- [ ] Set price = **Free**; pick availability (countries).
- [ ] Answer Age Rating questionnaire (§4).
- [ ] In Xcode: set a Version (e.g. 1.0) and Build number, select "Any iOS
      Device", **Product → Archive**, then **Distribute App → App Store Connect**.
- [ ] In App Store Connect, attach the uploaded build to the version.
- [ ] Paste the **App Review notes** (§4); export compliance is already set (§5).
- [ ] **Submit for Review.**

First review for a new app usually takes ~24–48h. If it's rejected, it's almost
always a small fixable thing (a missing field or a reviewer question) — not a
restart.
