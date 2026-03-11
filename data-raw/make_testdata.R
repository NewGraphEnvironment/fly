#!/usr/bin/env Rscript
#
# make_testdata.R
#
# Generate bundled test data from Upper Bulkley River floodplain.
# Crop near Houston, BC.
# Dual-scale coverage: 1:12000 and 1:31680 (1968).
#
# Source: diggs cached data (BC Data Catalogue + flooded VCA output)
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

message("\nDone. Test data in: ", outdir)
