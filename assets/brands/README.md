# Watch brand logos

Drop a logo here and the Apps & Devices list uses it automatically on the next
build. Until a file exists, that row shows a coloured monogram instead, so the
screen is never broken by a missing logo.

## File names

The name must match the brand's `slug` in `lib/models/wearable_brands.dart`.
SVG is preferred, then PNG, then WebP.

| File | Brand |
| --- | --- |
| `apple-watch.svg` | Apple Watch |
| `garmin.svg` | Garmin |
| `whoop.svg` | Whoop |
| `oura.svg` | Oura |
| `polar.svg` | Polar |
| `fitbit.svg` | Fitbit |
| `samsung.svg` | Samsung Galaxy Watch |
| `wear-os.svg` | Wear OS and Pixel Watch |
| `suunto.svg` | Suunto |
| `coros.svg` | Coros |
| `amazfit.svg` | Amazfit and Zepp |

A square-ish mark works best. The tile is light, so a dark or full-colour logo
reads well; a white-only logo will not.

## Where to get them

Take each file from the brand's own press kit or brand guidelines page, not from
a logo-scraping site. Those pages also carry the rules for using the mark.

- Garmin: Garmin newsroom, media resources
- Fitbit and Wear OS: Google brand permissions
- Whoop: Whoop press page
- Oura: Oura press kit
- Polar: Polar newsroom
- Suunto: Suunto media bank
- Coros: Coros press resources
- Amazfit: Zepp Health press centre
- Samsung: Samsung newsroom brand assets

## Before shipping these

These are trademarks. Showing them to say "this watch works with Fitrybe" is
normally fine as nominative use, but each brand sets its own rules and some ask
you to apply first.

**Apple is the strict one.** Apple's guidelines let you use the words
"Apple Watch" in plain text, but not the Apple logo or the watch mark without
written permission. Leaving `apple-watch.svg` absent keeps that row on its
neutral monogram, which is the safe default.

Do not recolour, outline, stretch or add effects to any mark. The app draws the
file as supplied.
