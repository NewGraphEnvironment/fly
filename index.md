# fly

Select the minimum set of historic airphotos needed to cover your study
area.

## Why

Historic airphotos are essential for documenting landscape change, but
ordering them is tedious — you’re choosing from thousands of overlapping
frames across multiple scales and decades. Photo centroids are available
from the [BC Data
Catalogue](https://catalogue.data.gov.bc.ca/dataset/0af7544c-f2ad-4553-bb37-889c94d4c571)
but knowing which frames actually cover your area of interest requires
estimating ground footprints from scale and film format.

fly estimates those footprints, filters by actual ground coverage (not
just centroids), and picks the smallest set that meets your target.
Best-resolution photos first, coarser scales fill the gaps.

![Priority selection: 1:12000 (blue) and 1:31680 (orange) footprints
covering a floodplain AOI near Houston,
BC](reference/figures/readme-priority.png)

*Upper Bulkley River floodplain near Houston, BC — 1968 photos at
1:12,000 (blue) and 1:31,680 (orange).*

## Installation

``` r
pak::pak("NewGraphEnvironment/fly")
```

## Example

``` r
library(fly)
library(sf)

# Estimate footprint rectangles from centroids
footprints <- fly_footprint(centroids)

# Filter photos whose footprint overlaps the AOI
filtered <- fly_filter(centroids, aoi, method = "footprint")

# Select minimum set for 95% coverage
selected <- fly_select(filtered, aoi, target_coverage = 0.95)
```

## Related packages

[flooded](https://github.com/NewGraphEnvironment/flooded) delineates
floodplain extents from DEMs and stream networks — use it to generate
the AOI polygons that fly selects photos for.

## Documentation

Full walkthrough with priority selection at the [airphoto selection
vignette](https://newgraphenvironment.github.io/fly/articles/airphoto-selection.html).
