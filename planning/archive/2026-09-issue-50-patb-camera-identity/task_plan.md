# Task: Resolve inferred_format from the camera named in a frame's PAT-B file (#50)

## Problem

A digital frame with no `camera_calibration_url` cannot be sized from its GSD, because
pixel count spreads 32–83% at a given focal length. `fly_footprint()` records
`footprint_basis = "inferred_format"` and produces **no footprint at all** unless a DEM
is supplied — documented behaviour, and correct given what it knows.

But the sensor identity is often published elsewhere, and `fly` already ships the
dimensions. The centroid layer carries `patb_georef_url` for frames with a
photogrammetric solution, and those files name the camera.

Outcome: a frame with no calibration URL but with a PAT-B file is sized on the ordinary
`px_cross x ground_sample_distance` route — **no DEM required** — and `width_source`
records that the format came from a camera the province named rather than an inference.

## Decisions taken at the plan gate

1. **A new exported `fly_camera_patb()`** fetches and parses; `fly_footprint()` never
   touches the network and consumes a `camera_serial` column if one is present.
2. **`footprint_basis` stays the media value**, as for a calibration-URL row. Provenance
   goes in `width_source = "patb_serial=<serial>"`.
3. **Fix the mislabelled camera row and the generator**, plus the invariant test that
   makes name-based resolution safe.

## Phase 1: Measure the schemas and the population — DONE

- [x] Query the catalogue for digital frames with no `camera_calibration_url` and a
      `patb_georef_url`, across years; sample every archive, not just the two measured
      while planning. **41,249 frames, 4 years, 7 archives, 3 schemas**
- [x] Record per schema: key column, identity columns, coverage — into `findings.md`
- [x] Confirm the `.ori` / `.ORI` files carry no camera identity in any variant
- [x] Edit the issue body: correct the `20814295` claim, restate the schemas and the
      population as measured

Three findings change the design below, all recorded in `findings.md`:

1. **The catalogue GSD is 0 on all 24,742 frames of 2011-2012**, so resolving the camera
   alone still yields no footprint for the issue's own headline case. The PAT-B files
   carry the GSD; `fly_camera_patb()` returns it and `fly_footprint()` uses it only where
   the catalogue's is absent or 0.
2. **A serial that is present but unknown refuses.** `d_001_fi_16_georef.txt` labels both
   its cameras `UltraCam XP` and one of them is serial `70912643`, an UltraCam **X** — so
   falling through from an unknown serial to the camera string would size 1,790 frames
   20% too wide. The name is consulted only where the archive carries no serial at all.
3. **The serial index needs two passes**, `report_serial` then `key`, not a union — a
   union makes `20814295` ambiguous and refuses 14,717 correct frames.

## Phase 2: Fix the camera label and pin the invariant — DONE

- [x] `camera_name()` in `data-raw/make_camera_formats.R`: derive the label from
      `report_serial`'s family where a serial is present (`UC-SX-` → UltraCam X,
      `UC-SXp-` → UltraCam Xp), falling back to the text scan; QA check that the two agree
- [x] Patch `inst/extdata/camera_formats.csv` row `70912643_2015` → `UltraCam X`
- [x] `tests/testthat/test-camera_formats.R`: every distinct `camera` label maps to
      exactly one `(px_cross, px_along)` — restricted to `key_type == "calib_file"`, since
      the four fallback rows have `px_cross = NA` and three share one label across three
      widths, so an unrestricted test agrees trivially (review). Assert the premise that
      at least one label spans more than one row, or it is a per-row tautology
- [x] Restore the wrong label and confirm the test fails, as an executed check
- [x] Review round 1: three findings, all fixed — the disagreement diagnostic was
      blind to the risky branch (where `serial_family()` returns NA the label IS the
      text scan, so no disagreement can ever print), a comment named anchoring as the
      non-shadowing guarantee where the trailing hyphen is what does it, and a count
      of four that is five

## Phase 3: Serial resolution inside `fly_camera_format()` — DONE

- [x] Build the serial index from the `calib_file` rows **only** (review B4 — a short
      serial hitting a `focal_length` row gives a confident basis and no footprint), as
      **two passes**: `report_serial` tokens first, `key` tokens as a fallback. Tokenise
      on non-digits and take the longest run (B2); strip the `_YYYY` suffix from `key`
      first (B3)
- [x] Resolve a `camera_serial` column through that index —
      `width_source = "patb_serial=<serial>"`, `resolved = TRUE`, `inferred = FALSE`.
      Gate on the existing `matched`, not a fresh predicate, so a **withheld** calibration
      cannot fall through (review O1)
- [x] Resolve a `camera_name` column through the label **only where no serial is present**,
      by **exact** equality against a normalised label — a prefix match would size a
      `DMC II 250` from the `DMC II 230` row (review G5)
- [x] Refuse rather than guess, three ways, each with its own `width_source` tag in the
      shape of the existing `"withheld:"` refusal: rows that disagree on
      `(px_cross, px_along)`; a serial present but unknown; an unrecognised name
- [x] **Carry every refusal tag through `fly_footprint()`** — generalise its `withheld`
      block to `!from_table & !is.na(fmt$width_source)`, or the tag is computed and
      dropped (review B5)
- [x] `fly_footprint()` uses `patb_gsd` where `ground_sample_distance` is absent or 0,
      never overwriting the catalogue column, and records that in `width_source`
- [x] Tests: resolves by serial, resolves by name where no serial, ambiguous, unknown
      serial refuses rather than reading the name, unrecognised name refused
      (`DMC II 250`), withheld key + serial + name all present still refused, serial and
      calibration URL both present (URL wins), serial on a film frame (ignored),
      `patb_gsd` used only where the catalogue GSD is 0, refusal tags reaching
      `fly_footprint()$width_source`, zero-row input keeping column types
- [x] **The decisive offline check** (review AC2): every frame in
      `photo_centroids_digital.gpkg` has both a calibration URL and a PAT-B identity, over
      two cameras and two schemas — assert both routes resolve to the same
      `(px_cross, px_along)`

## Phase 4: `fly_camera_patb()` — DONE

- [x] New `R/fly_camera_patb.R` — `dest_dir = tempdir()` (never `fly_fetch()`'s `"photos"`
      default, which writes into the caller's cwd), accepts already-local archives,
      **dedupes URLs** before fetching, unzips, dispatches on schema by column names
      present, parses **every** georef member rather than the first, and asserts basename
      uniqueness
- [x] Join on `(tolower(roll), as.integer(frame))` — never on derived padding — and on
      `airp_id` where the schema carries it. `match()` semantics, duplicate keys asserted
      to agree on the identity, and `nrow(out) == nrow(input)` asserted: a `left_join` on
      a duplicated key is the #37 failure class (review G2, G3)
- [x] Sweep `centroid_shapes()` — this attaches columns to user-supplied data, which is
      how #35 shipped through two releases (review G8)
- [x] Test with the PAT-B rows **shuffled**, or a per-file implementation passes a
      per-frame test vacuously; and a frame absent from its archive returns `NA` rather
      than being dropped
- [x] An archive with only `.ori`/`.ORI`, a schema with no identity column, or a URL that
      404s into an HTML body under a `.csv` name (2 of the 7 measured), yields `NA` with a
      message naming the file. Detect the 404 by content — `download.file()` exits 0
- [x] Bundle a trimmed real PAT-B fixture in `inst/testdata/`, generated by
      `data-raw/make_testdata.R`, so the suite is offline; live canary guarded by
      `skip_on_ci()` **and** `skip_if_offline()`
- [x] Runnable `@examples` on the bundled fixture

## Phase 5: Documentation and release — DONE

- [x] `inst/notes/camera-formats.md`: the PAT-B route, the measured schemas, why the
      serial rather than the key is the join, why the `22814295` gap is not a typo, and
      the disposition of the issue's presenting symptom — the downstream 11,435 m figure
      is wrong by 2.2x, not this route (review A2)
- [x] Measure the delivered thumbnail orientation for the three newly reachable cameras.
      `fly_georef()`'s aspect gate and `fly_digital_rotation()` = 270 were measured on the
      two bundled cameras only, so a newly-sized frame can gain a footprint and still gain
      no GeoTIFF (review, `fly_georef()` section)
- [x] Repoint the passages that become false, by name: `R/fly_footprint.R` `inferred_format`
      describe item and the "can only be sized through a DEM" paragraph,
      `vignettes/airphoto-selection.Rmd`, `inst/notes/camera-formats.md` "the catalogue's
      URL basename is not a reliable serial", the `R/fly_camera_format.R` header
- [x] `NEWS.md` + `DESCRIPTION` bump to 0.10.0, as the final commit of the branch. NEWS
      must name the **behaviour change for `dem` callers**: a newly-resolved frame becomes
      `by_gsd` and so leaves the DEM route, moving the 2012 UltraCam X from 4,073 m to
      4,329 m against an exterior-orientation truth of 4,066 m (review O2); and that a
      frame can now gain a footprint and still be refused a GeoTIFF
- [x] File the follow-up issue for the DEM film blow-up the issue's own run surfaced
- [x] File the follow-up issue for the DEM film blow-up — fly#54
- [ ] `/planning-archive`, then `/gh-pr-push`

## Validation

- [x] Tests pass
- [x] `/code-check` — 3 rounds, 8 findings, all fixed; the two correctness bugs each
      proven by restoring the defect
- [x] `lintr::lint_package()` — no new lints beyond the ALL-CAPS-constant and
      `testdata_path` classes both already present at the baseline
- [x] `devtools::document()` read — one new export, no rebinding; `check_pkgdown()` clean;
      `R CMD build` tarball carries the fixtures and no `planning/`
- [x] End to end against the live population: of 41,249 frames, **22,366 resolve** —
      4,822 UltraCam Xp at 5,193 m, 2,827 UltraCam X at 4,329 m, 14,717 UltraCam Eagle at
      5,002 m — and 18,883 are refused for a named reason. Cross-check against the DEM
      route, which the issue measured as correct to within 1%
- [x] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
