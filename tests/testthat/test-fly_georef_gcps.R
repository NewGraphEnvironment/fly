# The pixel-to-ground correspondence is the part of georeferencing that can be wrong
# while everything around it looks healthy: a wrong-by-90 corner mapping still writes a
# valid GeoTIFF, in the right CRS, with the right extent, and nothing in this package
# looks at pixels. So it is tested here as a pure function, offline.

# A square, axis-aligned footprint — the film case. Ring order is the contract
# `fly_footprint()` documents: BL, BR, TR, TL.
film_ring <- function() {
  matrix(c(
    1000, 2000,   # BL
    5000, 2000,   # BR
    5000, 6000,   # TR
    1000, 6000    # TL
  ), ncol = 2, byrow = TRUE)
}

# UltraCam Eagle M3-shaped: 3175 x 2040 m about the origin, long axis across-track.
ultracam_ring <- function() {
  matrix(c(
    -1587.5, -1020,
     1587.5, -1020,
     1587.5,  1020,
    -1587.5,  1020
  ), ncol = 2, byrow = TRUE)
}

ground_of <- function(g) unname(g[, c("ground_x", "ground_y"), drop = FALSE])


test_that("fly_georef_gcps returns four corners in TL, TR, BR, BL pixel order", {
  g <- fly_georef_gcps(1250L, 1250L, film_ring(), 0)

  expect_equal(dim(g), c(4L, 4L))
  expect_identical(colnames(g), c("pixel_x", "pixel_y", "ground_x", "ground_y"))
  expect_equal(
    unname(g[, c("pixel_x", "pixel_y")]),
    matrix(c(0, 0, 1250, 0, 1250, 1250, 0, 1250), ncol = 2, byrow = TRUE)
  )

  # Pixel corners do not move with rotation — only the ground corners they map to.
  for (rot in c(0, 90, 180, 270)) {
    expect_equal(
      unname(fly_georef_gcps(1250L, 1250L, film_ring(), rot)[, c("pixel_x", "pixel_y")]),
      unname(g[, c("pixel_x", "pixel_y")]),
      info = paste("rotation =", rot)
    )
  }
})


test_that("film corner mapping is unchanged at every rotation", {
  # Golden values, not a re-derivation. Captured from the implementation as it stood
  # before the GCP construction was split out of `georef_one()` — the bytes pulled with
  # `git show <sha>:R/fly_georef.R`, exercised over the bundled film and digital
  # footprints plus random rings at four image shapes: 1024 cases, 0 differences.
  #
  # Written out rather than computed so this keeps working once that sha is history.
  expected <- list(
    "0"   = matrix(c(1000, 6000, 5000, 6000, 5000, 2000, 1000, 2000), ncol = 2, byrow = TRUE),
    "90"  = matrix(c(5000, 6000, 5000, 2000, 1000, 2000, 1000, 6000), ncol = 2, byrow = TRUE),
    "180" = matrix(c(5000, 2000, 1000, 2000, 1000, 6000, 5000, 6000), ncol = 2, byrow = TRUE),
    "270" = matrix(c(1000, 2000, 1000, 6000, 5000, 6000, 5000, 2000), ncol = 2, byrow = TRUE)
  )

  for (rot in names(expected)) {
    expect_equal(
      ground_of(fly_georef_gcps(1250L, 1250L, film_ring(), as.numeric(rot))),
      expected[[rot]],
      info = paste("rotation =", rot)
    )
  }
})


test_that("non-square corner mapping is unchanged at every rotation", {
  # Same golden capture, on a rectangle. Included because the film case is square and
  # therefore cannot distinguish a shift that swaps the two axes from one that does not.
  expected <- list(
    "0"   = matrix(c(-1587.5,  1020,  1587.5,  1020,  1587.5, -1020, -1587.5, -1020),
                   ncol = 2, byrow = TRUE),
    "90"  = matrix(c( 1587.5,  1020,  1587.5, -1020, -1587.5, -1020, -1587.5,  1020),
                   ncol = 2, byrow = TRUE),
    "180" = matrix(c( 1587.5, -1020, -1587.5, -1020, -1587.5,  1020,  1587.5,  1020),
                   ncol = 2, byrow = TRUE),
    "270" = matrix(c(-1587.5, -1020, -1587.5,  1020,  1587.5,  1020,  1587.5, -1020),
                   ncol = 2, byrow = TRUE)
  )

  for (rot in names(expected)) {
    expect_equal(
      ground_of(fly_georef_gcps(1063L, 1654L, ultracam_ring(), as.numeric(rot))),
      expected[[rot]],
      info = paste("rotation =", rot)
    )
  }
})


test_that("rotation 0 and 180 put image width on the cross-track edge, 90 and 270 along", {
  # The property the golden tables above encode, stated once so a future change to them
  # has to disagree with a sentence rather than only with a number.
  #
  # `fly_rectangles()` builds the ring in the rectangle's own frame, so edge 1->2 is
  # across-track and edge 2->3 along-track. Here: 3175 m across, 2040 m along.
  width_edge_m <- function(rot) {
    g <- ground_of(fly_georef_gcps(1063L, 1654L, ultracam_ring(), rot))
    sqrt(sum((g[2, ] - g[1, ])^2))   # TL -> TR is the image's width
  }

  expect_equal(width_edge_m(0), 3175)
  expect_equal(width_edge_m(180), 3175)
  expect_equal(width_edge_m(90), 2040)
  expect_equal(width_edge_m(270), 2040)
})


test_that("the ground quad keeps one handedness at every rotation", {
  # The mirror the aspect invariant cannot see. Mapping the pixel corners onto the ring
  # traversed the other way leaves every edge length identical, the aspect ratio
  # identical, and the output reflected. Signed area is what separates them, and it is a
  # property of the whole quad rather than of any one corner.
  signed_area <- function(g) {
    x <- g[, "ground_x"]; y <- g[, "ground_y"]
    k <- c(2, 3, 4, 1)
    sum(x * y[k] - x[k] * y) / 2
  }

  for (ring in list(film_ring(), ultracam_ring())) {
    s <- vapply(c(0, 90, 180, 270), function(r) {
      sign(signed_area(fly_georef_gcps(1063L, 1654L, ring, r)))
    }, numeric(1))
    expect_equal(s, rep(-1, 4))
  }

  # And it can fail: reverse the ring and the sign flips.
  reversed <- ultracam_ring()[c(4, 3, 2, 1), , drop = FALSE]
  expect_equal(sign(signed_area(fly_georef_gcps(1063L, 1654L, reversed, 0))), 1)
})


test_that("fly_gcp_anisotropy measures the stretch a mapping would apply", {
  # 3175 x 2040 m footprint, 1063 x 1654 px portrait image. The measured mapping is
  # isotropic; the pair it rejects stretches by the footprint's aspect squared.
  aniso <- function(rot) {
    fly_gcp_anisotropy(fly_georef_gcps(1063L, 1654L, ultracam_ring(), rot), 1063L, 1654L)
  }
  # 1e-3, not 1e-6: a thumbnail is a rounded downscale of the sensor, so even the
  # correct pairing lands at 0.99974 rather than exactly 1. That 0.03% is the headroom
  # the guard's 5% tolerance has to clear, against a 21% minimum for a wrong pairing
  # (the DMC II, the least eccentric camera in the shipped table).
  expect_equal(aniso(fly_digital_rotation()), 1, tolerance = 1e-3)
  expect_equal(aniso(90), 1, tolerance = 1e-3)
  # (m/px across) / (m/px along) when the axes are paired the wrong way round. Not
  # exactly the footprint's aspect squared, because the thumbnail is a rounded
  # downscale of the sensor rather than an exact one.
  wrong <- (3175 / 1063) / (2040 / 1654)
  expect_equal(wrong, 2.4217, tolerance = 1e-4)
  expect_equal(aniso(0), wrong, tolerance = 1e-6)
  expect_equal(aniso(180), wrong, tolerance = 1e-6)

  # Degenerate dimensions give NA rather than a number the guard would act on.
  expect_true(is.na(fly_gcp_anisotropy(fly_georef_gcps(10L, 10L, ultracam_ring(), 0), 0, 10)))
})


test_that("the digital rotation constant is 270 and is not derived at run time", {
  # Pinned deliberately. It was measured (inst/notes/georeferencing.md); a future reader
  # who recomputes it from the ring geometry will get a plausible wrong answer, because
  # the geometry alone cannot separate 270 from 90.
  expect_identical(fly_digital_rotation(), 270L)
})
