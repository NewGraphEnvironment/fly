# Findings — fly_footprint(dem =) returned a 110 km footprint for two 2003 film frames (#54)

## Issue context

## Problem

Two film frames of 2003 came back from `fly_footprint(dem = ...)` at **110,834 m**
across, against **8,022 m** for the same frames with no DEM — a 13.8x blow-up, where
the correction as a whole is documented as moving area by a median 14%.

Measured during the fly#50 run over the province-wide digital population; the two
frames were film, so they were not the subject of that work and were not chased
further. Recorded here rather than lost.

The same run reported a second thing worth separating out: **18 of 416 DEM-corrected
frames fell under 95% `dem_coverage`, one as low as 47%**, and a partially covered
footprint takes the **mean elevation of the covered part**. That is documented
behaviour, not a defect, but it is a silent one — a frame half off the edge of the DEM
is sized from the half that happens to be on it, and nothing in the output says the
number is weaker than its neighbours'.

## Where to look

`fly_footprint()` sizes a DEM frame as `format width x (flying_height - elevation) /
focal length`. A 13.8x width means `(flying_height - elevation)` came back about 13.8x
too large, so the candidates are:

- `flying_height` wrong or in the wrong units on those rows — it is metres **above sea
  level**, and fly#9 established that reading it as height above ground is exactly the
  error the DEM route exists to fix;
- the sampled elevation coming back near zero, or negative, over ground that is not;
- `focal_length` wrong or zero for a 2003 film frame;
- the two-pass resize diverging rather than converging, which the second pass is
  supposed to make impossible (it moves area by at most 0.53% on measured data).

An implausible result is reachable from any of them and none is currently guarded: the
function will happily return a 110 km footprint. Whatever the cause turns out to be,
**a plausibility bound on `height_agl` is probably the fix that generalises** — the
same shape as check D in `data-raw/make_camera_formats.R`, which catches a unit slip by
refusing a sensor that is not a physically possible size.

## Reproducing

Not yet reproduced in isolation — the frames were two rows of a large batch. First
step is to pull 2003 film frames with a DEM over them and find the pair, then print
`flying_height`, `focal_length`, `height_agl` and `dem_coverage` for them beside a
neighbouring frame that behaved.

## Notes

`inst/notes/terrain-correction.md` is required reading before changing anything under
`dem`: four successive `dem_coverage` implementations passed 200+ tests while wrong,
every time because the bundled DEM cannot reach the failure mode. Test at two
resolutions, with anisotropic cells, in a geographic CRS, with a truncating extent, and
with frames far apart.


## Plan-mode exploration (2026-09-18, read-only catalogue queries)

- 2003 province-wide: 13,168 frames, all film (1,388 BW, 11,780 colour), `focal_length`
  only 153 (5,900) or 305 (7,268). `flying_height / (scale x focal_length)`: median 1.29,
  99th percentile 15.7, max 15.8. 1,054 frames of 2003 at ratio > 4.
- All years, `FLYING_HEIGHT > 15000`: 1,550 frames, minimum ratio 10.05. Between 12,000
  and 15,000 m the frames are legitimate 1:60000-1:90000 flights at ratio ~1.2
  (e.g. `bc5342` 1:90000 at 13,716 m, `bc5344` at 14,630 m).
- Rolls seen in a 150-frame sample: `bc5596` (1974, 1:12000, 26,212 m), `bc79103` (1979,
  1:10000, 21,946 m), `bcc00085` (2000, 1:15000 / 305 mm, 56,390 m), `bcc03004`,
  `bcc03006`, `bcc03007`, `bcc03008`, `bcc03046` (2003, 71.5-75.1 km), `bcc05001` (2005,
  62,500 m). `bc79027` (1979, 1:13000, 19,995 m) appeared in the > 12,000 listing.
- Against MRDEM elevation at the centroid (n = 150), residual to `elev + scale x focal`:
  `/10.7639` gives 0% -736, 10% -236, 50% +253, 90% +1049, 100% +1501 m;
  `x0.3048` gives +4,491 .. +17,719 m. So stored = true metres x 3.28084^2.
- Not yet measured: whether a slipped roll hides below 15 km ASL; whether the mirror
  defect exists; whether any digital frame is affected. Phase 1.

## Errors Encountered

| Error | Resolution |
|-------|------------|
