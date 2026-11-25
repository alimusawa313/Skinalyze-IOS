# Acne detector improvement plan

> Written 2026-11-25 for a later session to execute. Owner's complaint: the model "is kinda shit and inaccurate".
> Read CLAUDE.md first; every rule there still applies. Related: PLAN.md §11.1 (scan reliability), §12.3 (detector
> improvements), §18.3 (consistency benchmark). Tick the checkboxes here as work lands.

## 0. Where things stand

- **Model:** `Skinalyze/AIModel/acneObj28200.mlmodel`, 31 MB. Core ML pipeline (neural network + built-in NMS),
  spec version 3, one 416×416 RGB input, outputs `confidence` (N×6) and `coordinates` (N×4). The format matches
  Create ML / Turi Create's YOLOv2-style object detector. Training data and training notebook are **unknown** (PLAN.md
  Q3 — ask the owner before Phase M3).
- **Classes** (labels are also legacy storage keys — never rename them, see `LesionType.modelLabel`):
  `blackheads`, `whiteheads`, `papules`, `pustules`, `nodules`, `dark spot`.
- **Pipeline today** (`Skinalyze/Scan/ScanAnalyzer.swift`, `SkinalyzeKit/.../Detection/InferencePipeline.swift`):
  per photo (front, right, left): Vision face box → square face crop with 20% margin (`FaceCrop`) → whole crop
  scaled to 416 (`.scaleFill`) → one model run → single confidence threshold 0.4 + cross-class NMS at IoU 0.45
  (`DetectionFilter`) → zone from box centre (`FaceZoneMapper`) → each zone counted from one photo only
  (`ZoneOwnership`) → weighted Breakout Index (nodule 4, pustule 3, papule 2, white/blackhead 1, dark spot 0) →
  band (`BreakoutBand`: 0 calm, 1–8 mild, 9–20 active, 21+ flared).
- `AcneDetector` is an actor in the app target that loads the model once and runs off the main actor. Every scan
  stores `modelVersion`.

### Why it is inaccurate (hypotheses to confirm with numbers in M0)

1. **Spots are too small.** A full face crop squeezed to 416 px makes a blackhead 2–4 px wide. YOLOv2-style
   detectors are weak on objects that small.
2. **Six classes are not reliably separable from a selfie.** Papule / pustule / nodule are hard even for
   dermatologists on photos; public acne datasets label them inconsistently. Nodule carries weight 4, so one wrong
   label moves the index a lot.
3. **Domain gap.** Public acne datasets are mostly close-up, clinical, lighter skin. Our input is a front-camera
   selfie in uncontrolled light; many users are Indonesian (Fitzpatrick III–VI).
4. **False positives on non-skin:** eyebrows, eyes, nostrils, lips, hairline, stubble, moles, freckles.
5. **One threshold for every class**, and a single frame per angle, so results flicker between repeat scans.

## 1. Rules for this work

- **Privacy:** face photos never leave the device except through the user's own iCloud. Benchmark and training
  photos come only from people who gave written consent, are stored **outside the repo** (default
  `~/SkinalyzeData/`), and are never uploaded to third-party labelling or training services without that consent
  covering it. Prefer self-hosted labelling (CVAT or Label Studio, local).
- **Deterministic verdicts:** counts and bands come from the detector + tested rules. No LLM in the loop.
- **Tests first** for every pure-logic piece (Swift Testing, in `SkinalyzeKit/Tests`). Pure logic lives in
  SkinalyzeKit so both the app and the benchmark tool use the exact same code; the app target only wraps Core ML.
- **Never silently re-score old scans.** Any change that moves numbers bumps a version (see M1.7) and old scans keep
  their stored counts until the user chooses "Re-analyse".
- **CloudKit schema is additive only** (new optional properties; no renames/deletions).
- **Performance budget** (PLAN.md §17): analysing 3 captures < 2.5 s on the oldest iOS 26 device class; peak memory
  during a scan < 350 MB. Measure on device after every inference change.
- **Copy:** tracker, not diagnosis. Run `scripts/lint_copy.py`.
- Work on a branch (`ml/detector-quality`), commit locally, **never push**.
- Tools: `Tools/DetectorBench` (run instructions in [benchmarks/README.md](benchmarks/README.md)).

## 2. Phases

Order matters: measure (M0) before changing anything, so every later step can prove it helped.

### M0 — Benchmark harness (do first, ~3–4 days)

Goal: one command prints accuracy and consistency numbers for the current pipeline, so "inaccurate" becomes a number.

- [x] **M0.1 Move the pure pipeline into SkinalyzeKit.** Extract from `AcneDetector.detect` everything except the
  Core ML call into a `DetectionPipeline` in `SkinalyzeKit/Sources/SkinalyzeKit/Detection/` that takes a closure
  `(CGImage) throws -> [RawDetection]` (the model run, crop-normalised) and returns final detections. `AcneDetector`
  becomes a thin wrapper. Existing behaviour and tests must not change (InferencePipelineTests stay green).
  *Done 2026-11-25:* `DetectionPipeline` (+ `VisionFaceAnalysis`, `CoreMLDetections`) in SkinalyzeKit; `AcneDetector` is a thin wrapper running `.shipping` (= baseline). Old tests unchanged and green.
- [x] **M0.2 Dataset layout + loader** (pure Swift, tested): a folder with `images/*.jpg|heic` and YOLO-format
  `labels/*.txt` (`class cx cy w h`, normalised), plus `meta.csv` (`file, subject_id, session_id, angle,
  fitzpatrick, lighting`). Class indices fixed in the order of `LesionType.allCases`.
  *Done:* `Tools/DetectorBench/Sources/BenchCore/Dataset.swift`. A missing label file = unlabelled photo (still used for consistency); an empty one = checked, no spots.
- [x] **M0.3 Metrics** (pure Swift, tested with hand-made fixtures):
  - matching: a prediction matches a ground-truth box of the same class if centre distance ≤ 0.5 × the GT box's
    larger side, or IoU ≥ 0.3 (IoU alone is too harsh for 3-px boxes); greedy by confidence;
  - per class: precision, recall, F1; a confusion matrix including "background" (missed / spurious);
  - small-object recall: GT boxes smaller than 1% of the face-crop width;
  - **count error** per photo and per zone (MAE), and Breakout Index error per scan;
  - **consistency** across repeat sessions of the same subject: band agreement and index coefficient of variation
    (reuse `ConsistencyMetrics`);
  - every metric also sliced by Fitzpatrick group and lighting.
  *Done:* `BenchCore/Matching.swift`, `Evaluation.swift`. Matching rule shared with the app (`DetectionMatching`). Also reports class-agnostic "spots found", the proposed grouped index (M1.6), and how many photos had no face.
- [x] **M0.4 `DetectorBench` tool.** A macOS command-line SwiftPM package at `Tools/DetectorBench/` (path
  dependency on `SkinalyzeKit`; compiles and runs the `.mlmodel` with Core ML on the Mac). Usage:
  `swift run DetectorBench --data ~/SkinalyzeData/bench --model Skinalyze/AIModel/acneObj28200.mlmodel --variant baseline`.
  It writes a Markdown report and a JSON file. Variants are flags (`--tiles 2x2`, `--class-thresholds file.json`,
  `--mask-landmarks`, …) so M1 changes can be compared side by side.
  Check the Mac and the iPhone produce the same detections on a few images (Core ML can differ slightly between
  CPU/GPU/ANE); if they differ, note the size of the difference in the report.
  *Done:* runs end to end (checked on synthetic images only). `--model-floor` was checked to reach the model. Mac-vs-iPhone check: the app export writes `device_detections.csv` and the report has a "Device parity" section — still to run on real exports.
- [ ] **M0.5 Collect the benchmark set** (owner + volunteers, with consent): ≥ 30 people, mixed skin tones and
  lighting; per person 3 sessions × (front, right, left) captured **with the app's own scan flow** (add a DEBUG-only
  "export last scan's photos" action in Profile that writes the three originals to the Files app). Label at least the
  front photos of every session; all three angles for 10 people.
  *Tooling done:* the export is a DEBUG launch argument `-exportBenchPhotos YES` (not a Profile button: Profile was being redesigned in parallel), writing `Documents/BenchExport/` in the bench layout. **Collecting photos is still open.**
- [ ] **M0.6 Labelling guide** in `docs/redesign/ml/LABELLING.md`: one paragraph and 3 example crops per class,
  what counts as background (pores, moles, freckles, scars, stubble, nostril shadow), minimum box size, how to box
  clusters. Two people label the same 30 photos; report per-class agreement (Cohen's κ). **If κ for
  papule/pustule/nodule is below ~0.5, the classes themselves are the problem** — feed that into M1.6.
  *Guide written:* [ml/LABELLING.md](ml/LABELLING.md). **Labelling and the κ check are still open** (needs D5).
- [ ] **M0.7 Baseline report** committed to `docs/redesign/benchmarks/YYYY-MM-DD-baseline.md` (numbers only, no
  photos). This is the bar every later change must beat.

Done when: one command reproduces the baseline report; the report shows per-class P/R, small-object recall, count
error, consistency, and skin-tone slices.

### M1 — Inference improvements without retraining (~1 week)

Each item is a separate commit, benchmarked against the previous one. Keep an item only if the report improves (or
consistency improves without recall dropping). Record the report in `docs/redesign/benchmarks/`.

- [ ] **M1.1 Tiling.** Run the model on overlapping tiles of the face crop at native resolution instead of the
  whole crop squeezed to 416: try 2×2 with 20% overlap, plus the whole crop (5 runs) to keep large lesions; then 3×3
  if the budget allows. Map tile boxes back to image space, drop boxes cut by a tile edge when the neighbour tile
  sees them whole, then merge with the existing cross-class NMS. Pure tile maths and merging in SkinalyzeKit with
  tests (tile rects cover the crop; a box near a seam is kept once; coordinates round-trip). Expected: the largest
  gain on blackheads/whiteheads. Watch the time budget: 3 photos × 5 runs = 15 model runs.
  *Code ready, not shipped:* `Tiling` + seam rule + merge in SkinalyzeKit with tests; bench flag `--tiles 2x2`. Decide with the benchmark.
- [ ] **M1.2 Skin mask from face landmarks.** Run `VNDetectFaceLandmarksRequest` on each capture; drop detections
  whose centre falls inside the eyes, eyebrows, outer lips or nostrils (slightly dilated polygons) or above the
  hairline (outside the face contour). Pure geometry in SkinalyzeKit with tests; Vision call in the app. Expected:
  fewer false positives.
  *Code ready, not shipped:* `SkinMask`/`SkinMaskBuilder` (eyes, brows, lips, lower nose outline as nostrils, below-jaw/outside-face). Vision has no hairline landmark, so the forehead top is the face box + 10%. Bench flag `--mask-landmarks`.
- [ ] **M1.3 Per-class confidence thresholds.** Replace the single 0.4 with a threshold per class chosen on the
  benchmark (maximise F1, or fix precision ≥ 0.8 for nodule because of its weight). Store them in one table in
  `DetectionFilter` with a test that every class has one.
  *Table in place:* `DetectionFilter.classThresholdTable`, every class 0.4 for now (no number change). Bench: `--class-thresholds file.json --model-floor 0.05`.
- [ ] **M1.4 Colour normalisation.** Gray-world (or skin-patch) white-balance and exposure normalisation of the face
  crop before inference (Core Image, off the main actor). Must be identical in the app and the bench. Keep only if
  it helps on the lighting slices.
  *Code ready, not shipped:* `ColorNormalization` (exposure + half-strength gray-world, gains clamped 0.5–2). Bench flag `--color-normalize`.
- [ ] **M1.5 Multi-frame agreement (needs device testing).** For the front angle, capture 3 stills in quick
  succession (or use the depth burst's video frames if their resolution is enough), detect on each, and keep a
  detection only if a matching box (centre distance rule from M0.3) appears in ≥ 2 of 3. Optionally add a
  horizontally flipped pass. Main goal: repeat scans agree. Touches `CameraSession`/`ScanCaptureModel`: verify on
  the owner's iPhone with the `[scan]` console log, and check the scan still feels instant.
  *Pure part ready:* `FrameAgreement.consensus`. Capture wiring and device testing still open.
- [ ] **M1.6 Steadier scoring.** Owner decision needed before shipping (see §3). Proposal: keep the six labels for
  display, but compute the index from groups — comedones (blackhead + whitehead, weight 1), inflamed (papule +
  pustule, weight 2), nodule (weight 4 but only above a high confidence; otherwise counted as inflamed), marks
  (weight 0). Tested in `BreakoutIndex`.
  *Proposal coded, not used for users' numbers:* `GroupedBreakoutIndex`; the bench reports its error next to the current index. Waits on D2.
- [ ] **M1.7 Versioning.** Add `pipelineVersion` (optional String, additive CloudKit change) next to `modelVersion`
  on `ScanSession`; bump it with any M1 change that moves numbers. The trend chart and Compare must mark a point
  where the version changed ("counted differently from here"). Add a "Re-analyse with the new detector" action on
  old scans (photos are stored, so they can be re-run); it replaces counts only after the user confirms. Tests for
  the migration and for "never re-score silently".
  *Storage done:* optional `ScanSession.pipelineVersion` (additive), set to `DetectionPipeline.shippingVersion` ("2d-1") on new scans; `CountingVersion` treats unversioned scans as 2d-1 and finds change points. **Still open:** the trend/Compare marker and the "Re-analyse" action (those screens were being redesigned in parallel).

Done when: the benchmark shows a clear gain over baseline (target: small-object recall +20 points, band agreement
across repeats ≥ 90%, index CV ≤ 25%, no skin-tone slice worse than baseline) and the 2.5 s budget holds on device.

### M2 — Grow the dataset (ongoing, owner-led)

- [ ] **M2.1 Find out what the current model was trained on** (ask the owner; PLAN.md Q3). If the original data and
  labels exist, re-check them against the labelling guide.
- [ ] **M2.2 Public data, cleaned:** ACNE04 (counts + boxes, single "acne" class — useful for a one-class spot
  detector), the Roboflow Universe acne sets, DermNet / Fitzpatrick17k images for darker skin. Check every
  licence for commercial use before using any of it; record the licence per source in
  `docs/redesign/ml/DATA-SOURCES.md`. Re-label to our guide; drop sets that can't be fixed.
- [ ] **M2.3 In-domain selfies:** expand the consented collection from M0.5 to a few hundred people over time — this
  matters more than any public set. Split train/validation/test **by person**, never by photo.
- [ ] **M2.4 Hard negatives:** label moles, freckles, scars, pores, stubble, eyebrow edges, nostril shadows as
  background (images with no boxes in those regions).

### M3 — Retrain (only if M1 leaves the model as the bottleneck; ~2–3 weeks)

- [ ] **M3.1 Choose the training stack — licence check first (owner decision, §3).** Ultralytics YOLO (v8/11) is
  the easiest and strongest for small objects, but it is **AGPL-3.0**: shipping its trained weights in a paid,
  closed-source app needs an Ultralytics enterprise licence. Permissive alternatives: YOLOX (Apache-2.0), RT-DETR
  implementations under Apache-2.0, or Create ML's object detector (Apple, no licence issue, weaker on tiny objects).
- [ ] **M3.2 Option A — one detector:** small/medium model, input 640–1024, trained on tiles of face crops (same
  tiling as M1.1), strong augmentation (blur, JPEG, white-balance and exposure shifts, front-camera noise, small
  rotations; **no** horizontal flips that break left/right zone semantics unless labels follow). Export to Core ML
  with NMS, FP16; then try 8-bit palettisation with coremltools to cut size, keeping it only if the bench says
  accuracy holds.
- [ ] **M3.3 Option B — two stages (recommended if M0.6 shows the types are hard to tell apart):** (1) a one-class
  "spot" detector tuned for recall, (2) a small classifier on a 64–96 px crop around each spot that outputs the type
  (Create ML image classifier is enough and licence-free). Each stage is easier to train, measure and improve; the
  classifier can say "unsure" and fall back to the comedone/inflamed group.
- [ ] **M3.4 Ship gate:** the new model must beat the M1 pipeline on the held-out test set overall **and** on every
  skin-tone slice, keep consistency targets, fit the time and memory budget on the oldest device, and stay under
  ~40 MB. New `modelVersion`; old scans untouched unless re-analysed (M1.7).

### M4 — Learn from the user (on device)

- [ ] **M4.1 Corrections UI:** long-press a pin on the result photo or 3D head → "Not a spot" / "This is a …". Stored
  locally per scan (additive model).
- [ ] **M4.2 Use them on device:** hide corrected pins immediately; recompute that scan's counts with the
  correction (deterministic, tested); after enough corrections, nudge that user's per-class thresholds within safe
  bounds.
- [ ] **M4.3 Optional data donation — owner decision, not to be built without it.** An explicit opt-in "Help improve
  Skinalyze: send this scan's photos and corrections" per scan, a privacy-policy and App Privacy label update, and
  storage the owner controls. This conflicts with "photos never leave the device" unless the owner approves it as an
  explicit, per-use consent exception (CLAUDE.md §3).

## 3. Decisions the owner must make

| # | Decision | Needed before | Recommendation |
|---|---|---|---|
| D1 | What data was `acneObj28200` trained on, and do we still have it? | M2 | Metadata says the Create ML app (6.0 beta, 28,200 iterations) — look for that Create ML project |
| D2 | Change how the index is computed (grouped classes, nodule gate) even though it shifts users' numbers? | shipping M1.6 | Yes, with M1.7 versioning and a "counted differently from here" marker |
| D3 | Training stack and licence (Ultralytics enterprise licence vs Apache-2.0 alternative vs Create ML) | M3 | Two-stage with an Apache-2.0 detector + Create ML classifier |
| D4 | Opt-in data donation (photos leave the device with consent) | M4.3 | Only after M0–M3 show where more data would help |
| D5 | Who labels (owner, paid annotators, dermatologist review of a sample)? | M0.6 | At least a dermatologist pass on the test set |

## 5. Possible future: use an existing model instead of retraining (researched 2026-11-25)

Owner asked whether a finished model could replace ours. Short answer: nothing found is ready to ship (on-device,
licence fit for a paid closed app, trained on selfies). Keep these in mind; any candidate goes through the benchmark
(`--model` takes any Core ML detector with the six labels) before anything else.

| Option | Pros | Blockers |
|---|---|---|
| Roboflow Universe / Hugging Face acne detectors | Free, many of them | Usually hosted API (photos leave the device) or Ultralytics weights (AGPL); "CC BY" on the page covers the dataset, not the weights; trained on clinical close-ups |
| ACNE04 (and its many re-uploads) | Standard benchmark, ~1,450 images, ~19k boxes | Original terms: academic use only — written permission from the author (Xiaoping Wu) needed for commercial use; re-uploads don't change that |
| Research models (ACNE8M, 9,440 images; YOLOv11 + skin-tone study, 3,118 images) | Larger, some skin-tone work | Weights/data availability unconfirmed; YOLOv11 is AGPL |
| Skin-analysis vendors with iOS SDKs (Perfect Corp, Haut.AI, GlamAR) | Proven, many skin tones | Paid; none confirmed on-device — cloud analysis breaks "photos never leave the device". Ask vendors about an on-device SDK before considering |
| **RF-DETR** (Roboflow) Nano/Small/Medium/Large | **Apache-2.0**, trains on YOLO-format data (our label format) | No official Core ML export (ONNX only; a community Core AI port exists, unverified). Best base if M3 happens |
| Our own Create ML project | Metadata shows the owner trained `acneObj28200` in the Create ML app — the project and labelled data may still exist | Find it (answers D1); retraining with more data is then cheap and licence-free |

Order if the M1 fixes are not enough: (1) find the Create ML project and retrain with more data; (2) fine-tune RF-DETR
on consented selfies plus licence-checked public data; (3) only then talk to vendors, on-device only.

## 4. Definition of done (whole plan)

- Benchmark report in `docs/redesign/benchmarks/` for baseline and for every kept change.
- Targets met on the held-out test set: small-object recall ≥ +20 points over baseline; band agreement across repeat
  scans ≥ 90%; index CV ≤ 25%; no skin-tone slice worse than baseline.
- Analysis of 3 captures < 2.5 s and < 350 MB peak on the oldest supported device, checked on hardware.
- All SkinalyzeKit tests pass (`scripts/test.sh`); copy lint clean; old scans unchanged unless re-analysed.
- PLAN.md §12.3 and this file updated with what was done and what was dropped (and why).
