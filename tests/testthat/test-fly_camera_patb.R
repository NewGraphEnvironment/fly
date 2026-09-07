# Reading a camera identity out of the province's PAT-B georeferencing files (fly#50).
#
# Everything here runs offline against `inst/testdata/patb/`, which holds trimmed copies
# of the real published archives — one per schema, plus the verbatim 404 body two of the
# seven live archives return. Trimmed, not synthesised: a hand-built fixture agrees with
# whatever the parser expects, and would not carry `Ultracm Eagle` or `DMC II 230`.

patb_cache <- function() {
  # Copied out of the installed package rather than used in place: `fly_camera_patb()`
  # creates `dest_dir` and would write into the library otherwise.
  d <- withr::local_tempdir(.local_envir = parent.frame())
  file.copy(list.files(testdata_path("patb"), full.names = TRUE), d)
  d
}

patb_centroids <- function() {
  sf::st_read(testdata_path("photo_centroids_digital.gpkg"), quiet = TRUE)
}


test_that("both bundled archives resolve every frame they cover", {
  got <- fly_camera_patb(patb_centroids(), dest_dir = patb_cache(), quiet = TRUE)

  expect_equal(nrow(got), 24L)
  expect_true(all(!is.na(got$camera_serial)))
  expect_setequal(unique(got$camera_serial), c("121201", "22814295"))
  expect_setequal(unique(got$patb_source),
                  c("d_003_fi_13_georef.zip", "d_005_emn_19_georef.zip"))
})


test_that("the serial route and the calibration route agree, over two cameras and two schemas", {
  # The decisive check, and it needs no network and no new numbers. Every bundled digital
  # frame carries BOTH a `camera_calibration_url` and a PAT-B identity, and the two are
  # independent: one is a report the province links per frame, the other a serial written
  # into a georeferencing file by a different process. They must land on the same sensor.
  #
  # This is what fails loudly on any indexing error — a pooled serial index, a key token
  # left carrying its `_YYYY` suffix, a token concatenated instead of split — because
  # `22814295` is exactly the case where the catalogue's key and the camera's own serial
  # disagree.
  photos <- fly_camera_patb(patb_centroids(), dest_dir = patb_cache(), quiet = TRUE)
  by_calibration <- fly_camera_format(photos)

  # Same frames, with the calibration hidden so only the PAT-B identity can answer.
  no_calib <- photos
  no_calib$camera_calibration_url <- NA_character_
  by_patb <- fly_camera_format(no_calib)

  expect_true(all(by_calibration$resolved))                       # premise: both routes ran
  expect_true(all(by_patb$resolved))
  expect_equal(by_patb$px_cross, by_calibration$px_cross)
  expect_equal(by_patb$px_along, by_calibration$px_along)
  expect_equal(by_patb$width_mm, by_calibration$width_mm)
  expect_true(all(grepl("^patb_serial=", by_patb$width_source)))
  expect_false(any(by_patb$inferred))
})


test_that("a bare-CSV archive resolves by camera name and carries the GSD", {
  # The 2012 schema and the reason `patb_gsd` exists: `lens_no` is 0 on every row, so the
  # model string is the only identity, and the catalogue's own `ground_sample_distance`
  # is 0 on all 7,649 frames of that year while the file says 30.
  d <- utils::read.csv(testdata_path("patb", "d_001_fi_12_georef.csv"),
                       stringsAsFactors = FALSE)
  photos <- sf::st_sf(
    airp_id = d$airp_id,
    film_roll = sub("_[^_]*$", "", d$roll_frame),
    frame_number = as.integer(sub(".*_", "", d$roll_frame)),
    media = "Digital - Colour", scale = "1:20000", focal_length = 100,
    ground_sample_distance = 0,
    patb_georef_url = "https://openmaps.gov.bc.ca/thumbs/patb_files/d_001_fi_12_georef.csv",
    geometry = sf::st_sfc(
      lapply(seq_len(nrow(d)), function(i) sf::st_point(c(-126 + i / 100, 54))), crs = 4326
    )
  )

  got <- fly_camera_patb(photos, dest_dir = patb_cache(), quiet = TRUE)
  expect_equal(unique(got$camera_name), "Vexcel Ultracam XP")
  expect_equal(unique(got$camera_serial), "0")
  expect_equal(unique(got$patb_gsd), 30)

  fmt <- fly_camera_format(got)
  expect_true(all(fmt$resolved))
  expect_equal(unique(fmt$px_cross), 17310)
  expect_true(all(startsWith(fmt$width_source, "patb_camera=")))

  # And the footprint the whole issue is about: 17310 px x 0.30 m, from a frame the
  # catalogue gives no usable GSD for and no calibration report.
  # Measured on the ring's own edges, not on its bounding box: these frames sit on a
  # flight line so the footprint is rotated onto it, and a bbox extent then reports the
  # along-track side where the cross-track one was meant.
  fp <- fly_footprint(got)
  sides <- lapply(sf::st_geometry(sf::st_transform(fp, 3005)), function(g) {
    xy <- sf::st_coordinates(g)[1:5, 1:2]
    sort(round(sqrt(rowSums((xy[2:5, ] - xy[1:4, ])^2))))[c(1, 4)]
  })
  # 17310 x 0.30 and 11310 x 0.30
  expect_equal(unique(vapply(sides, function(s) s[2], numeric(1))), 5193)
  expect_equal(unique(vapply(sides, function(s) s[1], numeric(1))), 3393)
  expect_true(all(grepl("gsd=patb", fp$width_source)))
})


test_that("the same archive joins identically by airp_id and by roll and frame", {
  # The bare schema is the only one carrying both keys. They agreed on all 19,475 rows
  # measured live; asserting it here means a future schema change cannot quietly make one
  # of the two wrong while the other keeps the tests green.
  d <- utils::read.csv(testdata_path("patb", "d_001_fi_12_georef.csv"),
                       stringsAsFactors = FALSE)
  base <- sf::st_sf(
    airp_id = d$airp_id,
    film_roll = sub("_[^_]*$", "", d$roll_frame),
    frame_number = as.integer(sub(".*_", "", d$roll_frame)),
    patb_georef_url = "https://openmaps.gov.bc.ca/thumbs/patb_files/d_001_fi_12_georef.csv",
    geometry = sf::st_sfc(
      lapply(seq_len(nrow(d)), function(i) sf::st_point(c(-126, 54))), crs = 4326
    )
  )
  cache <- patb_cache()

  by_both <- fly_camera_patb(base, dest_dir = cache, quiet = TRUE)
  by_id <- fly_camera_patb(base[, setdiff(names(base), c("film_roll", "frame_number"))],
                           dest_dir = cache, quiet = TRUE)
  # Roll and frame only, with airp_id values that match nothing.
  roll_only <- base
  roll_only$airp_id <- -seq_len(nrow(base))
  by_roll <- fly_camera_patb(roll_only, dest_dir = cache, quiet = TRUE)

  expect_equal(by_id$camera_name, by_both$camera_name)
  expect_equal(by_roll$camera_name, by_both$camera_name)
  expect_true(all(!is.na(by_roll$camera_name)))
})


test_that("row order in the PAT-B file cannot change the answer", {
  # A per-FILE implementation — `d$ccre_lens_number[1]` recycled over every frame —
  # passes a per-frame test vacuously, because the measured archives carry one camera
  # each. Shuffling the file is what separates a join from a constant.
  cache <- patb_cache()
  photos <- patb_centroids()
  straight <- fly_camera_patb(photos, dest_dir = cache, quiet = TRUE)

  shuffled <- withr::local_tempdir()
  ex <- withr::local_tempdir()
  utils::unzip(file.path(cache, "d_003_fi_13_georef.zip"), exdir = ex)
  f <- list.files(ex, pattern = "\\.txt$", full.names = TRUE)
  d <- utils::read.csv(f, stringsAsFactors = FALSE)
  set.seed(1)
  utils::write.csv(d[sample(nrow(d)), ], f, row.names = FALSE)
  withr::with_dir(ex, utils::zip(file.path(shuffled, "d_003_fi_13_georef.zip"),
                                 list.files(ex), flags = "-Xq"))
  file.copy(file.path(cache, "d_005_emn_19_georef.zip"), shuffled)

  expect_equal(fly_camera_patb(photos, dest_dir = shuffled, quiet = TRUE)$camera_serial,
               straight$camera_serial)
})


test_that("an archive that is a 404 body leaves its frames unresolved and says so", {
  # `utils::download.file()` sets FAILONERROR and raises on these, so `fly_fetch()`
  # already reports them as failures — but FAILONERROR is a property of one client, and a
  # copy already in `dest_dir` from anything else reaches the parser as HTML. The bundled
  # file is the province's own 404 body, kept verbatim.
  photos <- sf::st_sf(
    airp_id = 1:2, film_roll = "bcd11300", frame_number = 890:891,
    patb_georef_url = "https://openmaps.gov.bc.ca/thumbs/patb_files/d_003_fi_11_georef.csv",
    geometry = sf::st_sfc(sf::st_point(c(-126, 54)), sf::st_point(c(-126.1, 54)), crs = 4326)
  )

  msgs <- testthat::capture_messages(got <- fly_camera_patb(photos, dest_dir = patb_cache()))
  expect_true(any(grepl("No PAT-B table", msgs)))
  expect_true(any(grepl("404 body", msgs)))
  expect_equal(nrow(got), 2L)
  expect_true(all(is.na(got$camera_serial)))
  expect_true(all(is.na(got$patb_source)))
})


test_that("a frame the archive does not cover comes back NA rather than being dropped", {
  photos <- patb_centroids()
  photos$frame_number[1] <- 99999L                       # a frame no archive holds
  got <- fly_camera_patb(photos, dest_dir = patb_cache(), quiet = TRUE)

  expect_equal(nrow(got), nrow(photos))
  expect_true(is.na(got$camera_serial[1]))
  expect_false(any(is.na(got$camera_serial[-1])))
})


test_that("the added columns reach a tibble-backed caller", {
  # `sf::st_sf(x, a = , b = , geometry = )` keeps ONLY `x` when `x` is a tibble, and
  # `bcdata::collect()` returns a tibble — which is how four reporting columns reached no
  # real caller through two releases (fly#35). This attaches columns to user-supplied
  # data, so it sweeps the class axis rather than testing one shape.
  cache <- patb_cache()
  for (nm in names(centroid_shapes())) {
    x <- centroid_shapes()[[nm]]
    # The film centroids carry no `patb_georef_url`, so give them one that resolves to
    # nothing — the columns must arrive regardless of whether anything matched.
    x$patb_georef_url <- NA_character_
    got <- fly_camera_patb(x, dest_dir = cache, quiet = TRUE)

    expect_true(all(c("camera_serial", "camera_name", "patb_gsd", "patb_source") %in%
                      names(got)), info = nm)
    expect_equal(nrow(got), nrow(x), info = nm)
    expect_true(all(class(x) %in% class(got)), info = nm)
  }
})


test_that("fly_camera_patb refuses input it cannot join or fetch", {
  photos <- patb_centroids()

  expect_error(fly_camera_patb(photos[, setdiff(names(photos), "patb_georef_url")]),
               "patb_georef_url")
  expect_error(
    fly_camera_patb(photos[, setdiff(names(photos),
                                     c("film_roll", "frame_number", "airp_id"))]),
    "to join a PAT-B row"
  )

  # Two archives in different directories sharing a basename would silently merge in the
  # download cache, which is keyed on the basename.
  clash <- photos
  clash$patb_georef_url <- ifelse(
    seq_len(nrow(clash)) == 1,
    "https://openmaps.gov.bc.ca/thumbs/other/d_003_fi_13_georef.zip",
    clash$patb_georef_url
  )
  expect_error(fly_camera_patb(clash, dest_dir = patb_cache()), "share a basename")
})


test_that("the live archives still carry the identities this package resolves", {
  # A canary, not a unit test. It is the only thing that notices the province changing a
  # schema or retiring a URL, and it must not redden CI for a network hiccup.
  skip_on_cran()
  skip_on_ci()
  skip_if_offline()

  photos <- patb_centroids()
  got <- fly_camera_patb(photos, dest_dir = withr::local_tempdir(), quiet = TRUE)

  expect_setequal(unique(got$camera_serial), c("121201", "22814295"))
  expect_true(all(!is.na(got$patb_source)))
})


test_that("an all-NA airp_id column cannot hand a frame another frame's camera", {
  # `match()` treats NA as a matchable VALUE, and both sides can be NA: a caller may carry
  # no `airp_id` at all — roll and frame is the documented alternative — and a published
  # archive may leave the column blank. Left alone, every frame whose roll/frame key
  # missed the archive inherits the blank row's camera with `inferred = FALSE`. A
  # confident wrong sensor, which is fly#37's shape arriving through NA.
  d <- utils::read.csv(testdata_path("patb", "d_001_fi_12_georef.csv"),
                       stringsAsFactors = FALSE)
  cache <- patb_cache()
  # Blank one `airp_id` in the archive, as a published file may.
  d$airp_id[1] <- NA
  utils::write.csv(d, file.path(cache, "d_001_fi_12_georef.csv"), row.names = FALSE)

  photos <- sf::st_sf(
    # No `airp_id` column at all, so `id_frame` is all-NA.
    film_roll = c(sub("_[^_]*$", "", d$roll_frame[2]), "zzz99999"),
    frame_number = c(as.integer(sub(".*_", "", d$roll_frame[2])), 7L),
    patb_georef_url = "https://openmaps.gov.bc.ca/thumbs/patb_files/d_001_fi_12_georef.csv",
    geometry = sf::st_sfc(sf::st_point(c(-126, 54)), sf::st_point(c(-126.1, 54)), crs = 4326)
  )
  got <- fly_camera_patb(photos, dest_dir = cache, quiet = TRUE)

  expect_false(is.na(got$camera_name[1]))            # premise: the real frame resolved
  expect_true(is.na(got$camera_name[2]))             # the frame in no archive must not
  expect_true(is.na(got$camera_serial[2]))
  expect_true(is.na(got$patb_source[2]))
})


test_that("an archive naming two cameras for one frame warns even when quiet", {
  # `quiet` suppresses progress. This is a statement about the DATA, and the arbitrary
  # pick can be the same 20%-wrong sensor the serial-before-name rule exists to refuse.
  d <- utils::read.csv(testdata_path("patb", "d_001_fi_12_georef.csv"),
                       stringsAsFactors = FALSE)
  cache <- patb_cache()
  clash <- d[1, ]
  clash$camera <- "Vexcel Ultracam X"
  utils::write.csv(rbind(d, clash), file.path(cache, "d_001_fi_12_georef.csv"),
                   row.names = FALSE)

  photos <- sf::st_sf(
    airp_id = d$airp_id[1],
    film_roll = sub("_[^_]*$", "", d$roll_frame[1]),
    frame_number = as.integer(sub(".*_", "", d$roll_frame[1])),
    patb_georef_url = "https://openmaps.gov.bc.ca/thumbs/patb_files/d_001_fi_12_georef.csv",
    geometry = sf::st_sfc(sf::st_point(c(-126, 54)), crs = 4326)
  )
  expect_warning(fly_camera_patb(photos, dest_dir = cache, quiet = TRUE),
                 "more than one camera")
})


test_that("an unreadable archive is reported as unreadable, not as holding no camera", {
  # Both are unresolved frames and they need different fixes: one points at the province,
  # the other at this machine. A corrupt archive told the operator to go and look at the
  # catalogue.
  cache <- patb_cache()
  writeLines("not a zip", file.path(cache, "d_003_fi_13_georef.zip"))
  photos <- patb_centroids()

  expect_true(any(grepl("could not be unpacked|none of them a PAT-B table",
                        testthat::capture_messages(fly_camera_patb(photos, dest_dir = cache)))))
})


test_that("a download that failed is reported as a download failure, not as an empty archive", {
  # `fly_fetch()` returns `dest` whether or not the fetch worked, and `success` beside it.
  # Reading only the path sent the operator to the catalogue for a network problem.
  photos <- sf::st_sf(
    airp_id = 1L, film_roll = "bcd12001", frame_number = 1L,
    patb_georef_url = "https://openmaps.gov.bc.ca.invalid/thumbs/patb_files/nope_georef.csv",
    geometry = sf::st_sfc(sf::st_point(c(-126, 54)), crs = 4326)
  )
  msgs <- testthat::capture_messages(
    got <- suppressWarnings(fly_camera_patb(photos, dest_dir = withr::local_tempdir()))
  )
  expect_true(any(grepl("Could not download", msgs)))
  expect_true(is.na(got$camera_serial))
})


test_that("two members of one archive naming the same frame warn rather than the last winning", {
  # Which member wins was decided by `unzip()`'s member order — the province's own file
  # layout — and the two cameras here differ by 20% of ground width. The duplicate guard
  # existed but was scoped to a single member, so it could not see this.
  cache <- patb_cache()
  d <- utils::read.csv(testdata_path("patb", "d_001_fi_12_georef.csv"), stringsAsFactors = FALSE)
  other <- d[1, ]
  other$camera <- "Vexcel Ultracam X"

  stage <- withr::local_tempdir()
  utils::write.csv(d, file.path(stage, "aa_georef.csv"), row.names = FALSE)
  utils::write.csv(other, file.path(stage, "zz_georef.csv"), row.names = FALSE)
  zip_path <- file.path(cache, "d_pair_georef.zip")
  withr::with_dir(stage, utils::zip(zip_path, list.files(stage), flags = "-Xq"))

  photos <- sf::st_sf(
    airp_id = d$airp_id[1],
    film_roll = sub("_[^_]*$", "", d$roll_frame[1]),
    frame_number = as.integer(sub(".*_", "", d$roll_frame[1])),
    patb_georef_url = "https://openmaps.gov.bc.ca/thumbs/patb_files/d_pair_georef.zip",
    geometry = sf::st_sfc(sf::st_point(c(-126, 54)), crs = 4326)
  )
  expect_warning(fly_camera_patb(photos, dest_dir = cache, quiet = TRUE),
                 "more than one camera")
})


test_that("a georef table under an unexpected extension still dispatches on its columns", {
  # "Dispatch on the columns present, not the extension" is the release's own claim, and
  # the province has already used `.txt` and `.csv` for two different schemas. An
  # extension allowlist would drop a third, and would do it with the message that blames
  # the catalogue for publishing nothing.
  cache <- patb_cache()
  d <- utils::read.csv(testdata_path("patb", "d_001_fi_12_georef.csv"), stringsAsFactors = FALSE)
  stage <- withr::local_tempdir()
  utils::write.csv(d, file.path(stage, "georef.dat"), row.names = FALSE)
  withr::with_dir(stage, utils::zip(file.path(cache, "d_ext_georef.zip"),
                                    list.files(stage), flags = "-Xq"))

  photos <- sf::st_sf(
    airp_id = d$airp_id[1],
    film_roll = sub("_[^_]*$", "", d$roll_frame[1]),
    frame_number = as.integer(sub(".*_", "", d$roll_frame[1])),
    patb_georef_url = "https://openmaps.gov.bc.ca/thumbs/patb_files/d_ext_georef.zip",
    geometry = sf::st_sfc(sf::st_point(c(-126, 54)), crs = 4326)
  )
  got <- fly_camera_patb(photos, dest_dir = cache, quiet = TRUE)
  expect_equal(got$camera_name, "Vexcel Ultracam XP")
})


test_that("an unusable frame number does not match an archive row whose own frame is unusable", {
  # `paste0()` stringifies NA, so both sides used to become the literal key
  # `bcd12001_NA` and match each other. The `is.na()` guard on the id join cannot see
  # that — by `match()` time the value is three characters.
  cache <- patb_cache()
  d <- utils::read.csv(testdata_path("patb", "d_001_fi_12_georef.csv"), stringsAsFactors = FALSE)
  d$roll_frame[1] <- "bcd12001_xxx"                      # a frame suffix that will not parse
  utils::write.csv(d, file.path(cache, "d_001_fi_12_georef.csv"), row.names = FALSE)

  photos <- sf::st_sf(
    film_roll = "bcd12001", frame_number = NA_integer_,
    patb_georef_url = "https://openmaps.gov.bc.ca/thumbs/patb_files/d_001_fi_12_georef.csv",
    geometry = sf::st_sfc(sf::st_point(c(-126, 54)), crs = 4326)
  )
  got <- fly_camera_patb(photos, dest_dir = cache, quiet = TRUE)
  expect_true(is.na(got$camera_name))
  expect_true(is.na(got$patb_source))
})


test_that("a file that parses but matches no schema says so, rather than blaming the catalogue", {
  # "The province changed a schema" and "this disk is bad" and "this is a 404 page" all
  # left a frame unresolved and were all reported as the last one.
  cache <- patb_cache()
  utils::write.csv(data.frame(a = 1:2, b = 3:4),
                   file.path(cache, "d_003_fi_11_georef.csv"), row.names = FALSE)
  photos <- sf::st_sf(
    airp_id = 1L, film_roll = "bcd11300", frame_number = 890L,
    patb_georef_url = "https://openmaps.gov.bc.ca/thumbs/patb_files/d_003_fi_11_georef.csv",
    geometry = sf::st_sfc(sf::st_point(c(-126, 54)), crs = 4326)
  )
  expect_true(any(grepl("match no PAT-B schema",
                        testthat::capture_messages(fly_camera_patb(photos, dest_dir = cache)))))
})


test_that("a small archive with no trailing newline is read, not refused", {
  # `read.table` warns "incomplete final line found by readTableHeader" whenever a small
  # file has no trailing newline. Handled with `warning =` rather than `suppressWarnings`,
  # that handler RETURNS instead of the value and throws away a table that parsed
  # perfectly, so a 1-4 frame archive resolved zero of its frames and blamed the file.
  #
  # Both bundled fixtures end in a newline and both zip members are 6 rows, so nothing
  # else in this suite can reach it.
  cache <- patb_cache()
  d <- utils::read.csv(testdata_path("patb", "d_001_fi_12_georef.csv"),
                       stringsAsFactors = FALSE)[1:2, ]
  f <- file.path(cache, "d_001_fi_12_georef.csv")
  utils::write.csv(d, f, row.names = FALSE)
  raw <- readBin(f, "raw", file.size(f))
  writeBin(raw[-length(raw)], f)                      # strip the final newline
  expect_false(identical(utils::tail(readBin(f, "raw", file.size(f)), 1L), as.raw(10)))

  photos <- sf::st_sf(
    airp_id = d$airp_id,
    film_roll = sub("_[^_]*$", "", d$roll_frame),
    frame_number = as.integer(sub(".*_", "", d$roll_frame)),
    patb_georef_url = "https://openmaps.gov.bc.ca/thumbs/patb_files/d_001_fi_12_georef.csv",
    geometry = sf::st_sfc(sf::st_point(c(-126, 54)), sf::st_point(c(-126.1, 54)), crs = 4326)
  )
  got <- fly_camera_patb(photos, dest_dir = cache, quiet = TRUE)
  expect_equal(got$camera_name, rep("Vexcel Ultracam XP", 2))
})


test_that("a binary member does not leak a warning out of the reader", {
  # F5 removed the extension filter, so every member reaches `readLines()` and the HTML
  # test. Both warn on bytes that are not valid in the native encoding — noise on a
  # correct run, and fatal under `options(warn = 2)`.
  d <- withr::local_tempdir()
  bin <- file.path(d, "blob.dat")
  writeBin(as.raw(c(0xf8, 0x43, 0xa6, 0x80, 0xa1, 0xfc, 0xd6, 0x2a)), bin)

  expect_silent(res <- fly_patb_read_one(bin))
  expect_false(is.data.frame(res))
})
