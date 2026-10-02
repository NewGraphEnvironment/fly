# Infrared film is sized as the 9-inch negative because three witnesses say so (fly#89).
# Everything here is recomputed from what `data-raw/format_measure-infrared_film.R` shipped;
# nothing trusts the verdict columns it wrote. The rule is the pre-registered one with
# amendment 1 — see `inst/notes/camera-formats.md`, "Infrared film".

extdata <- function(f) {
  utils::read.csv(system.file("extdata", f, package = "fly", mustWork = TRUE),
                  stringsAsFactors = FALSE, na.strings = "")
}

ir_media   <- c("Film - BW IR", "Film - Colour IR")
formats    <- c(in9 = 9 * 0.0254, in5 = 5 * 0.0254, mm70 = 0.056)
min_frames <- 5L

band    <- fly_height_ratio_band()
in_band <- function(r) is.finite(r) & r >= band[1] & r <= band[2]
overlap <- function(base, side) 1 - base / side

# The window: central 95% of implied overlap over the sweep's in-band random frames, at 9 in.
window_frames <- function() {
  sw <- extdata("flying_height_sweep.csv")
  w  <- extdata("infrared_film_window.csv")
  rnd <- merge(sw[sw$set == "random", ], w, by = "airp_id")
  rnd$side <- (rnd$flying_height - rnd$elev) / (rnd$focal_length / 1000)
  rnd$r <- rnd$side / rnd$scale_n
  rnd[in_band(rnd$r), ]
}

recompute_w1 <- function(window) {
  fr <- extdata("infrared_film_frames.csv")
  fr$r <- (fr$flying_height - fr$elev) / (fr$scale_n * fr$focal_length / 1000)
  fits <- function(p) is.finite(p) & p >= window[1] & p <= window[2]
  do.call(rbind, lapply(split(fr, fr$film_roll), function(d) {
    rep_side <- ifelse(in_band(d$r), (d$flying_height - d$elev) / (d$focal_length / 1000), NA)
    med <- function(fmt, side) {
      p <- overlap(d$base, formats[[fmt]] * side)
      if (sum(is.finite(p)) >= min_frames) stats::median(p, na.rm = TRUE) else NA_real_
    }
    fin <- function(fmt) fits(med(fmt, d$scale_n)) | fits(med(fmt, rep_side))
    measurable <- is.finite(med("in9", d$scale_n)) | is.finite(med("in9", rep_side))
    alt <- fin("in5") | fin("mm70")
    w1 <- if (!measurable) {
      "unmeasurable"
    } else if (fin("in9")) {
      if (alt) "ambiguous" else "pass"
    } else {
      if (alt) "contradicts" else "fits_no_format"
    }
    data.frame(
      film_roll = d$film_roll[1], media = d$media[1],
      p_nominal_in9 = med("in9", d$scale_n), p_reported_in9 = med("in9", rep_side),
      w1 = w1
    )
  }))
}

test_that("the window and the spacing controls reproduce from the shipped frames", {
  rnd <- window_frames()
  expect_gt(nrow(rnd), 2000)
  p9 <- overlap(rnd$base, formats[["in9"]] * rnd$side)
  p5 <- overlap(rnd$base, formats[["in5"]] * rnd$side)
  window <- unname(stats::quantile(p9, c(.025, .975), na.rm = TRUE))
  # The figures the note quotes, to the precision it quotes them.
  expect_equal(round(window, 3), c(0.557, 0.780))
  # Control (a): ordinary frames at 9 in sit at the designed ~60%.
  expect_lt(abs(stats::median(p9, na.rm = TRUE) - 0.6), 0.1)
  # Control (b): the same frames sized at 5 in fall outside the window.
  m5 <- stats::median(p5, na.rm = TRUE)
  expect_true(m5 < window[1] || m5 > window[2])
})

test_that("every roll's spacing verdict recomputes from its frames", {
  rnd <- window_frames()
  window <- unname(stats::quantile(overlap(rnd$base, formats[["in9"]] * rnd$side),
                                   c(.025, .975), na.rm = TRUE))
  got <- recompute_w1(window)
  shipped <- extdata("infrared_film_rolls.csv")
  m <- merge(got, shipped, by = "film_roll", suffixes = c("", "_shipped"))
  expect_equal(nrow(m), 32)
  expect_setequal(m$media, ir_media)
  expect_equal(m$w1, m$w1_shipped)
  # Elevation and base ship rounded to 0.1 m; the medians move in the fourth decimal at most.
  expect_equal(m$p_nominal_in9, m$p_nominal_in9_shipped, tolerance = 1e-3)
  expect_equal(m$p_reported_in9, m$p_reported_in9_shipped, tolerance = 1e-3)
  # The outcomes the note names, roll by roll.
  expect_setequal(m$film_roll[m$w1 == "fits_no_format"],
                  c("bcf07060", "bci3", "bci95063", "bci96066"))
  expect_equal(m$film_roll[m$w1 == "ambiguous"], "bcf517")
  expect_false(any(m$w1 %in% c("contradicts", "unmeasurable")))
  expect_equal(sum(m$w1 == "pass"), 27)
})

test_that("the four rolls no format fits sit below the window, where a smaller format fits worse", {
  # Amendment 1 rests on this: below the window, shrinking the format lowers implied overlap,
  # so a 5-inch or 70 mm reading cannot be what these rolls are.
  s <- extdata("infrared_film_rolls.csv")
  low <- s[s$w1 == "fits_no_format", ]
  expect_true(all(pmax(low$p_nominal_in9, low$p_reported_in9, na.rm = TRUE) < 0.557))
  expect_true(all(low$p_nominal_in5 < low$p_nominal_in9))
  expect_true(all(low$p_nominal_mm70 < low$p_nominal_in5))
})

test_that("the #54 band classes and the three out-of-band roll-heights recompute", {
  fr <- extdata("infrared_film_frames.csv")
  nominal <- fr$scale_n * fr$focal_length / 1000
  r <- (fr$flying_height - fr$elev) / nominal
  r_slip <- (fr$flying_height / fly_height_slip_factor() - fr$elev) / nominal
  cls <- ifelse(in_band(r), "reported", ifelse(in_band(r_slip), "slip_repairable", "outside_band"))
  expect_equal(cls, fr$height_class)
  expect_equal(as.vector(table(factor(cls, c("reported", "outside_band", "slip_repairable")))),
               c(3769, 56, 0))
  # The note and fly#91: each out-of-band roll-height is a right height beside a wrong scale —
  # spacing fits the reported height and rejects nominal — and only bci9 sits where the fly#60 /
  # fly#72 strata reach (ratio above sea level <= 0.5, or 2 to 3).
  ob <- fr[cls == "outside_band", ]
  rnd <- window_frames()
  window <- unname(stats::quantile(overlap(rnd$base, formats[["in9"]] * rnd$side),
                                   c(.025, .975), na.rm = TRUE))
  by <- split(ob, ob$film_roll)
  expect_equal(lengths(lapply(by, `[[`, "airp_id")), c(bc5312 = 17, bci12 = 14, bci9 = 25))
  for (g in by) {
    expect_length(unique(paste(g$scale_n, g$flying_height, g$focal_length)), 1)
    p_nom <- stats::median(overlap(g$base, formats[["in9"]] * g$scale_n))
    p_rep <- stats::median(overlap(g$base, formats[["in9"]] *
                                     (g$flying_height - g$elev) / (g$focal_length / 1000)))
    expect_true(p_rep >= window[1] && p_rep <= window[2])
    expect_false(p_nom >= window[1] && p_nom <= window[2])
  }
  ratio_asl <- vapply(by, function(g) g$flying_height[1] / (g$scale_n[1] * g$focal_length[1] / 1000),
                      numeric(1))
  stratum <- ratio_asl <= 0.5 | (ratio_asl > 2 & ratio_asl <= 3)
  expect_equal(names(ratio_asl)[stratum], "bci9")
})

test_that("every thumbnail-bearing roll looks like a 9-inch film frame", {
  th <- extdata("infrared_film_thumbnails.csv")
  ref <- extdata("mask_border_sweep.csv")
  ref <- ref[ref$threshold == fly_mask_threshold(), ]
  asp_ref <- pmax(ref$nc, ref$nr) / pmin(ref$nc, ref$nr)
  ref <- ref[asp_ref < 1.5, ]
  aspect_max <- max(pmax(ref$nc, ref$nr) / pmin(ref$nc, ref$nr))
  collar_max <- max(ref$frac_total)
  expect_equal(nrow(ref), 254)
  ok <- th[th$masked, ]
  w2 <- vapply(split(ok, ok$film_roll), function(d) {
    a <- stats::median(pmax(d$nc, d$nr) / pmin(d$nc, d$nr))
    c <- stats::median(d$mask_fraction)
    if (a <= aspect_max && c <= collar_max) "pass" else "contradicts"
  }, character(1))
  shipped <- extdata("infrared_film_rolls.csv")
  expect_equal(unname(w2), shipped$w2[match(names(w2), shipped$film_roll)])
  expect_setequal(names(w2), c("bc5312", "bc5367", "bcc23", "bcf07060"))
  expect_true(all(w2 == "pass"))
  expect_equal(sum(!th$masked), 0)
})

test_that("no logbook page names a camera of another format", {
  pg <- extdata("infrared_film_pages.csv")
  expect_true(all(pg$camera_format %in%
                    c("23cm", "other_format", "unrecognised", "not_stated", "illegible")))
  expect_false(any(pg$camera_format == "other_format"))
  w3 <- vapply(split(pg, pg$film_roll), function(p) {
    if (any(p$camera_format == "other_format")) "contradicts"
    else if (any(p$camera_format == "23cm")) "pass"
    else if (any(p$camera_format == "unrecognised")) "unrecognised" else "not_stated"
  }, character(1))
  shipped <- extdata("infrared_film_rolls.csv")
  expect_equal(unname(w3), shipped$w3[match(names(w3), shipped$film_roll)])
  expect_equal(sort(names(w3)[w3 == "pass"]),
               c("bc5312", "bc5367", "bcc23", "bcc7", "bcc8", "bcf335"))
  # A page whose class is 23cm says so in writing: a format, or a camera model that is one.
  pass <- pg[pg$camera_format == "23cm", ]
  expect_true(all(grepl("9", pass$format_as_written) | grepl("RC ?10", pass$camera_as_written)))
  # Every unrecognised page names a camera body that also flew BW/colour rolls sized at 9 in.
  unrec <- pg[pg$camera_format == "unrecognised", ]
  expect_true(all(!is.na(unrec$same_camera_bw_colour) & nzchar(unrec$same_camera_bw_colour)))
})

test_that("fly_film_media() carries exactly the IR media the measurement admits", {
  s <- extdata("infrared_film_rolls.csv")
  admit <- vapply(ir_media, function(m) {
    d <- s[s$media == m, ]
    nrow(d) > 0 && any(d$w1 == "pass") && !any(d$w1 == "contradicts") &&
      !any(d$w2 == "contradicts") && !any(d$w3 == "contradicts")
  }, logical(1))
  expect_true(all(admit))
  expect_setequal(intersect(fly_film_media(), ir_media), ir_media[admit])
})
