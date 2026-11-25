# Onboarding and first-time tutorial — plan

Status: **approved 2026-11-25** with the recommended answers in §9; built in phases O0–O4 (see §8). Replaces PLAN.md §10.1 once approved. All rules in CLAUDE.md
and FEATURES.md §0 apply (score effort never skin, tracker not diagnosis, private by default, first scan of the day
free, every iPhone shape and pose).

## 1. What's wrong today

The current onboarding (`Skinalyze/Features/Onboarding/OnboardingView.swift`) is a tidy six-page form: welcome,
goals, skin type, sensitivity, name, privacy. Pimpi stands above each page and hops when you pick something, but:

- **You read and tap cards; you never *do* anything.** Every page looks the same, so nothing is memorable.
- **It ends on a button, not a scan.** The app's whole loop is the scan, and the first one is left for later.
- **Nothing comes back to you.** Your answers disappear into settings; there's no "here's your plan" moment.
- **There is no tutorial.** Streaks, quests, chests, the Deck, Compare, the Shelf, product checks, Skin School,
  the 3D head and Pimpi's poke are all discovered by accident, or never.

## 2. Goals and how we'll know

| Goal | Measure (checked in UI tests / recordings; no analytics leave the phone) |
|---|---|
| Fun and memorable | Every step has one physical action (tap, drag, hold, swipe) and a Pimpi reaction |
| Fast | Welcome → first scan in **≤ 90 s** on the quick path; every optional step skippable in one tap |
| Personal | Ends with a starter plan built from your answers (rule-based, tested) |
| Gets to the loop | The last onboarding step *is* the first scan (with "Look around first" as a way out) |
| Teaches by doing | Features are explained the first time you reach them, by Pimpi, one at a time, never a wall of tips |
| Builds the habit | A 7-day "first week" path on Home, rewarded for showing up (never for skin results) |
| Works for everyone | Every gesture has a button alternative; VoiceOver, Dynamic Type to AX5, Reduce Motion; Duo in every pose |

## 3. Principles

1. **Pimpi hosts, you act.** Pimpi is the guide on every screen and reacts to each answer (mood, hop, line).
   The user always does something small and satisfying rather than reading a paragraph.
2. **One idea per screen, one action per idea.** Short lines in Pimpi's handwriting; facts in plain type.
3. **Earn the questions.** Ask only what changes the app: goals, skin type, sensitivity, optional name, optional
   products. No age, no gender.
4. **Never a paywall before the first scan result** (FEATURES M5). Onboarding never mentions prices.
5. **Teach in context, not up front.** The onboarding stays short; the tutorial arrives where the feature is.
6. **Tips are polite.** One coach at a time, at most two per session, never over a sheet or during a scan; dismiss
   with a tap; "Turn off tips" and "Replay the tour" in Profile.
7. **Same feel as the rest of the app:** Pimpi's Place (sky, hill, chunky surfaces), the shared spring and haptic
   tokens, nothing that looks like a generic AI app.

## 4. The new onboarding — step by step

Ten short scenes. Progress shows as Pimpi walking along a little path at the top (instead of segments); Back is
always available; optional scenes have "Skip".

| # | Scene | What you do | Pimpi | Stored |
|---|---|---|---|---|
| 1 | **Wake Pimpi** | Pimpi is asleep on the hill (z's). "Tap to wake me." You poke; Pimpi stretches, blinks, waves. | sleepy → excited | — |
| 2 | **Hello** | Pimpi introduces itself in one line and holds up a blank name tag. Type your name and it's written on the tag in Pimpi's handwriting. *Optional.* | happy; party hat when the tag is filled | name |
| 3 | **Pack the bag** | "What are we working on?" Goal items (fewer breakouts · fade dark marks · understand my skin · check products · build a routine) sit on the hill; tap one and it flies into Pimpi's backpack with a bounce. Tap again to take it out. | curious; nods per item | goals |
| 4 | **Midday check** | Three quick cards: "By midday my forehead is…", "My cheeks usually feel…", "After washing, my skin feels…". Swipe or tap an answer. Pimpi announces the result ("Sounds like combination skin"). "I already know" jumps to the four type cards. | curious → happy | skin type |
| 5 | **New-product test** | "When you try something new, your skin…" three answers. Pimpi reacts (worried for "stings often", with a reassuring line). | happy / worried | sensitivity |
| 6 | **Your shelf** *(optional)* | Four empty shelf spots (cleanser, toner, moisturizer, sunscreen). Tap one to search, or scan a barcode. Products pop onto the shelf. "Skip — I'll add them later". | curious | shelf slots |
| 7 | **The promise** | Pimpi locks a little box: "Your photos stay on this iPhone and your own iCloud. Never on our servers." **Press and hold** to seal the promise. A ring fills, the haptic ramps up, and the box clicks shut. Also: "Tracks visible changes; not a medical device", plus a privacy policy link. | sunglasses | — |
| 8 | **Your starter plan** | A card slaps onto the hill like the scan sticker: your focus, two "look for" ingredients for your skin type, your first-week path, and today's first quest ("Do your first scan"). Tap to keep it. | excited | plan seen |
| 9 | **Camera, the friendly way** | Pimpi with its magnifier: "I look at your skin right here on the phone. Let me borrow the camera?" Then the system prompt. If you decline, you get a gentle path to Settings, and the app still works (Shelf, School). | curious | — |
| 10 | **First scan** | Straight into the scan stage, in coached first-scan mode (§5.1). "Look around first" skips to Home, with the first-week path waiting. | — | — |

Arriving from a friend's invite link: scene 2 adds "*Sunny Otter* invited you", and the friend is added when
onboarding ends (no photos, generated names only, as today).

### Accessibility and other states for each scene

- **Gestures have buttons:** wake is a Button; flying items are Buttons; the swipe cards also have answer buttons;
  press-and-hold has an `accessibilityAction` ("Seal the promise") and is a plain tap at accessibility text sizes.
- **Reduce Motion:** no flying or slapping; cross-fades and Pimpi's mood changes only.
- **Dynamic Type AX5:** Pimpi moves above the words; goal items become a single column; swipe cards become a list.
- **iPhone Duo:** unfolded or landscape uses a split arrangement (Pimpi and the hill on one side, the question on
  the other); outer display portrait is the baseline; compact × compact gets its own compact layout; nothing
  interactive on the fold (ReservedRegion).
- **State survives fold, unfold and rotate:** the current scene and answers are kept (`@SceneStorage` plus the
  stored values), so nothing resets.
- **Coming back later:** quit mid-onboarding and you resume at the same scene.

## 5. The tutorial

### 5.1 First scan, coached

The first scan runs in a gentler mode, used once:

- Before the camera, Pimpi shows the three poses with a small looping animation (look at me, turn right, turn left).
- During the scan, a one-line coach at the top ("Hold still — almost there") is spoken by VoiceOver, with extra
  patience: the manual-capture fallback appears sooner. The scan rules themselves never change.
- On TrueDepth iPhones, one line explains the 3D moment ("Hold still — I'm making your 3D head"). On iPhone Duo,
  2D only, with no mention of 3D.
- After the sticker moment, a short **result tour** of four coach steps:
  1. The breakout index: "This is your starting point, not a grade."
  2. The chapters: "Swipe for what changed, what we noticed and what helps."
  3. The 3D head or a spot pin: "Turn me" or "Tap a dot."
  4. Done: "Come back tomorrow and we'll compare."

  Each step is dismissed with a tap, and "Skip tour" is always there.

### 5.2 Pimpi coach marks: explained the first time you get there

A small coach bubble from Pimpi points at one thing, with a soft spotlight around it. The rules decide when; the
copy is one sentence plus "Got it".

| Where | When it shows (once) | Says |
|---|---|---|
| Home: Pimpi | First Home visit after onboarding | "Poke me any time. I've got tips." |
| Home: streak chip | After the first scan | "Show up each day and this grows. Skin doesn't count, showing up does." |
| Home: today's three | Second app open | "Three small things a day: scan, routine, one lesson." |
| Shelf | First Shelf visit | "Ask me 'Is it good for me?' about any product." |
| Product page | First product opened | "Green means it suits what you told me. It's a guide, not a rule." |
| Deck | Second saved scan | "Two scans: tap Compare to see them side by side." |
| Quest chest | First chest earned | "You earned a chest! Tap to open." |
| Skin School | First time the lesson card is on screen | "Two-minute lessons. Finish one for points." |
| Journey | First visit | "Every point moves you along. It's all effort, never skin." |
| Routine builder | First open | "Add your extras. I'll flag pairs that don't mix." |

Rules: at most two coaches per app session, never while a sheet, scan or celebration is on screen, and never twice.
"Turn off tips" and "Replay the tour" live in Profile. People who already use the app see only the coaches for
features they've never used (based on what they've actually done), never the onboarding.

### 5.3 The first week, on Home

A 7-step path card on Home (Pimpi walks along it), one small thing per day. Missing a day just waits; nothing is lost.

1. First scan + put one product on your shelf
2. Tick off your routine
3. Finish one Skin School lesson
4. Check a product: "Is it good for me?"
5. Scan again and **Compare** your two scans
6. Open your first quest chest
7. Visit your Journey map *(changed from "see your first weekly recap": recaps only open on Sunday/Monday, which
   could block finishing)*

Finishing it earns a starter outfit for Pimpi (a new free outfit, e.g. a scarf) and a celebration. Effort only, so
a breakout week never costs anything (FEATURES §0 rule 1). It disappears once finished, or can be dismissed.

## 6. How it's built

- **Kit (pure, tested first):**
  - `OnboardingFlow` holds the scenes, which can be skipped, how Back works, how to resume, and how an invite
    changes the flow.
  - `SkinTypeQuiz` turns three answers into a skin type. It's deterministic, with every combination tested.
  - `StarterPlan` builds your plan from goals, skin type and sensitivity: a focus, ingredients from
    `SkinTypeGuidance`, and the first-week steps.
  - `FirstWeekPath` tracks the seven steps from what you've already done (existing engagement events), and stays
    correct across days and on a second device.
  - `CoachRules` decide which coach can show now: once only, at most two per session, never over sheets, plus the
    rules for people who already use the app.
- **App:**
  - `Features/Onboarding/` gets one file per scene, plus `OnboardingFlowView`.
  - A shared `PimpiCoach` overlay draws the bubble and spotlight. Targets are marked with anchor preferences, so
    no geometry is hard-coded.
  - Coach state uses our own small store (`TutorialState`, synced with the engagement record) rather than TipKit:
    it needs to sync across devices and be tested, and the look is our own anyway.
  - First-scan mode is a flag on `ScanCaptureModel`. The scan rules don't change.
- **Data:**
  - Onboarding answers use the existing `UserProfile` keys.
  - Tutorial and first-week progress live in the synced engagement record (additive, tolerant decoding), so a
    second device doesn't repeat it.
  - No CloudKit schema change.
- **New Pimpi pieces:**
  - A backpack, a name tag and the promise box: small vector props.
  - Two poses, *waving* and *pointing* (PI7), used by the coach.
  - Every animated prop is checked in a frame-by-frame screen recording before it counts as done.
- **Copy:** English and Indonesian, through the copy lint (no medical words), short enough for speech bubbles.

## 7. Not doing

- A tutorial wall of slides before using the app.
- Asking for age, gender or anything that doesn't change the app.
- A paywall, trial pitch or prices anywhere in onboarding or the first-scan tour.
- Sound effects. Haptics and motion only; sound could come later as an option.
- Letting users rename Pimpi (brand character).

## 8. Phases

Each phase ends with tests green, screenshots and recordings checked (light and dark, iPhone SE size, Pro Max,
Duo closed, folded and unfolded, landscape, AX5, VoiceOver pass, Reduce Motion), and a local commit.

- **O0 Foundations**
  - [x] Kit: `OnboardingFlow`, `SkinTypeQuiz`, `StarterPlan`, `FirstWeekPath`, `CoachRules`, with tests written first
  - [x] Coach state: own store (`TutorialState`), synced; not TipKit
  - [x] Pimpi props (backpack, name tag, promise box, plan card) and waving and pointing poses
- **O1 Onboarding scenes 1–8**
  - [x] Wake, Hello and name tag, Pack the bag, Midday check, New-product test, Your shelf, The promise, Starter plan
  - [x] Path progress, Back, Skip, resume; invite variant
  - [x] Every gesture has a button / accessibility action; Reduce Motion variants
- **O2 Camera and first scan**
  - [x] Camera priming scene; denied path to Settings; "Look around first"
  - [x] Coached first-scan mode (pose intro, first-time lines); result tour (4 steps, skippable)
  - [x] UI test: welcome → Home on the quick path in ~40 s including the test's pauses
- **O3 Coach marks**
  - [x] Coach overlay + spotlight; the ten coaches in §5.2 (off-screen targets show in the middle)
  - [x] Profile: "Pimpi's tips" switch and "Replay the tour"
  - [x] People who already use the app: coaches only for features they've never used; no onboarding
- **O4 First week**
  - [x] "First week n/7" chip on Home (Home has no room for a card) opening the path; scarf reward and celebration
- **O5 Polish and sign-off**
  - [x] Indonesian for every new string; copy lint (0); largest text sizes (XXXL, AX5); landscape; Reduce Motion run
  - [x] Accessibility audit of every scene and the coach mark, light and dark (contrast, labels, hit areas, Dynamic
        Type). Fixed on the way: disabled buttons were faded below contrast (now a flat light button, app-wide),
        option subtitles, the name tag now grows with the text
  - [x] iPhone Duo outer display (closed, portrait): every scene
  - [ ] iPhone Duo unfolded and tabletop poses: the Simulator can't pose the Duo (`simctl` has no pose control) —
        check on hardware, or with RocketSim's `rocketsim duo pose book|open`
  - [x] Recordings of the onboarding frame-checked (wake and wave, backpack, promise lid, plan card); motion lab for
        the poses and scarf; installed on the owner's phone
  - [ ] The coached first scan on a real camera (the Simulator has none)

## 9. Decisions for the owner

| # | Question | Recommendation |
|---|---|---|
| 1 | Should the first scan be part of onboarding, or offered at the end? | **Part of it**, with "Look around first" as an easy way out |
| 2 | When should we ask for notifications? | **After the first scan** ("Want me to remind you tomorrow?"), not during onboarding. People say yes more often once they've seen the point |
| 3 | Should the "Your shelf" step (6) be in onboarding? | **Yes, optional.** It makes the plan and first product check personal straight away |
| 4 | Starter reward for finishing the first week | **A new free outfit (scarf)** |
| 5 | Should people who already use the app see anything? | **Only coaches for features they've never used**, and no onboarding |
| 6 | Sound effects | **No** for now |
