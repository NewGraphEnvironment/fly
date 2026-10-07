# Findings — Settle the disputed height digit on bc77087's logbook page 1 (#101)

## Issue context

**If we do it:** we learn whether any logbook page puts the ground under a catalogued height. That is fly#95's open question, and the answer would decide whether `bc77087`'s 57 frames ship a corrected height through the existing `factor != 1` route. **If we never do:** the transcription keeps 3.8, `bc77087` stays `misplaced` on a contested read, and fly#95's "no page does" stays true only as transcribed.

## Problem

`bc77087` page 1 (`data-raw/.cache/logbooks/bc77087__bc77087_1.jpg`, frames 1-60, "Swan Lake Grinrod") writes a TRUE HEIGHT whose first digit is disputed.
- fly#93's blind reader read **3.8**, which matches the catalogue's 1,158 m.
- fly#97's blind reader declined to choose, leaning **7.8**: a flat top and a single descending stroke.

Read as 7,800 ft (2,377 m), the median over the 57 frames of the height less MRDEM is 1,114 m, within 4% of 1,158 m. So the generator's relation would be `ground_plus` and W2 `ground`. fly#97's rule would then stop for a decision on the package's shape. 2,377 / 1,158 = 2.05 is close to the x2 slip, so the page alone would not settle the datum.

See `inst/notes/terrain-correction.md`, "What the frames under the terrain covered".

## What to do

Get a third, independent read of that one digit: a fresh blind reader, or the original scan at higher resolution if the province holds one. Fix the rule for what a 7.8 would ship before reading it, as fly#60/#72/#93/#95/#97 did.

`bc77070` was flown the same week on the same project at 3,800 ft, and its page reads clear. That is context, not evidence about this digit.

Related: fly#97, fly#95, fly#99.
