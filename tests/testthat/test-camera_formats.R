test_that("the shipped camera format table is structurally sound", {
  tbl <- fly_camera_table()

  expect_gt(nrow(tbl), 0)
  expect_equal(anyDuplicated(tbl$key), 0L)
  expect_true(all(tbl$key_type %in% c("calib_file", "focal_length")))
  expect_true(all(nzchar(tbl$key)))

  # Every calibration row must name the PDF it came from. Provenance is the point of
  # the artifact — a row whose source cannot be reopened cannot be re-checked.
  calib <- tbl[tbl$key_type == "calib_file", ]
  expect_true(all(!is.na(calib$source_pdf) & nzchar(calib$source_pdf)))
  expect_true(all(!is.na(calib$camera) & nzchar(calib$camera)))
  expect_true(all(!is.na(tbl$retrieved)))
})


test_that("check B: pixel count times pitch reproduces the stated image size", {
  # The strongest guard on the transcription, and only on the rows where it is real:
  # `mm_stated` is FALSE where the report gave array size and pitch but no millimetres,
  # so `width_mm` there IS `px * pitch` and comparing them tests arithmetic against
  # itself. Skipping those is the difference between a check and a vacuous pass.
  tbl <- fly_camera_table()
  b <- tbl[!is.na(tbl$mm_stated) & tbl$mm_stated, ]

  # Assert the premise, so a future table that loses its constrainable rows fails here
  # naming the real cause rather than passing on an empty set.
  expect_gt(nrow(b), 10)

  expect_lt(max(abs(b$px_cross * b$pitch_um / 1000 - b$width_mm) / b$width_mm), 1e-6)
  expect_lt(max(abs(b$px_along * b$pitch_um / 1000 - b$height_mm) / b$height_mm), 1e-6)
})


test_that("check D: every shipped format is physically plausible", {
  # Catches a unit slip (m / mm / um), which is the error class that survives check B by
  # being internally self-consistent. The reports write the micron sign three different
  # ways and one drops it altogether, so this is not hypothetical.
  tbl <- fly_camera_table()

  # 30-200 mm, matching the generator. Deliberately wider than the 87-166 mm the
  # shipped large-format cameras occupy: the catalogue also holds medium-format bodies
  # about 53 mm wide, and a bound that rejects valid data is worse than the unit slip it
  # guards against. This range still separates a micrometre read as a millimetre (~5 mm)
  # from a real sensor.
  expect_true(all(tbl$width_mm > 30 & tbl$width_mm < 200))
  expect_true(all(tbl$height_mm > 20 & tbl$height_mm < 150))
  aspect <- tbl$width_mm / tbl$height_mm
  expect_true(all(aspect >= 1 & aspect <= 2))

  pitch <- tbl$pitch_um[!is.na(tbl$pitch_um)]
  expect_true(all(pitch > 3 & pitch < 13))
})


test_that("fallback rows carry no pixel count, so they cannot take the GSD route", {
  # At a given catalogue focal length, sensor WIDTH spreads 1-3% but PIXEL COUNT spreads
  # 32-83%. A focal-keyed frame can therefore be sized by width x AGL/focal and never by
  # px x GSD. Withholding the pixel counts is what enforces that, rather than a comment
  # asking the resolver to remember.
  tbl <- fly_camera_table()
  fb <- tbl[tbl$key_type == "focal_length", ]

  expect_gt(nrow(fb), 0)
  expect_true(all(is.na(fb$px_cross)))
  expect_true(all(is.na(fb$px_along)))
  expect_true(all(!is.na(fb$width_mm) & !is.na(fb$height_mm)))
  # Each records how much room for error it carries. Spread is required only on rows
  # inferred from cameras at the SAME focal length — an extrapolated row has no
  # meaningful spread and says so with NA, asserted separately below.
  expect_true(all(!is.na(fb$n_cameras)))
  expect_true(all(!is.na(fb$width_spread_pct[!fb$extrapolated])))
  expect_true(all(!is.na(fb$note) & nzchar(fb$note)))
})


test_that("every calibration the catalogue offers is dispositioned, with a reason", {
  # The drift guard. `camera_formats_manifest.csv` records the keys the catalogue
  # actually offered when the table was built, written independently of the two
  # dispositions — so a key hand-edited out of either file, or a new camera added to
  # the manifest without being dispositioned, fails here rather than silently becoming
  # an unresolvable frame.
  manifest <- utils::read.csv(
    system.file("extdata", "camera_formats_manifest.csv", package = "fly"),
    stringsAsFactors = FALSE
  )
  excluded <- fly_camera_excluded()
  # The excluded file also records focal lengths deliberately left without a fallback
  # row, which are not calibrations and so are not in the manifest. Compare like with
  # like rather than pooling them — a pooled comparison passes for exactly the drift
  # the guard exists to catch.
  excluded_calib <- excluded$key[excluded$key_type == "calib_file"]
  shipped <- fly_camera_table()
  shipped <- shipped$key[shipped$key_type == "calib_file"]

  expect_gt(nrow(manifest), 0)
  expect_setequal(manifest$key, c(shipped, excluded_calib))
  expect_equal(length(intersect(shipped, excluded_calib)), 0L)

  # An excluded entry without a reason is a backlog note pretending to be a decision.
  expect_true(all(!is.na(excluded$reason) & nzchar(excluded$reason)))
  expect_true(all(excluded$key_type %in% c("calib_file", "focal_length")))
})


test_that("the drift guard fires on an undeclared calibration", {
  # A guard nobody has seen fail is decoration. Feed it a key that is in the manifest
  # and in neither disposition, and confirm it is reported.
  manifest <- utils::read.csv(
    system.file("extdata", "camera_formats_manifest.csv", package = "fly"),
    stringsAsFactors = FALSE
  )
  shipped <- fly_camera_table()
  shipped <- shipped$key[shipped$key_type == "calib_file"]
  ex <- fly_camera_excluded()
  excluded <- ex$key[ex$key_type == "calib_file"]

  undeclared <- c(manifest$key, "ultracam999_2031")
  expect_false(setequal(undeclared, c(shipped, excluded)))
  expect_equal(setdiff(undeclared, c(shipped, excluded)), "ultracam999_2031")
})


test_that("an extrapolated fallback row does not claim zero spread", {
  # `width_spread_pct` measures dispersion among the SOURCE cameras, so a single-source
  # row is structurally 0 however wrong the inference. Reporting 0 would give the
  # least-supported rows in the file the most confident label. An extrapolated row
  # reports NA — unknown, which is the truth.
  tbl <- fly_camera_table()
  ex <- tbl[!is.na(tbl$extrapolated) & tbl$extrapolated, ]

  expect_gt(nrow(ex), 0)                      # premise: something is extrapolated
  expect_true(all(is.na(ex$width_spread_pct)))
  # And it must say why, at length — an extrapolation is the one row type whose
  # warrant cannot be read off the numbers.
  expect_true(all(nchar(ex$note) > 40))
})


test_that("a withheld calibration cannot fall through to focal-length inference", {
  # The two withheld medium-format cameras are ~53 mm wide against the ~104 mm bodies
  # sharing their focal neighbourhood, so inferring one would be 1.95x too wide. Today
  # they return NA because no fallback row happens to exist at focal 53 or 83 — safety
  # by coincidence. This pairs each withheld key with focal 100, which DOES have a
  # fallback row, so only the refusal itself can stop the fall-through.
  ex <- fly_camera_excluded()
  withheld <- ex$key[ex$key_type == "calib_file"]
  expect_gt(length(withheld), 0)

  tbl <- fly_camera_table()
  expect_true("100" %in% tbl$key[tbl$key_type == "focal_length"])   # premise

  photos <- sf::st_sf(
    media = rep("Digital - Colour", length(withheld)),
    focal_length = rep(100, length(withheld)),
    camera_calibration_url = paste0(
      "https://openmaps.gov.bc.ca/thumbs/calib_report_zips/", withheld, ".zip"
    ),
    geometry = sf::st_sfc(
      lapply(seq_along(withheld), function(i) sf::st_point(c(-126, 54))), crs = 4326
    )
  )
  got <- fly_camera_format(photos)

  expect_true(all(!got$resolved))
  expect_true(all(is.na(got$width_mm)))
  expect_true(all(grepl("^withheld:", got$width_source)))
})


test_that("resolved and inferred are distinct, so !inferred is a safe filter", {
  # A row that resolved to nothing is also `inferred = FALSE`, so without `resolved` the
  # natural "give me the trustworthy rows" filter sweeps up every unresolved frame.
  photos <- digital_fixture()
  got <- fly_camera_format(photos)

  expect_true(all(got$resolved[1:5]))
  expect_false(got$inferred[1])      # exact calibration
  expect_true(got$inferred[5])       # focal-length fallback
  expect_true(all(!is.na(got$width_mm[got$resolved])))
})
