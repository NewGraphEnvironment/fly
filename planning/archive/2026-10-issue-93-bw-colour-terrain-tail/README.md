## Outcome

Some BW/colour film frames have a catalogued height in band above sea level that leaves the #54 band only over
the ground. No roll-table stratum held them, so with a DEM they were drawn at nominal scale.

`data-raw/height_measure-terrain_tail.R` now censuses them. A coarse MRDEM picture with a margin held to every
frame read picks the frames read exactly by the sweep's own instrument, and three controls guard it. The
generator settles them under fly#91's `terrain` tail with #72's rule unchanged.

Amendment A2 is pre-registered and changes the order, not the rule. It evaluates the spacing condition first,
and excludes only roll-heights the rule could never accept. Pages for the rest were transcribed blind by six
transcribers, each with a control page, and consolidated page by page. 60 BW/colour roll-heights (1,344 frames)
are now tabled at factor 1.

Four code-check rounds each found something real.
- Round 1 found a gap in A2's bound.
- Round 2 found a defect inside round 1's fix. Six pages that fix had sent to the logbook were never read,
  because `ls --color` defeated an anchored grep, and they shipped as "no page".
- Round 3 named the mechanism: "no transcribed row reaches these frames" was encoded as "no page". A fifth
  frame state now separates the two, and it corrected two false reasons that predate this branch.
- Round 4's enumeration ended the loop: all 504 absence reasons, in every tail, are true against
  `FLIGHT_LOG_URL`.

Spawned fly#95: 374 frames under terrain at or above the aircraft, and the 176 roll-heights where nominal
fits, as a possible height above ground.

## Measurement

**Census.**
- 1,389,968 usable BW/colour frames are in band above sea level, and 18,747 were read exactly. **4,773 frames
  on 298 roll-heights / 216 rolls** fall below the band. The issue's estimate from 12 draws was ~7,000
  (3,500-11,900); 374 more sit at r <= 0.
- **Coarse-vs-exact error.** Max 111.8 m on the sweep, but 142.7 m on the frames read. So the margin the sweep
  alone gave (223.6 m) was raised to 285.4 m by the loop. Its smallest slack was 217 m.
- **Controls.** 0 out-of-band frames among 1,000 read past the prefilter, and the sweep reproduced to 0.05 m.

**A2, over 300 terrain roll-heights.**

| outcome | roll-heights | frames |
|---|---|---|
| spacing fits nominal | 176 | 2,380 |
| cannot fit the catalogued height | 32 | 472 |
| to the logbook | 92 | 1,952 |

The first version said 35 cannot fit; three moved to the logbook after round 1.

**Verdict.**
- 62 terrain rows tabled (1,375 frames). On them `r` is 0.313-0.619, median 0.536, so these frames were drawn
  at about twice the width the spacing supports. Overlap at the logbook height is 0.562-0.773.
- 238 excluded, each with the reason that fired.
- No tabled row or earlier verdict moved. Two earlier excluded rows were reworded from a false "no page".

**Logbook read.**
- 182 pages on 60 rolls: 1,442 literal lines, consolidated to 421 rows.
- Six control pages agree on height and lens. One covers a narrower range under strict consolidation.

## Evidence

`planning/archive/2026-10-issue-93-bw-colour-terrain-tail/run_*.log`; raw transcription in `transcription/`;
review rounds `review-*.md`.

Closed by: PR for branch 93-bw-colour-frames-out-of-the-height-band
