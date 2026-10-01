# dem_measure-canopy_height.R — does a bare-earth DEM size a forested frame wrong? (fly#80)
#
# `fly_footprint(dem =)` sizes a frame from the mean of the DEM under it, and the DEM the
# documentation recommends, MRDEM-30's DTM, is bare earth. Over forest the camera images the
# canopy, so a frame there is drawn too wide by about `canopy / height_agl`. fly#65 bounded
# that only to first order, under a uniform canopy. This script measures it.
#
# MRDEM-30 publishes a DSM on the DTM's own grid, so the obvious instrument is DSM - DTM. It is
# not independent everywhere: outside lidar the DTM *is* the DSM minus NRCan's forest-removal
# model (product specification §7.2), so on those cells DSM - DTM is that model. The source
# layer says which cells are which, and two witnesses NRCan's pipeline did not produce are
# read beside it: the HRDEM lidar mosaic, where it covers cells MRDEM took from radar, and
# Meta/WRI's canopy height model. The rule each is judged by was fixed before any frame was
# measured, in fly#80's archived planning findings ("Decision rule", "Amendment 1"). Read it
# before changing any threshold here.
#
# Everything is public: the airphoto centroid layer and VRI of the BC Data Catalogue, NRCan's
# MRDEM-30 and HRDEM mosaic, and Meta/WRI's canopy height model on AWS Open Data.
#
# Usage, from the repo root, after `height_calibrate-flying_height_slip.R` has built the
# centroid cache and `dem_measure-coastal_water.R` its land tiles:
#   Rscript data-raw/dem_measure-canopy_height.R
#
#   Stage 0  inputs and their versions
#   Stage 1  what DSM - DTM is: source layer, sea, a noise floor, and the witnesses
#   Stage 2  census: a coarse canopy shift for every DEM-eligible film frame, to stratify
#   Stage 3  a probability sample sized through `fly_footprint()` on both surfaces, and
#            ray-cast on both
#   Stage 4  epoch: the stand at photo date, from VRI
#   Stage 5  the verdicts; write `inst/extdata/dem_canopy_*.csv`
#
#   FLY_CANOPY_SMOKE=1 runs a handful of frames into a separate cache and writes nothing
#   FLY_CANOPY_STOP=<n> stops after stage n

pkgload::load_all(quiet = TRUE)
suppressMessages({
  library(sf)
  library(terra)
})
sf::sf_use_s2(FALSE)

cap_memory <- function() {
  terra::gdalCache(128)
  terra::terraOptions(memfrac = 0.05, memmax = 1, progress = 0)
  invisible(TRUE)
}
cap_memory()

CENTROIDS  <- "data-raw/.cache/centroids"
LAND_TILES <- "data-raw/.cache/dem_coastal/land_tiles.rds"
SMOKE      <- nzchar(Sys.getenv("FLY_CANOPY_SMOKE"))
STOP_AFTER <- as.integer(Sys.getenv("FLY_CANOPY_STOP", "99"))
CACHE      <- if (SMOKE) "data-raw/.cache/dem_canopy_smoke" else "data-raw/.cache/dem_canopy"
META_DIR   <- "data-raw/.cache/dem_canopy"          # the Meta tiles are shared by both
BUCKET     <- "https://canelevation-dem.s3.ca-central-1.amazonaws.com"
MRDEM_DTM  <- paste0("/vsicurl/", BUCKET, "/mrdem-30/mrdem-30-dtm.tif")
MRDEM_DSM  <- paste0("/vsicurl/", BUCKET, "/mrdem-30/mrdem-30-dsm.tif")
MRDEM_SRC  <- paste0("/vsicurl/", BUCKET, "/mrdem-30/mrdem-30-source.tif")
META_URL   <- "https://dataforgood-fb-data.s3.amazonaws.com/forests/v1/alsgedi_global_v6_float_epsg4326_v3_10deg"
META_TILES <- c("lat=60.0_lon=-140.0", "lat=60.0_lon=-130.0", "lat=60.0_lon=-120.0",
                "lat=50.0_lon=-130.0", "lat=50.0_lon=-120.0")
REPO       <- normalizePath(".")
WORKERS    <- as.integer(Sys.getenv("FLY_DEM_CALIB_WORKERS", "3"))
FORMAT_M   <- 9 * 0.0254

stopifnot(dir.exists(CENTROIDS), file.exists(LAND_TILES))
dir.create(CACHE, recursive = TRUE, showWarnings = FALSE)

write_if_changed <- function(d, path) {
  tmp <- tempfile(fileext = ".csv")
  needs <- which(vapply(d, function(v) is.character(v) && any(grepl('[",\n]', v)),
                        logical(1)))
  utils::write.csv(d, tmp, row.names = FALSE, na = "",
                   quote = if (length(needs)) needs else FALSE)
  if (!file.exists(path) || tools::md5sum(tmp) != tools::md5sum(path)) {
    file.copy(tmp, path, overwrite = TRUE) || stop("could not write ", path)
    message("wrote ", path, " (", nrow(d), " rows)")
  } else {
    message(path, " unchanged")
  }
}
save_atomic <- function(x, path) {
  tmp <- paste0(path, ".part")
  saveRDS(x, tmp)
  stopifnot(file.rename(tmp, path))
  invisible(path)
}
pub <- function(...) message(sprintf(...))

# The ray-cast and its helpers, taken from the fly#65 script rather than copied: that script
# is a closed measurement and is not edited, and a second copy would drift. Only the named
# top-level function definitions are evaluated; nothing else in it runs.
fns_from <- function(path, names) {
  ex <- parse(path, keep.source = FALSE)
  got <- character(0)
  for (e in ex) {
    if (is.call(e) && identical(e[[1]], as.name("<-")) && is.name(e[[2]]) &&
        as.character(e[[2]]) %in% names && is.call(e[[3]]) &&
        identical(e[[3]][[1]], as.name("function"))) {
      eval(e, envir = globalenv())
      got <- c(got, as.character(e[[2]]))
    }
  }
  missing <- setdiff(names, got)
  if (length(missing)) stop("not found in ", path, ": ", paste(missing, collapse = ", "))
  invisible(got)
}
fns_from("data-raw/dem_measure-coastal_water.R", c("raycast", "densify", "close_ring"))

# ---------------------------------------------------------------------------
# Stage 0 — inputs, and the version of each remote one
# ---------------------------------------------------------------------------

# MRDEM was regenerated on 2026-06-22; a cache built against another version is not this
# measurement. Every cache below is keyed on these.
head_of <- function(url) {
  h <- curl::curl_fetch_memory(url, handle = curl::new_handle(nobody = TRUE))
  hd <- curl::parse_headers_list(h$headers)
  c(status = h$status_code, etag = gsub('"', "", hd[["etag"]] %||% ""),
    modified = hd[["last-modified"]] %||% "", bytes = hd[["content-length"]] %||% "")
}
`%||%` <- function(a, b) if (is.null(a)) b else a
VERSIONS <- do.call(rbind, lapply(c(dtm = MRDEM_DTM, dsm = MRDEM_DSM, source = MRDEM_SRC),
                                  function(u) head_of(sub("^/vsicurl/", "", u))))
VERSIONS <- data.frame(asset = rownames(VERSIONS), VERSIONS, row.names = NULL)
for (i in seq_len(nrow(VERSIONS))) {
  pub("  version %-6s %s etag %s modified %s", VERSIONS$asset[i], VERSIONS$status[i],
      VERSIONS$etag[i], VERSIONS$modified[i])
}
stopifnot(all(VERSIONS$status == "200"))
vtmp <- tempfile()
writeLines(paste(VERSIONS$etag, collapse = "|"), vtmp)
VKEY <- substr(unname(tools::md5sum(vtmp)), 1, 8)
unlink(vtmp)
pub("  cache key %s", VKEY)
meta_paths <- file.path(META_DIR, paste0("meta_chm_", META_TILES, "_avg.tif"))
for (k in seq_along(META_TILES)) {
  if (!file.exists(meta_paths[k])) {
    stop("missing ", meta_paths[k], ": download ", META_URL, "/meta_chm_", META_TILES[k],
         "_avg.tif into ", META_DIR)
  }
}
pub("  Meta CHM: %d local 10-degree tiles, %.1f GB", length(meta_paths),
    sum(file.size(meta_paths)) / 1e9)

dtm <- terra::rast(MRDEM_DTM)
dsm <- terra::rast(MRDEM_DSM)
src <- terra::rast(MRDEM_SRC)
# The whole comparison rests on the two surfaces sharing a grid.
stopifnot(terra::compareGeom(dtm, dsm, stopOnError = FALSE),
          terra::compareGeom(dtm, src, stopOnError = FALSE))

# ---------------------------------------------------------------------------
# Stage 1 — what DSM - DTM is
# ---------------------------------------------------------------------------

# A square window about a point, snapped out to the MRDEM grid, read from all three layers.
window_at <- function(lon, lat, half = 1500) {
  p <- sf::st_transform(sf::st_sfc(sf::st_point(c(lon, lat)), crs = 4326), terra::crs(dtm))
  xy <- sf::st_coordinates(p)
  e <- terra::align(terra::ext(xy[1] - half, xy[1] + half, xy[2] - half, xy[2] + half),
                    dtm, snap = "out")
  list(dtm = terra::toMemory(terra::crop(dtm, e)), dsm = terra::toMemory(terra::crop(dsm, e)),
       src = terra::toMemory(terra::crop(src, e)), ext = e)
}

# Meta's mean canopy height on the MRDEM window's grid. Meta's `avg` tiles carry the mean of
# its 1 m model per 0.00025-degree cell, in centimetres (the units are checked against the
# lidar sites below, not assumed); they are averaged again onto the 30 m grid.
meta_on <- function(template) {
  bb <- sf::st_bbox(sf::st_transform(sf::st_as_sfc(sf::st_bbox(
    as.vector(terra::ext(template))[c(1, 3, 2, 4)] |> stats::setNames(c("xmin", "ymin", "xmax", "ymax")),
    crs = sf::st_crs(terra::crs(template)))), 4326))
  hits <- lapply(meta_paths, function(f) {
    r <- terra::rast(f)
    e <- terra::intersect(terra::ext(r), terra::ext(bb[c(1, 3, 2, 4)]))
    if (is.null(e)) return(NULL)
    terra::crop(r, terra::ext(bb[1] - .01, bb[3] + .01, bb[2] - .01, bb[4] + .01))
  })
  hits <- Filter(Negate(is.null), hits)
  if (!length(hits)) return(NULL)
  m <- if (length(hits) == 1) hits[[1]] else do.call(terra::merge, hits)
  # The tiles declare no nodata; no canopy is 100 m tall, so anything above is not a height.
  m <- terra::clamp(m, 0, 10000, values = FALSE)
  terra::project(m / 100, template, method = "average")
}

# HRDEM's 2 m lidar mosaic on the MRDEM window's grid, where a partition covers it.
HRDEM_PARTS <- c("1_3", "1_4", "1_5", "1_6", "1_7", "2_3", "2_4", "2_5", "2_6",
                 "3_3", "3_4", "3_5", "3_6")
HRDEM <- list()
hrdem_on <- function(template, what) {
  if (is.null(HRDEM[[what]])) {
    HRDEM[[what]] <<- lapply(HRDEM_PARTS, function(pt) {
      terra::rast(sprintf("/vsicurl/%s/hrdem-mosaic-2m/%s-mosaic-2m-%s.tif", BUCKET, pt, what))
    })
  }
  out <- NULL
  for (r in HRDEM[[what]]) {
    # The HRDEM mosaic is in MRDEM's own CRS (EPSG:3979); asserted rather than reprojected.
    stopifnot(terra::same.crs(r, template))
    e <- terra::intersect(terra::ext(r), terra::ext(template))
    if (is.null(e)) next
    w <- terra::crop(r, e)
    if (all(is.na(terra::values(w)))) next
    a <- terra::project(w, template, method = "average")
    out <- if (is.null(out)) a else terra::cover(out, a)
  }
  out
}

fin <- function(x) x[is.finite(x)]
q <- function(x, p) unname(stats::quantile(x, p, na.rm = TRUE))

SITES_CSV <- file.path(CACHE, paste0("sites_", VKEY, ".rds"))
if (!file.exists(SITES_CSV)) {
  # Sea: the nine fly#65 sites, on the DSM. The fly#65 verdict rests on near-shore sea
  # reading ~0.14 m; a DSM that read differently there would move every coastal frame.
  coastal <- utils::read.csv("inst/extdata/dem_coastal_sites.csv", stringsAsFactors = FALSE)
  tiles <- readRDS(LAND_TILES)
  sea_rows <- lapply(seq_len(nrow(coastal)), function(i) {
    w <- window_at(coastal$lon[i], coastal$lat[i])
    xy <- terra::xyFromCell(w$dtm, seq_len(terra::ncell(w$dtm)))
    pts <- sf::st_transform(sf::st_as_sf(as.data.frame(xy), coords = c("x", "y"),
                                         crs = terra::crs(dtm)), 3005)
    near <- tiles[lengths(sf::st_intersects(tiles, sf::st_as_sfc(sf::st_bbox(pts)))) > 0, ]
    land <- if (nrow(near)) lengths(sf::st_intersects(pts, near)) > 0 else rep(FALSE, nrow(xy))
    a <- terra::values(w$dtm)[, 1]; s <- terra::values(w$dsm)[, 1]
    data.frame(kind = "sea", site = coastal$site[i], lon = coastal$lon[i], lat = coastal$lat[i],
               n = sum(!land), n_na_dtm = sum(!land & !is.finite(a)),
               n_na_dsm = sum(!land & !is.finite(s)),
               dtm_median = stats::median(fin(a[!land])), dsm_median = stats::median(fin(s[!land])),
               diff_mean = mean(fin((s - a)[!land])), diff_p95 = q(abs(s - a)[!land], .95),
               src1 = mean(terra::values(w$src)[!land, 1] %in% 1),
               src10 = mean(terra::values(w$src)[!land, 1] %in% 10),
               meta_mean = NA_real_, hrdem_mean = NA_real_, hrdem_n = NA_integer_,
               dtm_vs_hrdem = NA_real_)
  })

  # Canopy and non-canopy sites, each a 3 km window. The non-forest ones are the noise
  # floor: over a lake, farmland, grassland or bare rock DSM - DTM should be ~0, and what it
  # reads there is the error of the difference itself.
  SITES <- data.frame(
    kind = c(rep("floor", 6), rep("canopy", 8)),
    site = c("okanagan_lake", "fraser_delta_farm", "peace_farm", "chilcotin_grass",
             "spatsizi_alpine", "chilko_lake",
             "carmanah_oldgrowth", "revelstoke_wetbelt", "houston_pine", "fort_nelson_boreal",
             "elephant_hill_burn", "quesnel_interior", "haida_gwaii_forest", "sunshine_coast"),
    lon = c(-119.52, -123.05, -120.60, -122.90, -128.60, -124.10,
            -124.66, -118.15, -126.60, -122.60, -121.20, -122.30, -132.05, -123.75),
    lat = c(49.95, 49.10, 56.25, 51.90, 57.70, 51.30,
            48.65, 51.05, 54.40, 58.70, 51.00, 52.95, 53.25, 49.60))
  site_rows <- lapply(seq_len(nrow(SITES)), function(i) {
    w <- window_at(SITES$lon[i], SITES$lat[i])
    a <- terra::values(w$dtm)[, 1]; s <- terra::values(w$dsm)[, 1]
    mt <- meta_on(w$dtm)
    hs <- hrdem_on(w$dtm, "dsm"); ht <- if (!is.null(hs)) hrdem_on(w$dtm, "dtm") else NULL
    hv <- if (!is.null(hs)) terra::values(hs)[, 1] else rep(NA_real_, length(a))
    hg <- if (!is.null(ht)) terra::values(ht)[, 1] else rep(NA_real_, length(a))
    data.frame(kind = SITES$kind[i], site = SITES$site[i], lon = SITES$lon[i], lat = SITES$lat[i],
               n = length(a), n_na_dtm = sum(!is.finite(a)), n_na_dsm = sum(!is.finite(s)),
               dtm_median = stats::median(fin(a)), dsm_median = stats::median(fin(s)),
               diff_mean = mean(fin(s - a)), diff_p95 = q(abs(s - a), .95),
               src1 = mean(terra::values(w$src)[, 1] %in% 1),
               src10 = mean(terra::values(w$src)[, 1] %in% 10),
               meta_mean = if (is.null(mt)) NA_real_ else mean(fin(terra::values(mt)[, 1])),
               # HRDEM's own canopy (its DSM minus its DTM) and MRDEM's DTM against HRDEM's,
               # both only on cells HRDEM covers.
               hrdem_mean = if (any(is.finite(hv - hg))) mean(fin(hv - hg)) else NA_real_,
               hrdem_n = sum(is.finite(hv - hg)),
               dtm_vs_hrdem = if (any(is.finite(a - hg))) mean(fin(a - hg)) else NA_real_)
  })
  sites_out <- do.call(rbind, c(sea_rows, site_rows))
  save_atomic(sites_out, SITES_CSV)
}
sites_out <- readRDS(SITES_CSV)
for (i in seq_len(nrow(sites_out))) {
  s <- sites_out[i, ]
  pub("  site %-6s %-20s n=%5d src1 %.2f src10 %.2f | DTM %7.2f DSM %7.2f | DSM-DTM mean %6.2f p95|.| %6.2f | Meta %6.2f | HRDEM canopy %6.2f (n=%s) DTM-HRDEM DTM %6.2f",
      s$kind, s$site, s$n, s$src1, s$src10, s$dtm_median, s$dsm_median, s$diff_mean, s$diff_p95,
      s$meta_mean, s$hrdem_mean, s$hrdem_n, s$dtm_vs_hrdem)
}

# The source layer over BC: how much of the province MRDEM took from radar (1), lidar (10),
# or a blend (5). Read coarse through the COG's overviews, nearest, so each value is a real
# code; a share, not a map.
tiles <- readRDS(LAND_TILES)
SRC_COARSE <- file.path(CACHE, paste0("source_coarse_", VKEY, ".tif"))
if (!file.exists(SRC_COARSE)) {
  bb <- sf::st_bbox(sf::st_transform(sf::st_as_sfc(sf::st_bbox(
    c(xmin = 150000, ymin = 330000, xmax = 1900000, ymax = 1800000), crs = 3005)),
    terra::crs(src)))
  tmp <- paste0(SRC_COARSE, ".part")
  sf::gdal_utils("translate", MRDEM_SRC, tmp, options = c(
    "-projwin", as.character(bb[1]), as.character(bb[4]), as.character(bb[3]), as.character(bb[2]),
    "-outsize", "2400", "0", "-r", "nearest", "-of", "GTiff"))
  stopifnot(file.rename(tmp, SRC_COARSE))
}
sc <- terra::rast(SRC_COARSE)
ON_LAND <- file.path(CACHE, paste0("source_on_land_", VKEY, ".rds"))
if (!file.exists(ON_LAND)) {
  scp <- sf::st_transform(sf::st_as_sf(as.data.frame(terra::xyFromCell(sc, seq_len(terra::ncell(sc)))),
                                       coords = c("x", "y"), crs = terra::crs(sc)), 3005)
  save_atomic(lengths(sf::st_intersects(scp, tiles)) > 0, ON_LAND)
  rm(scp)
}
on_land <- readRDS(ON_LAND)
sv <- terra::values(sc)[on_land, 1]
SRC_SHARE <- c(radar = mean(sv %in% 1), blend = mean(sv %in% 5), lidar = mean(sv %in% 10),
               none = mean(!sv %in% c(1, 5, 10)))
pub("  MRDEM source over BC land (%d coarse cells at %.0f m): radar %.3f, blend %.3f, lidar %.3f, other/none %.3f",
    length(sv), terra::res(sc)[1], SRC_SHARE[["radar"]], SRC_SHARE[["blend"]], SRC_SHARE[["lidar"]],
    SRC_SHARE[["none"]])

# Does any lidar ground in NRCan's own HRDEM mosaic sit under cells MRDEM took from radar?
# Measured, not assumed: random points in the HRDEM *DTM* coverage over BC (its DSM reaches
# much further — partition 1_5 is 41 GB of DSM against 5.8 GB of DTM, and on the radar cells
# probed that extra DSM is smooth far-north surface, not lidar), kept where MRDEM's source is
# radar. It found none, so HRDEM cannot check MRDEM's radar cells; it was the witness planned.
HRDEM_COUNT <- file.path(CACHE, paste0("hrdem_radar_count_", VKEY, ".rds"))
if (!file.exists(HRDEM_COUNT)) {
  cov <- do.call(c, lapply(HRDEM_PARTS, function(pt) {
    sf::st_geometry(sf::st_read(file.path(META_DIR, sprintf("hrdem_%s-coverage.gpkg", pt)),
                                layer = "dtm", quiet = TRUE))
  }))
  cov <- sf::st_transform(sf::st_union(cov), 3005)
  cov <- sf::st_intersection(cov, sf::st_union(sf::st_geometry(tiles)))
  # Every draw is seeded where it happens, so it does not depend on which caches existed.
  set.seed(80)
  cand <- sf::st_sample(cov, if (SMOKE) 200 else 3000)
  cv <- terra::extract(src, terra::vect(sf::st_transform(cand, terra::crs(src))))[, 2]
  save_atomic(c(n = length(cv), radar = sum(cv %in% 1), lidar = sum(cv %in% 10),
                blend = sum(cv %in% 5)), HRDEM_COUNT)
}
hc <- readRDS(HRDEM_COUNT)
pub("  HRDEM lidar ground over BC: %d random points; on MRDEM radar cells %d, lidar %d, blend %d",
    hc[["n"]], hc[["radar"]], hc[["lidar"]], hc[["blend"]])

# LidarBC is the witness instead. The province's own lidar, 1 m tiles with a bare-earth DEM
# and (on most) a DSM from the same flight, served through the public `stac-elevation-bc`
# collection (images.a11s.one), CGVD2013 like MRDEM, and almost all flown after MRDEM's radar
# (2011-2015). Random radar cells over BC land; the newest tile carrying both a DEM and a DSM
# under each; every MRDEM cell of that tile that is radar-sourced and has all four values.
LIDAR_PROBE <- file.path(CACHE, paste0("lidarbc_probe_", VKEY, ".rds"))
N_LIDAR <- if (SMOKE) 5 else 150
PROBE_DIR <- file.path(CACHE, paste0("lidarbc_windows_", VKEY))
dir.create(PROBE_DIR, showWarnings = FALSE)
lidar_window <- function(both, pt) {
  f <- both[[order(vapply(both, function(f) f$properties$datetime, ""), decreasing = TRUE)[1]]]
  # Downloaded, not read over /vsicurl/: these tiles are strip-organised (one row per
  # block), and `terra::project()` over a remote strip TIFF issues a range request per strip
  # per pass — the first run of this probe took 6.5 hours. A whole tile is ~8 MB and 1.5 s.
  tf <- tempfile(fileext = c(".dem.tif", ".dsm.tif"))
  on.exit(unlink(tf), add = TRUE)
  curl::curl_download(f$assets$dem$href, tf[1], quiet = TRUE)
  curl::curl_download(f$assets$dsm$href, tf[2], quiet = TRUE)
  # Some tiles carry an undeclared nodata of -3.4e38, which a mean takes as data (the first
  # complete run published means of 1e37). Anything outside BC's possible elevations is nodata.
  dem_l <- terra::clamp(terra::rast(tf[1]), -100, 5000, values = FALSE)
  dsm_l <- terra::clamp(terra::rast(tf[2]), -100, 5100, values = FALSE)
  tb <- terra::project(terra::as.polygons(terra::ext(dem_l), crs = terra::crs(dem_l)), terra::crs(dtm))
  e <- terra::align(terra::ext(tb), dtm, snap = "in")
  if (terra::xmax(e) <= terra::xmin(e) || terra::ymax(e) <= terra::ymin(e)) return(NULL)
  a <- terra::toMemory(terra::crop(dtm, e)); s <- terra::toMemory(terra::crop(dsm, e))
  sr <- terra::toMemory(terra::crop(src, e))
  lg <- terra::project(dem_l, a, method = "average")
  ls <- terra::project(dsm_l, a, method = "average")
  av <- terra::values(a)[, 1]; svv <- terra::values(s)[, 1]
  hg <- terra::values(lg)[, 1]; hv <- terra::values(ls)[, 1]
  ok <- is.finite(av) & is.finite(svv) & is.finite(hg) & is.finite(hv) & terra::values(sr)[, 1] %in% 1
  if (sum(ok) < 100) return(NULL)
  mt <- tryCatch(meta_on(a), error = function(e) NULL)
  mv <- if (is.null(mt)) rep(NA_real_, length(av)) else terra::values(mt)[, 1]
  lc <- hv - hg
  open <- ok & lc < 1   # open ground in the lidar: the datum and ground error with no canopy
  data.frame(
    lon = pt[1], lat = pt[2], year = as.integer(substr(f$properties$datetime, 1, 4)),
    tile = basename(f$assets$dem$href), n = sum(ok), n_open = sum(open),
    mrdem_canopy = mean(svv[ok] - av[ok]),   # MRDEM DSM - DTM: NRCan's removal model here
    lidar_canopy = mean(lc[ok]),             # LidarBC DSM - DEM: measured
    dtm_resid = mean(av[ok] - hg[ok]),       # MRDEM DTM above lidar ground
    dtm_resid_open = if (any(open)) mean(av[open] - hg[open]) else NA_real_,
    dsm_resid = mean(svv[ok] - hv[ok]),      # radar DSM against the lidar surface
    imaged_over_dtm = mean(hv[ok] - av[ok]), # the lidar surface above what fly sizes from
    meta_canopy = mean(mv[ok], na.rm = TRUE),
    relief = stats::sd(hg[ok]))
}
if (!file.exists(LIDAR_PROBE)) {
  radar_cells <- which(on_land)[sv %in% 1]
  set.seed(80)
  pick <- radar_cells[sample.int(length(radar_cells), if (SMOKE) 60 else 1500)]
  xy <- terra::xyFromCell(sc, pick) +
    matrix(stats::runif(2 * length(pick), -.5, .5) * terra::res(sc)[1], ncol = 2)
  ll <- sf::st_coordinates(sf::st_transform(sf::st_as_sf(as.data.frame(xy), coords = c("x", "y"),
                                                         crs = terra::crs(sc)), 4326))
  stac <- rstac::stac("https://images.a11s.one/")
  n_hit <- 0L
  n_fail <- 0L
  rows <- list()
  for (i in seq_len(nrow(ll))) {
    if (length(rows) >= N_LIDAR) break
    it <- tryCatch(
      stac |> rstac::stac_search(collections = "stac-elevation-bc",
                                 intersects = list(type = "Point", coordinates = unname(ll[i, ])),
                                 limit = 50) |> rstac::post_request(),
      error = function(e) NULL)
    if (is.null(it) || !length(it$features)) next
    both <- Filter(function(f) all(c("dem", "dsm") %in% names(f$assets)), it$features)
    if (!length(both)) next
    n_hit <- n_hit + 1L
    cache_i <- file.path(PROBE_DIR, sprintf("p%04d.rds", i))
    if (file.exists(cache_i)) {
      got <- readRDS(cache_i)
    } else {
      # A remote tile read can fail part-way (seen: a strip short by half on
      # bc_094a055_..._20240527). Retried once; a second failure is counted, not hidden.
      got <- tryCatch(lidar_window(both, ll[i, ]), error = function(e) {
        tryCatch(lidar_window(both, ll[i, ]),
                 error = function(e2) structure(conditionMessage(e2), class = "probe_error"))
      })
      save_atomic(got, cache_i)
    }
    if (inherits(got, "probe_error")) { n_fail <- n_fail + 1L; next }
    if (!is.null(got)) rows[[length(rows) + 1]] <- got
  }
  lp <- if (length(rows)) do.call(rbind, rows) else NULL
  pub("  LidarBC probe: %d radar points tried, %d under a tile with DEM and DSM, %d windows kept, %d reads failed twice",
      i, n_hit, if (is.null(lp)) 0L else nrow(lp), n_fail)
  # Refuse rather than cache a hole: an empty probe is a failed probe, not a finding.
  if (is.null(lp) || nrow(lp) < min(30, N_LIDAR)) stop("LidarBC probe returned too few windows")
  save_atomic(lp, LIDAR_PROBE)
}
lp <- readRDS(LIDAR_PROBE)
pub("  lidar probe: %d windows on radar cells, median %d cells each", nrow(lp), as.integer(stats::median(lp$n)))
pub("  lidar probe: tile years %s", paste(names(table(lp$year)), table(lp$year), sep = ":", collapse = " "))
for (v in c("mrdem_canopy", "lidar_canopy", "dtm_resid", "dtm_resid_open", "dsm_resid", "imaged_over_dtm", "meta_canopy")) {
  pub("  lidar probe %-16s median %6.2f m, mean %6.2f, 10th %6.2f, 90th %6.2f",
      v, stats::median(lp[[v]], na.rm = TRUE), mean(lp[[v]], na.rm = TRUE), q(lp[[v]], .1), q(lp[[v]], .9))
}
fit <- function(y, x) { k <- is.finite(x) & is.finite(y); unname(stats::coef(stats::lm(y[k] ~ 0 + x[k]))) }
pub("  lidar probe: imaged_over_dtm / mrdem_canopy through origin %.3f; meta / lidar %.3f; mrdem / lidar %.3f; cor(mrdem, lidar) %.3f",
    fit(lp$imaged_over_dtm, lp$mrdem_canopy), fit(lp$meta_canopy, lp$lidar_canopy),
    fit(lp$mrdem_canopy, lp$lidar_canopy), stats::cor(lp$mrdem_canopy, lp$lidar_canopy))
if (STOP_AFTER <= 1) quit(save = "no")

# ---------------------------------------------------------------------------
# Stage 2 — census: a coarse canopy shift for every DEM-eligible film frame
# ---------------------------------------------------------------------------

# Used only to stratify the sample and to bin the population (Amendment 1): a coarse read
# cannot carry a tail statistic. The DSM and DTM are read through the same window at the same
# size, with the COG's overviews averaged, and asserted onto one grid — a misaligned pair
# would turn a terrain gradient into "canopy".
CENSUS <- file.path(CACHE, paste0("census_", VKEY, ".rds"))
CENSUS_OUT <- if (SMOKE) 700 else 7000
if (!file.exists(CENSUS)) {
  frames <- do.call(rbind, lapply(list.files(CENTROIDS, "\\.rds$", full.names = TRUE), readRDS))
  stopifnot(!anyDuplicated(frames$airp_id))
  frames$scale_n <- suppressWarnings(as.numeric(sub("^1:", "", frames$scale)))
  # fly#58's eligibility, unchanged, so the denominator is the one it published.
  film <- frames[frames$media %in% fly_film_media() &
                   is.finite(frames$scale_n) & frames$scale_n > 0 &
                   is.finite(frames$flying_height) & frames$flying_height > 0 &
                   is.finite(frames$focal_length) & frames$focal_length > 0, ]
  rm(frames)
  bb <- sf::st_bbox(sf::st_transform(sf::st_as_sfc(sf::st_bbox(
    c(xmin = 150000, ymin = 330000, xmax = 1900000, ymax = 1800000), crs = 3005)), terra::crs(dtm)))
  coarse <- function(url, what) {
    path <- file.path(CACHE, sprintf("%s_coarse_%s_%d.tif", what, VKEY, CENSUS_OUT))
    if (!file.exists(path)) {
      tmp <- paste0(path, ".part")
      sf::gdal_utils("translate", url, tmp, options = c(
        "-projwin", as.character(bb[1]), as.character(bb[4]), as.character(bb[3]), as.character(bb[2]),
        "-outsize", as.character(CENSUS_OUT), "0", "-r", "average", "-of", "GTiff"))
      stopifnot(file.rename(tmp, path))
    }
    terra::rast(path)
  }
  cd <- coarse(MRDEM_DSM, "dsm"); ct <- coarse(MRDEM_DTM, "dtm")
  stopifnot(terra::compareGeom(cd, ct, stopOnError = FALSE))
  res_c <- terra::res(cd)[1]
  # Summed-area tables of canopy and of valid-cell count, so every frame's box mean is four
  # lookups. Negative DSM - DTM is kept: clipping it to zero would bias the mean up.
  cm <- terra::as.matrix(cd - ct, wide = TRUE)
  ok <- is.finite(cm)
  cm[!ok] <- 0
  sat <- function(m) {
    s <- apply(m, 2, cumsum)
    t(apply(s, 1, cumsum))
  }
  S <- sat(cm); K <- sat(ok * 1)
  rm(cm, ok)
  box <- function(tab, r0, r1, c0, c1) {
    g <- function(r, c) ifelse(r < 1 | c < 1, 0, tab[cbind(pmax(r, 1), pmax(c, 1))])
    g(r1, c1) - g(r0 - 1, c1) - g(r1, c0 - 1) + g(r0 - 1, c0 - 1)
  }
  xy <- sf::st_coordinates(sf::st_transform(sf::st_as_sf(film[, c("x", "y")], coords = c("x", "y"),
                                                         crs = 3005), terra::crs(cd)))
  col <- (xy[, 1] - terra::xmin(cd)) / res_c + 0.5
  row <- (terra::ymax(cd) - xy[, 2]) / res_c + 0.5
  half <- FORMAT_M * film$scale_n / 2 / res_c
  r0 <- pmax(1, round(row - half)); r1 <- pmin(nrow(S), round(row + half))
  c0 <- pmax(1, round(col - half)); c1 <- pmin(ncol(S), round(col + half))
  inside <- r1 >= r0 & c1 >= c0
  n_c <- ifelse(inside, box(K, r0, r1, c0, c1), 0)
  film$c_census <- ifelse(n_c > 0, box(S, r0, r1, c0, c1) / pmax(n_c, 1), NA_real_)
  film$n_census <- n_c
  rm(S, K)
  film$agl_nominal <- film$scale_n * film$focal_length / 1000
  film$p_census <- film$c_census / film$agl_nominal
  film$decade <- 10 * (film$photo_year %/% 10)
  film$scale_band <- as.character(cut(film$scale_n, c(0, 15000, 30000, Inf),
                                      labels = c("fine", "mid", "coarse")))
  film$p_band <- as.character(cut(film$p_census, c(-Inf, .0025, .005, .01, .02, Inf),
                                  labels = c("p_lt_0.25", "p_0.25_0.5", "p_0.5_1", "p_1_2", "p_ge_2")))
  save_atomic(film[, c("airp_id", "photo_year", "decade", "film_roll", "frame_number", "scale",
                       "scale_n", "scale_band", "media", "focal_length", "flying_height", "x", "y",
                       "c_census", "n_census", "agl_nominal", "p_census", "p_band")], CENSUS)
  rm(film)
}
census <- readRDS(CENSUS)
pub("  census: %d DEM-eligible film frames; %d with no coarse canopy under them (%.2f%%)",
    nrow(census), sum(is.na(census$p_census)), 100 * mean(is.na(census$p_census)))
pub("  census p (coarse canopy / nominal agl): median %.4f, 90th %.4f, 95th %.4f, 99th %.4f; share over 0.5%% %.3f, over 1%% %.3f",
    stats::median(census$p_census, na.rm = TRUE), q(census$p_census, .9), q(census$p_census, .95),
    q(census$p_census, .99), mean(census$p_census > .005, na.rm = TRUE),
    mean(census$p_census > .01, na.rm = TRUE))
pub("  census years %d-%d; share from 1985 on %.3f", min(census$photo_year), max(census$photo_year),
    mean(census$photo_year >= 1985))
P_EDGES <- c(-Inf, 0, .001, .0025, .005, .0075, .01, .015, .02, .03, .05, Inf)
cen_bin <- stats::aggregate(list(n = rep(1L, nrow(census))),
                            list(decade = census$decade, scale_band = census$scale_band,
                                 p_bin = as.character(cut(census$p_census, P_EDGES, right = FALSE))),
                            length)
na_bin <- stats::aggregate(list(n = rep(1L, sum(is.na(census$p_census)))),
                           list(decade = census$decade[is.na(census$p_census)],
                                scale_band = census$scale_band[is.na(census$p_census)]), length)
if (nrow(na_bin)) cen_bin <- rbind(cen_bin, data.frame(na_bin[, 1:2], p_bin = "none", n = na_bin$n))
cen_bin <- cen_bin[order(cen_bin$decade, cen_bin$scale_band, cen_bin$p_bin), ]
stopifnot(sum(cen_bin$n) == nrow(census))
if (STOP_AFTER <= 2) quit(save = "no")

# ---------------------------------------------------------------------------
# Stage 3 — the probability sample: both surfaces through `fly_footprint()`, and ray-cast
# ---------------------------------------------------------------------------

# Controls first. The fly#65 flat and step controls are re-run here because the ray-cast is
# re-used, and three canopy-specific ones are added (review G5).
H0 <- 3000; F0 <- 0.153; A0 <- 0.1143 / F0
synth <- function(fun, res = 10) {
  r <- terra::rast(xmin = 1e6 - 3000, xmax = 1e6 + 3000, ymin = 5e5 - 3000, ymax = 5e5 + 3000,
                   resolution = res, crs = "EPSG:3005")
  terra::values(r) <- fun(terra::xFromCell(r, seq_len(terra::ncell(r))),
                          terra::yFromCell(r, seq_len(terra::ncell(r))))
  r
}
sq <- function(h) cbind(1e6 + c(-h, h, h, -h, -h), 5e5 + c(-h, -h, h, h, -h))
area_of <- function(xy) as.numeric(sf::st_area(close_ring(xy)))
# Canopy control 1, flat: ground 700 m, a uniform 25 m canopy. Cast from the ground-sized
# rectangle onto the canopy, the true footprint must be the canopy-sized rectangle, and the
# ground-sized one wider by exactly c / (agl - c).
flat_canopy <- function() {
  e <- 700; cc <- 25
  top <- synth(function(x, y) rep(e + cc, length(x)))
  h_g <- A0 * (H0 - e); h_c <- A0 * (H0 - e - cc)
  rc <- raycast(densify(sq(h_g)), c(1e6, 5e5), H0, e, top)
  stopifnot(!any(rc$bad))
  a_t <- area_of(rc$xy)
  c(t_vs_canopy_rect = a_t / (2 * h_c)^2 - 1,
    ground_wider = sqrt((2 * h_g)^2 / a_t) - 1 - cc / (H0 - e - cc))
}
# Canopy control 2, an edge: 40 m canopy to the north of the centroid, open ground to the
# south, on flat 0 m ground. Analytic true area 2a^2((H - c)^2 + H^2); the rectangle drawn at
# the mean c/2 is a^2 c^2 smaller (fly#65's step control at canopy scale). Judged by
# convergence, as that one was.
edge_canopy <- function(per_edge) {
  cc <- 40
  r <- synth(function(x, y) ifelse(y > 5e5, cc, 0), res = 5)
  e_w <- cc / 2; h <- A0 * (H0 - e_w)
  rc <- raycast(densify(sq(h), per_edge), c(1e6, 5e5), H0, e_w, r)
  stopifnot(!any(rc$bad))
  a_t <- area_of(rc$xy)
  c(true_vs_analytic = a_t / (2 * A0^2 * ((H0 - cc)^2 + H0^2)) - 1,
    gap_vs_analytic = (a_t - (2 * h)^2) / (A0^2 * cc^2) - 1)
}
fc <- flat_canopy(); e32 <- edge_canopy(32); e128 <- edge_canopy(128)
pub("  control canopy flat: T / canopy rectangle - 1 = %.2e (under 1e-5); ground-sized width excess - c/(agl - c) = %.2e (under 1e-6)",
    fc[1], fc[2])
pub("  control canopy edge: T / analytic - 1 = %.2e at 32 rays per edge, %.2e at 128; gap / a^2 c^2 - 1 = %.2e, %.2e",
    e32[1], e128[1], e32[2], e128[2])
if (abs(fc[1]) > 1e-5 || abs(fc[2]) > 1e-6 || abs(e32[1]) > 1e-3 || abs(e128[1]) > 1e-4 ||
    abs(e32[2]) > 0.05 || abs(e128[2]) > abs(e32[2]) / 3) {
  stop("the ray-cast does not reproduce its canopy controls; it is not trusted")
}

N_PER_STRATUM <- if (SMOKE) 1 else 60
SAMPLE <- file.path(CACHE, paste0("sample_", VKEY, ".rds"))
if (!file.exists(SAMPLE)) {
  pool <- census[!is.na(census$p_census), ]
  pool$stratum <- paste(pool$p_band, pool$scale_band, sep = "/")
  N_h <- table(pool$stratum)
  set.seed(80)
  idx <- unlist(lapply(split(seq_len(nrow(pool)), pool$stratum), function(i) {
    i[sample.int(length(i), min(N_PER_STRATUM, length(i)))]
  }), use.names = FALSE)
  smp <- pool[idx, ]
  n_h <- table(smp$stratum)
  smp$weight <- as.numeric(N_h[smp$stratum] / n_h[smp$stratum])
  # One frame in ten also gets the ring-invariance control.
  smp$inv <- seq_len(nrow(smp)) %% 10 == 0
  save_atomic(smp, SAMPLE)
}
smp <- readRDS(SAMPLE)
pub("  sample: %d frames in %d strata, weights %.0f to %.0f, summing to %.0f of %d census frames with a canopy value",
    nrow(smp), length(unique(smp$stratum)), min(smp$weight), max(smp$weight), sum(smp$weight),
    sum(!is.na(census$p_census)))

empty_c <- function() {
  list(fp_dtm_terrain = NA_character_, fp_dtm_height = NA_character_, fp_dsm_terrain = NA_character_,
       fp_dsm_height = NA_character_, agl_dtm = NA_real_, agl_dsm = NA_real_, cov_dtm = NA_real_,
       cov_dsm = NA_real_, elev_sd_dtm = NA_real_, area_w_dtm = NA_real_, area_w_dsm = NA_real_,
       c30 = NA_real_, n30 = NA_integer_, radar_share = NA_real_, lidar_share = NA_real_,
       meta_c = NA_real_, rays_bad_dtm = NA_integer_, rays_bad_dsm = NA_integer_,
       area_t_dtm = NA_real_, area_t_dsm = NA_real_, area_t_dsm_inv = NA_real_)
}

measure_canopy <- function(row, dtm_src, dsm_src, src_src) {
  out <- empty_c()
  dtm <- terra::rast(dtm_src); dsm <- terra::rast(dsm_src); src <- terra::rast(src_src)
  pt <- sf::st_as_sf(row[, c("airp_id", "photo_year", "scale", "film_roll", "frame_number",
                             "media", "focal_length", "flying_height", "x", "y")],
                     coords = c("x", "y"), crs = 3005, remove = FALSE)
  quiet <- function(e) withCallingHandlers(e, warning = function(w) invokeRestart("muffleWarning"))
  # `fly_footprint()` itself for every sized number, never a reimplementation of it.
  ft <- quiet(fly_footprint(pt, dem = dtm))
  fs <- quiet(fly_footprint(pt, dem = dsm))
  out$fp_dtm_terrain <- ft$footprint_terrain; out$fp_dtm_height <- ft$height_source
  out$fp_dsm_terrain <- fs$footprint_terrain; out$fp_dsm_height <- fs$height_source
  out$agl_dtm <- ft$height_agl; out$agl_dsm <- fs$height_agl
  out$cov_dtm <- ft$dem_coverage; out$cov_dsm <- fs$dem_coverage
  out$elev_sd_dtm <- ft$dem_elev_sd
  gt <- sf::st_geometry(ft); gs <- sf::st_geometry(fs)
  if (!sf::st_is_empty(gt)) out$area_w_dtm <- as.numeric(sf::st_area(gt))
  if (!sf::st_is_empty(gs)) out$area_w_dsm <- as.numeric(sf::st_area(gs))
  usable <- ft$footprint_terrain %in% "dem_agl" && fs$footprint_terrain %in% "dem_agl" &&
    ft$height_source %in% "reported" && fs$height_source %in% "reported" &&
    is.finite(out$area_w_dtm) && is.finite(out$area_w_dsm)
  if (!usable) return(out)

  H <- row$flying_height
  e_t <- H - ft$height_agl; e_s <- H - fs$height_agl
  vt <- sf::st_coordinates(gt)[, 1:2]; vs <- sf::st_coordinates(gs)[, 1:2]
  centre <- c(row$x, row$y)
  # One window every ray from either ring can reach: both rings are scalings of one another
  # about the centroid, so W_dtm scaled out to the lowest plausible surface covers both.
  reach <- (H + 50) / (H - e_t)
  big <- sweep(sweep(vt, 2, centre) * reach, 2, centre, "+")
  bd <- sf::st_transform(sf::st_sfc(close_ring(big[-nrow(big), ]), crs = 3005), terra::crs(dtm))
  e <- terra::align(terra::ext(terra::vect(bd)), dtm, snap = "out")
  if (is.null(terra::intersect(e, terra::ext(dtm)))) return(out)
  wt <- terra::toMemory(terra::crop(dtm, e)); ws <- terra::toMemory(terra::crop(dsm, e))
  wsrc <- terra::toMemory(terra::crop(src, e))

  pw <- terra::vect(sf::st_transform(gt, terra::crs(dtm)))
  ex <- terra::extract(c(ws - wt, wsrc), pw, ID = FALSE)
  k <- is.finite(ex[[1]])
  out$n30 <- sum(k)
  out$c30 <- if (any(k)) mean(ex[[1]][k]) else NA_real_
  out$radar_share <- mean(ex[[2]] %in% 1)
  out$lidar_share <- mean(ex[[2]] %in% 10)
  mt <- tryCatch(meta_on(wt), error = function(e) NULL)
  if (!is.null(mt)) {
    mv <- terra::extract(mt, pw, ID = FALSE)[[1]]
    out$meta_c <- if (any(is.finite(mv))) mean(mv, na.rm = TRUE) else NA_real_
  }

  rt <- raycast(densify(vt), centre, H, e_t, wt)
  rs <- raycast(densify(vs), centre, H, e_s, ws)
  out$rays_bad_dtm <- sum(rt$bad); out$rays_bad_dsm <- sum(rs$bad)
  if (!any(rt$bad)) out$area_t_dtm <- as.numeric(sf::st_area(sf::st_make_valid(
    sf::st_sfc(close_ring(rt$xy), crs = 3005))))
  if (!any(rs$bad)) out$area_t_dsm <- as.numeric(sf::st_area(sf::st_make_valid(
    sf::st_sfc(close_ring(rs$xy), crs = 3005))))
  if (isTRUE(row$inv)) {
    # The same camera rays, started from the other ring, must land on the same ground.
    ri <- raycast(densify(vt), centre, H, e_t, ws)
    if (!any(ri$bad)) out$area_t_dsm_inv <- as.numeric(sf::st_area(sf::st_make_valid(
      sf::st_sfc(close_ring(ri$xy), crs = 3005))))
  }
  out
}

# fly#65's sampled frames, for the first-order canopy table in the note (review G4): the mean
# of DSM - DTM under each frame's own rectangle. The CSV carries its area, not its vertices,
# and a single frame's bearing is not re-derived here, so the rectangle is the axis-aligned
# square of that area about the centroid — close enough for a mean of a 30 m surface, and
# labelled so.
coastal_c <- function(row, dtm_src, dsm_src) {
  dtm <- terra::rast(dtm_src); dsm <- terra::rast(dsm_src)
  h <- sqrt(row$area_w) / 2
  sqp <- sf::st_sfc(close_ring(cbind(row$x + c(-h, h, h, -h), row$y + c(-h, -h, h, h))), crs = 3005)
  pv <- terra::vect(sf::st_transform(sqp, terra::crs(dtm)))
  e <- terra::align(terra::ext(pv), dtm, snap = "out")
  if (is.null(terra::intersect(e, terra::ext(dtm)))) return(NA_real_)
  v <- terra::extract(terra::crop(dsm, e) - terra::crop(dtm, e), pv, ID = FALSE)[[1]]
  if (any(is.finite(v))) mean(v[is.finite(v)]) else NA_real_
}

RUNS_DIR <- file.path(CACHE, paste0("frames_", VKEY))
dir.create(RUNS_DIR, showWarnings = FALSE)
cf <- utils::read.csv("inst/extdata/dem_coastal_frames.csv", stringsAsFactors = FALSE)
cf <- cf[cf$admitted, c("airp_id", "area_w")]
cxy <- census[match(cf$airp_id, census$airp_id), c("x", "y")]
cf <- cbind(cf, cxy)
if (SMOKE) cf <- cf[seq_len(min(5, nrow(cf))), ]
stopifnot(!anyNA(cf$x))

jobs <- c(lapply(seq_len(nrow(smp)), function(i) list(kind = "s", id = smp$airp_id[i], row = smp[i, ])),
          lapply(seq_len(nrow(cf)), function(i) list(kind = "c", id = cf$airp_id[i], row = cf[i, ])))
done <- sub("\\.rds$", "", list.files(RUNS_DIR, "\\.rds$"))
jobs <- jobs[!paste0(vapply(jobs, `[[`, "", "kind"), vapply(jobs, function(j) as.character(j$id), "")) %in% done]
pub("  frames to measure: %d (sample %d, fly#65 frames %d)", length(jobs), nrow(smp), nrow(cf))
if (length(jobs)) {
  cl <- parallel::makeCluster(WORKERS)
  objs <- list(cap_memory = cap_memory, raycast = raycast, densify = densify, close_ring = close_ring,
               empty_c = empty_c, measure_canopy = measure_canopy, coastal_c = coastal_c,
               meta_on = meta_on, meta_paths = normalizePath(meta_paths), save_atomic = save_atomic,
               RUNS_DIR = RUNS_DIR)
  res <- tryCatch({
    parallel::clusterCall(cl, function(repo, objs) {
      setwd(repo)
      suppressMessages(pkgload::load_all(quiet = TRUE))
      sf::sf_use_s2(FALSE)
      for (nm in names(objs)) assign(nm, objs[[nm]], envir = globalenv())
      cap_memory()
      NULL
    }, REPO, objs)
    parallel::parLapplyLB(cl, jobs, function(j, dtm_src, dsm_src, src_src) {
      out <- tryCatch(
        if (j$kind == "s") as.data.frame(measure_canopy(j$row, dtm_src, dsm_src, src_src))
        else data.frame(airp_id = j$id, c_coastal = coastal_c(j$row, dtm_src, dsm_src)),
        error = function(e) structure(conditionMessage(e), class = "frame_error"))
      if (inherits(out, "frame_error")) return(paste(j$kind, j$id, out))
      if (j$kind == "s") out <- cbind(airp_id = j$id, out)
      save_atomic(out, file.path(RUNS_DIR, paste0(j$kind, j$id, ".rds")))
      NA_character_
    }, MRDEM_DTM, MRDEM_DSM, MRDEM_SRC)
  }, finally = parallel::stopCluster(cl))
  errs <- stats::na.omit(unlist(res))
  # Refuse to report over a hole: a frame that errored is not a frame that found nothing.
  if (length(errs)) stop(length(errs), " frames errored, e.g. ", errs[1])
}
rd <- function(prefix) do.call(rbind, lapply(list.files(RUNS_DIR, paste0("^", prefix, ".*\\.rds$"),
                                                        full.names = TRUE), readRDS))
ms <- rd("s")
ms <- merge(smp, ms, by = "airp_id")
cc <- rd("c")
stopifnot(nrow(ms) == nrow(smp), setequal(ms$airp_id, smp$airp_id),
          nrow(cc) == nrow(cf), setequal(cc$airp_id, cf$airp_id))
if (STOP_AFTER <= 3) quit(save = "no")

# ---------------------------------------------------------------------------
# Stage 4 — epoch: was the canopy the DSM carries there when the photo was taken?
# ---------------------------------------------------------------------------

wq <- function(x, w, p) {
  k <- is.finite(x) & is.finite(w)
  x <- x[k]; w <- w[k]
  o <- order(x); cw <- cumsum(w[o]) / sum(w)
  x[o][which(cw >= p)[1]]
}
lin <- function(a, b) sqrt(a / b) - 1
ms$admitted <- ms$fp_dtm_terrain %in% "dem_agl" & ms$fp_dsm_terrain %in% "dem_agl" &
  ms$fp_dtm_height %in% "reported" & ms$fp_dsm_height %in% "reported" &
  is.finite(ms$cov_dtm) & ms$cov_dtm >= fly_dem_coverage_min() &
  is.finite(ms$cov_dsm) & ms$cov_dsm >= fly_dem_coverage_min()
ms$class_changed <- (ms$fp_dtm_terrain %in% "dem_agl") != (ms$fp_dsm_terrain %in% "dem_agl") |
  !(ms$fp_dtm_height %in% ms$fp_dsm_height)
ms$d_c <- lin(ms$area_w_dtm, ms$area_w_dsm)
ms$rho_dtm <- lin(ms$area_w_dtm, ms$area_t_dtm)
ms$rho_dsm <- lin(ms$area_w_dsm, ms$area_t_dsm)
ms$today <- lin(ms$area_w_dtm, ms$area_t_dsm)   # the package today against the canopy surface
ms$raycast_ok <- ms$admitted & ms$rays_bad_dtm %in% 0 & ms$rays_bad_dsm %in% 0 &
  is.finite(ms$area_t_dtm) & is.finite(ms$area_t_dsm)

EPOCH <- file.path(CACHE, paste0("epoch_", VKEY, ".rds"))
EPOCH_DIR <- file.path(CACHE, paste0("epoch_frames_", VKEY))
dir.create(EPOCH_DIR, showWarnings = FALSE)
N_EPOCH <- if (SMOKE) 2 else 400
if (!file.exists(EPOCH)) {
  ep <- ms[ms$admitted & is.finite(ms$d_c) & ms$d_c >= .005, ]
  # Every eligible frame, carrying its design weight. A cap is drawn uniformly, never in
  # proportion to weight: a weighted draw without replacement, then weighted again, counts the
  # heavy strata twice (Amendment 3, from code-check round 1).
  if (nrow(ep) > N_EPOCH) {
    set.seed(80)
    ep <- ep[sort(sample.int(nrow(ep), N_EPOCH)), ]
  }
  vri_one <- function(row) {
    h <- sqrt(row$area_w_dtm) / 2
    fpg <- sf::st_sfc(close_ring(cbind(row$x + c(-h, h, h, -h), row$y + c(-h, -h, h, h))), crs = 3005)
    q1 <- function() bcdata::bcdc_query_geodata("WHSE_FOREST_VEGETATION.VEG_COMP_LYR_R1_POLY") |>
      bcdata::filter(bcdata::INTERSECTS(fpg)) |>
      bcdata::select(PROJ_AGE_1, PROJ_HEIGHT_1, PROJECTED_DATE, BCLCS_LEVEL_2) |>
      bcdata::collect()
    v <- tryCatch(q1(), error = function(e) tryCatch(q1(), error = function(e2) {
      structure(conditionMessage(e2), class = "vri_error")
    }))
    if (inherits(v, "vri_error")) stop("VRI query failed for ", row$airp_id, ": ", v)
    A <- as.numeric(sf::st_area(fpg))
    base <- data.frame(airp_id = row$airp_id, vri_share = 0, treed_share = 0,
                       unknown_share = NA_real_, c_now = NA_real_, c_then = NA_real_,
                       young_share = NA_real_, replaced_share = NA_real_)
    if (!nrow(v)) return(base)
    v <- suppressWarnings(sf::st_intersection(sf::st_make_valid(v), fpg))
    a <- as.numeric(sf::st_area(v))
    base$vri_share <- sum(a) / A
    tr <- v$BCLCS_LEVEL_2 %in% "T" & is.finite(v$PROJ_AGE_1) & is.finite(v$PROJ_HEIGHT_1)
    base$treed_share <- sum(a[tr]) / A
    # Canopy epoch: the lidar project where the frame is mostly lidar-sourced (median 2018 per
    # the specification), GLO-30's collection otherwise (2011-2015, midpoint 2013).
    cy <- if (isTRUE(row$lidar_share > .5)) 2018 else 2013
    py <- row$photo_year
    # VRI projects every polygon to one date (2025-12-31 when probed), so its height is the
    # height THEN, not at either epoch. Heights are carried back linearly in age (Amendment 3):
    # height at year t is h (t - O) / (yr - O). Linear in age understates how short a young
    # stand is, so it understates harm.
    yr <- as.numeric(substr(as.character(v$PROJECTED_DATE), 1, 4))
    O <- yr - v$PROJ_AGE_1
    at <- function(t) ifelse(t >= O, v$PROJ_HEIGHT_1 * pmax(0, t - O) / pmax(yr - O, 1), NA_real_)
    h_now <- at(cy)
    # A stand that originated after the photo replaced one whose height is unknown: neutral,
    # c_then = c_now. One that originated after the canopy epoch was not what the DSM saw
    # either; both epochs saw stands that are gone, so that area is unknown and left out.
    unknown <- tr & O > cy
    c_then <- ifelse(O <= py, at(py), h_now)
    known <- !unknown
    base$unknown_share <- sum(a[unknown]) / sum(a)
    if (!any(known)) return(base)
    # Non-treed ground carries no canopy in either epoch: it stays in the mean as zero, so a
    # frame with no treed polygon has both errors 0 rather than dropping out (round 1).
    w <- a[known]
    base$c_now <- sum(w * ifelse(tr[known], h_now[known], 0)) / sum(w)
    base$c_then <- sum(w * ifelse(tr[known], c_then[known], 0)) / sum(w)
    tk <- tr & known
    if (any(tk)) {
      base$young_share <- sum(a[tk & O <= py & (py - O) < (cy - O) / 2]) / sum(a[tk])
      base$replaced_share <- sum(a[tk & O > py]) / sum(a[tk])
    }
    base
  }
  rows <- lapply(seq_len(nrow(ep)), function(i) {
    f <- file.path(EPOCH_DIR, paste0(ep$airp_id[i], ".rds"))
    if (!file.exists(f)) save_atomic(vri_one(ep[i, ]), f)
    readRDS(f)
  })
  save_atomic(do.call(rbind, rows), EPOCH)
}
ev <- readRDS(EPOCH)
ev <- merge(ms[, c("airp_id", "weight", "photo_year", "decade", "d_c", "radar_share")], ev, by = "airp_id")
ev$dtm_err <- ev$c_then
ev$dsm_err <- abs(ev$c_then - ev$c_now)
ev$dsm_worse <- is.finite(ev$c_then) & ev$dsm_err > ev$dtm_err
if (STOP_AFTER <= 4) quit(save = "no")

# ---------------------------------------------------------------------------
# Stage 5 — the verdicts, as Amendment 1 states them
# ---------------------------------------------------------------------------

pub("  sample frames %d; admitted %d; ray-cast clean %d; classification differs between surfaces %d (%s)",
    nrow(ms), sum(ms$admitted), sum(ms$raycast_ok), sum(ms$class_changed),
    paste(names(table(paste(ms$fp_dtm_height, "->", ms$fp_dsm_height)[ms$class_changed])),
          table(paste(ms$fp_dtm_height, "->", ms$fp_dsm_height)[ms$class_changed]),
          sep = ": ", collapse = ", "))
a <- ms[ms$admitted & is.finite(ms$d_c), ]
pub("  admitted weight %.0f of %.0f (%.3f)", sum(a$weight), sum(ms$weight), sum(a$weight) / sum(ms$weight))

# Control 3: the census, calibrated against the 30 m read on the same frames.
a$p30 <- a$c30 / a$agl_dtm
cal <- a$p_census / a$p30
pub("  census calibration: weighted median p_census / p30 %.3f on %d frames with p30 >= 0.25%%; census p against 30 m p, weighted 95th %.4f vs %.4f",
    wq(cal, a$weight * (a$p30 >= .0025), .5), sum(a$p30 >= .0025, na.rm = TRUE),
    wq(a$p_census, a$weight, .95), wq(a$p30, a$weight, .95))
# The identity: side_dtm / side_dsm - 1 = c / (agl_dsm) to first order, from the two passes.
# A diagnostic of the instrument, not a population figure: unweighted over the sample.
pub("  identity (sample, unweighted): median |d_c - c30 / agl_dsm| %.2e", stats::median(abs(a$d_c - a$c30 / a$agl_dsm), na.rm = TRUE))

# 1. Materiality.
pub("  d_c (side_dtm / side_dsm - 1), weighted: median %.4f, 90th %.4f, 95th %.4f, 99th %.4f; share over 0.5%% %.3f, over 1%% %.3f",
    wq(a$d_c, a$weight, .5), wq(a$d_c, a$weight, .9), wq(a$d_c, a$weight, .95), wq(a$d_c, a$weight, .99),
    sum(a$weight[a$d_c > .005]) / sum(a$weight), sum(a$weight[a$d_c > .01]) / sum(a$weight))
material <- wq(a$d_c, a$weight, .95) >= .01
pub("  MATERIAL (weighted 95th of d_c at or over 1%%): %s", material)
for (b in c("fine", "mid", "coarse")) {
  x <- a[a$scale_band == b, ]
  pub("  d_c by scale %-6s n=%3d weight %8.0f: median %.4f 95th %.4f; share over 1%% %.3f",
      b, nrow(x), sum(x$weight), wq(x$d_c, x$weight, .5), wq(x$d_c, x$weight, .95),
      sum(x$weight[x$d_c > .01]) / sum(x$weight))
}
for (dd in sort(unique(a$decade))) {
  x <- a[a$decade == dd, ]
  pub("  d_c by decade %d n=%3d weight %8.0f: median %.4f 95th %.4f; share over 1%% %.3f",
      dd, nrow(x), sum(x$weight), wq(x$d_c, x$weight, .5), wq(x$d_c, x$weight, .95),
      sum(x$weight[x$d_c > .01]) / sum(x$weight))
}
rad <- a$radar_share > .5
pub("  d_c by source: radar-majority weight share %.3f, 95th %.4f; lidar-majority 95th %.4f",
    sum(a$weight[rad]) / sum(a$weight), wq(a$d_c[rad], a$weight[rad], .95),
    wq(a$d_c[!rad], a$weight[!rad], .95))
pub("  Meta under the same frames: weighted median meta_c / c30 %.3f (reported, not decisive)",
    wq(a$meta_c / a$c30, a$weight * (a$c30 > 2), .5))

# 2. Rectangle model under a DSM.
r <- a[a$raycast_ok, ]
inv <- r[is.finite(r$area_t_dsm_inv), ]
pub("  control invariance: %d frames, max |T from W_dtm ring / T from W_dsm ring - 1| %.2e (under 1e-4)",
    nrow(inv), if (nrow(inv)) max(abs(inv$area_t_dsm_inv / inv$area_t_dsm - 1)) else NA)
if (nrow(inv) && max(abs(inv$area_t_dsm_inv / inv$area_t_dsm - 1)) > 1e-4) {
  stop("control invariance: the same rays land on different ground")
}
p_dtm <- wq(abs(r$rho_dtm), r$weight, .95); p_dsm <- wq(abs(r$rho_dsm), r$weight, .95)
pub("  rectangle model, weighted 95th |rho|: DTM %.4f, DSM %.4f; medians %.4f, %.4f (n=%d)",
    p_dtm, p_dsm, wq(abs(r$rho_dtm), r$weight, .5), wq(abs(r$rho_dsm), r$weight, .5), nrow(r))
not_degraded <- p_dsm <= p_dtm + .01
pub("  RECTANGLE NOT DEGRADED (DSM 95th within DTM 95th + 1 point): %s", not_degraded)
pub("  the package today against the canopy surface, weighted: median %+.4f, 95th |.| %.4f; signed share too wide %.3f",
    wq(r$today, r$weight, .5), wq(abs(r$today), r$weight, .95), sum(r$weight[r$today > 0]) / sum(r$weight))
pub("  first order (sample, unweighted): median |(today - rho_dtm) - d_c| %.2e (realised canopy shift against predicted)",
    stats::median(abs((1 + r$today) / (1 + r$rho_dtm) - 1 - r$d_c), na.rm = TRUE))

# 3. The canopy instrument on radar cells.
slope <- fit(lp$imaged_over_dtm, lp$mrdem_canopy)
valid <- slope >= 0.67 && slope <= 1.5
pub("  INSTRUMENT VALID ON RADAR CELLS (lidar-probe slope %.3f within [0.67, 1.5]): %s", slope, valid)

# 4. Epoch.
pub("  epoch: %d frames with d_c >= 0.5%% (weight %.0f); VRI covers weighted median %.3f of the footprint, treed %.3f; %d with no VRI at all, %d whose VRI area is all unknown",
    nrow(ev), sum(ev$weight), wq(ev$vri_share, ev$weight, .5), wq(ev$treed_share, ev$weight, .5),
    sum(ev$vri_share == 0), sum(ev$vri_share > 0 & !is.finite(ev$c_then)))
epoch_ok <- character(0)
for (dd in sort(unique(ev$decade))) {
  x <- ev[ev$decade == dd & is.finite(ev$c_then), ]
  if (!nrow(x)) next
  sh <- sum(x$weight[x$dsm_worse]) / sum(x$weight)
  pub("  epoch %d n=%3d: DSM worse than DTM on weighted share %.3f; weighted median c_then %.1f m c_now %.1f m; young-at-photo share %.3f, replaced-since %.3f",
      dd, nrow(x), sh, wq(x$c_then, x$weight, .5), wq(x$c_now, x$weight, .5),
      wq(x$young_share, x$weight, .5), wq(x$replaced_share, x$weight, .5))
  if (sh < .10) epoch_ok <- c(epoch_ok, as.character(dd))
}
pub("  EPOCH HOLDS for decades: %s", if (length(epoch_ok)) paste(epoch_ok, collapse = ", ") else "none")

outcome <- if (!material) "NOTHING" else if (!valid) "UNRESOLVED" else
  if (not_degraded && length(epoch_ok)) "RECOMMEND A DSM" else "DOCUMENT"
pub("  OUTCOME: %s", outcome)

# fly#65's canopy table, with each frame's measured canopy in place of a uniform one. First
# order (the fly#65 formula), not a re-run ray-cast; the measured canopy is under an
# axis-aligned square of each frame's area.
cm65 <- utils::read.csv("inst/extdata/dem_coastal_frames.csv", stringsAsFactors = FALSE)
cm65 <- merge(cm65, cc, by = "airp_id")
cm65$err_w <- lin(cm65$area_w, cm65$area_t); cm65$err_l <- lin(cm65$area_l, cm65$area_t)
cm65$elev_w <- cm65$flying_height - cm65$height_agl
cm65$elev_l <- cm65$elev_w + (cm65$mean_land - cm65$mean_all)
cm65$d <- (cm65$flying_height - cm65$elev_w) / (cm65$flying_height - cm65$elev_l) - 1
k65 <- cm65$height_agl / (cm65$height_agl - cm65$c_coastal)
cm65$w_c <- (1 + cm65$err_w) * k65 - 1; cm65$l_c <- (1 + cm65$err_l) * k65 - 1
co65 <- cm65[cm65$coastal & is.finite(cm65$d) & cm65$d > 0 & cm65$n_sea > 0, ]
in65 <- cm65[cm65$set == "inland" & !cm65$coastal, ]
pub("  fly#65 frames, measured canopy: coastal n=%d median %.2f m, inland n=%d median %.2f m",
    nrow(co65), stats::median(co65$c_coastal, na.rm = TRUE), nrow(in65),
    stats::median(in65$c_coastal, na.rm = TRUE))
pub("  fly#65 frames under measured canopy (first-order): median(|W| - |L|) %+.5f; W area 95th coastal %.4f inland %.4f (bare earth %.4f / %.4f)",
    stats::median(abs(co65$w_c) - abs(co65$l_c), na.rm = TRUE), q(abs(co65$w_c), .95),
    q(abs(in65$w_c), .95), q(abs(co65$err_w), .95), q(abs(in65$err_w), .95))

keep <- c("airp_id", "photo_year", "decade", "film_roll", "frame_number", "scale_n", "scale_band",
          "focal_length", "flying_height", "c_census", "n_census", "p_census", "p_band", "stratum",
          "weight", "inv", "fp_dtm_terrain", "fp_dtm_height", "fp_dsm_terrain", "fp_dsm_height",
          "agl_dtm", "agl_dsm", "cov_dtm", "cov_dsm", "elev_sd_dtm", "area_w_dtm", "area_w_dsm",
          "c30", "n30", "radar_share", "lidar_share", "meta_c", "rays_bad_dtm", "rays_bad_dsm",
          "area_t_dtm", "area_t_dsm", "area_t_dsm_inv", "admitted")
sig <- function(d) { num <- vapply(d, is.double, logical(1)); d[num] <- lapply(d[num], signif, 10); d }
out_s <- sig(ms[order(ms$stratum, ms$airp_id), keep])
out_e <- sig(ev[order(ev$airp_id), c("airp_id", "vri_share", "treed_share", "unknown_share", "c_now",
                                     "c_then", "young_share", "replaced_share")])
out_l <- sig(lp)
out_st <- sig(sites_out)
out_c <- sig(cc[order(cc$airp_id), ])
out_v <- rbind(VERSIONS[, c("asset", "etag", "modified")],
               data.frame(asset = "source_share", etag = paste(names(SRC_SHARE), signif(SRC_SHARE, 6), sep = "=", collapse = ";"),
                          modified = ""))
if (SMOKE) {
  message("smoke run: nothing written")
  quit(save = "no")
}
write_if_changed(out_s, "inst/extdata/dem_canopy_sample.csv")
write_if_changed(cen_bin, "inst/extdata/dem_canopy_census.csv")
write_if_changed(out_e, "inst/extdata/dem_canopy_epoch.csv")
write_if_changed(out_l, "inst/extdata/dem_canopy_lidar.csv")
write_if_changed(out_st, "inst/extdata/dem_canopy_sites.csv")
write_if_changed(out_c, "inst/extdata/dem_canopy_coastal.csv")
write_if_changed(out_v, "inst/extdata/dem_canopy_versions.csv")
