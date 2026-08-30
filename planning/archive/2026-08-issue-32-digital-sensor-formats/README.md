# Issue #32 — sensor widths for digital frames

`fly_footprint()` marked every digital frame `unknown_format` with an empty geometry.
#30 made that gap honest without closing it: 223,667 of 1,670,471 frames province-wide,
so the package was quietly film-only for anything after ~2010.

Digital frames are now sized from their camera's sensor, read out of the calibration
reports the catalogue links to through `camera_calibration_url` and shipped as
`inst/extdata/camera_formats.csv` — 14 calibrations covering 169,688 frames, plus
focal-length fallback rows for frames carrying no calibration.

Two findings during exploration reshaped the work, both confirmed with the user before
implementation:

- **The catalogue's `SCALE` is not the true image scale for a digital frame.** Sizing
  from it gives 34% of true width; it is a derived nominal figure implying a ~12.5 um
  pixel pitch for every camera against real pitches of 3.9-12 um. Digital frames are
  sized as `pixel count x ground_sample_distance` instead, needing neither `scale` nor
  a DEM.
- **Sensors are not square** (1.10:1 to 1.80:1, widths 87.1-165.9 mm), so footprints
  became rectangles rotated onto the flight line via `fly_bearing()`. Film unchanged.

The numbers are parsed, never typed, and gated on five checks. Two caught real problems
before shipping: a camera whose catalogue metadata contradicts its own report (withheld),
and — via an independent second reading — that the focal-83 frames are a 53.9 mm
medium-format body, so the fallback that would have inferred a 104 mm UltraCam for them
is refused. That was a 93% error.

**What this issue is worth remembering for.** Three defects were found only by restoring
them: the rotation matrix was backwards, the orientation test was decoration (`%% 180`
discarded the sign it existed to catch), and the 2013 UltraCam report renders `20010` as
`2001O` and drops the micron sign, so `Pixel Size 5.200 m` reads as metres.

And code-check rounds 2 and 3 each found a defect **inside the previous round's fix**,
both with the same root cause: branching on `half_cross`, which is NA for every
camera-table row by construction. Round 2 — the DEM route unreachable for exactly the
frames it exists to serve. Round 3 — rotation never applied to those same frames. Asking
for the mechanism rather than more instances is what ended it: rotation is now decided
from the format's aspect ratio, known before any sizing route runs, and a structural
invariant sweep over 12 input shapes guards the reporting columns that had drifted.

Closed by PR (see `Fixes #32`). Suite 1162 pass / 0 fail / 0 warn.
Follow-up: #38 (georeferencing digital frames). Related: #30, #9.
