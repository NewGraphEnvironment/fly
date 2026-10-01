# Findings — Photo parallax as a witness of the surface the camera saw at the photo date (#82)

## Issue context

## Problem

fly#80 measured that sizing a frame from MRDEM's bare-earth DTM rather than its DSM moves it a weighted median 0.17% of width (95th 0.46%), and found that whether a DSM would be the *right* surface depends on whether the canopy it carries (radar 2011–2015, lidar 2019–2025) existed when the photo was taken. The only instrument used for that was VRI stand origin with a linear height-age curve — a model, not an observation of the photo date. Under it a DSM is worse than the DTM on about 15% of 1970s frames where the canopy matters.

Nothing in fly#80 observes the surface the camera actually saw.

## A public instrument that does

The photos themselves. fly already correlates adjacent-frame thumbnails (`data-raw/georef_calibrate-corner_mapping.R`). For two frames adjacent by number, the image shift Δ between them and the air base B give the height of the imaged surface below the camera, `H − e_seen = f · B / Δ`, at the photo date.

Catalogue centroids are noisy, so per frame this is weak. fly#65's design applies: a within-roll slope of the implied surface on the predicted canopy offset (`DSM − DTM` under the frame), where a slope of 1 means the canopy was seen and 0 means bare earth.

## What is not known

- Whether thumbnail resolution resolves a shift of a few tenths of a percent.
- Whether centroid error averages out within a roll at the canopy offsets that occur (median a few metres).

## Approach

Measure before deciding, as fly#58, fly#65 and fly#80 did: fix the rule before any frame is measured, use synthetic controls, and report the slope by decade.


## Errors Encountered

| Error | Resolution |
|-------|------------|
