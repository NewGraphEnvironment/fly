# fly#50 Phase 2 — staged-diff review, round 1

Reviewed: `data-raw/make_camera_formats.R`, `inst/extdata/camera_formats.csv`,
`tests/testthat/test-camera_formats.R` (staged only; `R/fly_camera_format.R` and
`R/fly_footprint.R` are modified-unstaged and out of scope).

The intended change is correct and the label fix reproduces exactly. Three findings, none
blocking; the first is the one worth acting on.

---

## Findings

### 1. [fragile] `data-raw/make_camera_formats.R:368–388` — the `disagree` diagnostic is silent on precisely the case that reintroduces the fly#50 bug

`camera_name()` falls back to `camera_name_text()` whenever `serial_family()` returns
`NA` — which includes any Vexcel serial whose prefix is not one of the six in
`SERIAL_FAMILY`. Measured against the new function:

```
UC-Ep-1-1     -> NA      (UltraCam Eagle Prime, non-II)
UC-F-1-1      -> NA      (Falcon, non-M2)
UC-Xp-1-1     -> NA
UC-Osprey-1-1 -> NA
```

Those rows are then labelled by the whole-report text scan — the exact mechanism that
produced the `70912643_2015` mislabel.

The new diagnostic cannot see it. `disagree[i]` is set only when
`!identical(from_text, parsed$camera[i])`, and on the fallback path
`parsed$camera[i]` **is** `from_text`, by construction. So the block reports where the
serial route *worked* (the safe case) and stays silent where it *did not* (the risky
case). The comment's claim — "it is how the `70912643` mislabel would have been caught
the first time" — is true only because that serial happens to be in
`SERIAL_FAMILY` today; it does not generalise to the next UC body the catalogue adds.

Nothing else covers the gap either: a non-UC body (PhaseOne, AIC Pro) falls through both
routes to `camera = NA` and is caught downstream by the structural test, but an
*unrecognised UC* serial produces a confident, plausible, possibly-wrong label with no
message on any regenerate.

One line closes it, beside the existing block:

```r
unknown_uc <- !is.na(parsed$report_serial) &
  grepl("^UC-", parsed$report_serial) &
  is.na(vapply(parsed$report_serial, serial_family, character(1)))
if (any(unknown_uc)) {
  message("  UC serial not in SERIAL_FAMILY, label fell back to the text scan: ",
          paste(parsed$report_serial[unknown_uc], collapse = ", "))
}
```

(Reference: `code-check.md`, "A guard that fails toward pass" — the error path and the
nothing-to-report path are indistinguishable.)

### 2. [fragile — low] `data-raw/make_camera_formats.R:287` — the comment names the wrong guarantee, and the property it names would not hold

> `# The prefix is anchored, so \`UC-SXp-\` cannot be matched by the \`UC-SX-\` entry.`

Anchoring is not what prevents the shadow. `UC-SXp-1-70912643` does not contain the
substring `UC-SX-` anywhere, so an unanchored `UC-SX-` would also miss it. What actually
does the work is the **trailing hyphen** in every pattern: drop it (`^UC-SX`) and the Xp
serial matches the X entry, and since `serial_family()` takes `which(hit)[1]` — first in
declaration order, not longest-match — the answer would then depend on the order of the
vector rather than on specificity.

Verified as written: all six patterns are mutually exclusive over both the 11 real
serials and hypothetical `UC-Ep-`/`UC-E-`/`UC-Eagle-`/`UC-EpII-` cases, so today's
behaviour is correct. The risk is that the comment invites a later editor to relax the
trailing `-`. Say the hyphen is load-bearing, or make the selection order-independent
(longest matching prefix).

### 3. [low] `tests/testthat/test-camera_formats.R:199` — the premise comment miscounts

> `# spans four, UltraCamXp two and DMC III two.`

`UltraCam Eagle` spans **five** `calib_file` rows, not four —
`20814295_2013/_2014/_2016/_2017` plus `50311261_2014`. Measured:

```
DMC 1 · DMC II 1 · DMC III 2 · UltraCam Eagle 5 · UltraCam Eagle M3 1 ·
UltraCam Falcon M2 1 · UltraCam X 1 · UltraCamXp 2      (max = 5)
```

The assertion itself (`expect_gt(max(table(calib$camera)), 1L)`) is unaffected.

---

## Checklist items verified clean

**1. No silent label changes.** Ran the new `serial_family()` / `camera_name()` against
the 14 `calib_file` PDFs in `data-raw/.cache/pdf`. Every shipped label is reproduced
exactly; the only serial↔text disagreement in the whole set is the intended one:

```
key              shipped              camera_name()        text says
121201_2011      DMC II               DMC II               DMC II
20114172_2019    UltraCam Falcon M2   UltraCam Falcon M2   UltraCam Falcon M2
20814295_2013    UltraCam Eagle       UltraCam Eagle       UltraCam Eagle
20814295_2014    UltraCam Eagle       UltraCam Eagle       UltraCam Eagle
20814295_2016    UltraCam Eagle       UltraCam Eagle       UltraCam Eagle
20814295_2017    UltraCam Eagle       UltraCam Eagle       UltraCam Eagle   (UC-E-)
20814295_2018    UltraCam Eagle M3    UltraCam Eagle M3    UltraCam Eagle M3
20910461_2016    UltraCamXp           UltraCamXp           UltraCamXp
40112365_2015    UltraCamXp           UltraCamXp           UltraCamXp
50311261_2014    UltraCam Eagle       UltraCam Eagle       UltraCam Eagle
70912643_2015    UltraCam X           UltraCam X           UltraCamXp   <-- intended
dmc100039_2006   DMC                  DMC                  DMC
dmc327542_2017   DMC III              DMC III              DMC III
dmc327550_2018   DMC III              DMC III              DMC III
```

So a regenerate changes one field and prints exactly one override line — no dilution of
the signal, and no other row moves.

**2. Prefix shadowing.** Each of the 11 real serials matches exactly one pattern
(probe run per-pattern, not just via `which(hit)[1]`). `^UC-SX-` does not match
`UC-SXp-…`; `^UC-E-` does not match `UC-Eagle-…` or `UC-EpII-…`. `which(hit)[1]` is
therefore order-independent over the current set. See finding 2 for the caveat.

**3. `disagree` edge cases.** `report_serial()` always returns length 1 (`m[1]` or
`NA_character_`), so `if (is.na(serial))` is safe. `fs::dir_ls()` is only called on
`parsed$key`, whose cache directories are guaranteed to exist because `parse_one()` just
read them, so the un-`tryCatch`ed `dir_ls` cannot hit a missing path. On
`pdfs == character(0)`: `fs::path_file(character(0))` is `character(0)`,
`character(0) == "x"` is `logical(0)`, `pdfs[logical(0)]` is `character(0)`, and
`!length(hit)` returns `NA_character_` — correct. Every branch of the vapply body returns
a length-1 character. `nrow(parsed) == 0` gives `character(0)` and
`any(!is.na(character(0)))` is `FALSE`. No duplicate PDF basenames exist under any key
dir, so `hit[1]` reads the same file `parse_one()` did.

**4. Neither new test passes vacuously.** Confirmed by restoring the defect
(`sed` the CSV row back to `UltraCamXp`, run, `git checkout --` to restore from the
index):

```
10  one camera label means one sensor                     1 failure
        actual[4:7]: 1 1 1 2  /  expected: 1 1 1 1
11  the label invariant fires on the mislabel             2 failures
        "UltraCam X" %in% calib$camera  -> FALSE
        all(n_formats(calib) == 1L)     -> FALSE
```

Both go red on the restored bug and green on the fix (`NOT_CRAN=true test_file()`, 11/11
tests passing, 0 skipped). The `expect_gt(max(table(calib$camera)), 1L)` premise does
guard the tautology case: on an empty `calib` it evaluates `max(table(character(0)))`
= `-Inf` and fails before the vacuous `expect_equal(integer(0), integer(0))` can pass.
The memoisation comment is accurate (`fly_camera_cache` is a namespace `new.env`), and
R copy-on-modify means `broken$camera[...] <- ` cannot reach it.

**5. CSV diff scope.** `--numstat` is `1 1`; a full `diff` of `HEAD:` against `:` shows
one changed line and only the `camera` field within it. `camera_formats_manifest.csv`
carries `key` + `retrieved` only, so it pins nothing that this change moves;
`camera_formats_excluded.csv` is untouched and none of its four rows collide with the
new label.

**Downstream label safety.** `fly_camera_label()` normalises `"UltraCam X"` →
`ultracamx` and `"UltraCamXp"` → `ultracamxp` — distinct, so the new label cannot
collide with the Xp under the exact-match resolver.
