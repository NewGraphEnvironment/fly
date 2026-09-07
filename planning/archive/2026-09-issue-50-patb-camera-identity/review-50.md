# Plan review — #50, with dispositions

Plan subagent, run concurrently with Phase 1 against `task_plan.md`, the issue and the
code. 22 findings. Recorded here rather than left in a transcript, per `planning.md`.

Two of its findings I had reached independently from the Phase 1 measurement before the
review landed (B1 and AC1); both are noted as such rather than claimed twice.

## Blockers

| # | finding | disposition |
|---|---|---|
| B1 | A union serial index makes `20814295` ambiguous and refuses the most-flown camera in the table | **Accepted, already fixed.** Reached independently from the Phase 1 measurement. The review proposes "index `key` digits only for rows with no `report_serial`"; that variant breaks the Intergraph DMC, whose `report_serial` (`DMC01 - 0039`) exists but yields `0039` while a PAT-B lens number is `100039`. The two-pass form — report index first, key index as fallback — resolves the DMC as well, and closes G4 with it |
| B2 | Digits must be **tokenised**, not concatenated: `gsub("[^0-9]", "", "UC-Fp-1-20114172-f70")` is `12011417270` and matches nothing | **Accepted.** Split on non-digits and take the longest run; ties keep all |
| B3 | `key` carries a `_YYYY` suffix, and token `2014` hits two rows that *agree*, so the ambiguity guard stays silent and any 4-digit identity equal to 2014 resolves to "UltraCam Eagle" | **Accepted.** Strip `_YYYY` before tokenising, and assert no index token is a 4-digit year |
| B4 | Build the index from `calib` rows only — the fallback keys are `"80"`, `"92"`, `"100"`, `"120"`, `"127"`, and a short serial hitting one gives `from_table = TRUE` with `px_cross = NA`: a confident `footprint_basis` and no footprint, worse than today | **Accepted** |
| B5 | `"ambiguous_serial:"` is computed in `fly_camera_format()` and then **dropped** by `fly_footprint()`, which copies `width_source` only for `from_table` and for `startsWith("withheld:")` | **Accepted.** Generalise the carry to `!from_table & !is.na(fmt$width_source)` rather than adding a second `startsWith`. This is verbatim the defect the `withheld` block exists to fix |

## Ordering

| # | finding | disposition |
|---|---|---|
| O1 | The new route must gate on the existing `matched`, which already carries `refused`. A fresh gate reopens the withheld-calibration hole — reachable: `10210206_2015` withholds 495 frames whose PAT-B may name an UltraCam Eagle | **Accepted.** Gate on `digital & !matched`, extend `matched`, and test withheld + serial + name all present, still refused |
| O2 | A frame that becomes `by_gsd` leaves `dem_eligible <- !by_gsd & ...`, so **`fly_footprint(dem = )` returns a different footprint than before** for every newly-resolved frame | **Accepted as a finding; precedence unchanged.** Measured: for the 2012 UltraCam X the GSD route gives 4,329 m against 4,073 m today, and exterior orientation says 4,066 m — so those DEM callers get a number 6.5% wider. The Xp moves 1.5% the other way. Changing the global GSD-beats-DEM precedence set in #32 is a larger decision than this issue, and keying an exception to PAT-B provenance invents a rule the 2015/2016 frames contradict (their `seg_gsd` equals the catalogue's). So the precedence stands and **NEWS names the change and its measured size** |

## Gaps

| # | finding | disposition |
|---|---|---|
| G1 | `fly_camera_patb()` needs to accept already-local archives, and `fly_fetch()`'s `dest_dir` defaults to `"photos"` in the working directory — an example that inherits it writes into the user's cwd | **Accepted.** `dest_dir = tempdir()`, and a documented path for local files |
| G2 | Duplicate keys in a PAT-B file multiply rows through a `left_join` — the #37 failure class | **Accepted.** `match()` semantics, assert duplicate keys agree on identity, assert `nrow(out) == nrow(input)` |
| G3 | Join on `(tolower(roll), as.integer(frame))` rather than deriving padding; one archive serves many rolls; one roll may span archives; parse every georef member, not `f[1]`; assert basename uniqueness; dedupe URLs before fetching | **Accepted, all six.** The padding-free form is prior art in `data-raw/georef_calibrate-corner_mapping.R` |
| G4 | A minimum token length of 5 drops the Intergraph DMC (`0039`) | **Closed by B1's two-pass form** — the DMC resolves through the key index at `100039` |
| G5 | The name route is more dangerous than "one label, one format" covers: the measured `ccre_camera_type` is `"DMC II 230"` against a shipped label `"DMC II"`, and a prefix match would size a DMC II 250 (17216x14656) from the 230's row | **Accepted.** Exact equality against a normalised label, unknown strings refused. Test `"DMC II 250"` refused. Note the name route only runs where no serial is present, which that archive is not |
| G6 | "Lens number equals camera serial" rested on n=1 | **Answered by Phase 1: n=3.** `121201` → `121201_2011` (a row with no report serial), `20814295` → the Eagle rows, `70912643` → `UC-SX-1-70912643` |
| G7 | Phase 1 should say which account of the schemas is wrong | **Done.** The `airp_id`-keyed bare CSV exists; three schemas confirmed; issue body rewritten |
| G8 | `fly_camera_patb()` attaches columns to user-supplied data, so it must sweep `centroid_shapes()` — this is how #35 shipped through two releases | **Accepted.** The single most likely way this feature reaches no real caller with a green suite |
| G9 | Three passages become false, by name: `R/fly_footprint.R:399` and `:423-426`, `vignettes/airphoto-selection.Rmd:73-75`, `inst/notes/camera-formats.md:37`, and the `R/fly_camera_format.R` header | **Accepted**, added to Phase 5 by name |

## Assumptions and acceptance

| # | finding | disposition |
|---|---|---|
| A1 | `footprint_basis` staying the media value makes `width_source` the only trace, so B5 is load-bearing rather than cosmetic | **Agreed** |
| A2 | The issue's presenting symptom — the same frames published downstream at 11,435 m against 5,193 m here — is never dispositioned | **Accepted.** Record it: exterior orientation says 5,273 m, so the downstream figure is wrong by a factor of 2.2, not this route |
| AC1 | The plan's acceptance numbers were the *exterior-orientation* figures, which a correct implementation would fail | **Accepted, already fixed.** Corrected to the GSD-route figures from the Phase 1 measurement before the review landed |
| AC2 | The bundled `photo_centroids_digital.gpkg` spans both measured archives and every frame has **both** a calibration URL and a PAT-B identity — so the serial route and the calibration route must resolve to the same `(px_cross, px_along)`, offline, over two cameras and two schemas | **Accepted, and it is the best test in the review.** It fails loudly on any indexing error in B1–B4 |

## Test gaps

| finding | disposition |
|---|---|
| Phase 2's label invariant is **vacuous three ways**: the four `focal_length` rows have `px_cross = NA` and three share one label across three widths, so restrict to `key_type == "calib_file"`; after the relabel only three labels have more than one row, so assert that premise; and make "restore the wrong label" an executed check | **Accepted, all three** |
| A per-*file* identity implementation passes a per-*frame* test vacuously, because `ccre_lens_number` is constant across all 5,481 rows of the measured archive | **Accepted.** Shuffle the PAT-B row order in the test and require an identical result |
| Missing cases: withheld + serial; ambiguous `width_source` surviving into `fly_footprint()`; `nrow` preserved under duplicate keys; `centroid_shapes()` sweep; zero-row input keeping column types; a frame absent from its archive returning `NA` rather than being dropped | **Accepted** |
| `skip_on_ci()` is the wrong helper alone for a live canary — `skip_if_offline()` is what makes it skip on a developer machine with no connection | **Accepted**, use both |

## `fly_georef()` — the exposure the plan missed entirely

Newly-sized frames reach two constants that were measured on **only the two cameras in
the bundled fixture** (Leica DMC II, UltraCam Eagle M3):

- the aspect gate in `fly_georef()`, which skips a frame whose delivered image aspect does
  not pair with its footprint edges;
- `fly_digital_rotation()` = 270, which geometry cannot verify — a wrong value writes a
  valid GeoTIFF over the right ground, turned a quarter turn.

UltraCam Xp, UltraCam X and the non-M3 UltraCam Eagle have never been measured. So this
issue can produce a frame that **gains a footprint and still gains no GeoTIFF**. That is a
correct refusal, and it will read as a regression unless NEWS names it.

**Disposition:** measure the delivered thumbnail orientation for the three newly reachable
cameras from the public thumbnails, record it in `inst/notes/`, extend the aspect premise
test where the data supports it, and name the refusal in NEWS.
