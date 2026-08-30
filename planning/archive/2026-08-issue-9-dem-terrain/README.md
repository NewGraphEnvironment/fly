# Issue #9 — DEM-based terrain-adjusted footprints

`fly_footprint()` sized every frame from the reported nominal scale. Measurement on the
bundled Upper Bulkley AOI reframed the issue twice over: `FLYING_HEIGHT` turned out to be
metres **above sea level** rather than height above ground, and the resulting error is a
**datum offset** rather than the slope effect the issue described — reported scale
understates footprint area by a median 14%, ranging to 27%, and always in the same
direction, because the scale is referenced to an elevation above the valley floor.

Built the true-scale rectangle: size each frame from `flying_height - terrain elevation`,
sampled in two passes (centroid, then mean under the resulting rectangle — they differ by
up to 130 m on a 7.2 km frame). Geometry stays rectangular, so downstream consumers were
unaffected. Per-corner ray-casting measured ~2% against the 14% and was deferred.

DEM source is MRDEM-30, NRCan's 30 m bare-earth DTM, chosen over `elevatr` after a
head-to-head: the two agree to within 0.42 percentage points, so the choice rested on
MRDEM needing no dependency beyond `terra` and being the product `flooded` already uses.

Two problems surfaced that the issue did not name. `dem` had to be threaded through all six
internal `fly_footprint()` call sites or the correction was unreachable from every function
a user actually calls. And an NA or zero `focal_length` made the corrected half-side
non-finite, producing an **empty geometry while `footprint_terrain` claimed `"dem_agl"`** —
downstream that reads as an unresolved recording format and sends the user to `format_size`
for a metadata problem. Fixed by classifying on the computed half-side rather than its
inputs.

Deviated from the issue on one point: terrain went into a new `footprint_terrain` column
rather than into `footprint_basis` as suggested, because that column is already matched by
value downstream. Issue body edited to record it.

**Six rounds of adversarial review ran** (`review-round1.md` .. `review-round6.md`), after
the user corrected an instruction the session had wrongly taken as barring subagents. Every
round found a real defect in the previous round's fix — fifteen findings in total. The
recurring cause was one thing: the bundled fixture, a single 30 m EPSG:3005 DEM, could not
reach the failure modes. It cannot exercise a coarse grid, a geographic CRS, a truncating
extent, or a wide photo spread, so four successive coverage measures each passed their own
tests while wrong.

Rounds 1-5 found bugs in the code; round 6 found one only in a test — a timing assertion
(`expect_lt(elapsed, 10)`) guarding an allocation defect that runs in 1.0 s against the
fix's 0.18 s — and confirmed the implementation correct under execution. That change of
character is what convergence looked like.

Closed by PR (`Fixes #9`). Suite 176 pass / 0 fail; `R CMD check` 0 errors, 0 warnings,
2 pre-existing NOTEs; vignette rebuilds. Released 0.5.0.
Follow-up: #10 (tilt/roll), ray-cast footprints still open.
