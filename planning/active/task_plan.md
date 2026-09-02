# Task: fly_footprint() silently returns 5x the rows when handed its own output (#37)

`fly_footprint()` accepts its own output and silently returns **five times as many
rows** as it was given. `sf::st_coordinates()` on a closed rectangle is one row per
*vertex*, so `fly_rectangles()` builds `5n` geometries from `n` attribute rows, and
`st_sf()` recycles the attribute frame up to match. No error, no warning, and 80 of
the 100 output rows carry attributes belonging to a different photo.

## Measured before implementation

| call | points in | polygons in | shape of the failure |
|---|---|---|---|
| `fly_footprint()` | 20 rows | **100 rows** | row count changes — detectable |
| `fly_bearing()` | 20 bearings | **20 bearings, up to 272 deg wrong** | right shape, wrong answer — undetectable |
| `fly_filter(method="centroid")` | 7 rows | **20 rows** | silently becomes a footprint filter |

`fly_bearing()` is the worse defect and the issue only flagged it as "worth
checking". It indexes `coords[ord, ]` with `ord` a permutation of `1:n` against a
`5n`-row matrix, so it returns a plausible bearing column at the correct
dimensions. Nothing downstream can tell.

## Correction to the issue's suggested fix

The issue proposes accepting `c("POINT", "MULTIPOINT")`. **MULTIPOINT reintroduces
the exact bug** — measured: 2 MULTIPOINT features of 2 points each give 4
coordinate rows. The guard must be POINT only.

POINT is not a *proxy* for "one coordinate row per feature" — it is exactly
equivalent to it. Verified: `sf` keeps an aligned `NA` row for an empty POINT, so
`n` features always yield `n` rows, including the empty geometries
`fly_footprint()` itself emits for unresolvable frames.

Zero-row input stays legal: `all()` of an empty vector is `TRUE`, so the
`digital_fixture()[0, ]` case passes vacuously — correct behaviour here, not a hole.

## Scope

**Direct guard** — these read centroid coordinates themselves: `fly_footprint()`,
`fly_bearing()`, `fly_filter()` (its `method = "centroid"` branch is the only path
that never reaches `fly_footprint()`).

**Inherit the guard**, no change needed: `fly_coverage`, `fly_overlap`,
`fly_select`, `fly_georef`.

**No guard**: `fly_summary()` drops geometry; `fly_fetch()` reads attributes only.

Confirmed safe: `fly_georef()` passes *centroids* to both `fly_footprint()`
(line 156) and `fly_bearing()` (line 227).

## Phase 1: Failing tests

- [x] Add `non_point_cases()` to `tests/testthat/setup.R` beside
      `footprint_cases()` — POLYGON, MULTIPOINT, LINESTRING
- [x] New `tests/testthat/test-fly_footprint_point_input.R`
- [x] Premise assertion: `nrow(fly_footprint(centroids)) == nrow(centroids)`
- [x] `fly_footprint()` rejects all three shapes, matching "must be points"
- [x] `fly_bearing()` rejects all three
- [x] `fly_filter()` rejects all three, under **both** `method` values
- [x] Sweep the inheriting exports — `fly_coverage`, `fly_overlap`,
      `fly_select`, `fly_georef` each reject rather than corrupt
- [x] Assert zero-row input is still accepted, so nobody "fixes" the vacuous pass
- [x] Confirm the new tests fail against current `main`

## Phase 2: The guard

- [x] Add `fly_check_points()` at the top of `R/fly_footprint.R`, beside the other
      internal helpers — never adjacent to an exported function's roxygen block,
      which would rebind its `@export`
- [x] Call from `fly_footprint()`, after the `inherits(x, "sf")` check and before
      `st_coordinates()`
- [x] Call from `fly_bearing()`, passing `"photos_sf"`
- [x] Call from `fly_filter()`, passing `"photos_sf"`, before the method branch
- [x] Full suite green — no regression in the 12 `footprint_cases()`
- [x] Guard the four inheriting exports too, each naming its own argument —
      the inherited error named `centroids_sf`, which none of them has
- [x] Place `fly_georef()`'s guard above `dir.create()` so a refusal leaves no
      empty output directory

## Phase 3: Documentation

- [x] `@param` on all three functions: points-only, and why an error rather than an
      `st_centroid()` coercion
- [x] `NEWS.md` entry under a development heading
- [x] `devtools::document()` — read the output, confirm `NAMESPACE` export count
      holds at 9
- [x] Edit the **issue body** to correct the MULTIPOINT recommendation and record
      the `fly_bearing` / `fly_filter` measurements

## Phase 4: Verification

- [x] Restore the bug — remove the guard, confirm each new test goes red. Patch
      **both** `asNamespace("fly")` and `as.environment("package:fly")` if patching
      bindings; test code resolves through the search path
- [x] Confirm the MULTIPOINT test fails against the issue's
      `c("POINT", "MULTIPOINT")` variant
- [x] `lintr::lint_package()` compared against the `HEAD` baseline
- [x] Fold in the background Plan-agent review findings
- [x] Fold in code-check round 1: refuse `sfc_GEOMETRY`, correct two comments
      that asserted coverage without measuring it, file fly#47 for empty POINT

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
