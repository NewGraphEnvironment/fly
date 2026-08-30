# Plan review — #32 (Plan agent, 2026-08-30)

Spawned after the PWF baseline, per `planning.md`. Read `fly_footprint.R` in full plus
every downstream consumer. Findings verified against the code before acting; the
verification result is recorded beside each.

## Blockers

**1. Sizing precedence is the reverse of what the code does.** `fly_footprint.R:417-427,479`
overwrites `half_side[corrected]` unconditionally whenever a DEM yields a usable AGL. A
digital frame sized by `px x GSD` arrives with `sized == TRUE`, so passing `dem` silently
switches its route — and every downstream consumer forwards `dem`. **Confirmed.** Fix:
gate `corrected` on `!gsd_sized`, and test that a digital frame is identical with and
without `dem`.

**2. `footprint_terrain` makes a false claim for `px x GSD` frames.** Line 391 labels any
non-NA half-side `"nominal_scale"`, documented as "sized from the reported scale" — the
exact claim the work promises never to make for a digital frame. **Confirmed.** Needs a
fifth value, plus honest `height_agl` (NA) and `dem_coverage` (NA) for that route.

**3. Rotation must be applied inside the two-pass DEM sampler, not just to the output.**
Lines 410-411 build both sampling windows through `fly_rectangles()`. Rotating only the
returned geometry makes `dem_coverage` describe an unrotated rectangle — the
returned/measured mismatch `test-fly_footprint.R:614-649` exists to catch. **Confirmed.**

**4. `GROUND_SAMPLE_DISTANCE` units.** Reviewer flagged that findings.md is ambiguous
between metres and centimetres and that Phase 4 writes `px x GSD` with no conversion.
**Verified: the field is CENTIMETRES.** UltraCam Eagle, GSD 30, 20010 px -> 20010 x 0.30 m
= 6003 m, which matches `104.052 mm x (AGL/focal)` = 6070 m. In metres it would be 100x.
`mixed_media_fixture()` sets `0.10`, a metres assumption, and the shipped GeoPackage
column is `int` and all-NA — so nothing currently exercises it. Convert explicitly and
assert the unit.

## Gaps

**5. `GSD == 0` builds a degenerate polygon, not an empty one.** `fly_rectangles()` guards
`is.finite(w)`; zero is finite, so a five-identical-vertex POLYGON passes `st_is_empty()`
and is invisible to `fly_warn_unsized()`. **Confirmed, and reachable:** `dmc100039_2006`
has GSD 0 on all 4,052 frames. Add `w > 0`.

**6. The focal-length fallback silently resolves `mixed_media_fixture()` row 4** (focal
100, no calibration URL), breaking four existing assertions at `test-fly_footprint.R:52,
61, 70, 85`. **Confirmed.** Gate the fallback on digital `media`, and update those tests
deliberately rather than discovering them red.

**7. `fly_georef()` applies its own bearing rotation to footprint corners**
(`fly_georef.R:199-244, 300-304`), calibrated against axis-aligned squares. A pre-rotated
non-square footprint would be double-corrected, and a 90-degree error maps landscape onto
portrait. **Confirmed.** Needs an explicit decision, not silence.

**8. `fly_bearing()` stops rather than returning NA** when `film_roll`/`frame_number` are
absent (`fly_bearing.R:31-34`), and takes the cross-track jump as the bearing at each
flight-line turn. **Confirmed.** Guard in `fly_footprint()`; document the turn case.

## Acceptance

**9. The proposed rotation tests cannot fail the way that matters.** Area is invariant
under *every* rotation and a 90-degree bbox swap tests the mechanism, not the angle — so a
long-axis/short-axis transposition and a sign-flipped azimuth both pass. **Agreed.**
Discriminating assertion: the long axis must be perpendicular to `bearing`, and
consecutive same-roll frames must show along-track overlap (~60%) not side-lap (~30%).

**10. "`SCALE` is never used for a digital frame" contradicts keeping `format_size`.**
`test-fly_footprint.R:89-98` pins `format_size` sizing a digital frame from `SCALE`.
**Confirmed.** Restate as "never used for a frame `fly` sized itself". Also: `format_size`
is a named numeric vector and cannot carry two dimensions per key without a type change.

## Non-finding (recorded so it is not re-litigated)

Rotation does **not** break the bounded-allocation invariant. `fly_dem_grid()` sizes to one
footprint's extent; a rotated `w x h` bbox peaks at `(w+h)^2/2`, about 2.2x unrotated for
aspect 1.8 — bounded and per-frame, nowhere near the union-grid defect. Centre-to-corner
distance is invariant under rotation, so the existing DEM buffer rule already covers it.
