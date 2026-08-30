# fly#38 — Georeference digital frames

Closed by PR against `main`, v0.7.0. `fly_georef()` had excluded every non-square
footprint, so the digital frames #32 had just sized could not be georeferenced.

The corner mapping is **rotation 270** — the top-left pixel maps to the footprint ring's
rear-left corner. The issue assumed establishing it needed licence-restricted orthophoto
imagery; it did not. The catalogue publishes per-frame exterior orientation through
`patb_georef_url`, a column `fly_fetch()` already supported, and consecutive frames
overlap enough to check each other. Three public routes agree, and the derivation ships
in `data-raw/georef_calibrate-corner_mapping.R` with the record in
`inst/notes/georeferencing.md`.

Two things worth carrying forward, both in `progress.md` in full:

- **The most convincing measurement was the wrong one.** Read naively the exterior
  orientation puts the Leica DMC II at rotation 90, on 97.6% agreement across four pooled
  projects. That camera's project flies east and west only, so its own data separates the
  rigid-mount and reflected-frame hypotheses at 97.6% against 98.4% — not at all.
- **Every one of three code-check rounds found a defect inside the previous round's
  fix**, and the suite was green throughout. Round 1 caught a guard that refused
  full-resolution film scans; round 2 caught the shape gate that fixed it switching the
  guard off for the exact case it existed for, plus an incomplete factor normalisation;
  round 3 caught the replacement tolerance being 0.4% too loose, guarded by a test that
  asserted against the most eccentric camera instead of the least. Convergence never
  arrived within three rounds — the reviews are kept beside this README.
