      *> ==========================================================
      *>  session.cpy  --  game / session state and the HUD state.
      *>  SCORE is PIC 9(7): exact integer points. No floats live
      *>  anywhere in this game -- a score is a ledger too.
      *> ==========================================================
       01  SESSION.
           05  GAME-STATE     PIC X(10) VALUE "TITLE".
      *>       TITLE PLAY DYING LEVELCLEAR GAMEOVER WIN QUIT
           05  SCORE          PIC 9(7)  VALUE 0.
           05  COINS          PIC 9(3)  VALUE 0.
           05  LIVES          PIC 9(2)  VALUE 3.
           05  CUR-LEVEL      PIC 9(2)  VALUE 1.
           05  TIME-LEFT      PIC 9(4)  VALUE 0.
           05  CAMERA-X       PIC 9(4)  VALUE 1.  *> world col at screen col 1
           05  FRAME-COUNTER  PIC 9(9)  VALUE 0.
           05  TICK-ACC       PIC 9(2)  VALUE 0.

      *> ---- signed physics constants (data items, not level-78) ----
       01  PHYS.
           05  JUMP-IMPULSE   PIC S9(4) VALUE -3.
           05  STOMP-BOUNCE   PIC S9(4) VALUE -2.

      *> ---- per-frame input intents (set by READ-INPUT) ----
       01  INPUT-FLAGS.
           05  WANT-LEFT      PIC X VALUE "N".
           05  WANT-RIGHT     PIC X VALUE "N".
           05  WANT-JUMP      PIC X VALUE "N".
           05  WANT-QUIT      PIC X VALUE "N".
           05  WANT-START     PIC X VALUE "N".
