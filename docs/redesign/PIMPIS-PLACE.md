# Pimpi's Place — the design language

> Owner picked this direction on 2026-11-25 (it replaces the dark live-camera "Mirror" look of V2-BOLD.md).
> The drawn screens live on the design canvas: https://claude.ai/artifact/V2S8YrPDv8p9wwNeumHHtc

## The idea

Home is Pimpi's place: a cream sky, a pink hill, Pimpi standing on it with one hand-written line for you. Every
other screen is the same place: content that needs attention sits on the sky, things you press sit on the hill.
Pimpi is on most screens, small, reacting to what you do.

## Rules

1. **Tokens only.** Colours from `Color.ds.*`, type from `Font.ds.*`, spacing from `Spacing`, radii from `Radius`,
   sizes from `Chunk`. No raw hex, no `.white` / `.black`, no magic numbers in views (name them in a private
   `Metrics` enum). No gradients as decoration, no glass (`glassEffect`, `.buttonStyle(.glass)`), no drop shadows.
2. **Pressable things stand proud.** Buttons, rows you tap and chips have a hard bottom edge and sink when pressed:
   `.buttonStyle(.chunky)` (the one filled primary action per screen), `.chunkyPlain`, `.chunky(.plain, fullWidth: false)`,
   `.chunkyIcon`, `Chip`, `PillPicker`. Resting panels use `.dsSurface()` / `.dsCard()`.
3. **Sky and hill.** `.dsHill(crest:)` or `HillShape` for the ground; content laid over the hill gets `.onHill()` so
   edges pick the hill's edge colour. Text on both is `Color.ds.ink` / `Color.ds.inkSecondary`.
4. **Pimpi's voice is handwriting** (`Font.ds.pimpi`, `SpeechBubble`) and is only for what Pimpi says. Pimpi cheers
   effort (showing up, streaks, routines) and never comments on how skin looks. Facts, numbers, verdicts and
   disclaimers stay in the normal type. Verdicts still come from the tested rules.
5. **One hero per screen**, few elements, no stacks of bordered cards. Heavy rounded type for titles and numbers.
6. **Light is the day palette, dark is dusk** (deep navy sky, violet hill). Never force a colour scheme on a screen
   (except the sticker moment and the 3D viewer, which stay dark by design).
7. Everything in CLAUDE.md still holds: every iPhone shape and pose, Dynamic Type to AX5, Reduce Motion fallbacks,
   every tappable thing is a `Button` with a label, tracker-not-diagnosis copy.

## Building blocks (SkinalyzeKit/DesignSystem/Place.swift)

`HillShape`, `HillBackdrop`, `.dsHill()`, `.onHill()`, `ChunkyButtonStyle`, `ChunkyIconButtonStyle`, `.dsSurface()`,
`SpeechBubble`, `PillPicker`, `Chunk`. Mascot: `Pimpi(mood:)` (SharedSources/System/Pimpi.swift), outfit from the
`pimpiOutfit` environment value; its outfits use their own `outfitRed/Green/Gold` tokens, never the status colours.

**Pimpi on a screen is always `PokablePimpi`** (Skinalyze/Shared/PokablePimpi.swift): a poke squashes it, makes it hop
and gives a light tap; pass `cheer:` to make it hop when the user does something (effort only), or `onPoke:` when the
screen decides what a poke changes. Don't write another one.

## Interaction (owner requirement, 2026-11-25: "all should be interactive")

Every screen reacts to touch: pressables sink, Pimpi is pokable and reacts to what you just did, selections slide,
checkmarks bounce, numbers roll (`.contentTransition(.numericText)`), new content pops in (`.popIn()`), each screen's
moment (chest, verdict, sticker, lesson done) is a small keyframe animation, haptics through `Haptic`. Every animation
has a Reduce Motion fallback. A static restyle is not done.

## Behaviour changes that came with the redesign

- Home does not run the camera; it opens when a scan starts and stops when you leave the scan.
- Tapping a filled shelf slot shows its verdict beside Pimpi (it counts as a product check); the name opens the page.
- On a free account only a sideways drag on the 3D head asks for Pro (a vertical swipe scrolls the page).
- The status colours (signal, positive, caution) are darker in light mode so they read as text on the hill (tested).
