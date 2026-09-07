# Resolving a frame's format from the camera its PAT-B file names (fly#50).
#
# Every identity used here is one the province actually publishes, taken from the
# archives measured in `planning/archive/.../findings.md`:
#
#   20814295  ccre_lens_number, d_001_fi_15_georef.txt   14,717 frames
#   22814295  cam_s_no,         d_005_emn_19_georef.csv
#   121201    ccre_lens_number, d_003_fi_13_georef.txt
#   10519431  ccre_lens_number, d_001_fi_16_georef.txt    1,790 frames, unknown body
#   100044    lens_no,          d_004_fi_11_georef.csv   11,826 frames, unknown body
#   "Vexcel Ultracam XP" / "Vexcel Ultracam X"  camera,   d_00{1,2}_fi_12_georef.csv

patb_fixture <- function(serial = NA_character_, camera = NA_character_,
                         gsd = 30, focal = 100, media = "Digital - Colour",
                         calib = NA_character_) {
  n <- max(length(serial), length(camera))
  rep_n <- function(x) if (length(x) == n) x else rep(x, length.out = n)
  sf::st_sf(
    airp_id = seq_len(n),
    scale = "1:20000",
    media = rep_n(media),
    focal_length = rep_n(focal),
    ground_sample_distance = rep_n(gsd),
    camera_calibration_url = rep_n(calib),
    camera_serial = rep_n(serial),
    camera_name = rep_n(camera),
    geometry = sf::st_sfc(
      lapply(seq_len(n), function(i) sf::st_point(c(-126 + i / 100, 54))), crs = 4326
    )
  )
}


test_that("a serial the province publishes resolves to the camera that flew the frame", {
  got <- fly_camera_format(patb_fixture(serial = c("20814295", "22814295", "121201")))

  expect_true(all(got$resolved))
  expect_false(any(got$inferred))
  expect_equal(got$camera, c("UltraCam Eagle", "UltraCam Eagle M3", "DMC II"))
  expect_equal(got$px_cross, c(20010, 26460, 15552))
  expect_true(all(grepl("^patb_serial=", got$width_source)))
})


test_that("20814295 resolves rather than colliding with the body filed under its key", {
  # The measurement behind the two-pass index. `20814295` reaches five calibration rows:
  # four UltraCam Eagles, plus the 2018 row the catalogue FILES under 20814295 while the
  # camera's own report numbers it 22814295 at a different format. A single union index
  # calls that ambiguous and refuses all 14,717 frames of the 2015 project that publish
  # this serial.
  tbl <- fly_camera_table()
  calib <- tbl[tbl$key_type == "calib_file", ]
  expect_gt(sum(grepl("20814295", calib$key)), 1L)                    # premise: it collides
  expect_gt(length(unique(calib$px_cross[grepl("20814295", calib$key)])), 1L)

  got <- fly_camera_format(patb_fixture(serial = "20814295"))
  expect_true(got$resolved)
  expect_equal(got$px_cross, 20010)
})


test_that("a camera name resolves only where the archive carries no serial", {
  # `lens_no` is 0 in both 2012 archives, which is how they spell "not recorded" — so the
  # model string is the only identity those 7,649 frames have.
  # Focal 53 throughout, so the focal-length fallback cannot resolve the third row and
  # the only thing that separates these frames is the model string.
  got <- fly_camera_format(patb_fixture(
    serial = c("0", "0", NA), camera = c("Vexcel Ultracam XP", "Vexcel Ultracam X", NA),
    focal = 53
  ))

  expect_equal(got$resolved, c(TRUE, TRUE, FALSE))
  expect_equal(got$px_cross[1:2], c(17310, 14430))
  expect_true(all(grepl("^patb_camera=", got$width_source[1:2])))
})


test_that("a serial that is present but unknown refuses instead of reading the name", {
  # The measured hazard, not a hypothetical one. `d_001_fi_16_georef.txt` labels BOTH its
  # cameras `UltraCam XP`, and one of them is serial 70912643 — `UC-SX-1-70912643`, an
  # UltraCam X at 14430 px against the Xp's 17310. Reading the name when the serial fails
  # would size that project's frames 20% wide, and the name is wrong in the file itself.
  # Focal 53 has no fallback row, so nothing else can resolve these and the refusal is
  # the whole answer. The interaction with the fallback is a separate test below.
  got <- fly_camera_format(patb_fixture(
    serial = c("10519431", "100044"), camera = c("UltraCam XP", "DMC1"), focal = 53
  ))

  expect_false(any(got$resolved))
  expect_true(all(is.na(got$width_mm)))
  expect_equal(got$width_source,
               c("unknown_serial:10519431", "unknown_serial:100044"))
})


test_that("an unrecognised camera name refuses rather than matching on a prefix", {
  # `DMC II 230` is what the catalogue's own PAT-B publishes and `DMC II` is what the
  # table ships. A prefix match would also size a DMC II 250 (17216 x 14656) and a
  # DMC II 140 (12096 x 11200) from the 230's row, silently and with inferred = FALSE.
  got <- fly_camera_format(patb_fixture(
    serial = NA, camera = c("DMC II 230", "DMC II 250", "DMC1", "Ultracm Eagle"),
    focal = 53
  ))

  expect_false(any(got$resolved))
  expect_true(all(startsWith(got$width_source, "unknown_camera:")))
})


test_that("a withheld calibration still cannot fall through, now that a second route exists", {
  # `matched` already carries the withheld refusals, and the PAT-B route gates on it. A
  # freshly computed "not yet resolved" predicate would reopen the hole, because a
  # withheld row IS unresolved by construction. `10210206_2015` is withheld with the
  # reason "visually read as UltraCam Eagle" — exactly the identity its PAT-B would name.
  ex <- fly_camera_excluded()
  withheld <- ex$key[ex$key_type == "calib_file"][1]
  expect_true(!is.na(withheld))                                        # premise

  got <- fly_camera_format(patb_fixture(
    serial = "20814295", camera = "Vexcel Ultracam XP",
    calib = paste0("https://openmaps.gov.bc.ca/thumbs/calib_report_zips/", withheld, ".zip")
  ))

  expect_false(got$resolved)
  expect_true(is.na(got$width_mm))
  expect_true(startsWith(got$width_source, "withheld:"))
})


test_that("a calibration URL beats a PAT-B identity that disagrees with it", {
  # The calibration is exact — the report gives the array size and the pitch, and the
  # millimetres are checked against them. A PAT-B camera identity is one step removed.
  got <- fly_camera_format(patb_fixture(
    serial = "121201", camera = "DMC II",
    calib = "https://openmaps.gov.bc.ca/thumbs/calib_report_zips/20814295_2018.zip"
  ))

  expect_true(got$resolved)
  expect_equal(got$px_cross, 26460)                    # the calibration, not the serial
  expect_equal(got$width_source, "20814295_2018")
})


test_that("a PAT-B identity on a film frame is ignored", {
  # This table describes sensors. Film is sized from `negative_size`, and a serial column
  # carried across from a digital batch must not reach it.
  got <- fly_camera_format(patb_fixture(
    serial = "20814295", camera = "Vexcel Ultracam XP", media = "Film - BW"
  ))

  expect_false(got$resolved)
  expect_true(is.na(got$width_mm))
  expect_true(is.na(got$width_source))
})


test_that("an ambiguous serial refuses rather than picking a format", {
  # Vacuous against the shipped table — no token there reaches two rows that disagree,
  # which is the point of the two-pass index. So the guard is exercised against an
  # injected table. Mock the reader rather than poking `fly_camera_cache`: that is a
  # namespace environment and a poked entry outlives the test.
  fake <- data.frame(
    key = c("aaa111111_2020", "bbb111111_2021"), key_type = "calib_file",
    camera = c("Cam A", "Cam B"),
    report_serial = c("UC-A-1-111111", "UC-B-1-111111"),
    width_mm = c(100, 50), height_mm = c(60, 30),
    px_cross = c(20000, 10000), px_along = c(12000, 6000),
    stringsAsFactors = FALSE
  )
  testthat::local_mocked_bindings(fly_camera_table = function() fake, .package = "fly")

  got <- fly_camera_format(patb_fixture(serial = "111111"))
  expect_false(got$resolved)
  expect_true(is.na(got$width_mm))
  expect_equal(got$width_source, "ambiguous_serial:111111")

  # And the same token resolves when the two rows agree — so the refusal is about the
  # disagreement, not about the token reaching two rows.
  fake$px_cross <- c(20000, 20000)
  fake$px_along <- c(12000, 12000)
  fake$width_mm <- c(100, 100)
  fake$height_mm <- c(60, 60)
  testthat::local_mocked_bindings(fly_camera_table = function() fake, .package = "fly")
  expect_true(fly_camera_format(patb_fixture(serial = "111111"))$resolved)
})


test_that("a PAT-B refusal does not block the focal-length fallback, and is still reported", {
  # An unrecognised serial says nothing about sensor size, unlike a withheld calibration
  # which says the sensor is medium-format. So the inference stays available — removing it
  # would cost 13,616 measured frames the DEM footprint they get today — and the refusal
  # travels alongside it rather than being overwritten.
  got <- fly_camera_format(patb_fixture(serial = "10519431", focal = 100))

  expect_true(got$resolved)
  expect_true(got$inferred)
  expect_equal(got$width_source, "focal_length=100; unknown_serial:10519431")
})


test_that("every refusal reaches the caller through fly_footprint()", {
  # `fly_camera_format()` computing a refusal is not the same as a caller seeing it.
  # `fly_footprint()` copies `width_source` for rows it sized and, separately, for rows
  # the table declined — and that second copy used to test one prefix by name, so a new
  # refusal tag would have been computed here and dropped on the way out.
  ex <- fly_camera_excluded()
  withheld <- ex$key[ex$key_type == "calib_file"][1]
  photos <- patb_fixture(
    serial = c("10519431", NA, NA), camera = c(NA, "DMC II 250", NA),
    focal = c(53, 53, 53),
    calib = c(NA, NA,
              paste0("https://openmaps.gov.bc.ca/thumbs/calib_report_zips/", withheld, ".zip"))
  )
  fp <- suppressWarnings(fly_footprint(photos))

  expect_equal(fp$width_source,
               c("unknown_serial:10519431", "unknown_camera:DMC II 250",
                 paste0("withheld:", withheld)))
  expect_true(all(sf::st_is_empty(sf::st_geometry(fp))))
})


test_that("patb_gsd sizes a frame only where the catalogue has no GSD of its own", {
  # Measured: `GROUND_SAMPLE_DISTANCE` is 0 on all 24,742 digital frames of 2011-2012, so
  # the camera alone does not make them sizeable. Where the catalogue DOES carry a value
  # it is used, so a footprint never depends on whether the caller ran `fly_camera_patb()`.
  photos <- patb_fixture(serial = rep("20814295", 3), gsd = c(0, NA, 25))
  photos$patb_gsd <- c(30, 30, 30)
  fp <- fly_footprint(photos)

  bb <- vapply(sf::st_geometry(sf::st_transform(fp, 3005)), function(g) {
    b <- sf::st_bbox(g)
    unname(b["xmax"] - b["xmin"])
  }, numeric(1))
  # 20010 px x 0.30, 0.30, 0.25 m. Tolerance because the ring is built in 3005 from a
  # 4326 centroid, so the reprojection moves the width by about a metre.
  expect_equal(bb, c(6003, 6003, 5002.5), tolerance = 1e-3)
  expect_equal(grepl("gsd=patb", fp$width_source), c(TRUE, TRUE, FALSE))
})


test_that("the PAT-B columns keep their types on zero-row input", {
  # `ifelse(logical(0), ...)` returns `logical(0)`, so an empty batch can silently report
  # a character column as logical and then fail to bind to a populated result.
  got <- fly_camera_format(patb_fixture(serial = "20814295")[0, ])

  expect_equal(nrow(got), 0L)
  expect_type(got$width_source, "character")
  expect_type(got$camera, "character")
  expect_type(got$resolved, "logical")
})


test_that("a serial with two equal-length digit runs refuses rather than picking one", {
  # `fly_serial_tokens()` keeps ties on purpose, and reading only the first would pick by
  # position in text the province writes: `100039-327542` and `327542-100039` are the same
  # identity and reach a 13824 px DMC and a 25728 px DMC III respectively. The shipped
  # table has no ties, so only an input like this can reach the guard.
  got <- fly_camera_format(patb_fixture(
    serial = c("100039-327542", "327542-100039"), focal = 53
  ))

  expect_false(any(got$resolved))
  expect_true(all(startsWith(got$width_source, "ambiguous_serial:")))

  # And a tie whose tokens AGREE still resolves — the refusal is about the disagreement,
  # not about there being two runs.
  agreeing <- fly_camera_format(patb_fixture(serial = "20814295-20814295", focal = 53))
  expect_true(agreeing$resolved)
  expect_equal(agreeing$px_cross, 20010)
})
