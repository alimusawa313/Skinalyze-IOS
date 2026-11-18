# Skinalyze V2 — "Mirror" (bold redesign spec)

> Owner direction (2026-11-18): "be bold, disregard the old design UI/UX entirely, be free." Bar: Apple Design Award
> winners (CapWords' signature camera→sticker moment, Tide Guide's living palette, grug's personality, Moonlitt's
> hero object). Scan must feel like Face ID enrollment (already working on device — keep `ScanCaptureModel` + gates).
> Supersedes PLAN.md §6–§10 visuals/IA and the rejected "Field Notes"/"Glow" looks. Baseline before V2: `221f79c`
> on branch `phase-8/open-items`.

## Core idea: the app IS a mirror

No tab bar, no lists-of-cards chrome. You open Skinalyze and **see yourself** — the live front camera, dimmed and
graded, full-bleed. Your skin data lives *on your face*.

### 1. Home = Mirror (replaces Today + tab bar)
- Full-screen live front camera (`CameraPreview`), graded dark with a mood-tinted vignette (latest band colours).
- Floating over your live face (face box from `CameraSession.frames`): soft glows at zones active in your last scan
  (`ScanSession.zoneIndex`) — your history overlaid on the real you.
- Top-left: giant rounded-heavy breakout index (ScaledMetric ~96 pt) + one short sentence.
- Centre-bottom: one huge circular **shutter ring** (Face ID tick ring, idle-breathing). Tap → scan starts *in place*
  (same camera, no modal): ticks light as you turn, haptic per tick, shutter sound, ring collapses into a card that
  **flies up** into the deck.
- No camera / Simulator: animated mood-gradient "mirror" placeholder with the same layout.

### 2. Deck = history (swipe up)
- Full-screen vertical stack of big **skin cards** (face cut-out sticker on mood gradient, `SkinCard`) with 3D
  perspective; pick two → Compare. Trend = thin glowing line along the stack edge.

### 3. Shelf = products (dock)
- Products as shelf tiles with depth; tap → verdict card springs open. Search + label scanner live here.

### 4. Navigation
- Floating three-glyph Liquid Glass **dock** (Mirror · Deck · Shelf) + swipe paging. Profile = tap the avatar in Mirror.

### 5. Result
- New card scales in over the Mirror, zones pulse, counts tick; three swipeable chapters
  (What changed · What we noticed · What helps) instead of a long scroll of panels.

### Visual language
- Dark-first, immersive, full-bleed photography of *you*; mood gradients (calm mint → flared magenta); heavy rounded
  type at huge sizes; glass only for dock/controls; zero bordered card stacks. Physical motion (springs, fly-up, ring
  collapse), haptics + sound on capture; Reduce Motion → fades.

### Keep (built and tested)
Scan engine + calibrated gates, ScanCaptureModel/FaceRing, persistence/migration, SkinalyzeKit engines, Product Check,
share extension, widgets, intents, 3D viewer, iPhone Duo rules (CLAUDE.md §1).

### Build order
- [x] 1. `MirrorView` + `AppShell` (glass dock) replacing `AppTabView` — `6892e21`
- [x] 2. `DeckView` (vertical 3D-tilt card stack, mood backdrop, trend line, pick-two compare)
- [x] 3. `ShelfView` (bouncy routine tiles, "Is it good for me?" search, label scanner)
- [x] 4. Result chapters (What changed · What we noticed · What helps; 3D scan as hero)
- [x] 5. Installed on owner's iPhone — awaiting owner's on-device check
- [ ] Card fly-up into the Deck after a scan (currently: result sheet opens)
- [ ] Delete dead V1 screens (TodayView, SearchView, ScanTimelineView grid, ScanFlowView capture screen)

### 3D = real TrueDepth scan (owner, 2026-11-18)
Every scan on a TrueDepth iPhone captures the front photo **with its depth map** (`CameraSession`, TrueDepth device,
depth delivery). `DepthMeshBuilder` (SkinalyzeKit, tested) unprojects it with the camera intrinsics into a metric mesh of
the user's actual face, textured with that photo; background and silhouette jumps are cut. Built automatically at
analysis — no extra step. iPhone Duo has no TrueDepth → 2D only. On-device checks: `[scan] front depth: WxH` and
`[scan] 3D mesh: N vertices` in the console log; the mesh should face you, upright, not mirrored.
