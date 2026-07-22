# skillviewer.md — SmartCalc AI Skill Registry

This is the single source of truth for every "skill" the in-app AI
assistant (`AITab`) can invoke. If you're adding, changing, or removing a
skill, edit it here first — this file describes *intent*; `AITab.qml` is
where that intent is actually implemented and enforced.

See REBUILD_NOTES.md → "AI Skills — tool-calling for in-app actions" for
the original design rationale (why an `actions` array in the same JSON
envelope, not provider-native tool-calling) and its follow-up section for
this pass. This file is the registry; that one is the narrative history.

## How a model actually "sees" this file

It doesn't, directly — and being honest about that constraint is the whole
reason this file is written the way it is. `AITab` talks to the model
through one stateless HTTP completion per turn (`ApiClient::sendToAI`).
There is no filesystem on the other end of that request, so the model can't
open `skillviewer.md`, list a directory, or otherwise "look something up"
mid-reply the way a person (or an agent with real tool access) could.

What actually happens instead:

1. The **SKILLS section of `AITab.qml`'s `systemPrompt`** (built in
   `sendMessage()`) is a hand-kept, deliberately terse mirror of the table
   below — sent in full with *every* request, not fetched on demand. This
   is the real single source of truth as far as the running app cares;
   this file is the source of truth for *keeping that mirror correct*.
2. The JSON reply contract's **`"think"` field** asks the model to name,
   in one short clause, which skill (if any) fits the request — before
   `"answer"` and `"actions"`, not after. Field order matters here: this
   app's free-model lineup mostly emits JSON keys in the order a prompt's
   own example shows them, so `"think"` has to come first in the schema to
   actually inform the answer instead of rationalizing one already made.
   That's the closest a stateless completion can get to "the AI looks at
   its skill list before it acts" — it's not reading a file, it's being
   handed the file's contents up front and asked to reason about them
   before committing to a response.
3. `AITab` never trusts the model's own arithmetic for a skill it
   recognizes. Each skill has one job in the model's reply — *name* what's
   wanted (an expression, a unit pair, a bit width) — and one job in
   `AITab.qml` — actually compute it, via the same backend (`mathEngine`)
   every other tab already trusts, or plain sandboxed JS for things with
   no backend involvement (dice, coin flips). See each skill's "Trust
   boundary" line below.

A human can see the same list `AITab` shows the model in the app itself:
AI tab → ⚙ → SKILLS (short caption, same content as this file's
one-liners).

## Skills

### `plot_graph`
- **Trigger:** user wants to see/plot/graph a function of `x`.
- **Params:** `{"expressions": ["f(x) form, e.g. sin(x), x^2-4, 1/x"]}` — up
  to 4.
- **Trust boundary:** each expression is probed at 7 x-values via
  `mathEngine.evaluateAt()` (`AITab.isPlottable()`); anything non-finite at
  every probe is silently dropped rather than rendered broken. Nothing
  from the model is ever `eval()`'d — same sandboxed evaluator `GraphTab`
  uses.
- **Renders as:** `MiniGraphPlot.qml` inline in the reply's own bubble —
  real grid lines, tick labels, auto-fit y-range, small legend. This *is*
  the answer, not a teaser for the full Graph tab (an earlier draft paired
  a bare-curve preview with an "Open in Graph tab ↗" hand-off; removed —
  see REBUILD_NOTES.md's "Revised" note).
- **Extractor:** `extractGraphExprs()`.

### `evaluate_expression`
- **Trigger:** the request needs a verified numeric result — percentages,
  interest, geometry, unit-less arithmetic, anything where a free model's
  own mental math is the weak link.
- **Params:** `{"expression": "calculator-syntax string, e.g.
  1000*(1+0.07/12)^(12*20)"}`.
- **Trust boundary:** run through `mathEngine.evaluate(expr, true,
  settings.fracMode)` — the same evaluator `CalcTab` and the offline
  arithmetic shortcut (`tryOfflineCalc()`) already trust. A result of
  `"Error"` (bad syntax, unknown name) drops the card silently; the
  model's prose `"answer"` still shows either way.
- **Renders as:** a `SkillResultCard` — expression (dim, mono) over the
  verified result (bold, mono). Accent color: `Theme.tabColors[0]`
  (Calc's red — this skill's "home" tab).
- **Extractor:** `extractEvalResult()`.

### `convert_units`
- **Trigger:** convert a value between units.
- **Params:** `{"value": number, "from": "unit", "to": "unit", "category":
  "Length|Weight|Temperature|Speed|Volume|Time|Data"}`.
- **Units (must match exactly — same list as `ConvertTab.qml`):**
  | Category | Units |
  |---|---|
  | Length | `mm cm m km in ft yd mi` |
  | Weight | `g kg lb oz t` |
  | Temperature | `°C °F K` |
  | Speed | `m/s km/h mph knot` |
  | Volume | `ml l "fl oz" cup pt gal` |
  | Time | `s min hr day wk mo yr` |
  | Data | `B KB MB GB TB PB` |
- **Trust boundary:** units are checked against `AITab.convertCategories`
  *before* calling `mathEngine.convertUnit()` — the C++ function's own
  guard fails open (an unrecognized unit silently returns the input value
  unchanged, which looks like a real if boring conversion, not an error),
  so AITab's own allow-list check is the actual gate.
- **Renders as:** a `SkillResultCard` — "`75 mph → km/h`" over "`120.7
  km/h`". Accent color: `Theme.tabColors[2]` (Convert's blue).
- **Extractor:** `extractConvertResult()`.
- **Bug found & fixed alongside this skill:** `knot`, `"fl oz"`, `pt`, and
  `PB` were selectable in `ConvertTab` but missing from
  `MathEngine::convertUnit`'s internal table, so converting to/from any of
  the four silently no-op'd. Fixed in `MathEngine.cpp` — see its own
  `// BUG FIX` comment. Not something this skill introduced, but it would
  have inherited the bug if left alone, so it got fixed at the source
  instead of routed around.

### `roll_random`
- **Trigger:** dice, a coin flip, or a random number in a range.
- **Params:** one of
  `{"kind":"dice","sides":6,"count":1}` ·
  `{"kind":"coin"}` ·
  `{"kind":"range","min":1,"max":100}`.
- **Trust boundary:** self-contained plain JS (`Math.random()`), formulas
  copied exactly from `RandomTab.qml`'s own `rollDice()` / `flipCoin()` /
  `pickRandom()`. Deliberately does **not** touch `RandomTab`'s actual
  state (session score, streak, history) — see "Cross-tab state" below.
  `sides`/`count` are bounds-checked (2–1000 sides, 1–20 dice) against a
  hallucinated huge number; not a real dice-game rule.
- **Renders as:** a `SkillResultCard` — 🎲 `"2d6"` / `"4 + 6 = 10"`, 🪙
  `"Coin flip"` / `"Heads"`, or 🎯 `"1 – 100"` / `"37"`. Accent color:
  `Theme.tabColors[3]` (Random's amber).
- **Extractor:** `extractRollResult()`.

### `convert_base`
- **Trigger:** show a number in decimal/hex/octal/binary.
- **Params:** `{"value": "string as typed", "fromBase": 10, "bitWidth":
  32}` — `fromBase` ∈ `{2,8,10,16}` (default 10), `bitWidth` ∈
  `{8,16,32,64}` (default 32), both optional.
- **Trust boundary:** self-contained plain JS. `clamp()` mirrors
  `ProgrammerTab.qml`'s own `clamp()`/`fmtHex()`/`fmtBin()` exactly
  (unsigned wraparound into the given bit width, so a negative input reads
  the same two's-complement way it would on the Programmer tab). A
  per-base charset regex gates `parseInt()` first — `parseInt("12G9", 16)`
  would otherwise silently parse `"12"` and drop `"G9"` rather than
  failing outright.
- **Known limitation (inherited, not new):** at `bitWidth: 64`, JS numbers
  only carry 53 bits of exact integer precision, so very large 64-bit
  values can lose precision in their low bits — same ceiling
  `ProgrammerTab.clamp()` already has today; not a regression introduced
  by this skill.
- **Renders as:** a `SkillResultCard` in table mode — DEC/HEX/OCT/BIN rows.
  Accent color: `Theme.tabColors[5]` (Programmer's magenta).
- **Extractor:** `extractBaseResult()`.

## Keeping this in sync

Adding a skill is three steps, same shape every time (this is also
documented inline in `AITab.qml` right above `systemPrompt`):

1. Add a section here (trigger, params, trust boundary, render shape).
2. Add a matching bullet + example to `AITab.qml`'s `systemPrompt`.
3. Add an `extractX()` reader next to the existing ones, and wire its
   result into `handleResponse()` and the chat-bubble `ColumnLayout`.

There's intentionally no generic `executeAction(skill, params)` dispatcher
— each skill gets its own reader function. A malformed or hallucinated
`params` object for one skill can't affect another this way, and each
reader can apply validation specific to its own domain (unit allow-lists,
base charsets, plot probing) rather than sharing one generic, necessarily
looser validator.

## Considered and skipped (this pass)

- **`lookup_formula`** (surface `FormulaTab`'s formula library) — skipped.
  `FormulaTab.formulaData`'s `expr` strings are *display* strings (`"A =
  ½ × b × h"`), not machine-evaluable ones; the actual per-formula
  arithmetic lives in calculation logic local to `FormulaTab.qml`.
  Exposing it as a skill would mean either duplicating that logic (real
  drift risk between two copies) or bridging into `FormulaTab`'s state —
  exactly the shape `plot_graph`'s first draft tried and walked back (see
  REBUILD_NOTES.md's "Revised" note). `evaluate_expression` covers the
  common case anyway: the model can just write the arithmetic directly
  (e.g. compound interest as `1000*(1+0.07/12)^(12*20)`) and get a
  verified result without a dedicated formula-lookup skill at all.
- **`open_tab` / navigation** — still skipped, for the same reason
  REBUILD_NOTES.md already gave it a pass: it's a clear extension of the
  same pattern, left out to keep each pass scoped to concrete asks rather
  than speculative ones.
- **A settings-mutating skill** (e.g. "switch to dark mode" via chat) —
  skipped. Every skill so far *computes and displays*; a skill that
  mutates persistent app state (`settings.darkMode = …`) is a different
  risk shape — silent, global, and outside the chat bubble it was
  triggered from — and deserves its own pass (confirmation step? visible
  undo?) rather than being folded in here.
