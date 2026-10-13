#!/bin/sh
# Starts the talk in pdfpc. Rebuilds the slides first if they are older than the source.
# Extra arguments go straight to pdfpc. Usual fixes:
#   ./present.sh -s               presenter and slides on the wrong screens: swap them
#   ./present.sh -S               only one screen (no projector, or mirroring is on)
#   ./present.sh -w both          rehearse: both views in windows on the laptop
#   ./present.sh -M               list monitors. -1 <presenter> -2 <projector> picks them by
#                                 name, but macOS shows "(null)" names: prefer -s there.
#   ./present.sh -P 7             restart at slide 7 after a crash
# On the projector, turn mirroring off (macOS: Displays settings) or pdfpc sees one screen.
set -e
cd "$(dirname "$0")"
pdf=build/presentation-16-9.pdf
if [ ! -f "$pdf" ] || [ presentation.typ -nt "$pdf" ] || [ -n "$(find bench/results assets -newer "$pdf" 2>/dev/null)" ]; then
  ./compile.sh
fi
# 20 min talk, timer turns red for the last 3 minutes.
exec pdfpc --duration=20 --last-minutes=3 "$@" "$pdf"
