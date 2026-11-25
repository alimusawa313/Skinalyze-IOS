# Detector benchmark reports

One Markdown + JSON pair per run, written by `Tools/DetectorBench` (ML-PLAN M0.4). Reports hold **numbers only**: no
photos, file names or subject IDs. Commit the baseline (M0.7) and every M1 change you keep or drop, so the decision
can be traced.

## Run

```sh
cd Tools/DetectorBench
swift run -c release DetectorBench \
  --data ~/SkinalyzeData/bench \
  --model ../../Skinalyze/AIModel/acneObj28200.mlmodel \
  --variant baseline
```

The dataset layout and labelling rules are in [../ml/LABELLING.md](../ml/LABELLING.md). Variants (each M1 item is a
flag; combine them):

| Flag | Plan item |
|---|---|
| `--tiles 2x2` (`--overlap 0.2`, `--no-whole-crop`) | M1.1 tiling |
| `--mask-landmarks` | M1.2 skin mask |
| `--class-thresholds thresholds.json --model-floor 0.05` | M1.3 per-class thresholds (the floor lets thresholds go below the model's own default) |
| `--color-normalize` | M1.4 colour normalisation |
| `--cpu-only` | Compare Core ML on CPU vs GPU/Neural Engine |

Name the variant after what changed, e.g. `--variant tiles-2x2-mask`. The report says whether the run matches what
the app ships. `--model` takes any Core ML object detector with the same six labels, so a candidate replacement model
can be compared the same way.

## What is not in these reports

- **Device timing.** The Mac timings only compare variants. The 2.5 s / 3 photos budget is measured on the oldest
  supported iPhone (watch the `[scan]` log).
- **Multi-frame agreement (M1.5)** needs burst captures; the dataset has one photo per angle.
- **Labeller agreement (κ).** Computed from the two labellers' files and added to the baseline report by hand.

## Notes from setting it up (2026-11-25)

- The model's metadata says it was trained in the Create ML app (version 6.0 beta, Create ML 15.1, 28,200
  iterations). It has optional `confidenceThreshold` and `iouThreshold` inputs; the app leaves both at the model
  defaults. Setting `--model-floor` was checked to pass through to the model.
- No real photos were available yet, so the tool was only run end to end on synthetic images. Those numbers mean
  nothing and were not committed.
