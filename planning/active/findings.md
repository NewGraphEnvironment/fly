# Findings — Surface frames whose catalogue centroids are known to be misplaced (#99)

## Issue context

## Problem

fly#97's rule marks five roll-heights `misplaced`. On four of them, by their logbooks, the frames under the terrain that a logbook row reaches are not over the ground the catalogue's centroids put them on; the fifth, `bc77072` 1829, has its one such frame on no page. `fly_footprint()` places those footprints at the centroids anyway. When given `dem =`, it falls back to nominal scale on the frames whose DEM ground is at or above the catalogued aircraft height (`r <= 0`), and warns.

The five are `bc77026` 2042 m, `bc77070` 1158 m, `bc77072` 1829 m and 1981 m, and `bc77087` 1158 m, from `inst/extdata/flying_height_image_overlap_keys.csv` (`location == "misplaced"`). The evidence, its counts and its limits are in `inst/notes/terrain-correction.md`, "What the frames under the terrain covered". In short:
- **The logbook.** The page writes the catalogue's height under an M.S.L. header, yet MRDEM under the catalogue's centroids is at or above it.
- **The photos.** They show the catalogue's centroid step is longer than the air base. So the spacing along each line is not the photos' either. They do not test the page's datum.
- **The caveats.**
  - `bc77070`'s step margin is at the instrument's resolution.
  - `bc77087` rests on its page's 3,800 ft. Three blind reads of that digit disagreed (3; 3 or 7; 3 or 5), and a human read settled it as 3 (fly#101). The read was not blind.
  - Four of `bc77026`'s frames under the terrain, and `bc77072` 1829's one, have no shipped logbook row.

Two more roll-heights, `bc7718` and `bc80117`, were left `unsettled` by fly#97's rule. Their pages name places far from the catalogue's frames, "TAHSIS" and "YALE BLUFF" (see the note).

## What to decide

Should fly surface a known misplaced centroid to the caller? Options:
- a shipped ledger read by `fly_footprint()`'s `r <= 0` warning, so the warning names the roll's state, as `fly_georef()` already does for film rolls;
- a column on the output;
- nothing, with the note as the record.

The ledger would cover only rolls measured so far. The defect may be wider: consecutive catalogue steps on older rolls are often equal to within 0.5% (fly#82's probe). Whatever ships should say so rather than read as a census.

Related: fly#97, fly#95, fly#82.




## Mutation table (Phase 1, 2026-10-08)

`test-fly_footprint_misplaced.R` against four planted defects in `fly_footprint()`:

| mutation | failures |
|---|---|
| none (baseline) | 0 |
| `on_mis` drops `under_terrain` entirely (names frames outside the fallback set) | 1 |
| reader drops the `location == "misplaced"` filter | 4 |
| key ignores `focal_length` | 2 |
| key uses unformatted `fh` | 12 |

The first needed a mixed fixture: a misplaced key above the terrain beside another frame under
it, so the block runs. Code-check round 1 showed what it does and does not isolate: replacing
`under_terrain` with `unusable` passes, because for a keyed frame with complete metadata the two
coincide (an `unusable` frame with finite height, lens and scale and a covered DEM is under the
terrain). So the test pins "only frames in the fallback set are named", not `r <= 0` separately,
and no test can separate them today.

## Code-check round 1 (2026-10-08)

The warning claimed per frame what fly#97's label holds per roll-height (`bc77072` 225 and four
`bc77026` frames have no logbook row; `bc77087` rests on fly#101's non-blind read), and its "so"
made the photos a reason for the centroid being at fault. Rewritten to state fly#97's either/or
(the height is not above sea level as written, or the frames are not where the catalogue puts
them) and the two caveats, in the warning, the code comment and the roxygen.

## Pre-existing lint

`indentation_linter` at the `partial` warning in `R/fly_footprint.R` is on `main` too; left alone.

## Plan review (Plan agent, arrived after Phase 2 was written; 2026-10-08)

Acted on:
- **B1.** `num()` lived inside the roll-table block, which does not run where `out_of_band` is
  all FALSE (a `media` outside `fly_film_media()`), so the warning would have errored. Lifted;
  new test, which is the only one red when the old scope is restored.
- **G1.** Only `r <= 0` frames are named. Against MRDEM that is 112 of the 311 frames on the five
  keys, and the other 199 (the `terrain` tail rows in `flying_height_rolls_excluded.csv`) are
  refused by the ratio check. Stated in roxygen and pinned to both CSVs.
- **G3.** The roxygen lists the five keys; a test rebuilds the list from the reader and checks
  the Rd.
- **A1.** The generator's rule labels `consistent_nominal` and `disagrees` keys `misplaced` too,
  for which the step sentence would be false; the reader test asserts every one is
  `step_overstated`.
- **W1-W4.** The warning's per-frame logbook claim, the causal "so", "suspiciously even" and the
  `fly#97` in the message string were rewritten; `bc77070`'s resolution caveat added.
- **AC1.** The generic warning is pinned verbatim.
- **G5, O2.** CLAUDE.md and the note, in Phase 3.

Not acted on: the stale "mirrored rectangle" comment near the coverage block predates this branch.

## Code-check round 2 (2026-10-08): two findings, one inside a fix

- The roxygen called the 311 "frames on these roll-heights". It is fly#93's census (in band above sea
  level but below it over the ground, plus under the terrain); the 1977 centroid cache holds 368 on the
  five keys, 57 of them in band and sized from the DEM as usual. This was inside the plan review's G1
  fix, so the loop now ends only on an enumeration.
- "Not every frame named is reached by a logbook row" is false for a call whose frames all sit on
  `bc77070`, `bc77072` 1981 or `bc77087` (`frames_logbook == frames`). Rescoped to the five roll-heights.

**Mechanism:** a figure or a property computed over one population (the census, the roll-height, the
frames a logbook row reaches) stated over a wider one (every frame on the roll-height, the frames this
call named, every frame a page reaches).

## Enumeration (2026-10-08)

Every quantified claim the branch adds, in the warning string, roxygen, code comments, NEWS, CLAUDE.md,
the note and test comments, checked against its producer:

| claim | producer | verdict |
|---|---|---|
| pages write the catalogued height above sea level for the frames they reach | W2 rule: `frames_catalogue >= 0.9 * frames_logbook` (`data-raw/height_measure-image_overlap.R:651`) | was "all"; now "at least 90%", pinned to the rows |
| M.S.L. header | note; pinned on the 107 reached `r <= 0` frames only | stated as the note does; test comment says the rows do not carry it |
| step longer than the air base | `w1 == "step_overstated"` per key | per roll-height; asserted for every `misplaced` key |
| not every frame reached by a logbook row | `frames_logbook < frames` on `bc77026`, `bc77072` 1829 | scoped "across the five" |
| one rests on a non-blind digit | `bc77087` (fly#101) | scoped "across the five" |
| one has a step margin at resolution | `bc77070`, D_agl -0.226 vs tau 0.220 (note) | only one in the note |
| 112 / 311 / 199 | `frames_nonpositive`, `frames`, `_excluded.csv` terrain `frames_measured` | scoped to the census; pinned |
| 64-77% of steps equal within 0.5% | fly#82 probe of 1965/1975/1985 rolls (note) | "in a probe of older rolls" |
| frames in band sized from the DEM as usual | code path (`corrected`) | true by construction |
| "not every frame named" | n/a | gone from all four places it appeared |

## Code-check round 3 (2026-10-08): the enumeration above was incomplete

Mechanism named by the reviewer: a sentence names its frame set by what it is about, and nobody checks
that set against the line that computed the figure. Four instances the enumeration missed, all fixed:
- "an unlisted roll-height is unmeasured": the list is 5 of fly#97's 9 keys; `bc7718`, `bc80117`,
  `bc5715` and `bcc325` were measured and labelled otherwise (warning, roxygen, reader comment, NEWS,
  note). Now "not thereby clean", with the 9 and the 4 pinned.
- CLAUDE.md "at least 90% (not all)": all five keys read 100%; 90% is W2's threshold.
- The code comment's "not every frame on them" cited the `r <= 0` subset's five frames; it now cites
  the census counts (`bc77026` 80 of 118, `bc77072` 1829 12 of 17), pinned.
- "the frames they reach": the denominator is `frames_logbook`, frames **read**; the producer separates
  read from covered. Now "read" everywhere.

## Termination: a mechanical enumeration (2026-10-08)

Every added prose line outside `planning/` (184 lines: warning string, roxygen, R comments, NEWS,
CLAUDE.md, note, test comments) was extracted from `git diff origin/main` and each frame-set reference
checked against its producer. That read found three more stragglers of the round-3 class (roxygen
"reached by a logbook row", roxygen "measured so far", reader/test headers "measured as misplaced"),
fixed; a grep for each phrase now returns nothing. Every remaining claim is per roll-height and scoped
to the five keys, to the census, to frames read, or to the `r <= 0` subset, as its producer is. The loop
ends here, on the enumeration, not on a reviewer's Clean.
