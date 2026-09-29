# /code-check summary — Phase 5 (docs + measurement) of #56

| Round | Findings | Fixed | Accepted | Inside previous fix? |
|-------|----------|-------|----------|----------------------|
| 1 | 2 (per-frame range false; source-side count quoted as output loss) | 2 | 0 | — |
| 2 | 3 (output-side fix measured one bearing, 30°, and quoted it as the loss — axis-aligned loses every opaque 0; cluster not stopped on error; "printed only on Windows" is a GDAL-build effect) | 3 | 0 | **y** |
| 3 | 7 (mechanism: results stated without the condition they were measured under — platform, pixel isotropy, GDAL build, bearings measured, source band count; plus downstream issue body and script error handling) | 7 | 0 | n |

Ended by enumeration: round 3 tabled 30 quantified claims in the diff against their
producers (`review-docs-round3.md`); every failing row is fixed. The measurement it rests
on was re-run after the script restructure and reproduced the report byte for byte
(`data-raw/.cache/mask_interior_zeros_log.txt`).

What changed in substance: the headline moved twice. Source-side 161/182 → output-side at
30° 41/182 → both bearings, where axis-aligned is 161/182 (rewritten as 1, never deleted)
and 30° is 41/182. The mechanism changed from "deleted" to "rewritten as 1", and the 0→1
shift of #68 turned out not to be Windows-specific.
