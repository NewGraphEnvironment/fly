# Task: Frames under terrain where spacing rejects both nominal scale and the height read as above ground (#97)

## Problem

fly#95 tested whether the catalogued `flying_height` is a height above ground on the frames under terrain at or above the aircraft (`r <= 0`). On nine roll-heights, adjacent-frame spacing rejects **both** readings on offer: the catalogued height read as above ground, and nominal scale. These frames are drawn at nominal scale today, with a warning. Spacing does not support that fallback either.

| roll | height (m) | focal | scale | frames | of them `r <= 0` | overlap, above ground | overlap, nominal |
|---|---|---|---|---|---|---|---|
| `bc5715` | 732 | 153 | 1:4800 | 2 | 1 | 0.199 | 0.202 |
| `bc77026` | 2042 | 305 | 1:6000 | 118 | 11 | 0.479 | 0.419 |
| `bc77070` | 1158 | 153 | 1:5000 | 64 | 59 | 0.526 | 0.283 |
| `bc77072` | 1829 | 153 | 1:10000 | 17 | 1 | 0.355 | 0.228 |
| `bc77072` | 1981 | 153 | 1:10000 | 55 | 3 | 0.354 | 0.164 |
| `bc77087` | 1158 | 153 | 1:5000 | 57 | 38 | 0.478 | 0.209 |
| `bc7718` | 1524 | 305 | 1:5000 | 24 | 24 | 0.857 | 0.857 |
| `bc80117` | 1372 | 153 | 1:8000 | 19 | 19 | 0.860 | 0.843 |
| `bcc325` | 396 | 153 | 1:2000 | 2 | 1 | 0.285 | 0.075 |

The window is 0.557-0.780, from the generator. That is 157 `r <= 0` frames out of the 374. Source: `inst/extdata/flying_height_above_ground.csv`.

## Context from plan-mode exploration

fly#95 left nine roll-heights (157 `r <= 0` frames) where adjacent-frame spacing rejects nominal scale
*and* the catalogued height read as above ground. `fly_footprint()` draws them at nominal with a warning,
and nothing supports that either. The issue asks whether any instrument can say what these frames covered,
with the rule fixed before it runs (as #60/#72/#93/#95).

**What exploration found (not blind, so it goes in findings as already known):**
- **The spacing instrument's premise is weakest exactly here.** On 1970s rolls the catalogue centroids are
  interpolated evenly along each line, e.g. `bc77087` steps 931,931,931…, and `bc7718` 161/164. fly#82 found
  the spacing ×1.7 off what the images showed on `bc85054` 162. Seven of the nine keys also have step jumps
  of 2–372 km inside the key (line breaks; `bc7718` spans two lines 372 km apart).
- **The logbooks already read point at the centroids, not the scale.** Each page writes the catalogue's
  height under an M.S.L. header. Height minus nominal height above ground leaves a valley-floor ground
  height under the place the page names:

  | roll-height | page | implied ground | page's place | MRDEM median under the centroids |
  |---|---|---|---|---|
  | `bc77026` 2042 | 6,700 ft | 213 m | Pemberton Area | 1,729 m |
  | `bc77087` 1158 | 3,800 ft | ~393 m | Swan Lake–Grindrod | 1,264 m |
  | `bc77072` 1829/1981 | 6,000/6,500 ft | ~299/451 m | Spences Bridge/Savona | 1,575/1,260 m |

  `bc77026`'s page also remarks "Forward overlap seems excessive (75.9%)", where spacing says 0.42.
  `bc7718` 1524 m is 5,000 ft, which is exactly nominal height above ground, so its implied ground is 0 m.
- **Coverage.** All eight rolls have thumbnails (every frame) and `FLIGHT_LOG_URL` pages (35). Pages are
  transcribed for `bc77026`, `bc77072` and `bc77087`. None are transcribed for `bc77070`, `bc7718`,
  `bc80117`, `bcc325` or `bc5715`.
- **Reusable code.** `global_shift()`, `patch_shifts()`, `phase_corr()`, `pc_surface()`, `down()`,
  `hann2()`, `read_gray()`, `roll_meta()` and `fetch_pair()` are in `data-raw/dem_measure-photo_parallax.R`.
  They measure the image shift between adjacent thumbnails without centroid input. Pulled with `fns_from()`
  (`data-raw/dem_measure-canopy_height.R:93`), never copied. The window and the f1 air base are in
  `data-raw/height_calibrate-lower_tail_rolls.R:134` and `height_measure-terrain_tail.R:102`.

**Decisions taken at the gate:** the instruments are images plus logbooks, with no geolocation search. The
package does not change if the answer is "centroids misplaced"; a follow-up issue is filed for flagging
those frames.

**The logic the rule will encode:**
- Image overlap `p_img` replaces spacing's "designed ~60%" premise with the overlap the photos actually
  have. That tests leads 1, 2 and 4: an unusual flown overlap, a side off nominal, and pairs that are not
  adjacent.
- Lead 3, a misplaced centroid, is tested by the logbook against the catalogue. A page height under an
  M.S.L. header with MRDEM above it is a contradiction for *every* positive height above ground. So either
  the datum is wrong or the centroids are not over the photographed ground. Strip directions and place
  names against the catalogue's lines say which.

## Phase 1: Pre-register the rule (findings.md, committed before any image of the nine is measured)
- [x] Record what is already known (bullets above, incl. the implied-ground table and the logbook overlap
      remark) as not blind
- [x] Instrument W1, image overlap. For each key pair (n, n+1 both on the key):
      `p_img = 1 - |global shift| / thumbnail side`.
      - **Pair status:** `matched` (fly#82's own gate: ≥ 20 confirming patches), `no_match`, `no_thumbnail`.
      - **`line_break` pairs:** the centroid step is over 3× the key's median step. They are image-tested
        but kept out of the medians. If one matches, the frames are adjacent despite the jump.
- [x] Controls, with gates that stop the script before the nine are measured (as fly#82 stopped).
      - **Negative control:** a seeded draw of in-band 1970–1985 film roll-heights (f 153/305) whose
        spacing at nominal fits the window. The median `p_img - p_nominal` must sit within a stated bound.
        The control's own spread sets the tolerance τ.
      - **Positive control:** `bc85054` 162/163 must come out as disagreeing.
- [x] Per-key W1 verdict, evaluated in this order:
      1. `too_few_pairs`: under 3 matched pairs. This leaves `bc5715` and `bcc325` (2 `r <= 0` frames)
         unsettled by construction, and the findings say so.
      2. `not_adjacent`: under half the pairs match.
      3. `spacing_consistent_nominal`: `|p_img - p_nominal| <= τ`.
      4. `spacing_consistent_agl`: `|p_img - p_agl| <= τ` and not nominal.
      5. `spacing_disagrees`: neither, with `k = (1 - p_nominal)/(1 - p_img)` reported.
- [x] Witness W2, the logbook, per frame:
      - page height vs the catalogue, and the header datum
      - strip direction vs the catalogue line bearing (`fly_bearing()`), tolerance fixed here
      - place or Op name, verbatim
      - any recorded overlap remark vs `p_img`
      - implied ground `G_R = H_page - AGL_R` for each surviving size reading R. A reading whose `G_R` is
        below 0 m is physically excluded.
- [x] The combined outcome per key, from a fixed table of W1 × W2 outcomes: `nominal_centroids_misplaced`,
      `nominal_flown_off_window`, `agl_supported`, `not_adjacent` or `unsettled`. Coverage follows #72:
      the logbook reads at least half the frames, with at least 90% agreeing.
- [x] Evaluation order: all logbook pages are transcribed (Phase 3) before any image of the nine is
      measured (Phase 4)

## Phase 2: The image instrument and its controls — `data-raw/height_measure-image_overlap.R`
- [x] Stage 0: inputs. Read the two census CSVs, `flying_height_above_ground.csv`, the window and the
      centroid cache. Thumbnails are shared with fly#82's cache; this script has its own measurement cache,
      keyed on an algorithm tag.
- [x] Stage 1: the controls. Seeded draw, measure, gates. On a gate failure, stop and write nothing.
- [x] `FLY_IMGOVL_SMOKE=1` runs a handful of control pairs into a separate cache and writes nothing.
      `FLY_IMGOVL_STOP=n` stops after stage n.
- [x] PSOCK, not fork, for any parallel thumbnail work. Worker code avoids `mean()` on a SpatRaster.

## Phase 3: Logbooks, read blind before any image of the nine
- [x] Fetch the pages of the 5 untranscribed rolls into `data-raw/.cache/logbooks/`. Stop if any linked
      page is uncached (#93's guard).
- [x] Blind transcription by subagents, with the catalogue values withheld and a control page each:
      - heights go to `data-raw/flying_height_logbooks.csv` in its existing schema
      - per-strip direction, place/Op name and overlap remarks for all 8 rolls go to a new input
        `data-raw/flying_height_logbook_strips.csv`, never regenerated
- [x] Re-run `height_calibrate-lower_tail_rolls.R`. `flying_height_rolls.csv` and `_excluded.csv` must come
      out byte-identical. If a tabled row moves, stop and report before going further. Expected logbook
      column changes in `flying_height_above_ground.csv` are listed in findings.

## Phase 4: The measurement on the nine keys
- [x] Stages 2–3: measure every key pair, apply W1 and W2, and print a producer line for every figure the
      note will quote
- [x] Write `inst/extdata/flying_height_image_overlap_controls.csv`, `_pairs.csv` and `_keys.csv`, with one
      row per key and its outcome and the reason that fired
- [x] Re-run from cache; the outputs must be byte-identical

## Phase 5: Package consequence
- [x] Expected: no code change, recorded as such (as fly#65/#80/#95)
- [x] ~~If any key comes out `agl_supported`~~ (none did; no W2 `ground`), or otherwise supports a size other than nominal, stop and bring
      the package shape to the user before changing `fly_footprint()`
- [ ] If any key is `nominal_centroids_misplaced`, file the follow-up issue on flagging misplaced-centroid
      frames, with numbers from the shipped CSV

## Phase 6: Tests and documentation
- [x] `tests/testthat/test-fly_footprint_image_overlap.R` recomputes τ, every pair status, every key
      verdict and every note table from the shipped CSVs
- [x] Restore-the-bug check: perturb one input and confirm the test goes red
- [x] `inst/notes/terrain-correction.md`: a new fly#97 section, and the fly#95 section's "That is fly#97"
      pointer updated
- [x] NEWS; CLAUDE.md Architecture entry for the script and the Key Decision
- [ ] Enumerate every numeric or universal sentence in the note and NEWS against its producer line (#95's
      loop-ender)
- [ ] Edit issue #97's body to the outcome

## Validation
- [ ] Tests pass (`devtools::test()`, with `NOT_CRAN=true` on any single-file re-run)
- [ ] `/code-check` rounds until a round finds nothing inside the previous round's fix
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

