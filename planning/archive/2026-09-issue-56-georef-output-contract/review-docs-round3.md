# Docs review, round 3 (#56, staged diff after cf47430)

## The mechanism

Rounds 1 and 2 and the failures below share one shape: **a claim keeps the result and drops
the condition it was measured under.** The instrument fixes something (one bearing, one GDAL
build on one OS, one image geometry, one source band layout) and the prose states the
result as a property of the output contract. Round 2 dropped the bearing. This round finds
three more conditions dropped the same way: the **platform** ("on every platform", measured
on macOS 3.8.5 only, CI never run on this branch), the **pixel geometry** ("exact for an
axis-aligned warp", true only where image aspect equals footprint aspect, which the 1250 x
1250 thumbnails and `measure_output()`'s `dm/2` ring satisfy by construction), and the
**GDAL build** ("silently", when two of the three builds named in the diff print the
message).

Probes were run in a scratch copy of the repo (`fly3`) on sf's GDAL 3.8.5; nothing in the
repo was edited apart from this file.

## Enumeration

| # | claim (location) | producer | scope stated vs scope supported | verdict |
|---|---|---|---|---|
| 1 | Gray 2 bands, RGB 4, "on every platform" (NEWS l.3 "Band count is now one number on every platform"; CLAUDE.md Key Decision; roxygen l.131-132; test asserts it unconditionally) | test-fly_georef_mask.R on macOS/3.8.5. `gh run list --branch 56-…` returns `[]` and the branch has no origin ref, so no ubuntu or Windows run exists | every platform vs one platform. The Windows 2-band result under the old options (#68) was never explained, so what that build does with `-srcalpha -dstalpha` is unknown | **FAIL (F1)** |
| 2 | No NoData value on any output (NEWS, CLAUDE.md "no NoData", note) | probe: Byte 1/3 band and UInt16 1 band, with and without `-srcnodata 0`, all without `NoData` | srcnodata leg included, supported on 3.8.5 | pass |
| 3 | Alpha opaque = datatype max, 255 Byte / 65535 UInt16 (NEWS, CLAUDE.md, note) | tests l.297-321 (UInt16); probe gives 65535 on UInt16 1 and 3 band | 1-3 band sources pass. A 4-band source gives alpha 0/100 (source band 4 taken as alpha), and a 2-band source gives 3 bands | pass for gray/RGB; **edge (F6)** |
| 4 | 161 of 182 axis-aligned, 242,439 px, median 47, max 3.6% (NEWS, CLAUDE.md, note table, findings) | log "warp axis-aligned" block | the 182 calibration thumbnails, 3.8.5 | pass |
| 5 | 41 of 182 at 30 deg, 12,682 px, median 13, max 0.26% (same places) | log "30 degrees" block | same | pass |
| 6 | 0 deleted on the default path (note "None was deleted on this, the default, path") | log: `true 0 deleted … frames 0` at both bearings | the two bearings, masked, no srcnodata | pass |
| 7 | "**0 pixels deleted at any bearing**" (findings.md) | same log | two bearings, not any | **FAIL, low (F5)** |
| 8 | Axis-aligned count "identical to"/"equals" the source count (findings, script header 1b) | log 242,439 = 242,439 | the 182 thumbnails | pass |
| 9 | Source-side count "exact for an axis-aligned warp"; axis-aligned "lands output cells on source pixels … every opaque 0 is lost" (note new para; script header 1 and `measure_output()` comment; CLAUDE.md "wrong for every bearingless frame") | the 182 thumbnails, all 1250 x 1250 on square footprints, and `measure_output()` sizes the ring at `dm/2`, i.e. isotropic 1 m pixels by construction | every axis-aligned warp vs isotropic-pixel warps only. Probe: 200 lone zeros, axis-aligned, `fly_georef_warp_opts(1, NULL, FALSE)`: 200 x 200 on a square footprint keeps **200/200**; 200 x 188 on the same square footprint keeps **0/200** | **FAIL (F2)** |
| 10 | Rotated loss is lower "because resampling mixes a lone 0 with its neighbours" (NEWS, note) | mechanism, consistent with log and probe | general | pass |
| 11 | Worst frames all roll bcb94081 (NEWS, note, findings) | log top-5, both bearings | calibration set | pass |
| 12 | GDAL rewrote 0 as 1 "silently" (NEWS l.3, CLAUDE.md "GDAL silently **rewrote**") | findings synthetic check: silent on sf 3.8.5; Homebrew 3.13 CLI prints it; the Windows runner printed it (#68) | unscoped vs one build of three. Roxygen, note and test comments scope it to 3.8.5 correctly | **FAIL, low (F4)** |
| 13 | Deleted instead where `srcnodata = "0"` was given (NEWS, roxygen, note, tests) | findings: `-srcnodata 0 -dstnodata 0` gives nodata on 3.8.5 | pre-0.19.0 unmasked path only, which is the only one that could carry it | pass |
| 14 | Windows gave 2 bands masked, 1 on ubuntu/macOS (NEWS, CLAUDE.md, note) | #68 CI run | as stated | pass |
| 15 | "Which count a caller got depended on the GDAL build, not on the frame" (note) | #68: three runners that differ in OS and GDAL together | build-vs-OS is inference. Harmless, and it is the natural reading | pass (inference) |
| 16 | `else if`: `-srcnodata` never beside `-srcalpha` (NEWS, CLAUDE.md, note table, roxygen) | R/fly_georef.R:549-554; tests l.79-87 | code | pass |
| 17 | "srcnodata reaches a frame only when fly_mask() declined it" (NEWS, CLAUDE.md) | code | under `mask = "border"`, which the NEWS heading names. Under `mask = "none"` it reaches every frame | pass (scoped by heading) |
| 18 | A decline with no srcnodata warns (NEWS, CLAUDE.md, note table) | R/fly_georef.R:489-496 | code | pass |
| 19 | "Declined" = `masked = FALSE`; an error fails the frame (note) | georef_one: `fly_mask_one()` is called without tryCatch | code | pass |
| 20 | Mask declined 0 of 264 and 0 of 10,105 (NEWS, CLAUDE.md, note, roxygen) | log, both populations | public thumbnails | pass |
| 21 | Fallback reaches non-Byte (non-8-bit) scans (NEWS, CLAUDE.md, note) | R/fly_mask.R:234-240 refuses non-Byte | code | pass |
| 22 | "Every thumbnail is 8-bit" (note) | JPEG thumbnails; 0 declines | population | pass |
| 23 | 121-px deletion with both options (note, roxygen) | pre-existing synthetic measurement | unchanged | pass |
| 24 | Two distinct output alpha values, 0 and 255, on a rotated warp (note) | note l.288, the existing section | Byte masked | pass |
| 25 | Warped band 2 is `Alpha` because `-dstalpha` creates it (note) | probe: `ColorInterp=Alpha` on 1-band Byte and UInt16 | pass | pass |
| 26 | COG writer loses alpha interp without `alpha="YES"`; round-trip check refuses (note) | stac_airphoto_bc#36 body, measured with its `write_cog()` | as stated | pass, but see F3 |
| 27 | VRT GCP step saves ~350 MB vs 700 MB per frame (note) | pre-existing | unchanged | not re-checked |
| 28 | Calibration script now prints the post-#56 band count (script comment) | `fly_georef_warp_opts(nb0, NULL, masked = TRUE)`; nb0 is the source count, which is the function's contract; the script runs `load_all()` | code | pass |
| 29 | Script "refuses to report if any frame errored" (CLAUDE.md Architecture) | `n_err` stop precedes CSV and report; an output-pass error aborts parLapplyLB | code: holds | pass, but see F7 |
| 30 | Public repo: no private sibling named | grep of diff: only "the private sibling" | pass | pass |

## Findings

- **[medium] NEWS.md:3, CLAUDE.md (Key Decision "on every platform"), R/fly_georef.R:131-132, tests/testthat/test-fly_georef_mask.R (unconditional assertion)**: "Band count is now one number on every platform" has no producer. The branch is unpushed (`gh run list --branch 56-georef-output-contract-a-real-alpha-band` returns `[]`, and there is no origin ref), so only macOS on sf's GDAL 3.8.5 has run it. This is the #68 error repeated. The old claim was measured on macOS and stated for all platforms, and the Windows runner's 2-band result under `-srcalpha -dstnodata 0` was **never explained**. So nothing establishes what that build gives under `-srcalpha -dstalpha`, and 2 or 3 bands are both possible. Fix: let the three-platform CI run before stating it, or scope it to "on macOS/GDAL 3.8.5; CI decides the rest". The note's own header ("on sf's GDAL 3.8.5") already scopes it correctly.

- **[medium] inst/notes/border-masking.md (new para: "an axis-aligned warp lands output cells on source pixels … So the source-side count … is exact for an axis-aligned warp"), data-raw/mask_measure-interior_zeros.R header item 1 ("It is exact for an axis-aligned warp") and the `measure_output()` comment ("every opaque 0 is lost"), CLAUDE.md ("wrong for every bearingless frame")**: output cells land on source pixels only when the image's aspect matches the footprint's, so the source pixels are isotropic. The measurement satisfies that by construction on two counts. Every calibration thumbnail is 1250 x 1250 on a square film footprint, and `measure_output()` sizes the ring at `dm[1]/2, dm[2]/2`, which is 1 m pixels whatever the image. A full-resolution 9-inch scan at 9600 x 9000 on a square footprint is the note's own example of a production shape, and it does not satisfy it. Probe (scratch copy, GDAL 3.8.5, `fly_georef_warp_opts(1L, NULL, FALSE)`, axis-aligned, 200 isolated zeros): a 200 x 200 image on a square footprint keeps **200 of 200** as opaque 0, and a 200 x 188 image on the same footprint keeps **0 of 200**. So "axis-aligned" does not by itself mean "exact, every 0 lost". The condition is isotropic source pixels. The numbers (161/182 and so on) stand for their stated population. The general sentences need "on a frame whose pixels map square to the ground (every thumbnail here)", or the equivalent.

- **[low] stac_airphoto_bc#36 body (cited from NEWS.md:3 and the note as the downstream spec)**: it still carries the claims this round refuted. It says `-dstnodata 0` "wrote genuine black inside the frame as nodata" (the output measurement shows 0 deleted and all of it rewritten as 1), gives "up to 3.5%" (a source-side figure; the output figure is 3.6%), and says "On Windows it also shifted real zeros to 1" (3.8.5 on macOS does it too, silently). The staged fix repaired fly's copies of the sentence and not this one, even though the issue is read as the spec for the republish. Edit the body.

- **[low] NEWS.md:3 ("GDAL silently rewrote"), CLAUDE.md ("GDAL silently **rewrote** genuine black as 1")**: "silently" holds on one of the three builds the diff itself names. findings.md records that Homebrew's GDAL 3.13 CLI prints the message and the Windows runner printed it (#68). Silent on sf's 3.8.5 only. The roxygen, the note and the test comments already scope it that way.

- **[low] planning/active/findings.md (+"**0 pixels deleted at any bearing.**")**: the producer measured two bearings, axis-aligned and 30 degrees. Say "at either bearing measured". This is the same class as round 2's finding, but on a durable-record file.

- **[low] NEWS.md:3 ("A consumer … must now read the last band: 0 is fill, and the opaque value is the datatype's maximum")**: this holds for 1- and 3-band sources, and I verified it on Byte and UInt16. An unmasked 4-band Byte source is different: GDAL takes the source's band 4 as alpha and passes its values through. The probe gave alpha 0/100 with no appended band. A 2-band source comes out as 3 bands. The note correctly scopes its sentence to "a Byte grayscale or RGB source". Whether any catalogue scan is 4-band is unknown, so this is low, but the NEWS reading instruction is stated for every output.

- **[low] data-raw/mask_measure-interior_zeros.R, code**: the check ordering is correct in effect but runs in the wrong order, and it can lose the expensive pass.
  - (a) `tryCatch(finally = stopCluster)` wraps only the output pass. `clusterEvalQ(load_all)` and the source-pass `parLapplyLB` sit outside it. The source pass's per-frame `tryCatch` does not catch a cluster-level error such as a `load_all` failure or a worker dying, and on that path the PSOCK workers are never stopped (CLAUDE.md: PSOCK workers outlive their master). Open the `tryCatch` immediately after `makePSOCKcluster()`.
  - (b) `n_err` is checked **after** the output pass. A doomed run (for example, every frame "error" from the missing-closure case) still spends 2 x 182 warps before it refuses, and frames that errored at source are silently dropped from `gray_calib` because `bands` is NA. Check `n_err` first.
  - (c) `measure_output()` has no per-frame `tryCatch`, so one bad frame aborts `parLapplyLB` before `write.csv`. That discards the whole 10,105-frame source pass it would have written.

  The report loop reads the right columns: `lost_out + shifted_out` over `frame_out`, the identity check against `zero_new`, and NA rows from declined frames are handled by `na.rm`.
