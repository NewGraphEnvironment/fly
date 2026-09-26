# Task: fly#54's ÷10.764 looks like ÷10 on the pre-2000 slipped rolls (#71)

## Problem

fly#54 repairs 1,589 film frames by dividing `FLYING_HEIGHT` by 3.28084² = 10.764. Measured
while settling fly#60, that factor looks right for the 2003 rolls and **about 7.6% wrong for
the pre-2000 ones**, where the defect appears to be a dropped decimal point, ×10.

Two independent signs, both from public data:

- **A flight logbook.** Roll `bc78065` is catalogued at 4,115 m (13,500 ft) on its 1:2000
  frames. Its scanned logbook page (`flight_log_url`), read with the catalogue values withheld,
  gives TRUE HEIGHT **1.35**, i.e. 1,350 ft. ÷10 gives 411 m; ÷10.764 gives 382 m.
- **Round feet.** Planned altitudes are round numbers of feet. Under ÷10 the pre-2000 slipped
  heights land exactly on them: bc5596 8,600 ft, bc78065 1,350, bc78078 3,100, bc79103 7,200,
  bcc00085 18,000 / 18,500 / 19,000. Under ÷10.764 they don't.

The ratio to `scale × focal_length` points the same way. Ordinary frames centre on r = 1.03:

| roll | year | frames | r ÷10 | r ÷10.764 |
|---|---|---|---|---|
| bc5596 | 1974 | 8 | 0.957 | 0.856 |
| bc78065 | 1978 | 24 | 0.975 | 0.880 |
| bc78078 | 1978 | 15 | 0.957 | 0.884 |
| bc79027 | 1979 | 10 | 0.970 | 0.898 |
| bc79103 | 1979 | 24 | 1.031 | 0.929 |
| bcc00085 | 2000 | 236 | 1.030 | 0.944 |
| bcc03004 / 06 / 07 / 08 / 46 | 2003 | 1,054 | 1.15–1.22 | 1.06–1.11 |
| bcc05001 | 2005 | 217 | 1.078 | 0.979 |

The 2003 rolls carry measured per-frame heights, not planned ones, so round feet cannot speak
for them, and there ÷10.764 is the better fit.

## Context (from plan-mode exploration)

fly#54 divides `FLYING_HEIGHT` by 3.28084² on 1,589 film frames. fly#60's control roll
`bc78065` read 1,350 ft in its logbook, which fits ÷10, not ÷10.764. Round feet point the same
way on the other pre-2000 rolls. If that holds, those frames are drawn about 7.6% too narrow.
The issue's own fix: carry the pre-2000 rolls in `flying_height_rolls.csv` with factor 1/10,
**not** change `fly_height_slip_factor()`.

What exploration established (read-only probes, 2026-09-26):

- **Slipped roll-heights** (sweep `upper_tail`, in band after ÷K): 13 rolls. The issue's table
  lists 12 and leaves out **`bcb98013` frame 52**: 97,924 m on a roll whose other 207 frames read
  7,924. That is an extra leading digit, not a slip. Neither ÷10 nor ÷10.764 gives 7,924.
- **Logbook links in the catalogue** for the frames that slipped:
  | roll | slipped frames | page |
  |---|---|---|
  | bc78065 | 38–61 | already read (CONTROL, 1.35) |
  | bc78078 | 77–91 | `bc78078_6.jpg` (55–91) |
  | bc79027 | 205–214 | `bc79027_4.jpg` (190–214) |
  | bc79103 | 294–317 | `bc79103_5.jpg` |
  | bcb98013 | 52 | `bcb98013_1.jpg` |
  | bcc00085 | 1–236 (3 heights) | `bcc00085_1.jpg` |
  | bc5596 | 204–211 | **none** (frames 141–211 have no URL; page 3 starts at 212) |
  | bcc03004/06/07/08/46, bcc05001 | all | **none** |

  So the logbooks can settle 5 rolls plus the control. They cannot settle the six 2003/2005 rolls,
  and those keep #54's ÷10.764, which the issue says fits them better. They also cannot settle
  `bc5596`: its slipped 26,212 m is exactly ×10 of the neighbouring frames' 2,621 m, but that
  witness is noted and not used.
- **`R/fly_footprint.R:1152`** accepts a tabled row only where `tab_factor == 1` or
  `tab_factor > 1`. A factor of 0.1 is rejected silently, so that one line has to change. The
  table is already consulted before the slip, for any out-of-band frame, and the keys cannot
  collide: the slipped heights differ from every lower-tail height.
- **`data-raw/height_calibrate-lower_tail_rolls.R`** stages 4–5 do the logbook join, the verdict
  and the write. They are keyed to `lower` and to the factors `c(1, 10, 100)`.
- **`test-fly_footprint_height_rolls.R:192`** expects the factor set to be `c(1, 10, 100)`, and
  `:199` expects every lower-tail roll-height to be either corrected or excluded.

## Decision for the gate (stored data) — DECIDED: `tail` column

**Where the slipped roll-heights the logbook cannot settle get recorded.** Chosen: add a
`tail` column (`"lower"` / `"upper"`) to both shipped tables and list the untabled upper-tail
roll-heights in `flying_height_rolls_excluded.csv`, with a reason that says #54's ÷10.764 still
applies. Accounting stays complete ("an unlisted roll is unmeasured"). Alternative: keep
`excluded` lower-tail only and record the upper tail in the note alone. That changes no schema,
but the 2003/2005 rolls stay findable only in prose.

## Phases

### Phase 1: Read the pre-2000 logbooks blind
- [x] Fetch the five pages above into `data-raw/.cache/logbooks/` with the script's existing
  `fetch_logbooks()`. It is guarded by `dir.exists`, so call it for these rolls explicitly
- [x] Transcribe them through a subagent. It gets the image paths and the CSV column spec, and
  it gets **no catalogue heights**, as fly#60 did. Append the rows to
  `data-raw/flying_height_logbooks.csv` with `control = FALSE`
- [x] Record the reading in `findings.md`: which factor each roll names, and the `bcb98013` typo

### Phase 2: Tests first
- [ ] `test-fly_footprint_height_rolls.R`: allow a factor below 1. A frame on a tabled 1/10
  roll-height is sized from `height_m`, so it is `corrected_roll_table` and not
  `corrected_unit_slip`. A 2003 frame still takes ÷10.764
- [ ] Mutation check: restore `tab_factor > 1` and confirm the new test goes red
- [ ] Update the sweep-holding test. Every upper-tail slipped roll-height is either tabled or
  excluded (per the gate decision). The factor set becomes `c(1, 10, 100)` plus whatever the
  logbooks name for the upper tail

### Phase 3: Code
- [ ] `R/fly_footprint.R`: `tab_factor > 1` → `tab_factor != 1` in `tabled`. Update the comments
  and the roll-table warning text, which says "dropped digits", to cover a height recorded ten
  times too large
- [ ] Update the `fly_height_slip_factor()` comment. Its claims "the only candidate that survives
  the terrain" and "fires on the 1,589 and on nothing else" now hold only for the frames the
  table does not reach
- [ ] `fly_height_roll_table()` roxygen/comment: `factor` can be below 1

### Phase 4: Calibration script and shipped tables
- [ ] Refactor stages 4–5 of `height_calibrate-lower_tail_rolls.R` into one function run over
  a set and its named factors: lower tail `c(1, 10, 100)`, slipped upper tail `c(1/10, 1/K)`.
  The rule stays the one fixed in fly#60 (≥50% covered, ≥90% agree, no lens conflict, spacing
  fits). New causes: `height_decimal_added` (1/10) and `unit_slip` (1/K)
- [ ] Print round-feet distance under ÷10 and ÷K as a non-gating witness. State that spacing
  cannot separate 7.6%
- [ ] Rerun the script. Regenerate `flying_height_rolls.csv` and `_excluded.csv`, and diff the
  lower-tail rows, which must come back unchanged
- [ ] Run `devtools::test()` and `lintr`

### Phase 5: Docs
- [ ] `inst/notes/terrain-correction.md`: replace the fly#71 paragraph with the result
- [ ] Add a CLAUDE.md Key Decision line
- [ ] Draft the NEWS entry. The version bump is left to `/gh-pr-merge`
- [ ] File a follow-up issue for `bcb98013` frame 52 (a typo that #54's ÷10.764 draws ~15% wide)
  and for bc5596 (×10 of its neighbours, no logbook), unless the logbook settles the first

## Verification
- The script's controls pass (spacing, `bcc228`, `bc7349`), and `bc78065` reads back factor 1/10
- The lower-tail rows of `flying_height_rolls.csv` are byte-identical before and after
- `devtools::test()` is green, and the mutation (`> 1`) goes red
- `fly_footprint(dem =)` on a synthesized `bc78065` 1:2000 frame gives `height_agl` near
  411 m − elev and `height_source == "corrected_roll_table"`

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
