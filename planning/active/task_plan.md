# Task: BW/colour frames whose catalogued height may be above ground, not above sea level (#95)

## Problem

The fly#93 census (`data-raw/height_measure-terrain_tail.R`) found two groups of BW/colour film frames. In both, the catalogued `flying_height` looks like a height **above ground** that was recorded as a height above sea level. No roll-table rule reads either group.

1. **374 frames on 15 rolls lie under terrain at or above the catalogued aircraft height** (`r <= 0`). Their ratio above sea level is in band, but the mean of MRDEM under the nominal square is higher than `flying_height`. `fly_footprint(dem =)` keeps them in its terrain-above-aircraft case. A factor-1 row cannot reach them (the `tabled` condition requires `r_reported > 0`), so the fly#93 `terrain` tail leaves them untailed, by amendment A3. Largest roll-heights:

   | roll | year | flying_height | focal | scale | frames | median elev |
   |---|---|---|---|---|---|---|
   | `bcc285` | 1981 | 1707 | 305 | 1:5000 | 106 | 1,974 |
   | `bc77070` | 1977 | 1158 | 153 | 1:5000 | 59 | 1,392 |
   | `bc77087` | 1977 | 1158 | 153 | 1:5000 | 38 | 1,334 |
   | `bc7718` | 1975 | 1524 | 305 | 1:5000 | 24 | 1,776 |
   | `bcc267` | 1980 | 1524 | 305 | 1:5000 | 23 | 2,213 |

   The other ten are `bc5602`, `bc81111`, `bc81075`, `bc80117`, `bc5695`, `bc77026`, `bc79121`, `bc77072`, `bcc325` and `bc5715`.

2. **176 terrain roll-heights (2,380 frames) where spacing fits nominal scale.** Amendment A2 excludes these, because no logbook height can make #72's rule accept them. Nominal scale already sizes them, but the disagreement sits in the height field. A height recorded above ground instead of above sea level would produce exactly this pattern: ratio above sea level in band, `r` below it, and nominal right.

## Context from plan-mode exploration

fly#93's census left two groups whose `flying_height` looks like a height **above ground** recorded as
above sea level, and no roll-table rule reads either:

1. **374 frames on 15 rolls at `r <= 0`** (terrain at or above the aircraft). `fly_footprint()` draws them at
   nominal with a warning; a factor-1 row cannot reach them (`tabled` needs `r_reported > 0`,
   `R/fly_footprint.R:1240`). They are only *counted* today (`flying_height_terrain_population.csv`), not
   shipped frame by frame — but every one is in the census's ETag-keyed cache
   (`data-raw/.cache/terrain_tail/elev_8212c794.rds`).
2. **176 roll-heights (2,380 frames) excluded by A2(a)**, "spacing fits nominal".

The issue asks whether "recorded above ground" can be tested, with any rule fixed before it is run.

### What exploration found (it shapes the phases, and is recorded as already known)

- **The two groups share roll-heights.** `bcc285` 1707 m has 106 frames at `r <= 0` and 39 in group 2;
  `bc77087`, `bc77072`, `bc81075`, `bc79121`, `bc77026` likewise. So the unit is the roll-height
  (roll, height, lens, scale), taking both groups' frames together — never one group alone.
- **Group 2 can never table under a #72-shaped rule.** Nominal already fits there by A2(a), and #72 requires
  spacing to *reject* the rival. So for group 2 the test can only *refute* "above ground" or leave it
  undecided; only roll-heights with group-1 frames, where nominal may be rejected, can move a footprint.
- **Separability.** "Above ground" predicts side = `FORMAT_M x flying_height / f`, i.e. `ratio_asl` times
  nominal. Group-2 roll-heights by `ratio_asl`: 20 at <= 0.77, 8 at 0.77-0.9, 60 at 0.9-1.1, 49 at 1.1-1.3,
  39 at > 1.3. Spacing separates readings ~1.6x apart and no closer (#60), so the middle ~60 are undecidable
  by spacing — and there the two footprints differ by under 10%.
- **Peeked, so not blind:** pooled over group 2's 2,380 frames, `ratio_asl` median 1.06 (0.63-1.59);
  overlap median 0.672 at nominal, 0.674 at `flying_height` as above-ground. No per-roll-height spacing
  and nothing on group 1's spacing has been computed.
- **Logbooks.** Every transcribed TRUE HEIGHT header is M'/M.S.L.-type or unlabelled (871 rows); none says
  above ground. Rows exist for 4 of the 15 group-1 rolls and 22 of the 144 group-2 rolls. A logbook MSL
  height near `flying_height + ground` is the discriminating witness for "above ground"; one equal to
  `flying_height` under an MSL header is a witness against.

### Phase 1: Pre-register the rule (findings.md, committed before any per-roll-height number exists)
- [x] Record what is already known (the bullets above, incl. the pooled peek) as not blind
- [x] Population: every roll-height reaching a group-1 frame or an A2(a) roll-height; both groups' frames together
- [x] Spacing witness S: per roll-height median overlap at `flying_height` as above-ground and at nominal,
      against the generator's window → `supports` (AGL fits, nominal rejected) / `refutes` (AGL rejected) /
      `undecided` (both fit) / `neither`
- [x] Logbook witness L, with tolerances fixed: `names_catalogue` (MSL header, within 2% of `flying_height`),
      `names_ground_plus` (MSL height ≈ `flying_height` + ground under the frames, tolerance fixed here),
      `above_ground_header`, `other`; coverage counted per frame as in #72
- [x] The tabling rule, #72-shaped and strict: S `supports` AND L covers ≥ half the frames with ≥ 90% naming
      `ground_plus` or an above-ground header; everything else excluded with the reason that fired
- [x] Evaluation order (as #93's A2): S first; pages transcribed only for roll-heights where S `supports`

### Phase 2: Ship the `r <= 0` frames from the census that found them
- [x] `height_measure-terrain_tail.R` writes `inst/extdata/flying_height_terrain_nonpositive.csv`
      (same columns, `base` from the same f1 rule)
- [x] Re-run from the ETag-keyed cache; the two existing CSVs must come out byte-identical
- [x] Test: 374 rows on 15 rolls, equal to the population row, every `r <= 0`

### Phase 3: The measurement — `data-raw/height_measure-above_ground.R`
- [x] Reads both censuses, the logbooks CSV and the generator's window; pulls helpers with `fns_from()`
      rather than copying
- [x] Writes `inst/extdata/flying_height_above_ground.csv` (one row per roll-height: frames per group,
      `ratio_asl`, both overlaps, S, L, outcome, reason)
- [x] ~~`FLY_AGL_SMOKE=1`~~ no smoke flag (deterministic; byte-identity checked instead); producer line for every figure the note will quote

### Phase 4: Blind logbook read (only if Phase 3 leaves S-`supports` roll-heights without rows) — NOT NEEDED: the one `supports` roll-height (`bc5602`) was fully transcribed
- [ ] Fetch pages; stop on any `FLIGHT_LOG_URL` page uncached or untranscribed (#93's guard)
- [ ] Blind transcribers with a control page each, appended to `data-raw/flying_height_logbooks.csv`
- [ ] Re-run Phase 3

### Phase 5: Verdict into the package (only if any roll-height tables; shape approved at the gate)
- [ ] Generator `height_calibrate-lower_tail_rolls.R` settles the tabled rows as tail `above_ground`,
      `cause = "height_above_ground"`, `height_m` = the catalogued height; excluded ones ledgered with reason
- [ ] `fly_footprint()` sizes those frames from `height_m` as height above ground (no terrain subtracted),
      reaching `r <= 0` frames too; `height_source = "corrected_roll_table"`
- [ ] `height_fixture()` gains a row reaching the route; restore-the-bug check that the test goes red
- [x] If nothing tables: no code change, recorded as such (as fly#65/#80) — nothing tabled

### Phase 6: Tests and documentation
- [x] `tests/testthat/test-fly_footprint_above_ground.R` recomputes every verdict and every note table from the shipped CSVs
- [x] `inst/notes/terrain-correction.md` section; NEWS; CLAUDE.md Architecture + Key Decision
- [ ] Edit issue #95's body to the outcome

## Validation

- [x] Tests pass
- [x] `/code-check` — run as four rounds over the branch (not per commit), ended by enumeration
- [x] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
