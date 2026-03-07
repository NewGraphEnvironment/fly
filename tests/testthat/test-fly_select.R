test_that("fly_select minimal mode returns sf with selection columns", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_select(centroids, aoi, mode = "minimal", target_coverage = 0.50)
  expect_s3_class(result, "sf")
  expect_true("selection_order" %in% names(result))
  expect_true("cumulative_coverage_pct" %in% names(result))
})

test_that("fly_select minimal mode selects fewer photos than input", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_select(centroids, aoi, mode = "minimal", target_coverage = 0.50)
  expect_lt(nrow(result), nrow(centroids))
})

test_that("fly_select minimal coverage increases monotonically", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_select(centroids, aoi, mode = "minimal", target_coverage = 0.50)
  if (nrow(result) > 1) {
    diffs <- diff(result$cumulative_coverage_pct)
    expect_true(all(diffs >= 0))
  }
})

test_that("fly_select defaults to minimal mode", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result_default <- fly_select(centroids, aoi, target_coverage = 0.50)
  result_explicit <- fly_select(centroids, aoi, mode = "minimal", target_coverage = 0.50)
  expect_equal(nrow(result_default), nrow(result_explicit))
  expect_equal(result_default$selection_order, result_explicit$selection_order)
})

test_that("fly_select all mode returns every photo touching AOI", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_select(centroids, aoi, mode = "all")
  expect_s3_class(result, "sf")
  # all mode should return at least as many as minimal
  result_min <- fly_select(centroids, aoi, mode = "minimal", target_coverage = 0.99)
  expect_gte(nrow(result), nrow(result_min))
})

test_that("fly_select all mode does not add selection columns", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_select(centroids, aoi, mode = "all")
  expect_false("selection_order" %in% names(result))
  expect_false("cumulative_coverage_pct" %in% names(result))
})

test_that("fly_select all mode only returns photos intersecting AOI", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_select(centroids, aoi, mode = "all")
  # verify every selected photo footprint actually intersects the AOI
  fp <- fly_footprint(result)
  aoi_t <- sf::st_transform(aoi, sf::st_crs(fp))
  touches <- sf::st_intersects(fp, aoi_t, sparse = FALSE)[, 1]
  expect_true(all(touches))
})

test_that("fly_select all on single scale returns subset", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  photos_12k <- centroids[centroids$scale == "1:12000", ]
  result <- fly_select(photos_12k, aoi, mode = "all")
  expect_s3_class(result, "sf")
  expect_lte(nrow(result), nrow(photos_12k))
  expect_true(all(result$scale == "1:12000"))
})

test_that("fly_select rejects invalid mode", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  expect_error(fly_select(centroids, aoi, mode = "bogus"))
})

test_that("fly_select minimal handles full coverage without error", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  # target 1.0 forces the algorithm to exhaust all photos or hit 100%
  result <- fly_select(centroids, aoi, mode = "minimal", target_coverage = 1.0)
  expect_s3_class(result, "sf")
  expect_gt(nrow(result), 0)
  # coverage should be scalar, not length 0
  expect_length(result$cumulative_coverage_pct, nrow(result))
})

# --- ensure_components tests ---

test_that("ensure_components selects at least as many photos as without", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result_plain <- fly_select(centroids, aoi, mode = "minimal",
                             target_coverage = 0.80)
  result_ec <- fly_select(centroids, aoi, mode = "minimal",
                          target_coverage = 0.80, ensure_components = TRUE)
  expect_gte(nrow(result_ec), nrow(result_plain))
})

test_that("ensure_components covers more AOI components", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)

  sf::sf_use_s2(FALSE)
  components <- sf::st_cast(
    sf::st_transform(aoi, 3005) |> sf::st_union() |> sf::st_make_valid(),
    "POLYGON"
  )

  count_covered <- function(selected) {
    fp <- fly_footprint(selected) |> sf::st_transform(3005)
    fp_union <- sf::st_union(fp) |> sf::st_make_valid()
    sum(vapply(seq_along(components), function(k) {
      any(sf::st_intersects(fp_union, components[k], sparse = FALSE))
    }, logical(1)))
  }

  result_plain <- fly_select(centroids, aoi, mode = "minimal",
                             target_coverage = 0.80)
  result_ec <- fly_select(centroids, aoi, mode = "minimal",
                          target_coverage = 0.80, ensure_components = TRUE)

  covered_plain <- count_covered(result_plain)
  covered_ec <- count_covered(result_ec)

  expect_gte(covered_ec, covered_plain)
})

test_that("ensure_components returns valid selection columns", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result <- fly_select(centroids, aoi, mode = "minimal",
                       target_coverage = 0.80, ensure_components = TRUE)
  expect_s3_class(result, "sf")
  expect_true("selection_order" %in% names(result))
  expect_true("cumulative_coverage_pct" %in% names(result))
  # selection_order should be sequential
  expect_equal(result$selection_order, seq_len(nrow(result)))
  # coverage should increase monotonically
  if (nrow(result) > 1) {
    diffs <- diff(result$cumulative_coverage_pct)
    expect_true(all(diffs >= 0))
  }
})

test_that("ensure_components FALSE is the default", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result_default <- fly_select(centroids, aoi, mode = "minimal",
                               target_coverage = 0.80)
  result_false <- fly_select(centroids, aoi, mode = "minimal",
                             target_coverage = 0.80,
                             ensure_components = FALSE)
  expect_equal(nrow(result_default), nrow(result_false))
})

test_that("ensure_components works on single-polygon AOI", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  # Create single polygon from convex hull of AOI
  single_aoi <- sf::st_convex_hull(sf::st_union(aoi))
  single_aoi <- sf::st_sf(geometry = single_aoi, crs = sf::st_crs(aoi))
  result <- fly_select(centroids, single_aoi, mode = "minimal",
                       target_coverage = 0.80, ensure_components = TRUE)
  expect_s3_class(result, "sf")
  expect_gt(nrow(result), 0)
})

test_that("ensure_components is ignored in all mode", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  aoi <- sf::st_read(testdata_path("aoi.gpkg"), quiet = TRUE)
  result_plain <- fly_select(centroids, aoi, mode = "all")
  result_ec <- fly_select(centroids, aoi, mode = "all",
                          ensure_components = TRUE)
  expect_equal(nrow(result_plain), nrow(result_ec))
})
