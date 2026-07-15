#!/usr/bin/env bash
# ==========================================================
#  SUPER COBOL BROS. -- build script
#  Compiles the whole game to a single ./super-cobol-bros
#  binary with GnuCOBOL (cobc).  Pure COBOL, no other langs.
# ==========================================================
set -euo pipefail

cd "$(dirname "$0")"

COBC="${COBC:-cobc}"
SRC="src/main.cob"
OUT="super-cobol-bros"

if ! command -v "$COBC" >/dev/null 2>&1; then
  echo "error: '$COBC' (GnuCOBOL) not found on PATH." >&2
  echo "Install it, e.g.:  brew install gnucobol   (macOS)" >&2
  echo "                   sudo apt install gnucobol (Debian/Ubuntu)" >&2
  exit 1
fi

echo ">> Building $OUT with $($COBC --version | head -1)"

# -x            : build an executable program
# -free         : free-format source (see NOTES.md)
# -Wall         : all warnings
# -I src/copy   : copybook include path
"$COBC" -x -free -Wall -I src/copy -o "$OUT" "$SRC"

echo ">> Done. Run ./$OUT to play, or ./$OUT --selftest for the test suite."
