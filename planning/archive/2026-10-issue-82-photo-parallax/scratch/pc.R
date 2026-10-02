# phase correlation helpers (probe)
read_gray <- function(p) {
  r <- terra::rast(p)
  m <- terra::as.matrix(if (terra::nlyr(r) >= 3) mean(r[[1:3]]) else r[[1]], wide = TRUE)
  storage.mode(m) <- "double"
  m
}
hann2 <- function(nr, nc) outer(0.5 - 0.5 * cos(2 * pi * (0:(nr - 1)) / (nr - 1)),
                                0.5 - 0.5 * cos(2 * pi * (0:(nc - 1)) / (nc - 1)))
# shift s such that b[i + s] ~ a[i]  (content of a appears at +s in b), rows/cols
phase_corr <- function(a, b, win = TRUE) {
  a <- a - mean(a); b <- b - mean(b)
  if (win) { w <- hann2(nrow(a), ncol(a)); a <- a * w; b <- b * w }
  Fa <- fft(a); Fb <- fft(b)
  R <- Fb * Conj(Fa); R <- R / pmax(Mod(R), 1e-12)
  r <- Re(fft(R, inverse = TRUE)) / length(R)
  k <- which.max(r); i <- (k - 1) %% nrow(r); j <- (k - 1) %/% nrow(r)
  nr <- nrow(r); nc <- ncol(r)
  g <- function(ii, jj) r[(ii %% nr) + 1, (jj %% nc) + 1]
  # parabolic sub-pixel
  di <- { y0 <- g(i - 1, j); y1 <- g(i, j); y2 <- g(i + 1, j); den <- y0 - 2 * y1 + y2; if (den == 0) 0 else 0.5 * (y0 - y2) / den }
  dj <- { y0 <- g(i, j - 1); y1 <- g(i, j); y2 <- g(i, j + 1); den <- y0 - 2 * y1 + y2; if (den == 0) 0 else 0.5 * (y0 - y2) / den }
  si <- i + di; sj <- j + dj
  if (si > nr / 2) si <- si - nr
  if (sj > nc / 2) sj <- sj - nc
  c(row = si, col = sj, peak = max(r), second = sort(r, decreasing = TRUE)[5])
}
