# Structural invariants of the reporting columns, swept across every input shape a
# caller can present.
#
# A global invariant beats more examples here: it cannot be gamed by fixture choice, and
# the reporting surface is exactly where this package has been bitten — #30 claimed a
# terrain treatment for a frame with no geometry, #35 dropped the columns entirely on a
# tibble, and #32 shipped a basis and a width_source alongside an empty geometry with
# nothing to say so.

test_that("footprint_terrain is NA exactly where the geometry is empty", {
  skip_if_no_terra()
  cases <- footprint_cases()
  for (nm in names(cases)) {
    cs <- cases[[nm]]
    fp <- suppressWarnings(fly_footprint(cs$x, dem = cs$dem))
    empty <- sf::st_is_empty(sf::st_geometry(fp))

    # Both directions. A terrain value on an empty geometry claims a treatment for a
    # frame that was never placed; an NA on a real footprint hides how it was sized.
    expect_identical(is.na(fp$footprint_terrain), empty, info = nm)
    expect_true(all(is.na(fp$height_agl[empty])), info = nm)
    expect_true(all(is.na(fp$dem_coverage[empty])), info = nm)
  }
})


test_that("every frame gets a basis, and the reporting columns keep their types", {
  skip_if_no_terra()
  cases <- footprint_cases()
  for (nm in names(cases)) {
    cs <- cases[[nm]]
    fp <- suppressWarnings(fly_footprint(cs$x, dem = cs$dem))

    expect_true(all(!is.na(fp$footprint_basis)), info = nm)
    # `ifelse(logical(0), ...)` returns `logical(0)`, so an empty result would report a
    # character column as logical and fail to bind to a populated one.
    expect_type(fp$footprint_basis, "character")
    expect_type(fp$footprint_terrain, "character")
    expect_type(fp$width_source, "character")
    expect_type(fp$height_agl, "double")
    expect_type(fp$dem_coverage, "double")
    expect_identical(nrow(fp), nrow(cs$x), info = nm)
  }
})


test_that("a sized footprint is a closed rectangle of positive area", {
  skip_if_no_terra()
  cases <- footprint_cases()
  for (nm in names(cases)) {
    cs <- cases[[nm]]
    fp <- suppressWarnings(fly_footprint(cs$x, dem = cs$dem))
    g <- sf::st_geometry(sf::st_transform(fp, 3005))
    sized <- !sf::st_is_empty(g)
    if (!any(sized)) next

    # Catches the degenerate five-identical-vertex polygon a zero half-dimension builds:
    # `st_is_empty()` reports FALSE for it, so it would pass every emptiness check while
    # covering nothing.
    expect_true(all(as.numeric(sf::st_area(g[sized])) > 0), info = nm)
    for (i in which(sized)) {
      xy <- sf::st_coordinates(g[[i]])[, 1:2, drop = FALSE]
      expect_identical(nrow(xy), 5L, info = nm)
      expect_equal(xy[1, ], xy[5, ], info = nm)
      # Opposite edges equal: still a rectangle after any rotation.
      d <- sqrt(rowSums(diff(xy)^2))
      expect_equal(d[1], d[3], info = nm)
      expect_equal(d[2], d[4], info = nm)
    }
  }
})
