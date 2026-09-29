## Outcome

Every `fly_georef()` output now carries one alpha band: grayscale is 2 bands (Gray + Alpha,
no NoData) where it was 1 band with `-dstnodata 0`, and RGB stays 4. `mask = "border"` with
`srcnodata` is accepted, and `srcnodata` is the fallback for frames whose mask declined.
`fly_georef_warp_opts()` was always an `else if`, so the v0.11.0 refusal guarded a pair GDAL
never received. `georef_one()` warns when a mask declines with no fallback. Absorbs #68 and
#69. The lesson is in the measurement: the headline number moved twice under review, and
the old defect turned out to be a different mechanism than the issue said.

## Measurement

All on the 182 grayscale frames of the 264-thumbnail calibration set, sf's GDAL 3.8.5,
macOS. Produced by `data-raw/mask_measure-interior_zeros.R`.

- **The old default path rewrote true black as 1 and deleted none.**
  - Axis-aligned warp: 161 frames, 242,439 px, median 47 per frame, max 3.6%
    (bcb94081_042).
  - 30° warp: 41 frames, 12,682 px, median 13 per frame, max 0.26%.
  - Deletion happened only where `srcnodata = "0"` was also given.
  - #68's "Windows shifts 0 to 1" is a GDAL behaviour. 3.8.5 does it silently; other
    builds print it.
- **Wrong turns, kept:**
  1. The first figure was source-side ("161 frames lost black"). It was presented as
     *deletion*, which is the wrong mechanism.
  2. Review flagged it as a proxy. The replacement measured one bearing (30°) and quoted
     41 frames as the loss.
  3. The next review showed an axis-aligned warp of isotropic pixels loses every opaque 0.
     So the source-side count was right for bearingless frames, and the 30° figure is the
     lower end.
- **Mask decline rate:** 0 of 264, and 0 of all 10,105 thumbnails in the directory. The
  fallback never fires on thumbnails; its reach is non-8-bit scans.
- **Downstream:** `stac_airphoto_bc`'s `03_cog.py` refuses gray+alpha, because rasterio
  drops the alpha colorinterp without `alpha="YES"`. Its own guard caught it; filed
  stac_airphoto_bc#36. A private sibling that pins the warp options was filed separately.

## Evidence

`data-raw/.cache/mask_interior_zeros*` (gitignored, regenerate with the script). The
reviews are `review-*.md` in this directory.

Closed by: PR (see branch `56-georef-output-contract-a-real-alpha-band`)
