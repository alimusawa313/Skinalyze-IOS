# Skinalyze Redesign — Phases

> **Status:** Planning · **Last updated:** 2026-11-18 · **What & why:** [PLAN.md](PLAN.md) · **Rules:** [/CLAUDE.md](../../CLAUDE.md)
>
> Phases are **build order, not releases** (release strategy is deferred). Each phase has a goal, dependencies, scoped
> workstreams with checkbox tasks, deliverables, **exit criteria** (a phase is done only when every exit criterion is
> met), tests, risks, and the skills/agents to load. Tick boxes as you go; update PLAN.md §20 when a phase closes.

---

## Build status (2026-11-18) — all phases built; ready for device testing

All work is on local branches (never pushed): `phase-0/foundation` → `phase-1/scan-engine` → `phase-2/design-system`
→ `phase-3/app-shell` → `phase-4/face-3d` (this last branch contains everything, incl. Phases 5–7).

| Phase | Status | Verified by |
|---|---|---|
| 0 Foundation | ✅ Done | Migration tests on the real legacy `Result` model; store pinned; catalogs merged |
| 1 Scan engine | ✅ Built — **needs device calibration** | 66 gate/flow/zone/NMS tests; camera only testable on hardware |
| 2 Design system | ✅ Done | WCAG contrast tests on every text/UI token |
| 3 App shell & screens | ✅ Done | XCUITest E2E (Today, Timeline, detail, Compare, Search, scan-without-camera, a11y audit) on iPhone 17 **and iPhone Duo** |
| 4 3D face | ✅ Built — **needs device calibration** (UV / mirroring flags) | Mesh codec + pin mapping tests; synthetic-mesh UI test |
| 5 Product Check | ✅ Done (Visual Intelligence not yet) | Verdict golden tests; share extension builds + embeds; shared-context test |
| 6 Insights & habit | ✅ Mostly (journal/HealthKit not built) | Insight/effect tests; widgets + control + App Intents build |
| 7 Polish | ✅ Icon, accent, ID strings, asset cleanup, copy lint gate | `scripts/test.sh`: 96 Kit + 8 app + 7 UI tests, 0 copy violations |

### How to test

1. `scripts/test.sh` (or `scripts/test.sh "iPhone Duo"`) — everything above, including the UI suite.
2. Simulator with sample data: run the `Skinalyze` scheme with launch argument `-seedDemoData` (Debug only).
   Add `-startTab timeline|products|search|scan` to jump straight to a screen; `-AppleLanguages (id)` for Indonesian.
3. **On a real iPhone (required for):** scanning (gates, auto-capture, hold-still ring, retake), Face ID 3D view,
   biometric lock, reminders, widgets/Control, Share sheet from Safari / Photos, label scanner.
4. **On a real iPhone Duo:** closed ↔ open ↔ tabletop mid-scan (scan must keep its captured angles), vertical bars,
   Touch ID lock copy, no 3D offered.

### Device calibration checklist (hardware needed)

- [ ] `GateThresholds.rightTurnYawSign` — turn right on the "Turn right" step; flip if hints say the opposite
- [ ] `GateThresholds.minSharpness` / `luma` — tune with the consistency benchmark (PLAN §18.3)
- [ ] `FaceMeshCapturer.projectionIsMirrored` + UV V-flip — texture should line up with the face; pins on real spots
- [ ] Capture orientation on iPhone Duo inner/outer displays and in landscape

### Owner actions before a device/TestFlight build

- [ ] Register App Group `group.com.Patani.Skinalyze` and enable it for `com.Patani.Skinalyze`,
      `com.Patani.Skinalyze.ProductCheck`, `com.Patani.Skinalyze.Widgets`
- [ ] Confirm whether the shipped build had CloudKit on (schema treated as live/additive either way)

### Still open (not built)

- Visual Intelligence integration (Phase 5) · trigger journal + HealthKit (Phase 6) · consistency-benchmark fixture
  collection and detector retraining (Q3) · full Indonesian coverage (core flows done) · app target Swift 6 mode ·
  ARKit-based gating on Face ID iPhones · on-device Foundation Models phrasing (templates ship today) ·
  moving the SwiftData store into the App Group (no longer required: extensions use `SharedContext` snapshots)

## Overview

| Phase | Name | Goal (one line) | Depends on | Size |
|---|---|---|---|---|
| 0 | Foundation & cleanup | A clean, modern, testable codebase that can grow | — | M |
| 1 | Scan reliability engine | Same face → same result, measured | 0 | L |
| 2 | Brand & design system | A distinctive identity + tokens + motion/haptics system | 0 (parallel with 1) | M |
| 3 | App shell, core screens & adaptive layouts | The new app on every iPhone shape and pose | 1, 2 | XL |
| 4 | 3D face scan & zones | The signature 3D experience + per-zone tracking | 1, 3 | XL |
| 5 | Product Check | "Is this good for me?" from anywhere | 0, 2 (3 for in-app UI) | L |
| 6 | Insights, routine & habit | Turn data into reasons to come back | 3, 4 (zones), 5 (ingredients) | L |
| 7 | Trust, accessibility, performance & polish | Award-level finish | all | M |

```
0 ──┬── 1 ──┬── 3 ──┬── 4 ──┐
    │       │       │       ├── 6 ── 7
    └── 2 ──┘       └── 5 ──┘
```

Phase 5's ingredient engine (in `SkinalyzeKit`) can start right after Phase 0; its in-app UI waits for Phase 3.

---

## Conventions for every phase

**Workflow (from `/CLAUDE.md`):** plan → tests first (RED) → implement (GREEN) → refactor → review (`swift-reviewer`
agent + `swiftui-pro` skill) → verify on the device-state matrix → **commit locally (never push)**.

**Branches:** one feature branch per workstream, e.g. `phase-1/capture-gates`. Conventional commits.

**Universal Definition of Done (applies to every task with UI):**
- [ ] Uses design tokens only (no raw hex / magic numbers) — from Phase 2 onward
- [ ] Previews for: smallest iPhone portrait + landscape, Pro Max, Duo closed portrait + landscape, Duo partially folded
      (book + tabletop), Duo unfolded portrait + landscape — from Phase 3 onward
- [ ] No interactive element in the fold / camera reserved regions
- [ ] State survives fold / unfold / rotate
- [ ] Light + dark, Dynamic Type to AX5, VoiceOver labels, Reduce Motion fallback
- [ ] No main-thread blocking (ML, image work, session start/stop)
- [ ] Copy passes the §15.1 banned-terms check
- [ ] Unit tests for logic; ≥ 80% coverage on `SkinalyzeKit` code touched

**Skills to load** (vendored in `.claude/skills/`, see PLAN.md §22): named per phase below.

---

## Phase 0 — Foundation & cleanup

**Goal:** Make the codebase safe to change: modern toolchain, dead code gone, storage fixed, shared package in place,
tests running. No visible redesign yet — the app should look and behave the same (minus bugs fixed along the way).

**Skills/agents:** `swift-concurrency`, `swiftui-expert-skill` (latest-apis, soft-deprecation), `iphone-duo-readiness`
(audit only), agents `swift-build-resolver`, `refactor-cleaner`, `tdd-guide`.

> **Progress (2026-11-18, branch `phase-0/foundation`, local commits only):** items ticked below are committed and
> verified (`scripts/test.sh`: 27 package tests + 6 app-hosted tests green; app launches on iPhone 17 + iPhone Duo
> simulators). Items marked **→ Phase N** were moved deliberately: they touch legacy screens that Phase 1/3 rewrite,
> so doing them now would be throwaway work.

### 0.1 Toolchain & project

- [x] `project.yml`: `deploymentTarget: iOS: "26.0"`, iPhone-only, entitlements wired, team set
- [ ] Swift 6 language mode for the **app** target → after the legacy views are replaced (Phase 3). *`SkinalyzeKit`
      already builds in Swift 6 mode.*
- [x] Builds with Xcode 27.2 / iOS 27.x SDK
- [x] Removed the broken `resources: [Resources]` entry
- [x] `UISupportedInterfaceOrientations`: landscape left/right added (layouts fixed in Phase 3; camera in Phase 1)
- [x] `SkinalyzeTests` target (Swift Testing, app-hosted) · [ ] `SkinalyzeUITests` → Phase 3 (E2E on new screens)
- [x] Local Swift package `SkinalyzeKit` (`Detection/`, `Persistence/` so far) linked to the app
- [x] App Group entitlement (`group.com.Patani.Skinalyze`, name TBD with rebrand Q1) — **owner must register the App
      Group in the developer portal before the next device/TestFlight build**
- [x] `scripts/test.sh` — package tests + app build/tests + copy lint in one command
- [x] `scripts/lint_copy.py` banned-terms lint (report-only until the Phase 2 copy rewrite; 12 current hits)

### 0.2 Dead code & duplicate removal

- [x] Deleted `DetailVIew`, `CompareView`, `ContentCell`/`ScrollCell`, `CameraSheetTutor`, `CardStackView`, `temp`,
      `LottieView` (`CameraView.swift` kept — it defines the live `CameraPreviewView`; `LineDivider` moved to its own file)
- [x] Removed unreachable routes (`detailView`, `compareImagesView`); merged `prodUsed` into `productUsedView`
- [ ] Rename `NewDetailViewTest`, move `ProductSearchView` → Phase 3 (screens are rebuilt)
- [x] Deleted unused assets (`Atas`, empty `Image`, `capsuleInactive`); `brownTest`/`maskotScan` are in use and kept;
      missing `MaskotNone` replaced with an invisible spacer
- [x] Color-name case fixed: `TextPrimary` → `textPrimary` (51 call sites), `TextReverse` → `textReverse`
- [x] Catalogs merged by `scripts/merge_catalog.py` → `ProductCatalog.json` (459 products, 457 with ingredients,
      legacy `product_id`s preserved; 898 KB → 567 KB)
- [ ] Collapse the copy-pasted product slot blocks → Phase 3 (Products screen rebuild)

### 0.3 State & architecture modernization

- [ ] `ObservableObject` → `@Observable`, inline `@ObservedObject` fixes → Phase 1 (scan VMs) / Phase 3 (screens)
- [ ] `@Observable AppRouter`, remove nested `NavigationView`s → Phase 3 (new shell)
- [ ] Remove `UIScreen.main.bounds` → Phase 3 (every legacy screen using it is replaced)
- [ ] `ScanFlow` state machine → Phase 1 (built together with the capture engine)

### 0.4 Storage migration (CloudKit-aware) — highest-risk task in this phase

- [x] Fixture-based tests: idempotent import, content preserved, bad/missing images tolerated, legacy never modified,
      delete-without-resurrection, EXIF orientation preserved (Kit + app-hosted tests on the real `Result` model)
- [x] New CloudKit-compatible models: `ScanSession`, `ScanCapture`, `StoredDetection` (`UserProduct` → Phase 3/6)
- [x] `@Attribute(.externalStorage)` image `Data` (HEIC, JPEG fallback, quality 0.8)
- [x] Launch-time background migration (`LegacyMigrationRunner` → `ScanStore` actor), batched, marker = `legacyResultID`
- [x] **Store pinned to its pre-App-Group path** (the App Group entitlement would otherwise move SwiftData's default
      store and hide existing history)
- [ ] Move store into App Group container (copy → verify → switch) → start of Phase 5 (first extension that needs it)
- [x] New scans stored once as photos + detections (no duplicate "analyzed" images / JPEG overlays)
- [ ] Profile `@AppStorage` → App Group `UserDefaults` → start of Phase 5 (with the store move)
- [ ] **Owner:** verify iCloud sync between two devices on the development CloudKit container (needs signed builds)

### 0.5 Quick correctness fixes (low risk, high value)

- [x] Blackheads now count toward severity (`LegacySeverityScale`, regression test); `geaScale` starts at 0
- [x] Saved scans are never re-analyzed (Detail + Compare render stored detections)
- [x] Compare no longer force-unwraps missing images
- [ ] Camera permission denied state → Phase 1 (1.2 capture engine)
- [ ] 0-interval `Timer` haptic spam → Phase 1 (1.2/1.3 gates rewrite)

**Deliverables:** modern project, `SkinalyzeKit` package, migrated storage, tests running, cleaner code.

**Exit criteria:**
- [ ] App builds on Xcode 27.1, iOS 26 deployment, Swift 6 strict concurrency with zero warnings in new code
- [ ] All legacy-store fixtures migrate correctly; a real device with existing history migrates with no data loss
- [ ] Storage per scan reduced (measure before/after; target ≥ 70% smaller)
- [ ] No dead/duplicate screens or routes remain; `grep UIScreen.main` returns nothing
- [ ] Test suite runs locally; ≥ 80% coverage on `SkinalyzeKit/Persistence`

**Risks:** CloudKit migration (mitigate with fixtures + dev container); scope creep into redesign (resist — Phase 3).

---

## Phase 1 — Scan reliability engine

**Goal:** Make scans deterministic enough to trust, and *prove it* with a benchmark. Includes the iPhone Duo camera
work and the ARKit-on-Duo spike, since capture is the foundation for everything after.

**Skills/agents:** `swift-concurrency` (actors, isolation), `iphone-duo-camera`, `iphone-duo-hinge-and-scenes`
(scene/camera accessory awareness), `swiftui-expert-skill` (performance), agents `tdd-guide`, `swift-reviewer`,
`performance-optimizer`.

### 1.1 Benchmark first (RED before fixing)

- [ ] Define the consistency benchmark (PLAN §18.3): fixture set spec, metrics, targets
- [ ] Collect fixture captures with consent (diverse skin tones/lighting; 5 repeats each); store outside the repo
- [ ] Annotate a ground-truth subset (lesion boxes + types) for recall measurement
- [ ] Harness: run current pipeline on fixtures → baseline numbers in `docs/redesign/benchmarks/baseline.md`

### 1.2 Capture engine

- [ ] `CaptureEngine` actor owns `AVCaptureSession` (begin/commit configuration, `canAdd*` checks, photo preset)
- [ ] `AVCapturePhotoOutput` with `.quality` prioritization for stills; video data output for gating only
- [ ] Continuous AE/AWB/AF; exposure + focus point of interest on face center (remove `exposureMode = .locked`)
- [ ] Session start/stop off-main; lifetime tied to `ScanFlow` + `scenePhase`, **not** `onDisappear`
- [ ] **Rotation:** `AVCaptureDevice.RotationCoordinator` — one per camera, created after preview layer is in a
      window, read then observe both angles, reapply on new outputs; disable sensor-orientation compensation
- [ ] **Mirroring** follows camera direction; capture and preview mirroring consistent
- [ ] **iPhone Duo cameras:** individual inner/outer front cameras (not the virtual front camera); select via
      `AVCaptureDeviceDirectionCoordinator` (main actor) → pass `AVCaptureDeviceDescriptor` to the actor; switch
      cleanly on open/close/flip; `dynamicAspectRatio` for the square sensors
- [ ] Mid-capture device change (fold/unfold/flip) → pause current angle, re-gate, resume — never lose captured angles
- [ ] Retake works (single angle and full)

### 1.3 Quality gates

- [ ] Gate evaluator (pure, testable) with inputs: face box, landmarks pose, luma stats, sharpness, motion
- [ ] Distance/size + centering (re-enable and fix the commented-out logic, in normalized coordinates)
- [ ] Pose via landmarks (yaw/pitch/roll) — front and side targets per PLAN §11.1
- [ ] Light: mean Y-plane luma inside face box + clipped % (fix the BGRA misread; sample, don't loop every pixel)
- [ ] Sharpness: Laplacian variance on face crop (vImage/Core Image), per-device calibrated floor
- [ ] Stillness: box-center delta + CoreMotion gyro, sustained ≥ 0.7 s
- [ ] `DetectFaceCaptureQualityRequest` > 0.5; best-of-5 burst
- [ ] Gate state published to UI at ≤ 15 Hz (no `@Published` sample buffers)
- [ ] Manual capture fallback after 20 s of failing gates (flagged in scan metadata)

### 1.4 Inference & scoring

- [ ] `AcneDetector` actor: load model once; Swift Vision `CoreMLRequest`; off-main
- [ ] Square face crop with margin in pixel space; correct orientation; no 224 downscale; evaluate `.scaleFill` vs
      416 tiling for small lesions (benchmark decides)
- [ ] Explicit confidence threshold (start 0.4; tune on benchmark) + cross-class NMS
- [ ] Zone assignment (2D landmark zones now; mesh zones in Phase 4)
- [ ] Cross-angle dedupe by zone ownership
- [ ] Breakout Index + bands relative to user baseline (replaces public GEA); keep `legacyGEA` for old scans
- [ ] Persist detections (type, confidence, normalized bbox, angle, zone) + `modelVersion` + capture metadata

### 1.5 Spikes (time-boxed, decisions recorded in PLAN §2)

- [x] ~~ARKit on iPhone Duo (Q8)~~ — decided: **Duo = 2D only** (no Face ID sensor)
- [ ] **ARKit-based gating on Face ID iPhones:** compare ARKit pose/distance vs Vision gates for consistency
- [ ] **Tabletop scan feasibility** (inner camera in tabletop pose): framing, distance, lighting

**Deliverables:** new capture + inference pipeline behind the existing UI; benchmark report; spike decisions.

**Exit criteria:**
- [ ] Benchmark: severity-band agreement across repeats ≥ 90%; per-type count CV ≤ 25% (or targets revised with
      evidence and recorded in PLAN §2)
- [ ] Analysis of 3 captures < 2.5 s on the oldest supported device; UI never freezes
- [ ] Zero crashes across: denied permission, retake, < 3 captures, fold/unfold/flip mid-scan (hardware), rotation
- [ ] Captured image orientation + mirroring correct in every orientation and Duo pose (hardware)
- [ ] ≥ 80% coverage on gates, scoring, dedupe, zone assignment, state machine

**Risks:** detector is the ceiling (→ Q3 retraining track); Duo hardware access for testing.

---

## Phase 2 — Brand & design system

**Goal:** A distinctive, non-generic identity and the token/motion/haptics system every screen will use. Runs in
parallel with Phase 1.

**Skills/agents:** `swiftui-expert-skill` (liquid-glass, animation-basics/advanced/transitions, previews, accessibility
patterns), `swiftui-pro` (design, accessibility), agent `a11y-architect`.

### 2.1 Brand decisions

- [ ] Resolve Q1 (rename?) and Q2 (direction A/B/C) — record in PLAN §2
- [ ] If renaming: shortlist per PLAN §6.2 criteria; check App Store + domain availability; pick
- [ ] Moodboard + 3 key-screen mock comparisons (Today, Scan, Result) per direction before committing
- [ ] Contour motif generator: from a face mesh (or canonical mesh for marketing) → topographic SVG/`Path`
- [ ] App icon (light, dark, tinted, clear variants for iOS 26 icon styles); alternate icons optional

### 2.2 Tokens (`SkinalyzeKit/DesignSystem`)

- [ ] Color tokens (PLAN §6.3) as asset-catalog colors with light/dark/high-contrast variants; contrast-checked
- [ ] Severity ramp, color-blind checked (deuteranopia/protanopia/tritanopia simulations)
- [ ] Type scale (New York display/numerals + SF Pro UI), Dynamic Type only, AX layout switches
- [ ] Spacing (4-pt grid), radius set (≤ 4 values), elevation (≤ 2 levels), hairline width
- [ ] Glass usage helpers (`GlassEffectContainer` patterns) for the three allowed custom-glass surfaces

### 2.3 Motion & haptics

- [ ] `Motion` tokens (snappy, smooth, expressive, gentle, stagger, reduced) + `Motion.resolve()` for Reduce Motion
- [ ] `Haptics` vocabulary via `.sensoryFeedback` (PLAN §7.3) + rate limiter
- [ ] Shared effects: numeric content transitions, symbol effects, scroll transitions, zoom navigation helper
      (single shared namespace), contour "draw" effect, sweep shader (`layerEffect`) prototype
- [ ] Motion spec sheet: each signature moment (PLAN §7.5) storyboarded with timing before implementation

### 2.4 Components

- [ ] Buttons (primary/secondary/tertiary, loading/success morph), chips (multi-select with sliding highlight), cards,
      list rows, section headers, delta badge (▲▼ + color + text), severity band pill, empty state, error state,
      inline validation field, segmented control styling, progress ring (5-segment), lesion-type glyphs (SF Symbol
      format, 6 types)
- [ ] Component gallery screen (debug-only) showing every component in all states

### 2.5 Voice & copy

- [ ] Copy guide (PLAN §6.8, §15.1) + String Catalog set up with English + Bahasa Indonesia
- [ ] Rewrite all existing strings (fix typos; remove diagnostic language)
- [ ] Short, accurate camera usage string; privacy promise copy

**Deliverables:** brand decision, icon, tokens, motion/haptics system, component library + gallery, copy guide.

**Exit criteria:**
- [ ] Every component renders correctly in light/dark, AX5, Increase Contrast, Reduce Motion, Reduce Transparency
- [ ] Component gallery reviewed against PLAN §6.7 anti-slop rules (explicit sign-off)
- [ ] All text tokens ≥ 4.5:1 contrast; severity ramp passes color-blind simulation with labels
- [ ] Zero raw hex values or fixed font sizes in `DesignSystem` consumers (lint)

**Risks:** endless brand iteration (time-box direction choice); motion over-design (one hero per moment).

---

## Phase 3 — App shell, core screens & adaptive (Duo) layouts

**Goal:** Ship the new app experience on every iPhone shape and pose: new IA, onboarding, Today, scan UI, result,
timeline, compare, products, profile/settings — 2D results for now (3D arrives in Phase 4).

**Skills/agents:** `swiftui-expert-skill` (layout, lists, scroll, sheets, navigation, charts, iphone-duo, liquid-glass,
animation), `iphone-duo-readiness` → `iphone-duo-adaptive-layout`, `iphone-duo-dual-pane-patterns`,
`iphone-duo-vertical-bars`, `iphone-duo-design-review`, `swiftui-pro` for review, agents `a11y-architect`,
`swift-reviewer`, `e2e-runner` (XCUITest).

### 3.1 Shell & navigation

- [ ] `TabView` with `Tab` API: Today · Timeline · Products · Search (`role: .search`); `.sidebarAdaptable` on regular width
- [ ] Scan as a primary action (Today button + evaluate `tabViewBottomAccessory` pill); scan flow as `fullScreenCover`
- [ ] `AppRouter` per-tab typed paths; deep links (`skinalyze://…`); `@SceneStorage` restoration
- [ ] Vertical bars on Duo: toolbar item ordering, symbol vs text, overflow, visibility priority
- [ ] `Layout` helpers in `SkinalyzeKit/Layout`: reserved-region-aware modifiers, `ArrangementView` wrappers,
      `HingeProgress` normaliser, preview device-state configurations

### 3.2 Onboarding (PLAN §10.1)

- [ ] Paged flow with progress + back; goals, skin type (+ mini quiz), sensitivity, optional name/age range,
      optional products, privacy promise, camera priming, first-time coaching
- [ ] Remove fake chat, GIFs, gender-coded UI; correct Terms/Privacy titles
- [ ] Duo/landscape: split arrangement (illustration | question)

### 3.3 Today (PLAN §10.2)

- [ ] Last scan card, streak, scan-due prompt, routine preview, one insight slot (placeholder until Phase 6)
- [ ] Empty state; zoom transition into scan detail
- [ ] Duo unfolded two-column; outer-display glance optimized

### 3.4 Scan UI (on the Phase 1 engine) (PLAN §10.3)

- [ ] Live contour (2D landmark-based for now), 5-segment ring with gate haptics, single instruction line, angle tray,
      cancel, manual fallback, voice guidance setting
- [ ] Review screen with per-angle quality badges + single-angle retake
- [ ] Analysis screen (2D sweep version), cancellable, real progress
- [ ] Landscape HUD reflow; **tabletop hands-free mode** (active division region wider than tall → preview in raised
      half, controls in flat half) if the Phase 1 spike was a go
- [ ] Contextual "Start hands-free scan" suggestion when entering tabletop (hinge status, effect only)

### 3.5 Result / Scan detail (PLAN §10.4) — 2D version

- [ ] Photo carousel with pins overlay (from stored detections), zone overlay (2D zones)
- [ ] Headline vs previous scan, zone list with deltas, lesion-type multi-select filter, "What this means", products
      at the time, notes, disclaimer (calm styling)
- [ ] Duo unfolded / wide landscape: visual | data companion pane

### 3.6 Timeline & Compare (PLAN §10.5–10.6)

- [ ] Swift Charts trend (overall + per-zone toggles), scrubber with selection haptics, grouped list, empty state
- [ ] Compare selection (third replaces oldest + hint); compare screen with wipe slider (handle avoids reserved
      regions), deltas table, product changes between dates, earlier-left labelling
- [ ] Duo unfolded: list-detail for Timeline; dual view (before | after across the fold, no slider on the fold)

### 3.7 Products & Profile/Settings (PLAN §10.7, §10.9)

- [ ] Routine (AM/PM, reorder, check-off), shelf (active/paused/finished with dates), wishlist placeholder
- [ ] Product search by name + brand + ingredient; product detail
- [ ] Profile editing with onboarding components; neutral avatar
- [ ] Settings: reminders placeholder, biometric lock (branch on `biometryType`), iCloud status, language, voice
      guidance, delete all data, privacy, terms, about

### 3.8 Localization

- [ ] All new strings in String Catalogs (EN + ID); test long-string layouts

**Deliverables:** the redesigned app (2D results), fully adaptive across the device-state matrix.

**Exit criteria:**
- [ ] Every screen passes the Universal DoD, including all Duo poses and orientations in Device Hub
- [ ] `iphone-duo-readiness` audit passes with no open items; `iphone-duo-design-review` critique addressed
- [ ] Fold/unfold/rotate during: onboarding form input, mid-scan, compare, sheet presentation → no state loss
      (UI tests + manual Device Hub run)
- [ ] XCUITest E2E: onboarding → first scan (mock camera) → result → timeline → compare passes
- [ ] `performAccessibilityAudit()` passes on every screen
- [ ] No legacy screens remain in the navigation graph

**Risks:** biggest phase — split by workstream branches; Duo UI tested in simulator, camera bits need hardware.

---

## Phase 4 — 3D face scan & zones

**Goal:** The signature experience: a textured 3D face with pins, mesh-based zones, and zone tracking over time.

**Skills/agents:** `swift-concurrency` (texture baker actor), `swiftui-expert-skill` (animation, performance, trace
analysis), `iphone-duo-hinge-and-scenes` (hinge effects), `iphone-duo-camera`, agents `performance-optimizer`,
`swift-reviewer`. (No vendored RealityKit/ARKit skill — use Apple docs/WWDC.)

### 4.1 Capture

- [ ] ARKit face-tracking capture path (`isSupported` gate) reusing Phase 1 gates (ARKit pose/distance)
- [ ] Store per capture: mesh vertices, face transform, camera intrinsics/transform; `captureMode` recorded
- [ ] iPhone Duo: 2D path with landmark zones (decided — no 3D on Duo); 3D UI entry points hidden there

### 4.2 Zones

- [ ] Author canonical zone vertex sets (forehead, nose, L/R cheek, chin, L/R jaw) against the 1,220-vertex topology;
      visual validation tool (debug)
- [ ] Map detections → mesh (ray/projection → `vertexIndex` + barycentric) → zone
- [ ] Replace 2D zone assignment for 3D-captured scans; keep 2D zones for 2D scans; never mix silently in trends

### 4.3 Texture & viewer

- [ ] Texture baking v1: front capture only, UV-space projection
- [ ] v2: blend front/left/right by normal-to-camera weight with seam feathering (Metal compute if needed)
- [ ] `RealityView` viewer: limited orbit, pinch, double-tap reset, zone overlay material, pins (billboards), tap
      callouts, Liquid Glass legend
- [ ] Accessible alternative: zone list with counts/deltas (VoiceOver), viewer hidden from AX tree appropriately

### 4.4 Motion (signature moments)

- [ ] Scan ring around live mesh contour; oval → contour morph
- [ ] Analysis sweep shader over the mesh; pins pop in with stagger; counts tick
- [ ] Result settle animation; delta chips from zones
- [ ] Hinge-driven rotation effect (`HingeProgress`, `isEnabled` only when visible) + drag fallback on other iPhones
- [ ] Reduce Motion variants for all of the above

### 4.5 Integrations

- [ ] Result/detail, Timeline (3D thumbnail + per-zone small multiples), Compare (synced dual viewers or wipe
      material) upgraded to 3D where available
- [ ] Legacy/2D scans render gracefully in 3D contexts (photo card fallback)

**Deliverables:** 3D scan, viewer, zones, zone trends, signature motion.

**Exit criteria:**
- [ ] Zone assignment consistency: same face, 5 repeats → per-zone band agreement ≥ 90% (benchmark extension)
- [ ] Texture bake < 2 s; viewer at 60/120 fps on supported devices; memory < 350 MB peak during scan
- [ ] Works on Face ID iPhones (3D) and on iPhone Duo + any unsupported device (2D, no 3D entry points) — verified on hardware
- [ ] All motion has Reduce Motion fallbacks; VoiceOver zone list complete

**Risks:** texture seams (ship v1 front-only first); Duo face tracking (fallback is first-class).

---

## Phase 5 — Product Check

**Goal:** "Is this good for me?" from Safari, other apps, screenshots, labels, and Visual Intelligence — answered on
device by a deterministic engine.

**Skills/agents:** `swift-concurrency`, `swiftui-expert-skill` (sheets, accessibility, liquid-glass), `iphone-duo-dual-pane-patterns`
(companion pane), agents `tdd-guide`, `security-reviewer` (extension data access).

### 5.1 Data & licensing

- [ ] Resolve Q5 (catalog licensing); if needed, plan own catalog
- [ ] Curate `ingredients.json` (canonical INCI, EN/ID aliases, categories, comedogenic ratings with sources,
      irritancy, conflict pairs)
- [ ] Resolve product photo source consistent with privacy copy

### 5.2 Ingredient engine (`SkinalyzeKit/Ingredients`) — tests first

- [ ] INCI parser (normalization, splitting, OCR error correction via fuzzy alias match, "may contain", parentheticals)
- [ ] Catalog matcher (title/brand fuzzy match; barcode if available)
- [ ] Rules engine → verdict + ranked reasons (rule IDs); personalization from profile, latest scan lesion mix,
      routine, effectiveness history (stubbed until Phase 6)
- [ ] Golden-case suite (≥ 100 cases across skin types/sensitivities/lesion mixes)
- [ ] Foundation Models assist: `@Generable ParsedIngredientList` for messy OCR; phrasing with template fallback;
      availability checks (Q4: Indonesian)

### 5.3 Share extension (`ProductCheckShare`)

- [ ] Activation rules: web URL, text, image
- [ ] Safari JS preprocessing to read JSON-LD `Product` / `og:title` in-page (no extra network fetch)
- [ ] OCR for images (`RecognizeTextRequest`; evaluate `RecognizeDocumentsRequest`)
- [ ] Verdict card UI (glass card, verdict + reasons + actions); motion per PLAN §7.5.6
- [ ] Actions: add to routine, save to wishlist, open in app (best effort) — via App Group store
- [ ] Memory budget < 80 MB; no ML/3D in extension

### 5.4 In-app

- [ ] Label/barcode scanner (VisionKit `DataScannerViewController`)
- [ ] Product Check history; wishlist; product detail shows personal ingredient highlights
- [ ] Duo unfolded: companion pane (product + ingredients | verdict + routine fit)

### 5.5 Visual Intelligence & intents

- [ ] App Intents visual-intelligence integration (screenshot/camera search → matching products → verdict)
- [ ] "Check a product" App Intent (text/image input)

### 5.6 Optional cloud (only if Q6 = yes)

- [ ] Proxy backend design, App Attest, rate limits, consent sheet, privacy label update — separate decision doc first

**Deliverables:** ingredient engine, share extension, in-app scanner, Visual Intelligence entry.

**Exit criteria:**
- [ ] Golden cases 100% pass; parser accuracy ≥ 95% on OCR fixture set (EN + ID labels)
- [ ] Share flow works from Safari, Photos, and at least two shopping apps; verdict appears < 1.5 s
- [ ] Extension memory < 80 MB under worst-case image
- [ ] No verdict copy fails the banned-terms check; LLM output validated before display
- [ ] Privacy: no network calls from the extension (verified with network instrument)

**Risks:** catalog licensing; OCR quality on curved/shiny labels (fallback: let user crop/confirm parsed list).

---

## Phase 6 — Insights, routine & habit

**Goal:** Turn scans and products into reasons to come back: trends, product effectiveness, routines, journal,
reminders, widgets, controls, intents, export, sync polish.

**Skills/agents:** `swiftui-expert-skill` (charts + charts-accessibility, lists), `swift-concurrency`,
`iphone-duo-hinge-and-scenes` (multiple scenes), agents `tdd-guide`, `security-reviewer` (HealthKit).

### 6.1 Insights engine (tests first)

- [ ] Trend rules (streaks up/down per zone, calmest in N weeks, scan gaps) with minimum-data thresholds
- [ ] Product effectiveness (PLAN §11.4) with caveated phrasing
- [ ] Phrasing via Foundation Models with template fallback; banned-terms validation
- [ ] Feed into Today insight slot, Product detail, Compare, Product Check personalization

### 6.2 Routine & journal

- [ ] Routine conflicts across steps; daily check-off → `RoutineLog`; streaks
- [ ] Trigger journal (tags, stress, notes); HealthKit opt-in (sleep, menstrual flow) → **local-only store**
- [ ] Correlation insights after ≥ 4 weeks, cautious language

### 6.3 System surfaces

- [ ] Widgets: small, medium, interactive routine checklist, Lock Screen circular/rectangular; tinted/clear modes
- [ ] Controls: Start scan, Check off routine
- [ ] App Intents / Shortcuts / Siri: Start scan, Log routine, Show my trend
- [ ] Reminders: scan cadence at a daylight time, AM/PM routine, actionable notifications

### 6.4 Export & sync

- [ ] Dermatologist PDF export (charts, zone table, selected photos, product timeline, notes, non-medical footer)
- [ ] Raw export (JSON + images); delete-all-data flow
- [ ] iCloud sync status UI + toggle; verify HealthKit-derived data never syncs

**Deliverables:** insights, routine/journal, widgets, controls, intents, reminders, export.

**Exit criteria:**
- [ ] Insight rules covered by tests with fixture histories; no insight fires below its data threshold
- [ ] Widgets/controls render correctly in all families and rendering modes; timeline updates after a scan
- [ ] HealthKit data verified absent from CloudKit (inspect dev container)
- [ ] PDF export legible, localized, and passes the banned-terms check

**Risks:** insight over-claiming (thresholds + review); notification fatigue (sane defaults, easy controls).

---

## Phase 7 — Trust, accessibility, performance & polish

**Goal:** Award-level finish: accessibility excellence, performance budgets met, privacy airtight, every detail
considered, App Store presence ready (when a release is eventually planned).

**Skills/agents:** `swiftui-expert-skill` (performance patterns, Instruments trace recording/analysis),
`swiftui-pro` (full review), `iphone-duo-design-review` (final critique), agents `a11y-architect`,
`performance-optimizer`, `security-reviewer`, `swift-reviewer`.

### 7.1 Accessibility pass

- [ ] Full VoiceOver walkthrough of every flow (incl. scan guidance announcements and 3D alternative)
- [ ] Voice Control, Switch Control spot checks; Dynamic Type AX5 on every screen and every Duo pose
- [ ] Reduce Motion / Transparency / Increase Contrast / Differentiate Without Color / Bold Text / Button Shapes

### 7.2 Performance pass

- [ ] Instruments traces (SwiftUI template on device) for: launch, scan, analysis, timeline scroll, fold/unfold
- [ ] Fix hitches and excessive view updates; verify all PLAN §17 budgets on oldest supported device + Duo
- [ ] App size audit (GIFs gone, catalog merged, model compression evaluated)

### 7.3 Privacy & compliance

- [ ] Privacy policy + nutrition label updated; App Review notes drafted (face data usage, non-diagnostic stance)
- [ ] Banned-terms lint clean across app, extension, widgets, PDF
- [ ] Security review of App Group data, extension, HealthKit, export

### 7.4 Polish

- [ ] Motion review of every signature moment against the spec (timing, interruptibility, one hero per moment)
- [ ] Haptics review (no chatter, correct vocabulary)
- [ ] Empty/error/loading states audit on every screen
- [ ] Final `iphone-duo-design-review` across closed / open / book / tabletop / tent
- [ ] App Store assets (when release is planned): screenshots across iPhone + Duo sizes/poses, preview video
      (the `hyperframes` skills can produce a launch video), localized metadata

**Exit criteria:**
- [ ] All PLAN §16 accessibility requirements verified; zero audit failures
- [ ] All PLAN §17 performance budgets met on hardware
- [ ] Security review: no CRITICAL/HIGH findings open
- [ ] Owner sign-off on motion, copy, and Duo experience

---

## After the redesign: growth, engagement and paywall

The backlog agreed on 2026-11-19 (Pimpi mascot, streaks and quests, sharing, product features, paywall) is tracked in
[FEATURES.md](FEATURES.md), with its own rules; its build phases are in [FEATURE-PHASES.md](FEATURE-PHASES.md).
Tick items there as they ship.

---

## Cross-phase tracks (run continuously)

| Track | Starts | Notes |
|---|---|---|
| Consistency benchmark | Phase 1 | Re-run on every capture/inference change; results in `docs/redesign/benchmarks/` |
| Detector retraining (Q3) | After Phase 1 baseline | Only if the benchmark shows the model is the bottleneck |
| Copy & localization | Phase 2 | Every new string EN + ID; banned-terms lint in every phase |
| Device-state verification | Phase 0 audit, enforced from Phase 3 | Device Hub matrix + hardware for camera |
| Decision log hygiene | Always | Every decision → PLAN §2; every answered question → out of PLAN §3 |
