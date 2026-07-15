      *> ==========================================================
      *>  constants.cpy  --  SUPER COBOL BROS.
      *>  Screen geometry, physics tuning, capacities, glyphs.
      *>  Every magic number and glyph lives here: re-skin or
      *>  re-tune the game by editing this one file.
      *>  (Free-format source; see NOTES.md for why.)
      *> ==========================================================

      *> ---- frame / screen geometry (1-indexed, curses coords) ----
       78  FRAME-TIMEOUT        VALUE 1.      *> tenths of a sec => ~10 FPS
       78  SCR-COLS             VALUE 80.
       78  SCR-ROWS             VALUE 24.
       78  HUD-LINE             VALUE 1.
       78  FIELD-TOP-LINE       VALUE 2.      *> play field = screen rows 2..23
       78  FIELD-ROWS           VALUE 22.     *> world is 22 rows tall
       78  MSG-LINE             VALUE 24.
       78  MAX-WORLD-WIDTH      VALUE 240.

      *> ---- physics (cells / frame). Tuned; see NOTES.md ----
       78  GRAVITY              VALUE 1.
       78  MAX-FALL             VALUE 2.
       78  RUN-SPEED            VALUE 1.       *> 1 cell/frame: player visits
      *>                                         every column so exact-column
      *>                                         coin/enemy hits never skip.
       78  INTENT-FRAMES        VALUE 3.      *> coyote window for held-key feel
       78  INVULN-FRAMES        VALUE 15.
       78  FRAMES-PER-TICK      VALUE 10.     *> ~1 game-second at 10 FPS
       78  DEADZONE-LEFT        VALUE 30.     *> camera dead-zone (screen cols)
       78  DEADZONE-RIGHT       VALUE 50.

      *> JUMP-IMPULSE and STOMP-BOUNCE are signed; kept as data items
      *> (some GnuCOBOL builds dislike signed level-78 literals).

      *> ---- entity table capacities ----
       78  MAX-ENEMIES          VALUE 32.
       78  MAX-COINS            VALUE 128.
       78  MAX-PLATFORMS        VALUE 16.
       78  MAX-SHROOMS          VALUE 8.
       78  MAX-LEVELS           VALUE 4.

      *> ---- scoring ----
       78  SCORE-COIN           VALUE 200.
       78  SCORE-STOMP          VALUE 100.
       78  SCORE-SHROOM         VALUE 1000.
       78  SCORE-BLOCK-COIN     VALUE 200.
       78  TIME-BONUS-PER       VALUE 50.
       78  COINS-PER-LIFE       VALUE 100.

      *> ---- glyphs (pure ASCII: never depend on Unicode) ----
       78  G-EMPTY              VALUE " ".
       78  G-PLAYER-S           VALUE "@".
       78  G-PLAYER-B-TOP       VALUE "O".
       78  G-PLAYER-B-BOT       VALUE "@".
       78  G-GROUND             VALUE "=".
       78  G-HARD               VALUE "#".
       78  G-PIPE               VALUE "|".
       78  G-QUESTION           VALUE "?".
       78  G-USED               VALUE "u".   *> spent ? block (solid)
       78  G-COIN               VALUE "o".
       78  G-GOOMBA             VALUE "&".
       78  G-SHROOM             VALUE "m".
       78  G-SPIKE              VALUE "^".
       78  G-FLAG               VALUE "F".
       78  G-POLE               VALUE "!".   *> flag pole
       78  G-PLATFORM           VALUE "-".   *> moving platform surface
       78  G-SPAWN              VALUE "P".

      *> ---- curses colours (GnuCOBOL FOREGROUND-COLOR values) ----
       78  CLR-BLACK            VALUE 0.
       78  CLR-BLUE             VALUE 1.
       78  CLR-GREEN            VALUE 2.
       78  CLR-CYAN             VALUE 3.
       78  CLR-RED              VALUE 4.
       78  CLR-MAGENTA          VALUE 5.
       78  CLR-YELLOW           VALUE 6.
       78  CLR-WHITE            VALUE 7.

      *> ---- CRT STATUS codes returned by ACCEPT ... WITH TIMEOUT ----
       78  K-OK                 VALUE 0.
       78  K-UP                 VALUE 2003.
       78  K-DOWN               VALUE 2004.
       78  K-ESC                VALUE 2005.
       78  K-LEFT               VALUE 2009.
       78  K-RIGHT              VALUE 2010.
       78  K-TIMEOUT            VALUE 8001.
