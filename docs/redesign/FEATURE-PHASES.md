# Skinalyze — Build Phases for the Feature Backlog

> How the backlog in [FEATURES.md](FEATURES.md) gets built, in order. Each phase ships something usable on its own,
> names what it needs from the owner, and says exactly how it is checked before it reaches the owner's phone.
> IDs (PI2, E1, M8 …) refer to FEATURES.md. Update the status line of a phase when it starts and when it ships, and
> tick the matching items in FEATURES.md.

**Status key:** ☐ not started · ◐ in progress · ☑ shipped (with commit)

## How every phase is checked (no exceptions)

These come from mistakes already made on this project; they are the definition of "done".

1. **Logic is test-first** in SkinalyzeKit (Swift Testing): the rule is written as a failing test, then built.
2. **Screens are looked at, not assumed**: the visual tour (`VisualTourUITests`) is extended to reach every new
   screen, run in light and dark, and the screenshots are read before anything is installed.
3. **Checked with what the phone actually uses**: same renderer, same code path. A check on different data or a
   different renderer does not count.
4. **Camera, depth, motion, notifications, purchases, widgets on the lock screen** cannot be proven in the
   Simulator — they are marked "needs owner's phone" and are not called done until the owner confirms.
5. Full suite green (kit + app unit + UI), copy lint at 0, then install, then commit locally. **Never push.**
6. Every new string ships in English and Indonesian — `scripts/check_strings.sh` must pass.
7. CloudKit schema changes are additive only (new optional fields / new models; never rename or delete).

---

## Phase 0 — Close out what is open  ☑ (2026-11-19)

**Why first:** new features should not be stacked on unconfirmed work.

- [x] Owner confirmed the fused 3D scan (real sides) works on the phone.
- [x] The finished card now drops into the Deck after the sticker sticks, then the result opens.
- [x] Dead V1 screens deleted (Today, Search, the old timeline grid, the old capture screen). The pieces still in
  use moved to their own files: `ScanScreens.swift` (review, messages, shutter sound), `TrendChart.swift`,
  `Avatar.swift`, `ProductDetailView.swift`.
- [x] Two things the redesign had dropped by accident are back: the shutter sound on each capture, and the daily
  routine check-off (now on the Shelf).
- [x] Indonesian for **every** string, not only the new ones: the catalog went from 101 to 328 strings (321
  translated, 7 marked do-not-translate). `scripts/check_strings.sh` extracts strings with the compiler, syncs the
  catalog and fails if any lacks Indonesian; it runs as part of `scripts/test.sh`.
- [x] The debug-only raw 3D dump stays (debug builds only) but keeps just the three most recent scans.

**Still open from this phase:** nothing.

---

## Phase 1 — Streaks and Pimpi on the Mirror  ☑ (2026-11-19, one item deferred)
**Ships:** E1, E2, E3, E4, PI2, part of PI5 · **Size:** medium

**What the user gets:** Pimpi stands beside the shutter on the Mirror with a flame showing the routine streak; its
mood follows the streaks. Tapping it opens the streak sheet: routine streak (days), scan streak (weeks), freezes,
weekends-off and repair. Milestones (7 / 30 / 100 days; 4 / 12 / 26 / 52 weeks) open the sheet once with Pimpi excited.

**Built**
- [x] `StreakEngine` (SkinalyzeKit, 13 tests): streaks are derived from history — routine done-days and scan dates —
  plus a freeze ledger. Covers local-midnight day change, time-zone travel, weekends-off, automatic freezes (never
  wasted on a gap they can't bridge), repair (yesterday only, once per 30 days), milestones, earning a freeze every
  7 days (cap 2).
- [x] `PimpiMoodEngine` (SkinalyzeKit, tested): mood from streak state and time of day only — never skin results.
  A lapsed *scan* habit makes Pimpi curious, not sad.
- [x] `EngagementStore` (4 tests) + `EngagementModel`: done-days kept separately from the routine log (which only
  holds ~2 months, so a 100-day streak was uncountable); existing check-offs imported once; freeze ledger; settings.
- [x] Mirror: `PimpiStreakBadge` beside the ring; `StreakSheet`. Checked in light and dark for done-today and for
  a broken streak; the other states are covered by the engine tests and the Pimpi mood gallery.
- [x] `Pimpi.swift` moved to the shared sources (widgets can use it in Phase 2). New strings in EN + ID.

**Deferred (still open):**
- [ ] **Synced storage.** Streak inputs (done-days, freeze ledger) live in on-device settings, like the routine log
  they come from. They do not survive a reinstall and do not sync between devices. Moving them (and the routine
  log) to an additive SwiftData/CloudKit model is its own careful step because it changes the synced schema — do it
  before Phase 9 (social) at the latest.

**Needs from owner:** try it on the phone — check off a routine step on the Shelf and watch the flame; say if
weekly is the right scan rhythm.

---

## Phase 2 — Pimpi widget and Pimpi's notifications  ☑
**Ships:** PI3, PI4 (G11 moved out — see below) · **Size:** small–medium

**Shipped (2026-11-19):**
- [x] Shared engagement snapshot in the App Group (`EngagementSnapshot`, tolerant decoding, tested).
- [x] Pimpi widget: small, lock-screen circular and rectangular. Mood and streak change through the day without
  opening the app. Every family looked at in light and dark in the Simulator (`-pimpiWidgetGallery YES` draws the
  same view the widget uses).
- [x] `ReminderPlanner` — pure, tested: at most one notification a day, stops after three in a row with no visit.
  "Reminders from Pimpi" switch in Profile replaces the old scan reminder.
- [x] String catalog moved to `SharedSources/Localization` so app, widget and share extension share one file;
  `check_strings.sh` covers all three. EN + ID complete.

**Still open:**
- [ ] **G11 sticker-card widget** — not built; it needs a small face-free card image written to the App Group.
  Build it with Phase 3, which makes that card image anyway.
- [ ] **Owner's phone:** add the widget to the home and lock screen; turn reminders on and confirm one arrives.

**Build**
1. Extend the widget snapshot (App Group) with streak and Pimpi mood; additive, old snapshots still decode (tested).
2. Widgets: Pimpi mood + streak (small, lock-screen circular and rectangular) and the sticker-card widget.
   Tinted / clear rendering modes.
3. Notification schedule as a pure, tested function: (streak state, last scan, quiet hours, user setting) → at
   most one notification a day, gentle escalation, stops after repeated ignores. Extends the existing reminders.
4. Copy in Pimpi's voice, EN + ID, through the copy lint: never about skin condition, never guilt about results.

**Done when:** schedule tests green; widget previews for every family checked.
**Needs owner's phone:** lock-screen widgets and real notification delivery.
**Risk:** notification fatigue — the cap and back-off are part of the tested rule, not a later tweak.

---

## Phase 3 — Share cards  ☑
**Ships:** G2, G4, G5, G11, the E4 streak card · **Size:** medium

**Shipped (2026-11-19):**
- [x] One pipeline (`Features/Share`): card view → image at fixed sizes (story 1080×1920, post 1080×1350, square
  1080×1080, tested) → system share sheet. Nothing is uploaded by the app.
- [x] Skin card with **Hide my face** (asked on every share, never remembered). The hidden version is built from the
  sticker's outline only; a test proves no photo pixel survives, and the card view never receives the photo.
- [x] Product verdict card (same rule-based verdict as the page; the disclaimer line is never truncated).
- [x] Earlier / later card from the eye-aligned Compare photos.
- [x] Streak card from the Streaks sheet (two days or more).
- [x] Watermark is one switch (`ShareCardPolicy`), on for everyone until Phase 5.
- [x] G11: "Skin card" home-screen widget — mood colour, index and Pimpi, no photo.
- [x] All 15 exports (5 cards × 3 shapes) opened and checked from the Simulator (`-shareCardDump <folder>`);
  share sheet covered by a UI test. EN + ID.

**Still open:**
- [ ] **Owner's phone:** the Simulator cannot cut out a face, so the real sticker and its hidden outline were only
  seen as a rounded photo there — share one real scan both ways and check it. Add the Skin card widget.
- [ ] Moving exports (tilt-shimmer card video, before/after slider video) come with Phase 4's video writer.

**Build**
1. One share-rendering pipeline: a SwiftUI card → image at fixed export sizes (story 9:16, square, 4:5).
2. Skin card export, with **"hide my face"** (sticker silhouette + stats only), chosen by the user on every share.
3. Product verdict card ("Is it good for me?").
4. Before/after export from the eye-aligned Compare.
5. Watermark as a single switch in the pipeline (always on until Phase 5 decides who sees it).
6. System share sheet; nothing is uploaded by the app.

**Done when:** exported images for each size and each card are opened and checked (faces aligned, text not
clipped, large text sizes do not break the card); hide-face export verified to contain no face pixels.
**Risk:** privacy — the hide-face path gets its own test.

---

## Phase 4 — Glow-up reel and 3D turntable  ☑
**Ships:** G1, G3 · **Size:** large · **Start with a spike**

**Shipped (2026-11-19):**
- [x] Spike passed: RealityKit's offscreen renderer (`RealityRenderer`) draws the same head entity the viewer shows,
  so the turntable ships now rather than later.
- [x] Glow-up reel (Deck → film button): eye-aligned stickers oldest → newest, index counting, colour shifting,
  6–12 s, 1080×1920 at 30 fps. Timing is `ReelPlan` (tested); more than 16 scans are sampled evenly.
  Hide-my-face carries over (outlines only).
- [x] 3D turntable (scan result → Share → 3D turntable): front → each side → front within the captured turn range,
  6 s, loops. `TurntablePlan` tested. Spot pins are left out of the video.
- [x] Progress shown while making; closing the sheet cancels; nothing is uploaded.
- [x] Checked frame by frame in the Simulator: reel with 2 scans and with 6, reel with the face hidden, turntable
  on a real head mesh captured from the phone. Reel and turntable each covered by a UI test.
- [x] Fixed on the way: sleepy Pimpi's "z" was text and failed the accessibility audit at night; now drawn.

**Still open:**
- [ ] **Owner's phone:** make one reel and one turntable from real scans (the Simulator cannot cut out a face, so
  real stickers were not seen in the reel); check export time; post one to TikTok / Reels.
- [ ] Frames are drawn on the main thread with a pause between each (the encoder runs off it). Fast in the
  Simulator (2–5 s); if the phone stutters while making a video, move the drawing to Core Graphics.
- [ ] A reel with 10+ real scans has only been covered by the timing tests, not viewed.
- [ ] Turntable is free until Phase 5 puts it behind Pro; watermark stays on for everyone until then.

**Build**
1. **Spike first (time-boxed):** offscreen rendering of the 3D head to video frames, and writing a video file
   from SwiftUI-rendered frames. If the 3D offscreen route is not reliable on device, the turntable ships later
   and the reel (2D) ships alone.
2. Reel: sticker cards oldest → newest, registered by the eyes (reuse `FaceAligner`), index counting, band colour
   shifting; 6–12 seconds; 9:16.
3. Turntable: the fused head rotating within its captured turn range.
4. Export off the main thread with progress and cancel; hide-face option carries over.

**Done when:** exported videos are opened frame-by-frame (as done for the sticker moment) for at least: 2 scans,
10 scans, a scan with no 3D. **Needs owner's phone:** export time and quality on device; posting to TikTok/Reels.
**Risk:** highest technical risk in the backlog — hence the spike and the fallback.

---

## Phase 5 — Paywall  ☐
**Ships:** M1, M2, M3, M4, M5, M6, M8 · **Size:** large

**Build**
1. `Entitlements` in SkinalyzeKit: one tested place that answers "is this allowed?" — free limits as named
   constants (1 saved scan/day, 7-scan history, 3 product checks/month), Pro unlimited. Until this phase everything
   is free; from here every gated feature asks this one place.
2. Scan-limit rule (M8), tested: only analysed-and-saved scans count; cancelled / retaken / failed do not; resets
   at local midnight; time-zone and clock-change cases.
3. StoreKit 2: weekly, monthly, annual (7-day trial), optional lifetime; local StoreKit configuration file so the
   whole flow is testable without App Store Connect; restore purchases; subscription status across devices.
4. Paywall screen (Pimpi-led) and the triggers: after the first sticker moment, second scan the same day, 8th
   scan in history, first 3D turn, export without watermark. Never before the first scan result.
5. Existing users: decide and implement what current App Store users keep (see owner questions).

**Done when:** entitlement and limit tests green; purchase, trial, restore, expiry and refund walked through in the
StoreKit test environment; tour screenshots of the paywall in light/dark and at large text sizes.
**Needs owner's phone:** a sandbox purchase end to end.
**Needs from owner:** price points (IDR and others), whether lifetime ships at launch, product setup in App Store
Connect, and **what existing users get** (recommended: everyone who installed before the paywall keeps their full
history and 3D as it is today).
**Risk:** App Review — clear terms, restore button, no dark patterns; a rejected paywall delays everything.

---

## Phase 6 — Quests, glow points, chests, badges, outfits  ☐
**Ships:** E5, E6, E7, E8, E13, PI5, PI6 · **Size:** medium–large

**Build**
1. `QuestEngine` and points ledger in SkinalyzeKit, tested: three daily quests chosen from what the user can
   actually do today; points for effort only; a day's quests cannot be farmed by changing the clock.
2. Additive models: quest progress, points ledger, unlocks.
3. Chest opening moment; rewards are cosmetic only (card themes, holo styles, Pimpi outfits/hats); badge shelf.
4. Pimpi outfits: accessories drawn in the same vector style; Pro sets gated through `Entitlements`.

**Done when:** engine tests green (including clock tampering); tour shows quest list, chest, badge shelf, outfits.
**Risk:** scope creep — ship three quest types and a small reward set first.

---

## Phase 7 — Skin School  ☐
**Ships:** E9, E10 · **Size:** medium (code) + content work

**Build**
1. Lesson format as data (title, 3–5 cards, two quiz questions, sources) so lessons are added without code.
2. Lesson player, quiz, XP; lesson path with units; first units free, the rest through `Entitlements`.
3. First ~10 lessons, EN + ID, each with listed sources, through the copy lint.

**Done when:** every lesson renders at all text sizes; quiz scoring tested; sources visible.
**Needs from owner:** topic list and **sign-off on wording** — this is the feature closest to health advice, so
nothing ships without it.

---

## Phase 8 — Spot timeline and zone heat map  ☐
**Ships:** P1, P2 · **Size:** large

**Build**
1. Matching the same spot across scans (kit, tested): detections registered into the fused head's coordinates or
   the eye-aligned frame, matched by position with a tolerance; states: appeared, still there, fading, gone.
2. Spot timeline from a tapped pin.
3. Heat map of zone activity over time on the 3D head, scrubbable by date.

**Done when:** matching tested on synthetic sequences and replayed on the owner's real scans offline before any
UI is trusted. **Needs owner's phone:** several real scans over time.
**Risk:** false matches look like wrong claims — wording stays "seen in the same place", and low-confidence
matches are not shown.

---

## Phase 9 — Recaps, journey and social  ☐
**Ships:** E11, E12, E14, E15, E16, E17, G6, G8 · **Size:** large (social needs a backend decision)

- Weekly and monthly recap, Skin Wrapped, journey map: local, built on what Phases 1–8 already store.
- Friend streaks, leagues, referral: need data to leave the device (streak and points only). **Decision needed
  before any work:** CloudKit sharing/public database vs. a small backend. No photos, ever.

**Needs from owner:** go/no-go on social once the local parts are live and there is usage data.

---

## Phase 10 — Product utilities (pick by demand)  ☐
**Ships (candidates):** P3–P14, G7, G9, G10

Trigger journal and HealthKit correlation (P3, P4), routine builder (P5), patch-test timer (P6), expiry tracker
(P7), barcode scan (P8 — needs a data source), dupe finder (P9), UV nudge (P10), dermatologist pack (P11),
scan-quality coach (P12), vault (P13), Watch / Shortcuts (P14), routine cards (G7), creator kit (G9), marketplace
share entry (G10). Ordered after launch by what users actually ask for; each gets its own short phase entry here
when picked.

---

## Order at a glance

| Phase | Ships | Depends on | Owner input needed |
|---|---|---|---|
| 0 Close out | open items | — | confirm 3D on phone |
| 1 Streaks + Pimpi on Mirror | E1–E4, PI2 | 0 | scan rhythm (default weekly) |
| 2 Widget + notifications | PI3, PI4 | 1 | test on phone |
| 3 Share cards | G2, G4, G5 | — (can run alongside 1–2) | — |
| 4 Reel + turntable | G1, G3 | 3 | test on phone |
| 5 Paywall | M1–M6, M8 | 3 (watermark), ideally 4 | prices, App Store Connect, existing-user policy |
| 6 Quests + rewards | E5–E8, E13, PI5, PI6 | 1, 5 (Pro sets) | — |
| 7 Skin School | E9, E10 | 5 | topics + wording sign-off |
| 8 Spot timeline + heat map | P1, P2 | 0 (confirmed 3D), 5 | scans over time |
| 9 Recaps + social | E11–E17, G6, G8 | 1, 6 | backend decision, go/no-go |
| 10 Utilities | P3–P14, G7, G9, G10 | varies | pick by demand |
