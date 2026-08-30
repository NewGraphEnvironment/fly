# Findings — fly_footprint() drops footprint_basis and friends on tibble input (#35)

## Reproduced on `main` at `8585fd5`, sf 1.1.2

Against `inst/testdata/photo_centroids.gpkg` with the class overridden:

```
sf,data.frame             -> footprint_basis footprint_terrain height_agl dem_coverage
sf,tbl_df,tbl,data.frame  -> (all four absent)
```

## Mechanism — an `sf::st_sf()` branch, not a `fly` quirk

`st_sf()` builds its attribute frame with a chain that keeps only the **first**
argument when that argument is a tibble:

```r
df = if (inherits(x, c("tbl_df", "tbl"))) x
     else if (length(x) == 1) data.frame(row.names = row.names)
     else if (!sfc_last && inherits(x, "data.frame")) x
     else if (sfc_last && inherits(x, "data.frame")) x[-all_sfc_columns]
     else if (inherits(x[[1]], c("tbl_df", "tbl"))) x[[1]]   # <-- here
     else cbind(data.frame(row.names = row.names), as.data.frame(x[-all_sfc_columns], ...))
```

With six arguments, `x` is a plain list of length 6, so the first four branches
are not taken. `x[[1]]` is the dropped-geometry tibble, so `df` becomes that
tibble alone — `footprint_basis`, `footprint_terrain`, `height_agl` and
`dem_coverage` are discarded before the sfc column is reattached. A plain
data.frame first argument falls through to the final `cbind()`, which keeps
everything. That is the whole difference.

Confirmed in isolation:

```
st_sf(tbl, extra = "hello", geometry = g)  ->  "extra" present: FALSE
st_sf(df,  extra = "hello", geometry = g)  ->  "extra" present: TRUE
```

## Scope — one call site

`grep -rn "st_sf(" R/` returns two hits. `R/fly_footprint.R:64` builds a bare
geometry frame (`st_sf(geometry = rects[ok])`) and attaches nothing to
user-supplied data. `R/fly_footprint.R:482` is the defect. Every other frame in
the package is a `dplyr::tibble()` built from scratch — `fly_fetch.R:84,93,104`,
`fly_overlap.R:38,71,82`, `fly_georef.R:142`, `fly_coverage.R:66` — so none
inherit the input's class and none are affected.

Nothing downstream reads the four columns, so this is pure loss of reporting
rather than breakage: geometry and every downstream number are correct with a
`tbl_df` input today. That is what makes it dangerous rather than obvious.

## Why the suite cannot see it

Every fixture in the package is `sf, data.frame`:

- `inst/testdata/photo_centroids.gpkg` reads back plain via `sf::st_read()`
- `mixed_media_fixture()` and `terrain_fixture()` in `tests/testthat/setup.R`
  are built by `sf::st_sf()` on plain vectors

No number of added cases along the existing axis would find this. Seventh
instance of the pattern in `inst/notes/terrain-correction.md` and the `CLAUDE.md`
gotcha — *ask which shapes the fixture can never present*.

Two adjacent axes were checked and are **already covered**, so class shape is the
single gap:

- **geometry column name** — the bundled fixture's geometry column is named
  `geom`, not `geometry`, so the `st_drop_geometry()` path is exercised
- **row subsets** — existing tests pass `centroids[centroids$scale == ..., ]`

## Fix shapes measured

| shape | four columns | output class for a `tbl_df` input |
|---|---|---|
| `st_sf(as.data.frame(drop_geom(x)), basis =, ..., geometry =)` | present | `sf, data.frame` — **downgraded** |
| assign onto `attrs`, then `st_sf(attrs, geometry =)` | present | `sf, tbl_df, tbl, data.frame` — preserved |

The second was verified across three input shapes, in each case with `geometry`
last and `attr(, "sf_column")` correct:

```
sf,data.frame                      -> cols ok, class preserved
sf,tbl_df,tbl,data.frame           -> cols ok, class preserved
sf,grouped_df,tbl_df,tbl,data.frame-> cols ok, class preserved
```

It works because a two-element `x` still reaches the `inherits(x[[1]], "tbl_df")`
branch — but by then the four columns are *inside* `x[[1]]`, so surviving as
`x[[1]]` is exactly what is wanted. Chosen over the issue's suggested
`as.data.frame()` because it is the smaller delta: a tibble caller's class is
unchanged from today, only the missing columns appear.

## `sf::st_read(path, as_tibble = TRUE)` gives an honest tibble fixture

No class hacking is needed to build the regression fixture:

```
sf::st_read(p, quiet = TRUE)                    -> sf,data.frame
sf::st_read(p, quiet = TRUE, as_tibble = TRUE)  -> sf,tbl_df,tbl,data.frame
dplyr::group_by(tbl, scale)                     -> sf,grouped_df,tbl_df,tbl,data.frame
```

Per the negative-fixture rule in `CLAUDE.md`, the helper asserts that premise
inline, so a future `sf` change fails on the premise rather than on the
behaviour under test.

## Column vectors are already full length

`basis`, `terrain`, `height_agl` and `dem_coverage` are each length `nrow()`
(`rep()` / `ifelse()` over length-`n` inputs, `R/fly_footprint.R:353-382`), so
assigning them with `$<-` introduces no recycling that `st_sf()` was not already
doing.

## Baseline

`devtools::test()` on `8585fd5`: **FAIL 0 | WARN 0 | SKIP 0 | PASS 225**.

CI on `main` at session start: all recent runs green (pkgdown + pages).

## Errors Encountered

| Error | Resolution |
|-------|------------|
