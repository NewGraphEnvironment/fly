# Frames under the terrain on a roll-height whose catalogue centroids fly#97 labelled
# `misplaced` (fly#99). The warning reads `flying_height_image_overlap_keys.csv` itself, so the
# ledger is one fact in one file; `test-fly_footprint_image_overlap.R` recomputes `location`.

# One frame per row, all at one point over level ground, so `r <= 0` is arithmetic: the DEM
# reads `elev` everywhere and a frame is under the terrain exactly when its height is at or
# below it. `bc77070` 1158 m, 153 mm, 1:5000 is a `misplaced` key; `bc99999` is not a roll.
misplaced_fixture <- function(film_roll = c("bc77070", "bc99999"),
                              flying_height = rep(1158, length(film_roll)),
                              focal_length = rep(153, length(film_roll)),
                              scale = rep("1:5000", length(film_roll))) {
  n <- length(film_roll)
  sf::st_sf(
    airp_id = seq_len(n),
    film_roll = film_roll,
    scale = scale,
    media = rep("Film - BW", n),
    focal_length = focal_length,
    flying_height = flying_height,
    geometry = sf::st_sfc(rep(list(sf::st_point(c(-126.60, 54.40))), n), crs = 4326)
  )
}

collect_warnings <- function(expr) {
  w <- character()
  val <- withCallingHandlers(expr, warning = function(x) {
    w <<- c(w, conditionMessage(x))
    invokeRestart("muffleWarning")
  })
  list(value = val, warnings = w)
}

misplaced_warnings <- function(w) grep("labelled `misplaced`", w, value = TRUE, fixed = TRUE)

test_that("the ledger is the keys file's misplaced rows, five roll-heights", {
  tab <- fly:::fly_height_misplaced_table()
  keys <- utils::read.csv(system.file("extdata", "flying_height_image_overlap_keys.csv",
                                      package = "fly", mustWork = TRUE),
                          stringsAsFactors = FALSE)
  expect_true(all(tab$location == "misplaced"))
  expect_identical(nrow(tab), sum(keys$location %in% "misplaced"))
  expect_identical(
    sort(paste(tab$film_roll, tab$flying_height)),
    c("bc77026 2042", "bc77070 1158", "bc77072 1829", "bc77072 1981", "bc77087 1158")
  )
  # fly#97 left these two unsettled; the plan gate decided they are not named (fly#99).
  expect_false(any(tab$film_roll %in% c("bc7718", "bc80117")))
  # The warning says the photos show the step longer than the air base. The generator's rule
  # also labels `consistent_nominal` and `disagrees` keys `misplaced`, for which that sentence
  # would be false, so a re-run that adds one must stop here rather than ship the claim.
  mk <- keys[keys$location %in% "misplaced", ]
  expect_true(all(mk$w1 == "step_overstated"))
  # And "the logbook pages write the catalogued height above sea level for at least 90% of the
  # frames they read": the figure is read off the same rows (W2's own 90% rule). The M.S.L.
  # header is the note's claim, which `test-fly_footprint_image_overlap.R` pins on the 107
  # reached frames under the terrain; the rows do not carry the header.
  expect_true(all(mk$w2_height == "msl_catalogue"))
  expect_true(all(mk$frames_catalogue / mk$frames_logbook >= 0.9))
  # "Not thereby clean: four fly#97 measured carry another label" -- the 9 keys, and which 4.
  expect_identical(nrow(keys), 9L)
  expect_identical(sort(keys$film_roll[!keys$location %in% "misplaced"]),
                   c("bc5715", "bc7718", "bc80117", "bcc325"))
  # "Not every frame on them is read by the logbook": the code comment's two cases.
  rd <- paste(mk$film_roll, mk$flying_height, mk$frames_logbook, mk$frames)
  expect_true(all(c("bc77026 2042 80 118", "bc77072 1829 12 17") %in% rd))
  expect_identical(sum(mk$frames_logbook < mk$frames), 2L)
})

test_that("the roxygen's five keys and its census counts are the shipped files'", {
  tab <- fly:::fly_height_misplaced_table()
  src <- testthat::test_path("..", "..", "man", "fly_footprint.Rd")
  skip_if(!file.exists(src), "man/ is not reachable from an installed package")
  prose <- gsub("\\s+", " ", paste(readLines(src), collapse = " "))
  listed <- regmatches(prose, regexpr("On five roll-heights \\([^)]*\\)", prose))
  expect_length(listed, 1)
  # Each key, as the roxygen spells it: roll, then height in metres.
  for (r in unique(tab$film_roll)) {
    hs <- sort(tab$flying_height[tab$film_roll == r])
    expect_match(listed, paste0("\\code{", r, "} ", paste(hs, collapse = " m and "), " m"),
                 fixed = TRUE, info = r)
  }
  expect_identical(lengths(regmatches(listed, gregexpr("\\\\code\\{bc", listed))),
                   length(unique(tab$film_roll)))
  keys <- utils::read.csv(system.file("extdata", "flying_height_image_overlap_keys.csv",
                                      package = "fly", mustWork = TRUE))
  mk <- keys[keys$location %in% "misplaced", ]
  ex <- utils::read.csv(system.file("extdata", "flying_height_rolls_excluded.csv",
                                    package = "fly", mustWork = TRUE))
  k <- function(d) paste(d$film_roll, d$flying_height, d$focal_length, d$scale_n)
  above <- sum(ex$frames_measured[ex$tail == "terrain" & k(ex) %in% k(mk)])
  expect_identical(c(sum(mk$frames_nonpositive), sum(mk$frames), above), c(112L, 311L, 199L))
  expect_identical(sum(mk$frames_nonpositive) + above, sum(mk$frames))
  # 311 is the census, not the catalogue: the census holds only frames below the band or under
  # the terrain, and the catalogue has frames in band on these keys too (code-check round 2).
  expect_match(prose, paste("Of the 311 frames on these roll-heights that fly#93's census holds",
                            "(those in band above sea level but below it over the ground, and",
                            "those under the terrain), 112 are under",
                            "MRDEM's terrain; the other 199 are below the band"), fixed = TRUE)
  expect_match(prose, "Frames in band are sized from the DEM as usual", fixed = TRUE)
})

test_that("a frame under the terrain on a misplaced roll-height is named; another roll is not", {
  skip_if_no_terra()
  res <- collect_warnings(fly_footprint(misplaced_fixture(), dem = flat_dem(elev = 1300)))
  # Both frames still reach the generic fallback warning, unchanged.
  expect_match(res$warnings, "terrain at or above the aircraft", all = FALSE)
  mis <- misplaced_warnings(res$warnings)
  expect_length(mis, 1)
  expect_match(mis, "^1 of those 2 frames", perl = TRUE)
  expect_match(mis, "bc77070 1158 m (1 frame)", fixed = TRUE)
  expect_no_match(mis, "bc99999", fixed = TRUE)
  expect_match(mis, "labelled so far, not a census", fixed = TRUE)
  expect_match(mis, "Across the five roll-heights so labelled, not every frame is read by the logbook",
               fixed = TRUE)
  expect_match(mis, "or the frames are not where the catalogue puts them", fixed = TRUE)
  expect_match(mis, "for at least 90% of the frames they read", fixed = TRUE)
  expect_match(mis, "What the frames under the terrain covered", fixed = TRUE)
  # The footprint itself is unchanged: drawn at nominal scale where the catalogue puts it.
  expect_identical(res$value$footprint_terrain, c("nominal_scale", "nominal_scale"))
  expect_identical(res$value$height_source, c("implausible", "implausible"))
  expect_equal(sf::st_area(res$value)[1], sf::st_area(res$value)[2])
})

test_that("a misplaced-key frame above the terrain is not named", {
  skip_if_no_terra()
  res <- collect_warnings(fly_footprint(misplaced_fixture("bc77070"), dem = flat_dem(elev = 300)))
  expect_length(misplaced_warnings(res$warnings), 0)
  # Beside a frame that IS under the terrain, so the block runs: 1158 m over 1000 m ground
  # is above it, 900 m is not. What keeps the misplaced key out here is that it is not in the
  # fallback set at all (r = 0.21 is out of band, so `implausible`), not the `r <= 0` test
  # alone: for a keyed frame with complete metadata, `unusable` and `under_terrain` coincide.
  fx <- misplaced_fixture(c("bc77070", "bc99999"), flying_height = c(1158, 900))
  res <- collect_warnings(fly_footprint(fx, dem = flat_dem(elev = 1000)))
  expect_match(res$warnings, "terrain at or above the aircraft", all = FALSE)
  expect_identical(res$value$height_source, c("implausible", "implausible"))
  expect_length(misplaced_warnings(res$warnings), 0)
})

test_that("a frame under the terrain that never reached the roll table does not error", {
  skip_if_no_terra()
  # A `media` outside `fly_film_media()` is not compared against its scale, so `out_of_band`
  # is FALSE everywhere and the roll-table block, where `num()` used to be defined, never
  # runs. The frame still falls under the terrain, so the misplaced block does (plan review B1).
  fx <- misplaced_fixture(c("bc77070", "bc99999"))
  fx$media <- "Film - Odd"
  res <- collect_warnings(fly_footprint(fx, dem = flat_dem(elev = 1300),
                                        format_size = c("Film - Odd" = 9)))
  expect_match(res$warnings, "terrain at or above the aircraft", all = FALSE)
  expect_match(misplaced_warnings(res$warnings), "bc77070 1158 m (1 frame)", fixed = TRUE)
})

test_that("the generic fallback warning is unchanged", {
  skip_if_no_terra()
  res <- collect_warnings(fly_footprint(misplaced_fixture(), dem = flat_dem(elev = 1300)))
  generic <- paste0(
    "2 of 2 frames have `flying_height` or `focal_length` values that give no usable height ",
    "above ground \u2014 missing, zero, or terrain at or above the aircraft. Check that ",
    "`flying_height` is metres above sea level. Sized from nominal scale instead. See ",
    "`footprint_terrain`."
  )
  expect_true(generic %in% res$warnings)
})

test_that("only the four key columns together match, written as integer or double", {
  skip_if_no_terra()
  # bc77070 at 1158 m but on a 305 mm lens, and at 1:6000, is a different roll-height.
  fx <- misplaced_fixture(c("bc77070", "bc77070", "bc77070", "bc77087"),
                          flying_height = c(1158L, 1158, 1158, 1158),
                          focal_length = c(153L, 305, 153, 153),
                          scale = c("1:5000", "1:5000", "1:6000", "1:5000"))
  res <- collect_warnings(fly_footprint(fx, dem = flat_dem(elev = 1300)))
  mis <- misplaced_warnings(res$warnings)
  expect_length(mis, 1)
  expect_match(mis, "^2 of those 4 frames", perl = TRUE)
  expect_match(mis, "bc77070 1158 m (1 frame), bc77087 1158 m (1 frame)", fixed = TRUE)
})

test_that("frames are counted per roll-height and pluralised", {
  skip_if_no_terra()
  fx <- misplaced_fixture(c("bc77087", "bc77070", "bc77087"))
  res <- collect_warnings(fly_footprint(fx, dem = flat_dem(elev = 1300)))
  mis <- misplaced_warnings(res$warnings)
  expect_match(mis, "^3 of those 3 frames", perl = TRUE)
  expect_match(mis, "bc77070 1158 m (1 frame), bc77087 1158 m (2 frames)", fixed = TRUE)
})

test_that("no film_roll column, an NA roll, or no dem: nothing is named and nothing errors", {
  skip_if_no_terra()
  fx <- misplaced_fixture()
  fx$film_roll <- NULL
  res <- collect_warnings(fly_footprint(fx, dem = flat_dem(elev = 1300)))
  expect_length(misplaced_warnings(res$warnings), 0)

  fx <- misplaced_fixture(c(NA, "bc77070"))
  res <- collect_warnings(fly_footprint(fx, dem = flat_dem(elev = 1300)))
  expect_match(misplaced_warnings(res$warnings), "^1 of those 2 frames", perl = TRUE)

  res <- collect_warnings(fly_footprint(misplaced_fixture()))
  expect_length(misplaced_warnings(res$warnings), 0)
})

test_that("a factor film_roll and every caller class shape reach the same warning", {
  skip_if_no_terra()
  fx <- misplaced_fixture()
  shapes <- list(
    plain = fx,
    factor = within(fx, film_roll <- factor(film_roll)),
    tbl = sf::st_as_sf(dplyr::as_tibble(fx)),
    grouped = dplyr::group_by(sf::st_as_sf(dplyr::as_tibble(fx)), .data$film_roll)
  )
  shapes$bcdc <- shapes$tbl
  class(shapes$bcdc) <- c("bcdc_sf", class(shapes$bcdc))
  stopifnot(inherits(shapes$tbl, "tbl_df"), inherits(shapes$grouped, "grouped_df"))
  dem <- flat_dem(elev = 1300)
  msgs <- vapply(shapes, function(s) {
    m <- misplaced_warnings(collect_warnings(fly_footprint(s, dem = dem))$warnings)
    if (length(m) == 1) m else NA_character_
  }, character(1))
  expect_false(anyNA(msgs))
  expect_length(unique(msgs), 1)
})
