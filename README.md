# fly

<!-- badges: start -->
<!-- badges: end -->

Airphoto footprint estimation and coverage selection. Estimate ground
footprints from airphoto centroids and scale, compute coverage of areas of
interest, and select minimum photo sets using greedy set-cover.

## Installation

```r
pak::pak("NewGraphEnvironment/fly")
```

## Example

```r
library(fly)
library(sf)

# Estimate footprint rectangles from centroids
footprints <- fly_footprint(centroids)

# Filter photos whose footprint overlaps the AOI
filtered <- fly_filter(centroids, aoi, method = "footprint")

# Select minimum set for 95% coverage
selected <- fly_select(filtered, aoi, target_coverage = 0.95)
```

See the [airphoto selection
vignette](https://newgraphenvironment.github.io/fly/articles/airphoto-selection.html)
for the full pipeline.
