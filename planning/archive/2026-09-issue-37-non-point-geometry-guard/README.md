# fly#37 — non-point geometry guard

`fly_footprint()` accepted its own POLYGON output and silently returned **100
rows from 20**, recycling each frame's attributes across five geometries.
`sf::st_coordinates()` returns one row per feature for POINT and one row per
*vertex* for anything else.

Closed by PR #48: an internal `fly_check_points()` refusing non-POINT geometry,
called from all seven functions that take caller-supplied photo geometry, each
naming its own argument.

## Measurement

The reported row count was the detectable half. With the guard neutralised in
both `asNamespace("fly")` and `as.environment("package:fly")`:

| call | points | footprints in |
|---|---|---|
| `fly_footprint()` | 20 rows | **100 rows** |
| `fly_bearing()` | 20 bearings | **20 bearings, up to 272.8 deg wrong** |
| `fly_filter(method = "centroid")` | 7 rows | **20 rows** |
| `fly_overlap()` | — | 56 pair rows |
| `fly_select()` minimal / all | — | 7 / 14 rows |
| `fly_coverage()` | — | errors, by accident of how it assigns |

`fly_bearing()` was the worse defect and the issue had listed it only as "worth
checking": it returns the right *number* of bearings with wrong values, so
nothing downstream can tell.

The issue's suggested guard, `%in% c("POINT", "MULTIPOINT")`, was measured to be
wrong rather than argued to be: installed verbatim, it refused POLYGON and let
the same footprints cast to MULTIPOINT through at **100 rows from 20**.

## The wrong turns, which are the point of this record

Five review rounds, and rounds 2, 3 and 4 each found a defect **inside the
previous round's fix**. Three separate comments were corrected for stating
something asserted rather than measured.

1. **Round 1** — a `sfc_GEOMETRY` column of points passed the guard and died
   opaquely. The comment justifying that called it "a legitimate input".
2. **Round 2** — the fix for (1) ran before the type check, so a GEOMETRY column
   of *polygons* was told to `st_cast(x, "POINT")`, which takes a polygon's first
   vertex: 20 rows in, 20 out, guard accepting, **ten frames moved 1,940 m**.
3. **Round 3** — reordering had moved the destructive advice between clauses, not
   removed it. Both messages recommended `st_cast()`, and following it on a
   POLYGON gave **100 rows from 20 with 80 duplicated `airp_id`** — issue #37
   verbatim, reproduced by doing what the error said. The guard tests *shape*,
   and `st_cast()` always produces the right shape.
4. **Round 4** — the fix for (3) tested the right property at the wrong
   granularity. `nrow(st_coordinates(x)) == nrow(x)` is a sum, blind to a
   redistribution that conserves the total: one frame digitised twice plus one
   frame with no location satisfies it, and taking the offered cast shifted every
   frame against its attributes, **18 of 19 wrong by up to 20.4 km**. The sweep's
   assertion was itself circular — it restated the guard's own predicate and
   passed on that input.

The class, named in round 3 and closed in round 4: **a guard's remedy must not
produce the shape the guard accepts.** The condition is now sound per feature by
construction — a non-empty feature contributes at least one coordinate, so "no
empties" plus "total equals the feature count" forces exactly one each — and the
test asserts displacement against fixture ground truth rather than the row count.

## Outcome

- Guard at seven entry points; `fly_georef()`'s sits above `dir.create()` so a
  refusal leaves no output directory
- Suite **1311 passing**, 0 failures / warnings / skips
- Breaking for MULTIPOINT-of-one and mixed `GEOMETRY` columns, both in NEWS with
  the one-line fix
- **fly#47** filed: an empty POINT aborts the batch instead of yielding an empty
  footprint. Deliberately not folded in — refusing 20 frames over one unlocatable
  centroid contradicts the per-frame reporting #30 established

## Evidence

`planning/archive/2026-09-issue-37-non-point-geometry-guard/review-round[1-4].md`
— each round's findings, with the reproductions and the restore-the-bug proofs.
