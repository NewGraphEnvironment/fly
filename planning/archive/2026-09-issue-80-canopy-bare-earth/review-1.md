# Plan review 1 (Plan agent, 2026-09-30) — findings and disposition

Full review text was returned in-reply (the Plan agent has no Write tool); condensed here with
what was done about each. Verified before acting where a probe was cheap.

| id | finding | disposition |
|---|---|---|
| B1 | Materiality on W_dtm vs T_dsm fires on bare earth (inland 95th is 3.18% with no canopy); W_dsm beats W_dtm against T_dsm by construction (side ∝ H − e, so W_dtm/W_dsm − 1 = c̄/(agl − c̄)) | **Accepted.** Amendment 1: materiality on d_c = side_dtm/side_dsm − 1 from `fly_footprint()` on both surfaces; the ray-cast asks only whether a DSM degrades the rectangle model (ρ_dsm vs ρ_dtm) |
| B2 | "Wrong by the same amount, the other way" is wrong: DTM err = c_then/agl, DSM err = (c_then − c_now)/agl, so the DSM loses only where c_now > 2·c_then | **Accepted**, algebra checked. Epoch criterion rewritten on that condition, from VRI stand origin |
| B3 | DSM − DTM may be NRCan's model; DTM may keep residual canopy; DTM + Meta double-counts; Meta weak north of 51.6°N (GEDI); HRDEM is the better witness | **Accepted.** Provenance confirmed from the NRCan spec (DTM = GLO-30 minus removal model outside lidar). Stage 1 probes: on lidar cells MRDEM DSM−DTM equals HRDEM's to 0.1 m; at Revelstoke (radar cells) MRDEM DTM sits 9.2 m above lidar ground (87 cells). Lidar-over-radar probe added (150 windows). Meta demoted to reported, not decisive; T_meta dropped |
| G1 | Coarse nearest census biased in the tail; heights from `flying_height` carry the slip | **Accepted.** Census at ~250 m `-r average`, used only to stratify; nominal agl = scale × focal; materiality from a weighted probability sample; census calibrated against 30 m on the sample |
| G2 | "Forested frames" denominator drawn from the instrument | **Accepted.** Denominator is all DEM-eligible film (#58) |
| G3 | Sample needs design weights | **Accepted.** Stratified by census shift × scale, weights N_h / n_h |
| G4 | Reuse #65's cached frames | **Accepted, first-order:** measured c̄ under each #65 frame replaces the uniform canopy in the note's table |
| G5 | No canopy positive control; no-canopy stratum vacuous | **Accepted.** Flat canopy control, 0/40 m canopy-edge step with convergence, ring-invariance control on a subset; no-canopy stratum dropped (Stage 1 floor sites instead) |
| G6 | A DSM can move a frame across the height checks | **Accepted.** Admitted only where `dem_agl` + `reported` under both; changes counted and documented; the test pins it |
| G7 | DSM over sea unprobed | **Done** in Stage 1: DSM = DTM over all six readable sea sites |
| G8 | Census cannot ship 1.44 M rows | **Accepted.** Ships binned |
| G9 | Docs list incomplete (vignette, note :824, :870) | **Accepted**, added to Phase 4 |
| G10 | Pin versions | **Done.** ETags logged; caches keyed on them |
| O1 | Freeze the rule after the probes | Amendment 1 written after the Stage 1 probes and before any frame is sized |
| O2 | Leave the #65 script untouched or verify the extraction | **Accepted — untouched.** The new script evaluates only the named function definitions from it (`fns_from()`); no copy, no edit |
| A1 | Population is 1963–2019, 62% from 1985 | Recorded; the plan's "1930s" was wrong |
| A2 | X-band claim uncited | Replaced by the lidar-over-radar measurement |
| A4 | Over-claiming ground costlier than under-claiming | Signed errors reported beside |err|; rule stays symmetric, stated |
| A5 | 1% justification | Stated: #58's ~2% per-corner error is the scale below which a bias is not worth a column |
| S1 | Epoch depth | VRI stand origin (minimum tier). Photo parallax (adjacent-frame shift = f·B/Δ) filed as a follow-up |
| S2 | Add "unresolved" | **Accepted** |
| AC1 | Flat-offset fixture test is tautological | **Accepted.** Test uses a DSM tall enough to move a frame across `fly_height_ratio_band()` |
| AC2–AC4 | Producer line per figure; mutate prose in restore-the-bug; pre-register witness disagreement | Accepted; AC4 is in Amendment 1 |
