## Outcome

fly#95 left nine roll-heights (157 frames under terrain at or above the catalogued aircraft) where
adjacent-frame spacing rejected nominal scale and the height read as above ground alike. fly#97 measured
the overlap the photos themselves show, with fly#82's patch matcher seeded by a padded masked
cross-correlation that reads no centroid. The logbook pages of the five untranscribed rolls were read blind
first. The rule was fixed before any thumbnail was matched, and amended twice before any of the nine was
measured (A1 after a smoke run, A2 from a plan review).

On five roll-heights the photos show the catalogue's centroid step is longer than the air base, so
spacing's rejection of nominal said nothing about scale; nominal stands, unrefuted rather than confirmed.
By their logbooks against MRDEM, 107 frames on four of them are not over the ground photographed. Two
roll-heights were flown at ~85% overlap, where the readings cannot be told apart. **No code change.**

What was learned:
- **Spacing's window is no evidence about scale on an older roll without the photos.**
- **`bc77087`'s page-1 digit (3.8 or 7.8) is the open question.** Read as 7.8, it would be the first page to
  put the ground under a catalogued height.
- **The prose was the defect class again.** Five code-check rounds found claims stated over a wider set
  than their producer computed, each round inside the previous round's fix. One round also caught a
  counterfactual asserted rather than run. It ended when every figure lived in one copy (the note), the
  other copies carried figure-free claims, and the new text was enumerated.

## Measurement

- **Controls** (run before the nine; the A2 gates are the ones in force):
  - synthetic known shifts: 50 of 50 matched at overlap 0.35-0.90, error under 1e-4;
  - floor: 0.20 none, 0.25 all (synthetic shifts are one-signed; positive shifts reach about 0.18);
  - unrelated pairs: 0 of 36 compared matched;
  - crew-written overlaps on 9 rolls: median +0.018;
  - `bc85054`: flagged, |D| 0.548;
  - tau 0.220 in log step-error units, against a ceiling of 0.223. The instrument cannot see a step error
    under about x1.25.
- **The nine.** Five `step_overstated`. Their photos overlap 0.62-0.81 where the step says 0.11-0.42.
  Under any height the logbook allows, the step is x1.25-x2.70 the air base. `bc77070` passes by 0.006;
  on `bc77087` the result rests on its 3.8 read. Two `indistinguishable`, two `too_few_pairs`.
- **Corroboration outside the gates:**
  - `bc77070` 271/272 reads 0.316, where its page writes "Only 40% overlap";
  - `bc77026` reads 0.807, against its page's "75.9%";
  - `bc80117` reads 0.840, against its page's "80%".
- **Wrong turns kept:**
  - the 0.20 synthetic gate, unmatched for reasons of geometry (A1);
  - an outcome that was `p_img > p_agl` restated (A2);
  - the A2 gloss "the images reject the above-ground reading" (round 1);
  - "1.9-3.0x" being `k` at nominal (round 1);
  - a 7.8 counterfactual reasoned to "read_other" when the generator says `ground` (round 3);
  - place distances first written from memory;
  - two broken probes, both mine: empty strings read as present, and `bc7718`'s distance taken over the
    census set only.
- **Byte-identity:**
  - every re-run of the script from cache: all five CSVs unchanged;
  - the generator, before and after the appended logbook rows: the roll tables unchanged;
  - fly#95's logbook counts moved (576 to 689 frames read) and its verdicts did not.
- **Tests.** Full suite FAIL 0, PASS 5,698.

The durable record is `inst/notes/terrain-correction.md`, "What the frames under the terrain covered".

## Evidence

- `planning/archive/2026-10-issue-97-image-overlap/run_*.log`
- `review-*.md`, `claims_enumerated*.md`
- `transcription/batch*`

Closed by: PR for branch 97-frames-under-terrain-where-spacing-rejec · follow-up fly#99
