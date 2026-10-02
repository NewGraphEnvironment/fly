# Task: Infrared film (Film - BW IR, Film - Colour IR) is sized as an unknown format (#89)


`fly_film_media()` (`R/fly_footprint.R`) lists `"Film - BW"` and `"Film - Colour"` only, so the catalogue's infrared film — **`Film - BW IR` (771 frames) and `Film - Colour IR` (3,054 frames)**, counted over the cached catalogue in `data-raw/.cache/centroids` — is treated as an unknown recording format: `footprint_basis = "unknown_format"`, an empty geometry, and no coverage, selection or georeferencing.

Found in fly#53's film rotation campaign, where every drawn roll of the `bci` and `bcf` series, and three `bcc` rolls from 1965-69, came back `legs_unscorable`: e.g. `bcc23`, `bcc7`, `bcc8` and `bcf07060` are all `Film - Colour IR` at focal 305, and 73/73, 87/87, 87/87 and 247/247 of their footprints are empty.

## Context from plan-mode exploration
**What exploration found that shapes the plan:**

- **Few IR thumbnails exist.** Of the 26 IR rolls the #53 campaign pulled, only `bcc23` (52%) and
  `bcf07060` (100%) carry thumbnail URLs. Every other pulled roll has none. So the thumbnail
  witness the issue proposes covers at most a few rolls. Spacing is the witness that reaches all
  32.
- **The `legs_unscorable` state hid the missing thumbnails.** Every leg came back `not_rotated`
  (empty footprint) before the thumbnail check ran. Once IR is sized, most drawn IR rolls will
  move to `thumbnails_unavailable`, which is the truthful state. At most 2–3 can ship a rotation.
- **There is a third witness the issue does not list: logbook pages.** 15 of the pulled IR rolls
  have `flight_log_url` pages. The #60 transcription shows these pages name the camera ("camera
  RC8 355"), and RC8/RC10-class cameras are 23 cm format. This witnesses the format directly.
- **Spacing can tell 9" apart from the formats IR might actually have used.** At ~60% designed
  overlap, sizing at 9" would put a 5" frame near 0.28 overlap and a 70 mm frame below zero, both
  outside the window. It cannot tell 9" from 9.5", but no such mapping format exists. The
  instrument and its window already exist in `data-raw/height_calibrate-lower_tail_rolls.R:40-117`
  (air base to the adjacent frame number, window = central 95% of in-band random frames from
  `inst/extdata/flying_height_sweep.csv`).
- **Other code that reads the film set:**
  - `fly_camera_format()` (`R/fly_camera_format.R:244`) treats IR as *digital* today. It is
    refused only because no focal fallback matches. The change removes IR from that branch,
    which is correct.
  - The height check's `film_like` (`R/fly_footprint.R:1168`) will start holding IR heights
    against scale × focal.
  - `fly_georef()` already routes on `grepl("^Film")`, so no change is needed there.
- **Decided at the gate:** the four `data-raw/` scripts that call `fly_film_media()` (slip #54,
  coverage #58, coastal #65, canopy #80) get **pinned** to the set they were measured over. This
  keeps their shipped tables reproducible.

## Phase 1: Pre-register the rule (committed before any IR measurement)

- [x] Write the rule into `findings.md`: population, three witnesses, pass/contradict criteria,
  controls, decision.
- [x] **W1 spacing** (every roll that has adjacent frames):
  - Compute per-frame implied forward overlap at 9" two ways:
    - from nominal scale (`p_nominal`);
    - from reported height less the MRDEM elevation (`p_reported`).
  - Use the window from the lower-tail script's definition, recomputed from the shipped sweep.
  - A roll **passes** if its median lies in the window under at least one reading whose `r` is in
    band.
  - A roll **contradicts** if both readings sit outside the window on the same side.
  - Also report the 5" and 70 mm medians, to show per roll that the test discriminates.
  - Control: the in-band random BW/colour frames reproduce about 0.6. If they don't, stop.
- [x] **W2 thumbnails** (rolls that have them):
  - aspect inside the film sweep's range (`mask_border_sweep.csv`, `nc/nr`);
  - `fly_mask` collar fraction at threshold 16 inside the BW/colour sweep range;
  - record mask declines.
- [x] **W3 logbooks:** a camera named on a page must be one with a 23 cm format. Pages that
  name no camera are recorded as such, not counted.
- [x] **Decision:**
  - Add both media values only if W1 passes on every roll it can measure and no W2 or W3
    observation contradicts.
  - On any contradiction: stop, record it, and escalate. No per-roll table in this issue.
- [x] Not a gate, but reported: the `r` distribution of IR frames, i.e. how many the #54 band
  check will refuse or repair once they count as film.

## Phase 2: Measurement script

- [ ] `data-raw/format_measure-infrared_film.R`:
  - Stage 0: IR frames from the centroid cache.
  - Stage 1: pull IR rolls via bcdata into a gitignored `data-raw/.cache/infrared_film/` (reads
    the #53 roll cache where present, never writes it).
  - Stage 2: MRDEM elevation under the nominal square. Use PSOCK, as in
    `height_calibrate-flying_height_slip.R:180-205`.
  - Stage 3: spacing and controls.
  - Stage 4: thumbnails via `fly_fetch(type = "thumbnail")`, then aspect and `fly_mask` collar.
  - Stage 5: verdict per the pre-registered rule; print a producer line for every figure.
  - `FLY_IRFILM_SMOKE=1` writes nothing.
- [ ] Ship `inst/extdata/infrared_film_spacing.csv` (per roll: frames, bases, medians per
  reading and per format, `r` summary, verdict) and `inst/extdata/infrared_film_thumbnails.csv`
  (per frame: dims, collar fraction, mask declined).
- [ ] `tests/testthat/test-fly_footprint_infrared.R` recomputes every roll verdict and the
  media-level decision from the shipped CSVs, using the same thresholds.

## Phase 3: Logbook transcription

- [ ] Read every IR roll's `flight_log_url` page by hand.
- [ ] Write `data-raw/infrared_film_logbooks.csv`. This is an input that is never regenerated,
  with the same columns as `flying_height_logbooks.csv` plus `camera_as_written`.
- [ ] The script reads it as W3, and the test holds W3's verdict to it.

## Phase 4: Size IR as film (only if Phase 1's decision passes)

- [ ] Write failing tests first in `test-fly_footprint.R`:
  - an IR frame is sized at `negative_size`;
  - `footprint_basis` equals its media value;
  - `fly_camera_format()` is not consulted;
  - the height check applies (`film_like`);
  - `format_size` can override an IR value.
- [ ] Prove the tests go red against the old `fly_film_media()`.
- [ ] Add `"Film - BW IR"` and `"Film - Colour IR"` to `fly_film_media()`. Update its comment,
  the `media` roxygen in `fly_footprint()` (~line 515), and the comment at
  `fly_camera_format.R:241`.
- [ ] Pin the four data-raw scripts to a literal `c("Film - BW", "Film - Colour")`, with a comment
  naming it as the set their shipped tables were measured over (#89).

## Phase 5: Calibrate the IR rolls' rotations

- [ ] `georef_calibrate-film_rotations.R`: stamp `retrieved` per roll from when that roll was
  measured, not from the date of the run. Otherwise a partial re-run restamps all 116 measured
  rolls.
- [ ] Remove the drawn IR rolls' `cal/*.rds` and re-run Stage 3 (smoke first). The draw depends
  only on thumbnail availability, so the drawn set stays the same.
- [ ] Regenerate the five `film_rotations*.csv`. Diff to confirm only IR rows moved.
  `test-fly_film_rotations.R` must pass.

## Phase 6: Documentation and release notes

- [ ] Add an "Infrared film" section to `inst/notes/camera-formats.md`: the witnesses, the
  numbers read off producer lines, and what spacing cannot separate.
- [ ] Add a `NEWS.md` entry.
- [ ] `CLAUDE.md`: a Key Decisions entry, and list the new script and CSVs in Architecture.
- [ ] Run `devtools::document()`, `lintr::lint_package()` and `pkgdown::check_pkgdown()`.

## Validation

- [ ] Tests pass (full `devtools::test()`, and `NOT_CRAN=true` on any single-file re-run).
- [ ] `/code-check` clean on each commit.
- [ ] PWF checkboxes match landed work.
- [ ] `/planning-archive` on completion, then `/gh-pr-push`.

