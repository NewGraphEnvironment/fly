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

`/code-check`'s subagent rounds were not run — the session barred the Agent tool. Reviewed
against the checklist directly, which is what caught the empty-geometry bug.

Closed by PR (`Fixes #9`). Suite 176 pass / 0 fail; `R CMD check` 0 errors, 0 warnings,
2 pre-existing NOTEs; vignette rebuilds. Released 0.5.0.
Follow-up: #10 (tilt/roll), ray-cast footprints still open.
