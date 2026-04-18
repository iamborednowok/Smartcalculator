# SmartCalc — Custom Tab Icons

Drop an image file here to replace any tab's emoji with a real icon.

## Naming convention

The file name **must match the tab label in lowercase**, no spaces:

| Tab     | Expected filename (pick one extension) |
|---------|----------------------------------------|
| CALC    | `calc.png` / `calc.svg` / `calc.jpg`  |
| FORMULA | `formula.png` / `formula.svg` / …     |
| CONVERT | `convert.png` / `convert.svg` / …     |
| RANDOM  | `random.png` / `random.svg` / …       |
| GRAPH   | `graph.png` / `graph.svg` / …         |
| PROG    | `prog.png` / `prog.svg` / …           |
| AI      | `ai.png` / `ai.svg` / …              |

The loader tries **PNG → SVG → JPG** in that order, then falls back to the
built-in emoji / text glyph automatically — so you can replace tabs one at a
time and the rest stay as-is.

## Image requirements

| Property  | Recommendation |
|-----------|----------------|
| Max size  | **48 × 48 px** (displayed at ~18 × 18 dp; larger images are downscaled but waste resources) |
| Format    | PNG (transparency) or SVG (crisp at any density) preferred over JPG |
| Alpha     | Use a transparent background — the tab bar tints the foreground colour via QML's `color` property override in `TabIcon.qml` if you want tinting |
| Colour    | Monochrome / single-colour icons look best; the active/inactive colour is applied by the theme automatically when the image is not found (text fallback path) |

> **48 px is the hard cap for the icon to render sharply inside the 50 px
> tall tab pill.** Anything larger will be downscaled with `mipmap: true`
> smoothing, but won't gain you any extra fidelity on a 1× display.

## Wiring a new icon into the build

After dropping the file here, open `CMakeLists.txt` and add the path to the
`RESOURCES` list inside `qt_add_qml_module`:

```cmake
RESOURCES
    qml/icons/README.md
    qml/icons/calc.png      # ← add your file here
```

Then rebuild. Qt's resource compiler will embed the image in the binary so
the file doesn't need to be shipped alongside the executable.

## Fallback chain summary

```
qml/icons/<label>.png  ─┐
qml/icons/<label>.svg  ─┤ first match wins
qml/icons/<label>.jpg  ─┘
         ↓ (none found)
   emoji / "01" text glyph (always works, no rebuild needed)
```
