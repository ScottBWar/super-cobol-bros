# SUPER COBOL BROS.

An ASCII, side-scrolling platformer in the spirit of the original
*Super Mario Bros.* — written in **100% GnuCOBOL**. No C, no game
libraries, no shelling out. Just `cobc`, curses-backed screen I/O, and a
1959 business language doing something it was absolutely not designed for.

```
SCORE 0000400  COINSx02  MARIOx03  1-1  TIME 396
--------------------------------------------------------------------------------
                                                                     ooooo
                      ?
                                               @
                              |
              ooo             |         G
======================================================================   =======
======================================================================   =======
```

Run, jump, stomp Goombas, collect coins, grab a mushroom to grow, ride
moving platforms across pits, and reach the flag. Four hand-authored
levels of increasing difficulty.

---

## Build

Requires **GnuCOBOL 3.1.2+** (`cobc`).

```sh
# macOS
brew install gnucobol
# Debian / Ubuntu
sudo apt install gnucobol

./build.sh          # compiles to ./super-cobol-bros
```

`build.sh` runs `cobc -x -free -Wall -I src/copy` — it compiles clean with
zero warnings.

## Play

```sh
./super-cobol-bros
```

Needs a terminal at least **80 columns × 24 rows**. If the terminal is
smaller the game prints a message and exits without garbling your shell.

### Controls

| Key            | Action                                        |
|----------------|-----------------------------------------------|
| `A` / `←`      | move left                                     |
| `D` / `→`      | move right                                    |
| `W` / `space` / `↑` | jump                                     |
| `Q` / `Esc`    | quit (always restores the terminal)           |

Press **space** on the title screen to start; space also confirms the
level-complete, game-over and victory screens.

### The glyphs

| Glyph | Thing            | Glyph | Thing               |
|-------|------------------|-------|---------------------|
| `@`   | you (small)      | `o`   | coin                |
| `O@`  | you (big)        | `&`   | Goomba (stomp it)   |
| `=`   | ground / brick   | `m`   | mushroom (grow!)    |
| `#`   | hard block       | `^`   | spikes (deadly)     |
| `\|`  | pipe             | `F`   | goal flag           |
| `?`   | question block   | `-`   | moving platform     |

Colour is an enhancement only — every glyph is distinct, so the game is
fully playable on a monochrome terminal.

---

## Testing

```sh
./super-cobol-bros --selftest   # headless assertion suite (34 tests)
./tests/run-tests.sh            # build + selftest + render + pty smoke
```

The **self-test** is the real regression net: it exercises the physics,
collision, combat, camera and level-loader logic directly, with no
terminal required, printing `PASS`/`FAIL` per case and exiting non-zero on
any failure.

Two handy headless inspection modes (no terminal needed):

```sh
./super-cobol-bros --dump1      # print a level's opening frame as text
./super-cobol-bros --dump4      # (--dump1 .. --dump4)
./super-cobol-bros --demo       # auto-run level 1-1 and print the frame
```

### Manual playtest checklist

- [ ] Jump arc feels weighty (rises, hangs, falls) and lands reliably.
- [ ] No screen flicker while running (dirty-cell renderer).
- [ ] Standing on a moving platform carries you along with it.
- [ ] Stomping a Goomba kills it and gives a small bounce.
- [ ] A side/below hit shrinks a big player, or kills a small one.
- [ ] Bonking a `?` block from below yields a coin or a mushroom.
- [ ] Falling into a pit or running out of time costs a life.
- [ ] Losing all lives → GAME OVER; clearing level 1-4 → victory.
- [ ] The terminal is intact after every exit path (quit, win, game over).

---

## Level file format

Levels are plain-text **data** files in `levels/`, parsed at runtime by the
loader — they are not code, and are editable in any text editor. (The
helper `tools/make_levels.py` regenerates them, but the `.lvl` files are
the source of truth the game reads.)

```
# lines starting with '#' are comments (header/entity sections only)
NAME 1-1
WIDTH 220          # world width in columns (<= 240)
TIME 400           # starting timer
GRID               # <-- the 22 grid rows begin on the NEXT line
<exactly 22 rows, verbatim, top row first>
PLATFORM <id> <col> <row> <axis H|V> <range> <speed>   # optional, after grid
```

Grid legend:

```
space empty   =  ground/brick(solid)   #  hard block(solid)   |  pipe(solid)
?  question block   o  coin   P  player spawn   G  goomba
M  mushroom (pre-placed)   ^  spikes   F  goal flag   !  flag pole (decor)
```

**The `GRID` marker** is required: it tells the parser exactly where the 22
grid rows start, so a blank sky row (all spaces) at the top is never
mistaken for a header/comment. After the 22 rows, optional `PLATFORM`
lines define moving platforms.

The loader **fails loudly**: a bad `WIDTH`, the wrong number of grid rows,
a missing (or duplicate) spawn `P` or flag `F`, or exceeding a table
capacity is reported with the file line and reason instead of loading a
broken level. See the fixtures in `tests/fixtures/`.

---

## Project layout

```
build.sh                 one-command build (cobc -x -free -Wall)
src/main.cob             program entry, state machine, all game logic
src/copy/                copybooks (shared data structures):
  constants.cpy            screen dims, physics tuning, glyphs, colours
  world.cpy                terrain grid + level metadata
  entities.cpy             player record + enemy/coin/platform/shroom tables
  session.cpy              score / lives / camera / input intents
  buffers.cpy              front & back screen buffers
levels/world-1-1..4.lvl  the four level data files
tools/make_levels.py     level-authoring helper (emits the .lvl files)
tests/run-tests.sh       test runner
tests/fixtures/          malformed levels the loader must reject
```

## How it works (the short version)

- **Game loop:** `ACCEPT ... WITH TIMEOUT` is *both* the non-blocking input
  read *and* the frame governor (~10 FPS). `DISPLAY ... AT LINE/COLUMN`
  positions output anywhere. That's the whole real-time engine.
- **Rendering:** a 22×80 back buffer is composed each frame (terrain slice +
  entities + player), diffed against a front buffer, and only the changed
  cells are drawn — no full-screen clear, no flicker.
- **Camera:** the player is kept inside a horizontal dead-zone; the world
  (200+ columns) scrolls past the 80-column viewport.
- **Everything is integer / character-cell.** Score is `PIC 9(7)` — an exact
  ledger, no floats anywhere.

See `NOTES.md` for the tuned physics constants and the GnuCOBOL gotchas hit
along the way.

---

*Written in COBOL. Yes, really.*
