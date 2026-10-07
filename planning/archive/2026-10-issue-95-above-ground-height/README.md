## Outcome

fly#93 left two groups whose catalogued `flying_height` looked like a height above ground recorded as above sea
level: 374 frames under terrain at or above the aircraft, and 176 roll-heights where spacing fits nominal scale.
A rule was fixed before any per-roll-height number existed: spacing first, then the logbook. **Nothing tabled, and
the package is unchanged.**

The census now ships the 374 frames (`flying_height_terrain_nonpositive.csv`). The generator gained Stages 3c and
6, which write one verdict per roll-height (`flying_height_above_ground.csv`), and the suite recomputes the
spacing columns.

What was learned is that the instrument cannot settle the question. On a key, the overlap read as above ground is
`1 - (1 - p_nominal) / ratio_asl`, and in band above sea level the two readings are under 1.6x apart, which is
where #60 found spacing stops separating them. A plan review pointed this out after the run. So the result is
reported as "cannot settle", not "false". Nine roll-heights where spacing rejects nominal as well went to fly#97.

Four code-check rounds found 15 defects (3, 1, 6 and 5). All but one were prose of a single mechanism: a count
computed over one set, described as a neighbouring set (a scope dropped, a superset, or the fetch set instead of
the join set). The exception was a folded logbook state in code, which moved no row. In rounds 3 and 4 a defect sat
inside the previous round's fix. An enumeration of every numeric or universal sentence (96 of them) ended the
loop.

## Measurement

- **Population.** 188 roll-heights, judged on the 2,956 frames the two census files hold on them. The two groups
  are 2,754 of those frames; the other 202 sit on 8 keys that neither group holds.
- **Spacing**, window 0.557-0.780. It supports reading the height as above ground on 1 roll-height (24 frames),
  is undecided on 126 (1,562), and refutes it on 61 (1,370). No roll-height lacked an air base.
  - Undecided: the two readings differ by a median 12% in width, up to 49%.
  - Refutes: on the 52 roll-heights where nominal fits, they sit a median 0.028 outside the window, and 23 of them
    by under 0.02.
- **Logbook.**
  - `bc5602` 1219 m, the only `supports` roll-height, has 4,000 ft (the catalogue's own figure) under an M.S.L.
    header on all 24 frames, while MRDEM puts the ground at 1,234-1,591 m under 23 of them. It is excluded.
  - Transcribed pages exist for 26 of the 154 rolls. On the 576 frames they read: 558 carry the catalogue's
    figure, 18 carry neither, and 0 put the ground under it.
- **Frames under the aircraft.** 174 are on undecided roll-heights, 20 on refuted ones where nominal fits, 23 on
  `bc5602`, and 157 where neither reading fits (fly#97).
- **Byte-identity.** A census re-run from the ETag-keyed cache (8212c794) took 24 s and left both existing CSVs
  byte-identical. Every generator run left `flying_height_rolls.csv` and `_excluded.csv` byte-identical.
- **Wrong turns.**
  - The plan said a separate script; the measurement went into the generator, which already held the window, the
    air base and the logbook join.
  - The first Stage 6 run stopped on a `tapply()` 1-d array.
  - Prose defects are tabled in `findings.md`, "Code-check summary".

## Evidence

`planning/archive/2026-10-issue-95-above-ground-height/run_*.log`; review rounds `review-*.md`; the enumerated
claims `claims_enumerated.txt`.

Closed by: PR for branch 95-bw-colour-frames-whose-catalogued-height
