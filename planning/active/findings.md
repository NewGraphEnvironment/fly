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

## Phase 1 — whole population, no DEM (2026-09-18)

Pulled by year: **1,670,471 frames, equal to the catalogue's own `numberMatched`**, no
duplicate `airp_id`. Data runs 1963-2024.

- Media: Film - BW 861,619; Film - Colour 581,360; Film - Colour IR 3,054; Film - BW IR
  771; **Digital - Colour 223,667**.
- **No digital frame is slipped.** Digital `flying_height` tops out at 7,513 m (99.9% at
  7,274), none above 10,000; 17 are NA or <= 0. So the absolute ceiling is a backstop with
  nothing in today's catalogue to catch, and no digital band is needed.
- Film: 1,446,804 frames, 1,440,972 with a usable scale, focal length and height (5,832 not).
- `ratio_asl = flying_height / (scale x focal_length)`, which bounds the DEM route's `r`
  from above since terrain only lowers it:

  | ratio_asl | frames |
  |---|---|
  | (0, 0.25] | 965 |
  | (0.25, 0.5] | 998 |
  | (0.5, 0.75] | 3,808 |
  | (0.75, 0.9] | 1,638 |
  | (0.9, 1.5] | 1,352,363 |
  | (1.5, 2] | 63,837 |
  | (2, 3] | 15,256 |
  | (3, 4] | 302 |
  | (4, 5] | 45 |
  | (5, 7] | 158 |
  | (7, 9] | 13 |
  | (9, 12] | 93 |
  | (12, 20] | 1,496 |
  | > 20 | 0 |

- **Slipped population (ratio_asl > 9): 1,589 frames on 13 rolls** — `bc5596` (1974, 8),
  `bc78065` (1978, 24), `bc78078` (1978, 15), `bc79027` (1979, 10), `bc79103` (1979, 24),
  `bcb98013` (1998, 1), `bcc00085` (2000, 236), `bcc03004` (232), `bcc03006` (178),
  `bcc03007` (231), `bcc03008` (179), `bcc03046` (234) (2003), `bcc05001` (2005, 217).
- **The low-altitude slip is real, so the absolute check alone would have missed it:**
  `bc78065` reads 4,115 m at 1:2000 (ratio 13.45) and `bc78078` 9,449 m at 1:6000
  (ratio 10.29) — both perfectly legal altitudes.
- Highest legitimate `flying_height` (ratio_asl <= 3): **14,630 m**; 99.99% at 13,716.
- Other catalogue errors, not the slip: `bc78122` (1:10000 at **83 mm**, ratio 5.1),
  `bc78146` (8,230 m at 1:10000, 5.4), `bcb92006` (6,300 m at 1:5000, 8.2), `bc5294`
  (180 frames, 5,944 m at 1:12000, 3.2). And a low family where the height is far too small
  for the scale — `bc79122` 640 m at 1:20000, `bc7280` 60 m at 1:16000, `bc7717` 1,676 m at
  1:12500 / 305 mm — about 7,400 frames under 0.9.

## Phase 1 — terrain under the deciding frames (MRDEM-30, 7,156 frames)

The bin table above counted every `Film - *` stock. `fly_footprint()` sizes only
`fly_film_media()` — BW and Colour — so the script's population is **1,442,979 film frames,
1,437,147 usable**; the shipped `flying_height_population.csv` is on that basis (the
slipped counts are identical: 93 + 1,496 = 1,589).

`r = (flying_height - mean terrain under the nominal footprint) / (scale x focal_length)` —
the number the guard computes.

- **Ordinary frames** (random 2,500 of ratio_asl <= 2): median 1.031, 2.5-97.5% 0.806-1.253,
  0.5-99.5% 0.582-1.358, max 1.989. **99.2% inside [1/1.6, 1.6].**
- **Least favourable legitimate frames** (600 of the 15,231 at ratio_asl 2-3): two masses —
  one at r ~ 1.0-1.3 (low flights over high ground, nothing wrong) and one at **r 1.8-2.3,
  209 of 223 of them recorded at 153 mm** — a 305 mm lens catalogued as 153, which the DEM
  route draws at twice its width and the nominal route gets right since it never reads
  `focal_length`. Trough between them at about 1.6-1.9. That is what set the upper edge.
- **Slipped (1,589 frames, 13 rolls, identified by ratio_asl > 9, not by the rule):** raw r
  10.01-15.83; **repaired r 0.800-1.316, median 1.050** — the same shape as the ordinary
  population, which is the independent confirmation of the factor. All inside the band.
- **Empty stretch between the populations: r 6.69 to 10.01.**
- **Repair fires on 0 of 2,733 sampled frames that are outside the band and not slipped.**
- **Rolls are partially slipped:** 1,208 frames sit on a slipped roll without being slipped,
  so the rule has to be per frame, never per roll.
- Ceiling: highest legitimate film height 14,630 m, digital 7,513 m, 0 of 223,667 digital
  frames above 16,000.

### Dead end kept: the slip also seems to run the other way, and is not repaired

1,962 frames read under half their nominal height. Multiplying by 10.76 brings 726 into
the band (`bc79122` 640 m at 1:20000, `bc7584`, `bc7675`, `bc81013` ...) — but multiplying
by **10** brings 729 (a dropped digit in a height in feet: 609 m is 2,000 ft), and for a
different set of rolls doubling brings 799 (305 recorded for 153: `bc80001`, `bcc162`,
`bc79209` sit at ratio_asl 0.500 exactly). The repaired spread is 0.63-1.6 and runs on past
2 and 3 with no gap, where the forward slip is 0.80-1.32 behind a gap six wide. Three
remedies the terrain cannot tell apart, so none is applied: these frames come back
`"implausible"` at nominal scale. Most were already falling back, since 588 of them have
terrain above the recorded height.

### Dead end kept: `mclapply`

See Errors. The first DEM run "completed (exit code 0)" with no output file.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `parallel::mclapply()` over `/vsicurl/` MRDEM: all 104 chunks died with "An irrecoverable exception occurred. R is aborting now", and the background wrapper still reported exit 0 | GDAL's curl handles do not survive a fork on macOS. PSOCK cluster (`parallel::makeCluster()` + `parLapply()`), opening the raster inside each worker; gate on the `DEM DONE` marker, not the exit code |
