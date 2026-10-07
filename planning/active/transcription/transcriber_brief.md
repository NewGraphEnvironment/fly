# Logbook transcription brief

You are transcribing scanned aerial-photography flight logbook pages (British Columbia, 1970s) into CSV.
The images are in the directory named in your task. Each page is there whole (`<page>.jpg`) and as nine
overlapping crops enlarged 2x (`<page>__row<r>_col<c>_x2.png`, row 1 at the top, column 1 at the left).
The crops add nothing that is not on the page; they make small handwriting easier to see. Read EVERY
image file in that directory with the Read tool. To list the directory, read nothing: its files are
named in your task.

Rules — these matter:
- Use ONLY the Read tool, and ONLY on the image files named in your task. Do not open any other file,
  repository, issue, note, or website, do not search for the rolls, do not use Bash, Glob or Grep, and
  do not spawn subagents.
- Transcribe what is written. Where you infer something that is not written, say so in `note` ("Inference, not
  written: ...").
- Do not guess a digit. If a value cannot be read, leave the interpreted field blank and set `legibility` to
  `partial` or `illegible`, describing the doubt in `note`.
- There is no expected answer. Read the pages.

You cannot write files. Reply with the CSV as text, in ONE fenced code block that starts with the line
"```csv rows.csv" and ends with "```". RFC 4180, every string double-quoted, header row first, exactly
these columns:

| column | meaning |
|---|---|
| file | the page's image file name (`<page>.jpg`), exactly, even where you read the line on a crop |
| film_roll | the part of the file name before `__` (e.g. `bc5285`) |
| page_rolls | the roll identifier(s) as written on the page header |
| frames_final | the FINAL exposure numbers this line covers, as a range `a-b` or a single number `a`. Final numbers are the ones assigned to the processed film (often a separate "FINAL" or red-ink column); field/exposure counter numbers are NOT finals. Blank if the line has no final numbers |
| frame_from | integer first final number of the line (blank if none) |
| frame_to | integer last final number of the line (blank if none) |
| height_as_written | the flying-height entry for this line exactly as written ("18.0", "ditto", "16.5 MSL", ...) |
| height_digits | for a height written as a figure: the figure's digits and decimal point only, with every digit you cannot read with certainty written as `?` (e.g. `12.5`, `?2.5`, `1?.0`). For a ditto line, the figure it repeats, written the same way. Blank if no height |
| height_header | the column header of that height field exactly as printed/written (e.g. "TRUE HEIGHT (M'/M.S.L.)") |
| height_ft_interpreted | the height in FEET as a plain number, ONLY where the unit is established by the header or entry and every digit is certain. These forms usually give thousands of feet above mean sea level, so "18.0" under an M'/M.S.L. header is 18000. Resolve "ditto"/" marks to the value they repeat. Blank if the unit cannot be established or any digit is uncertain |
| leading_digit_confidence | for EVERY line whose height is written as a figure (not a ditto): `clear` if the first digit can be read as only one digit; `uncertain` if it could be more than one; `illegible` if it cannot be read. For a ditto line, `ditto`. Blank if no height |
| leading_digit_alternatives | where `leading_digit_confidence` is `uncertain` or `illegible`, every digit it could be, separated by `/` (e.g. `5/6`), most likely first only if one is more likely. MUST be blank where it is `clear` |
| focal_as_written | the lens focal length as written on the page (e.g. `6"`, `152.4`, `12"`), blank if none |
| focal_mm | focal length in mm (6" = 153, 12" = 305, 3.5" = 88; otherwise as written in mm), blank if none written. Do NOT infer it from a camera model |
| scale_as_written | any photo scale written on the page, verbatim, with where it is written if it is not on the line (e.g. "1:15,840 (title)"). Blank if none |
| legibility | `clear`, `partial` or `illegible` for this line |
| note | anything that affects reading: sheet n of m, camera, strips, overwritten numbers, reflights, cancelled lines, your doubts |

One row per logbook line that carries a final frame range or a height. If a page has no such lines (cover sheet,
index, blank), write one row for it with only `file`, `film_roll`, `page_rolls`, `legibility` and a `note`
saying what the page is.

After the code block, write one line: the number of rows and the number of images you read. Nothing else.
