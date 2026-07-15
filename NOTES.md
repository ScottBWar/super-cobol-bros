# NOTES — implementation log

Design decisions, the final tuned constants, and the GnuCOBOL gotchas hit
while building SUPER COBOL BROS. Future-me will want these.

## Tuned physics constants

All in `src/copy/constants.cpy` (and the two signed ones in
`session.cpy`). Units are **character cells per frame** at ~10 FPS.

| Constant        | Value | Why                                              |
|-----------------|-------|--------------------------------------------------|
| `FRAME-TIMEOUT` | 1     | tenths of a second on the input ACCEPT → ~10 FPS |
| `GRAVITY`       | 1     | +1 downward velocity per airborne frame          |
| `MAX-FALL`      | 2     | terminal velocity; keeps falls readable          |
| `JUMP-IMPULSE`  | -3    | apex ≈ 3+2+1 = 6 cells; clears pipes and gaps    |
| `STOMP-BOUNCE`  | -2    | small hop after squashing a Goomba               |
| `RUN-SPEED`     | 1     | **must be 1** — see below                        |
| `INTENT-FRAMES` | 3     | coyote window so held-key auto-repeat feels smooth |
| `INVULN-FRAMES` | 15    | post-shrink mercy invulnerability (blinks)       |
| `FRAMES-PER-TICK` | 10  | timer ticks down once per ~10 frames (~1s)       |

**Why `RUN-SPEED` must be 1:** the terminal delivers key *presses*, not
holds, so we get at most one keystroke per frame. Coin / enemy / goal
collisions are exact single-cell overlaps (`C-X = P-X`, `E-Y = P-Y`, …). If
the player moved 2 cells per frame it could *skip over* a coin's column or
an enemy's cell between frames and never register the overlap. Moving one
cell per frame guarantees the player visits every column, so nothing is
skipped. Horizontal collision, landing and head-bonk are all resolved
**one cell at a time** for the same reason (axis-separate, step-by-step).

Jump *feel* is the single most important thing to tune. `-3 / 1 / 2` gives
a weighty arc that rises fast, hangs briefly and clears a 2-tall pipe or a
~6-wide gap. Retune here first if it feels floaty or stiff.

## Architecture choices (deviations from the spec, and why)

- **Free-format source** (`-free`), not fixed format. The spec recommended
  fixed format for copybook portability across compilers, but this project
  is GnuCOBOL-only, so that portability never matters — and free format
  removes a whole class of column-counting bugs while writing ~1500 lines.
  The choice is applied consistently to every file.
- **One program + copybooks, logic in paragraphs** — not separate
  `CALL`ed sub-programs with `LINKAGE`. The spec explicitly permits
  collapsing subsystems into paragraphs, and it avoids the real hazard of
  passing large *mutable* tables (the world grid, entity tables, buffers)
  by reference across program boundaries every frame. Data lives in
  copybooks (`constants / world / entities / session / buffers`); logic is
  grouped into clearly-named paragraphs by subsystem (physics, collision,
  enemyai, render, levelload, screens). Correctness and clarity first.
- **All game logic is screen-independent.** Only the thin render (`DISPLAY
  ... AT`) and input (`ACCEPT ... WITH TIMEOUT`) layer touches curses.
  Everything else — physics, collision, AI, level parsing, the compositor
  that fills the back buffer — runs with no terminal, which is what makes
  the 34-case `--selftest` suite possible and is where the confidence
  comes from.
- **`GRID` marker in the level format.** The spec's proposed format had
  comments starting with `#`, but `#` is also the hard-block glyph, and the
  top grid row (sky) is legitimately all-blank — so "skip blanks/comments
  until the grid" is ambiguous. An explicit `GRID` line marks exactly where
  the 22 verbatim rows begin. Documented in the README.

## GnuCOBOL gotchas (the ones that cost time)

1. **`GO TO <exit-label>` across paragraphs breaks `PERFORM`.** The first
   build looked fine and then blew the stack with runaway recursion. Cause:
   paragraphs were invoked with `PERFORM SINGLE-PARA` but used
   `GO TO SINGLE-PARA-EXIT`, where the exit label was a *separate following
   paragraph*. The `GO TO` branches out of the performed range, so the
   `PERFORM` never returns and control cascades into whatever paragraph is
   next in the source. **Fix:** use `EXIT PARAGRAPH` (returns cleanly from
   the performed paragraph). Every early-exit in the code uses it now.

2. **Screen-clear clause is `WITH BLANK SCREEN`, not `WITH ERASE`.**
   `DISPLAY x AT LINE n COLUMN m WITH ERASE` fails to parse
   ("expecting LINE or SCREEN"). `WITH BLANK SCREEN` (or `WITH ERASE EOS`)
   is the accepted form in GnuCOBOL 3.2.

3. **`ACCEPT ... WITH TIMEOUT` status can lie in odd environments.** On a
   real terminal, a key press returns `CRT STATUS = 0` and a timeout
   returns `8001`. In a headless pseudo-tty (like CI), a real key can come
   back tagged `8001` *with the character still delivered*. So `READ-INPUT`
   trusts the **delivered byte** for character keys (`a/d/w/q`) regardless
   of status, uses the status only for arrow/ESC keys (which carry no
   character), and guards space-jump behind a genuine `0` status so a
   timeout that blanks the field can't cause phantom jumps. A genuine
   timeout leaves the pre-set `X"00"` sentinel, which matches no action.

4. **Shared work variables across `PERFORM`ed loops.** `UPDATE-WORLD` uses
   `WS-I` for its entity loops, so a test (or any caller) that itself loops
   on `WS-I` while calling `UPDATE-WORLD` gets its counter clobbered. The
   integration test loops on a dedicated `WS-J`. The live game loop uses
   `PERFORM UNTIL GAME-STATE = "QUIT"` and is unaffected.

5. **Terminal size query:** `ACCEPT n FROM LINES` / `ACCEPT n FROM COLUMNS`
   work and are used for the 80×24 guard — but only reject when the size is
   reported and genuinely too small (0 = unknown → allow), so odd hosts
   don't get a false refusal.

## Testing approach

- `--selftest` — 34 headless assertions: gravity/landing/jump arc,
  horizontal + head-bonk collision, coins & the 100-coins-→-life rule,
  stomp vs side-hit (small dies / big shrinks), mushroom growth, the
  moving-platform *carry* case, camera clamp, all four levels load, the
  loader rejects three kinds of malformed file, a scripted 80-frame
  playthrough of 1-1, the render compositor, reaching the flag, and pit
  death. This is the regression net.
- `--dump[1-4]` / `--demo` — render a frame to plain text so the compositor
  is inspectable without a terminal (also how the levels were eyeballed).
- `tests/run-tests.sh` — build + selftest + per-level render smoke + a
  pseudo-tty run that confirms the terminal is restored on quit.

## Known limitations / future polish

- Variable jump height (short hop vs full hop) is not implemented — single
  fixed impulse. Would need reliable key-release, which terminals don't give.
- Airborne coins are best collected near the jump apex (where vertical speed
  is ≤1); a fast 2-cell fall could pass a coin's row between frames. Levels
  place airborne coins accordingly.
- Enemies are Goombas only (patrol + wall/ledge turn + stomp). No shells,
  no projectiles.
- One mushroom power-up state (small/big). No fire flower.
