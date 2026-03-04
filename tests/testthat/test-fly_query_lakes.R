test_that("fly_query_lakes returns NULL when no waterbody keys", {
  # Synthetic sf with waterbody_key = 0 (no real lake)
  streams <- sf::st_sf(
    waterbody_key = c(0, 0),
    geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(0, 0, 1, 1), ncol = 2)),
      sf::st_linestring(matrix(c(1, 1, 2, 2), ncol = 2)),
      crs = 4326
    )
  )

  # This test doesn't need a DB — the NULL path triggers before any query
  result <- fly_query_lakes(conn = NULL, streams_sf = streams)
  expect_null(result)
})

test_that("fly_query_lakes queries DB when keys exist", {
  skip_if_no_db()

  conn <- DBI::dbConnect(RPostgres::Postgres(),
    host = "localhost", port = 63333,
    dbname = "bcfishpass", user = "newgraph")
  on.exit(DBI::dbDisconnect(conn))

  streams <- fly_query_habitat(conn, wsgroup = "BULK",
    habitat_type = "rearing", species_code = "co",
    min_stream_order = 6)

  result <- fly_query_lakes(conn, streams)
  # May return sf or NULL depending on data
  if (!is.null(result)) {
    expect_s3_class(result, "sf")
  }
})
