# Review round 4 — fly#74 exact() fix, storage assumptions, doc figures

Reviewed in a scratch copy (generator re-run from the copy's root, 60 s; the workspace was
saved after Stage 5b and probed). The staged CSVs reproduce byte-for-byte: after the re-run,
`git status` shows no unstaged change to `inst/extdata/`. `test-fly_footprint_height_rolls.R`
passes (251, `NOT_CRAN=true`).

## 1. The fix itself — correct, nothing wrong found

- **Derivation.** A stored figure S = T − a. Rounding gives a ∈ [−0.5, 0.5] and truncation
  a ∈ [0, 1), so a ∈ [−0.5, 1). With Tb = k·Ts, B − k·s = k·b − a ∈ [−(1 + k/2), k + 1/2].
  Correct.
- **Direction.** Upper: `exact(h, sib, k)` puts big = catalogue h. Lower: `exact(sib, h, k)`
  puts big = sibling. Both correct. The test's `max(hs) − k·min(hs)` with
  `k = max(f, 1/f)` is the same in both tails.
- **Whether the looser interval admits a wrong neighbour.** I enumerated every adjacent
  neighbour of every roll-height the logbook left: 3,876 (pair, relation) rows, in band or
  not. Under the new interval, four pairs name a relation, and they are the four tabled
  factor rows. The old interval gives the same set minus `bc7675`. Outside the interval, the
  only pair within two interval widths of either bound is `bc5596` / 2,438 m under ×10.764
  (r = −30.4 against [−6.4, 11.3]). Nothing else comes near. No "different relations"
  outcome occurs at all (the refusal table has no such row), and the fix flips nothing.
- **Controls.** `bc5596` still settles from 203 and 2,438 still names nothing. `bcb98013`
  still settles on `digit`.

## 2. Storage assumptions in Stage 5b and the tests, checked against the catalogue

| assumption | where | against the data |
|---|---|---|
| Heights are integers | `digits()` (`formatC format="d"`), comment "Heights are whole metres" | Holds. `flying_height` is class integer and every value is whole. No NA in height or focal; NA `scale_n` is handled by `%in%`; no NA reaches the neighbour subset. |
| a ∈ [−0.5, 1): stored by round or truncate only | `exact()`, the test check, note step 3, NEWS, CLAUDE.md | **Incomplete, see finding D1.** A third storage exists. It fails only toward refusal, and no current outcome changes. |
| Digit relation is string identity | `relation()` | Holds only if the typo was made on the stored metre string and both frames were stored the same way (97,925 beside 7,924 would refuse). It fails toward refusal. Loosening it to ±1 on the remainder finds no additional pair: only `bcb98013` 51/53. |
| `abs(log_factor − f) > 1e-9` | `sibling()` | Safe. The two sides are the same literal expressions (1/10, 1/K, 10, 100). A digit factor `round(sib/h, 6)` can never equal a named factor, so any logbook factor vetoes a digit relation. That matches rule 5 and does not fire on current data (`bcb98013`'s page names no factor). |
| `is_f()` 1e-9 in `cause` | stage 5 | Safe for the same reason. The digit factor 0.08092 matches no named factor and falls to the `sibling_rel` arms. |

## Findings

- **[doc] `inst/notes/terrain-correction.md:418-422`, `data-raw/height_calibrate-lower_tail_rolls.R:430-435`, `NEWS.md:3` ("Exact means within what storing whole metres can move a figure, and the catalogue both rounds and truncates"), `CLAUDE.md` #74 entry, `R/fly_footprint.R:260`.** (D1)
  The interval rests on "each figure off its true value by a ∈ [−0.5, 1)". That is the same
  kind of assumption round 3 found, one level further out, and the catalogue contradicts it.
  Some figures were converted at **3.28 ft/m** and then rounded, not at 0.3048:
  - 20,000 ft: **6,098** on 2,677 frames (20000/3.28 = 6097.6), beside 6,096 on 198,669 and
    6,097 on 175.
  - 15,000 ft: **4,573** on 770 frames (4573.2), beside 4,572 on 11,903.
  - 10,000 ft: **3,049** on 106 frames.

  A figure stored this way sits a ≈ −(0.5 + 0.000256·T) off its true value: −2 at 6,096 m and
  about −7 at 26,000 m. So a genuine ×10 whose large figure came through 3.28 reaches
  r ≈ +17 against a limit of 10.5, and a ÷10 whose sibling came through 3.28 reaches about
  +12.

  **Impact today: none.** The error only widens the true interval, so it can only cause
  refusals, never a false accept. The enumeration in §1 finds no neighbour pair between
  either bound and two interval widths past it, so no outcome changes. The claim as written,
  that this is what the catalogue's storage can do, is false, and it is the premise the note
  offers as the justification. The fix is either to state the bound as covering rounding and
  truncation of a 0.3048 conversion, with 3.28-converted figures refusing, or to widen it.

- **[doc, minor] "×10.764 to 31 m" — `NEWS.md:4`, `CLAUDE.md:324`, `inst/notes/terrain-correction.md:438`, generator comment `:437`.**
  With the package's own factor, `fly_height_slip_factor()` = 3.28084² = 10.76391, the gap is
  26,212 − 10.76391 × 2,438 = **−30.4 m**, so 30 m. "31" comes from the rounded 10.764
  (30.6). The 0.12% is right (0.116%), and so is [−6.4, 11.3].

- **[doc, minor] `inst/notes/terrain-correction.md:448`: "Every other witness agrees with the sibling there."**
  On `bc7675` the logbook's height is **20,200 ft (6,157 m)** on all 34 frames it reads
  (logbook row 113–248, "20.2"). The shipped height is the sibling's 6,096 m (20,000 ft), 1.0%
  lower. The logbook agrees on the *factor* (×10, within its 2%), not on the height. Had it
  covered half the frames, the table would ship 6,157.1 m. The sentence should say "names the
  same factor", or note the 61 m.

- **[doc, minor] `vignettes/airphoto-selection.Rmd:411`: "the province's flight logbooks, or where they are silent an adjacent frame".**
  Two of the five sibling rows have a logbook that speaks:
  - `bc7675`: read on 34 frames, naming ×10.
  - `bcb98013` frame 52: its page reads 24,000 ft, which contradicts the shipped 7,924 m
    (26,000 ft) by 7.7%. The note does flag that the page may belong to another roll.

  "Where they do not settle it" would be accurate.

## Re-derived and correct

All from the shipped CSVs, the sweep, and the re-run:

- Tables and counts:
  - 33 roll-heights, 1,438 frames: 1,130 lower, 308 upper.
  - 516 excluded, 2,113 frames. Upper excluded is 1,281, every row "#54's 10.764 still
    applies", which is 1,290 − 8 − 1.
  - 5 sibling rows, 138 frames, of 521.
  - The table rows (frames, relation, from-frame, height, overlap) all match.
- Refusal counts: lower 10/486, 6/99, 36/247; upper 1/10 (`bc79027`), 463/1,271. The 463 all
  sit on `bcc03004/06/07/08/46` and `bcc05001`.
- Figures quoted for `bc5596` and `bcb98013`:
  - [−6.4, 11.3] at k = 10.764.
  - #54 widths: `bc5596` 204–211 are −10.28% to −11.23% (10.3–11.2% narrow) and `bcb98013`
    52 is +17.05% (17.1% wide), from sweep terrain.
  - 8,600 ft to 0.3 ft (0.26), and 7,989 ft, 11 ft short.
  - 212 is 8,000 ft in the logbook.
- Figures quoted for `bc7675`:
  - 6,096 − 6,090 = 6 against 5.5.
  - Logbook coverage 40%.
- Logbook reads for the other lower-tail rows:
  - `bc87070`: row "169-20?" at 13.0 = 3,962 m.
  - `bcc822`: "2300" for 120–130, between 22,500 and 23,000.
- `R/fly_footprint.R`: 308 by the roll table (299 + 9); 308 + 1,281 = 1,589; "the 10 frames
  of `bc79027`"; 1,271 on the 2003–2005 rolls.

/Users/airvine/Projects/repo/fly/planning/active/review-round4.md
