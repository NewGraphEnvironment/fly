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


## Phase 1 measurements (2026-09-28)

Producer: `data-raw/mask_measure-interior_zeros.R` over
`stac_airphoto_bc/data/raw/thumbs` (read-only), 8 PSOCK workers, 2.5 min. Per-frame CSV in
`data-raw/.cache/mask_interior_zeros.csv` (gitignored). Counted on the SOURCE after
`fly_mask_one()` at threshold 16: a pixel exactly 0 and still opaque in the masked copy is
one the old `-dstnodata 0` output wrote as nodata.

**Calibration set (the 264 of `mask_border_sweep.csv`; 182 grayscale, 82 RGB):**
- 172 of 182 grayscale frames carry some source pixel at exactly 0; the mask removes some
  of those zeros on 170 (they are collar), and leaves opaque zeros on **161 of 182**.
- Lost share of frame over those 161: median **3.0e-05** (median 47 pixels of 1.56 M),
  max **3.5%**; **12** frames above 0.1%. Total 242,439 pixels.
- The tail is one roll: bcb94081 frames 040-053 (1994) hold 1-3.5% true black each.
- **Mask declined on 0 of 264.**

**Whole directory today (10,105; 3,751 grayscale, 6,354 RGB):** 3,506 of 3,751 grayscale
frames lose some zero, median 3.1e-05, max 3.5%, 34 above 0.1%. **Declined on 0 of 10,105.**

Reading: the collision is near-universal in *incidence* and small in *extent* — a few dozen
pixels on most frames, percent-level on a dark roll. The fallback (#69) never fires on
thumbnails: every thumbnail is 8-bit and none trips the interior cap. Its reach is the
paths thumbnails cannot exercise — non-Byte full-resolution scans and unreadable sources —
which nothing public here can measure (the catalogue carries no full-res URL; see the
calibration script header).

Grayscale output with -dstalpha on a UInt16 source: alpha is 0/65535, not 0/255 (measured
on a synthetic INT2U frame). Consumers must read alpha as "0 = fill", not "255 = opaque".

## Errors Encountered

| Error | Resolution |
|-------|------------|
| PSOCK workers: `could not find function "measure_one"` on every frame, report printed zeros | `clusterExport()`; script now stops if any frame errored |
| fallback test: both legs identical | terra writes `NAflag = NA` on UInt16 as nodata 0, which GDAL honours regardless; fixture uses `NAflag = 65535` |
| fallback test: opaque count 0 | UInt16 alpha is 65535; `opaque(full =)` |
