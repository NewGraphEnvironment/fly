# fly #30 — footprints for digital frames

## Context

`fly_footprint()` computes ground coverage as `negative_size * scale * 0.0254`
with `negative_size = 9` inches. A digital frame has no negative. In the sample
measured on the issue, 20% of catalogue frames (136/680) are `Digital - Colour`,
and for those the function returns a rectangle derived from a negative that does
not exist.

This matters more than the size of the error. The footprint is the reason to use
this package over a point-in-polygon test: `fly_filter(method = "footprint")`,
`fly_overlap()` and `fly_coverage()` are all computed from it, and a wrong
footprint still draws, still overlaps, still yields a coverage percentage.
It fails silently and plausibly.

`fly_footprint()` is called internally by **five** exported functions
(`fly_filter.R:39`, `fly_select.R:54` and `:111`, `fly_georef.R:114`,
`fly_overlap.R:26`, `fly_coverage.R:29`), so whatever it returns for a digital
frame propagates through the whole package.

### One correction to the approach discussed

Deriving width from `ground_sample_distance` is not reachable from catalogue
metadata alone: `ground_width = GSD x pixels_across`, and pixel count is absent
just as sensor width is. GSD's real value is **identification** —
`pixel_pitch = GSD / scale_denominator` (0.10 m at 1:15000 => 6.67 um) narrows
the camera family and can be checked against `camera_calibration_url`.

So this issue ships the **mechanism plus an honest flag**; establishing the
actual widths is research and becomes its own issue (agreed in session).

## Approach

Add a per-media format lookup and a provenance column. Never fabricate a
rectangle for a frame whose format is unknown; never silently drop one either.

```r
fly_footprint(
  centroids_sf,
  negative_size = 9,      # retained: back-compat, and the no-media fallback
  format_size   = NULL    # named inches, keyed by `media`; NULL = shipped defaults
)
```

Resolution order per row, recorded in a new `footprint_basis` column:

| Condition | Width used | `footprint_basis` | Signal |
|---|---|---|---|
| `media` matches the format table | table value | `"film_9in"` (or the key) | — |
| no `media` column at all | `negative_size` | `"assumed_default"` | one-time message |
| `media` present, not in table (digital) | none — empty geometry | `"unknown_format"` | `warning()` with count |

Shipped defaults cover film only (`Film - BW`, `Film - Colour` = 9). Digital keys
are deliberately absent until the research issue lands, so a digital frame gets
`unknown_format` rather than an invented number. A user who knows their camera
passes `format_size = c("Digital - Colour" = 3.54)` today.

`warning()` not `cli::cli_alert_warning()` — callers need to catch it, and
`expect_warning()` must fire (`r-packages.md`, "Common pitfalls").

## Phases

### Phase 1: Tests first
- [x] Add a synthesized digital fixture in `tests/testthat/` — bundled
      `inst/testdata/photo_centroids.gpkg` is 100% `Film - BW` / focal 153, and
      `data-raw/make_testdata.R` sources a 1968 film-only AOI, so digital cannot
      come from there
- [x] Test: digital rows return empty geometry, not a 9-inch rectangle
- [x] Test: `footprint_basis` values are correct for film / digital / no-media
- [x] Test: `warning()` fires with the digital count, and is catchable
      (pair with `expect_gt(length(w), 0)` — `expect_match(all = FALSE)` passes
      vacuously on `character(0)`)
- [x] Test: `format_size` override produces a real footprint for digital
- [x] Test: back-compat — film-only input is unchanged, `negative_size` still works
- [x] Confirm they fail against current `fly_footprint()`

### Phase 2: fly_footprint()
- [ ] Format lookup keyed on `media`, defaults film-only
- [ ] `footprint_basis` column on the returned sf
- [ ] Empty geometry for unknown format; `warning()` naming the count
- [ ] No-`media` fallback to `negative_size` so existing callers keep working
- [ ] Verify the phase-1 tests now pass

### Phase 3: Downstream — the five consumers
- [ ] `fly_filter.R:39` — drop empty footprints before `st_intersects`; warn with
      count (`st_intersects` on an empty geometry returns FALSE, so without this
      digital frames vanish from a filter result with no signal)
- [ ] `fly_select.R:54`, `:111` — same, and confirm coverage denominators are not
      computed as if the dropped frames were absent from the input
- [ ] `fly_overlap.R:26`, `fly_coverage.R:29` — same
- [ ] `fly_georef.R:114` — skip unwarpable frames, report them in the return value
      rather than erroring the whole batch
- [ ] Test at least `fly_filter` and `fly_coverage` on mixed film/digital input

### Phase 4: Docs
- [ ] Fix the stale focal-length claim at `fly_footprint.R:20`. `FOCAL_LENGTH`,
      `FLYING_HEIGHT` and `SCALE` are 100% populated and already present in the
      bundled test data (`focal_length`, `flying_height`,
      `ground_sample_distance` columns) — the docstring says they are not
      available
- [ ] Document `format_size` and `footprint_basis` with a runnable `@examples`
      block on mixed input
- [ ] Note the field is `SCALE`, not `PHOTO_SCALE` (the latter returns all NULL,
      which reads as missing data rather than a wrong field name)
- [ ] Vignette: a line on filtering by `footprint_basis`
- [ ] `devtools::document()`

### Phase 5: Hand off the research
- [ ] File the follow-up issue: identify the cameras behind the 2011/2018 digital
      rolls and establish sensor widths. Record the `pixel_pitch = GSD / scale`
      lever and `camera_calibration_url` as the two routes, and that #30 ships
      the `format_size` slot the results drop into
- [ ] Cross-reference #9 (DEM-adjusted footprints) and #10 (flight metadata) —
      both need focal length and flying height, which Phase 4 establishes are
      already available

## Validation

- [ ] `Rscript -e 'devtools::test()' 2>&1 | grep -E "(FAIL|ERROR|PASS)" | tail -5`
- [ ] `Rscript -e 'lintr::lint_package()'` clean
- [ ] `Rscript -e 'devtools::document()' 2>&1 | grep -E "(Writing|warning)"`
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

## Notes

- `planning/` does not exist in this repo yet; the no-args scaffold runs first.
- Branch: `30-fly-footprint-assumes-a-9-inch-negative-b`
- Not in scope, by agreement: researched sensor widths (Phase 5 hands off), and
  DEM/terrain adjustment (#9).
