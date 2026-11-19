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

## Phase 1 — Streaks and Pimpi on the Mirror  ☐
**Ships:** E1, E2, E3, E4, PI2, part of PI5 · **Size:** medium

**What the user gets:** a scan streak (weekly rhythm) and a daily routine streak, a flame on the Mirror, streak
freeze / weekend-off / 24-hour repair, milestone celebrations, and Pimpi on the Mirror whose mood follows it all.

**Build**
1. `StreakEngine` in SkinalyzeKit — pure and tested first. Streaks are **derived** from history (scan dates,
   routine check-off days) plus a small ledger of freezes, so they can never drift out of sync with the data.
   Cases to test: weekly scan rhythm, day boundaries at local midnight, time-zone travel, weekend-off, a freeze
   covering a missed day, repair inside 24 h, repair refused after 24 h, milestones at 7 / 30 / 100.
2. `PimpiMoodEngine` in SkinalyzeKit — pure and tested: (streak state, scanned today?, scan due?, streak at risk?,
   just broke?) → mood. Mood never depends on skin results (FEATURES rule 1).
3. Routine check-offs currently live in `UserDefaults` on one device. Add an additive SwiftData model for
   check-off days so the routine streak survives reinstall and syncs; import existing check-offs once (tested,
   idempotent, like the legacy scan migration).
4. Freeze ledger: additive SwiftData model (earned / used / date).
5. Mirror: Pimpi and the streak flame in the home chrome — must stay uncluttered (index, avatar, shutter, dock,
   plus one Pimpi + flame element). Milestone moment with Pimpi `excited`.
6. Move `Pimpi.swift` to the shared sources so widgets can use it in Phase 2.

**Done when:** engine tests green; tour screenshots show Pimpi in each streak state in light and dark; streak
survives relaunch in the Simulator. **Needs owner's phone:** nothing new (no camera/motion involved).
**Needs from owner:** confirm weekly as the scan rhythm (default if no answer).
**Risk:** clutter on the Mirror — settle the layout from screenshots before wiring behaviour.

---

## Phase 2 — Pimpi widget and Pimpi's notifications  ☐
**Ships:** PI3, PI4, G11 · **Size:** small–medium

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

## Phase 3 — Share cards  ☐
**Ships:** G2, G4, G5 · **Size:** medium

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

## Phase 4 — Glow-up reel and 3D turntable  ☐
**Ships:** G1, G3 · **Size:** large · **Start with a spike**

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
| 2 Widget + notifications | PI3, PI4, G11 | 1 | test on phone |
| 3 Share cards | G2, G4, G5 | — (can run alongside 1–2) | — |
| 4 Reel + turntable | G1, G3 | 3 | test on phone |
| 5 Paywall | M1–M6, M8 | 3 (watermark), ideally 4 | prices, App Store Connect, existing-user policy |
| 6 Quests + rewards | E5–E8, E13, PI5, PI6 | 1, 5 (Pro sets) | — |
| 7 Skin School | E9, E10 | 5 | topics + wording sign-off |
| 8 Spot timeline + heat map | P1, P2 | 0 (confirmed 3D), 5 | scans over time |
| 9 Recaps + social | E11–E17, G6, G8 | 1, 6 | backend decision, go/no-go |
| 10 Utilities | P3–P14, G7, G9, G10 | varies | pick by demand |
