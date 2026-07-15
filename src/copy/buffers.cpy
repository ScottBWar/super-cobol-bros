      *> ==========================================================
      *>  buffers.cpy  --  double-buffered play-field for the
      *>  dirty-cell renderer. BACK = what should show this frame,
      *>  FRONT = what is currently on screen. We DISPLAY only the
      *>  cells that differ, then copy BACK -> FRONT. No flicker.
      *>  Buffers are the VISIBLE 22x80 viewport (already camera-mapped).
      *> ==========================================================
       01  BACK-BUF.
           05  BB-ROW OCCURS 22 TIMES.
               10  BB-CELL OCCURS 80 TIMES PIC X.
       01  FRONT-BUF.
           05  FB-ROW OCCURS 22 TIMES.
               10  FB-CELL OCCURS 80 TIMES PIC X.

      *> HUD is diffed as a whole 80-char line.
       01  HUD-TEXT           PIC X(80) VALUE SPACES.
       01  HUD-PREV           PIC X(80) VALUE ALL X"01".
