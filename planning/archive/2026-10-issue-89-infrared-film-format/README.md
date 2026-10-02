## Outcome

Infrared film (`Film - BW IR`, `Film - Colour IR`; 3,825 frames on 32 rolls) was `unknown_format` with empty footprints. The 9-inch format was established before the media values were added to `fly_film_media()`, under a rule pre-registered in `findings.md`, with three witnesses: adjacent-frame spacing (fly#60's instrument), thumbnail aspect and collar (fly#23's reference), and the camera named on 27 hand-read logbook pages.

As registered, the rule stopped: four rolls' spacing sat below the window. A smaller format makes implied overlap lower still, so the contradiction carried no format information. The user approved Amendment 1, written after the data and recorded as such; it names those rolls `fits_no_format` and makes a pass require that 5 in and 70 mm fail.

The fly#53 rotation campaign was re-run for the 26 IR rolls it had recorded `legs_unscorable` only because their footprints were empty. `bcc23` now ships at 270. The rotation script's date stamping was fixed along the way, and the #54/#58/#65/#80 generators were pinned to the film set their shipped tables were measured over.

Code-check took four rounds plus the plan review. Every round from 2 on found published prose that had dropped a producer's scope — the reading, the denominator, the population — rounds 3 and 4 inside the previous fix. It ended by giving every quoted figure a producer line and a test.

Round 3 also found 56 out-of-band IR frames on three right-height/wrong-scale roll-heights. They are filed as fly#91 and are out of scope here.

## Measurement

- **Window.** 0.557-0.780, the central 95% over 2,481 in-band random BW/colour frames. Control (a): median 0.635 at 9 in. Control (b): median 0.343 at 5 in, outside the window.
- **Control (c), the base rate.** 5.76% of 6,680 BW/colour rolls fall outside the window on the nominal reading; 13 (0.19%) are at or below 0.30, all flown 1972-1979.
- **W1, spacing.** 27 pass, 1 ambiguous (`bcf517`), 4 `fits_no_format` (`bcf07060`, `bci3`, `bci95063`, `bci96066`), 0 contradicts.
- **W2, thumbnails.** 4 rolls pass, 422 thumbnails, 0 declined.
- **W3, logbooks.** 6 rolls write 9 x 9 or name an RC 10. 11 name only serials, and those serials also flew 9-inch BW/colour rolls. 0 contradict.
- **#54 band on IR.** 3,769 frames reported, 56 outside the band, 0 slip-repairable.
- **Rotations.** 57 rolls ship, up from 56. Every non-IR row of all five `film_rotations*.csv` is unchanged.
- **Wrong turns kept.**
  - The registered W1 definition, and the escalation it forced.
  - Five published figures corrected by review, each one a figure copied rather than re-read: 5.75% for 5.76%; 0.19-0.27 quoted for both readings; "square 23 cm frames"; "the fly#60/#72 class" for two roll-heights neither rule reaches; 0.0915 for 0.0916.

## Evidence

`data-raw/.cache/irfilm_run*.log`, `data-raw/.cache/filmrot_*.log`, `data-raw/.cache/fulltest_89*.log` (gitignored, local). The shipped record is `inst/extdata/infrared_film_*.csv` and `inst/notes/camera-formats.md`, "Infrared film is the 9-inch negative (fly#89)".

Closed by: PR for branch `89-infrared-film-film-bw-ir-film-colour-ir`
