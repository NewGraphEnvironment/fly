# fly#58 — Measure what a partially DEM-covered footprint costs

**Outcome:** the cost of partial DEM coverage is measured and ships as an artifact the
suite recomputes; `fly_dem_coverage_min()` stays at 0.95 with a measured justification
replacing the inherited one; no fallback floor was added; and one new reported column,
`dem_elev_sd`, ships because coverage alone cannot separate the frames inside a band.
Released as 0.14.0.

## Measurement

The error is exactly the elevation bias over the height above ground — realised width
error equals `Δelev / height_agl` to **1.6e-13** over 10,248 runs — so the pipeline adds
nothing of its own and the result transfers past this package.

Against MRDEM-30, the DEM the package documents as its default, partial coverage is all
but absent: **66 of 1,437,147** DEM-eligible film frames sit under 0.95 (0.005%), **0** of
223,667 digital frames, and **0 of 2,975** randomly drawn controls. The issue's own figure
— 18 of 416 from the fly#50 run — does not reproduce; the likely explanation is a DEM
cropped to that run's AOI, which is inference and is recorded as such. So the frequency is
not a property of the catalogue at all, and the decision rests on cost rather than rate.

The worst linear error at or above 0.95 coverage is **0.794%**, still 0.794% at 0.94, and
first passes 1% at 0.92. One percent of width is about two percent of area, which is the
per-corner ray-casting the model defers — so 0.95 is very nearly where a truncated frame's
worst case stops being cheaper than an error already accepted in every frame.

No floor, by the rule fixed before the numbers existed: no coverage band exists where the
DEM route is worse than nominal scale in the median. Below 20% coverage it is still better
by nearly four times.

`dem_elev_sd` ships because at a fixed coverage the error spans **13 to 52 times**, and
frames above their band's median spread sit **2.3 to 4.1 times** further out.

## Evidence

- `inst/extdata/dem_coverage_{sweep,targets,population}.csv` — 11,520 runs, 240 references,
  the binned population. `data-raw/dem_calibrate-coverage_error.R` reproduces all of it
  from public data (BC Data Catalogue + MRDEM-30)
- `inst/notes/terrain-correction.md`, "What a partially covered footprint costs"
- `tests/testthat/test-fly_footprint_coverage.R` parses all eight of the note's tables and
  recomputes every cell at its printed precision; each reddens on a planted wrong value
- `review-round[1-4].md` — the four `/code-check` rounds

## What went wrong, and is worth reading

**Three consecutive review rounds each found a defect inside the previous round's fix.**
The mechanism, named in round 3: the binder set was built by walking the *test* and not the
*prose*, so the note's claims were a strict superset of the assertions and nothing
enumerated the difference. It is terminated by enumeration — the table count is now
asserted — not by a quiet round.

**A feasibility-probe figure reached the note as a measurement.** "A 0.30 target comes back
as 0.215 achieved" was the two-frame probe's parameterisation quoted as the sweep's. This
issue's own `findings.md` says those numbers must not reach the note; one did, and survived
two review rounds. Measured, a 0.30 share gives median achieved coverage 0.699.

**Two numbers were wrong in the direction that flattered the design that shipped** — the
within-band rho range and the count of bands where `covered_sd` wins. Both were the
justification for the column that was chosen, and neither had a producer line or a test.

**Each robustness arm computes its own reference.** The shipped table kept one row per
frame, so arm errors were measured against the native reference — `ref_n` 90,692 cells
against 101. Keyed on `(airp_id, arm)` now.

**`tolerance` in testthat is relative.** At 2e-2 a three-decimal published figure was
pinned only to ±2%; 12.529% would have survived drifting to 12.629%. Comparison is now at
each figure's printed precision.

Five harness defects are recorded in `findings.md`: a PSOCK worker environment missing
every helper, a resume filter that skipped nothing while the row count grew (so it looked
like progress), GDAL's 3,276 MB-per-process block cache, the master holding the 1.67M-row
catalogue for the whole run, and orphaned workers causing the next memory kill. Also two
GDAL driver-guess failures in the atomic-write idiom, and a `terra::distance()` measuring
the wrong direction and marking 99.999% of the catalogue as a candidate.

## Closing

Commits `2baee85`..`4df2a97` on `58-measure-what-a-partially-dem-covered-f`.
