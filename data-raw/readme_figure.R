# README figure: one site, ten years apart, from photos fly georeferenced (#104)
#
# Two thumbnails from the public stac-airphoto-bc collection (https://images.a11s.one/), which
# fly georeferenced onto their estimated footprints, cropped to the same 2 km x 2 km box at
# McKilligan Road on the upper Bulkley River (Neexdzii Kwa) near Houston, BC, centred on
# -126.5345, 54.45192. Writes man/figures/readme-history.png. Run from the package root.

library(terra)

out <- "man/figures/readme-history.png"

# STAC items 1400364 (1971-07-17) and 790359 (1981-07-13)
photos <- data.frame(
  year = c(1971, 1981),
  url = c(
    "https://stac-airphoto-bc.s3.us-west-2.amazonaws.com/thumbs/1971/bc7326_030_thumb.tif",
    "https://stac-airphoto-bc.s3.us-west-2.amazonaws.com/thumbs/1981/bc81050_048_12n_thumb.tif"
  )
)

# The box in BC Albers (EPSG:3005), the CRS both thumbnails are written in
box <- terra::ext(964426, 966426, 1049182, 1051182)

read_photo <- function(url) {
  f <- tempfile(fileext = ".tif")
  # One request for the whole file: a /vsicurl/ read issues one per block
  st <- curl::curl_fetch_disk(url, f)$status_code
  if (st != 200) stop("HTTP ", st, " fetching ", url, call. = FALSE)
  r <- terra::rast(f)
  stopifnot(terra::nlyr(r) == 2, terra::crs(r, describe = TRUE)$code == "3005")
  r <- terra::crop(r, box)
  # Band 2 is the alpha fly writes: 0 outside the photo's footprint
  r <- terra::mask(r[[1]], r[[2]], maskvalues = 0)
  # Display only: each scan's own exposure, stretched to the full grey range
  terra::stretch(r, minq = 0.01, maxq = 0.99)
}

imgs <- lapply(photos$url, read_photo)

png(out, width = 1800, height = 920, res = 200, bg = "white")
op <- par(mfrow = c(1, 2), mar = c(0.2, 0.2, 0.2, 0.2), oma = c(0, 0, 0, 0))
for (i in seq_along(imgs)) {
  terra::plot(imgs[[i]], col = grey.colors(256, start = 0, end = 1), range = c(0, 255),
              legend = FALSE,
              axes = FALSE, box = FALSE, ext = box, mar = c(0.2, 0.2, 0.2, 0.2),
              maxcell = terra::ncell(imgs[[i]]))
  # Positioned by coordinates: a keyword-placed label after terra::plot() draws nothing
  xl <- box$xmin + 60
  yt <- box$ymax - 60
  rect(xl, yt - 190, xl + 430, yt, col = "white", border = NA)
  text(xl + 215, yt - 95, photos$year[i], cex = 1.3, font = 2)
}
# 500 m scale bar on the second panel
x0 <- box$xmax - 620
y0 <- box$ymin + 90
rect(x0 - 40, y0 - 50, x0 + 540, y0 + 190, col = "white", border = NA)
segments(x0, y0, x0 + 500, y0, lwd = 4, lend = 1)
text(x0 + 250, y0 + 100, "500 m", cex = 1)
par(op)
dev.off()

message("Wrote ", out)
