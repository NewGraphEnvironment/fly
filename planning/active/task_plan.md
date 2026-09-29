# Task: Georef output contract: a real alpha band for grayscale, and a supported mask-or-nodata fallback (#56)


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

Absorbs #68 (Windows band count) and #69 (mask-or-nodata fallback).

**Decisions taken at the gate (user):**
- Grayscale **just changes** to 2 bands (gray + alpha). No opt-out argument; breaking
  change in NEWS with "1 → 2 bands" first. `fly_georef()` formals unchanged.
- **Relax the refusal**: `mask = "border"` + `srcnodata` is allowed; `srcnodata` applies
  only to frames whose mask declined. No new `mask` value.

## Phase 1: Measure first
- [x] `data-raw/mask_measure-interior_zeros.R`: over the 264 thumbnails
  (`stac_airphoto_bc/data/raw/thumbs`, read-only), for each grayscale frame count pixels
  exactly 0 that the threshold-16 floodfill mask does **not** remove — the real content
  `-dstnodata 0` loses today. Report frames affected / 182 and pixel fractions (median,
  max). Producer line for each figure.
- [x] Mask decline rate: count frames where `fly_mask_one()` declines at the shipped
  constants (cap from `inst/extdata/mask_border_sweep.csv` offline, plus a live run of
  `fly_mask_one()` over the 264 for the other paths). State what thumbnails cannot speak
  to (non-Byte full-res scans are the decline path most likely to matter).
- [x] Record both in `findings.md`.

## Phase 2: Tests first (red)
- [x] Rewrite warp-opts table tests: `-dstalpha` for every band count, `-dstnodata`
  never emitted; `-srcalpha` when masked, `-srcnodata` only when unmasked (else-if kept,
  asserted for all four masked × srcnodata rows).
- [x] End-to-end: grayscale → 2 bands **unconditionally** (Windows pin removed), RGB → 4;
  masked and unmasked agree; grayscale collar removal now countable via the alpha band
  (same `opaque()` check RGB already has).
- [x] New: an interior block of exact 0 in a grayscale frame survives as opaque data
  (the output-side collision this issue exists to fix). Restore `-dstnodata 0` and
  confirm it goes red.
- [x] `fly_georef()` accepts `mask = "border"` + `srcnodata`; a frame whose mask declines
  (synthetic non-Byte or cap-tripping source) gets `-srcnodata`, a masked frame does not.
  Remove the test asserting the refusal.

## Phase 3: Implement
- [x] `fly_georef_warp_opts()`: `-dstalpha` for all inputs; drop the `-dstnodata 0` arm.
- [x] Remove the `mask = "border"` + `srcnodata` refusal in `fly_georef()`.
- [x] Rewrite roxygen: `@param srcnodata` (fallback where the mask declines), **Nodata
  handling** item 1 and the "mutually exclusive" paragraph, `fly_georef_warp_opts()`'s
  three rules. `devtools::document()`.
- [x] Tests green; `lintr::lint_package()` clean.

## Phase 4: Downstream check (read-only on other repos)
- [x] Georef a few bundled grayscale frames with the new build; run `stac_airphoto_bc`'s
  `scripts/03_cog.py` `write_cog()` + `check_same_raster()` on them from scratch space
  (its conda env), without writing into that repo. Record result.
- [x] File a `stac_airphoto_bc` issue: grey outputs become gray+alpha 2-band; its
  `tests/test_cog.py` "grey frame with nodata 0" fixture describes the old shape.
- [x] File an issue in the private sibling that pins `fly_georef_warp_opts()`'s table and
  calls `fly:::georef_one()`: its guard will now (correctly) fail, and the exported
  `fly_georef(mask = "border", srcnodata = ...)` replaces the `:::` reach. Reference kept
  one-directional (backtick `fly#56` there; nothing named from fly).

## Phase 5: Docs and record
- [x] `inst/notes/border-masking.md`: rewrite "Nothing downstream changes band count" to
  the new unconditional invariant (grayscale 2, RGB 4, all platforms); add the Phase 1
  measurements with producers; the fallback semantics.
- [x] CLAUDE.md Key Decision for #23: replace the platform-conditional band-count
  paragraph (fly#68) with the new invariant and the #69 decision.
- [x] NEWS.md entry (breaking, band count named first). Version bump left to `/gh-pr-merge`.

## Validation
- [ ] Tests pass (`devtools::test()`), including the restore-the-bug checks above
- [ ] Three-platform CI green on the PR (the Windows 2-band pin is gone, so this is the
      real test of #68)
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion, then `/gh-pr-push`
