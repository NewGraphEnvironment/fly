# test_georef_decades.R — Visual QA: one georef thumbnail per decade
#
# Produces georeferenced thumbnails in a single directory for QGIS inspection.
# Requires stac_airphoto_bc centroid cache and downloaded thumbnails.
#
# Usage: source this script interactively, then load the output dir in QGIS.

library(sf)
library(dplyr)
devtools::load_all()

# --- Config ------------------------------------------------------------------

stac_dir <- "../stac_airphoto_bc"
cache_path <- file.path(stac_dir, "data/centroids_raw.parquet")
thumbs_dir <- file.path(stac_dir, "data/raw/thumbs")
out_dir <- file.path(stac_dir, "data/raw/georef/qa_decades")

stopifnot(
  "Centroid cache not found — run stac_airphoto_bc/scripts/01_fetch.R first" =
    file.exists(cache_path)
)

# --- Load centroids ----------------------------------------------------------

centroids <- arrow::read_parquet(cache_path) |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

centroids$decade <- floor(centroids$photo_year / 10) * 10

# --- Pick one photo per decade near Houston ----------------------------------
# Closest to AOI centre so footprints overlap for easy comparison

aoi_centre <- st_sfc(st_point(c(-126.65, 54.4)), crs = 4326)
centroids$dist <- as.numeric(st_distance(centroids, aoi_centre))

samples <- centroids |>
  group_by(decade) |>
  slice_min(dist, n = 1, with_ties = FALSE) |>
  ungroup() |>
  arrange(decade)

message(nrow(samples), " samples across decades: ",
        paste(samples$decade, collapse = ", "))

# --- Find raw thumbnails on disk ---------------------------------------------

samples$thumb_path <- vapply(seq_len(nrow(samples)), function(i) {
  year_dir <- file.path(thumbs_dir, samples$photo_year[i])
  if (!dir.exists(year_dir)) return(NA_character_)
  pattern <- paste0("^", samples$film_roll[i], "_",
                    sprintf("%03d", samples$frame_number[i]))
  files <- list.files(year_dir, pattern = pattern, full.names = TRUE)
  if (length(files) == 0) return(NA_character_)
  files[1]
}, character(1))

found <- !is.na(samples$thumb_path)
if (any(!found)) {
  message("Missing thumbnails for: ",
          paste(samples$film_roll[!found], samples$frame_number[!found],
                sep = "_", collapse = ", "))
}
samples <- samples[found, ]

# --- Georef with default rotation=180 ----------------------------------------

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

fetch_result <- dplyr::tibble(
  airp_id = samples$airp_id,
  url     = NA_character_,
  dest    = samples$thumb_path,
  success = TRUE
)

result <- fly_georef(fetch_result, samples, dest_dir = out_dir, overwrite = TRUE)

message("\n", sum(result$success), "/", nrow(result), " georeferenced")
message("Output: ", normalizePath(out_dir))
message("Open in QGIS: open ", normalizePath(out_dir))

# --- Summary table -----------------------------------------------------------

summary_tbl <- samples |>
  st_drop_geometry() |>
  select(decade, photo_year, film_roll, frame_number, scale) |>
  mutate(
    georef_ok = result$success,
    output = basename(result$dest)
  )

print(as.data.frame(summary_tbl))
