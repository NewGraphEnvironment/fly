# /code-check summary — Phases 2-3 of #56

| Round | Findings | Fixed | Accepted | Inside previous fix? |
|-------|----------|-------|----------|----------------------|
| 1 | 0 | 0 | 0 | — |
| 2 | 1 (docs count: 10,105 already contains the 264) | 1 | 0 | n |
| 3 | 5 (prose claims vs producers: "on Windows" is a GDAL-build effect; "never mistaken for fill" false on the srcnodata leg; terra NA → `nan` not 0; warning attributed to the mask; decline list read as complete) | 5 | 0 | n |

Ended by enumeration: round 3 named the mechanism (claims copied from a summary rather than
re-derived) and swept every quantified claim in the diff's roxygen, warnings, test comments
and data-raw header against its producer; the five it found were fixed, the rest confirmed.
