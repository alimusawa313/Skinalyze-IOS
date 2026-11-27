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

## Product page header and search result

In `hero/`, made to Apple's [asset best practices](https://developer.apple.com/app-store/asset-best-practices/):

| File | Size | What |
|---|---|---|
| `header.png` / `header.mp4` | 3840 × 1646 (21:9), video 8 s, 30 fps | Pimpi waving "hi!" on the hill, stickers of real moments floating around it (streak, compare, Good match), the iPhone and the open iPhone Duo either side. No text. |
| `search.png` / `search.mp4` | still 3840 × 2560, video 1920 × 1280 (3:2), 9 s, 30 fps | "Your tiny skin-care buddy": a phone stepping through real screens (Home, scan, compare, product check, streaks, Skin School), each moment's sticker popping out, Pimpi hopping beside it. |

Key art sits inside Apple's safe areas (header 1646 × 661 at 1097, 493; search 2168 × 1030 at 836, 765, on the
3840-wide template). The videos work silently (a silent stereo track only), loop seamlessly (every motion is a whole
cycle per loop; the last frame differs from the first no more than any two neighbouring frames) and are H.264 MP4.
Upload with `fastlane creative` (the videos; `fastlane creative images:true` for the stills): it puts them in the
app's Asset Library and places them on version 2.0 (en-US) through the App Store Connect API (`fastlane/creative_assets.rb`;
deliver doesn't know these assets yet). They are reviewed with the version.

Regenerate (after the raw screens above): `scripts/store-hero.sh <raw> docs/appstore/hero` (renderer:
`Skinalyze/Shared/StoreHeroArt.swift`, debug builds only).

## In-app events

Nine events through October 2027, defined in `fastlane/metadata/events.json` (text, badge, schedule, deep link) with their films in
`events/`. Each film is a 10 s seamless loop at 30 fps (H.264, a silent stereo AAC track) in two sizes: the event card
(`<event>-card.mp4`, 1920 × 1080) and the details page (`<event>-details.mp4`, 1080 × 1920); the PNGs are stills of the
same frame. Apple asks for no text or logos in event media and lays the badge, name and description over the bottom,
so the key art sits in the top two-thirds and the near hill fills the rest.

| Event | Badge | Runs (UTC) | Opens | Film |
|---|---|---|---|---|
| Meet Pimpi: Skinalyze 2.0 | Major Update | Dec 3, 2026 – Jan 2, 2027 | `skinalyze://today` | Pimpi in a party hat waving hello in confetti, between Home and the scan |
| Your 2026 Skin Wrapped | Special Event | Jan 1 – 7, 2027 (shown from Dec 25) | `skinalyze://wrapped` | A night of fireworks; a gift box opens and the year's stat cards fan out |
| 30 Days of Sunscreen | Challenge | Jan 1 – 31, 2027 (shown from Dec 18) | `skinalyze://challenge/sunscreen` | Pimpi in sunglasses under a big sun while a 30-day card fills in, then a cheer |
| 30 Days of Morning and Evening | Challenge | Feb 1 – 28, 2027 | `skinalyze://challenge/morningAndEvening` | Pimpi in a scarf beside a jar; the day turns to night and back while the card fills in |
| 30 Days of Hands Off | Challenge | Mar 1 – 31, 2027 | `skinalyze://challenge/handsOff` | Pimpi in a bow beside a raised-hand sign |
| Your Skin Wrapped: Jan–Mar | Special Event | Apr 1 – 7, 2027 | `skinalyze://wrapped` | The gift box under falling petals, Pimpi with a flower |
| Summer Sunscreen Challenge | Challenge | Jun 1 – 30, 2027 | `skinalyze://challenge/sunscreen` | The sunscreen film with a flower and confetti |
| Your Skin Wrapped: Apr–Jun | Special Event | Jul 1 – 7, 2027 | `skinalyze://wrapped` | The gift box under a big sun, Pimpi in sunglasses |
| Your Skin Wrapped: Jul–Sep | Special Event | Oct 1 – 7, 2027 | `skinalyze://wrapped` | The gift box under falling leaves, Pimpi in a beanie |

`skinalyze://wrapped` opens last year's Wrapped in the first week of January, the quarter that just ended in the first
week of April, July and October (the app only offers it then), and otherwise the last finished quarter's;
`skinalyze://challenge/<kind>` offers that 30-day challenge (`ChallengeInviteView`). Both links need 2.0.1 or later;
in older builds they land on Home. Every event after Meet Pimpi starts at 10:00 UTC, so it's already the 1st in every
time zone. The Wrapped and challenge films share two scenes, varied by a look (`WrappedLook`, `ChallengeLook`: sky,
outfit, prop).

Upload with `fastlane events`: it creates or updates each event (matched by reference name) in every territory the
app is sold in, its en-US text and both videos, and leaves them as drafts (`fastlane/app_events.rb`). Submit each one
from App Store Connect with, or after, the app version its link needs.

Regenerate the films: `scripts/store-events.sh <raw> docs/appstore/events [event]` (renderer:
`Skinalyze/Shared/StoreEventArt.swift`, debug builds only; `STILLS_ONLY=1` for just the stills).
