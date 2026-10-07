#!/usr/bin/env bash
# fly#101: build the third blind reader's directory. Every page whole, plus four quadrant crops
# of every page at 2x (Lanczos), each overlapping its neighbours by 10% of the page so that no
# line is cut at a boundary. The crops are mechanical and identical for every page, so no line
# is singled out. bc77070_4 is withheld: it names the same project and place as bc77087_1.
# Usage: make_reader_dir.sh <repo root> <output dir>
set -euo pipefail
repo="$1"; out="$2"
src="$repo/data-raw/.cache/logbooks"
pages="bc77087__bc77087_1 bc77087__bc77087_2 bc77087__bc77087_3 bc77087__bc77087_4 bc77087__bc77087_5
bc77070__bc77070_1 bc77070__bc77070_2 bc77070__bc77070_3"
mkdir -p "$out"
for p in $pages; do
  f="$src/$p.jpg"
  [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
  cp "$f" "$out/$p.jpg"
  w=$(magick identify -format '%w' "$f"); h=$(magick identify -format '%h' "$f")
  cw=$(( w * 60 / 100 )); ch=$(( h * 60 / 100 ))
  xo=$(( w - cw )); yo=$(( h - ch ))
  i=0
  for off in "0 0" "$xo 0" "0 $yo" "$xo $yo"; do
    i=$((i + 1)); set -- $off
    magick "$f" -crop "${cw}x${ch}+$1+$2" +repage -filter Lanczos -resize 200% \
      "$out/${p}__quadrant${i}_x2.png"
  done
done
ls "$out" | wc -l
