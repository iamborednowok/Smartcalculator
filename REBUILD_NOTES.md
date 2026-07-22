# SmartCalc Rebuild — v3 ("RGB Neon")

This file is the living reference doc for the rebuild (replaces the old
`OVERHAUL_NOTES.txt`, which only tracked incremental fixes to the previous
design and has been removed — see "Files removed" below).

## Direction

- **Bold**: one loud accent (red) for primary actions/"=", one cool accent
  (blue) for operators & secondary actions, plus green and cyan joining in
  as extra gradient stops so primary CTAs sweep red → green → blue — a
  real RGB gradient. Each tab also gets its own identity color (see
  `Theme.tabColors`) for its nav pill, so navigation itself reads as
  colorful rather than a single accent everywhere.
- **Minimal**: generous spacing, and screens are allowed to have empty
  space — button grids don't stretch to fill their tab, a flexible spacer
  sits above them. (Note: an earlier draft of this doc described this
  direction as "flat surfaces, no gradients/glass" — that was true only
  very briefly. Glow and gradient accents were added on top of the flat
  layout shortly after and are now part of the design, see `Theme.qml`'s
  own "v4" header comment. Fixed here since the two had drifted out of
  sync.)
- **Orientation-aware**: the app now reflows by which way the device is
  actually held (`root.isWide`, driven by `width > height`), not by an
  absolute size breakpoint. See "Navigation" and "ProgrammerTab's
  landscape layout" below — this is new in this pass and replaces the old
  600px-width split.

## Design tokens — `qml/Theme.qml`

Every color in every tab is read from this one file. Nothing below is
hardcoded elsewhere, so a full re-color is a single-file edit.

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#FAFAF7` | `#0B0B0E` | window background |
| `surface` | `#F0EEE9` | `#18181C` | digit buttons, cards, chips |
| `surface2` | `#E8E4DC` | `#22222A` | operator buttons, dividers |
| `text` | `#15151A` | `#F5F5F2` | primary text |
| `textDim` | `#8C8A82` | `#8A8890` | secondary text |
| `textFaint` | `#CFCCC2` | `#46454E` | inactive nav/toggles |
| `accent` / `gradA` | `#FF3B5C` | same | "=", primary CTAs, active states, errors |
| `accent2` | `#2F7BFF` | same | operators, ribbon underlines, secondary actions |
| `gradB` | `#1B9E5E` | same | gradient middle stop (red→green→blue sweep) |
| `gradC` | `#22D3EE` | same | gradient end stop; also Convert's swap-button pair with `gradA` |

`Theme.tabColors` — 7 colors, one per tab in `allTabs` order (Calc, Formula,
Convert, Random, Graph, Programmer, AI), reusing hues already established
above (`accent`, `gradB`, `accent2`, `gradC`) plus 3 more shared with
`GraphTab.graphColors` (amber, magenta, violet) rather than inventing a
second disconnected palette. Drives `TabPillBar`'s per-tab pill color and
`ProgrammerTab`'s Ops Card button variety.

`Theme.bgStreakColors` — the 4-color subset (red/green/blue/cyan) used by
`AmbientGlow`'s background streaks (both modes as of the light-mode-parity
pass below — this comment used to say "dark-mode" specifically, which
stopped being true).

`Theme.glowColor(base, opacity)` — turns any base color into a glow-ready
`rgba`, e.g. `Theme.glowColor(Theme.tabColors[i], Theme.glowOp)`. Replaces
hand-deriving a `glowX`/`glowX2` constant pair per hue, which stopped
scaling once tabs/buttons needed 7+ colors instead of 2.

`Theme.textOn(fill)` — picks black or white text for a given fill color
using a perceived-brightness heuristic (not full WCAG contrast math, just
enough to pick a side). Needed once pill/badge fills could be any of the 7
tab colors — two of them (amber, cyan) are light enough that white text on
them fails contrast, unlike the original two accents which were both dark
enough for white text unconditionally.

`Theme.edgeOp`/`edgeA`/`edgeA2`/`edgeB`/`edgeB2` — crisp colored border
tokens, `0.42` opacity in *both* modes on purpose. Sibling to the
`glowOp`/`glowA`/`glowB` blur-bloom system, not a replacement for it: a
blurred bloom only reads as "glowing" against a dark backdrop, so that
system stays dark-only, but a thin saturated border reads fine on white
too — it just hadn't been given a light-mode-compatible token before.
See "Light mode gets its own neon" further down for the full story.

Spacing scale `sp1..sp6` = 4/8/14/22/34/52 × `Theme.scale`.
Radii `rSm/rMd/rLg` = 10/18/26 × `Theme.scale`.

**One intentional exception** — not a bug, don't "fix" this by routing it
through Theme:
- `GraphTab.graphColors` — an 8-color fixed palette so multiple plotted
  curves stay distinguishable. This is chart/content coloring (like a
  legend), not app theming. Only the first entry is theme-driven
  (`Theme.accent`, so it matches the default pre-loaded curve) — the
  other 7 are deliberately fixed literals, refreshed during the color
  pass below to harmonize with the new palette.
  *(Correction: an earlier draft of this doc claimed the first entry
  already referenced `Theme.accent` — it didn't; it was a plain hex
  literal that happened to match the old accent value and would have
  gone stale the moment `accent` changed. That's now actually fixed.)*
  *(A second exception used to be documented here — the `"#000000"` modal
  scrim behind `MoreSheet`. `MoreSheet` doesn't exist anymore, see
  "Navigation" below, so there's nothing left to carve out an exception
  for. If a future modal/sheet needs a scrim, the same reasoning still
  applies: scrims are conventionally plain black-with-opacity regardless
  of light/dark mode, so it should stay a literal, not route through
  `Theme.text`.)*

**Color pass — done.** See "Color pass + bug fixes" at the bottom for
the full list of what changed.

## Architecture notes

- **Shared backend instances** — `mathEngine`, `settings`, and `apiClient`
  are each declared exactly **once**, at `Main.qml`'s root, and reached by
  every tab through QML's normal id scope-chain (every tab is instantiated
  as a direct child of `Main.qml`). `FileHelper` is the one exception —
  it's declared locally inside `AITab.qml` only, since nothing else needs
  it (matches `FileHelper.h`'s own doc comment).
  **Do not** declare a second local `MathEngine {}` / `AppSettings {}`
  inside a tab — that silently forks state into two independent objects.
  An early pass of this rebuild made exactly that mistake in `CalcTab.qml`;
  it's fixed now, noted here so it doesn't come back.
- **Navigation is data-driven from one array** — `allTabs` in `Main.qml` is
  the single source of truth (icon, label, index). Add/rename/reorder a
  tab by editing that array only; `TabPillBar` renders it automatically,
  and each tab's pill color comes from `Theme.tabColors[index]` rather
  than from a field on the array itself.
  *(The `primary` flag that used to live on each `allTabs` entry is gone —
  it only existed to decide what showed in the bottom bar vs. folded under
  "More", and neither exists anymore; see below.)*
- **One nav, every orientation** — `TabPillBar` (colorful, glowing,
  horizontally-scrollable pills) replaces the old `TopRibbon` (wide) /
  `AppTabBar` + `MoreSheet` (narrow) split entirely. It's always at the
  top, in both orientations. This was a deliberate redesign, not just a
  rename: the previous design showed only "primary" tabs in the bottom bar
  and folded the rest under a "More" sheet; a single scrollable pill row
  can reach all 7 tabs directly, so that distinction — and the dead-weight
  of maintaining three nav components in lockstep — went away with it.
- **Orientation drives layout, not size** — `root.isWide` in `Main.qml` is
  now `width > height` (device orientation) instead of `width >= 600`
  (an absolute size breakpoint). The old threshold happened to *approximate*
  orientation on a phone (landscape width usually clears 600px), but it's
  wrong on its own terms — e.g. a tablet held in portrait is often still
  wider than 600px and would have incorrectly gotten the landscape
  treatment. Comparing width to height directly answers "which way is the
  device held" regardless of the device's absolute size, and updates the
  instant the device rotates. `ProgrammerTab` is the tab that currently
  reflows its internal layout based on this (see below); the rest keep the
  same content regardless of orientation, just more/less width to work
  with, same as before.
- **`GroupTabs`** is the reusable ribbon-style group selector (a flattened,
  single-row take on the "grouped command tabs" idea from Office-style
  ribbons). Takes a model of strings or `{label, value}` objects plus
  `currentValue`, emits `selected(value)`. Used for: Convert's category
  switcher, Programmer's base + bit-width rows, Formula's category switcher,
  Random's mode switcher, AI's model picker.
- `HapticHelper` stays a singleton, used the same way (`HapticHelper.click()`
  / `.heavy()`).
- `ApplicationWindow.window` attached property used for cross-tab helpers:
  `window.addHistory()`, `window.showToast()`, `window.currentTab`,
  `window.calcHistory`.

## Deliberate simplifications (vs. the original tabs)

- **CalcTab**: dropped rich syntax-highlighting of the expression and the
  separate `showVars` panel (variables now live in the "store → A/B/C…"
  strip after `=`) and the `parenBalance` hint — all in favor of a calmer,
  single-color display.
- **FormulaTab**: dropped the per-formula rainbow accent colors (a distinct
  hex per formula). Rows differentiate by icon + name now, consistent with
  the one-loud-accent direction.
- **RandomTab**: the original stacked all 4 sections (Dice/Coin/Range/Quiz)
  permanently on screen. Converted to a `GroupTabs` mode switcher showing
  one section at a time — same density problem GroupTabs was built to
  solve elsewhere, so it made sense here too. Per-difficulty rainbow colors
  in the quiz dropped for the same reason as Formula's.
- **GraphTab / AITab**: these two are the exception to "flexible spacer
  above content" — the plotted graph and the chat log *are* the
  variable-height payload of their tabs, so they're given `Layout.fillHeight`
  instead of being squeezed above a spacer. (This was the open question in
  the previous version of this doc — resolved.)
- **Navigation**: the old custom-icon-file system (`TabIcon.qml`, drop a
  `calc.png`/`.svg`/`.jpg` into `qml/icons/`, PNG→SVG→JPG fallback chain) is
  removed. Tab icons are now plain text/emoji glyphs defined directly in
  `allTabs` — simpler, and there's only one place to edit per tab instead of
  a file-naming convention plus a CMake RESOURCES entry.

All other logic — math evaluation, unit conversion, the full math-quiz
problem pool, dice/coin/range randomization, bitwise ops (including the
64-bit-safe hi/lo decomposition and the Int32-coercion-avoidance comments),
graph pan/zoom/pinch math, AI send/vision/offline-calc/JSON parsing — was
kept logically identical to the original. Only chrome and layout changed.

## Files removed in this pass

- `qml/main.qml` (lowercase) — an orphaned duplicate of `Main.qml`, never
  referenced by `CMakeLists.txt`'s `QML_FILES` (which only ever loaded the
  capital-M version). Different content, never loaded — dead file.
- `qml/components/TabIcon.qml`, `qml/icons/README.md` — the custom-icon-file
  system described above; superseded by plain icon glyphs in `allTabs`.
- `qml/components/UnitPill.qml` — Convert's unit chips are now inline
  `Rectangle`s in `ConvertTab.qml` instead of a separate component.
- `OVERHAUL_NOTES.txt` — superseded by this file.
- `qml/components/TopRibbon.qml`, `AppTabBar.qml`, `MoreSheet.qml` — all
  three replaced by the single `TabPillBar.qml` (see "Navigation" above).
  This is a genuine redesign, not a rename: the primary/secondary tab
  split these three existed to support is gone, not just relocated.

## Files added in this pass

- `qml/components/TabPillBar.qml` — the new unified nav (see "Navigation").
- `qml/components/AmbientGlow.qml` — decorative dark-mode-only background
  streaks behind the app chrome (red/green/blue/cyan, very low opacity).
  Built from plain `Rectangle` + `Gradient` only — deliberately not using
  a blur/shader effect, since `CMakeLists.txt` doesn't link
  `Qt6::QuickEffects` (Qt 6.5+'s `MultiEffect`) or the older
  `Qt5Compat.GraphicalEffects`, and adding a new Qt module dependency for
  a decorative background wasn't worth doing without being able to verify
  it actually links on the Android build target. Each streak fades to
  transparent at both ends (soft along its length); kept thin and low-
  opacity enough that the un-blurred perpendicular edges read as a light
  beam rather than a hard-edged bar, and foreground text always stays
  legible on top of it.

`qml/components/PlaceholderTab.qml` is **kept** even though nothing
currently uses it — it's a one-line drop-in stub for scaffolding a brand
new tab before it's fully built, which is the kind of thing worth having
on hand for future updates.

## Phase status

- [x] **Phase 1 — Foundation**: `Theme.qml`, `CalcButton`, `ToastMessage`,
      `GroupTabs`, `PlaceholderTab`, `Main.qml` shell with data-driven nav,
      `CalcTab.qml`. (Originally built with `AppTabBar`/`MoreSheet`/
      `TopRibbon` as the nav; those three were later replaced by
      `TabPillBar` — see "Navigation" and "Layout + navigation overhaul"
      below. Noted here so the phase history stays accurate rather than
      silently rewritten.)
- [x] **Phase 2 — Remaining tabs**: `ConvertTab`, `FormulaTab`, `RandomTab`,
      `GraphTab`, `ProgrammerTab`, `AITab` — all rebuilt, all wired into
      `Main.qml`'s `StackLayout`, all functionally equivalent to the
      originals (see Simplifications above for the few intentional drops).
- [x] **Phase 3 — Backend (C++) review**: read every file (`ApiClient`,
      `AppSettings`, `FileHelper`, `HapticHelper`, `MathEngine`, `main.cpp`).
      Most of it didn't need touching — `MathEngine`'s custom graph parser
      and injection-safe `eval()` wrapper in particular are already careful,
      documented, and battle-tested (see its inline "FIX #NN" history) and
      were deliberately left alone. One real bug found and fixed: see
      "Next up" below. Not a rewrite — just this one fix.
- [x] **Phase 4 — Android/CMake**: `AndroidManifest.xml` and
      `CMakeLists.txt`'s Android-specific parts confirmed unchanged and
      still correct. Splash/pre-render background uses the system
      `@android:color/black`, which already reads as near-identical to
      `Theme.bg`'s dark value (`#0B0B0E`) — nothing there depended on the
      old accent colors, so the color pass needed no Android-side changes.

## Color pass + bug fixes (this update)

**Color pass — done.** `accent` (red `#FF3B5C`) and `accent2` (blue
`#2F7BFF`) replace coral/violet; `gradB` (green `#1B9E5E`) and `gradC`
(cyan `#22D3EE`) are new. All still single-file (`Theme.qml`) for the
*values* — but the hero-button gradient itself changed shape from 2-stop
to 3-stop (red→green→blue) in 7 places (`CalcButton`, `TopRibbon`,
`FormulaTab`, `ProgrammerTab`, `GraphTab`, `AITab`, `RandomTab`), so a
*future* re-color only needs `Theme.qml` again, but this specific pass
touched the gradient-bearing files too. `GraphTab.graphColors`' other 7
fixed literals were also refreshed to harmonize (see exceptions above).

**Real bugs found during this pass (not just color):**
- `ApiClient::sendToAI` — the "no OpenRouter key" fallback path built a
  complete Anthropic request but sent a hardcoded empty `x-api-key`
  header, so it 401'd on every call. The real key was never passed
  through from `AppSettings.anthKey`. Now it is — chat works with just an
  Anthropic key, not only OpenRouter's free tier. Fails fast with a clear
  message if neither key is set, instead of firing a doomed request.
- `ProgrammerTab`'s "other 3 bases" row mislabeled itself — a leftover
  array lookup meant `array[10]` (index, not value) resolved to `"HEX"`
  instead of `"DEC"`, so the DEC row displayed the label "HEX" whenever
  the active base wasn't 10. Replaced with a plain `{10:"DEC",...}` map
  (matches how the web preview already did it correctly).
- `FormulaTab`'s "copy" row showed a "Copied" toast without ever touching
  the clipboard. Wired to the same hidden-`TextEdit` pattern CalcTab/
  ConvertTab/AITab already use.
- `GraphTab.graphColors[0]` was a plain `"#FF4D2E"` literal duplicating
  the (old) accent value rather than a live `Theme.accent` reference —
  it would have silently gone stale the instant `accent` changed, unlike
  the default pre-loaded curve above it, which already referenced
  `Theme.accent` live. Now `graphColors[0]` does too.

**Small refactors/optimizations alongside the above:**
- `Main.qml.addHistory()` — manual capped-array loop replaced with
  `.slice(0, 49)` + `.concat(...)`.
- `CalcTab.qml.handleBtn()` rebuilt two operator-key arrays (and ran
  `.indexOf` on them) on every single keypress; hoisted to two
  `readonly property var` constants.
- `ProgrammerTab`'s bit-cell press-flash hardcoded `color: "white"`;
  now `Theme.onAccent` (same value, keeps every color routed through
  Theme).
- `RandomTab`'s quiz correct/wrong feedback used blue/red — now
  green/red, a more intuitive convention now that green is genuinely
  part of the palette (was blue vs. red before, which didn't map to
  "success" as clearly).
- `main.cpp`'s standalone crash-recovery screen (shown when the QML
  engine itself fails to load, so it deliberately can't depend on
  `Theme.qml`) had its 3 hardcoded violet values refreshed to the new
  blue, for brand consistency — still fully self-contained by design.

**Not changed, and why:** `MathEngine.cpp`'s expression parser/evaluator,
`FileHelper`, `HapticHelper`, and the Android manifest/CMake config were
all reviewed and left as-is — already solid, and outside the scope of a
color + light refactor pass. App launcher icons (the raster PNGs under
`android/res/mipmap-*`) were also left alone — recoloring a baked bitmap
icon is a separate icon-design task, not a UI theme change.

## Layout + navigation overhaul (this update)

Follow-up pass on top of the color pass above, prompted by reference
mockups showing a landscape 3-card Programmer layout and a colorful
pill-style nav in both orientations.

**Navigation, rebuilt, not just recolored:**
- `TabPillBar` (new) replaces `TopRibbon` + `AppTabBar` + `MoreSheet`
  (removed). One scrollable pill row, always at the top, in every
  orientation. Each tab gets its own color from `Theme.tabColors` instead
  of everything sharing one accent; the active pill fills solid + glows,
  inactive pills stay quiet (colored icon, neutral label) so the row
  doesn't turn into visual noise. See "Navigation" under Architecture
  notes for the reasoning.
- `AmbientGlow` (new) — soft red/green/blue/cyan background streaks,
  dark mode only, sitting behind all app content at the `Main.qml` root.

**`root.isWide` is now orientation, not size** — `width > height` instead
of `width >= 600`. See "Orientation drives layout, not size" under
Architecture notes.

**`ProgrammerTab`'s landscape layout** — this is the tab the reference
mockups actually showed, so it's the one that got a real per-orientation
layout, not just new colors:
- **Landscape** (`root.wide === true`): Display Card, Bit Grid Card, and
  Ops Card sit side by side in one `GridLayout` row (30% / 42% / 28% of
  the available width). Input Card stays full-width below the row.
- **Portrait**: the same three cards, `GridLayout.columns` drops to `1`,
  so each takes its own full-width row instead — this is the original
  vertical stack, just formalized as "1-column" rather than a separate
  code path. One `columns: root.wide ? 3 : 1` binding drives both; nothing
  about the cards' internals differs between the two.
- **Bit Grid**: lit bits are now green throughout (`Theme.gradB`) instead
  of red for the MSB / blue for the rest — one consistent "on" color reads
  more like a real indicator light. The MSB keeps a thin red ring so which
  bit is the sign bit is still visible at a glance, just no longer via a
  totally different fill color. Cell size changed from "divide the tab's
  full width by 8" to a fixed scaled size — the old formula assumed the
  grid always spanned the full tab width, which stopped being true once it
  became one of three side-by-side cards in landscape.
- **Ops Card**: buttons arranged in a 2-column grid instead of a loose
  `Flow`, and each op (AND/OR/XOR/NOT/<</>>) gets its own hue from
  `Theme.tabColors` for visual variety — purely decorative, doesn't change
  which button does what.
- **Input Card**: the plain `TextField` + separately-dimmed A-F row is
  replaced with a real tappable keypad (0-9, A-F, ⌫, C) — both reference
  images showed a keypad here, not a text box. Reuses the exact same
  base-validity rule the old `TextField.onTextEdited` handler had
  (`digitEnabled`/`appendDigit`, next to the other pure-logic helpers near
  the top of the file) — what counts as valid input didn't change, only
  how you enter it. Each key dims when it's not valid for the current base
  (e.g. `8`/`9` and `A`-`F` dim in octal mode) rather than disappearing, so
  the grid shape stays constant across bases.

**Titles added to each card** (DISPLAY / BIT GRID / OPS CARD / INPUT CARD)
so the reference layout's labeled-card look carries through, and so it's
obvious at a glance which card is which once they're side by side instead
of implicitly ordered top-to-bottom.

**Not changed:** the underlying base-conversion/bitwise-op logic
(`doOp`, `clamp`, `bwAnd64`/`bwOr64`/`bwXor64`, `fmtHex`/`fmtOct`/`fmtBin`)
— all identical to before this pass. Only the surrounding layout, the bit
grid's colors, and the input mechanism changed.

**Other tabs** did not get a landscape-specific relayout in this pass —
only `ProgrammerTab` had a reference mockup to build against. They already
adapt to available width the same way they did before (more breathing
room in landscape, same content), just under the new nav. Worth a
follow-up if the same 3-card treatment (or something tab-appropriate) is
wanted elsewhere.

## Light mode gets its own neon (this update)

Follow-up on top of the layout/nav overhaul above. Feedback: light and
dark mode looked like two different apps — dark got the full neon
treatment, light got the same layout with none of the personality.

**Root cause**, not just a symptom fix: `Theme.glowOp` (and everything
derived from it — `glowA`/`glowA2`/`glowB`/`glowB2`) was `0` in light mode
by design, and it was doing double duty for two visually different
things:
1. **Blurred bloom** effects — an oversized, soft-edged rect simulating
   light bleeding outward (behind lit bits, behind the active nav pill,
   the outer rings on `CalcButton`'s eq/op faces). This one is *correctly*
   dark-only — the same trick against white doesn't read as "glowing," it
   reads as a smudge, so no light-mode equivalent was added for these.
2. **Crisp border rings** — a 1-2px colored outline around a card or
   button. This one was wrongly tied to the same dark-only knob. A
   saturated colored line reads as vivid on white the same way it does on
   black; there was no actual reason for these to disappear in light mode,
   they just did because they shared a token with (1).

**The fix**: split them. `glowOp`/`glowA`/`glowB`/etc. are unchanged and
still dark-only, still driving only the genuine blur-blooms. New
`Theme.edgeOp` (`0.42`, same value in both modes on purpose) and
`edgeA`/`edgeA2`/`edgeB`/`edgeB2` drive every card/button *border* ring
instead — swapped in across `ProgrammerTab` (all 4 cards), `FormulaTab`,
`CalcTab`, `GraphTab` (×2), `AITab`, and `RandomTab` (×4), and their
`visible: Theme.dark` gates removed since the whole point is that these
now hold up in both modes.

**Also part of the same fix, not just the border rings:**
- `AmbientGlow` (the background streaks) used to be dark-mode-only
  (`visible: Theme.dark`); now renders in both, with a *higher* peak
  opacity in light mode (0.16-0.22 vs. dark's 0.12-0.16) — a translucent
  color desaturates much more against near-white than against near-black,
  so equal opacity would've looked equally present in dark and nearly
  invisible in light. Tuned by eye, not derived from a shared constant.
- `TabPillBar`'s active-tab fill was the single biggest gap: solid in
  dark mode, a barely-there 16%-opacity tint in light mode, on a bar
  that's on-screen at all times. Now near-solid (90%) in light mode too.
  `labelColor` had to change alongside it — it used to just use the tab's
  raw hue as text color in light mode (fine against a faint tint, wrong
  against a near-solid fill) — now routes through `Theme.textOn()` in
  both modes.
- `surfaceEq`/`surfaceOp` (the red/blue-tinted card backgrounds) were
  deepened in light mode — the old values (`#FFF3F0`, `#F0EDFF` at the
  time) were tinted so faintly they were nearly indistinguishable from
  plain `Theme.surface`.

**New neon touch, not a light-mode fix**: `StyledInput` gets a colored
focus ring (`Theme.edgeB`) in both modes — previously focus was only a
subtle background shift. Doubles as a real usability improvement (clearer
focus state), not purely decorative.

**Deliberately left alone**: `ToastMessage` stays a flat, quiet pill
(its own header comment already says so) — it's transient and already
communicates state through solid color; `GroupTabs`' active-tab indicator
already had this right (a glow bloom that's correctly dark-only, plus an
always-solid crisp underline that never depended on `glowOp` in the first
place) — used as the model for how the rest of the fix should behave, not
something that itself needed changing. `ConvertTab`'s swap-button glow and
`CalcButton`'s eq/op outer rings are genuine blur-blooms too, same
reasoning as the bit-grid glow — left dark-only.

## Gradient pills + denser background strands (this update)

Closer match to the reference mood board's specific gradient/glow style,
on top of the color-parity pass above.

**Nav pills are real 2-stop gradients now, not flat fills.** Each tab's
pill (`TabPillBar`) goes from `Theme.tabColors[i]` to a new
`Theme.tabColorsEnd[i]` — an adjacent/lighter shade of the same hue,
matching the glassy gradient-pill look in the reference rather than a
flat color chip. Convert and Graph reuse `gradC`/`accent2` as their
end-stops rather than inventing two more one-off hex values, keeping the
"one consistent hue set" rule from the original color pass.

Gradients need a different contrast check than a flat fill: `Theme.textOn`
alone isn't safe if the gradient's *far* stop crosses the white/dark-text
threshold while the near one doesn't. New `Theme.textOnGradient(a, b)`
checks whichever stop is lighter (the harder case for white text) and
picks accordingly — some pills end up with dark labels even though their
base color alone would've suggested white (Convert, Random, Programmer,
AI all land here since their lighter stop crosses 0.6 luma), which is
correct, not a bug: a badge with a light-yellow gradient stop needing dark
text is normal, expected behavior, not a sign something's off.

**`AmbientGlow` v3 — many thin strands, not four wide bands.** The
reference shows something closer to a fiber-optic bundle per color (2-3
thin flowing strands close together) rather than one soft wide streak.
Reworked from 4 streaks (1 per color) to 12 (3 per color, offset in
position/width/opacity so they read as a bundle rather than identical
stacked copies) — same underlying technique (transparent → color →
transparent `Gradient`, no blur module), just restructured as bundles.

**Ops Card buttons got a proper glow bloom, not just a border.** The edge-
border fix from the light-mode-parity pass made them *visible* in both
modes, but next to the reference's clearly-glowing buttons a 1px border
alone still read as flat. Added a `z:-1`, oversized, dark-mode-only bloom
rectangle behind each button (same "blur bloom" technique as everywhere
else in the app) so they actually glow in dark mode, on top of the
border that already carries the light-mode version.

**Not changed:** `CalcButton`'s digit/func buttons are deliberately still
plain/neutral — every button glowing at once would cancel out the
hierarchy that makes the gradient "=" key and the colorful ops/nav stand
out as the things worth looking at. "Add neon where it's earned" rather
than "add neon everywhere" was the read on the ask here; happy to push
further into digit buttons specifically if that's not the right call.

## Funky animation pass (this update)

Everything below is motion only — no layout, color, or logic changed in
this pass. New `Theme.qml` tokens: `bounceDuration`/`bounceEasing`/
`bounceOvershoot` (quick tap feedback) and `popDuration`/`popEasing`/
`popOvershoot` (slower content entrances). Both use `Easing.OutBack`,
which overshoots slightly past its target before settling — that
overshoot is what reads as "funky" rather than a flat linear fade,
without tipping into something more exaggerated like `Easing.OutElastic`
(too wobbly for a calculator someone's trying to trust the numbers on).

**The asymmetric-bounce pattern, used everywhere below**: press-down is
quick and plain (`Easing.OutQuad`, `Theme.press` duration — feels
responsive, not laggy), release is what gets the springy overshoot
(`Theme.bounceDuration`/`bounceEasing`). Implemented as two named
`NumberAnimation`s restarted from `TapHandler.onPressedChanged`, not a
plain `Behavior`, since a `Behavior` applies one easing curve to a
property change regardless of direction — press and release need
different curves, so they need to be two separate animations, not one.

**Where it went:**
- `CalcButton` — every digit/op/eq/func/clear button in `CalcTab`.
- `TabPillBar` — pressing any pill bounces; releasing always bounces back
  up even if the tab you tapped was already active (an earlier draft of
  this only bounced back on "became active," which meant tapping an
  already-active pill pressed down and got stuck — fixed before it shipped).
- The 5 hero gradient buttons (Formula's Calculate, Random's quiz Start,
  Programmer's Execute, Graph's Add, AI's Send) — each got the bounce
  added individually rather than extracted into one shared component:
  they differ enough in sizing mode (some are `Layout.fillWidth`, Graph's
  Add is a fixed 60×44 sitting next to a text field), visibility
  conditions, and enabled-gating that a single generic component would've
  needed as many special cases as it saved lines. Also caught while in
  there: `ProgrammerTab`'s Execute button was missing the `edgeA` ring
  every other hero button has — added for consistency.
- `ProgrammerTab`'s bit-grid cells, Ops Card buttons, and keypad
  (digits + backspace + clear) — none of these had any press feedback at
  all before this pass, just an instant color change.
- `ToastMessage` — the entrance now overshoots slightly on the way up
  (exit stays a plain fade; a bounce on the way *out* read oddly, like the
  toast was reluctant to leave).
- `AmbientGlow` — each of the 12 background strands now drifts slowly and
  independently (7-11s per half-cycle, desynced by index so they don't
  move in lockstep) instead of sitting static. Kept deliberately small
  (single-digit pixels) and slow — this sits behind every screen at all
  times, so "barely perceptible" was the target, not "eye-catching."
- `RandomTab` — multiple dice results cascade in with a per-die stagger
  (45ms × index) instead of all popping in at once; the coin flip result
  gets a small spin + pop on landing.

**New, not just bounced**: every tab now plays a quick fade + gentle
pop-in the moment it becomes the active tab (`StackLayout.isCurrentItem`
flipping true), instead of just snapping into view when you switch to it.
Same pattern added to all 7 tab root `Item`s: a `readonly property bool
isCurrentTab: StackLayout.isCurrentItem` plus two triggered
`NumberAnimation`s (opacity 0→1, scale 0.97→1.0 with `popEasing`). Doesn't
fire on cold launch for the default tab (`isCurrentItem` starts `true`,
so there's no `false→true` transition to react to) — only on switches,
which is the case that actually needed it.

**Considered and skipped**: a full `HeroButton.qml`/`SecondaryButton.qml`
extraction for the repeated gradient-button pattern (see above — the
per-instance differences made this not worth it right now); a real
spring-physics `SpringAnimation` in place of `Easing.OutBack` (harder to
tune by feel without being able to render and check, and `OutBack` already
gets a convincing bounce out of a fixed, predictable duration).

## Performance + lazy tab loading + "better quiz" pass (this update)

Three asks in one pass: hunt down real performance problems, general QoL,
and make the quiz better. One section, since most of the QoL and quiz
work either fell out of the performance investigation directly or reuses
patterns it introduced (session state, persisted stats).

### Performance

**Lazy tab loading — the big one.** All 7 tabs were direct `StackLayout`
children, so every tab's full object graph was built synchronously at
launch regardless of which tab you actually opened first: `GraphTab`
painted a full canvas nobody was looking at, `AITab` stood up a
`FileDialog` and a `Qt.labs.settings` store, `RandomTab` built its whole
quiz problem pool (see below) — all before the first frame, for content
most sessions wouldn't touch right away, if ever.

Fix: every tab except `CalcTab` (the startup tab — no benefit lazy-loading
the thing shown immediately) now lives behind a `Loader` in `Main.qml`,
gated `active: root.currentTab === N || item !== null`. That's a "load
once, keep forever" latch — reading `item` inside its own `active`
binding is intentional, a standard, stable QML idiom for sticky
lazy-loading (false until first opened, permanently true after, since the
OR's left side already satisfies it going forward). "Keep forever"
matters as much as "lazy" — these tabs hold real, uniquely-generated
session state (quiz score, added graph functions, AI chat history, the
programmer tab's current value) that a Loader which unloads on tab-switch
would silently destroy.

One real wrinkle: `StackLayout.isCurrentItem` (see the pop-in-on-switch
note earlier in this doc) only ever gets set by `StackLayout` on its own
*direct* children. Once a tab lives behind a `Loader` it's a grandchild,
and the attached property would just never fire — silently killing the
entrance animation on every tab but Calc. Fixed by replacing it
everywhere: all 7 tabs now take a plain `property bool isCurrentTab:
false`, driven explicitly from `Main.qml` (`FormulaTab { isCurrentTab:
root.currentTab === 1 }` etc.) instead of the attached property. Same
animation, same trigger, works regardless of nesting depth.

**AmbientGlow's 12 background strands animated unconditionally, forever**
— including while the app was backgrounded/minimized. Invisible to the
user in that state, but still real CPU/battery burn. Gated `running` on
`Qt.application.state === Qt.ApplicationActive`; pauses mid-drift when
backgrounded, resumes from the same phase (no jump) when foregrounded.
Same bug, smaller scale, in AITab's 3 typing-indicator dots — hiding the
footer once a response lands doesn't stop the animations underneath, so
they were quietly ticking in the background for the rest of the app
session after the first AI request. Same fix.

**Graph plotting made W+1 QML→C++ calls per function per repaint.**
`GraphTab`'s plot loop called `mathEngine.evaluateAt()` once per
horizontal pixel — 400-1000+ round trips per function on a typical phone
width, on every repaint during pan/zoom (already throttled to one per
50ms, but each of *those* still paid the full per-pixel cost). Worse,
`evaluateAt()` re-ran `expression.simplified()` on the same unchanged
string every call — only `x` moves between samples, not the expression.
Added `MathEngine::evaluateRange(expr, xStart, xEnd, steps)`, a batched
sibling that simplifies once and walks the whole sample range in one
native loop — same `GParser`, same per-point math, same NaN-on-error
propagation as `evaluateAt()`, one call instead of hundreds.
`GraphTab.qml` calls it once per function per repaint now. `evaluateAt()`
itself is untouched, still used for `addFunction()`'s 7-probe validity
check, where call count doesn't matter.

**RandomTab's quiz problem pool was rebuilt from scratch every question.**
`getProblemPool()` constructed all ~29 problem definitions — each with a
`gen` closure — as a plain function called from `newMathProblem()`, so a
fast quiz session generated and immediately discarded the same ~29
objects over and over. Renamed `buildProblemPool()` and made it back a
`readonly property var problemPool`, same pattern as `FormulaTab.qml`'s
`formulaData` — the array literal is built exactly once now.

### Bugs found along the way

- **AI replies could be silently dropped.** `Main.qml` only forwarded
  `ApiClient`'s response to `AITab` while the AI tab was current — ask
  something, switch tabs before the reply lands, and it vanished: never
  appended to the chat, and `loading` never cleared, wedging the Send
  button (disabled while loading) for the rest of the session. Responses
  are now always delivered regardless of the active tab; `handleResponse()`
  raises a toast ("AI replied") when it fires while the user's looking at
  something else, so it isn't just sitting there unannounced.
- **Quiz answer field didn't clear between questions.** `mathAnswer` (the
  tracked JS value) reset in `newMathProblem()`, but the actual
  `StyledInput.text` was never bound back to it, so Skip/Next left
  whatever you'd typed sitting in the box. Gave the field an `id` and
  clear it explicitly. (A declarative `text: root.mathAnswer` doesn't
  actually fix this — a `TextField` permanently breaks a one-way binding
  on `text` the moment the user types a single character, so it would've
  silently stopped working after question one instead of just not
  working at all.)

### "Better quiz"

The quiz was an undifferentiated, endless stream of questions with a
running score that only ever cleared on a manual "reset" tap. Turned it
into a real session-based loop:

- **Length picker** (10 / 20 / Endless) next to the difficulty picker.
  Endless preserves the original behavior exactly; 10/20 give the round
  an actual start and end.
- **Session summary card** once a fixed-length round's last question is
  answered — score, accuracy, this session's best streak, average time
  per question (from timestamps, not a visible countdown — deliberately
  a stat, not added time pressure), and the all-time best streak with a
  "New all-time best!" callout if this round just beat it. "Play Again"
  jumps straight into a fresh round at the same settings; "change
  settings" returns to the picker.
- **Persisted lifetime stats** (best streak ever, lifetime right/wrong) —
  a local `Qt.labs.settings.Settings` store, same pattern `AITab.qml`
  already uses for `aiPrefs`. Survives app restarts, unlike the
  pre-existing score/streak, which lived only in memory.
- **Distinct haptics** for correct vs. wrong (`HapticHelper.click()` /
  `.heavy()` — the same two patterns `CalcButton` already uses for
  regular vs. destructive taps; no new C++).
- Score display is now scoped to the current session (zeroes on
  Start/Play Again) instead of free-running until manually reset — needed
  for the session-length math to mean anything, and a blended tally
  across a difficulty change wasn't that meaningful anyway. "reset" still
  works as a manual zero-without-restarting for Endless mode.
- Small addition: a "Qn/N" progress indicator folded into the existing
  category tag line during a fixed-length round.

**Considered and skipped**: multiple-choice mode (needs a hand-authored
set of plausible wrong answers per problem type — ~29 of them — for a
nice-to-have that free-text entry already covers reasonably well);
adaptive difficulty (real scope creep for this pass); per-category "weak
areas" tracking (the summary card already surfaces the signal that
matters most — accuracy and streak — without a second persisted-stats
shape to keep in sync).

### Found, not fixed

`FileHelper::readFileAsBase64()` runs synchronously on the GUI thread —
attaching a large image/PDF in `AITab` will briefly hitch the UI,
proportional to file size. Real, but lower-frequency than the fixes above
(attaching a file is an occasional action, not a per-frame or
per-question cost), and fixing it properly means restructuring
`FileHelper` onto a `QThread`/`QtConcurrent` worker — not something to
guess at blind in C++ that can't be compiled and tested here. Left alone
rather than risk it.

## Quiz variety + AI refresh (this update)

Two asks: make quiz questions feel less repetitive, and get the AI tab's
model list and key-based paths current again.

### Quiz: more unique questions

Two changes, both in `RandomTab.qml`:

- **12 new problem types**, 3 per difficulty tier (Doubling, Comparing,
  Money for Easy; Average, Ratios, Simple Interest for Hard; GCD, LCM,
  Speed for Nightmare; Combinations, Complex Magnitude, Matrix Trace for
  Impossible) — pool goes from 31 to 43 entries. Added a few small shared
  helpers (`gcdOf`, `factorial`, `nCr`) alongside the existing `rn`/`ri`/
  `fix` for the new generators to use. Every new generator computes its
  displayed answer directly from the numbers it actually shows (e.g. GCD's
  answer is `gcdOf(a, b)` on the real `a`/`b`, not backfilled from the
  values used to construct them) so correctness doesn't depend on the
  construction logic being airtight.
- **No-immediate-repeat filter.** `newMathProblem()` now tracks the last 2
  `tag|level` combinations used (`recentGens`) and excludes them from the
  pick when possible, so the same generator can't fire twice (or three
  times) in a row by chance — falls back to the unfiltered pool if
  excluding recents would leave nothing pickable. Resets on
  `startNewSession()`.

**Considered and skipped:** multiple-choice mode and per-category weak-
spot tracking — same reasoning as the "Better quiz" section above, still
holds.

### AI: refreshed model list + both key paths

The free-model landscape on OpenRouter had moved on since `orModels` was
last touched — Llama 3.3 70B / Gemma 3 27B / Mistral 7B were the lineup;
Mistral in particular currently has zero free models on OpenRouter at
all, so that entry was a guaranteed dead end. Verified the current lineup
directly against openrouter.ai (not a training-data guess) and replaced
the list:

- `openrouter/free` (Auto — Free) — new default (index 0). This is
  OpenRouter's own zero-cost-guaranteed router; it re-resolves to
  whatever's actually available per-request instead of pointing at one
  fixed slug, which matters because free lineups rotate — this is
  specifically the thing that made the old list go stale, and a fixed
  slug will do it again eventually no matter which one is picked today.
- `tencent/hy3:free` — OpenRouter's highest-traffic free model right now
  by a wide margin (reasoning, agentic, math-capable).
- `nvidia/nemotron-3-super-120b-a12b:free` — 120B/12B-active MoE, 1M
  context, strong multi-step reasoning.
- `nvidia/nemotron-3-nano-30b-a3b:free` — smaller/faster option for quick
  answers.

Also swapped `openrouter/auto` out entirely (it was the old "Auto-
select" entry) — confirmed against OpenRouter's own support docs that
the Auto Router's candidate set includes *paid* models and can silently
bill whichever key is active. `openrouter/free` is the router that's
actually guaranteed free; `auto` and `free` are not interchangeable
despite the similar name.

Separately, the direct-Anthropic-key fallback (used when no OpenRouter
key is set) was still pointing at `claude-sonnet-4-20250514` — several
generations behind. Updated to `claude-sonnet-5`, verified against
docs.claude.com. The vision path (`sendWithVision`) already used current
IDs (`claude-haiku-4-5-20251001` / `anthropic/claude-haiku-4-5`) and
didn't need touching — left it alone deliberately, including not
switching it to any of the new free text models above, since none of
them (checked) support image input; vision staying on a model that
actually does vision is the correct call, not staleness.

`ApiClient.cpp` got a few related fixes while in there for the key-based
paths generally:

- **Error messages were being thrown away on non-2xx responses.** The old
  code showed only Qt's generic `errorString()` (e.g. "server replied:
  Too Many Requests") and never looked at the response body on the error
  path — but providers put the actually useful detail (which limit,
  which key, how long to wait) in a JSON error body, not the HTTP reason
  phrase. Now tries that first, with a plain-language fallback for 401
  (bad key) and 429 (rate limited) specifically since those are the two
  a free-tier user is most likely to actually hit.
- Timeout bumped 15 s → 25 s — free models run on shared, sometimes
  oversubscribed capacity and 15 s was clipping legitimate-but-slow
  responses as failures, especially from the bigger models now in the
  default list.
- `max_tokens` bumped 1000 → 1500 — the response is a JSON object with a
  `steps` array; a full multi-step word-problem walkthrough plus JSON
  structural overhead could plausibly run past 1000 and get cut off
  mid-answer.
- Added the `X-Title` header to the OpenRouter branch (matches what
  `sendWithVision` already sends, and is OpenRouter's own convention for
  identifying the calling app in their dashboard).

**Considered and skipped:** true response streaming (would need
`QNetworkReply::readyRead` + incremental SSE/JSON parsing on the C++ side
— a bigger, riskier restructure than is safe to do blind on networking
code that can't be compiled and tested here); routing the vision path
through a free multimodal model like NVIDIA's Nemotron 3 Nano Omni
(free, and genuinely multimodal, but untested here for OCR/math-image
quality specifically — swapping a working paid-quality path for an
unverified free one on a guess isn't a good trade). "Downloadable"/
on-device AI: not practical for this app specifically — even the
smallest current Nemotron variants are 9B+ parameters, well beyond what
a phone can run well locally, and the whole point of the key-based paths
already in the app is to get frontier-ish quality without a local model
footprint. Free-tier cloud access via a key (which is what got refreshed
above) is the practical version of that ask for a mobile Qt app.

## Word Problems — a new quiz category (this update)

Ask: a math quiz where you have to actually read a short paragraph to know
which operation solves it — no "×"/"÷"/"GCD of" in the question text to
pattern-match against, only discoverable by reading 1-3 sentences of a
scenario.

### What's new, all in `RandomTab.qml`

- **13 new generators**, one pool entry each, all tagged
  `level:"Word Problems"`: Shopping Change, Splitting a Bill, Leftovers,
  Rate Over Time, More Than, Fraction of a Group, Age, Trip Remaining,
  Better Deal, Recipe Scaling, Ticket Revenue, Closing Distance, Discount.
  Together they cover addition, subtraction, multiplication, division,
  remainders, fractions/percentages, and multi-step combinations of these —
  comparable variety to a single existing difficulty tier (Easy has 13).
  Same rule the GCD/LCM generators already followed: every `a` is computed
  directly from the numbers actually shown in `q`, never backfilled from a
  separate construction target, so correctness doesn't depend on the setup
  math being airtight.
- **`"Word Problems"` is its own difficulty entry** (`📖`, appended after
  Impossible in `difficulties`/`diffIcons`), not folded into Easy/Hard/
  Nightmare/Impossible — "requires reading comprehension" is a different
  axis from "how hard is the arithmetic," not another rung on that ladder,
  and slotting it in the middle would've visually broken the
  green→orange→red→skull escalating-severity sequence. Selecting it filters
  the pool exactly like any other difficulty already does — `newMathProblem()`
  needed no logic changes — and it also surfaces normally under "Random"
  alongside everything else.
- **New reading-friendly display style, for this category only.** The
  question card's `Text` was centered, bold, and monospace — right for a
  short expression like "23 × 8", wrong for a 2-3 sentence paragraph (reads
  like a code block, and centered alignment makes multi-line prose harder
  to track line to line). `currentProb` now carries the entry's `level`
  through from `newMathProblem()`; the display `Text` checks
  `level === "Word Problems"` and switches to left-aligned, regular-weight
  `Theme.fontSans` at a slightly smaller size for just this category —
  every other tag/level renders exactly as before. The card's existing
  `Math.max(72, qText.implicitHeight + …)` height binding already handles
  the extra wrapped lines with no changes needed.
- **New `pickName()` helper** (+ a small fixed `wordProblemNames` list) so
  problems read like real scenarios ("Maya buys…") instead of "Person A" —
  the only new shared helper; everything else reuses `rn`/`ri`/`fix` as-is.
  Deliberately "they/them" throughout rather than gendering names, so no
  name→pronoun table is needed.

### Verified before landing, not just eyeballed

Wrote a standalone Node harness that imports the real `buildProblemPool()`
source unmodified and calls every generator — all 56, not just the 13 new
ones — thousands of times each, checking for thrown errors, non-numeric
answers, and empty question text: 0 failures across ~170k calls. Also
spot-checked several Word Problems samples by hand against their displayed
numbers (a Fraction-of-a-Group case, a Better-Deal case, a Closing-Distance
case) to confirm the arithmetic the app will mark "correct" actually is.
Couldn't render the actual QML UI in this environment (no Qt/display here),
so the logic and every generated string are verified, but the card's real
on-screen wrapping/height at various device font scales is worth a quick
look once it's built and run.

**Considered and skipped:** a separate 5th mode button (next to Dice/Coin/
Range/Quiz) instead of a new difficulty value — would've duplicated the
input/check/streak/session/hint machinery Quiz mode already has, for no
real benefit, since word problems still take one plain numeric answer like
everything else in Quiz. Clock-time-formatted answers ("what time does the
movie end?") — every other generator's answer is a plain number and
`checkAnswer()` parses it with `parseFloat`, so a string-shaped answer
would've needed its own comparison path; skipped to keep this pass's
surface area small rather than touch shared answer-checking logic for one
category.

## AI Skills — tool-calling for in-app actions (this update)

`AITab`'s systemPrompt used to promise a `graphExprs` array "for graph
requests" that nothing ever read — the model could say whatever it wanted
there and it silently went nowhere. Replaced with an actual, extensible
protocol: the model's JSON reply now carries an `"actions"` array of
`{"skill": "...", "params": {...}}` objects alongside its normal text
answer, and AITab validates + executes whatever it recognizes. The model
never touches app state directly; it only ever *proposes* an action.

**`plot_graph` is the first (and so far only) skill** — user asks to
see/plot/graph a function of `x`, the model names up to 4 expressions,
and AITab:
1. Runs each one through `mathEngine.evaluateAt()` at 7 probe x-values
   (same technique `GraphTab.addFunction()` already used) — anything that
   comes back non-finite at every probe is dropped silently rather than
   rendering a broken chart. Nothing from the model's output is ever
   `eval()`'d; it only ever reaches the same sandboxed C++ evaluator every
   other tab uses.
2. Renders the surviving expressions directly inside the reply's own chat
   bubble via a new `MiniGraphPlot.qml` — a read-only Canvas with grid
   lines, axis tick labels, auto-fit y-range, and a small legend. This
   *is* the answer, not a preview of one — see "Revised" below.

**Revised — dropped the "Open in Graph tab ↗" hand-off.** The first pass
of this feature paired a bare-curve preview (no grid/labels, "GraphTab has
the full instrument") with a link that pushed the same expressions into
the real `GraphTab` via a `Main.qml` bridge (`openGraphWithFunctions()` +
a `pendingGraphFunctions` handoff for the case where `GraphTab` hadn't
been opened yet this session, consumed by a `GraphTab.loadFunctions()` +
`Component.onCompleted` pair). Asked to make the chat view stand on its
own instead of pointing elsewhere, so all of that got removed again and
`MiniGraphPlot` gained the grid/tick-label rendering `GraphTab`'s Canvas
already had, rather than staying a stripped-down teaser. `GraphTab.qml`
and `Main.qml` are back to exactly what they were before this feature —
the entire skill now lives in `AITab.qml` + `MiniGraphPlot.qml` only,
which is also just a smaller surface area for a first skill to occupy.

**Why an `actions` array in the same JSON envelope, not the provider's
native tool-calling** (Anthropic tool_use / OpenAI-style function-calling,
which OpenRouter also exposes): the free-model lineup in `orModels` rotates
by design (see the "free models" section above) and several of those
models are not guaranteed to support structured tool calls reliably, while
every one of them already has to produce the existing `{"answer",
"steps",...}` JSON shape correctly for the app to work at all. One JSON
contract that degrades gracefully (a model that ignores `actions`
entirely just produces a normal text-only reply — `extractGraphExprs()`
returns `[]` and the bubble renders exactly as it did before this change)
beats a second, provider-specific request path that only some free models
would honor. Direct-Anthropic-key users are leaving real tool-calling
quality on the table this way, but the tradeoff is a single code path
that behaves the same regardless of which model answered.

**Extending this later:** a new skill is (1) one more bullet + example in
`AITab`'s systemPrompt describing its params, (2) a new `extractX()`-style
reader alongside `extractGraphExprs()`, (3) wherever its actual effect
belongs — most simply a chat-bubble UI element like `plot_graph` got, or a
call straight into `mathEngine`/`settings`. A skill that needs to reach
*another tab's* state would need a bridge similar to the one this pass
added and then removed — worth re-reading this section's "Revised" note
first if that comes up, since it's exactly the shape that turned out not
to be wanted here.

**Considered and skipped:** letting the model call a backend method
directly from the parsed response — would mean trusting model output as a
de-facto function call with no validation step in between; the current
design always routes through AITab's own `isPlottable()` gate first, and
the model only ever *describes* what it wants, never *does* it. A generic
`open_tab`/navigation skill (jump to Convert pre-filled, etc.) — a clear
extension of the same pattern, left out of this pass to keep it scoped to
the one concrete ask (graphing) rather than speculatively building skills
nothing has asked for yet.

## AI Skills, round 2 — four more skills + a "think" step

Followed the extension path the previous section laid out, for real this
time: four new skills alongside `plot_graph`, plus a registry file and a
"think" field the previous pass didn't have yet.

**New skills** — `evaluate_expression` (verify arithmetic/formula results
via `mathEngine.evaluate()` instead of trusting the model's own math),
`convert_units` (same non-trust pattern via `mathEngine.convertUnit()`),
`roll_random` (dice/coin/range, self-contained plain JS matching
`RandomTab`'s own formulas), `convert_base` (decimal/hex/octal/binary,
self-contained plain JS matching `ProgrammerTab`'s own `clamp()`). Full
detail — params, trust boundary, exact render shape — lives in the new
`ai-skills/skillviewer.md`, not duplicated here; see that file. Each got
its own `extractX()` reader (`extractEvalResult`, `extractConvertResult`,
`extractRollResult`, `extractBaseResult`) rather than a shared generic
dispatcher, same reasoning `skillviewer.md`'s "Keeping this in sync"
section gives: one skill's bad params can't affect another's this way.

**New shared component — `SkillResultCard.qml`.** `evaluate_expression`/
`convert_units`/`roll_random` all render as a one-line-context +
one-emphasized-value card; `convert_base` renders the same shell in a
small label/value table mode (DEC/HEX/OCT/BIN). One flexible component
covers all four rather than four near-duplicates of `MiniGraphPlot`'s
pattern — a curve genuinely needs a `Canvas`, these don't. Each skill's
card borrows its accent color from `Theme.tabColors[N]` for whichever tab
"owns" that domain (Calc/Convert/Random/Programmer) — same reasoning
`Theme.qml`'s own `tabColors` comment gives for reusing established hues
instead of inventing a second palette, just applied one level down from
nav pills to these cards.

**`"think"` — a field, not a UI mode.** Added `"think"` as the *first* key
in the JSON contract: one short clause naming which skill (if any) fits,
generated before `"answer"`/`"actions"` so it can inform them instead of
rationalizing a choice already made. Field order is doing real work here,
not just readability — this app's free-model lineup mostly emits JSON
keys in the order a prompt's own example shows them (same reason the
example blocks in `systemPrompt` were already written as complete objects
rather than fragments), so `"think"` had to move to the front of the
schema, not just get added at the end. Rendered as a small line above the
answer, colored with the AI tab's own identity hue
(`Theme.tabColors[6]`) — happens to double as a nice tell for "this line
is the model talking about itself," distinct from the answer, from the
steps, and from the graph/card results underneath it, without needing a
new visual language beyond a color this file already had a name for.

**`ai-skills/skillviewer.md` — what "skillviewer" can actually mean
here.** The registry file itself is straightforward — one section per
skill, same shape every time. The harder part was being honest about the
mechanism: the model talks to this app through one stateless HTTP
completion per turn (`ApiClient::sendToAI`), so there's no filesystem on
the other end of it for a model to "open a file" mid-reply the way a
person could. What the file actually does: it's the thing a developer
edits, and `AITab.qml`'s `systemPrompt` SKILLS section is a hand-kept
mirror of it, sent in full with every request — combined with the
`"think"` field asking the model to reason over that list before
answering. That's the real equivalent of "the AI looks at its skills
before it acts" that a stateless completion can produce; the file explains
this itself under "How a model actually 'sees' this file" rather than
leaving it implied. Also added a short human-facing version of the same
list — AI tab → ⚙ → a new SKILLS caption — so a person can see the same
capabilities the model's system prompt does, not just infer them from
what happens to work.

**Bug found while wiring `convert_units`, fixed at the source.**
`MathEngine::convertUnit`'s internal unit table was missing `knot`,
`"fl oz"`, `pt`, and `PB` — all four are selectable in `ConvertTab.qml`'s
own `unitCategories`, but converting to/from any of them silently
returned the input value unchanged (the function's not-found guard fails
open, not closed, so this looked like a real if boring conversion, not an
error). Existed before this pass and wasn't something `convert_units`
introduced, but the new skill would have inherited it silently, so fixed
in `MathEngine.cpp` directly rather than just working around it in
AITab's own unit allow-list. `ConvertTab` gets the fix for free.

**`MAX_TOKENS` — 1500 → 1700.** The "think" clause is a small, bounded,
*fixed* per-reply cost the previous 1500 ceiling (already sized around
`"steps"`-heavy word-problem replies, see the QOL FIX comment on this
constant in `ApiClient.cpp`) didn't have headroom for on top of an
already-long multi-step answer.

**Considered and skipped:** `lookup_formula`, a settings-mutating skill
(e.g. "switch to dark mode" via chat), and the `open_tab`/navigation skill
the previous section already declined — all three still out of scope, for
reasons specific enough to each that they're written up in
`skillviewer.md`'s own "Considered and skipped" section rather than here.
