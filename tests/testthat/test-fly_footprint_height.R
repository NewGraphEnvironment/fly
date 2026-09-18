# The plausibility checks on `flying_height`, and the repair of the one error they can
# identify (fly#54).
#
# The catalogue's `FLYING_HEIGHT` is 3.28084^2 too large on 1,589 film frames, which the DEM
# route turned into 110 km footprints. Every fixture here sits over level ground at a known
# elevation, so each expected height is arithmetic rather than a reading — and the two
# constants are checked further down against the sweep they were measured from, which ships
# in `inst/extdata/`, rather than against themselves.

collect_warnings <- function(expr) {
  w <- character()
  value <- withCallingHandlers(
    expr,
    warning = function(x) {
      w <<- c(w, conditionMessage(x))
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, warnings = w)
}

width_m <- function(fp) {
  vapply(sf::st_geometry(sf::st_transform(fp, 3005)), function(g) {
    if (sf::st_is_empty(g)) return(NA_real_)
    diff(range(sf::st_coordinates(g)[, 1]))
  }, numeric(1))
}


test_that("a slipped flying_height is repaired, flagged, and sized like its clean twin", {
  skip_if_no_terra()
  hf <- height_fixture()
  fp <- suppressWarnings(fly_footprint(hf, dem = flat_dem()))

  expect_identical(fp$height_source, height_fixture_source())
  expect_identical(
    fp$footprint_terrain,
    c("dem_agl", "dem_agl", "dem_agl", "nominal_scale", "dem_agl", NA)
  )

  # Rows 1 and 2 are one frame, clean and slipped. The fixture rounds the slipped height to
  # a whole metre, as the catalogue does, so the twins agree to that rounding and no better.
  expect_equal(fp$height_agl[1], 2628 - 700)
  expect_equal(fp$height_agl[2], fp$height_agl[1], tolerance = 1e-3)
  expect_equal(width_m(fp)[2], width_m(fp)[1], tolerance = 1e-3)
  # ... and nowhere near what `main` returned for it: 9 in x 0.0254 x (28288 - 700) / 0.153.
  expect_lt(width_m(fp)[2], 3000)

  # The height actually used is what is reported; the caller's column is not touched, so
  # raw against corrected stays comparable.
  expect_equal(fp$height_agl[3], 1340 - 700, tolerance = 1e-3)
  expect_identical(fp$flying_height, hf$flying_height)

  # An implausible film frame keeps its nominal-scale footprint — it is not dropped.
  flat <- fly_footprint(hf)
  expect_equal(width_m(fp)[4], width_m(flat)[4])
  expect_true(is.na(fp$height_agl[4]))
  # A camera-table frame has no nominal footprint to fall back to.
  expect_true(sf::st_is_empty(sf::st_geometry(fp)[6]))
})


test_that("the fixture reaches each check by the route it claims to", {
  hf <- height_fixture()
  # Row 3's slipped height is a legal altitude, so the ceiling cannot be what catches it.
  expect_lt(hf$flying_height[3], fly_flying_height_max())
  # Row 5 is the catalogue's highest legitimate height, and is under the ceiling too.
  expect_lt(hf$flying_height[5], fly_flying_height_max())
  # Row 6 can only be caught by the ceiling: it is digital, sized from the camera table.
  expect_gt(hf$flying_height[6], fly_flying_height_max())
  expect_false(hf$media[6] %in% fly_film_media())
})


test_that("corrected and implausible heights are each reported once, and not as missing", {
  skip_if_no_terra()
  got <- collect_warnings(fly_footprint(height_fixture(), dem = flat_dem()))
  w <- got$warnings

  corrected <- grep("corrected", w, value = TRUE)
  expect_length(corrected, 1)
  expect_match(corrected, "^2 of ")
  expect_match(corrected, "height_source", fixed = TRUE)
  expect_match(corrected, "10.76", fixed = TRUE)

  implausible <- grep("implausible", w, value = TRUE)
  expect_length(implausible, 1)
  expect_match(implausible, "^2 of ")
  expect_match(implausible, "height_source", fixed = TRUE)

  # Neither is missing metadata, and the digital frame was given every column the
  # no-way-to-size-it warning asks for. Both of those would point at the wrong thing.
  expect_false(any(grepl("missing, zero", w, fixed = TRUE)))
  expect_false(any(grepl("no way to size it", w, fixed = TRUE)))
})


test_that("no DEM window is ever built from a height that fails the checks", {
  skip_if_no_terra()
  # `main` sampled its second pass over the rectangle the slipped height implies — 41 km
  # here, 110 km on the 2003 rolls, fetched over the network per frame. Classifying after
  # both passes and discarding the result would return the right answer and still pay for
  # it, so assert on the grids themselves.
  hf <- height_fixture()
  dem <- flat_dem()

  sizes <- c()
  real_grid <- fly_dem_grid
  testthat::local_mocked_bindings(
    fly_dem_grid = function(dem, geom) {
      g <- real_grid(dem, geom)
      sizes <<- c(sizes, prod(dim(g)[1:2]))
      g
    }
  )
  suppressWarnings(fly_footprint(hf, dem = dem))

  # The widest legitimate window is row 5's: 20.6 km, corrected up by ~1%, on 100 m cells.
  widest <- (9 * 0.0254 * 90000 * 1.05 / 100 + 2)^2
  expect_gt(length(sizes), 0)
  expect_lt(max(sizes), widest)
  # Premise: the slipped row's own window would have stood out against that.
  expect_gt((9 * 0.0254 * (28288 - 700) / 0.153 / 100)^2, 3 * widest)
})


test_that("a repaired frame matches its clean twin on terrain the flat fixture cannot reach", {
  skip_if_no_terra()
  twins <- height_fixture()[1:2, ]
  bb <- sf::st_bbox(sf::st_transform(twins, 3005))
  truncated <- terra::crop(
    flat_dem(),
    terra::ext(bb[["xmin"]] - 40000, bb[["xmax"]] + 800, bb[["ymin"]] - 40000, bb[["ymax"]] + 40000)
  )
  dems <- list(
    "bundled 30 m"      = terra::rast(testdata_path("dem.tif")),
    "900 m cells"       = flat_dem(cell = 900),
    "geographic CRS"    = flat_dem(cell = 300, crs = "EPSG:4326"),
    "truncating extent" = truncated
  )
  for (nm in names(dems)) {
    fp <- suppressWarnings(fly_footprint(twins, dem = dems[[nm]]))
    expect_identical(fp$height_source, c("reported", "corrected_unit_slip"), info = nm)
    expect_equal(fp$height_agl[2], fp$height_agl[1], tolerance = 1e-3, info = nm)
    expect_equal(width_m(fp)[2], width_m(fp)[1], tolerance = 1e-3, info = nm)
    # Coverage has to describe the rectangle that is returned — the repaired one.
    expect_equal(fp$dem_coverage[2], fp$dem_coverage[1], tolerance = 1e-2, info = nm)
  }
  # Premise: the truncating case really does cut the footprint, or it tests nothing.
  cut <- suppressWarnings(fly_footprint(twins, dem = truncated))
  expect_lt(cut$dem_coverage[1], 0.95)
  expect_gt(cut$dem_coverage[1], 0)
})


test_that("a frame's height is judged on its own, whatever batch it arrives in", {
  skip_if_no_terra()
  hf <- height_fixture()
  dem <- flat_dem()
  batch <- suppressWarnings(fly_footprint(hf, dem = dem))
  expect_identical(batch$height_source, height_fixture_source())   # premise: not NULL
  for (i in seq_len(nrow(hf))) {
    alone <- suppressWarnings(fly_footprint(hf[i, ], dem = dem))
    expect_identical(alone$height_source, batch$height_source[i], info = i)
    expect_equal(alone$height_agl, batch$height_agl[i], info = i)
  }
})


test_that("height_source is carried for every class of input, with values that vary", {
  skip_if_no_terra()
  hf <- height_fixture()
  tbl <- sf::st_as_sf(dplyr::as_tibble(hf))
  grouped <- dplyr::group_by(tbl, .data$scale)
  stopifnot(!inherits(hf, "tbl_df"), inherits(tbl, "tbl_df"), inherits(grouped, "grouped_df"))

  dem <- flat_dem()
  out <- lapply(list(plain = hf, tbl = tbl, grouped = grouped),
                function(x) suppressWarnings(fly_footprint(x, dem = dem)))
  # The bundled centroids would give a constant column; this fixture gives three values.
  expect_setequal(out$plain$height_source, c("reported", "corrected_unit_slip", "implausible"))
  for (nm in names(out)) {
    expect_identical(out[[nm]]$height_source, out$plain$height_source, info = nm)
    expect_identical(out[[nm]]$height_agl, out$plain$height_agl, info = nm)
  }
})


test_that("height_source is NA wherever no DEM height was judged", {
  skip_if_no_terra()
  no_dem <- fly_footprint(height_fixture()[1:5, ])
  expect_type(no_dem$height_source, "character")
  expect_true(all(is.na(no_dem$height_source)))

  # A frame sized from its ground sample distance never consults `flying_height`.
  digital <- sf::st_read(testdata_path("photo_centroids_digital.gpkg"), quiet = TRUE)
  fp <- suppressWarnings(fly_footprint(digital, dem = testdata_path("dem.tif")))
  by_gsd <- fp$footprint_terrain %in% "gsd_scaled"
  expect_gt(sum(by_gsd), 0)
  expect_true(all(is.na(fp$height_source[by_gsd])))

  # Missing metadata is missing, not implausible; terrain above the aircraft is a height
  # that was there and was rejected.
  photos <- terrain_fixture()[1:2, ]
  photos$flying_height <- c(NA, 100)
  fp <- suppressWarnings(fly_footprint(photos, dem = testdata_path("dem.tif")))
  expect_identical(fp$height_source, c(NA, "implausible"))
  expect_identical(fp$footprint_terrain, c("nominal_scale", "nominal_scale"))
})


test_that("the bundled film frames are all left exactly as they were", {
  skip_if_no_terra()
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  fp <- fly_footprint(centroids, dem = testdata_path("dem.tif"))
  # `rep()`, not `all(... == "reported")`: on a column that does not exist that is
  # `all(logical(0))`, which is TRUE.
  expect_identical(fp$height_source, rep("reported", nrow(centroids)))
  r <- fp$height_agl /
    (as.numeric(sub("1:", "", centroids$scale)) * centroids$focal_length / 1000)
  band <- fly_height_ratio_band()
  expect_true(all(r > band[1] & r < band[2]))
})


test_that("the constants hold against the sweep they were measured from", {
  sweep_path <- system.file("extdata/flying_height_sweep.csv", package = "fly")
  pop_path <- system.file("extdata/flying_height_population.csv", package = "fly")
  skip_if(sweep_path == "" || pop_path == "", "the flying-height sweep is not installed")
  s <- utils::read.csv(sweep_path)
  pop <- utils::read.csv(pop_path)

  k <- fly_height_slip_factor()
  band <- fly_height_ratio_band()
  in_band <- function(r) r >= band[1] & r <= band[2]
  expect_equal(k, 3.28084^2)
  expect_equal(band[1] * band[2], 1)        # one factor, applied both ways

  nominal <- s$scale_n * s$focal_length / 1000
  s$ratio_asl <- s$flying_height / nominal
  s$r <- (s$flying_height - s$elev) / nominal
  s$r_fix <- (s$flying_height / k - s$elev) / nominal

  # The slipped population is identified by a ratio no terrain can produce, NOT by the
  # rule — or everything below could only agree with itself.
  slipped <- s$ratio_asl > 9
  ordinary <- s$set == "random"
  # Premise: the sweep holds both kinds of frame, in numbers.
  expect_identical(sum(slipped), 1589L)
  expect_identical(length(unique(s$film_roll[slipped])), 13L)
  expect_identical(sum(ordinary), 2500L)
  expect_identical(sum(pop$n[pop$media == "film" & pop$ratio_asl_from >= 9]), 1589L)

  # Every slipped frame is outside the band as reported and inside it once repaired, with
  # room on both sides.
  expect_false(any(in_band(s$r[slipped])))
  expect_true(all(in_band(s$r_fix[slipped])))
  expect_gt(min(s$r_fix[slipped]) / band[1], 1.2)
  expect_gt(band[2] / max(s$r_fix[slipped]), 1.2)
  expect_gt(min(s$r[slipped]) / band[2], 6)

  # The band costs ordinary frames under 1%.
  expect_gt(mean(in_band(s$r[ordinary])), 0.99)

  # The repair fires on nothing else: no sampled frame outside the band, slipped ones
  # aside, lands inside it when divided by the factor.
  other <- !slipped & !in_band(s$r)
  expect_gt(sum(other), 2000)               # premise: there are plenty to be wrong about
  expect_identical(sum(in_band(s$r_fix[other])), 0L)
  # ... because nothing sits between the two populations.
  expect_lt(max(s$r[!slipped]), 7)
  expect_gt(min(s$r[slipped]), 10)

  # Why the slip is NOT repaired in the other direction: three remedies each bring a
  # comparable share of the lower tail into the band, and terrain cannot choose.
  lower <- s[s$set == "lower_tail", ]
  ln <- lower$scale_n * lower$focal_length / 1000
  into_band <- function(f) sum(in_band((lower$flying_height * f - lower$elev) / ln))
  counts <- c(into_band(k), into_band(10), into_band(2))
  expect_true(all(counts > 600))
  expect_lt(max(counts) / min(counts), 1.2)

  # The ceiling clears every legitimate height in the catalogue, film and digital.
  film <- pop[pop$media == "film", ]
  legit_max <- max(film$flying_height_max[film$ratio_asl_to <= 3])
  expect_identical(legit_max, 14630L)
  expect_gt(fly_flying_height_max(), legit_max)
  expect_gt(fly_flying_height_max(), pop$flying_height_max[pop$media == "digital"] * 2)
  # ... and is no discriminator: slipped frames sit under it, which is the whole reason
  # the ratio check exists.
  expect_gt(sum(s$flying_height[slipped] < fly_flying_height_max()), 0)
})
