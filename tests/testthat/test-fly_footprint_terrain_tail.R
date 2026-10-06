# The BW/colour frames out of the height band only through terrain (fly#93). Everything here
# is recomputed from what `data-raw/height_measure-terrain_tail.R` and
# `data-raw/height_calibrate-lower_tail_rolls.R` shipped; nothing trusts a verdict column.
# The rule and amendment A2 are in `inst/notes/terrain-correction.md`, "The terrain tail".

extdata <- function(f) {
  utils::read.csv(system.file("extdata", f, package = "fly", mustWork = TRUE),
                  stringsAsFactors = FALSE, na.strings = "")
}

band    <- fly_height_ratio_band()
in_band <- function(r) is.finite(r) & r >= band[1] & r <= band[2]
format_m <- 9 * 0.0254

test_that("every census frame is in band above sea level and below it over the ground", {
  cf <- extdata("flying_height_terrain_frames.csv")
  expect_gt(nrow(cf), 0)
  expect_false(anyDuplicated(cf$airp_id) > 0)
  # The sweep's film set, not `fly_film_media()`: infrared is #89's census.
  expect_true(all(cf$media %in% c("Film - BW", "Film - Colour")))
  ir <- extdata("infrared_film_frames.csv")
  expect_length(intersect(cf$airp_id, ir$airp_id), 0)
  nominal <- cf$scale_n * cf$focal_length / 1000
  expect_true(all(in_band(cf$flying_height / nominal)))
  r <- (cf$flying_height - cf$elev) / nominal
  # Below the band, and above the ground: a frame under terrain at or above the aircraft is
  # `fly_footprint()`'s own case, which no factor-1 row reaches (amendment A3).
  expect_true(all(r > 0 & r < band[1]))
  # A frame sharing a (roll, frame) key has no air base, as in the generator.
  expect_true(all(is.na(cf$base[cf$dup_key])))
})

test_that("the census reconciles with its population table and its controls", {
  cf <- extdata("flying_height_terrain_frames.csv")
  pop <- extdata("flying_height_terrain_population.csv")
  n <- stats::setNames(pop$n, pop$step)
  expect_identical(as.integer(n[["terrain_below"]]), nrow(cf))
  expect_identical(as.integer(n[["terrain_above"]]), 0L)
  expect_identical(as.integer(n[["rolls"]]), length(unique(cf$film_roll)))
  expect_identical(as.integer(n[["roll_heights"]]),
                   nrow(unique(cf[, c("film_roll", "flying_height", "focal_length", "scale_n")])))
  expect_gte(n[["read_exactly"]], n[["terrain_below"]] + n[["terrain_nonpositive"]])
  expect_gt(n[["in_band_asl"]], n[["read_exactly"]])
  # Control 3: frames just past the prefilter, read exactly, and none out of band.
  expect_gt(n[["rejected_region_read"]], 0)
  expect_identical(as.integer(n[["rejected_region_out_of_band"]]), 0L)
  # The margin is twice the worst coarse error over every frame read exactly.
  expect_true(abs(n[["margin_m"]] - 2 * n[["coarse_error_max_m"]]) <= 0.1)
})

test_that("the census holds every sweep frame of its stratum, at the sweep's elevation", {
  cf <- extdata("flying_height_terrain_frames.csv")
  sw <- extdata("flying_height_sweep.csv")
  rnd <- sw[sw$set == "random", ]
  nominal <- rnd$scale_n * rnd$focal_length / 1000
  r <- (rnd$flying_height - rnd$elev) / nominal
  hit <- in_band(rnd$flying_height / nominal) & !in_band(r) & is.finite(r) & r > 0
  # The issue's estimate: 12 of the 2,500 random frames.
  expect_identical(sum(hit), 12L)
  pop <- extdata("flying_height_terrain_population.csv")
  expect_identical(as.integer(pop$n[pop$step == "sweep_random_terrain"]), 12L)
  m <- match(rnd$airp_id[hit], cf$airp_id)
  expect_false(anyNA(m))
  expect_true(all(abs(cf$elev[m] - rnd$elev[hit]) <= 0.1))
})

test_that("amendment A2 excludes exactly the roll-heights spacing already decides (fly#93)", {
  # The window, as the generator draws it: central 95% of in-band random frames' overlap at
  # the reported height, with the air base #89 shipped for those frames.
  sw <- extdata("flying_height_sweep.csv")
  w <- extdata("infrared_film_window.csv")
  rnd <- merge(sw[sw$set == "random", ], w, by = "airp_id")
  side <- (rnd$flying_height - rnd$elev) / (rnd$focal_length / 1000)
  rnd <- rnd[in_band(side / rnd$scale_n), ]
  win <- unname(stats::quantile(1 - rnd$base / (format_m * (rnd$flying_height - rnd$elev) /
                                                  (rnd$focal_length / 1000)),
                                c(.025, .975), na.rm = TRUE))
  fits <- function(p) is.finite(p) & p >= win[1] & p <= win[2]

  cf <- extdata("flying_height_terrain_frames.csv")
  ir <- extdata("infrared_film_frames.csv")
  ir <- ir[ir$height_class == "outside_band", ]
  ir <- ir[in_band(ir$flying_height / (ir$scale_n * ir$focal_length / 1000)), ]
  cols <- c("film_roll", "flying_height", "focal_length", "scale_n", "elev", "base")
  terr <- rbind(cf[, cols], ir[, cols])
  p_at <- function(d, k) {
    side <- d$flying_height * k - d$elev
    ifelse(side > 0, 1 - d$base / (format_m * side / (d$focal_length / 1000)), -Inf)
  }
  key <- function(d) paste(d$film_roll, d$flying_height, d$focal_length, d$scale_n)
  a2 <- vapply(split(terr, key(terr)), function(d) {
    p_nom <- stats::median(1 - d$base / (format_m * d$scale_n), na.rm = TRUE)
    ok <- is.finite(d$base)
    can <- any(ok) && max(p_at(d[ok, ], 1.02)) >= win[1] && min(p_at(d[ok, ], 0.98)) <= win[2]
    if (fits(p_nom)) "nominal" else if (!can) "cannot" else "logbook"
  }, character(1))

  tab <- fly_height_roll_table()
  excl <- extdata("flying_height_rolls_excluded.csv")
  et <- excl[excl$tail == "terrain", ]
  got <- ifelse(grepl("^spacing fits nominal scale, which no logbook", et$reason), "nominal",
                ifelse(grepl("^spacing cannot fit the catalogued height", et$reason), "cannot",
                       "logbook"))
  # Every terrain roll-height is tabled or excluded; an A2 reason sits exactly where A2 says,
  # and no A2 roll-height is tabled.
  tt <- tab[tab$tail == "terrain", ]
  expect_setequal(c(key(tt), key(et)), names(a2))
  expect_identical(unname(got), unname(a2[key(et)]))
  expect_true(all(a2[key(tt)] == "logbook"))
  expect_true(all(grepl("nominal scale still applies", et$reason, fixed = TRUE)))
})
