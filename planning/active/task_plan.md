# Task: fly_footprint(dem =) returned a 110 km footprint for two 2003 film frames (#54)


Two film frames of 2003 came back from `fly_footprint(dem = ...)` at **110,834 m**
across, against **8,022 m** for the same frames with no DEM — a 13.8x blow-up, where
the correction as a whole is documented as moving area by a median 14%.

Measured during the fly#50 run over the province-wide digital population; the two
frames were film, so they were not the subject of that work and were not chased
further. Recorded here rather than lost.

The same run reported a second thing worth separating out: **18 of 416 DEM-corrected
frames fell under 95% `dem_coverage`, one as low as 47%**, and a partially covered
footprint takes the **mean elevation of the covered part**. That is documented
behaviour, not a defect, but it is a silent one — a frame half off the edge of the DEM
is sized from the half that happens to be on it, and nothing in the output says the
number is weaker than its neighbours'.

## Cause found in plan-mode exploration


Two 2003 film frames came back 110,834 m across with a DEM against 8,022 m without. The
issue listed four candidate causes and had not reproduced it. Plan-mode exploration
(read-only catalogue queries, nothing written) settled which one:

**`FLYING_HEIGHT` is wrong in the catalogue, not in fly.** 1,550 frames carry a
`flying_height` above 15,000 m and every one reads **10.05-16.0x** what its own
`scale x focal_length` implies. Nine+ rolls: `bc5596` (1974), `bc79027`, `bc79103` (1979),
`bcc00085` (2000), `bcc03004/6/7/8/46` (2003, 1,054 frames), `bcc05001` (2005). Tested on
150 sampled frames against MRDEM elevation at the centroid:

| hypothesis | residual vs (terrain + nominal AGL) |
|---|---|
| stored = true metres x 3.2808^2 (feet->metres applied the wrong way), so `/10.7639` | median +253 m, 10-90% -236..+1049 m |
| stored = feet, so `x0.3048` | +4.5 to +17.7 km — rejected |

The issue's pair matches the 1:35000 rolls `bcc03006-8`: `(75,100 - 1,100) / 0.153 x 0.2286`
= 110.6 km. Legitimate high flights (1:60000-1:90000, 12.0-14.6 km ASL) sit at ratio ~1.2
and must not be touched. `focal_length` is clean (153 / 305 only); the two-pass resize is
not diverging.

**Decisions taken at the gate (user):**
- **Repair, do not discard, and leave a trail.** Where the x10.764 slip is identified the
  frame is sized from the corrected height and *flagged*, so the set can be found and
  audited later. (Note: refusing never dropped a photo — it falls back to a nominal-scale
  footprint — but repair gives the better footprint and the flag gives the audit list.)
- **Both checks**: relative to `scale x focal_length` for film, plus an absolute ceiling on
  `height_agl` as the backstop for camera-table digital frames where `SCALE` is unusable.
  Only the relative check can see a low-altitude slip (a 1:5000 frame x10.764 lands at a
  legal ~13 km ASL).
- **Partial `dem_coverage` is out of this branch** — separate issue, to be worked from real
  examples.

**One design choice I am making, flag it at approval if you want it otherwise:** the record
is a single character column **`height_source`** — `"reported"`, `"corrected_unit_slip"`,
`"implausible"`, `NA` where no DEM sizing was attempted — rather than two logical flags
(`height_implausible`, `height_corrected`). It matches the package's existing idiom
(`width_source`, `footprint_basis`, `footprint_terrain`), cannot hold a contradictory pair,
and `filter(height_source != "reported")` is the audit list. The caller's `flying_height`
column is **never overwritten**, so raw vs corrected stays comparable; `height_agl` reports
the height actually used.

## Rule (constants measured in Phase 1, not the numbers below)

For a DEM-eligible frame, `agl = flying_height - elev` from the first pass:
1. Film with a parseable scale: `r = agl / (scale x focal_length)`. `r` inside the measured
   legit band -> `"reported"`, unchanged behaviour.
2. `r` outside it -> try `agl' = flying_height / 10.7639 - elev`. If `agl' / nominal` lands
   inside the legit band -> size from `agl'`, `"corrected_unit_slip"`, `footprint_terrain`
   stays `"dem_agl"`. The second pass samples the *corrected* rectangle.
3. Otherwise -> `"implausible"`: falls back to nominal scale exactly as the existing
   `unusable` class does (`footprint_terrain = "nominal_scale"`, `height_agl` NA), counted
   in a warning that names the likely unit slip.
4. Any DEM-eligible frame (incl. camera-table digital, which has no usable scale and so no
   way to verify a repair) with `agl` above the absolute ceiling -> `"implausible"`.
   Camera-table frames have no nominal fallback, so they come back empty as `unusable`
   ones already do, under the same warning.

`10.7639` (= 3.28084^2) is a fixed constant; the band and the ceiling are measured.
Branching is on recording format and scale parseability, known before any route runs —
never on `half_cross` arrival order (CLAUDE.md gotcha, fly#32).


## Phase 0: Housekeeping the gate produced
- [x] File a separate fly issue for partial `dem_coverage` (18 of 416 frames under 95%,
      one at 47%, sized from the mean of the covered part) — to be worked from real
      examples; link it from #54
- [x] Edit the #54 issue body: cause found (`FLYING_HEIGHT` x10.764 on ~1,550 frames,
      rolls listed), the three hypotheses it rules out, the repair-and-flag decision

## Phase 1: Measure the population and set the constants
- [ ] `data-raw/height_calibrate-flying_height_slip.R` (`pkgload::load_all()`
      unconditionally): per-year paged pull of `AIMG_PHOTO_CENTROIDS_SP`, attributes +
      centroid, cached outside git; assert row count against the catalogue's own total
- [ ] Candidate sweep without a DEM: `flying_height / (scale x focal_length)` over every
      film frame with a parseable scale; count candidates by roll and year; confirm whether
      any slipped roll hides *below* 15 km ASL (the low-altitude case)
- [ ] Look for the mirror defect (`r` far *below* 1 — height recorded as AGL, or the
      inverse slip) and for any digital frame with an impossible `flying_height`
- [ ] DEM-sample (MRDEM `/vsicurl/`) every candidate plus a stratified control set of
      legitimate frames chosen for the *least favourable* cases, computed not remembered:
      highest terrain x largest scale (r pushed up), 1:90000 at 14.6 km (ceiling pushed)
- [ ] Set the legit band on `r` and the absolute `height_agl` ceiling from that, with the
      margin to the least favourable member on **both** sides stated; verify `/10.7639`
      puts every candidate inside the band, and list any that it does not
- [ ] Ship the sweep as `inst/extdata/flying_height_sweep.csv` (the `mask_border_sweep.csv`
      pattern) so the suite recomputes the constants rather than trusting them
- [ ] Record numbers and dead ends in `findings.md`

## Phase 2: Failing tests first
- [ ] Fixtures in `tests/testthat/setup.R` beside `terrain_fixture()`: a slipped film frame
      (x10.7639), a **low-altitude slip whose bad value is a legal altitude**, an
      implausible-not-slip frame (e.g. x4), a camera-table digital frame over the ceiling,
      and a legitimate 1:90000 / 14,630 m frame that must stay `"reported"`
- [ ] `test-fly_footprint.R`: corrected frame's width within tolerance of the same frame
      with the true height; `height_source` values; `height_agl` is the corrected height;
      input `flying_height` column unchanged; implausible frame falls back to nominal with
      one warning (`capture_warnings()`, assert the rendered text, not just a field name)
- [ ] Batch independence: a slipped frame sizes identically alone and in a mixed batch
- [ ] Terrain axes the bundled DEM cannot reach (per `terrain-correction.md`): run the
      slip case at ~900 m cells, in a geographic CRS, and with a truncating extent
- [ ] `height_source` added to `fly_reported_cols()` so the plain / tibble / grouped /
      `bcdc_sf` sweep and `test-fly_terrain_passthrough.R` cover it; `NA` with `dem = NULL`
      and for `gsd_scaled` frames
- [ ] Constants test: band and ceiling recomputed from `flying_height_sweep.csv`, with a
      premise assertion that the CSV holds both slipped and legitimate rows
- [ ] Confirm the new tests fail on `main`'s code

## Phase 3: Implement in `R/fly_footprint.R`
- [ ] `fly_height_slip_factor()`, `fly_height_ratio_band()`, `fly_agl_max()` — named
      constant functions in the `fly_dem_coverage_min()` style, each commented with its
      measurement
- [ ] Classify after the first pass per the Rule above; resize from the corrected height
      so the second pass samples the rectangle actually returned; keep `covered` reading
      the pass that matches the shipped rectangle
- [ ] Fold `"implausible"` into the existing fallback path; one new warning, with counts
      for corrected and implausible separately, naming `height_source`
- [ ] Attach `height_source` via the `attrs$` pattern (not `st_sf(x, col = )` — fly#35)
- [ ] Restore-the-bug proof: revert the classification, watch Phase 2 go red (count
      `failed` **and** `error`), via `testthat::test_file()`

## Phase 4: Docs
- [ ] roxygen: `@return` gains `height_source`; terrain section explains the slip, the
      repair and how to list repaired frames; `devtools::document()` and check NAMESPACE
      did not move; `pkgdown::check_pkgdown()`
- [ ] `inst/notes/terrain-correction.md`: new section — the measurement, the rejected
      feet hypothesis, why the relative check is the discriminating one, the constants'
      margins
- [ ] Vignette: one short paragraph + `table(height_source)` beside the existing
      `table(footprint_terrain)`
- [ ] Draft (**do not send**) a short defect note for DataBC listing the rolls, for Al to
      send or not

## Phase 5: Release
- [ ] `lintr::lint_package()`, `devtools::test()`, `devtools::check()`
- [ ] NEWS.md entry and version bump to 0.12.0 as the final commit
- [ ] CLAUDE.md Key Decisions entry (catalogue height slip, repair-and-flag, do not
      re-derive the band without the sweep)

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
