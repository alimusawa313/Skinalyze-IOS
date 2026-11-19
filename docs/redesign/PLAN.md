# Skinalyze Redesign — Master Plan

> **Status:** Planning · **Last updated:** 2026-11-18 · **Build order:** [PHASES.md](PHASES.md) · **Rules:** [/CLAUDE.md](../../CLAUDE.md)
>
> This is a living document. Update the **Decision Log** when something is decided, tick items in **§20 Master Tracker**
> as phases complete, and move resolved items out of **Open Questions**. "Skinalyze" is used as the working name until
> the rebrand naming decision is made.

---

## Table of contents

1. [North star](#1-north-star)
2. [Decision log](#2-decision-log)
3. [Open questions](#3-open-questions)
4. [Current-state audit](#4-current-state-audit)
5. [Product principles](#5-product-principles)
6. [Brand & visual identity (rebrand)](#6-brand--visual-identity-rebrand)
7. [Motion & interaction system](#7-motion--interaction-system)
8. [Information architecture & navigation](#8-information-architecture--navigation)
9. [Device & layout strategy — every iPhone, including iPhone Duo](#9-device--layout-strategy--every-iphone-including-iphone-duo)
10. [Screen specifications](#10-screen-specifications)
11. [Feature specifications](#11-feature-specifications)
12. [AI & ML architecture](#12-ai--ml-architecture)
13. [Data model & migration](#13-data-model--migration)
14. [Technical architecture](#14-technical-architecture)
15. [Privacy, safety & App Review compliance](#15-privacy-safety--app-review-compliance)
16. [Accessibility requirements](#16-accessibility-requirements)
17. [Performance budgets](#17-performance-budgets)
18. [Testing & quality strategy](#18-testing--quality-strategy)
19. [Risk register](#19-risk-register)
20. [Master tracker](#20-master-tracker)
21. [References](#21-references)
22. [Agent skills](#22-agent-skills-vendored-in-claudeskills)

---

## 1. North star

**One sentence:** The most trustworthy, private, and delightful way to *see how your skin is changing* — and to know
which products are actually helping.

**What "Apple Design Award-worthy" means for us, concretely:**

| ADA category | How we earn it |
|---|---|
| Delight & Fun | A scan that feels like a ritual: live face contour, gate-by-gate haptics, a 3D face you can spin, pins that pop in |
| Innovation | TrueDepth 3D zone tracking over time; product verdicts from the share sheet & Visual Intelligence; tabletop hands-free scan on iPhone Duo |
| Interaction | Every state change is animated with intent; fold/unfold/rotate are first-class moments, not edge cases |
| Inclusivity | Works for every skin tone, every Dynamic Type size, VoiceOver-guided scanning, Reduce Motion paths, Bahasa Indonesia + English |
| Social Impact | Private-by-default, on-device AI, honest non-diagnostic language, dermatologist export |
| Visuals & Graphics | A distinctive editorial identity built from the user's own face-mesh contours — not a template |

**Why the current app feels "basic & inconsistent"** (root causes, not symptoms):

1. The scan pipeline has no real quality gates, so results vary run-to-run (§4.1). No amount of visual polish fixes this.
2. There's no design system: ~15 asset colors, hard-coded hexes, 8+ corner radii, 27 fixed font sizes (§4.5).
3. Motion is almost absent (a handful of `withAnimation` calls) and the one transition attempt is broken (§4.6).
4. The app shows data (counts, a severity label) but no *insight* (trends, causes, what to do).

---

## 2. Decision log

| Date | Decision | Rationale |
|---|---|---|
| 2026-11-18 | **Minimum iOS 26.0**; build with iOS 27.1 SDK | Native Liquid Glass, Foundation Models, Swift Vision API, RealityView, zoom transitions with no back-compat branches. 27.1 SDK needed for iPhone Duo APIs (gated with `#available`). |
| 2026-11-18 | **Full rebrand** (visual identity; name TBD — see Q1) | Current mocha look is dated and inconsistent. |
| 2026-11-18 | Release strategy **deferred**; phases are build order, not release trains | Owner's call. |
| 2026-11-18 | **Commit locally only, never push** until owner says otherwise | Owner's call. Codified in `/CLAUDE.md` §5. |
| 2026-11-18 | **Hybrid AI**: deterministic rules engine decides; on-device Foundation Models phrases/parses; optional opt-in cloud only for identifying unknown products; face data never leaves device | Consistency, testability, App Review safety, privacy, cost, offline. See §12. |
| 2026-11-18 | **3D TrueDepth face scan** is a centerpiece feature, with 2D fallback | Fixed ARKit mesh topology enables per-zone tracking over time + better pose gating. |
| 2026-11-18 | **Product Check** via Share Extension shows verdict **inside the share sheet** | Share extensions can't officially open the host app; in-sheet verdict is also the better UX. |
| 2026-11-18 | **iPhone Duo is a first-class target**: all orientations, closed, partially folded, unfolded | Owner requirement. Codified in `/CLAUDE.md` §1. |
| 2026-11-18 | **RealityKit** for 3D (not SceneKit) | SceneKit is soft-deprecated; RealityView is the forward path. |
| 2026-11-18 | **3D scan is "ARKit face tracking where `isSupported`", not "TrueDepth only"** | iPhone Duo has **no Face ID / TrueDepth / LiDAR** (Touch ID in side button). ARKit face tracking also runs on A12+ front cameras without TrueDepth (ML-estimated mesh, same topology). Duo support must be confirmed on hardware; 2D path is the fallback. |
| 2026-11-18 | **iPhone Duo = 2D scan path only (no 3D face model)** | Owner confirmed: Duo has no Face ID sensor, so 3D face modeling isn't supported there. Duo gets the 2D capture + landmark zones, tabletop hands-free scan, and photo-based results/compare. 3D stays for Face ID iPhones. |
| 2026-11-18 | **Biometric lock, not "Face ID lock"** — branch on `LAContext.biometryType` | Duo uses Touch ID. |
| 2026-11-18 | **Vendored agent skills** in `.claude/skills/` (see §22) | No adequate native iOS design/motion/Duo skills were installed; vetted MIT-licensed community skills added. |
| 2026-11-18 | Position as **tracker, not diagnosis**; drop the public "GEA" label | Prior App Review 1.4.1 rejection; the current formula isn't a clinical GEA anyway. |

---

## 3. Open questions

| # | Question | Needed by | Notes |
|---|---|---|---|
| Q1 | Does the rebrand include a **new app name**? | Phase 2 start | Affects icon, App Store listing, Share sheet label, bundle display name. Bundle ID stays. |
| Q2 | Which **brand direction** (§6.1 A/B/C)? | Phase 2 start | Recommendation: A "Field Notes". |
| Q3 | Do we have (or can we get) the **training dataset** for the acne detector to retrain/tune? | Phase 1 end | Benchmark (§18) will tell us if the model is the bottleneck. |
| Q4 | Is **Bahasa Indonesia** supported by Apple Intelligence / Foundation Models? | Phase 5 | Determines whether ID users get LLM phrasing or template fallback. |
| Q5 | **Licensing** of the bundled product catalog (appears sourced from skinsort.com) | Phase 5 start | Need rights to use names, ingredient lists, and photos; otherwise build our own catalog. |
| Q6 | Opt-in **cloud product identification** — do we want it at all? | Phase 5 | Needs a proxy backend + consent flow. Can ship without it. |
| Q7 | **Monetization** (none / one-time / subscription)? | Before Phase 6 | **Answered 2026-11-19:** free core + Pro subscription (and optional lifetime) — see [FEATURES.md](FEATURES.md) §6. Price points still open. |
| Q8 | ~~Does ARKit face tracking work on iPhone Duo?~~ | — | **Answered 2026-11-18: no 3D on Duo** (owner decision, see §2). Remaining Duo camera facts: Duo has two front cameras (inner under-display, outer ultra-wide, both square sensors), no TrueDepth. Camera selection via `AVCaptureDeviceDirectionCoordinator` (AVKit). Face tracking support needs a **real device** — the simulator has no camera. |
| Q9 | Exact iPhone Duo API signatures | — | **Answered** by the vendored `iphone-duo-*` skills: `onHingeChange { old, new in }` → `DeviceHingeContext.hinge: DeviceHinge?` (`angle`, `status: .closed/.partiallyOpen/.fullyOpen`); `UIHingeInteraction`; `proxy.reservedRegions(kind: .division)` with `isActive`; `ArrangementView(.split / .overlay)`. Still compile-check in Xcode 27.1. |

---

## 4. Current-state audit

Paths are relative to the repo root. Findings come from a full read of the source on 2026-11-18. The top items were
spot-checked against the code by hand.

### 4.1 Why scans are inconsistent (ranked by likely impact)

| # | Root cause | Evidence | Effect |
|---|---|---|---|
| 1 | **Distance & in-oval gating are commented out** — `faceDistanceStatus` is always `"Normal"`, `isFaceInCircle` always `true` | `Skinalyze/ViewModels/FaceTrackingViewModel.swift:128-152` | Face size in crop is uncontrolled → lesions appear at wildly different pixel scales |
| 2 | **Exposure locked at session start** (`exposureMode = .locked`) | `FaceTrackingViewModel.swift:69` | Brightness depends on the room at launch; color-based classes (dark spot, pustule, papule) swing |
| 3 | **Brightness gate reads the wrong pixel format** — default 420YpCbCr parsed as BGRA, full-frame Swift loop per frame | `FaceTrackingViewModel.swift:165-176, 209-218` | Lighting check is garbage + drops frames |
| 4 | **Double/triple counting across angles** — counts from front/left/right are summed | `ResultViewModel.swift:160-170`, `AnalyzedResultView.swift:398-403` | Cheeks counted 2–3× depending on head turn |
| 5 | **Resolution destroyed** — crop → "224×224" (`UIGraphicsImageRenderer` at screen scale → 448/672 px, device-dependent) → Vision rescales to model's 416 with default `.centerCrop` | `ResultViewModel.swift:343-345` | Small comedones vanish; results differ per device |
| 6 | **Crop ≠ what the user sees** — aspect-fill preview vs non-uniform point→pixel scaling; capture not mirrored while preview is | `CameraScanView.swift:402-421`, `CameraView.swift:59` | Crop ~20% wider than oval, varies per device |
| 7 | **No sharpness / stillness gate**; capture is a single video frame up to 1 s after the last pose check | `CameraScanView.swift:328-356, 368` | Motion blur, noise |
| 8 | **Thresholds untuned** — model default conf 0.25, per-class NMS only | model metadata | One lesion can be counted under two classes |
| 9 | **Severity bug**: reads `acneCounts["blackhead"]`, key is `"blackheads"` | `ResultViewModel.swift:177` | Blackhead-only faces score "Healthy" |
| 10 | Pose check coarse (yaw ±0.5 rad from face-rect request), pitch/roll ignored | `FaceTrackingViewModel.swift:94-99` | Side shots vary in angle |
| 11 | State not reset on re-analysis (`boundingBoxImages`, `detectedResults`) | `AnalyzedResultView.swift:392` | Mismatched overlays, extra saved entries |
| 12 | View model re-instantiated: `@ObservedObject var viewmodel = ResultViewModel()` | `AnalyzedResultView.swift:18` | Results lost on view re-init; `geaScale` starts at 1 → shows "Mild" before analysis |
| 13 | **Saved logs are re-analyzed on open** (on a re-encoded JPEG) | `Views/Detail/NewDetailViewTest.swift:100` | A saved result can change after the fact |

### 4.2 Bugs & crash risks

- Step counter advances even when no frame was captured (`CameraScanView.swift:368-373`) → scans with <3 images →
  **crash** on force unwraps in `NewCompareView.swift:274,285`.
- Model reloaded per image (`ResultViewModel.swift:352`) and run synchronously on the main thread
  (`AnalyzedResultView.swift:398-403`) → UI freeze; spinner never animates.
- Possible re-analysis loop when detection returns nil (`AnalyzedResultView.swift:95-110`).
- `Timer` with 0.0 s interval spins the main thread and fires a heavy haptic on every tick (`CameraScanView.swift:296-311`);
  countdown timer not stored, so cleanup can't invalidate it.
- **Retake is broken**: `onDisappear` sets `isCameraLoaded = false`; returning never restarts → "Loading Camera…" forever
  (`CameraScanView.swift:36-47`, `CapturedImagesView.swift:59`).
- Session lifecycle: `stopRunning` dispatched to main (`FaceTrackingViewModel.swift:43`); `deinit` uses `[weak self]` so
  it never stops; `.background` QoS start; double start in `tutorDone`.
- **No camera permission handling** — denied = silent black screen.
- `@Published lastSampleBuffer` (`FaceTrackingViewModel.swift:17`) holds pool buffers and re-renders the view ~30×/s.
- Force unwraps on severity lookup (`AnalyzedResultView.swift:160-161`); silent model-load failure (`ResultViewModel.swift:353-356`).
- `MaskotNone` image referenced but missing from the asset catalog (`OnboardingChatView.swift:439`).
- `ResizableGIFPlayer` frame bug: `width: 2*scale` (`Tools/Gif Player.swift:106`).
- Color-name case mismatches to verify: `"textPrimary"` used 51× vs asset `TextPrimary`; `"TextReverse"` used 8× vs asset `textReverse`.
- `project.yml` lists `resources: [Resources]` — folder doesn't exist. No deployment target set.

### 4.3 Architecture & code health

- One `NavigationStack` with a `Router` enum, but `LogView` and Profile also nest `NavigationView`s.
- Duplicate/dead routes & screens: `detailView`/`newDetailView`, `compareImagesView`/`newCompareImagesView`,
  `prodUsed`/`productUsedView`; `DetailVIew`, `CompareView`, `ContentCell`, `ScrollCell`, `CameraSheetTutor`,
  `CardStackView`, `CameraView`, `temp` (`MainView.swift:87`), `LottieView` (fully commented).
- "Test" files in production: `NewDetailViewTest.swift`, `ProductTest.swift` (holds `ProductSearchView`).
- Fake Scan tab: an empty `Text("")` tab that pushes the camera and snaps selection back (`MainView.swift:45-72`).
- `ObservableObject` everywhere; view models instantiated inline as `@ObservedObject`.
- Two overlapping product catalogs: `SkincareProducts1.json` (458, with ingredients, 610 KB) and
  `FinalSkincareProductElFinale.json` (459, with photo URLs, 288 KB).
- ~300-line copy-pasted product slot blocks in both `ProductUsedView` and `ProductUsedSaved`.
- Result/Detail/Compare are near-duplicate code paths.
- 2.2 MB of GIFs (`Hover.gif`, `Timeline.gif`) for a loader and a splash.
- No tests at all.

### 4.4 UX problems by screen

| Screen | Problems |
|---|---|
| Splash | System-blue checkbox gate; "Terms and Conditions" link opens a sheet titled "Privacy Policy"; GIF sizing bug |
| Chat onboarding | Fake chat wrapping a 6-field form; fixed 1.5 s fake typing; empty name accepted; no age validation; gender Female/Male only (EditProfile has "Other"); typos ("ares", "when try new products"); options are `Text`+`onTapGesture` (invisible to VoiceOver); no progress, no back |
| Tab bar | Fake Scan tab flickers selection; tint flips to white while camera open |
| Camera | Tips sheet on *every* scan; ALL-CAPS 12 pt status chips; low-contrast red @25%; fixed 350×450 oval; instructions triplicated (chip + center text + step icons); no explicit cancel |
| Captured images | Plain pager + two buttons |
| Result / Detail | Long vertical stack without hierarchy; page dots hard-coded to 3; severity bar labelled Healthy…Severe but scale goes to Extremely Severe; 4×10 tick marker; "Select All" mixed into chip filters, single-select only; red bordered "Click to see from where we get these recommendations from"; red disclaimer; "Product Used" tab shows Add buttons on a read-only view; invisible "12345" spacer hack; no summary, no "what changed" |
| Face Log | No empty state; every row repeats a 3-line severity paragraph; compare allows exactly 2 with no feedback on a 3rd; magic negative padding |
| Compare | Re-analyses 6 images on appear with no loading UI; raw enum text (`verySevere`); newer log on the left; unlabelled dates; slider handle is a plain white circle |
| Products | Four hand-copied slots; placeholder shrinks to 50×50 on 3 of 4; search matches brand only; grey placeholder for network images |
| Profile | Gender-coded pink/blue avatar; `.foregroundColor(.black)` breaks dark mode; age not shown; "Saved Products" row isn't a button |

### 4.5 Current design language (to be replaced)

- **Palette:** warm mocha — `brownPrimary #DCD2C9/#564A47`, `brownSecondary #6F5750/#DCD2C9`, `btnClr #74574F`, plus
  ~12 more near-duplicates. Hard-coded hexes duplicate asset colors in 5+ places. System `.blue`, `.red`, `.pink`, `.gray`
  used ad hoc. Light-only colors (`Atas`, `brownTest`) break dark mode.
- **Type:** mostly semantic, but 27 fixed `.system(size:)` calls; `Quattrocento Sans` referenced but not bundled;
  `.custom("", size: 15)`.
- **Radii:** 8, 10, 16, 20, 30, 100, 200, Capsule, `height*0.05`. Primary buttons are capsule in some places, rounded
  rect in others.
- **Layout:** `UIScreen.main.bounds` everywhere; invalid `frame(width: .infinity)`.
- **Shadows:** only in chat.

### 4.6 Current motion inventory

- `withAnimation(.bouncy)` on accordions; `.smooth` on compare toggle; default on delete; chat scroll/append; a 3-dot
  typing indicator.
- `matchedTransitionSource` on log thumbnails, but the `.navigationTransition(.zoom)` is commented out — and uses a
  per-row `@Namespace`, so it couldn't work.
- One heavy haptic fired from a repeating timer. AVSpeechSynthesizer voice guidance on camera.
- **Never used:** transitions, `contentTransition`, `symbolEffect`, `sensoryFeedback`, `PhaseAnimator`,
  `KeyframeAnimator`, `scrollTransition`, shaders.

### 4.7 Data & persistence

- SwiftData, single `Result` model. **Images stored as base64 `String`s at JPEG quality 1.0**, ~9 per scan
  (3 originals + 3 byte-identical "analyzed" copies + 3 overlay images saved as JPEG, losing transparency).
- **CloudKit sync is live**: `Skinalyze.entitlements` enables CloudKit container `iCloud.com.Patani.Skinalyze`, and the
  camera usage string tells users saved data is stored in iCloud. ⇒ the production CloudKit schema is **additive-only**;
  migrations must account for this (§13).
- Profile in `@AppStorage` (standard defaults) — not shareable with extensions.
- Product photos fetched from skinsort.com via `AsyncImage`, which contradicts the privacy copy that
  "all processing happens on your device".
- Portrait-only (`UISupportedInterfaceOrientations` = portrait) — must change (§9).

---

## 5. Product principles

1. **Consistency before cleverness.** A scan must give the same answer for the same face. Ship gates and benchmarks
   before eye candy.
2. **Tracker, not doctor.** We show change over time and patterns. We never diagnose, prescribe, or claim to treat.
3. **Private by design.** On-device ML, on-device LLM, no third-party data sharing; iCloud only via the user's own account.
4. **Your baseline, not a scary absolute.** Lead with "vs. your last scan" and per-zone trends, not "Extremely Severe".
5. **Calm, then delightful.** Motion serves orientation and feedback first; flourishes are reserved for real achievements.
6. **Every iPhone shape is the main shape.** Regular iPhone, Duo closed, partially folded, unfolded, every orientation.
7. **Inclusive by default.** Skin-tone-neutral UI, VoiceOver-guided scanning, Dynamic Type everywhere, two languages.

---

## 6. Brand & visual identity (rebrand)

### 6.1 Directions

| | **A. Field Notes** *(recommended)* | B. Soft Lab | C. Warm Ritual |
|---|---|---|---|
| Feel | Personal skin journal × lab notebook. Editorial, quiet, precise | Clinical-cool, glassy, precise | Evolution of today's mocha; clay & sand, rounded |
| Type | New York (serif) for display + numerals; SF Pro for UI | SF Pro + SF Mono numerals | SF Pro Rounded |
| Color | Bone paper, ink, one vivid signal accent | Porcelain, graphite, cobalt | Sand, clay, cocoa |
| Motif | Contour lines from the user's own face mesh | Grids, measurement ticks | Soft blobs, pebbles |
| Risk | Must keep warmth so it isn't austere | Can feel cold/medical; generic | Least distinctive; closest to "skincare template" |

**Why A:** it's ownable (the motif literally comes from *your* face), it signals care + rigor, and serif numerals make
data feel personal rather than clinical. It contrasts well with Liquid Glass chrome.

### 6.2 Naming criteria (if Q1 = rename)

- Short (≤ 10 chars), pronounceable in English and Bahasa Indonesia, not a medical term, available as App Store name +
  `.com`/`.app`, doesn't imply diagnosis ("Derm", "Doctor", "Clinic" ❌). Keep "Skinalyze" as subtitle during transition
  if renamed, to retain search ranking.

### 6.3 Color tokens (proposal for direction A — validate in Phase 2)

Semantic tokens only; views never reference raw values.

| Token | Light | Dark | Use |
|---|---|---|---|
| `canvas` | `#F6F3EE` bone | `#121110` | App background |
| `surface` | `#FFFFFF` | `#1C1A18` | Cards, sheet content |
| `surfaceRaised` | `#FBF9F6` | `#252220` | Nested surfaces |
| `ink` | `#1A1817` | `#F3EFEA` | Primary text |
| `inkSecondary` | `#6A645E` | `#A8A099` | Secondary text |
| `inkTertiary` | `#9C958E` | `#6F6862` | Captions, disabled |
| `hairline` | `#E5DED5` | `#34302C` | Dividers, contour lines |
| `signal` | `#E2553A` vermilion | `#FF6B4E` | The ONE accent: live state, primary action, scan ring |
| `signalSoft` | `signal` @ 12% | `signal` @ 18% | Selected chips, highlights |
| `positive` | `#2F7D5B` | `#5CC296` | Improvement deltas |
| `caution` | `#B7791F` | `#E3A44A` | Product "use with caution" |
| Severity ramp (5 steps) | `#E9E4DC → #E8C9A0 → #E0A06A → #C9674A → #8E3B3B` | lifted variants | Zone heatmap & bands — always paired with label + shape (never color alone) |

Rules: one accent per screen; severity ramp is perceptually ordered and color-blind-checked (deuteranopia/protanopia);
no gradients except the severity ramp on heatmaps; contrast ≥ 4.5:1 for text (≥ 7:1 with Increase Contrast).

### 6.4 Typography

- **Display & numerals:** New York (`.system(.largeTitle, design: .serif)`), tabular numerals for counts/scores.
- **UI text:** SF Pro, semantic text styles only (`.body`, `.subheadline`, …) — no fixed sizes.
- **Data labels:** SF Pro `.caption` with `.monospacedDigit()`.
- Scale: `display` (New York, largeTitle, bold), `title` (New York, title2), `headline` (SF, headline), `body`,
  `callout`, `footnote`, `caption`. All Dynamic Type; layouts reflow at AX sizes (horizontal → vertical).

### 6.5 Iconography & illustration

- SF Symbols first (with `symbolEffect`); custom SF-Symbol-format glyphs for the 6 lesion types (blackhead, whitehead,
  papule, pustule, nodule, dark spot) so they animate and scale like system symbols.
- **Signature motif:** contour lines generated from the user's face-mesh depth (topographic style). Used on: scan
  screen, analysis loader, empty states, onboarding, widgets, and (generic version) the app icon.
- No stock photos (remove the unused `imageTest`), no mascot-as-crutch; the old mascot can be retired or redrawn in
  the new style if Q2 wants personality.

### 6.6 Liquid Glass usage

- Use native glass: tab bar, toolbars, sheets, menus, search. Custom `glassEffect` only for: the scan controls overlay,
  the floating zone legend on the 3D face, and the share-extension verdict card. Group custom glass in
  `GlassEffectContainer` so morphs are coherent.
- Never stack glass on glass; never put body text on glass over busy imagery without a scrim.

### 6.7 Anti-"AI slop" rules (enforced in review)

- ❌ Purple/blue "AI" gradients, sparkle ✨ icons for AI features, "Powered by AI" badges.
- ❌ Glassmorphism on every card; drop shadows on everything; neon glows.
- ❌ Emoji as UI; generic 3D blob illustrations; stock smiling-model photos.
- ❌ Grids of identical rounded cards with an icon + title + subtitle.
- ❌ Confetti for routine actions; bounce on everything.
- ✅ Real data as the hero (your face, your trends). ✅ One accent. ✅ Editorial hierarchy (big serif number, quiet
  label). ✅ Motion that explains cause → effect. ✅ Copy that sounds like a knowledgeable friend.

### 6.8 Voice & copy

- Warm, direct, specific, non-judgmental. "Your chin is calmer than last week" — not "Acne severity: Moderate".
- Never: "diagnose", "treat", "cure", "condition", "disease", "prescription", "clinically proven" (unless sourced).
- Always offer a next step. Error copy says what happened + what to do.
- Bilingual: English + Bahasa Indonesia via String Catalogs from day one of Phase 3.

---

## 7. Motion & interaction system

### 7.1 Principles

1. **Motion explains.** Every animation answers "where did this come from / where did it go / what changed".
2. **Physical, interruptible.** Springs only for UI (no linear/ease curves), always interruptible by touch.
3. **One hero per moment.** At most one prominent animation at a time; everything else supports.
4. **Respect the user.** Reduce Motion → crossfades; Reduce Transparency → solid surfaces; haptics never the sole channel.

### 7.2 Tokens (`DesignSystem/Motion.swift`)

| Token | Definition | Use |
|---|---|---|
| `Motion.snappy` | `.spring(duration: 0.28, bounce: 0.12)` | Taps, toggles, chips, small state changes |
| `Motion.smooth` | `.spring(duration: 0.45, bounce: 0.0)` | Layout changes, navigation, sheets, fold/unfold re-layout |
| `Motion.expressive` | `.spring(duration: 0.6, bounce: 0.3)` | Reveals, achievements, pins popping in |
| `Motion.gentle` | `.spring(duration: 0.9, bounce: 0.0)` | Large ambient moves (contour drift, mesh rotation settle) |
| `Motion.stagger` | 0.035 s per item, max 10 items, then batch | Lists, pins, chips |
| `Motion.reduced` | `.easeInOut(duration: 0.2)` opacity-only | Reduce Motion fallback for all of the above |

### 7.3 Haptic vocabulary (`DesignSystem/Haptics.swift`, via `.sensoryFeedback`)

| Event | Feedback | Notes |
|---|---|---|
| Scrub tick (timeline, slider detents) | `.selection` | Max one per 60 ms |
| Chip / toggle / check | `.impact(weight: .light)` | |
| Scan gate satisfied (each segment) | `.impact(flexibility: .soft, intensity: 0.5)` | Rising sequence as gates complete |
| Scan gate lost | `.warning` (soft) | Only after gate held ≥ 0.3 s, to avoid chatter |
| Capture taken | `.impact(weight: .medium)` | Paired with shutter flash |
| Analysis complete / scan saved | `.success` | |
| Error (permission, failure) | `.error` | |
| Fold / unfold re-layout | none | Don't compete with the hardware moment |

Rule: never trigger haptics from a repeating timer; drive them from state changes with `.sensoryFeedback(trigger:)`.

### 7.4 Sound (optional, off by default except shutter)

Subtle shutter on capture (respects silent mode); voice guidance (existing AVSpeechSynthesizer) moves to an
accessibility setting and integrates with VoiceOver announcements.

### 7.5 Signature moments

1. **Scan — "The ring"**: The oval morphs into a live contour of the user's face from the TrueDepth mesh. Around it, a
   5-segment ring (Distance · Angle · Light · Sharpness · Stillness). Each segment fills with `Motion.snappy` + a soft
   rising haptic as its gate passes; when all 5 hold for 0.7 s the ring closes, flashes `signal`, captures, and the
   frame thumbnail flies (matched geometry) into a 3-slot tray. Next angle: a ghost of the target head pose rotates to
   show where to turn.
2. **Analysis — "The sweep"**: The captured texture wraps onto the 3D mesh (unfolding from the 2D photo), a contour
   sweep (SwiftUI `layerEffect` shader) passes over it, and detections pop in as pins with `Motion.expressive` +
   stagger, while lesion counts tick with `.contentTransition(.numericText())`.
3. **Result — "Your face, explained"**: The 3D face settles to front view (`Motion.gentle`); zone overlay fades in;
   headline number in New York serif counts up; "vs. last scan" delta chips slide in from their zones.
4. **Timeline — "Scrub through time"**: Horizontal scrubber with `.selection` ticks per scan; the face crossfades and the
   zone heatmap morphs between scans; trend chart cursor follows.
5. **Compare — "Before ↔ After"**: Slider wipe on 2D, or on 3D a split material that wipes across the mesh; on Duo
   unfolded, before/after sit on either side of the fold (no slider on the fold).
6. **Product Check — "Verdict card"**: Card rises in the share sheet, verdict word appears with a single symbol effect,
   reasons stagger in; "Add to routine" morphs into a check.
7. **Routine — "Check-off"**: Step row strikes through with a drawn line, symbol `.bounce`, light haptic; completing
   all steps draws a closing contour around the day in the week strip (no confetti).
8. **Fold / unfold (Duo)**: Layout re-arranges with `Motion.smooth`; the 3D face rotates in proportion to hinge angle
   while folding (effect only, §9.4).

### 7.6 Microinteraction catalogue

| Component | Microinteraction |
|---|---|
| Primary button | Press: scale 0.97 + slight darken (`Motion.snappy`); loading: label crossfades to progress; success: morph to check |
| Chips / filters | Multi-select; selected chip gains `signalSoft` fill with a matched-geometry highlight sliding between chips |
| Numbers | `.contentTransition(.numericText(value:))` everywhere a number changes |
| Symbols | `symbolEffect(.bounce)` on tap; `.variableColor` for in-progress states; `.replace` for state swaps |
| Lists | `.scrollTransition` — rows ease in scale/opacity at edges; swipe actions with haptic at threshold |
| Navigation | `.navigationTransition(.zoom(sourceID:in:))` from thumbnails/cards into detail (single shared `@Namespace`) |
| Sheets | Detents with interactive dismissal; background content dims/scales subtly |
| Pull to refresh (Timeline) | Contour line "draws" as you pull |
| Empty states | Slow ambient contour drift (`Motion.gentle`, paused when off-screen or under Reduce Motion) |
| Text fields | Validation shake (keyframes) + inline hint; never block with alerts |
| Option cards (onboarding) | Cards tilt slightly toward the touch point (`visualEffect`) |
| Widgets | `contentTransition` on numbers; interactive check-off |

### 7.7 Motion accessibility

- `@Environment(\.accessibilityReduceMotion)` checked in a single `Motion.resolve()` helper — no per-view branching.
- Shaders, mesh rotation, ambient drift, and parallax disabled under Reduce Motion; replaced with static frames + fades.
- Respect `accessibilityPlayAnimatedImages` for any looping media.

---

## 8. Information architecture & navigation

### 8.1 Tabs (iOS 26 `TabView` with `Tab` API)

| Tab | Purpose | Notes |
|---|---|---|
| **Today** | Latest state at a glance: last scan summary, streak, today's routine, "Scan now" | Profile/settings via avatar in toolbar |
| **Timeline** | All scans; trends; compare | Replaces Face Log |
| **Products** | Routine (AM/PM), shelf, wishlist, Product Check history | |
| **Search** (`Tab(role: .search)`) | Search products/ingredients; entry to label scanner | System search tab |

**Scan** is a primary action, not a fake tab: a prominent button in Today + a `tabViewBottomAccessory` "Scan" pill
(evaluate) + App Intent / Control Center control. On Duo unfolded, tabs become a sidebar via
`.tabViewStyle(.sidebarAdaptable)`.

### 8.2 Navigation model

- One `NavigationStack` per tab, each with its own typed path in an `@Observable AppRouter`.
- Scan flow is a `fullScreenCover` with its own internal state machine — not pushed on a tab stack — so
  fold/unfold/rotate can't pop it.
- Deep links / intents: `skinalyze://scan`, `skinalyze://scan/{id}`, `skinalyze://product-check/{id}`,
  `skinalyze://routine`.
- State restoration with `@SceneStorage` for selected tab, timeline position, and in-progress forms.

### 8.3 Route inventory (replaces `Router.Destination`)

`today` · `timeline` · `scanDetail(id)` · `compare(idA, idB)` · `zoneDetail(scanID, zone)` · `products` ·
`productDetail(id)` · `routineEditor` · `productCheck(id)` · `profile` · `settings` · `privacy` · `export`.
Scan flow (modal): `permission → coaching (first time only) → capture (angle × 3) → review → analysis → result`.

---

## 9. Device & layout strategy — every iPhone, including iPhone Duo

> Binding rules are in [/CLAUDE.md](../../CLAUDE.md) §1. This section explains how each screen applies them.

### 9.1 Device-state matrix

Device facts (from the vendored `iphone-duo-dual-pane-patterns` skill, aligned to Apple's iOS 27 design templates):
outer display **466 × 678 pt**; inner display **951 × 669 pt** (669 × 951 portrait); the fold sits at **475.5 pt**, the
centre of the long edge. Each half of the inner display ≈ one outer display — design "one familiar pane + one extra
pane", not a stretched phone UI. Code never sees a "pose"; it sees **size class, reserved regions, and hinge status**:

| Pose | What code observes | Our pattern |
|---|---|---|
| Closed | outer display, compact width | Phone UI; secondary panes collapse to sheets/pushes |
| Open flat | regular × regular, division region inactive | Two panes side by side |
| Book (partly folded, inner landscape) | division region active, **taller than wide** | Two panes left/right, nothing interactive in the curve |
| Tabletop (partly folded, inner portrait) | division region active, **wider than tall** | Visual in the raised half, controls in the flat half |
| Tent | partially open, often flipped | Hands-free viewing; don't rely on touch |

| State | Layout approach |
|---|---|
| Regular iPhone portrait | Single column |
| Regular iPhone landscape | Single column with wider margins; camera preview rotates; 3D viewer gets a side panel if width allows |
| Duo closed portrait | Single column (same as regular iPhone) |
| Duo closed landscape (compact × compact) | Condensed: toolbars collapse, two columns only where content is short; scan shows preview + minimal HUD |
| Duo partially folded | Content split around the fold via `ArrangementView` split: *top half = visual (camera / 3D / face), bottom half = controls / data* |
| Duo unfolded portrait/landscape | Regular width: sidebar tabs; list + detail; 3D face + data panel; compare side by side |
| Split View / arbitrary width | Breakpoints by available width, not device |

### 9.2 Duo-specific opportunities (great on Duo, not just compatible)

1. **Tabletop hands-free scan** (partially folded on a table): raised half shows the inner front camera preview + the
   ring; flat half shows angle guide and progress. The device is stable → distance and pose are far more consistent.
   Camera picked with `AVCaptureDeviceDirectionCoordinator` (the forward-facing one relative to our view). *Depends on
   Q8 for 3D; the 2D path works regardless.* Fallback: closed, on the outer display, user holds the phone as usual.
2. **Camera capture accessory**: while scanning on the inner display, `CameraCaptureAccessory` can show the subject a
   mirror/guide on the outer display — useful for "scan a friend" or tent pose. (Evaluate; not core.)
3. **Unfolded Timeline** (list-detail, `NavigationSplitView`): scans list on one side, selected scan's 3D face + zone
   trends on the other.
4. **Unfolded Compare** (dual view): before | after on either side of the fold, synced 3D rotation; no draggable slider
   on the fold.
5. **Unfolded Product Check** (companion pane): product + ingredients | verdict + how it fits your routine.
6. **Outer display glance**: Today is optimized as a fast glance (routine, streak, one-tap scan).
7. **Hinge as delight** (effects only, via a `HingeProgress` normaliser — never thresholds on raw angle): opening the
   device rotates the 3D face from profile to front in proportion to progress; entering tabletop (active division
   region wider than tall) offers "Start hands-free scan" as a contextual suggestion.

### 9.3 Layout implementation rules

- Breakpoints from `horizontalSizeClass` + container width (`containerRelativeFrame`, `ViewThatFits`), never device checks.
- `ArrangementView` for every main/detail pairing; split vs overlay per Apple guidance.
- Custom controls (scan ring HUD, compare handle, timeline scrubber, 3D viewer gestures) query ReservedRegion and avoid
  the fold and camera regions.
- Every screen has previews for: iPhone (smallest supported) portrait/landscape, Pro Max, Duo closed portrait/landscape,
  Duo partially folded, Duo unfolded portrait/landscape.

### 9.4 Hinge-driven effects (non-layout)

| Effect | Fallback on non-Duo |
|---|---|
| 3D face rotates with hinge angle while opening | Rotate via drag / subtle device-motion parallax (off under Reduce Motion) |
| Tabletop pose → suggest hands-free scan | Not shown |
| Timeline scrub via hinge (experimental, opt-in) | Normal scrubber |

### 9.5 Camera across poses

- **Don't use the virtual front camera** on Duo for scanning — it's capped at 1080p60 and exposes **no depth**. Use the
  individual inner/outer front cameras, chosen by `AVCaptureDeviceDirectionCoordinator` (AVKit, main-actor; pass
  `AVCaptureDeviceDescriptor`s to the camera actor, build the `AVCaptureDevice` there). Don't assume exactly one camera
  faces forward.
- **Mirroring follows direction, not position** — re-decide it whenever the direction map changes.
- `AVCaptureDevice.RotationCoordinator`: **one per camera**, created once the preview layer is in a window
  (`didMoveToWindow`), read both angles then observe; reapply the capture angle when adding an output; then **disable
  sensor-orientation compensation** (on by default for Duo front cameras).
- Square ultra-wide sensors: set `dynamicAspectRatio` for capture framing; `videoGravity` for preview.
- Re-check `ARFaceTrackingConfiguration.isSupported` and camera discovery on every display/scene change; switch to the
  2D path seamlessly if face tracking isn't available on the current camera.
- The capture session's lifetime follows the scan flow's state machine and `scenePhase`, **not** view `onDisappear`.
- Camera behaviour across open/close/flip **must be tested on hardware** — the Duo simulator exercises UI only.

---

## 10. Screen specifications

Each screen lists: purpose · content hierarchy · key interactions/motion · states · Duo/landscape notes.

### 10.1 Onboarding (replaces Splash + Chat)

- **Purpose:** Get to a first great scan in < 90 s; collect only what personalizes results.
- **Flow (paged, progress bar, back always available):**
  1. Welcome — contour motif animates into the logo; one-line value prop; "Get started".
  2. Goals (multi-select cards): fewer breakouts · fade dark spots · understand my skin · check products.
  3. Skin type (cards with short descriptions) + "Not sure?" → 3-question mini quiz.
  4. Sensitivity (3 options).
  5. Optional: name (for greetings), age range (not exact age).
  6. Optional: current products (search / barcode) — skippable.
  7. Privacy promise (plain language: on-device, iCloud only if you want) + correctly titled Terms / Privacy links.
  8. Camera permission priming → system prompt.
  9. Coaching (first time only): 3 short tips with looping illustrative animation.
- **States:** inline validation; optional steps skippable.
- **Duo unfolded / landscape:** illustration on one side, question on the other (split arrangement).

### 10.2 Today

- **Hierarchy:** greeting + streak → last scan card (3D thumbnail, headline delta vs previous, top changed zone) →
  "Scan now" (if due) → today's routine (AM/PM by time of day) → one insight card (e.g., product effectiveness).
- **Empty (no scans):** contour illustration + "Your first scan takes about a minute" + Scan button.
- **Motion:** card zoom transition into scan detail; routine check-off; numeric transitions.
- **Duo unfolded:** two columns (status | routine + insight).

### 10.3 Scan flow

- **Permission:** if denied → explanation + "Open Settings" button; never a black screen.
- **Capture:** live preview, face contour, 5-segment ring, one large instruction line (VoiceOver-announced), angle tray
  (front · left · right). Cancel (X) always visible. Manual capture fallback after 20 s of failing gates, with the
  failing gate highlighted. Optional voice guidance.
- **Review:** 3 captures with quality badges; retake any single angle (not all three).
- **Analysis:** sweep animation (§7.5.2), progress tied to real work, cancellable.
- **States:** low light → suggest facing a window; too far/close → contour scales with arrows; blur → "hold still";
  no face → gentle re-center prompt.
- **Landscape / Duo:** HUD reflows to the side in landscape; tabletop mode when partially folded (§9.2).

### 10.4 Scan result / Scan detail (one screen, two entry points)

- **Hierarchy:** 3D face (or 2D photo carousel fallback) with zone overlay → headline (e.g., "Calmer than last week",
  serif number) → zone list with per-zone count + delta → lesion-type breakdown (tappable glyphs, multi-select filter
  that highlights pins) → "What this means" (plain-language, non-diagnostic) → products used at the time → notes.
- **Never re-runs ML on open** — renders stored detections.
- **Interactions:** tap pin → callout with type + "what is this?"; tap zone → zone detail with history chart.
- **Duo unfolded / wide landscape:** 3D face | data panel.

### 10.5 Timeline (replaces Face Log)

- **Hierarchy:** trend chart (overall + per-zone toggles, Swift Charts) → scrubber → scan list grouped by week/month
  (thumbnail, date, delta chip — no repeated paragraphs).
- **Compare:** select 2 (a third selection replaces the oldest, with a hint) → Compare.
- **Empty:** explains the timeline with a clearly labelled sample illustration.
- **Duo unfolded:** list | selected detail.

### 10.6 Compare

- 2D: wipe slider (handle avoids reserved regions); 3D: synced dual viewers or wipe material.
- Per-zone and per-type deltas table with ▲▼ glyph + color + text.
- Labels: "Earlier — 3 Nov" / "Later — 17 Nov"; earlier always on the leading side (reading order).
- Product changes between the two dates surfaced ("Started X cleanser on 8 Nov").

### 10.7 Products

- **Routine:** AM / PM segmented; ordered steps (drag to reorder); each step = product + category glyph; check-off.
- **Shelf:** all products I own (active / paused / finished) with start/stop dates — feeds the effectiveness insight.
- **Wishlist:** products saved from Product Check.
- **Add product:** search (name + brand + ingredient), barcode scan, label scan (OCR), or manual.
- **Product detail:** ingredients (highlighted helpful / caution / conflict *for me*), when I used it, effect on my zones.

### 10.8 Product Check (in-app + share extension)

See §11.6. In-app history list of past checks with verdict glyphs.

### 10.9 Profile & Settings

- Profile: name, skin type, sensitivity, goals (editable cards, same components as onboarding). Neutral avatar (initials
  on `surfaceRaised`, no gender coding).
- Settings: reminders, Face ID lock, iCloud sync toggle + status, language, voice guidance, data export (PDF + raw),
  delete all data, privacy policy, terms, about, acknowledgements.

---

## 11. Feature specifications

### 11.1 Scan reliability engine

**Goal:** same face, same conditions → same result. Measured by the consistency benchmark (§18.3).

**Capture gates** (initial thresholds; calibrate in Phase 1):

| Gate | 2D path (Vision) | 3D path (ARKit) | Initial threshold |
|---|---|---|---|
| Distance / size | Face bbox width / frame width | `faceAnchor.transform` z-distance | 0.45–0.65 of width · or 30–38 cm |
| Centering | bbox center offset | projected anchor center | ±0.08 of frame |
| Pose | `DetectFaceLandmarksRequest` yaw/pitch/roll | anchor Euler angles | Front: \|yaw\|<10°, \|pitch\|<10°, \|roll\|<8°. Sides: yaw 30–45°, \|pitch\|<12°, \|roll\|<10° |
| Light | Mean luma (Y plane) inside face box; % clipped | same on captured image | Mean 90–180, clipped < 5% |
| Sharpness | Laplacian variance on face crop (vImage / Core Image) | same | Per-device calibrated floor |
| Stillness | bbox center Δ between frames + CoreMotion gyro | anchor Δ | < 2% of frame / < 3°/s for ≥ 0.7 s |
| Overall | `DetectFaceCaptureQualityRequest` | — | > 0.5; keep best of a 5-frame burst |

**Capture:** high-quality still (`AVCapturePhotoOutput`, `.quality` prioritization) or ARKit high-res frame where
supported; continuous AE/AWB/AF with point of interest on the face center; consistent mirroring; orientation from the
rotation coordinator.

**Inference:** square face crop with margin in pixel space → model at native resolution (`.scaleFill`, or 416-tile
strategy for small lesions) → explicit confidence threshold (start 0.4, tune) → cross-class NMS → map each detection to
a zone (§11.2) → **dedupe across angles by zone ownership** (front owns forehead/nose/chin; each side shot owns its cheek
and jaw; overlaps resolved by highest confidence).

**Model management:** an `AcneDetector` actor loads the model once (Swift Vision `CoreMLRequest`), runs off-main, and
records `modelVersion` on every scan.

**Scoring (replaces the public "GEA"):** internal *Breakout Index* per zone and overall = weighted count by type
(nodule > pustule > papule > whitehead/blackhead; dark spots tracked separately as "marks", not breakouts), normalized
by zone area. Displayed as bands relative to the user's own baseline (Calm · Mild · Active · Flared) + delta vs previous.
Formula documented in code and in-app ("How we calculate this").

### 11.2 3D face scan & zones (ARKit face tracking)

- **Session:** `ARFaceTrackingConfiguration` on Face ID iPhones (`isSupported`). **iPhone Duo always uses the 2D path**
  (no Face ID sensor — owner decision). Any other device where `isSupported` is false also uses the 2D path. Same gating UI for all paths. Record `captureMode` per scan
  (`.trueDepth / .arkitEstimated / .camera2D`) so trends never mix incomparable data silently.
- **Per capture, store:** `ARFaceGeometry` vertices (1,220 × float3, constant topology), face transform, camera
  intrinsics + transform, captured image.
- **Texture:** project mesh vertices into each captured image (`ARCamera.projectPoint`) → UV-space texture per angle →
  blend front/left/right by vertex-normal-to-camera weight → seam-feathered single texture (background actor; Metal
  compute if CPU is too slow).
- **Viewer:** `RealityView` with a `ModelEntity` built from `MeshResource` / `LowLevelMesh`; orbit (limited yaw ±70°,
  pitch ±25°), pinch zoom, double-tap reset; Liquid Glass zone legend.
- **Pins:** each 2D detection center → ray from that capture's camera → intersect mesh (or nearest projected vertex) →
  store `vertexIndex` + barycentric coordinates → render as small billboarded markers colored by type; tap → callout.
- **Zones:** static vertex-index sets for forehead, nose, left cheek, right cheek, chin, left jaw, right jaw (authored
  once against the canonical topology; validated visually). Because topology is fixed, zone membership is identical
  across every scan and every user.
- **2D fallback:** zones approximated from Vision face landmarks (forehead above brows, cheek polygons, etc.); pins on
  the 2D photo.
- **Privacy:** mesh + texture stored on device / user's iCloud only; disclosed in privacy policy & App Review notes.

### 11.3 Timeline & insights

- Swift Charts: overall Breakout Index line with band backgrounds; per-zone small multiples; per-type stacked bars.
- Insights engine (deterministic rules, phrased by LLM or templates): "Chin up 3 scans in a row", "Forehead calmest in
  6 weeks", "You haven't scanned in 9 days".
- Minimum data rules: no trend claims with < 3 scans; confidence language scales with the amount of data.

### 11.4 Product effectiveness ("Did this product work?")

- Every `UserProduct` has start/stop dates. For each product started ≥ 14 days ago with ≥ 2 scans before and ≥ 3 after,
  compare zone indices before vs after (median, ignoring outliers).
- Present as correlation with honest caveats: "Since starting X, chin breakouts are down 40%. Other changes may also
  play a part." Never "X cured/treated…".
- Surfaces in Today (insight card), Product detail, Compare, and Product Check ("Last time you used something with
  coconut oil, your chin flared").

### 11.5 Routine builder

- AM/PM routines; steps ordered by convention (cleanse → tone → treat → moisturize → SPF) with suggestions.
- Daily check-off (feeds journal & streak); conflict warnings across steps (e.g., retinoid + AHA on the same night).
- Interactive widget + Control Center control to check off steps.

### 11.6 Product Check ("Is this good for me?")

**Entry points:**

| Entry | Input | Extraction |
|---|---|---|
| Share from Safari (product page) | URL + page | `NSExtensionJavaScriptPreprocessingFile` reads JSON-LD `Product` / `og:title` in-page (no extra network fetch) → match catalog |
| Share from other apps (Shopee / Tokopedia / Sociolla / Instagram) | URL / text / image | Title/text → fuzzy catalog match; image → OCR |
| Share a photo/screenshot of the label | Image | Vision text recognition (`RecognizeTextRequest`; evaluate `RecognizeDocumentsRequest`) → INCI parser |
| Share selected text | Text | INCI parser |
| In-app scanner | Live camera | VisionKit `DataScannerViewController` (text + barcodes) |
| iOS 26 Visual Intelligence | Screenshot / camera | App Intents visual-intelligence integration returns matching products + verdict entry |

**Ingredient engine (`SkinalyzeKit/Ingredients`):**

- Curated `ingredients.json`: canonical INCI name, aliases (EN/ID spellings, common OCR typos), categories (humectant,
  emollient, exfoliant AHA/BHA/PHA, retinoid, benzoyl peroxide, azelaic acid, niacinamide, fragrance, essential oil,
  drying alcohol…), comedogenic rating (0–5, sourced), irritancy flags, known conflict pairs.
- Parser: normalize case/punctuation, split on commas/bullets/newlines, fix OCR errors (fuzzy match against aliases),
  handle "may contain", parentheticals, concentrations.
- **Personalization inputs:** skin type, sensitivity, goals, latest scan's lesion mix (comedonal vs inflammatory),
  current routine, product-effectiveness history.
- **Verdict:** `goodMatch | useWithCaution | probablyNotForYou | notEnoughInfo` + ranked reasons (each reason references
  the rule that fired). Deterministic and unit-tested with golden cases.

**Share-extension UX:** compact SwiftUI card in the share sheet: product name + photo (if matched), verdict, 2–3 reasons
(tap to expand), actions: *Add to routine* · *Save to wishlist* · *Open in Skinalyze* (best-effort). Must stay within
extension memory limits (no acne model, no 3D). Reads profile / routine / latest-scan summary from the **App Group**.

### 11.7 Trigger journal (optional)

- Quick daily log: sleep, stress, diet tags, cycle phase, notes, routine adherence (automatic from check-offs).
- HealthKit (opt-in, read-only): sleep analysis, menstrual flow. **HealthKit-derived values are stored in a local-only
  store** (never iCloud) — App Review 5.1.3.
- Correlation insights only after ≥ 4 weeks of data, phrased cautiously.

### 11.8 Widgets, controls, intents, reminders

- **Widgets:** small (days since scan + band), medium (trend sparkline + top zone), interactive routine checklist;
  Lock Screen circular (streak) & rectangular (next scan). Contour-motif backgrounds; tinted/clear rendering modes.
- **Controls (Control Center / Lock Screen / Action button):** "Start scan", "Check off AM routine".
- **App Intents / Siri / Shortcuts:** Start scan, Log routine, Check a product (from text/image), Show my trend.
- **Reminders:** scan cadence (default every 3 days, user-set) suggested at a daylight time; AM/PM routine reminders;
  local notifications with actionable buttons.

### 11.9 Biometric lock

`LocalAuthentication`; lock Timeline/photos behind biometrics (setting); copy, glyph, and setting label branch on
`LAContext.biometryType` (Face ID on most iPhones, **Touch ID on iPhone Duo**, passcode fallback); blur the
app-switcher snapshot; `NSFaceIDUsageDescription`.

### 11.10 iCloud sync

- Already live; keep it, on the new external-storage schema. Sync status + toggle in Settings. Conflict policy:
  last-writer-wins per record; scans are append-only so conflicts are rare.
- Separate local-only `ModelConfiguration` for HealthKit-derived journal data.

### 11.11 Dermatologist export

PDF (`ImageRenderer` → PDF) with: date range, trend charts, zone table, selected photos, product timeline, user notes;
clear "not a medical document" footer. Shared via the share sheet. Optional raw export (JSON + images).

### 11.12 Localization

English + Bahasa Indonesia via String Catalogs; ingredient aliases bilingual; numbers/dates localized; layouts tested
with longer Indonesian strings.

---

## 12. AI & ML architecture

### 12.1 Responsibilities

| Layer | Tech | Decides? | Runs where |
|---|---|---|---|
| Lesion detection | Core ML YOLO-style detector (`acneObj28200`, 416×416, 6 classes) | Yes (counts) | On device |
| Face pose / quality | Vision / ARKit | Yes (gates) | On device |
| Scoring & insights | Swift rules engine | Yes | On device |
| Product verdict | Ingredient rules engine | Yes | On device |
| OCR → ingredient list cleanup | Rules + Foundation Models (`@Generable` structured output) | No (assists) | On device |
| Explanations / phrasing | Foundation Models, template fallback | No | On device |
| Unknown product identification (optional, Q6) | Cloud model via our proxy, opt-in per use | No (assists) | Cloud — product image/text only |

### 12.2 Foundation Models usage

- Check `SystemLanguageModel.default.availability`; if unavailable (device, region, language, disabled), use
  templates — feature parity, less flourish.
- Use `@Generable` structs for structured outputs (e.g., `ParsedIngredientList`, `InsightPhrasing`) and tool calling to
  fetch facts from our engine — the model never invents ingredient facts.
- Guardrails: no medical claims; output validated against a banned-terms list before display.

### 12.3 Detector improvements

1. Phase 1: fix preprocessing, thresholds, NMS, dedupe — measure with the benchmark.
2. If the benchmark still shows high variance or poor recall on small lesions → retrain/fine-tune (needs Q3):
   higher input resolution or tiling, more diverse skin tones and lighting, hard-negative mining (pores, freckles,
   moles, hair), class balance.
3. Version every model; store `modelVersion` per scan; never silently re-score old scans — offer "Re-analyze with new
   model" explicitly.

### 12.4 Optional cloud (only if Q6 = yes)

Proxy backend (no keys in app), App Attest, per-user rate limits, zero-retention provider settings, explicit per-use
consent sheet, privacy label + policy updates. Never send face photos or scan data.

---

## 13. Data model & migration

### 13.1 New models (SwiftData, CloudKit-compatible: all optional/defaulted, optional relationships, no unique constraints)

```
ScanSession      id, createdAt, captureMode(.trueDepth/.arkitEstimated/.camera2D), cameraID, deviceModel, displayState, appVersion,
                 modelVersion, overallIndex, band, notes, isLegacy, legacyGEA, captures[], detections[]
ScanCapture      id, angle(.front/.left/.right), image (Data, externalStorage, HEIC), width, height,
                 pose(yaw,pitch,roll), quality(luma, sharpness, captureQuality), cameraIntrinsics?, faceTransform?
FaceMeshSnapshot id, scan, vertices (Data), texture (Data, externalStorage)
Detection        id, scan, captureAngle, type, confidence, bbox (normalized), zone, vertexIndex?, barycentric?
UserProduct      id, catalogID?, customName?, brand?, category, ingredients?, startedAt, stoppedAt?, routineSlot, order
RoutineLog       id, date, slot(AM/PM), completedStepIDs
ProductCheck     id, createdAt, source, matchedCatalogID?, parsedIngredients, verdict, reasons, savedToWishlist
JournalEntry     id, date, tags, stress, notes          (CloudKit store)
HealthSample     id, date, sleepHours?, cyclePhase?     (LOCAL-ONLY store — never iCloud)
```

Profile (skin type, sensitivity, goals, name, age range) → App Group `UserDefaults(suiteName:)` (shared with
extensions/widgets), mirrored to iCloud key-value storage if sync is enabled.

Product catalog → read-only bundled JSON (merged single file) loaded into an in-memory index; not SwiftData.

### 13.2 Migration from legacy `Result` (CloudKit-aware)

Constraints: the production CloudKit schema is **additive only**; SwiftData custom migration stages combined with
CloudKit sync are risky.

Plan:
1. Keep `Result` in the schema (marked deprecated, never written again).
2. Add the new models (additive).
3. **App-level one-time migration** on launch (background, resumable, idempotent): for each `Result` without a
   migration marker → decode base64 → HEIC `Data` → create `ScanSession(isLegacy: true, legacyGEA: geaScale)` +
   `ScanCapture`s (in stored order) → copy `acneCounts` into a legacy summary → map `cleanserUsedID` etc. to
   `UserProduct` entries (start date = earliest scan referencing them) → set marker.
4. Legacy scans have no per-detection data → offer an optional "Re-analyze with new engine" per scan (explicit; shows
   it's re-scored).
5. Only after migration is verified across devices: nil out the heavy base64 fields on migrated records to reclaim
   iCloud space (additive-safe).
6. Migration covered by tests with fixture stores (§18).

### 13.3 App Group

`group.com.Patani.Skinalyze` (name TBD) — shared SwiftData store location (`ModelConfiguration(groupContainer:)`),
shared defaults, and the merged catalog for the share extension and widgets. Moving the existing store into the App
Group container is itself a migration step (copy, verify, switch).

---

## 14. Technical architecture

### 14.1 Targets (XcodeGen `project.yml`)

| Target | Type | Notes |
|---|---|---|
| `Skinalyze` | App | iOS 26.0 deployment, 27.1 SDK, all orientations |
| `SkinalyzeKit` | Local Swift package | Models, persistence, ingredient engine, insights, design system — shared by all targets |
| `ProductCheckShare` | Share Extension | SwiftUI card; uses `SkinalyzeKit` (no ML / 3D) |
| `SkinalyzeWidgets` | Widget Extension | Widgets + Controls |
| App Intents | In app (or App Intents extension) | Shortcuts, Siri, Visual Intelligence |
| `SkinalyzeTests` | Unit tests (Swift Testing) | |
| `SkinalyzeUITests` | UI tests (XCUITest) | Mock camera via launch argument |

### 14.2 Folder structure (by feature)

```
Skinalyze/
  App/                 SkinalyzeApp, AppRouter, Scenes, DeepLinks
  Features/
    Onboarding/
    Today/
    Scan/              Capture/ (session, gates, HUD)  Analysis/  Review/
    Face3D/            Mesh, Texture, Viewer, Pins, Zones
    Timeline/  Compare/  Products/  ProductCheck/  Profile/  Settings/  Export/
  Resources/           Assets, String Catalogs, ML model, catalog JSON
SkinalyzeKit/
  Sources/
    DesignSystem/      Tokens (Color, Type, Radius, Spacing), Motion, Haptics, Components
    Persistence/       Schema, Migration, Stores
    Detection/         AcneDetector actor, zone mapping, scoring
    Ingredients/       Catalog, Parser, Rules, Verdict
    Insights/          Trends, Effectiveness, Phrasing (FM + templates)
    Layout/            Duo helpers (reserved-region modifiers, arrangement wrappers, preview configs)
```

### 14.3 Concurrency & state

- Swift 6 strict concurrency. Views observe `@Observable @MainActor` models.
- `CaptureEngine` (actor / dedicated queue) owns AV/AR sessions; publishes gate state to the UI at ≤ 15 Hz.
- `AcneDetector` actor; `TextureBaker` actor; ingredient engine is pure functions (Sendable).
- Scan flow = explicit state machine (`idle → permission → coaching → capturing(angle) → review → analyzing → result →
  saved / failed(reason)`), unit-tested, independent of view lifecycle (survives fold/unfold/rotate).

### 14.4 Cleanup list (Phase 0)

Delete: `DetailVIew`, `CompareView`, `ContentCell`, `ScrollCell`, `CameraSheetTutor`, `CardStackView`, old
`CameraView`, `temp`, `LottieView`, unused assets (`imageTest`, empty `Image`, `Atas`, `brownTest`), GIFs, duplicate
routes. Rename/absorb `NewDetailViewTest`, `ProductTest`. Merge catalogs. Fix `project.yml` resources path, deployment
target, and orientations.

---

## 15. Privacy, safety & App Review compliance

### 15.1 Copy rules (Guideline 1.4.1 — previously rejected)

| Allowed | Avoid |
|---|---|
| "track", "notice", "changes", "calmer", "more active", "spots", "breakouts", "marks" | "diagnose", "detect acne disease", "treat", "cure", "condition", "severity grade", "medical" |
| "Many people find…", "may help", "match for your skin profile" | "will clear", "clinically proven" (unless cited), "safe" / "harmful" |
| "Consider seeing a dermatologist if…" (persistent / painful / nodules) | Any instruction to start/stop medication |

- Persistent disclaimer (not red, not alarming) in results & export: "Skinalyze tracks visible changes. It isn't a
  medical device and doesn't provide a diagnosis."
- Nodule detections or the "Flared" band → gentle suggestion to consult a professional.
- A banned-terms check runs in CI over String Catalogs and LLM outputs.

### 15.2 Data

- Face data (ARKit/TrueDepth): used only for in-app scanning/visualization, stored on device / user's iCloud, never
  used for advertising or shared; explained in the privacy policy + App Review notes.
- Camera usage string rewritten to be short and accurate (the current one is a paragraph).
- Third-party AI: none by default; if Q6, explicit consent per guideline 5.1.2.
- HealthKit: read-only, opt-in, local-only storage, clear purpose strings.
- Product photos: bundle them or use a source the privacy copy covers — no silent third-party fetches contradicting it.
- Privacy nutrition label updated in every phase that changes data handling.

---

## 16. Accessibility requirements

- VoiceOver: every control labeled; scan guidance announced (`AccessibilityNotification.Announcement`) with priority;
  results summarized in one sentence first; the 3D viewer offers an accessible zone list alternative.
- Dynamic Type to AX5; layouts switch to vertical at accessibility sizes; no truncated critical text.
- Contrast ≥ 4.5:1; Increase Contrast variants; color never the only signal (severity uses label + shape).
- Reduce Motion, Reduce Transparency, Differentiate Without Color, Bold Text, Button Shapes respected.
- Hit targets ≥ 44 pt; all custom tappables are Buttons.
- Voice Control names match visible labels.
- `performAccessibilityAudit()` in UI tests for every screen.

---

## 17. Performance budgets

| Metric | Budget (on the oldest iOS 26 device class) |
|---|---|
| Cold launch → first frame | < 400 ms |
| Tap Scan → live preview | < 800 ms |
| Gate evaluation | ≥ 15 Hz without dropping preview frames |
| Analysis of 3 captures (2D) | < 2.5 s; 3D texture bake < 2 s additional |
| Timeline scroll | No hitches (Instruments hitch rate < 5 ms/s) at 120 Hz on ProMotion |
| Memory peak during scan | < 350 MB |
| Share extension memory | < 80 MB |
| Storage per scan | < 3 MB (HEIC captures + mesh + texture + detections), vs ~9 base64 JPEGs today |
| App size | Remove 2.2 MB of GIFs + duplicate catalog; compress the model if accuracy allows |
| Fold / unfold re-layout | One layout pass; no camera session restart |

---

## 18. Testing & quality strategy

### 18.1 Unit (Swift Testing) — ≥ 80% coverage on `SkinalyzeKit`

Scoring & bands · zone mapping · cross-angle dedupe · capture gate evaluation (synthetic frames) · scan state machine ·
ingredient parser (OCR fixtures EN/ID) · verdict rules (golden cases) · effectiveness math · migration (fixture legacy
stores) · insight thresholds.

### 18.2 Integration

Detector on fixture images (deterministic outputs) · persistence with external storage · App Group sharing ·
share-extension pipeline with fixture URLs/images.

### 18.3 Consistency benchmark (the key metric)

- **Fixture set:** ≥ 30 faces (diverse skin tones, lighting, lesion types), 5 repeated captures each under
  controlled-but-varied conditions. (Collect with consent; store outside the repo.)
- **Metrics:** severity-band agreement across repeats (target ≥ 90%), per-type count coefficient of variation
  (target ≤ 25%), per-zone index CV, recall on small lesions vs annotated ground truth.
- Run on every change to capture/inference code; results tracked in `docs/redesign/benchmarks/`.

### 18.4 UI / E2E (XCUITest)

Onboarding → first scan (mock camera feeding fixtures) → result → timeline → compare; Product Check share flow;
permission-denied path; Retake; fold/unfold/rotate state preservation (Device Hub configurations); accessibility audits.

### 18.5 Visual review

Previews for every screen in all §9.1 device states, light/dark, AX5, Reduce Motion. Design review against §6.7.

---

## 19. Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Detector accuracy is the ceiling even after pipeline fixes | Med | High | Benchmark early (Phase 1); Q3 dataset; retrain plan |
| CloudKit migration corrupts/duplicates user history | Med | High | App-level idempotent migration, keep legacy model, fixture tests |
| Texture baking quality (seams, lighting mismatch between angles) | High | Med | Start with front-only texture; add blending iteratively; 2D fallback always |
| ARKit face tracking unsupported or poor on iPhone Duo (no TrueDepth) | Med | Med | Q8 hardware spike in Phase 1; 2D path with landmark zones is first-class, not an afterthought |
| Duo camera switching on open/close/flip breaks a scan mid-capture | Med | High | Direction coordinator + state machine that pauses/resumes the current angle; hardware tests |
| Duo API details differ from the vendored skills | Low | Med | Compile-check in Xcode 27.1 before Phase 3 layout work |
| App Review re-rejects on medical language | Med | High | §15.1 copy rules, banned-term lint, review notes |
| Foundation Models unavailable for many users/languages | High | Low | Templates provide parity |
| Catalog licensing | Med | Med | Q5 before Phase 5; own-catalog fallback |
| Share extension memory limits | Low | Med | No ML/3D in the extension; budget in §17 |
| Scope creep vs. quality | High | High | Phases gated by exit criteria; benchmark & accessibility gates are blockers |

---

## 20. Master tracker

Tick when the phase's exit criteria in [PHASES.md](PHASES.md) are met.

- [x] **Phase 0** — Foundation & cleanup
- [x] **Phase 1** — Scan reliability engine (device calibration pending)
- [x] **Phase 2** — Brand & design system
- [x] **Phase 3** — App shell, core screens & adaptive (Duo) layouts
- [x] **Phase 4** — 3D face scan & zones (device calibration pending)
- [x] **Phase 5** — Product Check (Visual Intelligence pending)
- [x] **Phase 6** — Insights, routine & habit (journal/HealthKit pending)
- [x] **Phase 7** — Trust, accessibility, performance & polish (device perf pass pending)

See PHASES.md → "Build status" for verification, how to test, and open items.

---

## 21. References

- Apple — Preparing your app for iPhone Duo: https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo
- Apple — iPhone Duo developer hub: https://developer.apple.com/iphone-duo/ · Prepare: https://developer.apple.com/iphone-duo/prepare/
- Apple HIG — Designing for iPhone Duo: https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo
- Tech Talks — Design for iPhone Duo: https://developer.apple.com/videos/play/tech-talks/111466/ ·
  Strike a pose with adaptive layouts on iPhone Duo: https://developer.apple.com/videos/play/tech-talks/111463/ ·
  Prepare your app for iPhone Duo: https://developer.apple.com/videos/play/tech-talks/111461/
- Apple Newsroom — Developers bring incredible new app experiences to iPhone Duo: https://www.apple.com/newsroom/2026/10/developers-bring-incredible-new-app-experiences-to-iphone-duo/
- App Review Guidelines (1.4.1, 5.1.2, 5.1.3): https://developer.apple.com/app-store/review/guidelines/
- Apple Developer Documentation: ARKit face tracking, RealityKit, Vision, Foundation Models, VisionKit, WidgetKit,
  App Intents, SwiftData. Apple articles: *Choosing a Camera by the Direction it Faces*, *Registering a camera capture
  accessory on iPhone Duo*, *Supporting Device Rotation in Your Camera App*.

---

## 22. Agent skills (vendored in `.claude/skills/`)

Installed 2026-11-18 after vetting (MIT licensed; markdown guidance; the only scripts are AvdLee's local `xctrace`
helpers — no network). Provenance in each skill's `SOURCE.md`. Use them — they're the reference for "how", this plan
is the reference for "what".

| Skill | Source | Use for |
|---|---|---|
| `swiftui-expert-skill` | AvdLee/SwiftUI-Agent-Skill | **Primary design/motion skill**: animation basics/advanced/transitions, Liquid Glass, iPhone Duo, layout, lists, scroll, sheets, charts (+ accessibility), previews, performance, latest/soft-deprecated APIs, Instruments trace analysis |
| `swiftui-pro` | twostraws/SwiftUI-Agent-Skill | Independent second-opinion review: design, accessibility, navigation, data, performance, hygiene, localization |
| `swift-concurrency` | AvdLee/Swift-Concurrency-Agent-Skill | Swift 6 strict concurrency, actors (capture engine, detector), Sendable, `@Observable`, migration |
| `iphone-duo-readiness` | mirzaaghazadeh/iphone-duo-skills | Entry point / audit checklist for Duo |
| `iphone-duo-adaptive-layout` | ″ | Reserved regions, fold avoidance, `ArrangementView` |
| `iphone-duo-dual-pane-patterns` | ″ | Display/half dimensions, hinge types, pose → pattern mapping |
| `iphone-duo-hinge-and-scenes` | ″ | Hinge effects, Split View, multiple scenes, `CameraCaptureAccessory` |
| `iphone-duo-camera` | ″ | Two front cameras, direction coordinator, rotation coordinator, mirroring |
| `iphone-duo-vertical-bars` | ″ | Toolbars/tab bars on the vertical axis |
| `iphone-duo-design-review` | ″ | Design critique across closed/open/book/tabletop/tent |

Also available and relevant: ECC agents `swift-reviewer`, `swift-build-resolver`, `a11y-architect`, `tdd-guide`,
`security-reviewer`; skills `tdd-workflow`, `verification-loop`, `architecture-decision-records`.

**Gap:** no reputable skill exists for RealityKit/ARKit face meshes, haptics design, or motion *direction* (as opposed to
SwiftUI animation APIs). §7 of this plan is the motion spec; Apple docs + WWDC sessions cover RealityKit/ARKit.
