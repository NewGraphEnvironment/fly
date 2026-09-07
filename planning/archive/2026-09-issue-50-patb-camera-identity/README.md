## Outcome

A digital frame with no `camera_calibration_url` used to get no footprint at all without a
DEM — `fly_footprint()` recorded `inferred_format` and returned an empty geometry, because
sensor width can be inferred from focal length and pixel count cannot. The province names
the camera elsewhere: in the per-frame PAT-B georeferencing files the catalogue links
through `patb_georef_url`. New exported `fly_camera_patb()` reads them; `fly_camera_format()`
resolves the identity against the shipped table on a third route, between the calibration
URL and the focal-length fallback.

The issue reasoned from 207 frames in one AOI. The population is **41,249**, across four
years, seven archives and three schemas, and **22,366 of them now resolve**. The rest are
refused with a reason that travels in `width_source` rather than guessed at.

Four things had to be measured rather than reasoned, and each changed the design. The
serial index runs two passes (`report_serial`, then `key`) because a union makes serial
`20814295` ambiguous between four UltraCam Eagles and the 2018 body the catalogue files
under the same number — 14,717 frames. Tokens are split on non-digits, and the `_YYYY`
suffix comes off keys first, or token `2014` reaches two rows that *agree* and any
four-digit identity equal to 2014 resolves confidently to an Eagle. A serial that is
present but unknown **refuses**, because one published archive labels both its cameras
`UltraCam XP` and one of them is a `UC-SX` UltraCam X — reading the name there would size
1,790 frames 20% wide. And the catalogue's own `ground_sample_distance` is **0** for all
24,742 frames of 2011–2012, so resolving the camera alone would have left the issue's own
headline case unsizeable; the PAT-B file supplies it.

`camera_formats.csv` shipped `70912643_2015` mislabelled `UltraCamXp` when its serial and
dimensions are an UltraCam X. Only the label was wrong and nothing joined on it, which is
why it survived — this release makes it a join key, so it was fixed in the generator too.

One of the issue's two reported data defects was disproved: the `20814295` / `22814295` gap
is the catalogue's own filing, not a typo, and is the reason the index must read both
columns.

## Measurement

**Population** — 41,249 digital frames with a PAT-B file and no calibration; 22,366 resolve
(4,822 UltraCam Xp, 2,827 UltraCam X, 14,717 UltraCam Eagle) and 18,883 are refused
(11,826 an unknown DMC serial, 5,267 a 404 archive, 1,790 an unknown UltraCam serial).

**Footprints, live** — 5,193 m for the Xp, 4,329 m for the X, 5,002 m for the Eagle. The
5,193 m reproduces the issue's own figure exactly. A 636-frame live sample sized 372 and
refused the rest with a named reason.

**What leaving the DEM route costs a caller** — measured against the exterior orientation
the province publishes per frame, over every row of the three archives: 5,193 against
5,220 m (Xp), 4,329 against 4,337 m (X), 5,002 against 5,000 m (Eagle). Ratios 0.995,
0.998, 1.001, so **at most 0.5%**, and slightly narrow rather than wide.

That last number is the wrong turn worth keeping. Three shipped artifacts first carried
"4,329 m against 4,073 m before, where exterior orientation gives 4,066 m … the implied GSD
is 32.1 cm" — two halves of one sentence that cannot both be true, since `14430 × 0.321` is
4,633 m. Both figures were inherited from an AOI subset in the issue body, and the 32.1 cm
came from the **first row** of one archive whose median is 30.1. Review round 3 caught the
self-contradiction; the population measurement replaced both. `findings.md` records it.

**Delivered thumbnail orientation** for the three newly reachable cameras — 784 × 1200
(Xp), 784 × 1200 (X), 818 × 1251 (Eagle), all portrait, matching their shipped aspects to
0.2%. `fly_georef()`'s aspect gate had only ever been measured on the two cameras in the
bundled fixture, so without this a newly sized frame could have been skipped with no way to
tell a correct refusal from a wrong sensor.

**Review** — a concurrent plan review (22 findings) plus four `/code-check` rounds
(8 findings, 4 of them correctness bugs). Round 3 named the mechanism behind all of them:
*two states that need different responses are given one representation, while the fact that
separates them is already computed and unread* — `match()` treating `NA` as a value, a tie
set read as its first element, a data claim gated on a verbosity flag, "unreadable" and
"empty" collapsed into `list()`, `file.exists()` standing in for `file.size()`. Round 4 then
found that same mechanism **inside round 3's own fix**: a `warning =` handler on
`read.csv()` discarded a table that had parsed, so any archive of 1–4 rows without a
trailing newline resolved zero frames and blamed the file. Every guard was proven by
restoring its defect and watching the test go red.

## Evidence

Live measurement scripts and cached archives:
`/private/tmp/.../scratchpad/p50/` — `probe_years.R` (population), `probe_resolve.R`
(schemas), `validate_live.R` (end-to-end), `dem_residual.R` (the DEM comparison),
`thumbs.R` (delivered orientation). Not committed — they read the live catalogue and are
reproducible from `findings.md`, which carries every number they produced.

Committed: `inst/testdata/patb/` holds trimmed copies of all three schemas plus the
province's own 404 body, so the suite is offline.

Closed by: PR #55 — commits `0ba388f`, `64adb17`, `93dcf33`, `da3cf4d`, `bdca92b`.
Follow-up filed as fly#54 (a 110 km DEM footprint on two 2003 film frames).
