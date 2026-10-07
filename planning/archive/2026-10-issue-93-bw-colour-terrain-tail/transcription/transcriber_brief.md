# Logbook transcription brief

You are transcribing scanned aerial-photography flight logbook pages (British Columbia, 1960s–2000s) into a CSV.
The images are in the directory named in your task. Read EVERY image file in that directory with the Read tool,
and transcribe EVERY line of every page that records an exposure/frame range.

Rules — these matter:
- Use ONLY the images. Do not open any other file, repository, issue, note, or website, and do not search for the
  rolls. Do not spawn subagents.
- Transcribe what is written. Where you infer something that is not written, say so in `note` ("Inference, not
  written: ...").
- Do not guess a digit. If a value cannot be read, leave the interpreted field blank and set `legibility` to
  `partial` or `illegible`, describing the doubt in `note`.

Write a CSV (RFC 4180, double-quoted strings, header row) to `<your directory>/rows.csv` with exactly these columns:

| column | meaning |
|---|---|
| file | the image file name, exactly |
| film_roll | the part of the file name before `__` (e.g. `bc5285`) |
| page_rolls | the roll identifier(s) as written on the page header |
| frames_final | the FINAL exposure numbers this line covers, as a range `a-b` or a single number `a`. Final numbers are the ones assigned to the processed film (often a separate "FINAL" or red-ink column); field/exposure counter numbers are NOT finals. Blank if the line has no final numbers |
| frame_from | integer first final number of the line (blank if none) |
| frame_to | integer last final number of the line (blank if none) |
| height_as_written | the flying-height entry for this line exactly as written ("18.0", "ditto", "16.5 MSL", ...) |
| height_header | the column header of that height field exactly as printed/written (e.g. "TRUE HEIGHT (M'/M.S.L.)") |
| height_ft_interpreted | the height in FEET as a plain number, ONLY where the unit is established by the header or entry. These forms usually give thousands of feet above mean sea level, so "18.0" under an M'/M.S.L. header is 18000. Resolve "ditto"/" marks to the value they repeat. Blank if the unit cannot be established or the value is unreadable |
| focal_as_written | the lens focal length as written on the page (e.g. `6"`, `152.4`, `12"`), blank if none |
| focal_mm | focal length in mm (6" = 153, 12" = 305, 3.5" = 88; otherwise as written in mm), blank if none written. Do NOT infer it from a camera model |
| scale_as_written | any photo scale written on the page, verbatim, with where it is written if it is not on the line (e.g. "1:15,840 (title)"). Blank if none |
| legibility | `clear`, `partial` or `illegible` for this line |
| note | anything that affects reading: sheet n of m, camera, strips, overwritten numbers, reflights, cancelled lines, your doubts |

One row per logbook line that carries a final frame range or a height. If a page has no such lines (cover sheet,
index, blank), write one row for it with only `file`, `film_roll`, `page_rolls`, `legibility` and a `note`
saying what the page is.

When finished, reply with ONLY: the path of rows.csv, the number of rows, and the number of images read.
