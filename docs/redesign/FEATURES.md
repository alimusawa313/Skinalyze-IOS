# Skinalyze — Feature Tracker (growth, engagement, product, paywall)

> One list of everything we have agreed to build after the V2 "Mirror" redesign and the 3D scan work, so nothing
> gets lost. Tick items as they ship. Owner approved the direction and the Pimpi mascot on 2026-11-19.
>
> Related: [FEATURE-PHASES.md](FEATURE-PHASES.md) (how this backlog gets built) · [PLAN.md](PLAN.md) (original redesign plan) ·
> [PHASES.md](PHASES.md) (redesign build status) ·
> [V2-BOLD.md](V2-BOLD.md) (Mirror spec) · project rules in [CLAUDE.md](../../CLAUDE.md).

**How to read this**

- `[ ]` not started · `[~]` in progress · `[x]` shipped (add the commit).
- **Free / Pro** says which side of the paywall a feature sits on.
- IDs (E1, G3, …) are stable — use them in commits and conversations.

---

## 0. Rules every feature must respect

1. **Score effort, never skin.** Streaks, points, quests, leagues and rewards count showing up and learning — never
   breakout numbers. A bad skin week must not cost the user anything.
2. **Tracker, not diagnosis.** No medical claims; correlations are worded "coincided with", never "caused"
   (App Review 1.4.1 history — the copy lint gates this).
3. **Private by default.** Face photos, scans and 3D data stay on the device (plus the user's own iCloud). Anything
   shared leaves only when the user exports it. Social features share streaks and points, never photos.
4. **HealthKit data never goes to iCloud.** No third-party AI sees personal data without per-use consent.
5. **The first scan of the day is always free.** Scanning is the loop that makes people share, so it is never
   locked — free users get one saved scan per day (owner decision 2026-11-19), Pro is unlimited. See M8.
6. All existing engineering rules still apply (iPhone Duo in every pose, design tokens, additive CloudKit schema,
   tests first for logic).

---

## 1. Build queue (in order)

The detailed phases — steps, how each is checked, and what each needs from the owner — are in
[FEATURE-PHASES.md](FEATURE-PHASES.md). Phase 0 there (closing out open work) comes before this queue.

| # | What | IDs |
|---|------|-----|
| 1 | Pimpi on the Mirror, reacting to the streak | PI2, E1 |
| 2 | Streaks with freeze, weekend-off and repair | E1–E4 |
| 3 | Pimpi widget (home + lock screen) | PI3 |
| 4 | Shareable skin card + product verdict share card | G2, G4 |
| 5 | Glow-up reel export | G1 |
| 6 | Paywall (StoreKit, plans, trial, triggers) | M1–M6 |
| 7 | Daily quests, glow points, chests | E5–E8 |
| 8 | Skin School | E9–E10 |
| 9 | Spot timeline + zone heat map on the 3D head | P1, P2 |
| 10 | Everything else, re-prioritised after launch data | — |

---

## 2. Pimpi (mascot)

Evolved from the original mascot: same pink blob, head bump, navy eyes, cream cheeks — redrawn as a vector character
with depth, no outlines, and moods.

- [x] **PI1 Pimpi character** — six moods (happy, excited, curious, sleepy, worried, sad); blinks, breathes, bump
  wobbles; still under Reduce Motion. `Skinalyze/Shared/Pimpi.swift`, commit `1095516`. Look approved by owner.
- [x] **PI2 Pimpi on the Mirror** (Phase 1) — mood follows the streak: excited after a scan, sleepy when a scan is due,
  worried when the streak is at risk, sad when it breaks. · Free
- [x] **PI3 Pimpi widget** (Phase 2) — home and lock screen; shows Pimpi's current mood + streak. · Free
- [x] **PI4 Notifications in Pimpi's voice** (Phase 2) — gentle escalation ("I've been waiting with my magnifying glass…");
  never about skin condition, never guilt about results. · Free
- [x] **PI5 Pimpi celebrations** — streak milestones, quest chests, first 3D scan. · Free
- [x] **PI6 Pimpi outfits and hats** — cosmetic rewards from chests; premium sets in Pro. · Free + Pro
- [ ] **PI7 More moods / poses as needed** (e.g. proud, waving, holding sunscreen). · —

---

## 3. Engagement (the Duolingo layer)

### Streaks
- [x] **E1 Scan streak** (Phase 1) — weekly rhythm (scan day), flame on the Mirror. · Free
- [x] **E2 Routine streak** (Phase 1) — daily AM/PM check-off in ~5 seconds. · Free
- [x] **E3 Streak freeze, weekend-off mode, repair within 24 h** (Phase 1) — freezes earned from quests. · Free (earned) / Pro (extra)
- [x] **E4 Milestones** (Phase 1; shareable card Phase 3) — 7 / 30 / 100 days with a Pimpi celebration and a shareable card. · Free

### Quests and rewards
- [x] **E5 Daily quests** — three small ones (check off routine, check a product, log sleep). · Free
- [x] **E6 Glow points** — earned for effort only (rule 1). · Free (Pro: double points)
- [x] **E7 Chests** — cosmetic rewards: sticker-card themes, holo styles, Pimpi outfits. · Free + Pro sets
- [x] **E8 Monthly quest** — limited badge. · Free

### Skin School
- [~] **E9 Lessons** — 60-second lessons ("What niacinamide does", "Why sunscreen indoors") + two-question quiz + XP.
  Content must pass the copy rules (general information, sources listed). · Free (first units) / Pro (all)
- [~] **E10 Lesson path** — units on a path, so there is always something to do between scans. · Free + Pro

### Progress
- [x] **E11 Journey map** (Phase 9) — levels as the user scans and learns. · Free
- [x] **E12 Weekly recap from Pimpi** (Phase 9) — every Sunday. · Free
- [x] **E13 Badge shelf** — first 3D scan, 10 product checks, a month of sunscreen… · Free
- [x] **E14 Monthly recap** (Phase 9) — short summary card. · Free

### Social (no faces)
- [x] **E15 Friend streaks and friend quests** (Phase 9, iCloud public database) — share streak and points only. · Free
- [x] **E16 Weekly leagues** (Phase 9) — ranked on consistency points, never on skin. · Free
- [x] **E17 30-day challenges** (Phase 9) ("30 days of sunscreen") with a finisher card. · Free

---

## 4. Growth and sharing

- [x] **G1 Glow-up reel** (Phase 4) — one-tap video: sticker cards morphing oldest → newest, eye-aligned, index counting;
  export for TikTok / Reels. The main viral loop. · Free (watermark) / Pro (no watermark)
- [x] **G2 Shareable skin card** (Phase 3: image; shimmer video with Phase 4) — the holo sticker card as image or tilt-shimmer video; "hide my face" option
  (silhouette + stats). · Free
- [x] **G3 3D face turntable export** (Phase 4; free until the paywall) — looping video of the fused 3D head rotating. · Pro
- [x] **G4 Product verdict share card** (Phase 3) — "Is it good for me?" result as a card; every check advertises the app. · Free
- [x] **G5 Before/after slider export** (Phase 3: still image; slider video with Phase 4) — from the eye-aligned Compare. · Free (watermark) / Pro
- [x] **G6 Skin Wrapped** (Phase 9) — yearly/quarterly recap: best streak, most-improved zone, product that coincided with the
  best month. · Free
- [ ] **G7 Routine cards** — "my shelf" as a shareable image; others tap to check those products for their skin. · Free
- [x] **G8 Referral** (Phase 9: invited friend gets a month via an App Store offer code; inviter gets thanks, not a month — needs a server) — give a month of Pro, get a month. · —
- [ ] **G9 Creator kit** — reel templates + affiliate code. · —
- [ ] **G10 Share-sheet entry from TikTok Shop / Shopee / Tokopedia product pages** — extends the existing share
  extension. · Free
- [x] **G11 Sticker-card widgets** (Phase 3: home screen, no photo) — home / lock screen widgets that look like the card. · Free

---

## 5. Product features

- [~] **P1 Spot timeline** (Phase 8 shipped "this area over time"; states wait for steadier detection) — tap a dot to follow that same spot across scans (appeared, fading, gone). · Pro
- [x] **P2 Zone heat map over time** (Phase 8) — on the 3D head, scrubbable by date. · Pro
- [ ] **P3 Trigger journal** — sleep, stress, cycle, diet, new product; shows what coincided with flare-ups. · Free
  (log) / Pro (insights)
- [ ] **P4 Cycle and sleep correlation via HealthKit** — on-device only (rule 4). · Pro
- [ ] **P5 Routine builder** — AM/PM steps, reminders, "don't mix these two actives" warning from the ingredient
  rules. · Free
- [ ] **P6 Patch-test timer** — "day 3 of 14: anything changed?" for a new product. · Free
- [ ] **P7 Product expiry tracker** — opened-on date and period-after-opening. · Free
- [ ] **P8 Barcode scan** — needs a product-barcode data source. · Free
- [ ] **P9 Dupe finder** — same key ingredients, cheaper. · Pro
- [ ] **P10 UV and humidity nudge** — "UV 9 today: sunscreen". · Free
- [ ] **P11 Dermatologist visit pack** — PDF with photos, trend, products used (extends the existing export). · Pro
- [ ] **P12 Scan-quality coach** — more consistent lighting between scans. · Free
- [ ] **P13 Private vault** — biometric lock exists; add hidden album and decoy mode. · Free
- [ ] **P14 Apple Watch routine check-off; Siri and Shortcuts** (some intents already exist). · Free

---

## 6. Paywall and money

**Free (drives growth):** one scan per day, latest result, sticker card and sharing, 7-scan history, 3 product checks
a month, streaks, basic quests, first Skin School units.

**Pro:** unlimited scans, unlimited history and Compare, 3D head + turntable export, reels without watermark, spot timeline, zone heat
map, trigger insights, unlimited product checks, dupe finder, PDF pack, sync across devices, custom card themes and
holo styles, extra streak freezes and repair, all of Skin School, premium Pimpi outfits, double glow points.

- [x] **M1 StoreKit subscriptions** — weekly, monthly, annual; 7-day trial. · —
- [ ] ~~**M2 Lifetime one-time purchase.**~~ Dropped by owner (2026-11-19). · —
- [ ] **M3 Localised pricing** — IDR, plus a student price. Actual price points: **owner decision, still open**. · —
- [x] **M4 Paywall screen** — Pimpi-led, shows what Pro adds; restore purchases; clear terms. · —
- [x] **M5 Paywall triggers** — after the first sticker moment; starting a second scan the same day (M8); opening an
  8th scan; first 3D turn; "export without watermark". Never before the first scan result. · —
- [x] **M6 Entitlement gating in code** — one tested place that answers "is this Pro?" · —
- [ ] **M7 Affiliate links on product pages** — clearly labelled; must never influence the verdict (verdicts stay
  rule-based). · optional
- [x] **M8 Free scan limit: one saved scan per day** — Pro is unlimited. Details so it never feels unfair:
  only a scan that was analysed and saved counts (a cancelled scan, a retake during capture, or a failed analysis does
  not); the day resets at local midnight; the Mirror (live camera) stays open and shows when the next free scan is
  available; a second scan the same day opens the paywall instead of the capture. The limit (1/day) is a tunable
  constant, tested. · Free limit / Pro unlimited

---

## 7. Deliberately not doing

- **Public feed of faces** — privacy and moderation burden.
- **AI "dermatologist chat"** — diagnosis risk; the app already had a 1.4.1 rejection.
- **Locking the scan entirely for free users** — kills the loop that makes people share (a daily limit is fine: M8).
- **Rewards or rankings based on skin results** — see rule 1.

---

## 8. Already built (for reference)

- [x] V2 "Mirror" redesign: live-camera home, glass dock, Deck, Shelf, result chapters, light + dark.
- [x] Face ID-style scan, calibrated on device; full side profile accepted.
- [x] Die-cut holo sticker cards + photo → sticker → card moment after each scan.
- [x] Real TrueDepth 3D: front + side captures fused into one head with real sides (`dd5b8ea`); viewer turns as far
  as each side was captured. Confirmed working on the owner's phone (2026-11-19).
- [x] Tappable spot pins; eye-aligned Compare.
- [x] Product Check ("Is it good for me?"), share extension, label scanner, widgets, intents.
- [x] Pimpi character (`1095516`).

## 9. Open decisions (owner)

1. Price points (M3) and whether a lifetime option ships at launch (M2).
2. Scan rhythm for the scan streak (E1): weekly is proposed.
3. Sign-off on the Skin School wording (E9) — draft of 10 lessons in [SKIN-SCHOOL.md](SKIN-SCHOOL.md).
4. Whether affiliate links (M7) are wanted at all.
