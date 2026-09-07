# Review round 4 — the fixes for round 3's seven findings (fly#50)

Scope: the round-3 fixes F1–F7 only, not the feature. Read against
`soul/conventions/code-check.md` and `code-check-r.md`.

**Note on what was reviewed.** `git status` reports `AM` on `R/fly_camera_patb.R` and
`MM` on `CLAUDE.md`, `NEWS.md` and `inst/notes/camera-formats.md` — the working tree
moved during this review (a `warning =` handler added to `readLines()`, and the
"23,241 frames of the three resolvable cameras" phrasing replaced with "every row of
the three archives"). Findings below are against the **working tree**. Suite green at
`FAIL 0 | WARN 0 | SKIP 0 | PASS 1462`.

---

## Findings

- **[bug]** `R/fly_camera_patb.R:90-92` — F2's `warning =` handler on `read.csv()`
  **discards a data.frame it successfully parsed**, and reports a valid PAT-B table as
  `could not be parsed`. `read.table` warns `incomplete final line found by
  readTableHeader` when a file has no trailing newline *and* `readTableHead` reaches EOF,
  which it does for small tables. Measured (R 4.5, this checkout, driving
  `fly:::fly_patb_read_one()` directly):

  ```
  1 data row , no trailing newline -> REFUSED: could not be parsed (incomplete final line ...)
  2 data rows, no trailing newline -> REFUSED: could not be parsed (...)
  3 data rows, no trailing newline -> REFUSED: could not be parsed (...)
  4 data rows, no trailing newline -> REFUSED: could not be parsed (...)
  5 data rows, no trailing newline -> OK data.frame 5
  ```

  A 1–4 frame archive published without a final newline resolves **zero** of its frames,
  and the operator is sent to "this file is broken" — one of the five outcomes F2 exists
  to keep apart — for a file that parsed perfectly. This is round 3's own mechanism
  inside F2's fix: two states (parsed-with-a-cosmetic-warning, and genuinely unparseable)
  are given one representation, and the fact that separates them (`d` *is* a data.frame)
  is computed and thrown away by the handler.

  It is invisible to the fixtures by construction — both bundled `.csv`s end `0a`, and
  both zip members are ≥6 rows — the "fixture that cannot reach the failure mode" row.

  Fix: keep only `error =`, and silence warnings without discarding the value —

  ```r
  d <- tryCatch(suppressWarnings(utils::read.csv(path, stringsAsFactors = FALSE)),
                error = function(e) structure(list(), msg = conditionMessage(e)))
  ```

  Safe on the warnings you *do* want to reject: a binary member that warns
  `line 3 appears to contain embedded nulls` still returns a garbage frame, which then
  fails schema dispatch and is reported as "matches no PAT-B schema this version knows".
  Different sentence, same (correct) outcome. Add the ≤4-row-no-trailing-newline case as
  a test — it goes red on the current code.

- **[fragile]** `R/fly_camera_patb.R:89` — `grepl("^\\s*<", head_bytes[1])` sits
  **outside every handler**, and warns on a first "line" that is not valid in the native
  encoding. F5 removed the extension allowlist, so every zip member now reaches this
  line; the working-tree edit added a `warning =` handler to `readLines()` on line 82–84
  citing exactly this class ("a binary member would otherwise raise a warning out of a
  function whose job is to say 'not this one'") and stopped one line short. Measured
  end-to-end, a binary member added beside the good table in
  `d_005_emn_19_georef.zip`:

  ```
  warnings escaping fly_camera_patb():
  [1] "unable to translate '<f8>C<a6><80><a1><fc><d6>*' to a wide string"
  [2] "input string 1 is invalid"
  resolved: 24 of 24
  ```

  Noise on a correct run today; under `options(warn = 2)` it aborts the batch, and it is
  a package warning with nothing the caller can act on. One-word fix:
  `grepl("^\\s*<", head_bytes[1], useBytes = TRUE)`.

- **[fragile]** `R/fly_camera_patb.R:147-154` — F2 names five outcomes per member and
  then **drops all of them whenever at least one member parses**. `read[ok]` returns the
  tables; the reasons in `read[!ok]` are reported only on the `!any(ok)` branch. With F5
  offering every member to the reader this is mostly `.ori` noise and correctly silent —
  but a *second* georef table that failed (a disk error, or the ≤4-row case above) is
  discarded with no message at all, and the frames it covered come back `NA` under a
  cheerful `N of M frames resolved` line. That is the collapse F2 exists to prevent,
  one level up from where it was fixed. Low reachability (no archive observed with two
  georef tables), but the guard already builds the string; emitting it when
  `any(ok) && any(!ok) && any(!ok & !grepl("no PAT-B schema", ...))` costs a line.

- **[fragile]** `planning/active/findings.md:180-186` — the record the shipped prose is
  derived from still says the DEM comparison is "over the whole population" with
  `n = 15,592` for the Eagle, and **15,592 is not reconcilable with anything else in the
  file**. findings.md's own tables give the only Eagle archive in the population
  (`d_001_fi_15_georef.zip`) **14,717** catalogue frames — used consistently at lines 16,
  45, 67, 80 and 127, and in the union-index argument in `CLAUDE.md` and
  `camera-formats.md` — and 4,822 + 2,827 + 14,717 = 22,366, the resolve total.
  4,822 + 2,827 + 15,592 = 23,241, the figure the working tree has just removed from
  `NEWS.md` and `CLAUDE.md`.

  The three shipped artifacts were re-worded to "every row of the three archives", which
  makes 15,592 *plausible* (an archive holds rows for frames that already carry a
  calibration URL, so archive rows ≥ 14,717 catalogue frames). But nothing states that,
  no producer is named for the number, and `findings.md` — the evidence record F6 exists
  to make trustworthy — was not updated with the re-wording. `NEWS.md` now carries
  **14,717** (line 5) and **15,592** (line 10) for the same camera in adjacent bullets
  with no sentence reconciling them.

  Per `code-check.md` ("Derive every number in a release note from the artifact it
  describes") and `planning.md` ("never a number without its producer"): state in
  `findings.md` what population 15,592 counts and how it was obtained, and say once —
  in `camera-formats.md` — that the DEM table's `n` is archive rows while the resolve
  table's `n` is catalogue frames. Otherwise the next session re-derives 23,241 from the
  same table and puts it back.

- **[fragile]** `data-raw/make_testdata.R:264` — the F4 sibling. `bundled_keys <-
  paste0(tolower(keep$film_roll), "_", as.integer(keep$frame_number))` is the exact
  stringify-NA shape F4 removed from `fly_patb_key()`, and `patb_keys()` on line 266
  produces the matching literal `..._NA` from the archive side, so an NA on either side
  trims the fixture to the wrong rows. The only guard is `stopifnot(nrow(d) > 0)`.
  Not reachable with today's `keep` (every bundled digital centroid carries both), and
  it is a human-run generator whose output is byte-compared — but it is the one
  remaining site of the pattern, and the fix is to reuse `fly_patb_key()` rather than
  restate it.

- **[fragile]** `git status`: `AM R/fly_camera_patb.R`, `MM CLAUDE.md`, `MM NEWS.md`,
  `MM inst/notes/camera-formats.md`. A plain `git commit` ships the **staged** versions —
  i.e. without the `readLines()` warning handler and without the entire "23,241 →
  every row of the three archives" correction. `code-check.md`, "A file staged and then
  EDITED commits the version from before the edit". Re-`git add` the four paths and read
  `git diff --cached` before committing.

---

## Branch enumeration for F1–F5 (priority 1)

**F1 — failed download reported as "published nothing".** Covered. `fly_fetch()` sets
`success = FALSE` on every arm: NA/empty URL, `download.file()` error, and (after this
branch's own change) a downloaded file that is missing or zero bytes; the cached-file
short circuit now also requires `file.size > 0`. `isTRUE(fetched$success[j])` therefore
reaches all of them, and `isTRUE(NA)` handles a `j` that missed (unreachable — `fetched`
carries one row per `want`). A `success = TRUE` file whose *content* is a 404 body is
picked up by F2's content check. No gap.

**F2 — five outcomes.** Covered at the member level for read error, empty, HTML,
zero rows and unrecognised schema; `fly_patb_tables()` propagates via the `error`
attribute and `fly_camera_patb()` reads it. Two gaps, both above: the parse-warning
branch mislabels a good file (finding 1) and the multi-member case discards reasons
(finding 3). The `is.null(why)` fallback in `fly_camera_patb()` is dead — `read[ok]` is
never length 0 when `any(ok)` — but harmless.

**F3 — `rbind` over all members.** Checked as asked, and it is sound. Every per-member
frame is built with the same five literal column names and the same coercions
(`as.character`/`as.numeric`), so a `gr` member and a `bare` member rbind cleanly with
no type promotion. `pull()` returning `rep(NA, nrow(d))` is a **logical** NA, and
`as.character(NA)` is `NA_character_`, `as.numeric(NA)` is `NA_real_` — both correct.
A zero-row table cannot reach the pooling at all: `fly_patb_read_one()` returns the
string `"parsed to zero rows"` before it can, so `rep(NA, 0)` never occurs. The
`any(!is.na(tab$id))` gate plus F4's `m2` guard handles the mixed case where one member
carries `airp_id` and another does not. Only cosmetic residue: `paste(tab$serial,
tab$camera)` stringifies NA, so a duplicate key whose two rows agree on serial while one
has a blank camera is reported as a conflict. That is a spurious warning, not wrong data.

**F4 — NA keys.** Covered on both sides of both joins: `fly_patb_key()` returns
`NA_character_`, `m[is.na(key_frame[rows])] <- NA_integer_` guards the photo side of the
roll/frame match (an NA can no longer arrive from the archive side, so the symmetric
guard is unnecessary there), and `m2[is.na(id_frame[rows]) | is.na(tab$id[m2])]` guards
**both** sides of the id match. The only remaining site of the pattern in the repo is
`data-raw/make_testdata.R:264`, above.

**F5 — no extension filter.** Directories are not a hazard: `utils::unzip(unzip =
"internal")` returns extracted **files** only (measured against a zip with a nested
directory), and a directory path handed to `readLines()` raises anyway and is caught.
Binary members parse to a refusal string, and the `.ori` member in the bundled zip was
confirmed to reach `"parsed, but its columns match no PAT-B schema this version knows"`
rather than a filename check — the fixture is doing its stated job. The one leak is the
unguarded `grepl()` on line 89, above. `read.csv()` now reads every member in full;
`.ori` members are line-per-frame text so that is bounded, and worth leaving as is.

## Tests (priority 6)

No vacuous guards found. The four the author verified go red (F1 `"Could not download"`,
F3 two-member conflict, F4 unusable frame number and all-NA `airp_id`, F5 `.dat` member)
each drive `fly_camera_patb()` end to end rather than a helper, which is the right level
— `code-check.md`'s rfp#243 row is about exactly the opposite. Two notes, neither a
defect:

- `"the added columns reach a tibble-backed caller"` sets every `patb_georef_url` to
  `NA`, so it exits at the `!length(want)` early return and only exercises
  `fly_patb_attach()`. That *is* the function under test for fly#35, so the sweep is
  valid — but it never runs the class axis through the main loop.
- `"an unreadable archive..."` greps an OR (`could not be unpacked|none of them a PAT-B
  table`), so it cannot distinguish which arm fired. Tightening it to
  `"could not be unpacked"` would pin the outcome F2 added.

Not covered by any test: the `"could not be read"` and `"is empty"` arms of
`fly_patb_read_one()`, and the parse-warning arm that finding 1 is about.
