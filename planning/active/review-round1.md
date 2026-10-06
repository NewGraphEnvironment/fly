# Code-check review, round 1 (fly#93), diff origin/main...HEAD

Verdict: no defect that moves a shipped number or verdict. Four findings. The first is a real
gap in the A2 proof. The other three are statements in the docs or the pre-registration that
the code and data contradict.

## What was verified clean (so the next round need not redo it)

- The census and population CSVs match `run_census.log` line for line: 1,437,147 / 1,389,968 /
  18,747 / 23 / 4,773 / 0 / 374, with 298 roll-heights and 216 rolls, Control 3 at 1,000 and 0,
  coarse max 142.7 and M 285.4.
- The terrain rows of both roll tables match the note's outcome table and NEWS row by row:
  62 tabled with 1,375 frames, which is 60 BW/colour rows and 1,344 frames plus the 2 IR
  rows; 238 excluded, with every reason count and frame count equal. The overlap range is
  0.562-0.773 and `r_corrected` is 0.313-0.619 (median 0.5355). The three partial-agreement
  rows are bc5225, bc5595 at 2651 m, and bc78104.
- `flying_height_rolls.csv`, `_excluded.csv` and `flying_height_logbooks.csv` have additions only
  (0 removed lines). bc5312 and bci12 are unchanged.
- The 406 appended logbook rows equal `consolidate()` over the 1,382 non-control literal lines,
  compared as a multiset on file, range, height, lens and scale. They cover 176 pages on 58 rolls.
  No control page was appended, and no appended page was already in the CSV.
- The A2 factor-1 tolerance is relative to the catalogue height: `abs(q / named - 1) <= 0.02` with
  `q = log_ft * FT / flying_height`. So `h_true` lies in [0.98 h, 1.02 h] and the 0.98/1.02 bounds
  are the right ones. A2(a) uses the same `median(p_nominal, na.rm = TRUE)` that `nu_row`
  uses.
- The note says the terrain keys reach 4,233 catalogue frames. That holds: the 2,858 key frames
  outside the census include 600 read exactly, and all are in band. None has r <= 0 and none is
  without terrain (checked against `elev_8212c794.rds`). `fly_footprint()` gates
  factor-1 rows on `r_reported > 0`, as the docs say.
- The above-band stop can fire: the upper arm read 1,511 frames.

## Findings

- **[fragile] data-raw/height_calibrate-lower_tail_rolls.R:296-321 (A2(b)); the same `p_at` at
  data-raw/height_measure-terrain_tail.R:378 and tests/testthat/test-fly_footprint_terrain_tail.R:86;
  inst/notes/terrain-correction.md:684.** The proof says each frame's overlap at the logbook
  height "lies between its overlap at 0.98 and at 1.02 of the height". Overlap
  `1 - base / side` is monotone only while `side > 0`. When a frame's ground is within 2% of
  the aircraft (0.98 h <= elev < h), a logbook height below `elev` gives a negative side, and
  the overlap is then **greater than 1**, not below `p(1.02 h)`. So `hi` is not an upper bound for
  those frames. The code comment says only "no lower bound"; there is no upper bound either.
  - **Where it occurs.** 21 census frames are like this. Three roll-heights excluded under
    `A2_CANNOT` contain them:
    - `bc77026` 2042 m, 305 mm, 1:6000: 6 of 107 frames;
    - `bc77072` 1981 m: 1 of 52;
    - `bc77072` 1829 m: 1 of 16.
  - **Why no verdict moves.** Conditions 1 and 2 force at least half the frames to agree. With so
    few frames above 1, the median of the agreeing set stays below the window on all three. But
    that is a counting argument; the per-frame bound the note, the code comment and NEWS rest on
    ("excludes only roll-heights the unamended rule could never accept") is false as written.
  - **Fix.** State the counting argument for these frames. Alternatively, treat `hi` as `+Inf`
    where any frame has `0.98 h <= elev`, which would send these three roll-heights to the
    logbook instead.

- **[docs] planning/active/findings.md:85 against data-raw/height_measure-terrain_tail.R:206-208.**
  - **What differs.** The pre-registered prefilter's upper arm is
    `flying_height - band[2] * nominal_agl > -M` (`need_high > -M`), which does not depend on the
    coarse elevation. The code reads `coarse < need_high + M` instead, which is a different and
    narrower set.
  - **Why it matters.** The "Amendments after the plan review" section does not record the
    change. `review-plan.md` G1 calls it "upper arm added", as if no arm had been
    pre-registered.
  - **Effect.** The code's form is sound by the same margin argument, and 0 frames were above
    the band. Still, the pre-registration and the run differ with no amendment written.

- **[docs] inst/notes/terrain-correction.md:710-713 (and the "accepted" premise).** The note says
  "lines at different heights, or with no height, are never merged" and that consolidation "can
  only withhold coverage". It does not hold everywhere.
  - **Where it fails.** `consolidate()` drops no-height lines from the merge sequence, so a run
    merges across them. On `bc7683__bc7682_7683_3.jpg`, the no-height lines at finals 49 and 84
    sit inside the consolidated 1-144 row at 20,000 ft. Those frames are now covered at a height
    nobody read for them.
  - **Effect.** This is the only instance in the 406 rows. No verdict moves: `bc7683` 2438 m is
    excluded as "not a named multiple" either way. But the claim that consolidation can only
    withhold coverage is false in this case.

- **[docs] inst/notes/terrain-correction.md:640-641; data-raw/height_measure-terrain_tail.R:12.**
  - **Pass count.** The note says "The second pass raised it to 285.4 m and the third read left
    it there." `run_census.log` and findings.md say there were two passes: pass 1's read
    (at M = 223.6) raised M to 285.4, and pass 2's read left it there. There is no third
    pass or read.
  - **Resolution.** The script header says the coarse picture is "~250 m". The run's picture is
    314 m, which the note states correctly. The 250 m figure is fly#80's cached DTM, not this
    script's 7,000-column output.
