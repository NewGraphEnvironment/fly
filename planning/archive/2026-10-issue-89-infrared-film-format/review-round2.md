# Code-check round 2: fly#89 working diff (IR sized as film, pins, rotation date fix, round-1 fixes), 2026-10-02

Scope: the uncommitted diff (`diff2.patch`) plus the changed files read in full from disk. This was a
read-only review. Tests ran in a copy of the repo under the scratchpad, and the only file written in
the repo is this one.

## Findings

- **[bug, published claim]** `R/fly_footprint.R:585-587` and `man/fly_footprint.Rd:85-87`. The new
  text for the `footprint_basis` item "the `media` value" lists only two routes: "one of the four
  film values, sized from `negative_size` ... or a value named in `format_size`". That leaves out
  the camera-table route. A digital frame sized from its calibration URL or its PAT-B camera also
  gets its `media` value as the basis: `basis[from_table] <- ifelse(fmt$inferred[from_table],
  "inferred_format", media)` (around line 971). This is the main way digital frames are sized. The
  old wording ("format resolved from the format table") covered it, loosely. As written, the man page
  tells a caller that a `"Digital - Colour"` basis means they passed `format_size`. Add the
  camera-table route (calibration or PAT-B camera) back to the item.

- **[bug, published figure]** `inst/notes/camera-formats.md`, "The result" ("the 9-inch overlap
  medians are 0.19 to 0.27, below the window"), and `planning/active/findings.md`, Amendment 1
  ("sit BELOW the window at 0.19-0.27"). Each roll has two 9-inch medians, nominal and reported.
  `irfilm_run5.log` and `infrared_film_rolls.csv` put `bci3`'s reported 9-inch median at **0.113**,
  and the reported medians of the four rolls span 0.113-0.273. Only the nominal medians span
  0.191-0.274. Either write "nominal 9-inch medians 0.19-0.27" or give the full range,
  "0.11-0.27". The verdict does not change: the test asserts `pmax(...) < 0.557`.

- **[bug, unbacked claim]** `R/fly_footprint.R:5-8` says "their thumbnails are square 23 cm frames".
  The note says "`bcf07060`'s thumbnails are square 23 cm frames with eight fiducials and a
  `30BCC (IR) 07060` data strip".
  - W2 measures aspect and collar fraction only.
  - The note's own W2 bullet says this is weak evidence: "a 5-inch or 70 mm frame is square too".
    Thumbnails can show *square*. They cannot show *23 cm*.
  - The fiducial count and the data-strip text are recorded in no shipped CSV and no producer line
    (`infrared_film_thumbnails.csv` has dimensions and mask fractions only). Nothing in the run
    produced them.
  - The R comment uses this as one of the three reasons the media values were added, so it
    overstates the evidence in exactly the direction fly#30 guards against.
  - Fix: say "square", or record the fiducial and data-strip observation somewhere a reader can
    check (a column, or a findings entry naming the frames).

- **[fragile, written data and stale prose]** Three things go stale as of this diff:
  - `inst/notes/georeferencing.md:284` says the 26 `legs_unscorable` rolls are "all infrared film,
    which `fly_footprint()` does not size — fly#89". From this diff on, `fly_footprint()` does size
    them.
  - `inst/extdata/film_rotations_excluded.csv` still records those 26 IR rolls as
    `legs_unscorable`. IR frames are now sized and rotated onto a bearing, so `fly_georef()` reaches
    its film refusal for them and reads the ledger. It would tell a caller "its legs could not be
    scored", but those legs failed only because the footprints were empty.
  - Phase 5 regenerates the ledger. Its run is in flight now (PID 62055, started 08:09), and it will
    move these rows and probably the counts.
  - Phase 6 lists only `camera-formats.md`, `NEWS.md` and `CLAUDE.md`. It does not list the count
    table and prose in `georeferencing.md` (56 / 60 / 26 / 13 / 10 / 8 / 3), and does not say that
    CLAUDE.md's "56 rolls" and "the other 6,660 film rolls" need re-deriving from the regenerated
    CSVs.
  - Add `inst/notes/georeferencing.md` ("The measured rolls") to Phase 6, and land Phase 5's CSVs
    in the same PR as the `fly_film_media()` change.

- **[minor, stale comment]** `R/fly_georef.R:728-729`: "a measured row carries the day the tables
  were written". After the date fix, a measured row carries the day that roll was measured. The
  code beside the comment (snapshot read from the unmeasured rows) is still correct; only the stated
  reason is wrong.

- **[drift, planning]** `planning/active/progress.md` (Phase 2 entry) has three stale items:
  - It says "four full runs (`irfilm_run{1..4}.log`)" and "Run 4 under the amendment". The shipped
    CSVs and the producer lines the note quotes, such as control (c)'s "flown 1972-1979", come
    from **run 5**, and `findings.md` says so ("runs 4-5", `irfilm_run5.log`).
  - It says the IR test gives "28 pass; the `fly_film_media()` tie fails". It now gives 29 pass,
    0 fail.

## Checked and clean

- **Round-1 fixes.**
  - Control (c) now prints the years. `bw_yr` is indexed by `names(bw_med)` after the `bw_n >= 5`
    subset, so it is aligned, and run 5 prints "13, flown 1972-1979".
  - The W3 guard is a per-roll `setequal` of `paste0(roll, "__", basename(url))` against
    `pages$file`, with the empty-URL case guarded. It fails toward stop if a page is missing, if a
    filename is wrong, or if a row is filed under the wrong roll. A row whose `film_roll` is mistyped
    is dropped by the `%in% rolls` filter and then trips the guard for the roll whose page is now
    missing.
  - `findings.md` now reads 5.76 / 3.11 / 2.65 / 0.19%, matching the log. "Result under
    amendment 1" matches run 5 line for line.
- **Rotation date fix** (`georef_calibrate-film_rotations.R:220-222, 268-285, 309, 319`).
  - Legacy cal files (no `measured_on`) and new ones bind under `dplyr::bind_rows()` with NA fill,
    because the cal objects are 1-row tibbles.
  - The legacy date is matched by `film_roll` against both shipped tables: `measured` from the
    shipped table, `retrieved` from the excluded rows with `measured == TRUE`. That column reads back
    as a logical, so the filter is right. A roll in neither table stops the run.
  - `ship$measured_on[i]` is indexed on `ship`, which is subset from `cal` after the fill, and
    `cal$measured_on[m_idx]` is aligned with `excl`.
  - Partial re-run: a roll whose cal file was deleted is re-measured and stamped with its own
    `Sys.Date()`. Every other roll keeps the date it already had.
  - Current state: the 90 surviving cal files are legacy and get 2026-10-02 from the CSVs. That is
    the true date, since their mtimes are 00:47-01:35 today. The 26 IR cal files were deleted, and
    the in-flight run stamps them itself.
  - The script was last edited at 07:53 and the run started at 08:09, so the run is reading the
    fixed file. **Do not edit this script, or `R/`, until PID 62055 exits.**
- **Consumers of `fly_film_media()` and of the media string.**
  - `fly_footprint()` uses it for format sizing (line 934) and `film_like` for the #54 check (line
    1176).
  - `fly_camera_format()` uses it to define digital. The focal fallback keys are 80 / 92 / 100 /
    120 / 127, and the IR focal lengths are 153 / 305, so the note's "only failed because no
    focal-length fallback matched" holds.
  - `fly_georef()` routes on `grepl("^Film")`, so it is unchanged.
  - The rotation script's population is `grepl("^Film")`, so it is unchanged.
  - No IR roll appears in `flying_height_rolls.csv` or `_excluded.csv`. The 56 out-of-band IR frames
    sit at r 0.44-0.53 or around 2.0-2.1, far from the band edges, and none is over the 16,000 m
    ceiling (IR maximum 7,620 m). So "the 56 fall back to nominal scale" holds.
- **Pins.**
  - The four scripts select film only through the pinned line. Their `fly_footprint()` calls run
    on frames drawn from that pinned set.
  - Digital sets are taken by `grepl("^Digital")` (`dem_calibrate-coverage_error.R:211`,
    `height_calibrate-flying_height_slip.R:284, 318`).
  - `dem_measure-photo_parallax.R` draws from the canopy census, which is pinned.
  - `height_calibrate-lower_tail_rolls.R` reads the sweep and its own `FORMAT_M`.
  - The other `data-raw/` scripts do not filter on `media`.
  - No other route picks up IR.
- **Note figures**, checked against `irfilm_run5.log` and the five CSVs, apart from the two
  findings above:
  - Population: 771 / 7 and 3,054 / 25.
  - Spacing: window 0.557-0.780, n = 2,481; controls 0.635 / 0.343; the per-media table.
  - Rolls: `bcf07060` 0.20 / -0.44. `bci95063` and `bci96066` are 1:7000-7200 at 305 mm, as are
    `bci93044` and `bci93045` at 0.65. Years are 1975 / 1995 / 1996 / 2007. `bcf517` has 13 frames
    at 1:4000 and 153 mm, with 0.770 / 0.587 / 0.816 / 0.668.
  - Thumbnails: 4 rolls and 422 frames, aspect 1, collar at most 0.0617 per frame (under 0.0707),
    0 declined, ~1,250 px.
  - Logbooks: 27 pages on 17 rolls, 6 pass, 11 serial-only.
  - #54 band: 3,769 / 56 / 0.
- **Tests.**
  - `NOT_CRAN=true` on `test-fly_footprint_infrared.R`: 29 pass, 0 fail.
  - The three new `test-fly_footprint.R` blocks, extracted into a copy: 8 pass, 0 fail.
  - Each of the three fails against the old `fly_film_media()`: an empty geometry, a focal-100
    resolve, and an empty geometry.
