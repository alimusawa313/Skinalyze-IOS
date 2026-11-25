# Labelling guide — acne benchmark (ML-PLAN M0.6)

For whoever draws boxes on benchmark photos. The goal is a benchmark that two careful people would label the same
way, so the numbers measure the detector and not the labeller.

**Privacy first.** Label only photos of people who gave written consent. Photos live outside the repo (default
`~/SkinalyzeData/bench/`). Label with a tool that runs on your own machine (Label Studio or CVAT, local install). Never
upload photos to a hosted labelling service unless the consent covers it. Never commit photos or label files.

**Labelling is not diagnosis.** You are marking what is visible on a photo for a tracker. Don't write medical notes.

## Setup

1. Get the photos with the app's debug export: run a Debug build with the launch argument `-exportBenchPhotos YES`,
   then Xcode → Devices and Simulators → Skinalyze → Download Container → `Documents/BenchExport/`. Copy it to
   `~/SkinalyzeData/bench/`. You get `images/`, `meta.csv` and `device_detections.csv`.
2. In `meta.csv` fill in `subject_id` (one ID per person, e.g. `S07`; never a name), `fitzpatrick` (I–VI) and
   `lighting` (`indoor`, `window`, `outdoor`, `dim`). Keep commas out of every field.
3. Set the tool's class list in exactly this order (it becomes the class index in the label files):

   | Index | Class | Index | Class |
   |---|---|---|---|
   | 0 | blackheads | 3 | pustules |
   | 1 | whiteheads | 4 | nodules |
   | 2 | papules | 5 | dark spot |

4. Export in **YOLO** format to `labels/<photo name without extension>.txt`, one line per box:
   `class cx cy w h`, normalised to the photo, origin top-left. A photo you have checked and found clear gets an
   **empty** `.txt` file. A missing `.txt` means "not labelled".

## Classes

| Class | What to box | Commonly confused with |
|---|---|---|
| **blackheads** | Open comedone: a small dark dot in a pore, flat, no redness around it. Usually nose, chin, forehead. | Ordinary dark pores (box only if clearly plugged), stubble, freckles |
| **whiteheads** | Closed comedone: a small skin-coloured or white bump, no redness, no visible pus. | Milia (harder, pearl-like; skip them), pustules (whiteheads have no red ring) |
| **papules** | Red, raised, solid bump without a visible white or yellow centre. | Pustules (look for a pale centre), nodules (papules are small and shallow) |
| **pustules** | Raised bump with a visible white or yellow centre, usually with a red ring. | Whiteheads (no red ring), papules |
| **nodules** | Large, deep, swollen lump, clearly bigger than papules nearby (roughly ≥ 5 mm), often without a head. | Large papules, clusters. **When unsure, use papules.** Nodules carry the most weight in the index. |
| **dark spot** | Flat brown or dark mark left after a breakout (post-inflammatory marks). | Moles, freckles, birthmarks (not marks), shadows |

Keep three example crops per class in `~/SkinalyzeData/bench/guide/` (from consenting subjects, outside the repo) and
look at them before each session. Don't put example photos in this file.

## Background: don't box these

Pores, moles, freckles, birthmarks, scars without colour, stubble and hair follicles, eyebrow edges, eyelashes, lips,
nostril shadows, the inside of the nose, glasses frames, jewellery, makeup specks, reflections and specular highlights,
and anything off the face (neck, ears, hairline, background).

## Boxes

- Draw the box tight around the visible lesion, including the red ring of an inflamed spot but not the wider blush.
- **Minimum size:** if you can't tell what it is when zoomed to 200%, don't box it. Never draw a box smaller than
  3 × 3 pixels.
- **Clusters:** box each spot you can tell apart. Draw one box around a cluster only when the spots merge into one
  lump; label it with the most severe type in it.
- **Partly hidden** (hair, edge of the photo, turned away): box the visible part if at least half the spot is visible.
- **Side photos** (`right`, `left`): label the whole visible face; the benchmark decides which photo owns which zone,
  the same way the app does.
- **Unsure between two types:** pick the less severe one (whitehead over pustule, papule over nodule) and note the
  photo name in your own notes, outside the repo.

## Agreement check

Two people label the same 30 front photos without seeing each other's boxes. Match boxes with the benchmark's rule
(same spot if the centres are within half the larger box side, or IoU ≥ 0.3) and report Cohen's κ per class in the
baseline report. **If κ for papules, pustules or nodules is below about 0.5, the classes themselves are the problem**,
not the model. That points to the grouped scoring (ML-PLAN M1.6) and a two-stage detector (M3.3).

## Order of work

1. All front photos of every session.
2. All three angles for 10 people.
3. The 30-photo agreement set, labelled by a second person.
4. If a dermatologist is available (ML-PLAN §3, D5), they review the test split.
