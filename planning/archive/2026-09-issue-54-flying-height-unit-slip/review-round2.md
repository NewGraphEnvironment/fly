# Code-check round 2 — fly#54 (`flying_height` checks)

Reviewer: subagent, 2026-09-18. Diff: whole branch + working tree against `main`.
Nothing in the repo was modified; restorations were done in a scratch copy.

## Verdict

**No code defect found.** Both round-1 fixes hold, are guarded by tests that go red when the
defect is restored, and did not disturb the adjacent classes I could construct. What remains
is five documentation claims that disagree with the shipped data or with a measurement —
all low severity, none affects a footprint.

## Findings

All **verified by running** unless marked otherwise.

- **[fragile — false release-note / test-comment figure]** `NEWS.md` 0.12.0 last-but-one bullet,
  and `tests/testthat/test-fly_footprint.R:344-347` — "had been sizing its 'wide frame' at
  2.8 km rather than the 7.9 km its comment described". Measured by running `main`'s
  `R/fly_footprint.R` (scratch copy) on row 1 relabelled 1:31680 at the edge cell: **2,659 m**
  (height_agl 1,779), not 2.8 km. Row 11 on the branch comes back **7,688 m** (nominal 7,242 m),
  not 7.9 km. And `main`'s comment never described a width at all — it says only "a wide
  frame" (`git show main:tests/testthat/test-fly_footprint.R`), so "the 7.9 km its comment
  described" has no source. 2.8 / 7.9 look like arithmetic with an assumed ~700 m ground rather
  than a reading (edge ground is ~810-850 m). Suggested: "2.7 km" and "7.7 km", and drop "its
  comment described".

- **[fragile — note claims that disagree with the shipped sweep]**
  `inst/notes/terrain-correction.md:135-139` (the inverse-slip paragraph). Recomputed from
  `inst/extdata/flying_height_sweep.csv`, lower_tail x 10.764:
  - "The repaired values spread from 0.63 past 3 **with no gap**" — they run from **-0.70 to
    5.38**; 130 of 1,962 land *below* the band (-0.70 to 0.002), nothing sits between 0.002 and
    0.676 (so the lowest in-band value is 0.676, not 0.63), and there are empty stretches at
    2.13-2.47 and **2.85-3.32** — i.e. there *is* a gap, right at the "3" the sentence names.
    The qualitative point (in-band and out-of-band values are not separated the way the forward
    slip is) survives; the numbers and "no gap" do not.
  - "the forward slip is 0.80-1.32 **behind a gap six wide**" — no reading of the data gives an
    empty stretch six wide. The empty stretch in `r` is 6.69 -> 10.01 (3.3 wide; the note's own
    table says so); in repaired terms it is 0.46 -> 0.80. "Six" appears to be
    `min(r[slipped]) / band[2]` = 6.26, which is the test's margin, not a gap — 505 non-slipped
    upper-tail frames sit inside that span.
  - "doubling brings 799 (the lens mislabel again, sitting at a ratio of exactly 0.500)" — only
    **306 of the 799** sit there, and at `ratio_asl` 0.4997 (= 152.4/305, i.e. height computed as
    scale x 6 in), not 0.500; the rest are at 0.498, 0.44, 0.423, 0.346. Only 519 of the 799 are
    catalogued at 305 mm; 280 are catalogued at 153 mm, which a 153<->305 mislabel cannot explain.

- **[fragile — overclaim]** `NEWS.md` ("`data-raw/height_calibrate-flying_height_slip.R`
  reproduces every figure from public data") and `inst/notes/terrain-correction.md:88`
  ("reproduces all of it"). The script does not compute the **98.7%** weighted share, the
  **1.2%**, or **209 of 223** (no weighting, no `r > 1.8`, no focal-length tabulation anywhere in
  it — grep), and the constants test does not assert them either. The figures themselves are
  right — I recomputed each from the two shipped CSVs (0.98659; 1.34% outside minus 0.11%
  slipped = 1.23%; 209 of 223, the other 14 being 13 at 305 mm and 1 at 88 mm) — but three
  headline numbers of the release note currently have no producer, which is the round-1 #3
  class one axis over. Either print them in Stage 4 or soften the sentence.

- **[fragile — stale field]** `DESCRIPTION:5` — `Version` moved to 0.12.0 but `Date:` is still
  `2026-09-08`, the 0.11.0 date; `NEWS.md` dates 0.12.0 2026-09-18. The last two releases
  (`ef4810d`, `bdca92b`) moved `Date` with `Version`. (DESCRIPTION is unstaged, so possibly
  still in flight.)

- **[fragile — roxygen NA list not exhaustive; very low]** `R/fly_footprint.R:578-580` /
  `man/fly_footprint.Rd` — "`NA`: ... or `flying_height` or `focal_length` missing". A film frame
  with `focal_length = NA` and `flying_height > 16000` comes back `"implausible"` /
  `"nominal_scale"`, on or off the DEM (probe A4), because `untested` requires `comparable`
  and `comparable` requires a finite nominal height. Behaviour is defensible — the DEM could not
  have sized it either way, so `no_dem_coverage` would send the caller to enlarge a DEM for
  nothing — and it is **unreachable in today's catalogue**: 0 film frames outside the 1,589 read
  over 16,000 m, and all 1,589 have a focal length (from the local cache). Recorded only because
  the task asked for the NA statement to be run. The list also omits the rows that were never
  DEM-eligible (unknown format, unparseable `scale`), which are NA too.

## Checked and found correct

**Fix 1 (`height_refused`)** — restored `!(height_source %in% "implausible")` in a scratch copy:
"a digital frame below the terrain is still told it has no footprint" fails (1). With the fix,
probe A8 (film + camera-table frame, both at `flying_height` 100 under 700 m ground) gives
`implausible` on both, the `unusable` warning "2 of 2", and the no-way-to-size-it warning
"1 of 2". A ceiling-refused table frame (fixture row 6) still suppresses it.

**Fix 2 (`untested`)** — restored the ungated ceiling arm: "a slipped frame the DEM does not
cover ..." fails (4). With the fix:
- no-`media`-column slipped frame over the ceiling, off the DEM -> `no_dem_coverage`,
  `height_source` NA, `dem_coverage` 0, only the outside-the-DEM warning (A2); same under the
  ceiling (A2b).
- `format_size`-named `Digital - Colour` frame at 45,000 m -> `implausible` / `nominal_scale`
  with its nominal footprint, on the DEM (`dem_coverage` 1) and off it (`dem_coverage` 0) (A1).
  Consistent with "only the ceiling applies to a digital frame, and it needs no terrain"; the
  warning's "sized from nominal scale instead" is true for it.
- camera-table frame over the ceiling, off the DEM -> `implausible`, empty (test).
- no second-pass window is built for an untested frame (`resize(NA, .)` is NA).
- `implausible`, `slipped`, `untested` cannot be NA — every operand is `is.finite()`-guarded
  or NA-free by construction.

**Invariant** (`test-fly_footprint_invariants.R`): `has_height == !is.na(height_agl) ==
(footprint_terrain == "dem_agl")` holds by construction — all three are written only on
`corrected`, which implies a drawn rectangle — and over the 13-case sweep (792 expectations, 0
failed). One unreachable-in-practice residue, not a finding: a frame in band on pass 1 whose
pass-2 elevation exceeds the *repaired* height would land in `unusable` with `height_source`
NA, since that label tests raw `fh <= elev`.

**`dem_coverage` / `footprint_terrain` per class** (probe A7 and tests): reported & repaired ->
second-pass coverage of the returned rectangle, `dem_agl` (the truncated-DEM twin test pins
repaired == clean); implausible film -> first-pass coverage of the nominal rectangle that is
returned, `nominal_scale`; implausible table frame -> NA / NA, empty; uncovered -> 0,
`no_dem_coverage`; unusable film -> first-pass, `nominal_scale`.

**Test vacuity** — restored four defects against the scratch copy; each turned exactly the test
written for it red: fix 1, fix 2, second pass not withheld, ceiling frame seeded (the last two
both fail "no DEM window is ever built ..."). The constants test's premises are real
(1,589 / 13 / 2,500 / 2,733 > 2,000; `NA >= 9` on the digital row is `FALSE & NA` = FALSE, so the
population sum is not NA). `man/` regenerates byte-identical from the roxygen; `NAMESPACE`
unchanged. Full suite on the working tree: 22 files, 1,829 expectations, 0 failed, 0 errors,
0 skipped, 0 warnings (`NOT_CRAN=true`).

**Numbers recomputed and matching** (shipped CSVs; catalogue-wide ones from
`data-raw/.cache/centroids`): 10.764; 1,670,471 centroids; 1,437,147 usable film ("1.44
million"), 1,419,822 at ratio_asl <= 2 ("1.42 million"), 15,231 in (2,3]; 7,156 = 2,094 + 600 +
2,500 + 1,962; 1,589 frames / 13 rolls / the 13 roll names and years / 1,054 on five 2003
rolls; slipped r 10.01-15.83, repaired 0.80-1.32 median 1.05; nothing 6.69-10.01; feet
3.02-4.71 with 0 in band; random median 1.03, 2.5-97.5% 0.81-1.25, 99.2% (2,481 of 2,500);
98.7% weighted; 1.2% (1.23%); 209 of 223; 2,733 with 0 repairs; 1,208; 1,963 / 1,962;
726 / 729 / 799; 14,630 m is 1:90000 film (8 frames, all 153 mm); digital max 7,513 of
223,667, none over the ceiling; `bc78065` 4,115 m at 1:2000 and `bc78078` 9,449 m at 1:6000;
lowest slipped 4,115 m; every 2003 slipped frame over the ceiling (69.8-79.8 km; 1,550 of all
1,589 are, the 39 that are not are the 1978 rolls). "The correction applies to those 1,589 and
to nothing else" holds for the whole catalogue, not just the sample: `r_fix <= ratio_asl /
10.764`, so a repair needs `ratio_asl >= 6.7`, and every frame above 3 was sampled. Fixture
arithmetic in `setup.R` and the test comments (41 km, 77 km, 15 km, 21 km, r = 2 for row 8,
14,424 m) checks out.

**Not verified:** "110,834 m across against 8,022 m" (NEWS, note) is restated from the issue
body; reproducing it needs the two frames over `/vsicurl/` MRDEM (fly#59: ~10 min). Plain
arithmetic gives 8,001 m for a 9 in negative at 1:35000, so 8,022 is presumably a bbox width of
a rotated or reprojected square — worth one look before it ships in a release note.
