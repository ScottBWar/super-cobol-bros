      *> ==========================================================
      *>  entities.cpy  --  player record + dynamic entity tables
      *>  Fixed capacities on purpose (COBOL likes static tables);
      *>  the level loader rejects any level that overflows them.
      *> ==========================================================

       01  PLAYER.
           05  P-X            PIC S9(4)  VALUE 0.   *> world column (feet)
           05  P-Y            PIC S9(4)  VALUE 0.   *> world row    (feet)
           05  P-VX           PIC S9(4)  VALUE 0.
           05  P-VY           PIC S9(4)  VALUE 0.
           05  P-ON-GROUND    PIC X      VALUE "N".
           05  P-SIZE         PIC X      VALUE "S". *> S small / B big
           05  P-STATE        PIC X(5)   VALUE "ALIVE".
           05  P-FACING       PIC X      VALUE "R".
           05  P-INVULN       PIC 9(3)   VALUE 0.
           05  P-MOVE-TIMER   PIC 9(2)   VALUE 0.

       01  ENEMIES.
           05  ENEMY OCCURS 32 TIMES.
               10  E-X          PIC S9(4).
               10  E-Y          PIC S9(4).
               10  E-VX         PIC S9(4).
               10  E-ALIVE      PIC X.          *> Y / N
               10  E-TYPE       PIC X.          *> G goomba
               10  E-MIN        PIC 9(4).       *> patrol left bound
               10  E-MAX        PIC 9(4).       *> patrol right bound
               10  E-PHASE      PIC 9(2).       *> move-every-N-frames counter
       01  ENEMY-COUNT          PIC 9(3) VALUE 0.

       01  COINS-TBL.
           05  COIN OCCURS 128 TIMES.
               10  C-X          PIC 9(4).
               10  C-Y          PIC 9(4).
               10  C-GOT        PIC X.          *> Y / N
       01  COIN-COUNT           PIC 9(4) VALUE 0.

       01  PLATFORMS.
           05  PLAT OCCURS 16 TIMES.
               10  PL-X         PIC S9(4).
               10  PL-Y         PIC S9(4).
               10  PL-HOME-X    PIC S9(4).
               10  PL-HOME-Y    PIC S9(4).
               10  PL-AXIS      PIC X.          *> H / V
               10  PL-RANGE     PIC 9(3).
               10  PL-DIR       PIC S9   VALUE 1.
               10  PL-SPEED     PIC 9(2) VALUE 1.
               10  PL-WIDTH     PIC 9(2) VALUE 3.
               10  PL-DX        PIC S9(2) VALUE 0. *> this-frame carry delta
               10  PL-DY        PIC S9(2) VALUE 0.
       01  PLAT-COUNT           PIC 9(3) VALUE 0.

       01  SHROOMS.
           05  SHROOM OCCURS 8 TIMES.
               10  M-X          PIC S9(4).
               10  M-Y          PIC S9(4).
               10  M-VX         PIC S9(4).
               10  M-VY         PIC S9(4).
               10  M-ACTIVE     PIC X.          *> Y / N
       01  SHROOM-COUNT         PIC 9(3) VALUE 0.
