# Skinalyze — Project Rules

These rules apply to every change in this repo, by humans or AI agents. The full redesign plan lives in
[docs/redesign/PLAN.md](docs/redesign/PLAN.md) and the build order in [docs/redesign/PHASES.md](docs/redesign/PHASES.md).
Read them before starting redesign work, and tick off checklist items there as you complete them. The growth,
engagement, mascot (Pimpi) and paywall backlog lives in [docs/redesign/FEATURES.md](docs/redesign/FEATURES.md) —
its §0 rules (score effort never skin, the scan is never paywalled, social shares no photos) are binding.

## 1. Every iPhone shape, every pose (NON-NEGOTIABLE)

The app must work and look intentional on **regular iPhones and iPhone Duo**, in **every** state:

| Device state | Size class (typical) | Must handle |
|---|---|---|
| Regular iPhone, portrait | compact W × regular H | Baseline layout |
| Regular iPhone, landscape | compact/regular W × compact H | No clipped content, camera preview rotates correctly |
| iPhone Duo **closed** (outer display), portrait | compact W × regular H | Same functionality as baseline |
| iPhone Duo **closed**, landscape | compact W × compact H | Dedicated compact×compact layout, nothing cut off |
| iPhone Duo **partially folded** (tabletop / "laptop" pose) | inner display, fold region active | Content split around the fold; controls never on the fold |
| iPhone Duo **fully unfolded**, portrait & landscape | regular W | Multi-column layouts (list + detail, split arrangements) |
| iPhone Duo Split View / any arbitrary width | any | Layout adapts continuously — never assume a fixed width |

Rules:

1. **Layout by size class and available space, never by device model.** No `UIScreen.main.bounds`, no hard-coded
   widths/heights, no `if device == duo`. Use `horizontalSizeClass`, `verticalSizeClass`, `ViewThatFits`,
   `containerRelativeFrame`, custom `Layout` types; `GeometryReader` only when nothing else works.
2. **Support all interface orientations.** `UISupportedInterfaceOrientations` must include portrait and landscape
   left/right. The camera preview and the captured image orientation must be correct in every orientation and pose
   (use `AVCaptureDevice.RotationCoordinator` / ARKit's own orientation handling).
3. **Keep interactive elements out of the fold and camera reserved regions.** System components do this automatically;
   **custom controls must use the ReservedRegion APIs** (SwiftUI / UIKit) — standard `safeAreaInsets` are NOT enough.
   Scrollable content may pass under the fold; buttons, sliders, drag handles, text fields, and gesture hot-spots may not.
4. **Primary/secondary layouts use `ArrangementView`** (split for main/detail, overlay for foreground/background) instead
   of hand-rolled stacks that happen to straddle the fold.
5. **Hinge angle (`onHingeChange` / `UIHingeInteraction`) is for interactions and effects only, never for layout.**
   It is `nil` on non-Duo iPhones — every hinge-driven feature needs a non-hinge fallback.
6. **Same functionality and information hierarchy on outer and inner displays.** The inner display adds space and
   columns, not features the outer display lacks.
7. **State survives fold / unfold / rotate.** Opening or closing the device must never reset a scan in progress, lose
   form input, restart the camera session unnecessarily, or drop navigation state. Never put destructive teardown in
   `onDisappear` that a display change could trigger; tie session lifetime to scene phase / explicit user actions.
8. **Camera / face-tracking availability is checked at runtime per display state** (`ARFaceTrackingConfiguration.isSupported`,
   `AVCaptureDeviceDirectionCoordinator`). iPhone Duo has **two front cameras, no TrueDepth, no Face ID (Touch ID), no
   LiDAR** — so **iPhone Duo uses the 2D scan path only; no 3D face model on Duo**. Never assume a camera faces the user. The 2D scan uses the default (virtual on Duo) front camera, which switches inner/outer automatically and needs no depth; any future depth/3D feature must pick individual cameras via `AVCaptureDeviceDirectionCoordinator`. Always
   branch biometric copy/glyphs on `LAContext.biometryType`. Camera open/close/flip behaviour must be tested on hardware.
9. **Gate iOS 27.1+ APIs** (Duo APIs) with `if #available(iOS 27.1, *)`; deployment target stays iOS 26.0.
10. **Verify every UI change** in Xcode Device Hub: iPhone Duo closed (portrait + landscape), partially folded,
    unfolded (portrait + landscape), plus the smallest supported regular iPhone and a Pro Max. Keep SwiftUI previews
    for these configurations up to date.

> **Use the vendored skills** in `.claude/skills/` for the how: start with `iphone-duo-readiness`, then
> `iphone-duo-adaptive-layout`, `iphone-duo-dual-pane-patterns`, `iphone-duo-camera`, `iphone-duo-hinge-and-scenes`,
> `iphone-duo-vertical-bars`, `iphone-duo-design-review`. For all SwiftUI/motion/Liquid Glass work use
> `swiftui-expert-skill` (+ `swiftui-pro` for review) and `swift-concurrency` for actors/isolation.
> See PLAN.md §22. API names follow Apple's iPhone Duo docs for the iOS 27.1 SDK; compile-check in Xcode 27.1:
> - https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo
> - https://developer.apple.com/iphone-duo/

## 2. Platform

- Deployment target **iOS 26.0**; build with the **iOS 27.1 SDK** (Xcode 27.1) so Duo APIs are available.
- Swift 6 language mode, strict concurrency. `@Observable` (not `ObservableObject`) for new state.
- Liquid Glass via native components first; custom glass only where no native component exists.
- RealityKit (`RealityView`) for 3D — not SceneKit.
- The Xcode project is generated by XcodeGen from `project.yml`; edit that, not a hand-made `.xcodeproj`.

## 3. Product guardrails

- **Tracker, not diagnosis.** No medical claims or diagnosis language — see PLAN.md §15 copy rules.
  (The app already received an App Review 1.4.1 rejection; treat wording as a compliance surface.)
- **Private by default.** Face photos, scan results, and face-mesh data never leave the device except through the
  user's own iCloud sync. No third-party AI receives personal data without explicit per-use consent.
  HealthKit-derived data is never stored in iCloud.
- **Deterministic verdicts.** Severity and product-match verdicts come from tested rules, not from an LLM.
  LLMs only parse and phrase.

## 4. Design guardrails

- Every color, font, radius, spacing, motion curve, and haptic comes from `DesignSystem/` tokens. No raw hex, no magic
  numbers in views.
- Motion uses the shared spring tokens; every animation has a Reduce Motion fallback.
- Haptics through the shared vocabulary (`.sensoryFeedback`); never fire haptics from a repeating timer.
- Every tappable element is a `Button` (or has button traits) with an accessibility label; Dynamic Type up to AX5.
- Avoid generic "AI-app" aesthetics — see PLAN.md §6.7.

## 5. Git

- **Commit locally only. NEVER `git push`** (no push, no force-push, no PR creation that pushes) until the owner
  explicitly says otherwise.
- Conventional commit messages: `<type>: <description>` (feat, fix, refactor, docs, test, chore, perf, ci).
- Work on a feature branch, not `main`, unless told otherwise.

## 6. Engineering guardrails

- Never block the main thread with ML inference, image processing, or capture-session start/stop.
- Load ML models once; run inference off the main actor.
- Store images as `Data` with `@Attribute(.externalStorage)` — never base64 strings.
- CloudKit sync is live in production: **schema changes must be additive only** (no renames, no deletions,
  all properties optional or defaulted, all relationships optional).
- Tests first for logic (severity, zones, ingredient engine, migration). Use Swift Testing for unit tests.
