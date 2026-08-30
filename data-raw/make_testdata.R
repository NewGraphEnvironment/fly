#!/usr/bin/env Rscript
#
# make_testdata.R
#
# Generate bundled test data from Upper Bulkley River floodplain.
# Crop near Houston, BC.
# Dual-scale coverage: 1:12000 and 1:31680 (1968).
#
# Source: diggs cached data (BC Data Catalogue + flooded VCA output)
#   ... except dem.tif, which is fetched over the network from NRCan's MRDEM-30
#   (see the DEM section at the foot of this script). That step needs outbound
#   HTTPS to canelevation-dem.s3.ca-central-1.amazonaws.com; everything else is
#   local. Takes a few seconds.
#
# Run from fly repo root: Rscript data-raw/make_testdata.R

library(sf)
library(dplyr)
sf_use_s2(FALSE)

airbc_data <- file.path(dirname(getwd()), "diggs", "data")
outdir <- "inst/testdata"
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

# --- Source data ---
photos <- st_read(file.path(airbc_data, "l_photo_centroids.geojson"), quiet = TRUE)
fp <- st_read(file.path(airbc_data, "floodplain_neexdzii_co_4th_order.gpkg"), quiet = TRUE) |>
  st_make_valid() |>
  st_transform(4326)
streams <- st_read(file.path(airbc_data, "l_streams.geojson"), quiet = TRUE)

# --- Test bbox: near Houston, upstream of confluence, within Neexdzii Kwa ---
test_bbox <- st_bbox(c(xmin = -126.75, ymin = 54.33, xmax = -126.45, ymax = 54.47), crs = 4326)
test_rect <- st_as_sfc(test_bbox)

# --- AOI: floodplain clipped to test area ---
aoi <- st_intersection(fp, test_rect) |>
  st_make_valid() |>
  st_union() |>
  st_sf(geometry = _)
st_write(aoi, file.path(outdir, "aoi.gpkg"), delete_dsn = TRUE, quiet = TRUE)
message("aoi.gpkg: ", round(as.numeric(st_area(st_transform(aoi, 3005))) / 1e6, 1), " km2")

# --- Photo centroids: 1968, dual scale, sample ~20 ---
p68 <- photos |> filter(photo_year == 1968)

# Capture zone: AOI + 1500m
capture <- st_buffer(st_transform(aoi, 3005), 1500) |>
  st_transform(4326) |> st_union() |> st_make_valid()
inside_cap <- st_intersects(p68, capture, sparse = FALSE)[, 1]
p68_cap <- p68[inside_cap, ]

# Sample: ~10 at 1:12000, ~10 at 1:31680
# Include mix of inside-AOI and outside-AOI centroids
set.seed(42)
p12 <- p68_cap |> filter(scale == "1:12000")
p31 <- p68_cap |> filter(scale == "1:31680")
sample_12 <- p12[sample(nrow(p12), min(10, nrow(p12))), ]
sample_31 <- p31[sample(nrow(p31), min(10, nrow(p31))), ]
test_photos <- bind_rows(sample_12, sample_31)

# Keep essential columns only
test_photos <- test_photos |>
  select(airp_id, photo_year, photo_date, scale, film_roll,
         frame_number, media, photo_tag, nts_tile,
         focal_length, flying_height, ground_sample_distance,
         thumbnail_image_url, flight_log_url,
         camera_calibration_url, patb_georef_url, geometry)
st_write(test_photos, file.path(outdir, "photo_centroids.gpkg"),
         delete_dsn = TRUE, quiet = TRUE)
message("photo_centroids.gpkg: ", nrow(test_photos), " photos (",
        paste(sort(unique(test_photos$scale)), collapse = " + "), ")")

# Verify inside/outside split
inside_aoi <- st_intersects(test_photos, aoi, sparse = FALSE)[, 1]
message("  Inside AOI: ", sum(inside_aoi), "  Outside: ", sum(!inside_aoi))

# --- Streams: clip to test area, keep essential columns ---
streams_clip <- st_intersection(streams, test_rect) |>
  select(linear_feature_id, blue_line_key, waterbody_key = watershed_group_id,
         gnis_name, stream_order, geometry)
# Keep only order 4+ and limit to ~10 segments
streams_clip <- streams_clip |>
  filter(stream_order >= 4) |>
  slice_head(n = 10)
st_write(streams_clip, file.path(outdir, "streams.gpkg"),
         delete_dsn = TRUE, quiet = TRUE)
message("streams.gpkg: ", nrow(streams_clip), " segments (order ",
        paste(sort(unique(streams_clip$stream_order)), collapse = ", "), ")")

# --- Floodplain: same as AOI but unbuffered (for fly_trim_habitat tests) ---
# Use a slightly larger extent so trimming is meaningful
fp_clip <- st_intersection(fp, st_buffer(st_transform(test_rect, 3005), 2000) |>
                             st_transform(4326)) |>
  st_make_valid() |> st_union() |> st_sf(geometry = _)
st_write(fp_clip, file.path(outdir, "floodplain.gpkg"),
         delete_dsn = TRUE, quiet = TRUE)
message("floodplain.gpkg: ", round(as.numeric(st_area(st_transform(fp_clip, 3005))) / 1e6, 1), " km2")

# --- Lakes: create small synthetic lake (real lakes may not be in this crop) ---
# Use a small polygon near a stream with a matching waterbody_key
if (nrow(streams_clip) > 0) {
  # Pick a stream segment and create a small lake polygon near it
  ref_stream <- streams_clip[1, ]
  stream_centroid <- st_centroid(ref_stream)
  lake_center <- st_coordinates(stream_centroid)
  lake_poly <- st_polygon(list(matrix(c(
    lake_center[1] - 0.005, lake_center[2] - 0.003,
    lake_center[1] + 0.005, lake_center[2] - 0.003,
    lake_center[1] + 0.005, lake_center[2] + 0.003,
    lake_center[1] - 0.005, lake_center[2] + 0.003,
    lake_center[1] - 0.005, lake_center[2] - 0.003
  ), ncol = 2, byrow = TRUE)))
  lakes <- st_sf(
    waterbody_key = ref_stream$waterbody_key,
    gnis_name_1 = "Test Lake",
    geometry = st_sfc(lake_poly, crs = 4326)
  )
  st_write(lakes, file.path(outdir, "lakes.gpkg"),
           delete_dsn = TRUE, quiet = TRUE)
  message("lakes.gpkg: ", nrow(lakes), " lake(s)")
}

# --- DEM: MRDEM-30 clip for terrain-adjusted footprints (#9) --------------
#
# MRDEM-30 is NRCan's Medium-Resolution Digital Elevation Model: a 30 m
# bare-earth DTM covering all of Canada as a single ~84 GB Cloud-Optimized
# GeoTIFF in EPSG:3979, public and unauthenticated. `/vsicurl/` range-reads
# only the bytes intersecting our AOI, so nothing near 84 GB is transferred.
#
# Same product `flooded::fl_dem_aoi()` defaults to, which is why fly reaches
# for it rather than a second elevation source. Compared head to head against
# elevatr z=10 over this AOI, the two agree to within 0.42 percentage points on
# the resulting footprint-area correction (fly#9) — so this choice is about
# provenance and dependencies, not accuracy.
#
# Buffer is 5.4 km. The widest footprint is 1:31680, 7.24 km across, so its
# half-side is 3.62 km — but a square's *corner* is the far point, at
# half_side * sqrt(2) = 5.12 km. Buffering by the half-side leaves the four
# corners of every edge frame hanging over no-data, which is a partial mean
# rather than a clean fallback. 5.4 km clears that with a little margin.
#
# The terrain correction also enlarges footprints by up to ~25% here, and the
# second sampling pass averages over the *enlarged* rectangle, so the margin
# has to cover that too.
#
# Crop in the source CRS, project after. Never reproject the whole COG.

message("Fetching MRDEM-30 clip (network step) ...")
terra::setGDALconfig("GDAL_HTTP_MAX_RETRY", "3")
terra::setGDALconfig("GDAL_HTTP_RETRY_DELAY", "2")

mrdem_url <- paste0(
  "/vsicurl/https://canelevation-dem.s3.ca-central-1.amazonaws.com/",
  "mrdem-30/mrdem-30-dtm.tif"
)

dem_aoi <- st_sf(geometry = st_union(st_buffer(st_transform(test_photos, 3005), 5400)))
dem_src <- terra::rast(mrdem_url)
dem_clip <- terra::crop(
  dem_src,
  terra::vect(st_transform(dem_aoi, st_crs(terra::crs(dem_src)))),
  snap = "out"
)
dem_clip <- terra::project(dem_clip, "EPSG:3005")

# INT2S: elevations are metres, and a sub-metre DEM read is not meaningful at
# 30 m posting. Halves the file against FLT4S for no loss that matters here.
dem_path <- file.path(outdir, "dem.tif")
terra::writeRaster(
  dem_clip, dem_path, overwrite = TRUE, datatype = "INT2S",
  gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2", "TILED=YES")
)
message("dem.tif: ", paste(dim(dem_clip)[1:2], collapse = "x"), " cells at ",
        round(terra::res(dem_clip)[1], 1), " m, ",
        paste(round(as.vector(terra::minmax(dem_clip, compute = TRUE))), collapse = "-"),
        " m, ", round(file.size(dem_path) / 1024), " KB")

message("\nDone. Test data in: ", outdir)


# --- Digital centroids: real frames over the same AOI (#32) ----------------
#
# The 20 photos above are the 1968 film sample, so nothing in them can exercise the
# digital path. The AOI itself is not film-only though — it holds 181 `Digital - Colour`
# frames from two cameras with very different sensor shapes, which is what lets a test
# tell a correctly-shaped footprint from a square one:
#
#   121201_2011    Leica DMC II 230        87.1 x 79.2 mm   aspect 1.10
#   20814295_2018  UltraCam Eagle M3      105.8 x 68.0 mm   aspect 1.56
#
# Fetched through bcdata rather than a hand-built WFS URL: a `BBOX(SHAPE, ...)` CQL
# filter returns 0 features for this AOI — including for a control that certainly has
# frames — so the obvious query reports a false absence.

message("Fetching digital centroids (network step) ...")
dig <- bcdata::bcdc_query_geodata("WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP") |>
  bcdata::filter(bcdata::BBOX(local(test_bbox), crs = "EPSG:4326")) |>
  dplyr::filter(MEDIA == "Digital - Colour") |>
  bcdata::collect()

stopifnot(nrow(dig) > 0)
names(dig) <- tolower(names(dig))

# Keep whole flight lines rather than a random sample: `fly_bearing()` needs consecutive
# frames on a roll, and a scattered sample leaves every frame bearing-less.
set.seed(42)
keep <- dig |>
  dplyr::group_by(.data$film_roll) |>
  dplyr::arrange(.data$frame_number, .by_group = TRUE) |>
  dplyr::slice_head(n = 6) |>
  dplyr::ungroup()

keep <- keep |>
  dplyr::select(dplyr::any_of(c(
    "airp_id", "photo_year", "photo_date", "scale", "film_roll", "frame_number",
    "media", "photo_tag", "nts_tile", "focal_length", "flying_height",
    "ground_sample_distance", "thumbnail_image_url", "flight_log_url",
    "camera_calibration_url", "patb_georef_url", "geometry"
  )))

st_write(keep, file.path(outdir, "photo_centroids_digital.gpkg"),
         delete_dsn = TRUE, quiet = TRUE)
message("photo_centroids_digital.gpkg: ", nrow(keep), " frames, cameras ",
        paste(sort(unique(basename(keep$camera_calibration_url))), collapse = ", "))
