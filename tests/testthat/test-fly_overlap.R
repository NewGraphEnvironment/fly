test_that("fly_overlap returns tibble with expected columns", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  result <- fly_overlap(centroids)
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("photo_a", "photo_b", "overlap_km2",
                     "pct_of_a", "pct_of_b") %in% names(result)))
})

test_that("fly_overlap finds overlapping same-scale photos", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  photos_12k <- centroids[centroids$scale == "1:12000", ]
  result <- fly_overlap(photos_12k)
  # adjacent flight-line photos should have some overlap

  expect_gt(nrow(result), 0)
  expect_true(all(result$overlap_km2 > 0))
  expect_true(all(result$pct_of_a >= 0 & result$pct_of_a <= 100))
  expect_true(all(result$pct_of_b >= 0 & result$pct_of_b <= 100))
})

test_that("fly_overlap uses airp_id when available", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  photos_12k <- centroids[centroids$scale == "1:12000", ]
  result <- fly_overlap(photos_12k)
  if (nrow(result) > 0) {
    expect_true(all(result$photo_a %in% photos_12k$airp_id))
    expect_true(all(result$photo_b %in% photos_12k$airp_id))
  }
})

test_that("fly_overlap returns empty tibble for single photo", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  result <- fly_overlap(centroids[1, ])
  expect_equal(nrow(result), 0)
  expect_s3_class(result, "tbl_df")
})

test_that("fly_overlap pairs are unique (no duplicates)", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  result <- fly_overlap(centroids)
  if (nrow(result) > 0) {
    pair_keys <- paste(result$photo_a, result$photo_b, sep = "-")
    expect_equal(length(pair_keys), length(unique(pair_keys)))
  }
})

test_that("fly_overlap larger scale has larger overlaps", {
  centroids <- sf::st_read(testdata_path("photo_centroids.gpkg"), quiet = TRUE)
  overlap_12k <- fly_overlap(centroids[centroids$scale == "1:12000", ])
  overlap_31k <- fly_overlap(centroids[centroids$scale == "1:31680", ])
  # 1:31680 footprints are ~7x larger so overlap area should be larger
  if (nrow(overlap_12k) > 0 && nrow(overlap_31k) > 0) {
    expect_gt(max(overlap_31k$overlap_km2), max(overlap_12k$overlap_km2))
  }
})
