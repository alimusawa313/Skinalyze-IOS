# App Store screenshots

"A day in Pimpi's Place": one hill and one dotted trail run through the whole set, and the sun crosses the sky from
sunrise (first shot) to night (last shot, the app in dark mode under the moon). Every shot is a real screen in a
chunky toy phone, with Pimpi stepping out of the frame and, on some, a piece of the screen lifted off as a sticker.

| Folder | Size | For |
|---|---|---|
| `screenshots/iphone-1206x2622` | 1206 × 2622 | iPhone, Dynamic Island medium (the required set) |
| `screenshots/iphone-1320x2868` | 1320 × 2868 | iPhone, Dynamic Island large |
| `screenshots/duo-outer-1398x2034` | 1398 × 2034 | iPhone Duo, outer display (closed, upright) |
| `screenshots/duo-inner-2853x2007` | 2853 × 2007 | iPhone Duo, inner display (open, wide) |

All PNG, RGB, no alpha. Order is the file prefix.

Captions (effort and fun only; no medical words, checked by `scripts/lint_copy.py`):

1. Meet Pimpi: *your tiny skin-care buddy*
2. One quick scan a day: *three angles, a few seconds*
3. Every spot, on the map: *tap a dot to see what it is*
4. See what changed: *any two days, side by side*
5. Is it good for me?: *ask about anything on your shelf*
6. Show up, earn streaks: *points for effort, never for skin*
7. Two-minute Skin School: *learn a little, earn a little*
8. Private by default: *your photos stay yours*

The inner display uses 1, 3, 4, 6 and 8, plus **Folded or open**: *Pimpi fits every screen* (Skin School in two
columns). On three of them the folded phone stands beside the open one, showing the same app on its front display
(screens captured on the outer display). The open phone is drawn without a crease.

The face in the scans is the debug demo data's illustrated portrait (`Skinalyze/Shared/DemoPortrait.swift`), never
a real person's photo. The 3D view in shot 3 is the Simulator's stand-in mesh; a capture from a device with
TrueDepth would show the real scan.

## Regenerate

```sh
# 1. Raw screens, light and dark, clean 9:41 status bar (StoreShotsUITests).
scripts/store-shots.sh <iPhone 18 Pro udid> <raw>/iphone
scripts/store-shots.sh <iPhone Duo udid> <raw>/duo-outer          # Duo closed, upright
DUO_INSPECTOR=280 <built scripts/duo-pose.swift> open             # unfold (Device Hub in front)
STORE_TEST=testApp scripts/store-shots.sh <iPhone Duo udid> <raw>/duo-inner light
STORE_TEST=testOnboarding scripts/store-shots.sh <iPhone Duo udid> <raw>/duo-inner dark
#    The inner display's captures come out in the panel's portrait orientation: rotate them a quarter turn clockwise.
#    The scan moment's timing varies: copy the clean "Reading your skin…" frame (sticker-N.png) to scan.png.
# 2. Frame them (StoreShotArt, a debug-only renderer in the app; build build/sim first).
scripts/store-render.sh <raw> docs/appstore/screenshots
```
