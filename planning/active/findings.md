# Findings — Georef output contract (#56)

## Issue context

## Problem

`fly_georef()` gives a **grayscale** output `-dstnodata 0` rather than a real alpha band,
while RGB gets `-dstalpha`. That was preserved deliberately in v0.11.0 (fly#23) so the
frame-border mask could ship without changing any output's band count, but it is strictly
the weaker contract:

- `-dstnodata 0` cannot express **partial coverage** at the mask boundary. Alpha can.
- It collides with real content: a genuine 0-valued pixel inside the frame is
  indistinguishable from a masked one. This is the same class of defect the mask exists to
  fix — `srcnodata = "0"` was deleting real black — reintroduced on the output side.
- It reads back as `NA` rather than as a maskable band, so a consumer counting coverage has
  to special-case grayscale.

182 of the 264 measured thumbnails are grayscale, so this is the majority of the corpus.

## Why it was not done in #23

Switching grayscale to alpha changes the band count of **every** grayscale output from 1 to
2. `stac_airphoto_bc` consumes those GeoTIFFs and turns them into COGs, so the change has
to be co-ordinated with that repo rather than shipped underneath it. Bundling it into #23
would have blocked a fix for a live defect on a downstream repo's readiness.

## What to do

- Emit `-dstalpha` for grayscale as well, giving 2-band output.
- Decide and record whether `fly_georef()` gains an argument for this or simply changes,
  and say so in NEWS as a breaking change with the band count named up front.
- Re-run the `stac_airphoto_bc` COG pipeline against the new shape before releasing.
- The measurement to make first: how many grayscale frames actually carry interior pixels
  at exactly 0, i.e. how much real content the current `-dstnodata 0` is losing.
  `inst/extdata/mask_border_sweep.csv` does not answer this — it measures the mask, not the
  output — so it needs a new pass.

See `inst/notes/border-masking.md`, "Nothing downstream changes band count".


## Absorbs #68: the Windows band count

#68 is the same decision seen from another platform, and is closed into this issue. Kept here as acceptance:

- On **Windows**, masking a **grayscale** frame yields **2 bands** against 1 with masking off (ubuntu and macOS give 1; RGB is 4 everywhere), so "output band counts do not change" was only ever true on the platforms it was measured on. Found by the three-platform CI on its first run ([job log](https://github.com/NewGraphEnvironment/fly/actions/runs/35680424973)).
- Same root, same runner: GDAL reports *"Value 0 in the source dataset has been changed to 1 ... to avoid being treated as NoData"*, so genuine zeros are silently shifted in the warped output — the output-side collision this issue already describes, measured.
- `tests/testthat/test-fly_georef_mask.R` (~l.200-215) **pins** the observed Windows value rather than skipping it. Emitting a real alpha band for grayscale should make all three platforms agree on 2 bands; that test and the CLAUDE.md Key Decision for #23 are then rewritten to state the new invariant unconditionally.


## Absorbs #69: the exported API refuses the fallback the internals already support

#69 is closed into this issue because it changes the same branch of `fly_georef_warp_opts()`, and what it should become depends on what this issue decides for grayscale output.

`fly_georef()` refuses `mask = "border"` together with `srcnodata` (`R/fly_georef.R:186-190`), on the grounds that GDAL would apply both and `srcnodata` would delete the interior black the mask kept. `fly_georef_warp_opts()` (`R/fly_georef.R:525-537`) does not apply both — it chooses with an `else if`. Measured on fly 0.14.1, all four combinations:

| `masked` | `srcnodata` | warp options |
|---|---|---|
| TRUE | `"0"` | `-srcalpha` (srcnodata ignored) |
| TRUE | `NULL` | `-srcalpha` |
| FALSE | `"0"` | `-srcnodata 0` |
| FALSE | `NULL` | neither |

So the refused pair is exactly **"mask where the mask runs, nodata the collar where it declines"** — and `fly_mask_one()` declines on four documented paths (`R/fly_mask.R:215-305`). The fourth row is the worst outcome and is reachable: a frame whose mask declined, given no `srcnodata` because the exported docs say the mask supersedes it, has its black collar warped in **as real data**. A downstream repo currently reaches the fallback by calling `fly:::georef_one()` and re-asserting the table above on every run, which pins it to a `@noRd` helper.

Acceptance, in addition to the grayscale work above:

- The exported API expresses the fallback: either relax the refusal where the two are not both applied, or add a `mask` value (e.g. `"border-or-nodata"`) that says it in one argument, keeping the refusal for the genuinely contradictory case. Decide after the grayscale output shape is settled — with a real alpha band, the right answer may differ.
- Reconcile the docstring at `R/fly_georef.R:143-148`, which describes both options applied together, with the code, which chooses between them.
- Measure the **mask decline rate** first; it decides how much the fallback matters. A 6-frame downstream probe saw 1 of 6 consistent with a decline, which is not a rate.


## Errors Encountered

| Error | Resolution |
|-------|------------|
