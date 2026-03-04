#' Query FWA lake polygons that intersect habitat streams
#'
#' Returns lake polygons from `whse_basemapping.fwa_lakes_poly` that share a
#' `waterbody_key` with the input streams. Use with [fly_trim_habitat()] to
#' fill gaps where lakes interrupt the stream network.
#'
#' @param conn A DBI connection to a bcfishpass database.
#' @param streams_sf An sf linestring — habitat streams (e.g. from
#'   [fly_query_habitat()]).
#' @return An sf polygon object in WGS84 (EPSG:4326), or `NULL` if no
#'   waterbody keys are found.
#'
#' @export
fly_query_lakes <- function(conn, streams_sf) {
  if (!requireNamespace("DBI", quietly = TRUE)) {
    stop("Package 'DBI' is required for fly_query_lakes().", call. = FALSE)
  }

  wbkeys <- unique(streams_sf$waterbody_key)
  wbkeys <- wbkeys[!is.na(wbkeys) & wbkeys != 0]

  if (length(wbkeys) == 0) {
    message("No waterbody keys found in streams - no lakes to query")
    return(NULL)
  }

  wbkey_list <- paste(wbkeys, collapse = ", ")
  sql <- glue::glue("
    SELECT waterbody_key, gnis_name_1,
           ST_Transform(geom, 4326) as geom
    FROM whse_basemapping.fwa_lakes_poly
    WHERE waterbody_key IN ({wbkey_list})
  ")

  result <- sf::st_read(conn, query = sql, quiet = TRUE)
  message("  ", nrow(result), " lake polygons")
  result
}
