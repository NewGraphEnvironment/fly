# Read the camera a frame's PAT-B file names

Downloads and parses the per-frame georeferencing files the BC Data
Catalogue publishes through `patb_georef_url`, and attaches the camera
identity they carry to the photo centroids.
[`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md)
then sizes those frames from the named camera instead of refusing them,
which needs no DEM.

## Usage

``` r
fly_camera_patb(
  photos_sf,
  dest_dir = tempfile("fly_patb"),
  overwrite = FALSE,
  quiet = FALSE
)
```

## Arguments

- photos_sf:

  An sf object with airphoto metadata, typically from the BC Data
  Catalogue centroid layer. Must contain `patb_georef_url`, and
  `film_roll` and `frame_number` or `airp_id` to join on.

- dest_dir:

  Directory to cache the downloaded archives in. Defaults to a session
  temporary directory; give it a real path to keep them between runs.

- overwrite:

  If `FALSE` (default), archives already in `dest_dir` are reused rather
  than re-downloaded.

- quiet:

  Suppress the per-archive progress messages.

## Value

`photos_sf` with four columns added, all `NA` where nothing resolved:

- `camera_serial`:

  the camera or lens serial the file publishes

- `camera_name`:

  the model string the file publishes, where it has one

- `patb_gsd`:

  ground sample distance in **centimetres**, matching the catalogue's
  own units. The catalogue's `ground_sample_distance` is 0 for whole
  years of digital imagery, and this is where the number is

- `patb_source`:

  the archive each row was resolved from

## Details

This is the only function in the package that reaches the network on the
sizing path.
[`fly_footprint()`](https://newgraphenvironment.github.io/fly/reference/fly_footprint.md)
takes the columns it produces and never fetches anything itself, so a
batch can be resolved once and reused.

Three file schemas are in circulation and they are dispatched on the
columns present rather than the file extension, because the extension
does not identify them. Two of the archives referenced by the frames
this exists for are 404s served as HTML under a `.csv` name; those
frames are reported as unresolved, by a message naming the archive
rather than by an error, so one missing file does not cost a batch its
other frames.

A serial that the shipped camera table does not recognise is **refused**
rather than resolved from the model string beside it. One published
archive labels both its cameras `UltraCam XP` while one of them is an
UltraCam X, a 20% difference in ground width — so the model string is
read only where the file carries no serial at all. See
`inst/notes/camera-formats.md`.

## Examples

``` r
centroids <- sf::st_read(system.file("testdata/photo_centroids_digital.gpkg",
                                     package = "fly"), quiet = TRUE)

# Copy the bundled archives into a scratch directory, so this runs offline and
# writes nothing into the installed package
cache <- file.path(tempdir(), "patb")
dir.create(cache, showWarnings = FALSE)
file.copy(list.files(system.file("testdata", "patb", package = "fly"),
                     full.names = TRUE), cache)
#> [1] TRUE TRUE TRUE TRUE

resolved <- fly_camera_patb(centroids, dest_dir = cache)
#> Downloaded 2 of 2 files
#> d_003_fi_13_georef.zip: 18 of 18 frames resolved
#> d_005_emn_19_georef.zip: 6 of 6 frames resolved
table(resolved$camera_serial, useNA = "ifany")
#> 
#>   121201 22814295 
#>       18        6 

# `fly_footprint()` picks the columns up from here. These frames also carry a
# calibration report, which wins; drop it and the PAT-B serial sizes them.
resolved$camera_calibration_url <- NA_character_
fp <- fly_footprint(resolved)
unique(fp$width_source)
#> [1] "patb_serial=121201"   "patb_serial=22814295"
```
