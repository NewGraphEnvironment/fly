D <- "/private/tmp/claude-501/-Users-airvine-Projects-repo-fly/0e762a6d-f932-4614-9d5b-0fc1d445cb10/scratchpad/p82"
source(file.path(D, "pc.R"))
f <- sprintf("%s/thumbs/bc5282_%d_thumb.jpg", D, 226:236)
for (k in 1:10) {
  a <- read_gray(f[k]); b <- read_gray(f[k + 1])
  s <- phase_corr(a[26:1225, 26:1225], b[26:1225, 26:1225])
  cat(sprintf("%d->%d  row %+8.2f col %+8.2f  peak %.3f\n", 225 + k, 226 + k, s[1], s[2], s[3]))
}
