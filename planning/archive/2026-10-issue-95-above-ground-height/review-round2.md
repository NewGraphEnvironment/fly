# Code-check round 2 (fly#95)

Reviewed HEAD 3b180f8. Both changed test files run green in an archive copy
(`test-fly_footprint_above_ground.R` 62 passed, `test-fly_footprint_terrain_tail.R` 62 passed, 0 failed, 0 skipped).
Round 1's three fixes hold: "where nominal fits" is carried in NEWS, CLAUDE.md and the note; 558 = 550
catalogue + 8 ambiguous; the logbook claim is now scoped to the 576 read frames.

## Findings

- **[severity: fragile — shipped claim with the wrong population]** NEWS.md:4, CLAUDE.md:409,
  inst/notes/terrain-correction.md:773-774. All three present 2,956 frames as the two groups'
  frames combined. NEWS: "fly#93 left 374 frames ... and 176 roll-heights ... Together they are 188 roll-heights
  and 2,956 frames." CLAUDE.md: "188 roll-heights (2,956 frames): fly#93's 374 frames at `r <= 0` plus the 176
  where A2 found nominal fits." Note: "with both groups' frames together: 188 roll-heights, 2,956 frames."

  The roll-height count is right: 16 `r <= 0` keys plus 176 A2(a) keys, sharing 4, makes 188. The frame count
  covers more than the two groups. Group 1 is 374 frames. Group 2 is the 2,380 frames A2 judged (this branch's own
  `findings.md`, "176 terrain roll-heights (2,380 frames)"), and 155 of the 374 sit on its keys. So the two
  groups together are **2,754** frames. The other **202** are census `r > 0` frames on the 8 keys an `r <= 0`
  frame reaches but A2 did not find nominal-fits. They belong to neither group: A2 gave those keys "spacing
  cannot fit the catalogued height within 2%" or "spacing rejects the logbook's height". The keys are
  `bc77026` 2042 (107 frames), `bc77070` 1158, `bc77087` 1158, `bc77072` 1829/1981, `bc5602` 1219, `bc5715` 732
  and `bcc325` 396. Check: 2,535 frames on A2(a) keys + (374 - 155) + 202 = 2,956.

  The pre-registered population ("every frame of that key in either census file") is what the code does, and
  that is fine. Only the prose turns the population of the keys into the two groups' frames.
  - **Fix:** say "188 roll-heights, and their 2,956 frames in the two census files", or name the 202.
  - **The test cannot catch this.** `test-fly_footprint_above_ground.R:211` pins only the string
    "188 roll-heights, 2,956 frames" and `nrow(fr)`, not the composition.

## Claims checked and found right (against the shipped CSVs, `data-raw/flying_height_logbooks.csv`, the logs)

**NEWS.md (development entry)**
- "No code change": the diff touches no `R/` files.
- "Every roll table is byte-identical": `flying_height_rolls*.csv` are not in the diff.
- "374 frames", "176 roll-heights" and "188 roll-heights" are right. "2,956 frames" is the finding above.
- "supports 1, undecided 126, refutes 61": matches the CSV and `run_rolls.log:352`.
- `bc5602` 1219 m: the page writes 4000 ft on frames 46-69, and the header is "TRUE HEIGHT (M¹/M.S.L.)".
- "576 logbook-read frames, 558": 550 catalogue + 8 ambiguous; 18 other; 0 ground_plus or ground_header.
- "Every frame here is in band above sea level ... under 1.6 times apart": `ratio_asl` ranges 0.628-1.593.
- "median 12% in width and up to 49%": 0.120 and 0.494 over the 126 undecided.
- "where nominal fits ... a median 0.028": 52 roll-heights, median 0.028.
- "nine roll-heights (157 of those 374 frames)": the nine keys are refutes with nominal not fitting. Every one
  carries `r <= 0` frames, and they sum to 157.

**CLAUDE.md**
- Architecture line: "374 frames at `r <= 0`" is right. The timing claim ("under a minute") has no recorded time
  in the logs, so it is unverified rather than wrong. Byte-identity is recorded by md5 in `progress.md`.
- "1 / 126 / 61", "`bc5602` 4,000 ft under M.S.L." and "576 ... 558 ... no page puts the ground under it" are
  right. "188 (2,956)" is the finding above.
- "`p_agl = 1 - (1 - p_nominal) / ratio_asl`": the test asserts the identity to 1e-9.
- "In band ... the ratio is under 1.6": right (see above).
- "up to 49%" and "median 0.028 ... where nominal fits": right.
- "the existing `factor != 1` branch, which already reaches `r <= 0` frames": `R/fly_footprint.R` gates the table
  on `out_of_band`, which includes `r <= 0`, not on `disputed`.
- "ambiguous with x2": on the 374 frames, (fh + elev) / fh runs 2.00-2.58, median 2.16.
- "Nine roll-heights (157 `r <= 0` frames)": right.

**inst/notes/terrain-correction.md, the fly#95 section and the two edited lines above it**
- "`fly_footprint()` draws at nominal with a warning": the `unusable` warning names terrain at or above the
  aircraft.
- "`bcc285` 1707 m carries 106 frames of the first and 39 of the second": 145 frames, 106 of them `r <= 0`.
- The spacing table (1/24/23, 126/1,562/174, 61/1,370/177) is right.
- `bc5602`: 0.631 and 0.510 against the window 0.557-0.780; 4,000 ft on all 24 frames; header M.S.L.
- "MRDEM puts the ground under 23 of those frames at 1,234 to 1,591 m": elev runs 1233.6-1591.4.
- "558 of 576" and the 550 / 8 / 18 / 0 table are right.
- "Over the 32 roll-heights with transcribed rows": 36 population roll-heights sit on rolls with transcribed rows.
  The other 4 are `bc5596` 2529, `bc82044` 2347, `bc87070` 3962 and `bcb98001` 948, and no row's frame range
  reaches their frames (unspanned). So 32 is right as "rows reaching them".
- "The headers say M.S.L. or name no datum; none names the ground": every row on these rolls is an
  M'/M¹/M.S.L.-type header except two blank-header rows on `bc5225` (frames 191-192), whose height was not
  interpreted.
- "On `bc5602`, `bc77026`, `bc77072` and `bc77087` the page's M.S.L. figure is below the ground under some
  frames": these are exactly the rolls with a page height <= elev: 23, 7, 3 and 38 frames, all under an M.S.L.
  header.
- "two readings ... exactly `ratio_asl` apart": right (the identity).
- "median 0.120, 0.352 at the 90th, at most 0.494; 494 of 1,562 more than 20%": right, and the test pins them.
- "52 refuted where nominal fits, median 0.028, 23 under 0.02": right.
- Frames-under-aircraft table 174 / 20 / 23 / 157: 20 = `bc5695` 16 + `bc79121` 4. The nine keys match.
- "about twice the height": 2.00-2.58 (see above).
- "fly#95 tested it (the next section), and these instruments cannot settle it": consistent.

**data-raw comments**
- `height_measure-terrain_tail.R` "every in-band frame under terrain at or above the aircraft (r <= 0)":
  `nonpos` is taken from `read`, which holds only frames in band above sea level. The stopifnot checks
  `nrow == sum(nonpos)`.
- `height_calibrate-lower_tail_rolls.R` Stage 3c: "only `supports` can table, so only its rolls go to the
  logbook" matches `agl_rolls`. The "two sides are exactly `ratio_asl` apart" claim matches the code.
- `height_calibrate-lower_tail_rolls.R` Stage 6: the relation definitions match the pre-registered rule. The
  "stops rather than tabling" claim matches the `if (any(av$tabled)) stop(...)`.

Not re-flagged (accepted): the note's rule text names only "in band as catalogued" for condition 4. The code
counts every key frame outside both census files, which also includes frames with no terrain under them.
Nothing tables, so this moves no number.
