# Code-check review, Phase 2 round 2 (fly#53)

Scope: `diff53_p2r2.patch` (R/fly_rotation_calibrate.R, its tests, DESCRIPTION/NAMESPACE),
with the round-1 fixes read first. Probed in a copy of the repo; the test file passes there
(`NOT_CRAN=true`, FAIL 0 | PASS 101).

## Findings

- **[severity: fragile]** R/fly_rotation_calibrate.R:404-412 with :346 — a leg on which **every
  pair is NA** at every rotation still returns `status = "scored"`, so the roll reads
  `no_decisive_leg` ("legs were scored and none decided"). That is the defect class round-1 #3
  and amendment 4 removed for never-scored legs, still reachable through the scorer itself.
  The 500-cell floor at 25 m is fixed in ground units while overlap scales with the photo
  scale. At 60% overlap a film frame's common ground is 0.6 x side^2. Measured with
  `fly_footprint()`: at 1:3000 the side is 685.8 m and the overlap is **~450 cells**, under
  500. So every pair is NA on every leg, and NA columns give `pairs = 0` and `rotation = NA`.
  The crossover is about 1:3300. Catalogue cache: **8,353 film frames on 90 rolls** are at
  1:3000 or larger, and 10,910 frames on 115 rolls are at 1:4000 or larger, where pairs go
  NA in part.
  If the campaign draws any of those rolls, they are tallied as measured non-decisions,
  which inflates the "undecided" rate. That is the figure that would be read as the rule
  being too strict. The leg row does carry `pairs = 0`, so the case is recoverable, but
  `state` reports it wrongly.
  Remedy at the author's discretion, since the 25 m / 500 floor is pre-registered: give a
  leg whose verdict has `pairs == 0` (or no rotation with any finite pair) a status of its
  own, e.g. `too_little_overlap`, which then falls into `legs_unscorable`. Do not change the
  floor.

## Checked and clean

- Fix 1 (`unlink(o)` before `georef_one()`): covers the refused path and the failed path.
  The thumbnails are keyed by URL basename and reused, which is harmless because their
  content is identical. The leg directories are `<roll>_<first_frame>`, and two legs on a
  roll cannot share a first frame.
- Fix 2: `withCallingHandlers()` around `tryCatch()` sees the stretch warning (its text
  matches `georef_one()`'s message, `"would stretch it by"`) before the `return(FALSE)`.
  `georef_one()`'s other FALSE returns (`fly_gdal_dim()` NULL, an output missing or empty)
  and the errors all map to `"failed"`, which becomes `warp_failed`. A rotation the guard
  refused on only some frames is dropped as a whole, per the rule. Under `options(warn = 2)`
  the warning still reaches the calling handler, because the conversion to an error happens
  only in the default handler.
- Fix 3: the state order matches the rule plus amendment 4. `thumbnails_unavailable`
  outranks `legs_unscorable`, and a scored leg outranks both.
- Fix 4: the typed zero-row template binds with the per-roll tibbles. `rotation` stays
  integer and the list-columns stay lists.
- The sign-test thresholds reproduce 5/5, 6/6, 7/7, 7/8, 8/9 and 9/10 at p <= 0.05.
  Separation uses `>= 90` circularly.
- Duplicate (`film_roll`, `frame_number`) keys would collide on output filenames. The
  catalogue cache has **0** of them across 1,670,471 rows, so this is not reachable from the
  documented source.
- `terra::intersect()` of touching or disjoint extents returns NULL, which is handled. A
  sliver extent narrower than 25 m builds a 1-column template rather than erroring
  (terra 1.9.50).

Note, outside the reviewed diff: while this review ran, uncommitted edits appeared in
`R/fly_bearing.R` (leg-end backward bearing, fly#87), `tests/testthat/test-fly_bearing.R`
and the `split()` loop in `fly_rotation_legs()`. They were not reviewed here.
