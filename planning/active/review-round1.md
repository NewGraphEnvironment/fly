# Code-check round 1 — fly#99 staged diff

Reviewer: subagent, 2026-10-08. Worked in a scratch copy; the only write to the repo is this file.

## Findings

- **[severity: fragile — over-claim in shipped warning text]** `R/fly_footprint.R:1411-1415`
  (and the same claim in the roxygen paragraph at ~735-745 / `man/fly_footprint.Rd:212-222`).
  The warning states, unqualified, for every frame it names: "the flight logbook writes the
  catalogued height above sea level ... so the centroid, not the height, is the likelier fault,
  and the ground the DEM read is probably not the ground photographed." The note
  (`inst/notes/terrain-correction.md`, "What the frames under the terrain covered") does not
  support that for every frame it can name:
  1. **`bc77072` 1829.** Its only `r <= 0` frame in the catalogue (225) "is on no page". The
     not-over-the-ground-photographed conclusion "rests on the logbook, not the photos", and no
     logbook row reaches that frame. It is `misplaced` "only because the verdict is made per key".
     So every catalogue frame this warning can name on that key gets a per-frame claim the
     measurement does not make. The same goes for `bc77026` 221, 222, 237 and 247, which lie past
     the shipped row's 219.
  2. **`bc77087` 1158** (38 of the 107 frames). "The logbook writes the catalogued height above
     sea level" holds only on the page digit read as 3.8. A human settled that read in fly#101,
     the read was not blind, and three blind reads disagreed. Read as 7.8, the page puts the
     ground *under* the height, which is the opposite of what the warning says. The warning
     doesn't qualify this.
  3. **"so the centroid, not the height".** The `so` makes the photos part of the reason for
     ruling out the height. The note says the opposite: "The photos cannot reject the other horn
     ... `D_agl` ... does not test the datum". Code-check round 1 of fly#97 withdrew A2's gloss
     "the images reject reading the column as above ground" as wrong. Linking the photo finding
     to "not the height" with `so` repeats that gloss.

  The issue's brief names (1) and (2) as non-over-claim requirements. Neither is honoured in the
  text. The fix is wording only (no geometry or columns involved): qualify the two keys, or make
  the logbook clause per-key rather than per-frame.

- **[severity: fragile — test premise false; guard not exercised]**
  `tests/testthat/test-fly_footprint_misplaced.R:75-81`. The comment says the mixed fixture's
  `bc77070` frame (1158 m over 1000 m) is above the terrain, "so ... only the `r <= 0` test keeps
  the misplaced key out". It isn't kept out that way. r = 158 / 765 = 0.21 is outside
  `fly_height_ratio_band()`, so the frame is `disputed`, then `implausible` (I checked
  `height_source` and the warnings), and the `unusable` gate drops it before `fh <= elev` is
  reached. Mutation run in a scratch copy: with `on_mis <- unusable & ...` in place of
  `under_terrain & ...`, the whole file stays green (27 passes). It's harmless today: on a matched
  key with finite metadata, `unusable` and `under_terrain` cannot differ, because a misplaced key
  above the terrain is either `corrected` or `implausible`. But the comment and the
  `findings.md` mutation row ("`on_mis` drops `under_terrain`" → 1 failure) describe a guard
  that the test does not actually isolate.

## Checked and clean

- **`height_source[under_terrain]`.** The value is the same as the old inline predicate. Between
  its definition (~1393) and its use (~1522), nothing reassigns `unusable`, `fh` or `elev`, and
  both lines sit in the same `if (!is.null(dem))` branch.
- **`num()` lifted out of the `if`.** It is still defined before both uses, and no later binding
  shadows it.
- **Key formatting.** `read.csv` integers against frame doubles, an integer `flying_height` or
  `focal_length` from the caller, and factor `film_roll` all match. NA roll is excluded
  explicitly. An NA in focal or scale gives `"NA"`, which no ledger key contains.
- **Reader.** It returns exactly the five `misplaced` rows. `bc7718` and `bc80117` (`not_tested`)
  are excluded. The CSV is tracked, lives under `inst/extdata`, and `.Rbuildignore` does not
  exclude it.
- **Other fixtures.** No other test calls `fly_footprint()` on these five keys, so no existing
  test gains the new warning.
- **Behaviour.** Geometry and columns are unchanged. The new test file passes in the scratch copy
  (27 expectations).
