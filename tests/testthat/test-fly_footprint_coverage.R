# What a partially DEM-covered footprint costs (fly#58), and the reporting it justifies.
#
# Every figure `inst/notes/terrain-correction.md` publishes about partial coverage is
# recomputed here from the artifacts that measured it, rather than trusted. That is the
# pattern `test-fly_mask.R` established, and it exists because a note in this package once
# published a maximum where it meant a minimum and nothing caught it for two releases.
#
# The sweep ships as two tables that join on `airp_id` AND `arm`: one row per truncation
# run, and one row per (frame, arm) carrying that arm's own full-coverage reference.
# Splitting them is what keeps the artifact at 1.5 MB instead of 3.5; keying them on both
# columns is what stops an arm being measured against a different raster's reference.

sweep_tables <- function() {
  sp <- system.file("extdata/dem_coverage_sweep.csv", package = "fly")
  tp <- system.file("extdata/dem_coverage_targets.csv", package = "fly")
  pp <- system.file("extdata/dem_coverage_population.csv", package = "fly")
  if (sp == "" || tp == "" || pp == "") {
    return(NULL)
  }
  sw <- utils::read.csv(sp, stringsAsFactors = FALSE)
  tg <- utils::read.csv(tp, stringsAsFactors = FALSE)
  # Joined on `arm` as well as `airp_id`. Every arm samples a different raster and so has
  # its own full-coverage reference; joining on the frame alone would measure each arm's
  # truncation against the NATIVE reference, which is a different DEM.
  d <- merge(sw, tg, by = c("airp_id", "arm"))
  d <- d[d$ref_ok, ]
  # Linear error against the frame's own full-coverage answer. Linear, not area: the note
  # quotes width throughout, and area is the square of this.
  d$err <- sqrt(d$area / d$ref_area) - 1
  d$nom <- sqrt(d$nominal_area / d$ref_area) - 1
  list(runs = sw, targets = tg,
       population = utils::read.csv(pp, stringsAsFactors = FALSE), joined = d)
}

# The population the note's error tables are computed over: one mechanism, one arm, and
# only the frames the DEM actually sized. Mixing in the runs that lost their terrain
# entirely would put a nominal-scale fallback in a table about partial coverage.
native_sized <- function(d) {
  d[d$arm == "native" & d$mech == "na_mask" & d$footprint_terrain == "dem_agl", ]
}


test_that("the shipped sweep is the one the note was written from", {
  x <- sweep_tables()
  skip_if(is.null(x), "the dem coverage sweep is not installed")

  # Premises. A truncated table would make every assertion below vacuous, and silently.
  expect_identical(nrow(x$runs), 11520L)
  # One row per (frame, arm), not per frame: 120 native plus 40 in each of three arms.
  expect_identical(nrow(x$targets), 240L)
  expect_identical(anyDuplicated(paste(x$targets$airp_id, x$targets$arm)), 0L)
  expect_identical(length(unique(x$targets$airp_id)), 120L)
  expect_identical(sum(x$targets$ref_ok[x$targets$arm == "native"]), 119L)
  # The references are genuinely per arm, which is why the key needs both columns. Compared
  # for the SAME frame across two arms — `length(unique(ref_n)) > 1` over the pooled rows
  # would be satisfied by ordinary frame-to-frame variation, and would still pass a
  # regression that filled every arm's reference from the native run.
  nat <- x$targets[x$targets$arm == "native", ]
  crs <- x$targets[x$targets$arm == "coarse", ]
  i <- match(crs$airp_id, nat$airp_id)
  expect_false(anyNA(i))
  expect_gt(nrow(crs), 30)
  expect_identical(sum(crs$ref_n != nat$ref_n[i]), nrow(crs))
  expect_setequal(unique(x$runs$arm), c("native", "coarse", "geographic", "anisotropic"))
  expect_setequal(unique(x$runs$mech), c("na_mask", "extent_crop"))
  expect_setequal(unique(x$runs$dir), c("N", "S", "E", "W", "NE", "NW", "SE", "SW"))
  expect_identical(length(unique(x$runs$cut_u)), 8L)
  # Every run joins to a target, or the error is measured against nothing.
  expect_true(all(paste(x$runs$airp_id, x$runs$arm) %in%
                    paste(x$targets$airp_id, x$targets$arm)))
  # The join loses nothing: every run finds its reference.
  expect_identical(nrow(merge(x$runs, x$targets, by = c("airp_id", "arm"))), nrow(x$runs))
  # The strata are the two axes the sweep was designed on, and both are properties known
  # before any truncation — never the outcome.
  expect_identical(length(unique(x$targets$stratum)), 12L)
  expect_gt(sum(x$targets$holdout), 30)

  # One target failed its premise and is excluded by name, not silently.
  expect_identical(unique(x$targets$airp_id[!x$targets$ref_ok]), 1154997L)
})


test_that("the error is the elevation bias over the height above ground, and nothing else", {
  x <- sweep_tables()
  skip_if(is.null(x), "the dem coverage sweep is not installed")

  # The claim the whole section rests on: half-side scales with height above ground, so
  # the realised width error IS the analytic term. If the pipeline contributed anything of
  # its own, this is where it would show.
  u <- x$joined[x$joined$footprint_terrain == "dem_agl" &
                  x$joined$height_source == "reported", ]
  expect_gt(nrow(u), 6000)
  analytic <- u$height_agl / u$ref_agl - 1
  # 1e-5 rather than machine epsilon because the shipped table is rounded to what the note
  # quotes: at full precision this agrees to 1.6e-13.
  expect_lt(max(abs(u$err - analytic)), 1e-5)
})


test_that("0.95 is where the worst case stops being cheaper than the deferred ray-casting", {
  x <- sweep_tables()
  skip_if(is.null(x), "the dem coverage sweep is not installed")
  n <- native_sized(x$joined)

  worst_at <- function(floor) max(abs(n$err[n$dem_coverage >= floor]))
  # The three figures the threshold's own comment in R/fly_footprint.R quotes.
  expect_equal(100 * worst_at(0.95), 0.794, tolerance = 2e-2)
  expect_equal(100 * worst_at(0.94), 0.794, tolerance = 2e-2)
  expect_equal(100 * worst_at(0.92), 1.221, tolerance = 2e-2)

  # The argument, not just the numbers: at the shipped threshold the worst truncated frame
  # is still cheaper in width than the ~2% of AREA per-corner ray-casting would move, and
  # one percent of width is about two percent of area. Below 0.92 that stops being true.
  expect_lt(worst_at(fly_dem_coverage_min()), 0.01)
  expect_gt(worst_at(0.92), 0.01)
  # ... and the threshold is where the code says it is.
  expect_equal(fly_dem_coverage_min(), 0.95)
})


test_that("no coverage band exists where falling back to nominal scale would be better", {
  x <- sweep_tables()
  skip_if(is.null(x), "the dem coverage sweep is not installed")
  n <- native_sized(x$joined)

  # The rule that decided against a fallback floor, fixed before the numbers existed: add
  # one only if some band exists where the DEM route is worse in the median. None is.
  b <- cut(n$dem_coverage, c(-0.01, 0.2, 0.4, 0.6, 0.8, 0.9, 0.95, 0.99, 1.01))
  dem <- tapply(abs(n$err), b, stats::median)
  nom <- tapply(abs(n$nom), b, stats::median)
  # `all()` of a length-0 or all-NA vector is TRUE, so the bands are counted first.
  expect_identical(sum(!is.na(dem)), 8L)
  expect_true(all(dem < nom))
  # With room, even in the worst band — this is what makes the absence of a floor a
  # measurement rather than a close call.
  expect_gt(min(nom / dem), 3)

  # The published pair for the lowest band, and the honest counterpart: the DEM route is
  # still worse on a minority of individual runs there.
  low <- n[n$dem_coverage <= 0.2, ]
  expect_equal(100 * stats::median(abs(low$err)), 1.491, tolerance = 2e-2)
  expect_equal(100 * stats::median(abs(low$nom)), 5.755, tolerance = 2e-2)
  expect_equal(sum(abs(low$err) > abs(low$nom)), 229)
  expect_equal(mean(abs(low$err) > abs(low$nom)), 0.152, tolerance = 2e-2)
})


test_that("coverage cannot separate the frames inside a band, and the covered spread can", {
  x <- sweep_tables()
  skip_if(is.null(x), "the dem coverage sweep is not installed")
  n <- native_sized(x$joined)

  # The spread the note publishes as 13 to 52 times. This is the whole case for shipping a
  # second column: at a fixed coverage, nothing else on the row separates these frames.
  #
  # The five ratios the note's table prints, recomputed — not a bound on them. A bound
  # would have to be `> 12.9`, because the smallest is 12.96 and the table rounds it to
  # 13.0x; asserting `> 13` is asserting the rounding, and it fails.
  b <- cut(n$dem_coverage, c(-0.01, 0.2, 0.4, 0.6, 0.8, 0.9, 0.95, 0.99, 1.01))
  ratio <- tapply(abs(n$err), b, function(z) max(z) / stats::median(z))
  expect_identical(sum(!is.na(ratio)), 8L)
  published <- c("(-0.01,0.2]" = 15.8, "(0.2,0.4]" = 13.0, "(0.6,0.8]" = 16.6,
                 "(0.8,0.9]" = 14.1, "(0.95,0.99]" = 25.1)
  for (lv in names(published)) {
    expect_equal(unname(ratio[lv]), unname(published[lv]), tolerance = 2e-2,
                 info = lv)
  }
  # And the range the prose states, to the precision the prose states it.
  expect_gt(min(ratio, na.rm = TRUE), 12.9)
  expect_lt(max(ratio, na.rm = TRUE), 52.5)

  # Scored on held-out targets only, which were untouched until the predictor was chosen.
  # Spelled exactly as `data-raw/dem_calibrate-coverage_error.R` spells it, so the two
  # cannot drift apart. They used different filters — `covered_n > 0 & is.finite(err)`
  # there against `dem_coverage > 0 & is.finite(covered_grad)` here. On this population
  # they select the identical rows (measured: 0 differ), which is exactly why aligning
  # them rather than checking them was the fix: two expressions that agree today and are
  # maintained separately are one edit from disagreeing, and nothing would say so.
  h <- n[n$holdout & n$covered_n > 0 & is.finite(n$err) & is.finite(n$covered_grad), ]
  expect_gt(length(unique(h$airp_id)), 30)
  rho <- function(v) stats::cor(v, abs(h$err), method = "spearman")

  # Pooled, the terrain statistics barely beat coverage — and pooling is the WRONG
  # comparison, because coverage dominates it. Recorded so the reasoning is checkable:
  # on this alone no column would have shipped.
  expect_equal(abs(rho(h$dem_coverage)), 0.717, tolerance = 2e-2)
  expect_equal(rho(h$covered_sd), 0.185, tolerance = 5e-2)
  expect_equal(rho(h$covered_range), 0.152, tolerance = 5e-2)

  # Within a coverage band, which is the question actually being asked, both spread
  # measures carry real signal.
  hb <- cut(h$dem_coverage, c(0, 0.2, 0.4, 0.6, 0.8, 0.95, 1.01))
  within_sd <- tapply(seq_len(nrow(h)), hb, function(i) {
    if (length(i) < 30) return(NA_real_)
    stats::cor(h$covered_sd[i], abs(h$err[i]), method = "spearman")
  })
  within_grad <- tapply(seq_len(nrow(h)), hb, function(i) {
    if (length(i) < 30) return(NA_real_)
    stats::cor(h$covered_grad[i], abs(h$err[i]), method = "spearman")
  })
  # Premise before the property. `min(all-NA, na.rm = TRUE)` is `Inf`, so if every band
  # fell under its size guard this assertion would pass on no data at all.
  expect_identical(sum(!is.na(within_sd)), 6L)
  expect_identical(sum(!is.na(within_grad)), 6L)
  # Both ends. A lower bound alone leaves the published "0.39 to 0.59" half unpinned, so a
  # max drifting to 0.384 would keep the suite green and the prose wrong.
  expect_equal(unname(round(min(within_sd, na.rm = TRUE), 2)), 0.39, tolerance = 1e-6)
  expect_equal(unname(round(max(within_sd, na.rm = TRUE), 2)), 0.59, tolerance = 1e-6)

  # The comparison that decided WHICH statistic ships. Until a review round recomputed it,
  # this half had no producer line and no assertion: the note published the gradient's
  # range as 0.27 to 0.51 and "four bands of six" where it is 0.27 to 0.59 and five of six,
  # and the error ran in the direction that flattered the column that was chosen.
  expect_equal(unname(round(min(within_grad, na.rm = TRUE), 2)), 0.27, tolerance = 1e-6)
  expect_equal(unname(round(max(within_grad, na.rm = TRUE), 2)), 0.59, tolerance = 1e-6)
  expect_identical(sum(within_sd > within_grad), 5L)

  # What `dem_elev_sd` buys a caller: split each band at its own median spread.
  hb2 <- cut(h$dem_coverage, c(0, 0.5, 0.8, 0.95, 1.01))
  gain <- tapply(seq_len(nrow(h)), hb2, function(i) {
    if (length(i) < 40) return(NA_real_)
    z <- h[i, ]
    m <- stats::median(z$covered_sd)
    stats::median(abs(z$err[z$covered_sd >= m])) / stats::median(abs(z$err[z$covered_sd < m]))
  })
  # The premise again, and it matters most here: this pair is the ONLY test of the "2.3 to
  # 4.1 times" claim the whole column exists for, and `min`/`max` of an all-NA vector are
  # `Inf` and `-Inf`, which would satisfy both bounds silently.
  expect_identical(sum(!is.na(gain)), 4L)
  expect_gt(min(gain, na.rm = TRUE), 2)
  expect_lt(max(gain, na.rm = TRUE), 4.5)
})


test_that("the geometric treatment and the achieved coverage agree except in the tail", {
  x <- sweep_tables()
  skip_if(is.null(x), "the dem coverage sweep is not installed")
  n <- native_sized(x$joined)

  # A draft of the note claimed "a 0.30 target comes back as 0.215" — the two-frame
  # probe's parameterisation (a fraction of the bounding box) quoted as this one (a share
  # of area). It survived two review rounds before being caught, and nothing shipped with
  # it. Pinned as a distribution so no single anecdote can stand in for it again.
  gap <- n$share_removed - (1 - n$dem_coverage)
  expect_equal(stats::median(gap), 0, tolerance = 1e-3)
  expect_equal(unname(stats::quantile(abs(gap), 0.9)), 0.055, tolerance = 5e-2)
  expect_equal(max(abs(gap)), 0.284, tolerance = 5e-2)
  # ... and the specific claim that was wrong: a 0.30 share does NOT land near 0.215.
  near <- n[abs(n$share_removed - 0.30) < 0.01, ]
  expect_gt(nrow(near), 40)
  expect_equal(stats::median(near$dem_coverage), 0.699, tolerance = 2e-2)
  expect_false(any(abs(near$dem_coverage - 0.215) < 0.01))
})


test_that("the result does not depend on the truncation mechanism, or on the grid", {
  x <- sweep_tables()
  skip_if(is.null(x), "the dem coverage sweep is not installed")
  d <- x$joined[x$joined$arm == "native", ]

  m1 <- d[d$mech == "na_mask", ]
  m2 <- d[d$mech == "extent_crop", ]
  i <- match(paste(m2$airp_id, m2$dir, m2$cut_u), paste(m1$airp_id, m1$dir, m1$cut_u))
  ok <- !is.na(i)
  expect_gt(sum(ok), 1800)
  a <- m1[i[ok], ]
  b <- m2[ok, ]
  # Where both mechanisms left the frame on the DEM route they agree closely. Where they
  # do not is the degenerate endpoint — a total loss, where one cell ring at the boundary
  # decides between `dem_agl` with a handful of cells and `no_dem_coverage` — and that
  # exception is stated rather than smoothed over.
  both <- a$footprint_terrain == "dem_agl" & b$footprint_terrain == "dem_agl"
  expect_gt(sum(both), 1600)
  expect_lt(max(abs(a$err[both] - b$err[both])), 0.005)
  disagree <- which(abs(a$err - b$err) > 0.01)
  expect_lt(length(disagree), 5)
  expect_true(all(a$share_removed[disagree] > 0.99))

  # Resolution, CRS and cell shape do not move the answer. The geographic arm matters
  # most: the reprojection branch that 0.95 was originally chosen for does not execute at
  # all on a DEM in the data's own CRS, so without it no threshold claim could be licensed.
  arm_median <- function(a_name) {
    z <- x$joined[x$joined$arm == a_name & x$joined$mech == "na_mask" &
                    x$joined$footprint_terrain == "dem_agl" & x$joined$dem_coverage < 0.8, ]
    100 * stats::median(abs(z$err))
  }
  expect_equal(arm_median("coarse"), 0.696, tolerance = 5e-2)
  expect_equal(arm_median("geographic"), 0.585, tolerance = 5e-2)
  expect_equal(arm_median("anisotropic"), 0.677, tolerance = 5e-2)
  expect_equal(arm_median("native"), 0.777, tolerance = 5e-2)
})


test_that("truncation never trips the flying-height checks, only the total-loss endpoint", {
  x <- sweep_tables()
  skip_if(is.null(x), "the dem coverage sweep is not installed")
  n <- x$joined[x$joined$arm == "native" & x$joined$mech == "na_mask", ]

  flipped <- !(n$footprint_terrain %in% "dem_agl") | !(n$height_source %in% "reported")
  expect_identical(nrow(n), 7616L)
  expect_identical(sum(flipped), 873L)
  # Every one is the legitimate endpoint: the DEM was removed entirely. Nothing crosses
  # `fly_height_ratio_band()` because its first pass was biased, which is the failure mode
  # a design review predicted and the sweep refutes.
  expect_true(all(n$footprint_terrain[flipped] == "no_dem_coverage"))
  expect_true(all(n$dem_coverage[flipped] == 0))
  expect_false(any(n$height_source[flipped] %in% "implausible"))
})


test_that("partial coverage is all but absent against the DEM the package recommends", {
  x <- sweep_tables()
  skip_if(is.null(x), "the dem coverage sweep is not installed")
  p <- x$population

  total <- function(k) p$n[p$set == k & is.na(p$coverage_bin)]
  expect_identical(total("film_dem_eligible_total"), 1437147L)
  expect_identical(total("film_edge_candidates_total"), 113L)
  expect_identical(total("digital_edge_candidates_total"), 173L)

  # The 66 the note publishes: frames the DEM SIZED and still left short of the threshold.
  # Binned by route, because the 26 it never reached land in the same coverage bin and
  # summing across them gives 92.
  edge <- p[p$set == "edge" & p$footprint_terrain == "dem_agl", ]
  short <- sum(edge$n[edge$coverage_bin %in%
                        c("[0,0.5)", "[0.5,0.8)", "[0.8,0.9)", "[0.9,0.95)")])
  expect_identical(short, 66L)
  expect_identical(sum(p$n[p$set == "edge" & p$footprint_terrain == "no_dem_coverage"]), 26L)
  expect_lt(short / total("film_dem_eligible_total"), 1e-4)

  # The control on the candidate finder, which reads a coarse overview and so cannot see a
  # small interior hole: not one randomly drawn frame is short of full coverage. Without
  # this the census above would be a census of whatever the finder happened to notice.
  rand <- p[p$set == "random" & p$footprint_terrain == "dem_agl", ]
  expect_identical(sum(rand$n[rand$coverage_bin != "1"]), 0L)
  expect_gt(sum(rand$n), 2900)
})


test_that("dem_elev_sd is reported for the pass the returned footprint came from", {
  skip_if_no_terra()
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  fp <- suppressWarnings(fly_footprint(centroids, dem = testdata_path("dem.tif")))

  expect_true("dem_elev_sd" %in% names(fp))
  expect_type(fp$dem_elev_sd, "double")
  sized <- fp$footprint_terrain %in% "dem_agl"
  expect_gt(sum(sized), 0)
  expect_false(anyNA(fp$dem_elev_sd[sized]))
  expect_true(all(fp$dem_elev_sd[sized] > 0))
  # Not a constant: a column that cannot vary would separate nothing, which is the one
  # thing it exists to do.
  expect_gt(stats::sd(fp$dem_elev_sd[sized]), 1)

  # NA exactly where there is no footprint, alongside the other reported columns.
  empty <- sf::st_is_empty(sf::st_geometry(fp))
  expect_true(all(is.na(fp$dem_elev_sd[empty])))
  # ... and NA throughout when no DEM was supplied, because nothing was sampled.
  expect_true(all(is.na(suppressWarnings(fly_footprint(centroids))$dem_elev_sd)))
})


test_that("dem_elev_sd tracks the terrain and not the frame size", {
  skip_if_no_terra()
  # Over level ground the spread is near zero however wide the frame; over real terrain it
  # is not. `flat_dem()` is a constant surface, so this separates "measures the DEM" from
  # "measures the footprint".
  hf <- height_fixture()
  flat <- suppressWarnings(fly_footprint(hf, dem = flat_dem()))
  sized <- flat$footprint_terrain %in% "dem_agl"
  expect_gt(sum(sized), 0)
  expect_true(all(flat$dem_elev_sd[sized] == 0 | is.na(flat$dem_elev_sd[sized])))

  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  real <- suppressWarnings(fly_footprint(centroids, dem = testdata_path("dem.tif")))
  expect_gt(stats::median(real$dem_elev_sd[real$footprint_terrain %in% "dem_agl"]), 5)
})

test_that("every row of the note's published tables recomputes from the shipped sweep", {
  x <- sweep_tables()
  skip_if(is.null(x), "the dem coverage sweep is not installed")
  np <- system.file("notes/terrain-correction.md", package = "fly")
  skip_if(np == "", "the terrain note is not installed")
  n <- native_sized(x$joined)

  # The binder set for this work was built by walking THIS file and not the note, so the
  # note's claims were a strict superset of the assertions and nothing enumerated the
  # difference — which is how a figure from the two-frame feasibility probe reached the
  # note and survived two review rounds. This test closes that by reading the note's own
  # tables and recomputing each row, so a figure cannot be published here without being
  # checked.
  md <- readLines(np, warn = FALSE)
  sec <- md[seq(grep("^## What a partially covered footprint costs", md),
                grep("^## Testing this", md) - 1)]
  # Terminate by enumeration rather than by intent. This test claims a figure cannot be
  # published in the section without being checked; that claim is only true if it walks
  # EVERY table, and an earlier version walked six of eight while saying so. Counting the
  # separator rows is what makes "all of them" a measurement.
  n_tables <- sum(grepl("^\\|[- |]+\\|$", sec))
  expect_identical(n_tables, 8L)
  pct <- function(v) as.numeric(sub("%$", "", v))
  # Compared at the PUBLISHED precision, not through a tolerance. `tolerance` in
  # testthat 3e is relative, so 2e-2 pinned a three-decimal figure only to +/-2% and
  # 12.529% would have survived drifting to 12.629%; tightening it instead just trades
  # that for false failures on the rounding the note itself carries. Rounding the computed
  # value to however many decimals the note prints and comparing exactly is what actually
  # binds the two.
  dp <- function(v) {
    v <- sub("%$", "", trimws(v))
    if (!grepl("\\.", v)) return(0L)
    nchar(sub(".*\\.", "", v))
  }
  expect_printed <- function(computed, printed, info) {
    expect_equal(round(computed, dp(printed)), pct(printed), tolerance = 1e-9, info = info)
  }
  rows_after <- function(header_regex) {
    i <- grep(header_regex, sec)
    expect_identical(length(i), 1L)
    r <- sec[seq(i + 2, length(sec))]
    r <- r[seq_len(which(!startsWith(r, "|"))[1] - 1)]
    lapply(strsplit(sub("^\\|", "", sub("\\|$", "", r)), "\\|"), trimws)
  }
  band_of <- function(lab) {
    e <- as.numeric(strsplit(sub("^0-", "0.00-", lab), "-")[[1]])
    n[n$dem_coverage > e[1] - 1e-9 & n$dem_coverage <= e[2] + 1e-9, ]
  }

  # Table 1 — signed error by coverage: n, median, 5th, 95th, max abs.
  t1 <- rows_after("^\\| achieved coverage \\| n \\| median")
  expect_identical(length(t1), 8L)
  for (r in t1) {
    z <- band_of(r[[1]])
    expect_identical(nrow(z), as.integer(gsub(",", "", r[[2]])), info = r[[1]])
    expect_printed(100 * stats::median(z$err), r[[3]], r[[1]])
    qs <- trimws(strsplit(r[[4]], "\\.\\.")[[1]])
    expect_printed(unname(100 * stats::quantile(z$err, .05)), qs[1], r[[1]])
    expect_printed(unname(100 * stats::quantile(z$err, .95)), qs[2], r[[1]])
    expect_printed(100 * max(abs(z$err)), r[[5]], r[[1]])
  }

  # Table 2 — the coverage-floor table behind the 0.95 argument.
  t2 <- rows_after("^\\| coverage floor \\| n \\| max abs linear error \\|")
  expect_identical(length(t2), 7L)
  for (r in t2) {
    f <- as.numeric(sub(".*>= ", "", gsub("\\*", "", r[[1]])))
    z <- n[n$dem_coverage >= f, ]
    expect_identical(nrow(z), as.integer(gsub(",", "", gsub("\\*", "", r[[2]]))), info = r[[1]])
    expect_printed(100 * max(abs(z$err)), gsub("\\*", "", r[[3]]), r[[1]])
  }

  # Table 3 — DEM route against the nominal fallback.
  t_nom <- rows_after("^\\| achieved coverage \\| median abs DEM \\|")
  expect_identical(length(t_nom), 8L)
  for (r in t_nom) {
    z <- band_of(r[[1]])
    expect_printed(100 * stats::median(abs(z$err)), r[[2]], r[[1]])
    expect_printed(100 * stats::median(abs(z$nom)), r[[3]], r[[1]])
    worse <- as.integer(gsub(",", "", sub(" of .*", "", r[[4]])))
    expect_identical(sum(abs(z$err) > abs(z$nom)), worse, info = r[[1]])
  }

  # Table 4 — the spread at fixed coverage, which is the case for the new column.
  t_sp <- rows_after("^\\| achieved coverage \\| median abs error \\| max abs error \\|")
  expect_identical(length(t_sp), 5L)
  for (r in t_sp) {
    z <- abs(band_of(r[[1]])$err)
    expect_printed(100 * stats::median(z), r[[2]], r[[1]])
    expect_printed(100 * max(z), r[[3]], r[[1]])
    expect_printed(max(z) / stats::median(z), sub("x$", "", r[[4]]), r[[1]])
  }

  # Table 5 — what `dem_elev_sd` buys, split at each band's own median spread. This is the
  # table the column's justification rests on, and until now only its 2-to-4.5 envelope
  # was asserted rather than its cells.
  t_gain <- rows_after("^\\| achieved coverage \\| low-spread median \\|")
  expect_identical(length(t_gain), 4L)
  hh <- n[n$holdout & n$covered_n > 0 & is.finite(n$err) & is.finite(n$covered_grad) &
            n$dem_coverage > 0, ]
  for (r in t_gain) {
    e <- as.numeric(strsplit(sub("^0-", "0.00-", r[[1]]), "-")[[1]])
    z <- hh[hh$dem_coverage > e[1] - 1e-9 & hh$dem_coverage <= e[2] + 1e-9, ]
    m <- stats::median(z$covered_sd)
    lo <- abs(z$err[z$covered_sd < m])
    hi <- abs(z$err[z$covered_sd >= m])
    expect_identical(length(lo), as.integer(sub(".*n=([0-9]+).*", "\\1", r[[2]])), info = r[[1]])
    expect_identical(length(hi), as.integer(sub(".*n=([0-9]+).*", "\\1", r[[3]])), info = r[[1]])
    expect_printed(100 * stats::median(lo), sub(" .*", "", r[[2]]), r[[1]])
    expect_printed(100 * stats::median(hi), sub(" .*", "", r[[3]]), r[[1]])
    expect_printed(stats::median(hi) / stats::median(lo), sub("x$", "", r[[4]]), r[[1]])
  }

  # Table 6 — the pooled predictor comparison. Its point is that the terrain statistics
  # BARELY beat coverage pooled, which is why the note says no column would have shipped on
  # it; 0.480 and 0.801 were asserted nowhere in the suite until round 4 counted the tables.
  t_pool <- rows_after("^\\| predictor, covered cells only \\|")
  expect_identical(length(t_pool), 5L)
  hp <- n[n$holdout & n$covered_n > 0 & is.finite(n$err) & is.finite(n$covered_grad), ]
  pooled <- c(
    "`dem_coverage`" = stats::cor(hp$dem_coverage, abs(hp$err), method = "spearman"),
    "`covered_range`" = stats::cor(hp$covered_range, abs(hp$err), method = "spearman"),
    "`covered_sd`" = stats::cor(hp$covered_sd, abs(hp$err), method = "spearman"),
    "`covered_grad` (planar fit)" = stats::cor(hp$covered_grad, abs(hp$err), method = "spearman"),
    "`covered_grad` x lost share x side / agl" = stats::cor(
      hp$covered_grad * (1 - hp$dem_coverage) * sqrt(hp$ref_area) / abs(hp$height_agl),
      abs(hp$err), method = "spearman"))
  for (r in t_pool) {
    expect_true(r[[1]] %in% names(pooled), info = r[[1]])
    stated <- as.numeric(sub(" .*", "", r[[2]]))
    expect_printed(abs(unname(pooled[[r[[1]]]])), sub("^-", "", sub(" .*", "", r[[2]])), r[[1]])
  }

  # Table 7 — the population census, recomputed from the shipped population table.
  t_pop <- rows_after("^\\| population \\| n \\| could reach nodata \\|")
  expect_identical(length(t_pop), 3L)
  p <- x$population
  tot <- function(k) p$n[p$set == k & is.na(p$coverage_bin)]
  expect_identical(as.integer(gsub(",", "", t_pop[[1]][[2]])), tot("film_dem_eligible_total"))
  expect_identical(as.integer(gsub(",", "", t_pop[[1]][[3]])), tot("film_edge_candidates_total"))
  expect_identical(as.integer(gsub(",", "", t_pop[[2]][[3]])), tot("digital_edge_candidates_total"))

  # Table 8 — the within-band rho comparison that decided WHICH statistic ships.
  t3 <- rows_after("^\\| achieved coverage \\| `covered_sd` \\| `covered_grad` \\|")
  expect_identical(length(t3), 6L)
  h <- n[n$holdout & n$covered_n > 0 & is.finite(n$err) & is.finite(n$covered_grad), ]
  for (r in t3) {
    z <- band_of(r[[1]])
    z <- z[z$airp_id %in% h$airp_id & z$holdout & z$covered_n > 0 & is.finite(z$covered_grad), ]
    expect_gt(nrow(z), 20)
    expect_printed(stats::cor(z$covered_sd, abs(z$err), method = "spearman"), r[[2]], r[[1]])
    expect_printed(stats::cor(z$covered_grad, abs(z$err), method = "spearman"), r[[3]], r[[1]])
  }
})
