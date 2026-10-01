# Photo parallax as a witness of the surface the camera saw (fly#82).
#
# `data-raw/dem_measure-photo_parallax.R` built an instrument that reads, from two adjacent
# thumbnails, how much of MRDEM's canopy the camera saw at the photo date. It failed its
# synthetic controls, and under the rule fixed before any frame was measured no sampled pair
# was measured. What shipped is the controls. This file recomputes their verdicts from the
# shipped rows and rebuilds the tables and figures of `inst/notes/terrain-correction.md`,
# "What the photos can say about the photo date (fly#82)".
#
# Not asserted, because no shipped table carries them: the pilot's DTM slopes on roll bc5282
# (0.95-1.13), the y-parallax robust SD (0.16-1.01 px), the JPEG quality, the x1.7 centroid
# spacing, the ~900 m registration offsets, the 0.703 snow frame, the 124-against-3 class
# counts, the 2 young patches in 11 pairs, and fly#80's 15.1%. Each is a producer line in the
# archived planning findings or in fly#80's own tables.

parallax_synthetic <- function() {
  p <- system.file("extdata", "dem_parallax_synthetic.csv", package = "fly")
  if (p == "") return(NULL)
  utils::read.csv(p, stringsAsFactors = FALSE)
}

parallax_section <- function() {
  np <- system.file("notes/terrain-correction.md", package = "fly")
  if (np == "") return(NULL)
  md <- readLines(np, warn = FALSE)
  start <- grep("^## What the photos can say about the photo date", md)
  if (!length(start)) return(NULL)
  h2 <- grep("^## ", md)
  md[seq(start, min(h2[h2 > start]) - 1)]
}

# The rule's verdict 1, recomputed from the rows (Amendments B 5 and C).
synthetic_verdict <- function(s) {
  refused <- grepl("^gated", s$status) | s$status %in% c("no_global", "no_registration", "no_dem")
  pass <- rep(NA, nrow(s))
  pl <- s$set == "plain" & s$displaced_m == 0 & !refused
  pass[pl] <- ifelse(s$status[pl] != "ok" | !is.finite(s$slope[pl]), FALSE,
                     ifelse(s$kappa[pl] == 0, abs(s$slope[pl]) <= 0.10,
                            abs(s$slope[pl] - 1) <= 0.25))
  qual <- s$set == "class_pooled" & s$n_mid >= 30 & s$n_old >= 30
  pass[qual] <- is.finite(s$phi[qual]) & is.finite(s$phi_vri[qual]) &
    abs(s$phi[qual] - s$phi_vri[qual]) <= 0.10
  pu <- s$set == "plain" & s$displaced_m == 0
  cases <- factor(s$case[pu], levels = c("flat_C0", "flat_C1", "dtm_C0", "dtm_C1"))
  plain_ok <- all(vapply(split(pass[pu], cases),
                         function(z) sum(z %in% TRUE) >= 2 && !any(z %in% FALSE), logical(1)))
  class_ok <- all(vapply(c(0, 150), function(off) {
    z <- pass[qual & s$displaced_m == off]
    length(z) >= 1 && all(z)
  }, logical(1)))
  list(pass = pass, plain_ok = plain_ok, class_ok = class_ok, ok = plain_ok && class_ok)
}

test_that("the shipped pass flags are the rule's, and the rule stops the study", {
  s <- parallax_synthetic()
  skip_if(is.null(s), "the parallax measurement is not installed")
  v <- synthetic_verdict(s)
  expect_identical(v$pass, as.logical(s$pass))
  # Every plain case passes on all three frames; the pooled class test fails in both sources
  # and both pools, so verdict 1 stops the study before any sampled pair.
  expect_true(v$plain_ok)
  expect_false(v$class_ok)
  expect_false(v$ok)
  cp <- s[s$set == "class_pooled", ]
  expect_identical(nrow(cp), 4L)
  expect_true(all(cp$n_mid >= 30 & cp$n_old >= 30))
  expect_true(all(!as.logical(cp$pass)))
})

test_that("the verdict logic fails a case whose every frame is refused", {
  # Restore-the-bug check for code-check round 5: splitting only the admitted rows let a case
  # with every frame refused vanish into all(logical(0)), which is TRUE.
  s <- parallax_synthetic()
  skip_if(is.null(s), "the parallax measurement is not installed")
  pl <- s$set == "plain" & s$displaced_m == 0 & s$case == "dtm_C1"
  s$status[pl] <- "gated_registration_bound"
  expect_false(synthetic_verdict(s)$plain_ok)
  # And one refused frame among passing ones still passes.
  s <- parallax_synthetic()
  s$status[which(pl)[1]] <- "gated_model_r2"
  expect_true(synthetic_verdict(s)$plain_ok)
})

test_that("every table in the note's fly#82 section is rebuilt from the shipped rows", {
  s <- parallax_synthetic()
  skip_if(is.null(s), "the parallax measurement is not installed")
  sec <- parallax_section()
  skip_if(is.null(sec), "the terrain note is not installed")
  # Two tables and 12 table lines (2 headers, 2 separators, 4 plain rows, 4 pooled rows). A
  # table or row added fails here until it is rebuilt.
  expect_identical(sum(grepl("^\\|[- |]+\\|$", sec)), 2L)
  expect_identical(sum(startsWith(sec, "|")), 12L)

  sg <- function(x) sub("^-", "−", sprintf("%+.3f", x))
  pl <- s[s$set == "plain" & s$displaced_m == 0, ]
  lab <- c(flat_C0 = "flat ground, κ = 0", flat_C1 = "flat ground, κ = 1",
           dtm_C0 = "terrain, κ = 0", dtm_C1 = "terrain, κ = 1")
  rows <- vapply(names(lab), function(k) {
    z <- pl[pl$case == k, ]
    sprintf("| %s | %d of %d | %s to %s |", lab[[k]], sum(as.logical(z$pass) %in% TRUE), nrow(z),
            sg(min(z$slope)), sg(max(z$slope)))
  }, character(1))
  cp <- s[s$set == "class_pooled", ]
  rows <- c(rows, vapply(seq_len(nrow(cp)), function(i) {
    sprintf("| %s | %s | %.3f | %.3f | %d / %d |",
            c(source_r = "radar", source_l = "lidar")[[cp$case[i]]],
            if (cp$displaced_m[i] == 0) "no" else "150 m", cp$phi[i], cp$phi_vri[i],
            cp$n_mid[i], cp$n_old[i])
  }, character(1)))
  for (r in rows) expect_true(r %in% sec, info = r)

  # Prose figures with a shipped producer.
  txt <- gsub("\\s+", " ", paste(sec, collapse = " "))
  k1 <- pl$slope[pl$kappa == 1]
  expect_match(txt, sprintf("read between %.3f and %.3f at true placement", min(k1), max(k1)),
               fixed = TRUE)
  disp <- s$slope[s$set == "plain" & s$displaced_m > 0 & s$kappa == 1 & s$status == "ok"]
  expect_match(txt, sprintf("canopy slope fell to %.3f", min(disp)), fixed = TRUE)
  expect_identical(length(unique(s$film_roll[s$set == "class"])), 11L)
  expect_match(txt, "on the eleven pilot frames", fixed = TRUE)
  admitted <- unique(cp$film_roll)
  expect_identical(admitted, "7 frames")
  expect_match(txt, "pooled over the seven the gates admitted", fixed = TRUE)
})

test_that("the versions the controls were run against are recorded", {
  p <- system.file("extdata", "dem_parallax_versions.csv", package = "fly")
  skip_if(p == "", "the parallax measurement is not installed")
  v <- utils::read.csv(p, stringsAsFactors = FALSE)
  expect_setequal(v$asset, c("dtm", "dsm", "source", "census", "algorithm"))
  expect_true(all(nzchar(v$etag)))
})
