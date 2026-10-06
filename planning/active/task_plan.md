# Task: BW/colour frames out of the height band only through terrain are not settled by any roll-table rule (#93)

## Problem

Some BW and colour film frames leave `fly_height_ratio_band()` only because of the ground under them. Their catalogued `flying_height` is within the band of `scale x focal_length` above sea level, but subtracting the terrain takes the ratio above ground out of it. No roll-table rule reads them.

`data-raw/height_calibrate-lower_tail_rolls.R` cuts its strata on the ratio above sea level:

| stratum | ratio above sea level |
|---|---|
| `lower_tail` | ≤ 0.5 |
| `near_upper` | 2 to 3 |
| `upper_tail` | > 3 |

A frame in band above sea level is in none of them. With a DEM, the #54 check sends every such frame to nominal scale (`height_source = "implausible"`), whatever caused it.

fly#91 settled the infrared frames of this kind (`bc5312`, `bci12`) under a new `terrain` tail, because #89's IR census held all of them. The BW/colour ones were left out of scope there.


## Context

Some BW/colour film frames have a catalogued `flying_height` that is in band against `scale x focal`
above sea level, but leave `fly_height_ratio_band()` once terrain is subtracted. With a DEM, #54 sends all
of them to nominal (`height_source = "implausible"`). No roll-table stratum holds them, because
`data-raw/height_calibrate-lower_tail_rolls.R` cuts its strata on the ratio above sea level. fly#91
settled the IR ones (`bc5312`, `bci12`) under a `terrain` tail, using #72's near_upper rule unchanged. This
issue does the same for BW/colour.

**What exploration measured (plan mode, read-only, coarse 250 m MRDEM cached by fly#80).** None of this is
blind, and the findings will say so:

- **Population.** 1,389,968 usable BW/colour frames are in band above sea level. ~4,750 are out of band
  through terrain, on 293 roll-heights / 214 rolls. All of them are below the band; frames per roll-height
  have a median of 7 and a maximum of 197. This matches the issue's 3,500-11,900.
- **#72's condition 3 at the catalogued height.**
  - Passes on ~74 roll-heights: 56 rolls, ~1,520 frames.
  - Fails on the rest: 143 fit nominal only, 37 fit both, 39 fit neither.
  - 12 of the 214 rolls already have logbook rows.
- **Coarse elevation is a usable prefilter.** Against the sweep's exact elevations over 7,147 frames,
  the coarse mean is off by 8.5 m at the median, 110 m at the 99.9th percentile and 162 m at most.
- `fly_footprint()` needs no change. The table lookup keys on roll, height, lens and scale, and does not read
  `tail` (`R/fly_footprint.R` ~1207-1234).

**Decisions taken at this gate:**

- **Spacing-first logbook read.** Condition 3 is evaluated before the read, and only roll-heights that pass
  it are transcribed. The rest ship excluded with a reason naming spacing.
- **New census script and a shipped CSV**, mirroring fly#89/#91.
- The tail is `terrain`, as for the IR rows.

## Phase 1: Pre-register (committed before the exact census is read and before any page is transcribed)

- [x] `findings.md` records what was already known when the rule was written, so it cannot be called blind:
  the coarse counts and the coarse spacing split above.
- [x] **Population.** Usable BW/colour film frames, using the sweep's filter spelled out (not
  `fly_film_media()`).
  - `ratio_asl` is in band.
  - `r = (flying_height - elev) / nominal_agl` is out of band, with `r > 0`.
  - `elev` is the sweep's measure: the mean of MRDEM-30 under the nominal 9-inch square, axis-aligned.
  - A frame above the band through terrain needs ground below sea level. If one appears, the script stops.
- [x] **Prefilter.** A frame is read exactly if `coarse_elev > flying_height - band[1] * nominal_agl - M`.
  - `M` is 2x the largest |coarse - exact| over the sweep's frames, computed in the script and printed.
  - A producer line prints the smallest slack among census frames, as evidence the margin was not binding.
- [x] **Controls**, all required to pass:
  - every sweep frame in the stratum (12 in `random`) is in the census;
  - every sweep frame the exact read touches reproduces the shipped sweep `elev` to 0.1 m;
  - `base` matches the generator's f1 rule.
- [x] **Rule.** #72's near_upper rule, unchanged, with `named = 1` and no sibling witness:
  - logbook coverage of at least 0.5 of frames, and at least 0.9 of covered frames naming factor 1;
  - no focal-length conflict;
  - spacing fits the logbook height and rejects nominal;
  - no logbook scale equal to the catalogue's.
- [x] **Amendment A2 (evaluation order).**
  - Condition 3 is first evaluated at the catalogued height (`p_reported`), because factor 1 means the
    logbook height is within 2% of it.
  - A roll-height that fails is not transcribed. It ships in `_excluded.csv` with the reason that fired:
    "spacing at the catalogued height {fits nominal | fits both | fits neither}; logbook not read; nominal
    scale still applies". It never ships as "no logbook page covers these frames", because an absent read
    must not share an encoding with an absent page.
  - A roll-height that passes gets the full rule, with condition 3 re-checked at the logbook height.
  - A2 can only exclude, never accept.
  - It is applied to the whole `terrain` tail. The IR rows pass it, which the diff shows.
- [x] Record what each outcome means:
  - accepted rows are tabled `scale_wrong` at factor 1, `witness = logbook`;
  - excluded rows carry the reason that fired;
  - the 143 roll-heights that fit nominal only are reported as nominal-correct, which is the "fine as
    catalogued" case the issue raises. It is not acted on.

## Phase 2: Census script, `data-raw/height_measure-terrain_tail.R`

- [x] Read the centroid cache and apply the sweep's BW/colour filter.
- [x] Build the coarse DTM with the `gdal_translate -outsize ... -r average` recipe from
  `dem_measure-canopy_height.R`, cached under the gitignored `data-raw/.cache/terrain_tail/`. Take box means
  with a summed-area table.
- [x] Measure `M` on the sweep and apply the prefilter.
- [x] Read MRDEM-30 exactly on a PSOCK cluster, with the sweep's worker: chunks of 50,
  `terra::extract(fun = mean, na.rm = TRUE)`.
  - The cache is resumable and saved atomically.
  - The script refuses to report if any chunk failed.
  - The worker is copied, because the sweep's is an anonymous closure. The elevation-reproduction control
    proves the copy matches.
- [x] Compute `base` with the f1 adjacency rule. Classify, run the controls, and print producer lines:
  - counts per step;
  - roll-heights and rolls;
  - the coarse-vs-exact error;
  - the A2 spacing split.
- [x] Ship two files:
  - `inst/extdata/flying_height_terrain_frames.csv`: out-of-band frames, with the IR census's columns;
  - `inst/extdata/flying_height_terrain_population.csv`: the step counts.
  - `FLY_TERRAIN_SMOKE=1` writes nothing.
- [x] Run it. Keep the log in `planning/active/run_census.log`.

## Phase 3: Generator, `data-raw/height_calibrate-lower_tail_rolls.R`

- [x] Read the terrain census:
  - assert its `base` equals the generator's to 0.1 m;
  - derive `f_m`, `nominal_agl`, `r`, `p_nominal`, `p_reported` and the `p_x*` columns as Stage 3b does;
  - `rbind` it with the IR terrain frames into `terr`.
- [x] Add the A2 prescreen per roll-height on `p_reported`/`p_nominal`. `want` gains only rolls that pass.
- [x] Add a Stage 5 `reason` arm for prescreened roll-heights, ahead of the logbook arms, worded so the
  "nominal scale" suffix test still holds.
- [x] Extend the frame-count reconciliation and the disjoint-key `stopifnot` to the new frames.
- [x] Replace the "Reported, not a gate" random-sample line with the completeness reconciliation.
- [x] Update the header comment with a fly#93 paragraph.
- [x] Dry run to fetch pages into `data-raw/.cache/logbooks/`. Before transcription, the refusal path should
  send every passing row to `_excluded` as "no logbook page".

## Phase 4: Blind logbook transcription

- [x] Split the cached pages of the ~51 new rolls across about 4-5 general-purpose transcribers.
  - Each is told not to spawn, and not to open any repo file, issue, note or `inst/extdata/`.
  - Each gets the images and the `flying_height_logbooks.csv` schema only, with no catalogue height, scale
    or lens.
  - Each writes rows to a scratchpad file and reports only its path.
- [x] Each batch carries one already-transcribed page as a blind control. Its rows are compared with the
  existing ones, and disagreements are recorded.
- [x] Append the rows with `control = FALSE`. Check frame ranges against catalogue frame numbers. Record the
  reader's blindness and the control agreement in `findings.md`.

## Phase 5: Regenerate and diff

- [x] Run the generator and keep the log in `planning/active/run_rolls.log`. Regenerate
  `flying_height_rolls.csv` and `_excluded.csv`.
- [x] Diff both CSVs. Every existing row, the two IR terrain rows included, must be byte-identical. Only new
  BW/colour `terrain` rows may appear.

## Phase 6: Tests

- [x] `test-fly_footprint_height_rolls.R`:
  - the `terrain` recompute takes the IR census plus `flying_height_terrain_frames.csv`;
  - `excl$tail` may now include `terrain`;
  - every A2-excluded row recomputes as failing spacing at the catalogued height, from the census;
  - every accepted terrain row sits below `band[1]` as catalogued.
- [x] New `test-fly_footprint_terrain_tail.R`:
  - every census row is in band above sea level and out of band on `r`;
  - the population counts reconcile;
  - the 12 sweep frames are present, with matching `elev`.
- [x] `fly_footprint()` fixture test: a frame keyed to one new accepted BW/colour row, over `flat_dem()`, goes
  to `corrected_roll_table`. A control frame differing only in scale stays nominal. If no row is accepted,
  pin that instead.
- [x] Prove the guards fire, in a scratch copy:
  - drop A2's reason arm;
  - drop one census row;
  - mislabel the tail;
  - drop `terrain` from `nu_row`.
- [x] Review G5: `test-fly_footprint_height_rolls.R:320` pins 2 terrain rows; `:222` tails of `excl`;
  `:210-215` build terrain from IR only.
- [x] Review G6: replace the `nu_row` mutation with one that targets the scale veto, or record it as not
  observable.
- [x] Run `devtools::test()` (FAIL/PASS grep) and `lintr`.

## Phase 7: Docs and close-out

- [ ] Add a fly#93 subsection to `inst/notes/terrain-correction.md`, with tables rebuilt from producer lines.
- [ ] `R/fly_footprint.R` roxygen and comments where tails are listed. Run `devtools::document()`.
- [ ] `CLAUDE.md`:
  - Architecture line for the new script and CSVs;
  - the #89 Key Decision's "same BW/colour population is unmeasured (fly#93)" becomes the outcome;
  - the generator's line says it reads the terrain census.
- [ ] Review G7: `NEWS.md:14`, `inst/notes/terrain-correction.md:619`, `R/fly_footprint.R:267,285`.
- [ ] File a follow-up issue for the `r <= 0` frames (A3), and for the A2(a) above-ground hypothesis if it
  is worth one.
- [ ] Check that `R CMD build` tarball size stays reasonable with the new CSV, about 450 KB.
- [ ] `/code-check` (3 rounds + enumeration), `/planning-archive`, `/gh-pr-push`. A Plan-agent review of
  `task_plan.md` runs concurrently after the baseline commit.

## Validation

- [x] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

## Verification

- The census script's controls pass:
  - sweep frames reproduced to 0.1 m;
  - the 12 random stratum frames are found;
  - the margin slack is printed and not binding.
- The generator's existing controls still pass (spacing, logbook and sibling controls, reconciliation
  `stopifnot`s). The CSV diff contains only new terrain rows.
- `Rscript -e 'devtools::test()' 2>&1 | grep -E "(FAIL|ERROR|PASS)" | tail -5`
- The fixture test shows the width moving from nominal to the logbook height on the DEM route.

## Spend

About 5 transcribers, 3 code-check rounds and 1 plan review: roughly 9 agents, past the ~5 default, and
reported as it happens. The exact MRDEM read is about 1 hour on 6 PSOCK workers, depending on how many frames
the margin admits.
