# Review round 3 — fly#59, mechanism + complete claim enumeration

Reviewed the branch as it stands at `2f0df22` (which landed mid-review; every check below
was re-confirmed against the post-commit tree). All probes ran against a byte-identical
copy in the scratchpad — `R/` and `tests/` in the live repo were never touched.

Suite on that copy: **FAIL 0, ERROR 0, SKIP 0, PASS 1880.**

---

## Mechanism

**Every sentence in this change is a restatement of a measurement taken against a draft,
and the change went through two design reversals after those measurements were written
down.** The read window moved from the counting template to `snap = "out"` (round 1); the
off-DEM handling moved from `tryCatch` to an extent test (before round 2). Each reversal
invalidated sentences that had already been copied into six files — comment, roxygen, Rd,
note, NEWS, CLAUDE.md, tests, findings, progress — and nothing binds a sentence to the code
it describes, so only the file being edited at the time got updated. That is what produced
five instances rather than one.

**The class at risk is the *justification*, not the fact.** "The read costs 64.59 s" is a
fact: it is checkable, it has a date, and it does not change when the code does. "The
template can be smaller than the footprint, *so this is reachable on real data*" is a
justification: its truth condition lives in a draft and in an inference, not in the tree, so
no amount of reading the code beside it will contradict it. Every round-2 finding was a
justification; so are three of the four findings below.

**Round 3's addition to the mechanism.** Round 2's five were sentences that *had been true*.
The largest defect still standing is a sentence that **was never true** — a reachability
argument that was reasoned from a frame's width rather than measured, and which is false by
a wide margin. The same drafting habit produces both: a justification gets written at the
moment the fix is understood, and nothing downstream ever asks it for evidence. **So the
terminating question for this class is not "is this sentence still true of the code" but
"was this sentence ever measured, and where is that measurement recorded".** Applying that
question to the 63 claims below is what produced the four findings; the third is the only
one whose measurement exists and disagrees, and the other three had no measurement at all.

---

## Enumeration

Every factual claim the change makes about behaviour. `run` = executed; `arith` = checked by
arithmetic; `consistent` = cross-checked against every other place the same number appears;
`network` = not reachable offline, checked only for internal consistency and attribution.

### `R/fly_footprint.R` — comment block in `fly_dem_sample()`

| # | claim | true? | how checked |
|---|---|---|---|
| 1 | `extract()` with no `fun` cost 64.59 s for one 1:15000 frame over `/vsicurl/` | consistent | `network`. Same figure in NEWS, note table, CLAUDE.md, findings.md — no disagreement |
| 2 | the same frame through a crop of its own window takes 0.69 s | consistent | `network`, same four places |
| 3 | both return the identical 12,616 cells and identical mean | consistent | `network`. Note's table gives 12616/609.150 for both fast forms |
| 4 | 4 HTTP GETs against 158 | consistent | `network`, four places agree |
| 5 | `fun = mean` is just as quick (0.66 s) | consistent | `network` |
| 6 | the coverage numerator needs every cell, so an aggregating extract will not do | **yes** | `run` — `got = sum(!is.na(vals))` reads the same vector as `mean()`; a `fun`-aggregated extract returns one row per frame |
| 7 | `align()` returns the same window handed the DEM or a crop of it | **yes** | `run` — 0/200 divergences, random frames 0.1–20 cells across |
| 8 | 243 million cells against 16 thousand for the two frames counted separately | **yes** | `run` — union via `fly_dem_grid` = 243,599,463; per-frame templates 8,190 + 8,100 = 16,290 |
| 9 | per-frame costs 1.23 s against 1.00 s for eight contiguous frames | consistent | `network`; `arith` 1.23/1.00 = 23% ✓ |
| 10 | a per-frame bound "cannot reproduce" the union allocation | **yes** | `run` — both windows 8,281 cells for frames 700 km apart |
| 11 | read window and template are snapped differently but both are one footprint | **yes** | `run` — see 10 |
| 12 | `align()` defaults to `snap="near"`, so the template can be smaller than the footprint | **yes** | `run` — 34 of the 40 frames in the new test have an uncontained template |
| 13 | 13 of 300 frames drawn 0.2–6 cells across on the bundled 30 m DEM disagreed | plausible, **unrecorded** | `run` — my reconstruction gives 10/300 over the same range (seed-dependent, same order). The measurement is in no PWF file — see **F4** |
| 14 | **"Reachable on real data, because a 3.4 km frame is 3.8 cells across on the 900 m DEM this file's own tests use"** | **NO** | `run` — **F1** |
| 15 | `snap="out"` is a superset of both the footprint and the template | **yes** | `run` — 0/500 real violations; 5/500 apparent ones are float noise ≤ 1.16e-10 m. findings.md's 4,000-case sweep agrees |
| 16 | `extract()` returns an NA placeholder row; `crop()` errors | **yes** | `run` — neutralising the guard errors 5 tests |
| 17 | tested on the extents, not by catching, because "crop() failed" is a proxy for "no DEM here" | **yes** | `run` — `grep tryCatch` finds none in the function; argument is sound |
| 18 | strict inequality, so extents that merely touch share no cell | **yes** | `run` — frame abutting the east edge returns `elev` NA, `covered` 0 |

### `R/fly_footprint.R` roxygen and `man/fly_footprint.Rd` (identical text; Rd is in sync — `roxygenise()` produced no diff)

| # | claim | true? | how checked |
|---|---|---|---|
| 19 | two frames take seconds rather than the minutes a whole-vector read cost before 0.13.0 | consistent | `network`; 263.4 s = 4.4 min ✓ |
| 20 | cost scales with the number of frames and never with the distance between them | **yes** | `run` — see 10 |
| 21 | **"There is nothing to gain by cropping a `/vsicurl/` raster yourself first"** | **overstated** | `run`/`consistent` — **F2** |

### `inst/notes/terrain-correction.md`, fly#59 section

| # | claim | true? | how checked |
|---|---|---|---|
| 22 | two frames took 583 s; `Rprof` 61 s sampled of 583 s wall | attributed | `network`; carried from the issue and explicitly disowned as contended two paragraphs later |
| 23 | the three-row timing table | consistent | `network` |
| 24 | "94x the wall clock and 39x the requests" | **yes** | `arith` — 64.59/0.69 = 93.6; 158/4 = 39.5 |
| 25 | 512-cell block spans 15.4 km; a 1:15000 footprint is 3.4 km | **yes** | `arith` — 512x30 = 15,360 m; 0.2286 m x 15000 = 3,429 m |
| 26 | 243 million cells for two frames 700 km apart | **yes** | see 8 |
| 27 | "13 of 300 … (an independent review round measured 52 of 300 over the same range on its own fixtures)" | **yes** | `run` — review-round1.md records 52/300 at 0.2–6 cells on random DEMs. Good reconciliation of two numbers that would otherwise read as a contradiction |
| 28 | **"That is not an exotic shape: a 3.4 km 1:15000 frame is under 4 cells across on a 900 m DEM"** | **NO** | `run` — **F1** |
| 29 | the read is snapped out, a superset of footprint and template | **yes** | see 15 |
| 30 | `crop()` to an overhanging extent clips rather than pads | **yes** | `run` — crop of dem to ext±50 km returns exactly the DEM's own extent and dim |
| 31 | "guarded on the extents and deliberately not caught" | **yes** | `run` — round-2 finding 2 landed |
| 32 | "Over 400 randomized geometries and 800 degenerate edge overlaps, no input was found where the extent test passes and `crop()` then errors" | **yes**, but **unrecorded** | `run` — 400 is review-round2.md, 800 is review-round1.md. Neither number is in findings.md — see **F4** |
| 33 | parity list (bundled / off-DEM / straddling / empty / hole / geographic / anisotropic / multi-layer / swept) | **yes** | `run` — reproduced the two I could reach offline; rest corroborated by rounds 1 and 2. **Eleven items** — see **F3** |
| 34 | "It holds wherever the frame covers at least one cell centre" | **yes** | `run` — and this is the *correct* statement of the condition that 14/28/36 state wrongly |
| 35 | "No route to it through `fly_footprint()` was found" | **yes** | bounded honestly, matches round 2 |
| 36 | **"`dem_coverage` is unaffected; only the sampled values move"** | **NO** | `run` — **F3** |

### `inst/notes/terrain-correction.md`, "Testing this" table

| # | claim | true? | how checked |
|---|---|---|---|
| 37 | new row: "invisible at 30 m, where a frame is 113 cells wide, and **live at 900 m, where it is under 4**" | **NO** | `run` — **F1**, strongest form. 113 cells is right (`arith` 3429/30.45 = 112.6); "live at under 4" is not |
| 38 | preamble now reads "nor the fly#59 window defect" | **yes** | the bundled fixture cannot reach it — 0/500 at 3.78 cells, and every bundled frame is ~113 cells across |

### `NEWS.md` 0.13.0

| # | claim | true? | how checked |
|---|---|---|---|
| 39 | "goes from 263 s to 4.3 s" | consistent | round-2 finding 4 landed; CLAUDE.md now agrees |
| 40 | **243,583,754 cells** | **yes, exactly** | `run` — `rast(ext(vect(in_dem)), resolution = res(dem))` = 243,583,754, which is precisely what the new test's mock measures |
| 41 | 1.260 s against 1.437 s for the 20 bundled frames | consistent | `arith` — 1.437/1.260 = 1.14, matching findings.md's "12% faster" |
| 42 | "13 of 300 … and a 3.4 km frame is under 4 cells across on a 900 m DEM" | **NO** (second half) | **F1** |
| 43 | **"a premise asserting the fixture can still reach the defect"** | **NO** | `run` — **F5** |
| 44 | **"planting a union-extent crop … reddens that test alone"** | **NO** | `run` — **F6** |
| 45 | "Removing the guard errors five tests, three of them pre-existing" | **yes, exactly** | `run` — 5 errors; tests 20, 29, 35 pre-existing, 36 and 38 new |
| 46 | **"identical … over nine shapes:"** followed by an eleven-item list | **NO** | `arith` — **F3** |
| 47 | "measured on a synthetic 10 x 10 grid, 96 against 95.5" | **yes** | matches review-round2.md; I reproduced the same phenomenon (60 vs 55 on my own 10x10) |
| 48 | `align()` invariant + `crop()` clips rather than pads | **yes** | see 7, 30 |
| 49 | 583 s was contended; 263 s is the quiet-link figure | **yes** | `arith` 583/263.4 = 2.21, matching findings.md's "about 2.2x" |

### `CLAUDE.md` — the #59 Key Decision and the Gotchas bullet

| # | claim | true? | how checked |
|---|---|---|---|
| 50 | 64.59 s / 158 requests vs 0.69 s / 4 requests, identical 12,616 cells | consistent | `network` |
| 51 | "went 263.4 s to 4.3 s like for like"; 583 s is an upper bound, do not quote it against a quiet-link number | **yes** | round-2 finding 4 landed cleanly |
| 52 | 23% on contiguous frames; cannot produce the 243-million-cell allocation | **yes** | see 9, 10 |
| 53 | parity "over off-DEM, **truncating**, geographic-CRS, multi-layer and anisotropic shapes — wherever the frame covers at least one cell centre" | **yes** | the "truncating" leg is evidenced in review-round1.md (dem.tif truncated to 0.9/0.7/0.55/0.5/0.45/0.3) and nowhere in findings.md — same gap as **F4** |
| 54 | Gotchas: 23% faster in exchange for 243 million cells at 700 km | **yes** | see 8, 9 |
| 55 | Gotchas: "13 of 300 frames drawn between 0.2 and 6 cells across on the bundled DEM" | plausible | see 13 |
| 56 | CLAUDE.md carries **no** 3.4 km reachability claim | — | the one document that escaped **F1**, by omission |

### `tests/testthat/test-fly_footprint.R` — comments in the three new tests

| # | claim | true? | how checked |
|---|---|---|---|
| 57 | "the grid assertion above cannot see the read at all" | **yes** | `run` — under both union plants, "does not size its coverage grid to the span of the photo set" stays green |
| 58 | "Asserted on the extents handed to `crop()`, not on elapsed time … the union crop returns the right numbers" | **yes** | `run` — under the union plant, `footprint_terrain`/`dem_coverage` assertions in that test still pass; only the cell bounds fail |
| 59 | "Measured before the fix: 13 of 300 frames drawn between 0.2 and 6 cells across" | plausible | see 13 |
| 60 | **"Not exotic. A 3.4 km 1:15000 frame is under 4 cells across on a 900 m DEM"** | **NO** | **F1** — and here it is the stated justification for this test's own fixture |
| 61 | "The oracle is the whole-DEM extract … not anything this code computes for itself" | **yes** | `run` — the test calls `terra::extract(dem, vect(gg))` directly |
| 62 | "Premise: the fixture must be able to expose the defect" | **NO** | **F5** |
| 63 | "The mock has to have been reached, or every bound below is vacuous" | **yes** | `run` — the mock fires; round 2 measured it too |
| 64 | "Two on-DEM frames either side of the off one, so a misalignment would show as the wrong elevation rather than only as an error" | **yes** | `run` — the test's `alone` comparison does exactly that |

### `planning/active/findings.md` / `progress.md`

| # | claim | true? | how checked |
|---|---|---|---|
| 65 | "crop once over `in_dem` … `max(crops)` = 243,583,754 … and **only the new test** reddens" | half **NO** | `run` — number exact; "only the new test" false (**F6**) |
| 66 | "remove the off-DEM extent guard … 5 tests error, three of them pre-existing" | **yes, exactly** | `run` — see 45 |
| 67 | "there is no `tryCatch` in the shipped code" | **yes** | `run` |
| 68 | "0 of 4000" superset violations; "0 of 1200" behavioural divergences | **yes** | `run` — my independent 0/500 and 0/2100 agree |
| 69 | "frame spanning the whole DEM and 50 km past it … both `elev` 866.2, `covered` 0.0359" | **yes, exactly** | `run` — reproduced 866.2201 / 0.03592756 |
| 70 | progress.md: "identical … over 9 shapes (and, after review, over a multi-layer DEM and frames swept 0.05–60 …)" | **yes** | `arith` — 9 + 2 = 11. progress.md has the arithmetic NEWS got wrong (**F3**) |
| 71 | progress.md: "Suite green: … PASS 1829" | **stale** | `run` — now 1880 |

---

## Findings

### F1 — [claim false] The reachability argument for the window defect was reasoned from frame width, and frame width is not the condition. Four places.

> "Reachable on real data, because a 3.4 km frame is 3.8 cells across on the 900 m DEM this
> file's own tests use." — `R/fly_footprint.R:285`
>
> "That is not an exotic shape: a 3.4 km 1:15000 frame is under 4 cells across on a 900 m
> DEM" — `inst/notes/terrain-correction.md:119`
>
> "and a 3.4 km frame is under 4 cells across on a 900 m DEM" — `NEWS.md:7`
>
> "Not exotic. A 3.4 km 1:15000 frame is under 4 cells across on a 900 m DEM" —
> `tests/testthat/test-fly_footprint.R:679`
>
> "invisible at 30 m, where a frame is 113 cells wide, and **live at 900 m, where it is
> under 4**" — `inst/notes/terrain-correction.md:268` (the "Testing this" table)

Measured. Synthetic 900 m DEM with no NA collar, 3.4 km square frames (3.78 cells across),
`snap = "near"` read against the whole-DEM read:

| regime | frames differing |
|---|---|
| interior, 500 random positions, 3.4 km frame | **0 / 500** |
| interior, 3.0–4.0 cells across | **0 / 200** |
| interior, 3.78 cells across | **0 / 200** |
| interior, 1.00 cells across | **0 / 200** |
| interior, 0.95 cells across | 29 / 200 |
| interior, 0.60 cells across | 130 / 200 |
| interior, 0.20 cells across | 80 / 200 |

Same shape on the bundled 30.45 m DEM: 0/200 at every band from 1.0 cells up, 50/200 at
0.05–0.5 cells.

**The mechanism says it must be so.** A `snap = "near"` edge moves inward by at most half a
cell, so the column it discards has its own centre *outside* the polygon — and
`terra::extract()` only takes a cell whose centre is inside. Discarding it therefore changes
nothing. The read can only diverge where `extract()` abandons the centre rule for its
touched-cells fallback, which happens **only when the frame's intersection with the DEM
covers no cell centre at all**. That is the condition the note states correctly two
paragraphs later ("It holds wherever the frame covers at least one cell centre") — so the
note contains both the right condition and a wrong proxy for it, and the wrong one is the
one that got copied into four files.

**It is reachable, for a different reason, and that reason is worth having instead.** A
full-size 3.4 km frame *does* exhibit it when it hangs off the DEM edge with a sub-cell
sliver of overlap: 22 of 100 swept overlap depths on the east edge, 22 of 100 on a corner,
all of them at overlaps under ~0.5 of a cell. And round 1's own sweep found 6/300 at 3–8
cells across — all "near a DEM edge". So the honest sentence is about *overlap*, not size:
a frame of any size whose overlap with the data is thinner than a cell, i.e. a frame at the
edge of DEM coverage, which is the ordinary case for an AOI-cropped DEM.

Why this matters more than a wording slip: the row in the "Testing this" table is an
instruction to future maintainers about *which axis to vary*, and it names the wrong axis.
Someone testing "a footprint only a few cells across" at 3–4 cells gets a green run and
concludes the axis is covered. The axis that catches it is "a footprint whose overlap with
the DEM is under one cell" — which is a different fixture.

### F2 — [claim overstated, user-facing] The roxygen tells users a pre-crop gains nothing; the repo's own measurement says 19%.

> "There is nothing to gain by cropping a `/vsicurl/` raster yourself first; a local crop is
> worth it only to work offline." — `R/fly_footprint.R:676`, `man/fly_footprint.Rd:274`

`findings.md` records, for eight contiguous frames off the remote COG: per-frame crop
**1.23 s**, one shared crop **1.00 s**. The shared-crop figure *includes* the crop, so a
caller who crops once to their own AOI and then calls `fly_footprint()` spends 1.00 s where
the unaided path spends 1.23 — a 19% saving, from exactly the operation the sentence says
gains nothing. The same 23% appears in NEWS, CLAUDE.md, the note and the code comment as the
*price* of per-frame bounding; the roxygen is the one place it is described as zero.

The defensible claim is the one the rest of the change makes: the saving is small, it is
unbounded in allocation, and it stops paying as the frames spread out (findings.md: a
whole-AOI crop of the bundled extent costs 4.4 s on its own, against ~3 s for 20 windowed
frames). Say that, rather than "nothing to gain" — a user who measures will find the repo's
own number contradicting its own documentation.

### F3 — [claim false] `dem_coverage` *is* affected in one regime, and the parity list is counted wrong.

Two separate errors in the same paragraph, both in NEWS and the note.

**(a) "`dem_coverage` is unaffected; only the sampled values move."** (`inst/notes/terrain-correction.md:143`, and NEWS.md:10 "with `dem_coverage` unaffected"). Measured, old
implementation pulled from `f1aa087^` and run beside the new one on a 10x10 100 m DEM with
no NA collar, frame overhanging the east edge:

| overlap | old `elev` | old `covered` | new `elev` | new `covered` |
|---|---|---|---|---|
| **0 (exact abutment)** | 60 | **0.08333** | NA | **0** |
| 1e-9 … 50 m | 60 | 0.08333 | 55 | 0.08333 |
| 50.1 m and up | 55 | 0.2 | 55 | 0.2 |

At exact abutment `covered` goes 0.0833 → 0, so `footprint_terrain` flips to
`no_dem_coverage`. Round 1 found this and called it "not a defect — a correction", which is
right: the old number came from cells whose centres lie outside the footprint. **Nobody
wrote it down.** It is a behaviour change in `dem_coverage`, it is excluded by neither of the
two riders the documents offer (the cell-centre condition, and "`dem_coverage` unaffected"),
and it is the one part of the parity story that is a genuine change rather than a
degenerate-regime wobble. Vanishingly unlikely to be hit through `fly_footprint()` — it
needs a footprint extent exactly equal to the DEM's to floating point — so this is a
completeness fix, not a defect: say "`dem_coverage` moves only where the overlap is exactly
zero, where the old value was read off cells outside the footprint".

**(b) "identical `elev` and `covered` over nine shapes:"** (`NEWS.md:10`) is followed by an
**eleven-item** list — the original nine plus the multi-layer DEM and the swept-resolution
sweep that were added after round 1. `progress.md:24` has it right ("over 9 shapes (and,
after review, over a multi-layer DEM and frames swept 0.05–60 cells across …)"); the note
carries the same eleven items with no count and is therefore fine. Only NEWS states a count,
and it is the pre-review one. This is the mechanism in miniature: the count was true of the
draft, the list grew, the count did not.

### F4 — [claim unevidenced] Three load-bearing numbers cite measurements that exist in no tracked file.

| number | cited in | where the measurement actually lives |
|---|---|---|
| "13 of 300 frames drawn between 0.2 and 6 cells across on the bundled 30 m DEM" | note, NEWS, CLAUDE.md, the code comment, the test comment | **nowhere** — not in findings.md, not in progress.md, not in either review file |
| "400 randomized geometries and 800 degenerate edge overlaps" | note | `review-round2.md` (400) and `review-round1.md` (800) — both untracked |
| parity "over … **truncating** … shapes" | CLAUDE.md | `review-round1.md` only; findings.md's parity list has no truncating leg |

The 13/300 is the one to care about: it is quoted in five places, it is the only number
behind the claim that the window defect was real on the *bundled* fixture, and re-deriving
it is not free — my own reconstruction over the same stated range gives **10/300**, same
order but not the same number, and the difference is entirely down to a seed and a
positioning rule that nothing records. `findings.md` is the evidence record this repo
archives; a number cited five times and recorded zero times is exactly the shape
`code-check.md` calls a claim with no producer.

The 400/800 is lower-stakes but has a sharper failure: `review-round1.md` and
`review-round2.md` are **untracked** (`git status` shows `??`). If they are not committed or
folded into findings.md before `/planning-archive`, the note will cite a 1,200-case sweep
whose record does not exist anywhere in the repository.

### F5 — [premise is a proxy, and is described as something it is not] The small-frame test's anti-vacuity premise does not test what NEWS says it tests, and the real margin is one frame in forty.

> NEWS.md:7 — "a test now checks 40 small frames against the whole-DEM extract **with a
> premise asserting the fixture can still reach the defect**"
>
> test comment — "**Premise: the fixture must be able to expose the defect.** A `snap = "near"`
> window that contains every frame would make the rest of this vacuous."
>
> the assertion — `expect_gt(uncontained, 0)`

`uncontained` counts frames whose `snap = "near"` template fails to contain the footprint.
That is *necessary* for the defect and nowhere near *sufficient* — per F1, a discarded column
whose centre lies outside the polygon changes nothing. Measured on the test's own 40 frames
(`set.seed(42)`, 900 m DEM):

- `uncontained` = **34 / 40** — the premise passes comfortably
- frames that would actually differ with the defect restored = **1 / 40**

So the premise is satisfied 34 times over while the thing it exists to guarantee holds once.
A fixture change that moved the size distribution up even slightly would leave the premise
green at 34/40 with the oracle comparison completely vacuous, and nothing would say so.

The test **does** fire as shipped — I restored `ei <- terra::ext(tmpl)` in a scratch copy and
got `FAIL 1`, in "the DEM read window contains the footprint, even when the frame is small",
on that one frame. So it is not decoration. But its margin is one frame, held by a seed, and
the premise cannot see that margin. The premise that would is the one F1 implies: count the
frames that cover no DEM cell centre, or simply assert that some frame is under one cell
across (measured: 8 of the 40 are).

NEWS's description of the premise is the separate half of this finding — it says the premise
asserts reachability, and it does not.

### F6 — [claim false] "Reddens that test alone" is wrong; a union crop reddens both new tests.

> NEWS.md:8 — "planting a union-extent crop takes it to the 243 million above and reddens
> **that test alone**, because the counting *grid* is still per-frame and the existing grid
> assertion cannot see the read at all"
>
> findings.md — "**only the new test** reddens"

Measured, two faithful plants, full `test-fly_footprint.R` each time:

| planted read window | `max(crops)` | result |
|---|---|---|
| `ei <- terra::ext(terra::vect(in_dem))` (raw union — the plant that yields the recorded figure) | **243,583,754** | FAIL 3: "reads the DEM through one window per frame" (2), "the DEM read window contains the footprint" (1) |
| `ei <- terra::align(terra::ext(terra::vect(in_dem)), dem)` (aligned union) | 243,599,463 | FAIL 3, same two tests |

Round 2 reported one test, correctly for the tree it ran against; the small-frame test now
also catches a union window, because a union extent is not snapped out either. **The
substantive point survives and is the one worth keeping**: the *pre-existing* grid assertion,
"fly_footprint does not size its coverage grid to the span of the photo set", stays green
under both plants — so the new crop-mock test is not redundant with it and cannot be deleted
as such. That is what the sentence was defending. "Reddens that test alone" is simply the
wrong way to say it, and it is the kind of sentence a future maintainer would use to justify
deleting one of the two new tests.

Note also that the recorded 243,583,754 belongs to the *raw*-extent plant specifically; the
aligned plant gives 243,599,463 and the note's own union figure (via `fly_dem_grid`) is
243,599,463 too. The number is right and reproducible — just worth knowing it names one
particular plant.

---

## Code defects

Short, as instructed — two rounds have swept this and I found nothing new.

- `per <- vapply(…, numeric(3))` / `per["elev", ]` — safe at n = 1 and n > 1; row names come
  from the first result's `c(elev=, got=, expected=)` literals. Re-confirmed.
- `vals <- NA_real_` off-DEM → `mean` `NaN` → caught by the existing
  `elev[is.nan(elev)] <- NA_real_`; `got` 0 → `covered` 0. Confirmed by the shipped test and
  by my own abutting/wholly-off probes.
- The `on_dem` guard: 0 cases found where it passes and `crop()` then errors, across my
  sweeps plus rounds 1 and 2. Strict inequality is right — the abutting frame returns NA/0.
- `terra::crop()` on an overhanging aligned extent clips; `align()` is crop-invariant. Both
  re-run here.
- An `NA` extent (empty geometry surviving a pathological reprojection) still errors in
  `if (!on_dem)`. Pre-existing, fly#47 family, identical in the old implementation — not a
  regression, and findings.md records it.
- Round 2's memory note still stands and is still undocumented: the counting template and the
  cropped window are both resident inside the loop, so peak per-frame residency is roughly
  double. Cell counts are unchanged and I could not demonstrate a regression, so this is a
  gap in the note's allocation argument rather than a defect.

## What I did not touch

No file under `R/` or `tests/` in the live repo was modified. All six planted defects were
driven in `scratchpad/flycopy`, a full copy, restored with `cmp` after each. The live repo's
`man/` was confirmed in sync by running `roxygenise()` (no diff produced). `2f0df22` landed
from another session part-way through; every check above was re-run or re-confirmed against
the post-commit tree.
