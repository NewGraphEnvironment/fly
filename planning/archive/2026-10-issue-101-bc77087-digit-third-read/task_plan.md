# Task: Settle the disputed height digit on bc77087's logbook page 1 (#101)

`bc77087` page 1 (`data-raw/.cache/logbooks/bc77087__bc77087_1.jpg`, frames 1-60, "Swan Lake Grinrod") writes a TRUE HEIGHT whose first digit is disputed.
- fly#93's blind reader read **3.8**, which matches the catalogue's 1,158 m.
- fly#97's blind reader declined to choose, leaning **7.8**: a flat top and a single descending stroke.

Read as 7,800 ft (2,377 m), the median over the 57 frames of the height less MRDEM is 1,114 m, within 4% of 1,158 m. So the generator's relation would be `ground_plus` and W2 `ground`. fly#97's rule would then stop for a decision on the package's shape. 2,377 / 1,158 = 2.05 is close to the x2 slip, so the page alone would not settle the datum.

See `inst/notes/terrain-correction.md`, "What the frames under the terrain covered".

**Decided at this gate:**
1. If the read settles 7.8, record it and don't apply it. `fly_footprint()` is untouched and the shape
   decision goes to a new issue.
2. The third read is a blind subagent only.

## Phase 1: Fix the rule before any read (committed before the reader is spawned)

As approved; where it differs from findings.md's Amendment A1 (reader type, page set, gate, crops, scoring),
findings.md is the authority.

- [x] Write the pre-registered rule into `findings.md`. It records what is already known and not blind
      (both prior reads, the catalogue's 3,800 ft, `bc77070` read clear at 3,800 ft as context only, and
      the provincial-copy probe). It then fixes the instrument, gate, verdict and outcomes below.
- [x] **Instrument.** A fresh general-purpose subagent, told not to spawn and not to open anything but
      the images in its directory. It gets:
      - `bc77087_1`-`_5` and `bc77070_1`-`_3` (`bc77070_4` withheld before any read: it names the same
        project and place at a clear 3.8; see findings.md).
      - Each page whole, plus four mechanical 2× Lanczos quadrant crops of each page, so no one line is
        singled out.
      - The fly#93/#97 brief (`rows.csv` only, no `strips.csv`), plus `leading_digit_confidence` and
        `leading_digit_alternatives` columns that it fills on **every** height entry, so the target is
        one decoy among many.
      - **Stage B**, only after `rows.csv` is written: for each height whose leading digit it did not
        mark `clear`, compare it with every 3 and 7 the same hand writes on these pages (dates, the roll
        number, frame numbers, headings). It cites each reference (file plus where on the page), says
        whether the hands match, and writes `glyphs.csv` plus a verdict.
      - No catalogue value, prior read, issue or note reaches it.
- [x] **Control gate.** The reader must reproduce every existing `clear` height row on the nine pages
      (`data-raw/flying_height_logbooks.csv` rows 657-665 and the `bc77070` rows) exactly, after fly#93's
      `consolidate.R`. Any miss voids the read: verdict `unsettled`.
- [x] **Verdict.** Settled only if the reader **commits** to the leading digit of the `bc77087_1`
      line-1 height. A commit is `clear`, or a Stage B decision citing at least one same-hand reference
      glyph that it judges written by the same hand.
      - Commits to 3: settled at **3.8**.
      - Commits to 7: settled at **7.8**.
      - Anything else (declines, leans without committing, reads another digit, fails the gate):
        **unsettled**.
      - The rule counts no lean, whether fly#97's or the reader's own.
      - The limitation is recorded: all three readers are the same model family, so these are not three
        independent human reads.
- [x] **Outcomes, fixed now:**
      - **3.8:** edit the note column of row 656 only, and `height_ft_interpreted` stays 3800. Both
        generators re-run and their outputs must be byte-identical. Prose moves from "contested" to
        "settled at 3.8 by a third blind read".
      - **7.8:** row 656 becomes `7.8` / `7800` with the three reads in its note. Re-run
        `height_calibrate-lower_tail_rolls.R` and `height_measure-image_overlap.R`, and ship the regenerated
        `flying_height_above_ground.csv` and `flying_height_image_overlap_*.csv`. The A2(5) stop is answered
        by an issue on the package's shape (fly#95: near ×2, ambiguous). **If `flying_height_rolls.csv`,
        `_excluded.csv` or anything `fly_footprint()` reads changes, stop and ask**, because this outcome
        promised no package behaviour change.
      - **unsettled:** row 656's note records the third read. The value stays 3.8, as now. Prose says
        three reads. The draft request to the province is the remaining route.
- [x] Commit the rule (with the brief and the crop script) before spawning the reader.

## Phase 2: The third read (as amended by findings.md, Amendment A1 — findings.md is the authority)
- [x] Amend the rule from the plan review (A1) and commit it before the reader directory is built
- [x] Build `<scratchpad>/pages_q` from the committed `transcription/make_reader_dir.sh` (bc77087_1-_5, 50
      images); record md5s in findings.md
- [x] Spawn the Plan-type reader unnamed with Stage A; write its `rows.csv` verbatim; hash it; send Stage B;
      write `glyphs.csv` and `verdict.csv` verbatim. Copy all three to `planning/active/transcription/reader/`
- [x] Run `transcription/audit.py` on the transcript, then `transcription/score.R`; record the verdict per
      the rule, figures read off the files, in findings.md

## Phase 3: Ship the outcome the rule names
- [x] Edit `data-raw/flying_height_logbooks.csv` file line 656 (`bc77087_1`, `frame_from == 1`) per the outcome.
- [x] Re-run the two generators from a frozen copy and `cmp`/`diff` every `inst/extdata` output they
      write against `main`. Expect byte-identical on 3.8 and unsettled. On 7.8, expect changes confined
      to the `bc77087` rows. Otherwise stop.
- [x] Rewrite every copy of the claim at once:
      - `inst/notes/terrain-correction.md`: about line 898 ("38 of the 107"), 979, 997, the "`bc77087`
        rests on a contested read" block (about 1032-1048), and "What it leaves" (about 1052-1060). Also
        fly#95's "as transcribed" in the logbook-relation table text (about 815-835).
      - `NEWS.md`: a new development entry; the released 0.23.2 entry is not edited.
      - Under 7.8, also every aggregate the review lists (`review-plan.md`, "Copies Phase 3 misses").
      - `CLAUDE.md`: the fly#97 paragraph ("`bc77087`'s page 1 reads 3.8 or 7.8") and fly#95's "as
        transcribed / `bc77087`'s disputed digit".
- [x] Update the tests that pin this prose: `tests/testthat/test-fly_footprint_image_overlap.R` (about
      lines 340-400, including the 7,800 ft counterfactual test, which stays as a recomputation under
      3.8/unsettled or becomes the shipped case under 7.8) and `test-fly_footprint_above_ground.R` if its
      logbook columns move. Add a test that reads row 656 and pins its value and the three-reads note.
- [x] On 7.8: open the shape-decision issue (repo-internal). On every outcome: update the bodies of
      fly#99 and fly#95 where they cite the contested read. Put the province draft in the archive and
      in the final report, unsent.

## Phase 4: Verify and close
- [ ] `NOT_CRAN=true` full `devtools::test()`, run with the tree committed; `lintr::lint_package()`.
- [ ] `/code-check` on each commit. Reviewers enumerate every copy of the bc77087 claim (note, NEWS,
      CLAUDE.md, tests, issue bodies) against its producer.
- [ ] `/planning-archive` (README with the measurement: three reads and the verdict). Then `/gh-pr-push`.

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
