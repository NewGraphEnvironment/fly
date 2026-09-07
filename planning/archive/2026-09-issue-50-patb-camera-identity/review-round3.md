# Review round 3 — fly#50 (`50-resolve-inferred-format-from-patb-camera`)

Full suite green at the time of review: **PASS 1454, FAIL 0, ERR 0, SKIP 0**.
`devtools::document()` produces no diff; `pkgdown::check_pkgdown()` clean; `lintr` adds no
new hits beyond the installed-vs-source artifacts the conventions already name.

Every finding below was reproduced by running it, not by reading. Probe scripts are inline
in the descriptions.

---

## Mechanism

**Two states that need different responses are given one representation, and the code
branches on that representation while the fact that separates them is already computed
and unread.**

Every round-1 and round-2 finding is one instance:

| round-2/1 finding | the two states | the value that collapsed them | the discriminator that existed |
|---|---|---|---|
| `match()` treats `NA` as a value | "this frame has no id" / "the archive published no id" | `NA` on both sides of `match()` | `is.na()` on each side |
| ties kept, `s[1]` read | a tie set / one arbitrary member | the first element | the set the producer already returned |
| `warning()` gated on `quiet` | a progress line / a claim about the data | one `quiet` flag | which of the two the message is |
| unreadable archive reported as "no camera identity" | "the province published nothing" / "this machine could not read it" | `list()` | the unzip condition |
| `file.exists()` on a cached download | "present" / "complete" | the dirent | `file.size()` |
| the disagreement diagnostic blind to its own branch | two independent readings / one reading compared with itself | `camera_name()` == `camera_name_text()` by construction | whether `serial_family()` answered |
| "anchoring is what stops the shadowing" | the stated guard / the operative guard | one comment | the trailing hyphen |
| "four" where it is five | a restated count / a re-derived one | prose | the table |

The corollary is what makes the class findable: **the discriminating fact was available at
the point of the collapse in every single case** — the exit status, the `success` column,
the file size, the tie set, the serial route, the trailing hyphen. So the sweep below is
not "look for more absences"; it is: *at each site where one value stands for two states,
name the discriminator and check whether it is read.*

---

## Enumeration — every site in this branch the mechanism reaches

| # | site | the two states | discriminator | verdict |
|---|---|---|---|---|
| 1 | `R/fly_camera_patb.R:239` `is.na(dest) \|\| !file.exists(dest)` | download failed / archive holds nothing | `fetched$success`, one line away | **OPEN — F1** |
| 2 | `R/fly_camera_patb.R:64-70,86-90` `fly_patb_read_one()` → `NULL` on the **non-zip** path | 404 body / corrupt / unreadable / unknown schema | the `error` attribute — built on the zip branch only | **OPEN — F2** |
| 3 | `R/fly_camera_patb.R:106-107` zip whose members all fail to parse | "no camera identity" / "every member failed to parse" | same | part of F2 |
| 4 | `R/fly_camera_patb.R:273-287` duplicate-camera warning | conflict **within** a table (warned) / conflict **across members** (silent, last wins) | `source[hit]` is already non-`NA` | **OPEN — F3** |
| 5 | `R/fly_camera_patb.R:50-53` `fly_patb_key()` | "no frame number" / the literal key `"NA"` | `is.na()` **before** the `paste0()` | **OPEN — F4** |
| 6 | `R/fly_camera_patb.R:76-77,105` `.ori` skip | "skipped by failing to dispatch" / skipped by an extension allowlist | the code | **OPEN — F5** |
| 7 | NEWS.md:10 / CLAUDE.md:118-121 / `inst/notes/camera-formats.md:195-197` | 4,066 m "exterior orientation" / findings.md's 32.1 cm ⇒ 4,633 m | findings.md | **OPEN — F6** |
| 8 | `inst/notes/camera-formats.md:139` schema table | "`lens_no` is 0 … 2011, 2012" / findings.md's `d_004_fi_11` `lens_no` = 100044 | findings.md | **OPEN — F7** |
| 9 | `match(id_frame[rows], tab$id)` NA-on-both-sides | fixed R2 | `is.na()` both sides | ✔ verified in code and by its test |
| 10 | `fly_serial_tokens()` ties vs `s[1]` | fixed R2 | every token looped | ✔ probed: `100039-327542` and `327542-100039` both → `ambiguous_serial:` |
| 11 | `quiet` vs the conflict `warning()` | fixed R2 | ✔ test asserts it fires under `quiet = TRUE` |
| 12 | `fly_fetch()` zero-byte cache skip | fixed R2 | `file.size()` | ✔ |
| 13 | `data-raw/make_camera_formats.R` `patb_get()` | fixed R2 | `file.size()` + `stopifnot` | ✔ |
| 14 | generator `disagree` / `unmapped` diagnostics | fixed R1 | `serial_family()` returning NA | ✔ — `unmapped` is gated `^UC-`, which the comment states |
| 15 | `fly_footprint.R:673` `refused` as the complement, not a prefix list | — | — | ✔ this is the mechanism applied correctly; it is what keeps `unknown_serial:` / `ambiguous_serial:` reaching the caller |
| 16 | `via` returned rather than re-derived (`fly_camera_format.R:133-136`) | fixed R1/R2 | ✔ probed: serial `"0"` → `via = "camera"` |
| 17 | withheld gate on `matched`, not a fresh predicate | — | ✔ tested; probed |
| 18 | `unknown_serial:` note names only `s[1]` | set / first member | reached only when **every** token is unknown, so the first is a fair representative | accepted, message-only |
| 19 | `agree()` compares dimensions, not the `camera` label | two agreeing rows with different labels | only dimensions are consumed downstream | accepted |
| 20 | `fly_patb_schema()` first-match order (gr, eop, bare) | a file carrying both `cam_s_no` and `camera` takes `eop` and drops the name | not reachable in the three measured schemas | noted |
| 21 | serial `"12"`/`"00"` → the name route | "present but unknown" (refuses) / "not recorded" (reads the name) | `nchar >= 3 & !^0+$` — stated in the code comment, but NEWS/roxygen say "no serial at all" | noted, deliberate |
| 22 | `quiet = TRUE` still prints `fly_fetch()`'s "Downloaded N of M" | noise only | — | noted |
| 23 | per-row resolve loop at production scale | — | measured 15.2 s for 41,249 rows, slightly super-linear (1.4e-4 → 3.7e-4 s/row); bounded by the population | **not a finding** |

**Does anything sit above its source of truth?** Two things, and both are prose:

- **F6** — three shipped artifacts (NEWS, CLAUDE.md, and `inst/notes/`, which ships inside
  the installed package) assert a number whose only ancestor is `planning/active/review-50.md`,
  and it contradicts the measurement in `findings.md`. This is `karpathy.md` §7's
  "documents that share an ancestor corroborate nothing" with the ancestor being a review
  note rather than the artifact.
- **F5** — the extension allowlist sits above the "dispatch on columns, not on the
  extension" claim made in the roxygen, the notes, NEWS and two code comments.

Everything else that could sit above its source is derived: 41,249, 22,366 (= 4,822 +
2,827 + 14,717), 18,883 (= 41,249 − 22,366), 24,742 (= 17,093 + 7,649), 14,717, 1,790,
5,193 / 4,329 / 5,002 m, "five rows / four agreeing" (verified against the built index:
`report[["20814295"]]` = 4 rows, `key[["20814295"]]` = 5), and the three thumbnail aspects
(1.5305 / 1.5319 / 1.5298 against 1.5306 / 1.5306 / 1.5293, all inside the 2e-3 tolerance).

---

## Findings

### F1 — **[fragile]** `R/fly_camera_patb.R:238-253` — a failed download is reported as "the province published nothing", and `fetched$success` is right there

```r
dest <- fetched$dest[match(u, fetched$url)]
tables <- if (is.na(dest) || !file.exists(dest)) list() else fly_patb_tables(dest)
```

`fly_fetch()` returns `dest` **whether or not the download succeeded**, and it returns a
`success` column beside it that this caller never reads. Measured against an unreachable
host:

```
MSG: Downloaded 0 of 1 files
MSG: No PAT-B table in d_zzz_georef.csv - it holds no camera identity
     (a 404 body, or `.ori` only). 1 frame(s) left unresolved.
```

That is exactly the round-2 finding — "an unreadable archive told the operator to go and
look at the catalogue" — in the branch the round-2 fix did not cover. The round-2 fix added
an `error` attribute inside `fly_patb_tables()`; it cannot describe a file that was never
fetched, because `fly_patb_tables()` is not called on that path.

Read `fetched$success` and say "could not be downloaded" when it is `FALSE`.

### F2 — **[fragile]** `R/fly_camera_patb.R:64-70, 86-90` — the same misattribution for a bare (non-zip) archive, and for a zip whose members all fail to parse

`fly_patb_tables()` returns an `error` attribute only on the zip branch (`dir.create`
failure, `unzip` failure). The non-zip branch returns a bare `list()`, and so does a zip
whose members all fail `fly_patb_read_one()`. Both then print the province-facing message.
Measured, with a corrupt bare `.csv` already sitting in `dest_dir`:

```
MSG: No PAT-B table in d_zzz_georef.csv - it holds no camera identity
     (a 404 body, or `.ori` only). 1 frame(s) left unresolved.
Warning: unable to translate '<ff><fe>' to a wide string
Warning: line 1 appears to contain embedded nulls
```

`fly_patb_read_one()` collapses five distinguishable outcomes into `NULL`: an HTML body (a
real 404 — the message is right), a `read.csv` error (a disk or encoding problem — the
message is wrong), zero rows, an unrecognised schema (a province-side change worth naming
on its own), and an unreadable file. The two that matter are already separable at the point
of the collapse: `tryCatch(..., error = )` knows it caught an error, and
`fly_patb_schema(d) == NULL` on a frame that *did* parse is "the province changed a schema",
which is a different report again.

### F3 — **[bug]** `R/fly_camera_patb.R:256-309` — two members of one archive naming the same frame silently pick the last one, while the same conflict *inside* one member warns

The duplicate-key guard (L273-287) is scoped to a single table. The loop is
`for (d in tables)`, and each table writes `serial[hit] <- ...` over whatever the previous
table wrote, with no comparison and no warning. Which member wins is decided by
`utils::unzip()`'s member order — that is, by the order the province happened to write the
archive, which is the same "decided by position in arbitrary provincial text" the round-2
`s[1]` fix removed.

Measured, one zip with two members naming frame `bcd12001_001` as an UltraCam XP and an
UltraCam X:

```
resolved camera_name: Vexcel Ultracam X
members in zip:       aa_georef.csv, zz_georef.csv
px_cross:             14430          # the XP is 17310 — 20% of ground width
```

No warning. The in-table guard's own comment says why this must not be silent: *"the
arbitrary pick can be the same 20%-wrong sensor the serial-before-name rule exists to
refuse."* The premise that makes it reachable is the code's own: L74-75 parses **every**
member precisely because "nothing establishes that an archive holds one georef table."

Either warn when a later table overwrites a row that already has a `patb_source` and
disagrees, or build one `tab` from all the members and let the existing duplicate-key guard
see the conflict.

### F4 — **[fragile]** `R/fly_camera_patb.R:50-53` — `fly_patb_key()` turns an unusable frame number into the literal string `"NA"`, so the round-2 `is.na()` guard cannot see it

```r
fly_patb_key <- function(roll, frame) {
  paste0(tolower(trimws(as.character(roll))), "_", suppressWarnings(as.integer(frame)))
}
```

`paste0()` stringifies `NA` to `"NA"`, so:

```
key of NA frame  : bcd12001_NA
key of bad frame : bcd12001_NA     # sub(".*_", "", "bcd12001_xxx")
```

Both sides of the join go through this function, so a photo with a missing `frame_number`
matches an archive row with an unparseable one, in the same roll. Measured:

```
NA-frame photo resolved to: Vexcel Ultracam XP / d_001_fi_12_georef.csv
```

with `inferred = FALSE` — a confident wrong camera. This is the round-2 `match()`-NA finding
arriving through `paste0()` instead of through `match()`, which is why the guard added for
`airp_id` (L299, `m2[is.na(id_frame[rows]) | ...] <- NA_integer_`) structurally cannot
cover it: by the time `match()` runs, the value is not `NA` any more, it is three
characters.

Reachability is genuinely narrow — `frame_number` is `integer` and non-`NA` in both bundled
layers, so it needs a catalogue row with a null frame number *and* an archive row whose
frame suffix does not parse. The stronger form is a roll using alphanumeric frame numbers
(`012A`), which collapses **every** frame of that roll onto one key on both sides. One
line closes it: return `NA_character_` when `is.na(as.integer(frame))` or
`is.na(roll)`, and let the `match()` miss.

### F5 — **[fragile]** `R/fly_camera_patb.R:76-77` and `data-raw/make_testdata.R` — `.ori` members are excluded by an extension allowlist, not by "failing to dispatch", and the fixture element added to prove otherwise cannot be exercised

The comment says:

> `.ori` / `.ORI` members carry full exterior orientation and no camera identity at all,
> and are **skipped by failing to dispatch rather than by matching their name**.

The code five lines later:

```r
members <- members[grepl("\\.(csv|txt)$", members, ignore.case = TRUE)]
```

That is an extension **allowlist** — `.ori` never reaches `fly_patb_schema()`. Measured
against the bundled `d_003_fi_13_georef.zip`: the only member kept is
`d_003_fi_13_georef.txt`. So `data-raw/make_testdata.R`'s rationale for the stub member —
*"Its presence is what proves the parser skips it by failing to dispatch rather than by
matching a filename"* — is false; the fixture proves nothing, in the round-1 shape (a
diagnostic that cannot reach its own risky branch).

It also has a live consequence, because the "dispatch on columns, not on the extension"
claim is a headline of this release (roxygen L142-145, notes, NEWS, findings). Measured: a
georef table under a third extension dispatches correctly *on its columns* and is still
dropped before dispatch —

```
schema dispatch on the .dat content -> TRUE
resolved?                            -> FALSE
```

— and it is dropped with F2's misattributing message. The province has already used two
different extensions for two different schemas, which is the repo's own argument for why an
extension cannot be trusted to identify a member.

Either keep the allowlist and fix the three claims (the filter is the operative guard; the
dispatch is the fallback), or drop the filter and let dispatch do the work it is documented
as doing — reading an `.ori` through `read.csv()` and failing to dispatch is what the
comment already asserts happens.

### F6 — **[bug]** `NEWS.md:10`, `CLAUDE.md:118-121`, `inst/notes/camera-formats.md:195-197` — the DEM-comparison numbers contradict `findings.md` and reverse the direction of the residual

All three say:

> Measured on the 2012 UltraCam X: **4,329 m against 4,073 m before**, where sizing from
> full exterior orientation gives **4,066 m** … but the stated GSD is *nominal* —
> `agl x pitch / focal` gives **32.1 cm** on those frames against a stated 30 — so the
> residual is now a known quantity rather than a surprise.

Those two halves cannot both be true, because *exterior-orientation ground width is
`px_cross x (agl x pitch / focal)`* — the same arithmetic as the implied GSD in the second
half. From `findings.md`'s own row for `d_002_fi_12` (agl 4481.6, pitch 7.2 µm, focal
100.5 mm, `px_cross` 14430):

```
implied GSD = 4481.6 * 7.2e-6 / 0.1005 = 0.3211 m   ( = the stated 32.1 cm  ✓ )
width       = 14430 * 0.3211            = 4,633 m   ( not 4,066 m )
```

So the shipped GSD footprint of 4,329 m is **6.6% narrower** than exterior orientation —
which is what `findings.md:184` concludes ("a footprint 7% narrow on those 2,827 frames").
NEWS/CLAUDE/notes present 4,329 m as **6.5% wider** than a 4,066 m truth. Same frames,
opposite sign, on the sentence a reader uses to decide whether to trust the new footprint.

The two published numbers are internally consistent with each other at an `agl` of about
3,935 m, against the 4,481.6 m the archive itself publishes — a 12% gap that is itself
either a finding or a mis-measurement. `4,066` and `4,073` appear nowhere but
`planning/active/review-50.md`; neither is derivable from `findings.md` or from the code.

Re-measure on the frames, or state the residual the way `findings.md` does and drop the
two numbers.

### F7 — **[fragile]** `inst/notes/camera-formats.md:139` — the schema table says the bare-CSV `lens_no` is 0 for 2011 as well as 2012, which `findings.md` contradicts

| schema | key | camera identity | GSD | where |
|---|---|---|---|---|
| bare CSV | … | `camera` string; **`lens_no` is 0** | `gsd` | **2011, 2012** |

`findings.md:36` measures `d_004_fi_11` (2011, 11,826 frames) with `lens_no` = **100044**,
and `findings.md:76` refuses those 11,826 frames *because* that serial is present and
unknown. The prose two sections down gets it right ("`lens_no` is 0 on every row of both
**2012** archives"); the table generalises it to 2011 and so describes the largest refused
population as taking the name route it is in fact excluded from. Restrict the cell to 2012.
