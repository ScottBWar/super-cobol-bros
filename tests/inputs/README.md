# Scripted input runs

The game reads one keystroke per frame via `ACCEPT ... WITH TIMEOUT`, so it
can be driven deterministically by feeding a byte stream to stdin under a
pseudo-terminal. `tests/run-tests.sh` does exactly this.

Because the game needs a real terminal for curses screen mode, you drive it
with `script(1)` to allocate a pty, e.g. on macOS:

```
( sleep 1; printf 'w'; sleep 0.3; printf 'ddddddddd'; sleep 0.3; printf 'q' ) \
  | ( TERM=xterm-256color script -q /dev/null ./super-cobol-bros )
```

Key legend (one byte per keypress):

| bytes        | effect                                      |
|--------------|---------------------------------------------|
| `w` / space  | jump  (also: start game / confirm on menus) |
| `a`          | move left                                   |
| `d`          | move right                                  |
| `q`          | quit (restores the terminal)                |

Example sequences:

- `q`                          — quit straight from the title screen.
- `w` then `ddddddddd` then `q` — start, run right, quit.
- `w` then `dddwdddwddd` then `q` — start, run-and-jump, quit.

The **authoritative** regression net is the headless assertion suite
(`./super-cobol-bros --selftest`), which exercises the physics, collision,
combat and level-loader logic with no terminal required.
