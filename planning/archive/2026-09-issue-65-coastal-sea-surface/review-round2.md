# Code-check round 2 — fly#65 (review of the round-1 fixes)

Reviewer worked read-only on the repo; tests were run on a copy under the session scratchpad
(`NOT_CRAN=true`, `load_all`): `test-fly_footprint_coastal.R` 71 pass, `test-fly_footprint_coverage.R`
273 pass.

## Verified, no finding

- Every figure the note / NEWS / CLAUDE.md / roxygen / findings quote matches
  `data-raw/.cache/logs/dem_coastal_run3.log` and the shipped CSV: 2,334 / 30 (13 + 17) /
  157 (152 coastal) / 23 / 0 / 2,124; 1,242 on 138 rolls; 592 on 59; 151 in the sensitivity;
  2.38% / 14.77%; control 3 median 0.021 m; bootstrap intervals; the 697 m tide figure
  (min `height_agl` over admitted = 697.04; 3.5/697 = 0.50%). run3 reports every CSV
  "unchanged", so the staged CSVs are the current script's output.
- Partition (script and test): categories are disjoint and exhaustive by construction; NA
  would make `sum()` NA and fail loudly, not pass. No frame is ineligible on `dem_coverage`.
- Sensitivity subset matches the admitted definition apart from `outside_not_sea`
  (eligibility is implied, finite `d` implies finite `mean_land`, `rays_bad %in% 0` and
  finite `area_t` match `rays_failed`).
- Control 3 is what Amendment 1 item 2 fixed (median under 1 m, admitted frames).
- fly#58 bound change: fly#58's section is lines 561–864 and every subsection in it is
  `###`, so "next `## `" gives exactly the lines the old "`## Testing this`" bound gave
  before fly#65 was inserted. No `## ` line appears inside a code fence in either section.
- None of the 157 `outside_not_sea` frames is near a land border (all inside BC; nothing
  near 49.0 N or the Alaska line), so "not a land border" holds.

## Findings

- **[fragile]** `inst/notes/terrain-correction.md` ~952–957 (and the test comment at
  `tests/testthat/test-fly_footprint_coastal.R:104`, `findings.md` correction paragraph) —
  fix 1 replaces one unmeasured mechanism with another. The note says the 157 frames
  "caught shoreline misregistration" and calls the sensitivity set "the 151 misregistered
  coastal frames". The only evidence is a median of per-frame medians (0.09 m). Per frame,
  42 of 157 have outside-cell medians above 0.5 m, 28 above 1 m and 10 above 5 m. Run
  `c052` (airp 1501404–1501406, near −125.18, 50.53) has 2,905–6,817 outside cells per
  frame at a uniform ~9.95 m, with 94–99% above 2 m. That is several km² of flat surface
  outside the polygon, not a misregistered shoreline sliver. The column name
  `outside_not_sea` is accurate. The prose should say what was measured (for example "115
  of 157 read under 0.5 m outside the polygon") and not assert misregistration for all of
  them. No verdict moves.

- **[fragile]** `tests/testthat/test-fly_footprint_coastal.R:441` — the new table guard
  pins the number of *tables* (3 separator lines) but not the number of *rows*. The section
  has 15 `|` lines (3 headers, 3 separators, 9 body rows). A tenth row added to any table
  keeps the separator count at 3, and every existing `%in%` check still passes, so the
  new row's figure goes unchecked. The comment claims "each rebuilt row by row". fly#58's
  guard pins rows per table (`expect_identical(length(t1), 8L)`). This one needs the same,
  e.g. `expect_identical(sum(startsWith(sec, "|")), 15L)`. Changing an existing figure is
  caught (as the mutation test showed). Adding one is not.

- **[bug, published text]** `inst/notes/terrain-correction.md` ~960 — the accounting list
  fix 2 added says "Every one is accounted for once" and ends "That leaves **2,124
  admitted**: 1,242 frames with sea in them … and 592 inland frames". 1,242 + 592 = 1,834.
  The sentence reads as a breakdown and leaves 290 admitted frames unaccounted for:
  - 225 non-coastal-flagged frames in coastal runs;
  - 64 coastal-flagged frames with no sea cell;
  - 1 coastal frame with sea but `d < 0`.

  Say that the two sets are what is scored, or add the 290.

- **[low, published claim]** note ~985 "L is **always** smaller than W where sea is
  present", and `test-fly_footprint_coastal.R:171` `expect_true(all(co$area_l <
  co$area_w))`. `co` is filtered on `d > 0`, and `d > 0` is exactly the condition
  `area_l < area_w`, so the statement and the test are both tautological. 1,243 admitted
  coastal frames have sea cells (`n_sea > 0`). One has `d = −0.00024`, so L is wider than
  W there, and it is dropped by the filter. "1,242 frames with sea in them" (note, NEWS,
  roxygen, CLAUDE.md) is really "with `d > 0`". The fix is to reword; no figure moves
  materially.

- **[fragile]** `data-raw/dem_measure-coastal_water.R:544` — fix 7's
  `setequal(m$airp_id, runs$airp_id)` ignores multiplicity. Two stale run files that
  overlap in membership (a selection rebuilt so a frame moves between run ids) pass the
  guard with duplicate rows, which would be written to the CSV. The suite's
  `anyDuplicated == 0` would catch it after the fact. Add
  `!anyDuplicated(m$airp_id)` / `nrow(m) == nrow(runs)` to the `stopifnot`.

- **[low, wording tied to fix 3]** note ~906–915 — "Each of 128 points on the returned
  rectangle's boundary is traced" (128 in total, 32 per edge, the measurement's density)
  sits beside "The 32-ray polygon cuts the corner … converges away at 128 rays" (128 *per
  edge*, 512 points). This reads as though the measurement ran at the converged density. At
  the density actually used, the step control is 2.6e-4, above Amendment 2's
  pre-registered 1e-4. `findings.md` discloses that; the note does not. Say "per edge" in
  both places.

- **[low, wording]** note ~952 "30 were not DEM-sized at a believed height: 13 on the roll
  table". The 13 are `dem_agl`, DEM-sized at a roll-table-corrected height, and were
  excluded because the rule admits only `height_source == "reported"`. "Not at the
  reported height" is what was tested.

- **[low, wording]** `R/fly_footprint.R:815` / `man/fly_footprint.Rd` — "the same frame on
  LidarBC is sized from the land alone". The note and NEWS say "roughly": 8–25% of the sea
  cells in the probe tiles still carry data (−2.533 m).
