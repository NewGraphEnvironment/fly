# Findings — fly_footprint() silently returns 5x the rows when handed its own output (#37)

## Measurements taken during plan-mode exploration

All reproduced against the bundled fixtures on `main` at 51085e0, before any change.

### The reported bug

```
20 centroids -> fly_footprint() -> 20 footprints -> fly_footprint() -> 100 rows
```

No error, no warning. Output geometry type is POLYGON.

### `fly_bearing()` is the worse defect

The issue listed this as "worth checking". It is the more dangerous of the two:

```
bearing rows from points: 20
bearing rows from polys:  20
identical: FALSE
max abs diff: 272.75 degrees
```

`fly_bearing()` indexes `coords[ord, ]` where `ord` is a permutation of `1:n`,
against a `5n`-row coordinate matrix. It therefore reads the first `n` *vertex*
rows and returns a bearing column of the **correct length** with wrong values.
`fly_footprint()` at least changes its row count, which is detectable; this
returns a plausible answer at the right dimensions and nothing downstream can
tell. Same family as CLAUDE.md's "a valid response is not a correct one".

### `fly_filter(method = "centroid")` bypasses the guard entirely

It is the only path in the package that reads `photos_sf` geometry without going
through `fly_footprint()`:

```
centroid-method rows, points in: 7
centroid-method rows, polys  in: 20
```

Handed footprints it silently becomes a footprint filter under a centroid label —
no row multiplication, but nearly 3x the selection, wrong and silent.

## The issue's suggested fix has a hole

The issue body proposes `%in% c("POINT", "MULTIPOINT")`. MULTIPOINT expands
exactly as POLYGON does:

```
n features: 2
st_coordinates rows: 4
```

So accepting MULTIPOINT reintroduces the bug the guard exists to prevent. The
guard must be POINT only. This is why MULTIPOINT is in the test fixture rather
than just POLYGON — it is the case that discriminates the correct guard from the
issue's plausible wrong one, per CLAUDE.md's "restore the bug and confirm the
test fails".

## Why POINT-only is equivalent, not a proxy

CLAUDE.md warns that a guard encoding the cause you measured is usually a proxy
for the property you want. Here the property is "one coordinate row per feature",
and POINT is exactly equivalent to it rather than correlated with it:

```
st_sfc(st_point(c(0,0)), st_point(), st_point(c(1,1)))
n features: 3   st_coordinates rows: 3
      X  Y
[1,]  0  0
[2,] NA NA     <- empty POINT keeps an ALIGNED row
[3,]  1  1
```

An empty POINT does not drop a row, so alignment survives the empty geometries
`fly_footprint()` itself emits for unresolvable frames. No separate row-count
assertion is needed as a backstop.

## Zero-row input must stay legal

`all(logical(0))` is `TRUE`, so a zero-row sf passes the guard vacuously. That is
the correct behaviour — `footprint_cases()` carries an `"empty input"` case and
`test-fly_camera_format.R:198` depends on it. Asserted explicitly in the new
tests so a future reader does not "fix" the vacuous pass.

## Call-graph facts established by reading

| function | reads centroid geometry directly | needs guard |
|---|---|---|
| `fly_footprint()` | yes, `st_coordinates()` line 435 | yes |
| `fly_bearing()` | yes, `st_coordinates()` line 38 | yes |
| `fly_filter()` | yes, in the `centroid` branch line 41 | yes |
| `fly_coverage()` | no — via `fly_footprint()` line 30 | inherits |
| `fly_overlap()` | no — via `fly_footprint()` line 33 | inherits |
| `fly_select()` | no — via `fly_footprint()` lines 57, 115 | inherits |
| `fly_georef()` | no — via `fly_footprint()` line 156 | inherits |
| `fly_summary()` | no — `st_drop_geometry()` line 15 | none |
| `fly_fetch()` | no — attribute columns only | none |

`fly_georef()` passes **centroids**, not footprints, to both `fly_footprint()`
(line 156) and `fly_bearing()` (line 227), so the guard does not break it. Its
own `st_coordinates()` call at line 309 is on `fp`, a footprint it built itself,
and is untouched.

## Errors Encountered

| Error | Resolution |
|-------|------------|
