# Mask the black frame border of an airphoto scan

Scanned airphotos carry a black collar — film holder edges, fiducial
marks, chamfered corners, scanner overrun — outside the exposed frame.
Left in place it covers adjacent photos in a mosaic. `fly_mask()` writes
a copy of each image with an **alpha band** marking that collar
transparent, leaving every pixel inside the frame untouched.

## Usage

``` r
fly_mask(
  src,
  dest_dir = "masked",
  threshold = fly_mask_threshold(),
  overwrite = FALSE
)
```

## Arguments

- src:

  Character vector of image paths.

- dest_dir:

  Directory for the masked copies. Created if it does not exist.

- threshold:

  How close to black a pixel must be to count as collar, as a per-band
  distance from 0. Defaults to **16**, which is measured rather than
  chosen — see **Threshold** below. The default is written as a call so
  that the shipped value and the calibrated constant cannot drift apart;
  there is only one of them.

- overwrite:

  If `FALSE` (default), skip images whose masked copy already exists.

## Value

A tibble with one row per input:

- `source`:

  the input path

- `dest`:

  the masked copy, or `NA` where none was written

- `mask_fraction`:

  share of the frame the mask covers. `NA` wherever no mask was computed
  — a resumed row, or any refusal reached before the measurement

- `mask_fraction_interior`:

  share of the central box the mask covers — the quantity the runaway
  guard tests. `NA` on the same rows as `mask_fraction`

- `threshold`:

  the threshold requested for this image. `NA` on a *resumed* row, whose
  file was written on an earlier run at a threshold this call did not
  measure and must not claim

- `masked`:

  whether a masked copy was written

- `reason`:

  why the row is what it is. `NA` only for an ordinary freshly masked
  image — a *resumed* row carries a reason with `masked = TRUE`, so
  partition on `masked`, never on `is.na(reason)`

- `success`:

  whether the call reached a definite conclusion about this image. A
  reasoned refusal — a non-Byte source, a colliding destination, a mask
  that exceeds the interior cap or could not be measured — is `TRUE`:
  the function did its job and declined. `FALSE` means something stopped
  it from concluding at all: the file is missing or unreadable, GDAL
  errored, or the copy could not be written

## Details

**The collar is edge-connected, not a shape.** The mask is a flood fill
seeded from the image border (GDAL `nearblack -alg floodfill`), so only
darkness *reachable from the edge* is masked. A dark lake or deep shadow
inside the frame is kept, which is the whole point: a plain threshold
masks it too. Measured on 1990 roll bcb90128 frame 213, a plain
threshold masks 7.7% of the frame and this masks 2.5% — the missing 5%
is water.

It is **not** a circle. fly#23 proposed detecting a circular lens
boundary; measured over 264 thumbnails spanning 1967-2018, the dark
region's median area is 2.7% where an inscribed circle implies 21.5%,
and the middles of the image edges are as dark as the corners, which a
circle cannot produce. See `inst/notes/border-masking.md`.

**Threshold:** scanned black is not 0. On these JPEGs it runs 3-12, so
the exact-zero matching
[`fly_georef()`](https://newgraphenvironment.github.io/fly/reference/fly_georef.md)
used before v0.11.0 masked a median of **0.16%** of the frame against
the **3.11%** a threshold of 16 reaches — a 19.8x gap. (Both are mask
fractions from `mask_border_sweep.csv`. The 2.7% quoted above is the
*raw dark* fraction, a different measurement, and the two must not be
compared.)

The default is set from the per-frame threshold at which a frame's own
collar is fully consumed, taken across the measured population;
`inst/notes/border-masking.md` carries the distribution. It assumes
**Byte** bands, and a source that is not Byte is refused rather than
reported as having no collar — `-near` is an absolute per-band distance,
so the number does not transfer to a 16-bit scan.

**The runaway guard.** A threshold high enough to reach scene content
floods inward and the mask stops being a collar. Because a genuine
collar hugs the border, it contributes almost nothing to a central box —
so the guard tests the **interior** fraction, not the total, which
cannot tell a thick collar from a lake running off the edge. When it
trips, the image is left unmasked with a warning rather than skipped: an
unmasked frame shows a black border, which is visible and is what
callers already live with, while an over-eager mask deletes real imagery
transparently and nothing downstream reports it.

A mask fraction of **zero is not a warning**. 27 of the 264 measured
frames carry no collar at all, digital frames among them, and for those
an empty mask is the right answer.

## Examples

``` r
centroids <- sf::st_read(system.file("testdata/photo_centroids.gpkg", package = "fly"))
#> Reading layer `photo_centroids' from data source 
#>   `/home/runner/work/_temp/Library/fly/testdata/photo_centroids.gpkg' 
#>   using driver `GPKG'
#> Simple feature collection with 20 features and 16 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -126.7631 ymin: 54.34512 xmax: -126.449 ymax: 54.47635
#> Geodetic CRS:  WGS 84

fetched <- fly_fetch(centroids[1, ], type = "thumbnail", dest_dir = tempdir())
#> Downloaded 1 of 1 files
masked <- fly_mask(fetched$dest[fetched$success], dest_dir = tempdir())
#> Masked 1 of 1 images
masked[, c("mask_fraction", "mask_fraction_interior", "masked")]
#> # A tibble: 1 × 3
#>   mask_fraction mask_fraction_interior masked
#>           <dbl>                  <dbl> <lgl> 
#> 1        0.0526                      0 TRUE  
```
