#!/bin/sh
# Builds the slides and the pdfpc speaker-notes file into build/.
set -e
cd "$(dirname "$0")"
mkdir -p build
typst compile presentation.typ build/presentation-16-9.pdf
typst eval 'query(<pdfpc-file>).first().value' --in presentation.typ > build/presentation-16-9.pdfpc
