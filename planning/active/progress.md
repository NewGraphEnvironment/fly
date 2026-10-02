# Progress — Infrared film (Film - BW IR, Film - Colour IR) is sized as an unknown format (#89)

## Session 2026-10-02

- Plan-mode exploration — phases approved by user ("Go all phases")
- Gate decision: the four data-raw scripts that call `fly_film_media()` are pinned to the
  set their shipped tables were measured over
- Created branch `89-infrared-film-film-bw-ir-film-colour-ir` off main
- Scaffolded PWF baseline from issue #89 with approved phases
- Next: Phase 1, pre-register the rule
- Phase 1: rule pre-registered in `findings.md` before any IR spacing, thumbnail or logbook
  content was read; reference figures for W2 read from the BW/colour sweep (254 film frames,
  aspect max 1.0056, collar 0-0.0707)
- Phase 2: `data-raw/format_measure-infrared_film.R` written; smoke then five full runs (1-2 halted; 3 completed under the registered rule; 4-5 under the amendment)
  (`data-raw/.cache/irfilm_run{1..5}.log`). Run 1 fired the registered rule (W1 contradicts on
  bcf07060, bci3, bci95063, bci96066); escalated; user approved amendment 1 (findings.md).
  Runs 4-5 under the amendment (run 5 adds round-1 fixes and wrote the shipped CSVs, identical
  to run 4's): W1 27 pass / 1 ambiguous (bcf517) / 4 fits_no_format; W2 4 pass; W3 6 pass /
  11 unrecognised; decision add for both media values
- Phase 3: 27 logbook pages read by hand into `data-raw/infrared_film_logbooks.csv`; every
  serial-only page names a camera body that also flew BW/colour rolls sized at 9 in
- Ships five `inst/extdata/infrared_film_*.csv`; `test-fly_footprint_infrared.R` recomputes
  them (28 pass before Phase 4, the `fly_film_media()` tie failing as intended; 29 after)
- Code-check: four rounds (`review-round{1..4}.md`) plus the plan review (`review-1.md`); five
  reviewer agents in all. Rounds 2-4 each found published claims that dropped a producer's
  scope, rounds 3 and 4 inside the previous round's fix; ended by enumeration — every figure in
  the final fix text now has a producer line in `data-raw/format_measure-infrared_film.R` and an
  assertion in `test-fly_footprint_infrared.R` (42 pass). Round 3 found 56 out-of-band IR frames on
  three wrong-scale roll-heights: filed fly#91, out of scope here
- Full suite before the round-3/4 test additions: FAIL 0 | PASS 4993
