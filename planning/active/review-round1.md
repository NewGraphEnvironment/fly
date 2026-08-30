# Review round 1 — fly#32 camera format table

Reviewed: staged diff plus the unstaged `fly_camera_format()` resolver in
`R/fly_camera_format.R` (working tree moved during the review; findings below were
re-verified against the tree state at the end, and the ones the author fixed mid-review
— the failing manifest drift guard, the generator/CSV divergence over focal 83 — are
**not** listed).

Verification used: live BC WFS query of all 223,667 `MEDIA LIKE 'Digital%'` frames
(`numberMatched` reconciled, 0 duplicate FIDs), plus R probes for each claimed R
semantic. The parsed numbers themselves check out against published camera
specifications — UltraCam Eagle 20010x13080 @ 5.2 um, Eagle M3 26460x17004 @ 4.0,
UltraCamXp 17310x11310 @ 6.0, UltraCamX 14430x9420 @ 7.2, DMC II 230 15552x14144 @ 5.6,
DMC III 25728x14592 @ 3.9, Z/I DMC 13824x7680 @ 12 f120 — and the cross-track/along-track
assignment is correct in every parser. No transcription error found in the shipped table.

## Findings

- **[bug]** `data-raw/make_camera_formats.R:483-500` — both exclusion-block
  `data.frame()` calls abort the script when their key vector is empty. `paste0()`
  returns length 1 for a zero-length argument (and `ifelse()` on a `logical(0)` test
  returns `logical(0)`, which `paste0` also absorbs), so `reason` is length 1 while
  `key` is length 0. Verified both:
  ```
  unparsed empty    -> ERROR: arguments imply differing number of rows: 0, 1
  nothing withheld  -> ERROR: arguments imply differing number of rows: 0, 1
  ```
  The second one fires in the **healthy** case: the moment check F rejects nothing,
  `parsed$key[!parsed$ship]` is `character(0)` and the run dies at line 496 — after
  ~25 MB of downloads, all parsing and all QA, with `camera_formats.csv` already
  written at line 471 but the excluded file and manifest not. That leaves the three
  artifacts inconsistent on disk, which is the state the manifest guard exists to
  detect. Guard each block with `if (length(...))`, as line 504 already does for
  `refused`.

- **[bug]** `data-raw/make_camera_formats.R:118-121` — the extract is guarded on
  directory *existence*, and `fs::dir_create(d)` runs before `utils::unzip()`. `unzip`
  does not error on a bad archive; verified:
  ```
  warning: error 1 in extracting from zip file
  unzip result: no error   dir still exists: TRUE   files: 0
  ```
  So an interrupted or corrupt extract leaves an empty directory that every later run
  skips. `parse_one()` then finds no PDFs, the key lands in `unparsed`, and it is
  written to `camera_formats_excluded.csv` with the reason **"calibration present only
  as a scanned image, not machine-readable"** — a specific factual claim that is now
  false and permanent until someone clears the cache by hand. This is the same
  guard-on-existence mistake the author explicitly fixed one block earlier for the zip
  (line 111, "Guard on non-empty, not existence"); the fix was not carried to the
  extract. Extract to a `.part` directory and rename, or gate on the directory
  containing at least one `.pdf`.

- **[bug]** `R/fly_camera_format.R:117-131` — the resolver never consults
  `camera_formats_excluded.csv`, so a frame whose calibration key was *deliberately
  refused* falls straight through to focal-length inference. Verified against real
  catalogue focal lengths:
  ```
  key              focal  width_mm  width_source        inferred
  72914123_2019     100    103.860  focal_length=100    TRUE     (1,545 frames)
  10210206_2015     100    103.860  focal_length=100    TRUE     (  495 frames)
  11937933_2009      83         NA  <NA>                FALSE    (  443 frames)
  12335326_2017      53         NA  <NA>                FALSE    (7,140 frames)
  ```
  The two dangerous ones (AIC Pro 53.904 mm, PhaseOne 53.4 mm) come back NA **only
  because no fallback row happens to exist at focal 83 or 53** — safety by coincidence
  of the current table contents, not by construction. `FALLBACK_REFUSE` enforces this
  in the generator; nothing enforces it in the consumer. Any future table that gains a
  row at those focals silently sizes 7,583 frames at ~1.95x their true width (3.8x
  area). Match `key` against the excluded set and refuse, rather than relying on the
  fallback set staying sparse.

- **[bug]** `data-raw/make_camera_formats.R:401-408` — `FALLBACK_REFUSE` encodes the
  one instance that was measured, not the property it stands for. Two consequences,
  both live:

  1. **Focal 53 is not listed.** `12335326_2017` is a 53.4 mm PhaseOne with 7,140
     frames. It has no no-URL frames today, so `need` excludes 53 and no row is built.
     The moment BC publishes one focal-53 frame without a calibration URL, the
     generator builds a row extrapolated from the nearest calibrated focal (70, the
     UltraCam Falcon at **103.86 mm**) — 1.95x too wide, 3.8x too much ground area,
     shipped with `width_spread_pct = 0`.
  2. **Extrapolation distance does not predict the error, so no distance bound fixes
     this.** The refused focal-83 row extrapolated from focal 80 — a 3.6% focal gap
     producing a **93%** width error. The shipped row `"120"` extrapolates from focal
     127 — a *larger* 5.5% gap — and is fine. Nothing in the generator's data separates
     them; only camera identity does. Row `"120"` covers 11,984 frames (5.4% of the
     whole digital catalogue) on exactly the warrant just refused as unsound.

  Also note the refusal is silent if it stops applying: if the catalogue ever populates
  a URL for the focal-83 frames, `refused` becomes empty, the excluded row disappears,
  and nothing reports that a declared safety refusal no longer fires. Assert that every
  `FALLBACK_REFUSE` name was actually matched.

- **[fragile]** `data-raw/make_camera_formats.R:428,439` — `width_spread_pct` and
  `n_cameras` are a proxy that does not guard what they are read as. They measure
  dispersion among the *source* cameras, so a single-source row is structurally `0`
  however bad the inference is. The two extrapolated rows carry the most confident
  labels in the file:
  ```
  "120"  extrapolated from nearest focal  165.888  n_cameras 1  width_spread_pct 0   (11,984 frames)
  "127"  inferred from focal length       165.888  n_cameras 1  width_spread_pct 0   (   845 frames)
  ```
  12,829 frames are labelled zero-spread on a width derived from one camera at a
  different catalogue focal. The refused focal-83 row would have shipped
  `width_spread_pct = 5.5` while being 93% wrong. An extrapolated row should not be
  able to report 0.

  (Row `"120"` is *probably* right — a 120 mm digital frame is very likely the Z/I DMC,
  which is 165.888 mm. But the generator did not reason that way: it reached it via
  "nearest catalogue focal is 127", using the same catalogue focal field that the calib
  row for that very camera declares wrong — `"catalogue records focal 127; the report
  says 120 - report preferred"`. Right by luck through a field the script distrusts.)

- **[fragile]** `data-raw/make_camera_formats.R:246` + QA sections C/F — `focal_mm` is
  the only shipped number with no gating bound. `parse_dmc` computes
  `num(sub(".*\\[m\\]", "", fl)) * 1000`; the unit anchor is the strict literal `[m]`,
  which does not match `[mm]`. When the sub misses, it is a no-op and `num()` — which
  strips non-digits and concatenates rather than failing — returns a finite number from
  the whole line, which then passes the `is.finite` gate at line 287 and is multiplied
  by 1000. Nothing catches it: check D bounds width, aspect and pitch but not focal;
  check C computes `focal_disagrees` and only prints it, never appending to `fail`; and
  check F is explicitly skipped where unmeasurable —
  `terrain_ok <- is.na(terrain_implied) | ...` — so a key whose frames carry no
  `GROUND_SAMPLE_DISTANCE`/`FLYING_HEIGHT` has **no** gating check on its focal length
  at all. Add a plausibility band on `focal_mm` the way D does for width.

- **[fragile]** `data-raw/make_camera_formats.R:342-345` and
  `tests/testthat/test-camera_formats.R:41` — check D's lower bound of 80 mm fails
  toward abort on legitimate input. The catalogue demonstrably contains medium-format
  bodies at 53.4 mm and 53.9 mm (7,583 frames, per the author's own exclusion notes).
  If either calibration ever becomes machine-readable and parses correctly, `bad_d`
  fires and `stop("QA failed, CSV not written")` discards the entire run including the
  14 good rows — and the test asserting `all(tbl$width_mm > 80)` fails on a correct
  table. The bound is tuned to large-format aerial cameras and the record is not
  exclusively large-format.

- **[fragile]** `data-raw/make_camera_formats.R:335` — `if (any(parsed$focal_disagrees))`
  errors with "missing value where TRUE/FALSE needed" when a key's catalogue focal is
  NA and no other row disagrees (`any()` returns NA, not FALSE). `focal_catalogue` is
  NA whenever a key's frames all carry a missing `FOCAL_LENGTH`. Same NA then flows
  into `ifelse(shipped$focal_disagrees, ...)` at line 461, producing an NA note.

- **[fragile]** `data-raw/make_camera_formats.R:426-427` — `w <- as.numeric(names(tw)[1])`
  round-trips a double through `as.character`, then `at$width_mm == w` compares it for
  exact equality. That round trip is not lossless for several widths this pipeline
  produces; verified:
  ```
  25728 x 3.9 -> "100.3392"  roundtrip_ok = FALSE
  14592 x 3.9 -> "56.9088"   roundtrip_ok = FALSE
  14144 x 5.6 -> "79.2064"   roundtrip_ok = FALSE
  ```
  It does not bite today only because the DMC III's 100.3392 is a *stated* value read
  from the report, not the `px * pitch` product. A derived width of the same shape
  yields `h = NA` and a fallback row with a missing height. Compare on the index
  (`which.max(table(...))` against the original vector) rather than on a reparsed value.

- **[fragile]** `data-raw/make_camera_formats.R:108,117` — the zip and pdf caches are
  keyed on `basename(u)`, but the identity of a calibration is the full URL. Two URLs
  in different directories sharing a basename would collapse: the second finds a
  non-empty cached zip, skips the download, and silently inherits the first camera's
  dimensions. Verified 18 distinct URLs / 18 distinct basenames today, so this is
  latent, not live — but `frames$key` is built from the basename too, so the two frames
  sets would already have merged before the cache was consulted.

- **[fragile]** `R/fly_camera_format.R:77,104` — `inferred = FALSE` is emitted both for
  an exact calibration match and for a row that resolved to nothing (see the probe in
  the third finding: `11937933_2009` and `12335326_2017` come back `width_mm = NA,
  inferred = FALSE`). A consumer filtering `!inferred` to get trustworthy rows also
  picks up every unresolved frame. `width_mm` is NA there so a careful caller is safe,
  but `!inferred` is the natural filter to write.

- **[fragile]** `data-raw/make_camera_formats.R:511` — `match(excluded$key, by_key$key)`
  pools two key namespaces. `by_key` holds calibration keys only, so the focal-keyed
  refusal row gets `frames = NA` where the answer is 47 (no-URL frames at focal 83).
  The summary at line 531-532 then understates the excluded frame count. Reporting
  only, no effect on shipped numbers.

## Checked and clean

- `nzchar(NA)` ordering is correct at `make_camera_formats.R:92` (`is.na(...) | !nzchar(...)`)
  and `fly_camera_format.R:110` (`!is.na(u) & nzchar(u)`).
- Empty CSV fields read back as `""` not NA for character columns, so the
  `!is.na(x) & nzchar(x)` assertions in the tests are the right form and do bite.
- `fly_camera_cache[[file]]` on a missing name returns NULL (does not error), so the
  cache short-circuit is sound; the cache key covers everything the read depends on.
- `stopifnot(nrow(d) == n, !anyDuplicated(d$FID))` is not vacuous — the WFS CSV does
  carry `FID` regardless of `propertyName`, confirmed over all 223,667 rows, 0 duplicates.
- No roxygen blocks in the new R file, NAMESPACE unchanged at 9 exports — no
  `@export` rebinding.
- `on.exit()` at `wfs_page:56` is inside a function, so it fires.
- `download.file` truncation is correctly handled via the `.part` + non-empty check.
- Check B is correctly restricted to `mm_stated` rows in both the generator and the
  test, and the test asserts its premise (`expect_gt(nrow(b), 10)`) rather than passing
  on an empty set.
- All six tests in `test-camera_formats.R` pass at the current tree state.
