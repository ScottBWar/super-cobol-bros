#!/usr/bin/env bash
# ==========================================================
#  SUPER COBOL BROS. -- test runner
#  1. builds the game
#  2. runs the headless --selftest assertion suite (the real
#     regression net: physics, collision, combat, level loader)
#  3. smoke-tests the renderer via --dump for every level
#  4. drives a scripted-input playthrough under a pseudo-tty
#     and checks the terminal is restored on quit
# ==========================================================
set -uo pipefail
cd "$(dirname "$0")/.."

GAME=./super-cobol-bros
fails=0

section() { printf "\n=== %s ===\n" "$1"; }
ok()      { printf "  ok   %s\n" "$1"; }
bad()     { printf "  FAIL %s\n" "$1"; fails=$((fails+1)); }

section "build"
if ./build.sh >/dev/null 2>&1; then ok "build"; else bad "build"; exit 1; fi

section "self-test suite"
if "$GAME" --selftest; then ok "selftest exit 0"; else bad "selftest nonzero exit"; fi

section "renderer smoke test (--dump)"
# The opening frame shows the 80-col viewport at the world's left edge:
# the player (@), ground (=) and the HUD are visible; the goal flag sits
# further right and scrolls into view later.
for n in 1 2 3 4; do
  out="$("$GAME" --dump$n 2>&1)"
  if echo "$out" | grep -q "@" && echo "$out" | grep -q "=" \
     && echo "$out" | grep -q "1-$n"; then
    ok "level 1-$n renders (player, ground, HUD)"
  else
    bad "level 1-$n dump missing expected content"
  fi
done

section "demo auto-play"
out="$("$GAME" --demo 2>&1)"
if echo "$out" | grep -q "SCORE"; then ok "demo runs"; else bad "demo failed"; fi

# ---- scripted-input playthrough under a pseudo-terminal --------------
# The game only enters curses mode with a real terminal, so we allocate
# one with script(1). Input scripts live in tests/inputs/. This checks
# the game launches, plays, and RESTORES THE TERMINAL on quit.
section "scripted-input pseudo-tty run"
pty_run() { # $1 = feed-commands subshell body, $2 = alarm secs
  ( eval "$1" ) | ( TERM=xterm-256color \
      perl -e "alarm ${2:-8}; exec 'script','-q','/dev/null','$GAME'" ) 2>&1
}
if ! command -v perl >/dev/null 2>&1 || ! command -v script >/dev/null 2>&1; then
  echo "  skip (perl/script not available)"
else
  out="$(pty_run "sleep 0.8; printf q; sleep 1.5" 6)"
  pkill -f "[s]uper-cobol-bros" 2>/dev/null
  if echo "$out" | LC_ALL=C tr -cd '[:print:]\n' \
       | grep -q "Thanks for playing"; then
    ok "quit from title restores the terminal"
  else
    bad "clean-quit restore message not observed"
  fi
fi

section "result"
if [ "$fails" -eq 0 ]; then
  echo "ALL TEST GROUPS PASSED"
  exit 0
else
  echo "$fails TEST GROUP(S) FAILED"
  exit 1
fi
