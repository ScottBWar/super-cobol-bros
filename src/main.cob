      *> ==========================================================
      *>  SUPER COBOL BROS.   --   main.cob
      *>  An ASCII side-scrolling platformer in pure GnuCOBOL.
      *>  Written in COBOL. Yes, really.
      *>
      *>  Architecture: one program, data in copybooks, logic in
      *>  named paragraphs grouped by subsystem (physics / collision
      *>  / enemyai / render / levelload / screens).  All game logic
      *>  is screen-independent so --selftest can exercise it with no
      *>  terminal.  See NOTES.md for design rationale.
      *>  Free-format source.
      *> ==========================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SUPER-COBOL-BROS.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           CRT STATUS IS KEY-STATUS.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT LVL-FILE ASSIGN TO LVL-FNAME
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS LVL-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  LVL-FILE.
       01  LVL-REC              PIC X(256).

       WORKING-STORAGE SECTION.
           COPY constants.
           COPY world.
           COPY entities.
           COPY session.
           COPY buffers.

      *> ---- terminal / input plumbing ----
       01  KEY-STATUS           PIC 9(4)  VALUE 0.
       01  IN-KEY               PIC X     VALUE SPACE.
       01  DISP-CHAR            PIC X     VALUE SPACE.
       01  WS-TERM-LINES        PIC 9(4)  VALUE 0.
       01  WS-TERM-COLS         PIC 9(4)  VALUE 0.
       01  WS-CMDLINE           PIC X(256) VALUE SPACES.

      *> ---- generic work vars ----
       01  WS-I                 PIC S9(4) VALUE 0.
       01  WS-J                 PIC S9(4) VALUE 0.
       01  WS-N                 PIC S9(4) VALUE 0.
       01  WS-STEPS             PIC S9(4) VALUE 0.
       01  WS-DIR               PIC S9(4) VALUE 0.
       01  WS-BR                PIC S9(4) VALUE 0.
       01  WS-SC                PIC S9(4) VALUE 0.
       01  WS-SL                PIC S9(4) VALUE 0.
       01  WS-WC                PIC S9(4) VALUE 0.
       01  WS-FG                PIC 9(2)  VALUE 7.
       01  WS-HI                PIC 9     VALUE 0.
       01  WS-DONE              PIC X     VALUE "N".
       01  WS-BLOCKED           PIC X     VALUE "N".
       01  WS-TMPR              PIC S9(4) VALUE 0.
       01  WS-TMPC              PIC S9(4) VALUE 0.
       01  WS-HEADROW           PIC S9(4) VALUE 0.
       01  WS-PSC               PIC S9(4) VALUE 0.
       01  WS-MAXCAM            PIC S9(4) VALUE 1.

      *> ---- IS-SOLID query in/out ----
       01  CHK-R                PIC S9(4) VALUE 0.
       01  CHK-C                PIC S9(4) VALUE 0.
       01  CHK-SOLID            PIC X     VALUE "N".
       01  CHK-GLYPH            PIC X     VALUE SPACE.

      *> ---- PLOT helper ----
       01  PLOT-R               PIC S9(4) VALUE 0.
       01  PLOT-C               PIC S9(4) VALUE 0.
       01  PLOT-G               PIC X     VALUE SPACE.

      *> ---- score helper ----
       01  SCORE-AMT            PIC 9(7)  VALUE 0.

      *> ---- level parsing ----
       01  LVL-FNAME            PIC X(64) VALUE SPACES.
       01  LVL-STATUS           PIC XX    VALUE "00".
       01  PARSE-PHASE          PIC X(4)  VALUE "HDR".
       01  LINE-NO              PIC 9(4)  VALUE 0.
       01  GRID-ROW             PIC 9(4)  VALUE 0.
       01  LOAD-ERROR           PIC X     VALUE "N".
       01  LOAD-MSG             PIC X(80) VALUE SPACES.
       01  SPAWN-SEEN           PIC 9(3)  VALUE 0.
       01  FLAG-SEEN            PIC 9(3)  VALUE 0.
       01  TK1                  PIC X(40) VALUE SPACES.
       01  TK2                  PIC X(40) VALUE SPACES.
       01  TK3                  PIC X(40) VALUE SPACES.
       01  TK4                  PIC X(40) VALUE SPACES.
       01  TK5                  PIC X(40) VALUE SPACES.
       01  TK6                  PIC X(40) VALUE SPACES.
       01  TK7                  PIC X(40) VALUE SPACES.

      *> ---- HUD edited fields ----
       01  ED-SCORE             PIC 9(7).
       01  ED-COINS             PIC 9(2).
       01  ED-LIVES             PIC 9(2).
       01  ED-TIME              PIC 9(3).
       01  ED-LVL               PIC 9.

      *> ---- screen text line ----
       01  SCREEN-LINE          PIC X(80) VALUE SPACES.

      *> ---- self-test bookkeeping ----
       01  TEST-TOTAL           PIC 9(4)  VALUE 0.
       01  TEST-FAILS           PIC 9(4)  VALUE 0.
       01  TEST-NAME            PIC X(32) VALUE SPACES.
       01  EXP-NUM              PIC S9(9) VALUE 0.
       01  GOT-NUM              PIC S9(9) VALUE 0.
       01  RUN-MODE             PIC X(8)  VALUE "GAME".
       01  WS-DUMPLVL           PIC 9     VALUE 1.

       PROCEDURE DIVISION.

      *> ==========================================================
      *>  ENTRY
      *> ==========================================================
       MAIN-ENTRY.
           MOVE "GAME" TO RUN-MODE
           ACCEPT WS-CMDLINE FROM COMMAND-LINE
           INSPECT WS-CMDLINE CONVERTING
              "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
              TO "abcdefghijklmnopqrstuvwxyz"
           PERFORM DETECT-RUN-MODE
           EVALUATE RUN-MODE
               WHEN "TEST"
                   PERFORM RUN-SELFTEST
                   IF TEST-FAILS > 0
                      MOVE 1 TO RETURN-CODE
                   ELSE
                      MOVE 0 TO RETURN-CODE
                   END-IF
               WHEN "DUMP"
                   PERFORM RUN-DUMP
               WHEN "DEMO"
                   PERFORM RUN-DEMO
               WHEN "KEYTEST"
                   PERFORM RUN-KEYTEST
               WHEN OTHER
                   PERFORM GAME-MAIN
           END-EVALUATE
           STOP RUN.

      *>   Command-line flags (headless helpers for testing/inspection):
      *>     --selftest         run the assertion suite
      *>     --dump[1-4]        print level N's opening frame as text
      *>     --demo             auto-run level 1 to the right, then print
       DETECT-RUN-MODE.
           MOVE 1 TO WS-DUMPLVL
           MOVE 0 TO WS-N
           INSPECT WS-CMDLINE TALLYING WS-N FOR ALL "selftest"
           IF WS-N > 0
              MOVE "TEST" TO RUN-MODE
           END-IF
           MOVE 0 TO WS-N
           INSPECT WS-CMDLINE TALLYING WS-N FOR ALL "demo"
           IF WS-N > 0
              MOVE "DEMO" TO RUN-MODE
           END-IF
           MOVE 0 TO WS-N
           INSPECT WS-CMDLINE TALLYING WS-N FOR ALL "keytest"
           IF WS-N > 0
              MOVE "KEYTEST" TO RUN-MODE
           END-IF
           MOVE 0 TO WS-N
           INSPECT WS-CMDLINE TALLYING WS-N FOR ALL "dump"
           IF WS-N > 0
              MOVE "DUMP" TO RUN-MODE
              MOVE 0 TO WS-N
              INSPECT WS-CMDLINE TALLYING WS-N FOR ALL "2"
              IF WS-N > 0 MOVE 2 TO WS-DUMPLVL END-IF
              MOVE 0 TO WS-N
              INSPECT WS-CMDLINE TALLYING WS-N FOR ALL "3"
              IF WS-N > 0 MOVE 3 TO WS-DUMPLVL END-IF
              MOVE 0 TO WS-N
              INSPECT WS-CMDLINE TALLYING WS-N FOR ALL "4"
              IF WS-N > 0 MOVE 4 TO WS-DUMPLVL END-IF
           END-IF.

       RUN-DUMP.
           MOVE WS-DUMPLVL TO CUR-LEVEL
           PERFORM LOAD-LEVEL
           IF LOAD-ERROR = "Y"
              DISPLAY "load error: " FUNCTION TRIM(LOAD-MSG)
              MOVE 2 TO RETURN-CODE
              EXIT PARAGRAPH
           END-IF
           MOVE 1 TO CAMERA-X
           PERFORM DUMP-FRAME.

       RUN-DEMO.
           MOVE 1 TO CUR-LEVEL
           PERFORM LOAD-LEVEL
           MOVE "PLAY" TO GAME-STATE
           MOVE 0 TO FRAME-COUNTER
           PERFORM VARYING WS-J FROM 1 BY 1 UNTIL WS-J > 45
              MOVE "N" TO WANT-LEFT
              MOVE "Y" TO WANT-RIGHT
              MOVE "N" TO WANT-JUMP
              IF FUNCTION MOD(WS-J, 9) = 0
                 MOVE "Y" TO WANT-JUMP
              END-IF
              ADD 1 TO FRAME-COUNTER
              IF GAME-STATE = "PLAY"
                 PERFORM UPDATE-WORLD
              END-IF
           END-PERFORM
           DISPLAY "--- demo: level 1-1 after 45 auto-frames ---"
           PERFORM DUMP-FRAME.

      *>   Print the composed play field as plain text (no curses),
      *>   so the renderer's output is inspectable without a terminal.
       DUMP-FRAME.
           PERFORM COMPOSE-BACK-BUFFER
           PERFORM RENDER-HUD-TEXT
           DISPLAY FUNCTION TRIM(HUD-TEXT)
           MOVE ALL "-" TO SCREEN-LINE
           DISPLAY SCREEN-LINE
           PERFORM VARYING WS-BR FROM 1 BY 1 UNTIL WS-BR > FIELD-ROWS
              MOVE SPACES TO SCREEN-LINE
              PERFORM VARYING WS-SC FROM 1 BY 1 UNTIL WS-SC > SCR-COLS
                 MOVE BB-CELL(WS-BR, WS-SC) TO SCREEN-LINE(WS-SC:1)
              END-PERFORM
              DISPLAY SCREEN-LINE
           END-PERFORM
           MOVE ALL "-" TO SCREEN-LINE
           DISPLAY SCREEN-LINE.

      *> ==========================================================
      *>  TOP-LEVEL STATE MACHINE
      *> ==========================================================
       GAME-MAIN.
           PERFORM CHECK-TERM-SIZE
           IF WS-DONE = "Y"
              EXIT PARAGRAPH
           END-IF
           MOVE "TITLE" TO GAME-STATE
           PERFORM UNTIL GAME-STATE = "QUIT"
               EVALUATE GAME-STATE
                   WHEN "TITLE"      PERFORM DO-TITLE
                   WHEN "PLAY"       PERFORM PLAY-FRAME
                   WHEN "DYING"      PERFORM DO-DYING
                   WHEN "LEVELCLEAR" PERFORM DO-LEVELCLEAR
                   WHEN "GAMEOVER"   PERFORM DO-GAMEOVER
                   WHEN "WIN"        PERFORM DO-WIN
                   WHEN OTHER        MOVE "QUIT" TO GAME-STATE
               END-EVALUATE
           END-PERFORM
           PERFORM RESTORE-TERMINAL.
       GAME-MAIN-EXIT.
           EXIT.

       CHECK-TERM-SIZE.
      *> Enter screen mode and read the size. Only refuse if the
      *> terminal reports a real, too-small size (0 = unknown => allow).
           MOVE "N" TO WS-DONE
           DISPLAY " " AT LINE 1 COLUMN 1 WITH BLANK SCREEN
           ACCEPT WS-TERM-LINES FROM LINES
           ACCEPT WS-TERM-COLS  FROM COLUMNS
           IF (WS-TERM-COLS > 0 AND WS-TERM-COLS < 80) OR
              (WS-TERM-LINES > 0 AND WS-TERM-LINES < 24)
              PERFORM RESTORE-TERMINAL
              DISPLAY "SUPER COBOL BROS. needs an 80x24 terminal."
              DISPLAY "Your terminal is "
                 WS-TERM-COLS "x" WS-TERM-LINES ". Resize and retry."
              MOVE "Y" TO WS-DONE
           END-IF.

       RESTORE-TERMINAL.
      *> Leave curses cleanly so the user's shell is never garbled.
           DISPLAY " " AT LINE MSG-LINE COLUMN 1 WITH BLANK SCREEN
           DISPLAY "Thanks for playing SUPER COBOL BROS."
              AT LINE 1 COLUMN 1.

      *> ==========================================================
      *>  PLAY : one frame = input -> update -> render
      *> ==========================================================
       PLAY-FRAME.
           ADD 1 TO FRAME-COUNTER
           PERFORM READ-INPUT
           IF WANT-QUIT = "Y"
              MOVE "QUIT" TO GAME-STATE
              EXIT PARAGRAPH
           END-IF
           PERFORM UPDATE-WORLD
           PERFORM RENDER-FRAME.
       PLAY-FRAME-EXIT.
           EXIT.

      *> ==========================================================
      *>  INPUT
      *> ==========================================================
       READ-INPUT.
           MOVE "N" TO WANT-LEFT
           MOVE "N" TO WANT-RIGHT
           MOVE "N" TO WANT-JUMP
           MOVE "N" TO WANT-QUIT
      *>   sentinel: a genuine timeout leaves IN-KEY untouched (X"00")
           MOVE X"00" TO IN-KEY
           MOVE 0 TO KEY-STATUS
           ACCEPT IN-KEY AT LINE MSG-LINE COLUMN 1
               WITH AUTO TIMEOUT FRAME-TIMEOUT NO ECHO
               ON EXCEPTION CONTINUE
           END-ACCEPT
      *>   Arrow / ESC keys arrive as a CRT STATUS code (no character).
           EVALUATE KEY-STATUS
               WHEN K-ESC      MOVE "Y" TO WANT-QUIT
               WHEN K-LEFT     MOVE "Y" TO WANT-LEFT
               WHEN K-RIGHT    MOVE "Y" TO WANT-RIGHT
               WHEN K-UP       MOVE "Y" TO WANT-JUMP
               WHEN OTHER      CONTINUE
           END-EVALUATE
      *>   Character keys are read straight from IN-KEY. We trust the
      *>   delivered byte rather than the status code: some terminals
      *>   (and headless ptys) report a timeout status even when a real
      *>   key was read. A recognised letter is never produced by a
      *>   genuine timeout (which leaves the X"00" sentinel).
           EVALUATE FUNCTION LOWER-CASE(IN-KEY)
               WHEN "a"  MOVE "Y" TO WANT-LEFT
               WHEN "d"  MOVE "Y" TO WANT-RIGHT
               WHEN "w"  MOVE "Y" TO WANT-JUMP
               WHEN "q"  MOVE "Y" TO WANT-QUIT
               WHEN " "
      *>           space = jump, but only when it is a genuine key press
      *>           (not a timeout that happened to blank the field)
                   IF KEY-STATUS = K-OK
                      MOVE "Y" TO WANT-JUMP
                   END-IF
               WHEN OTHER CONTINUE
           END-EVALUATE.

      *> ==========================================================
      *>  WORLD UPDATE  (pure logic, no screen)
      *> ==========================================================
       UPDATE-WORLD.
           PERFORM UPDATE-PLATFORMS
           PERFORM STEP-PLAYER-PHYSICS
           PERFORM UPDATE-ENEMIES
           PERFORM UPDATE-SHROOMS
           PERFORM CHECK-COINS
           PERFORM CHECK-SHROOM-COLLECT
           PERFORM CHECK-ENEMY-COLLISIONS
           PERFORM CHECK-HAZARDS
           PERFORM CHECK-GOAL
           PERFORM TICK-TIMER
           PERFORM UPDATE-CAMERA
           IF P-INVULN > 0
              SUBTRACT 1 FROM P-INVULN
           END-IF.

      *> ---- one frame of player physics --------------------------
       STEP-PLAYER-PHYSICS.
           IF P-STATE NOT = "ALIVE"
              EXIT PARAGRAPH
           END-IF
      *>   1. ground check (terrain or platform directly beneath feet)
           PERFORM PLAYER-GROUND-CHECK
      *>   2. jump
           IF WANT-JUMP = "Y" AND P-ON-GROUND = "Y"
              MOVE JUMP-IMPULSE TO P-VY
              MOVE "N" TO P-ON-GROUND
           END-IF
      *>   3. horizontal intent (decay window for continuous feel)
           IF WANT-LEFT = "Y"
              MOVE "L" TO P-FACING
              COMPUTE P-VX = -1 * RUN-SPEED
              MOVE INTENT-FRAMES TO P-MOVE-TIMER
           END-IF
           IF WANT-RIGHT = "Y"
              MOVE "R" TO P-FACING
              MOVE RUN-SPEED TO P-VX
              MOVE INTENT-FRAMES TO P-MOVE-TIMER
           END-IF
           IF P-MOVE-TIMER > 0
              PERFORM MOVE-PLAYER-HORIZONTAL
              SUBTRACT 1 FROM P-MOVE-TIMER
              IF P-MOVE-TIMER = 0
                 MOVE 0 TO P-VX
              END-IF
           ELSE
              MOVE 0 TO P-VX
           END-IF
      *>   4. gravity
           IF P-ON-GROUND = "Y"
              IF P-VY > 0
                 MOVE 0 TO P-VY
              END-IF
           ELSE
              ADD GRAVITY TO P-VY
              IF P-VY > MAX-FALL
                 MOVE MAX-FALL TO P-VY
              END-IF
           END-IF
      *>   5. vertical move
           PERFORM MOVE-PLAYER-VERTICAL
      *>   6. re-check ground for next frame's jump
           PERFORM PLAYER-GROUND-CHECK.
       STEP-PHYS-EXIT.
           EXIT.

       PLAYER-GROUND-CHECK.
           COMPUTE CHK-R = P-Y + 1
           MOVE P-X TO CHK-C
           PERFORM QUERY-SOLID
           MOVE CHK-SOLID TO P-ON-GROUND.

      *> ---- horizontal movement with axis-separate resolution ----
       MOVE-PLAYER-HORIZONTAL.
           IF P-VX = 0
              EXIT PARAGRAPH
           END-IF
           IF P-VX > 0
              MOVE 1 TO WS-DIR
              MOVE P-VX TO WS-STEPS
           ELSE
              MOVE -1 TO WS-DIR
              COMPUTE WS-STEPS = -1 * P-VX
           END-IF
           PERFORM WS-STEPS TIMES
              COMPUTE WS-TMPC = P-X + WS-DIR
      *>       block at world edges
              IF WS-TMPC < 1 OR WS-TMPC > W-WIDTH
                 EXIT PARAGRAPH
              END-IF
      *>       test every cell the player body would occupy
              MOVE "N" TO WS-BLOCKED
              MOVE WS-TMPC TO CHK-C
              MOVE P-Y TO CHK-R
              PERFORM QUERY-SOLID
              IF CHK-SOLID = "Y"
                 MOVE "Y" TO WS-BLOCKED
              END-IF
              IF P-SIZE = "B"
                 COMPUTE CHK-R = P-Y - 1
                 MOVE WS-TMPC TO CHK-C
                 PERFORM QUERY-SOLID
                 IF CHK-SOLID = "Y"
                    MOVE "Y" TO WS-BLOCKED
                 END-IF
              END-IF
              IF WS-BLOCKED = "Y"
                 EXIT PARAGRAPH
              END-IF
              MOVE WS-TMPC TO P-X
           END-PERFORM.
       MPH-EXIT.
           EXIT.

      *> ---- vertical movement with landing / head-bonk -----------
       MOVE-PLAYER-VERTICAL.
           IF P-VY = 0
              EXIT PARAGRAPH
           END-IF
           IF P-VY > 0
              MOVE 1 TO WS-DIR
              MOVE P-VY TO WS-STEPS
           ELSE
              MOVE -1 TO WS-DIR
              COMPUTE WS-STEPS = -1 * P-VY
           END-IF
           PERFORM WS-STEPS TIMES
              IF WS-DIR > 0
      *>          moving down: test cell below feet
                 COMPUTE CHK-R = P-Y + 1
                 MOVE P-X TO CHK-C
                 PERFORM QUERY-SOLID
                 IF CHK-SOLID = "Y"
                    MOVE 0 TO P-VY
                    MOVE "Y" TO P-ON-GROUND
                    EXIT PARAGRAPH
                 ELSE
                    ADD 1 TO P-Y
                 END-IF
              ELSE
      *>          moving up: test cell above head
                 COMPUTE WS-HEADROW = P-Y
                 IF P-SIZE = "B"
                    SUBTRACT 1 FROM WS-HEADROW
                 END-IF
                 COMPUTE CHK-R = WS-HEADROW - 1
                 MOVE P-X TO CHK-C
                 PERFORM QUERY-SOLID
                 IF CHK-SOLID = "Y"
                    PERFORM BONK-BLOCK
                    MOVE 0 TO P-VY
                    EXIT PARAGRAPH
                 ELSE
                    SUBTRACT 1 FROM P-Y
                 END-IF
              END-IF
           END-PERFORM.
       MPV-EXIT.
           EXIT.

      *> ---- head-bonk: spend ? blocks -> coin or mushroom --------
       BONK-BLOCK.
      *>   CHK-R / CHK-C hold the bonked cell
           IF CHK-R < 1 OR CHK-R > FIELD-ROWS
              EXIT PARAGRAPH
           END-IF
           MOVE W-CELL(CHK-R, CHK-C) TO CHK-GLYPH
           IF CHK-GLYPH = G-QUESTION
              MOVE G-USED TO W-CELL(CHK-R, CHK-C)
              IF P-SIZE = "S" AND SHROOM-COUNT < MAX-SHROOMS
                 PERFORM SPAWN-SHROOM
              ELSE
                 MOVE SCORE-BLOCK-COIN TO SCORE-AMT
                 PERFORM ADD-SCORE
                 PERFORM ADD-COIN
              END-IF
           END-IF.
       BONK-EXIT.
           EXIT.

       SPAWN-SHROOM.
           ADD 1 TO SHROOM-COUNT
           COMPUTE M-X(SHROOM-COUNT) = CHK-C
           COMPUTE M-Y(SHROOM-COUNT) = CHK-R - 1
           MOVE 1 TO M-VX(SHROOM-COUNT)
           MOVE 0 TO M-VY(SHROOM-COUNT)
           MOVE "Y" TO M-ACTIVE(SHROOM-COUNT).

      *> ==========================================================
      *>  IS-SOLID  (terrain glyph OR active platform covers cell)
      *> ==========================================================
       QUERY-SOLID.
           MOVE "N" TO CHK-SOLID
           IF CHK-R < 1 OR CHK-R > FIELD-ROWS
      *>       above the sky = open; below the field = open (a pit)
              EXIT PARAGRAPH
           END-IF
           IF CHK-C < 1 OR CHK-C > W-WIDTH
              MOVE "Y" TO CHK-SOLID
              EXIT PARAGRAPH
           END-IF
           MOVE W-CELL(CHK-R, CHK-C) TO CHK-GLYPH
           IF CHK-GLYPH = G-GROUND OR CHK-GLYPH = G-HARD OR
              CHK-GLYPH = G-PIPE OR CHK-GLYPH = G-QUESTION OR
              CHK-GLYPH = G-USED
              MOVE "Y" TO CHK-SOLID
              EXIT PARAGRAPH
           END-IF
           PERFORM PLATFORM-COVERS
           .
       QSOLID-EXIT.
           EXIT.

       PLATFORM-COVERS.
      *>   does any active platform occupy (CHK-R, CHK-C) ?
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > PLAT-COUNT
              IF CHK-R = PL-Y(WS-I) AND
                 CHK-C >= PL-X(WS-I) AND
                 CHK-C <= PL-X(WS-I) + PL-WIDTH(WS-I) - 1
                 MOVE "Y" TO CHK-SOLID
              END-IF
           END-PERFORM.

      *> ==========================================================
      *>  MOVING PLATFORMS  (carry the player standing on top)
      *> ==========================================================
       UPDATE-PLATFORMS.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > PLAT-COUNT
              PERFORM STEP-ONE-PLATFORM
           END-PERFORM.

       STEP-ONE-PLATFORM.
           MOVE 0 TO PL-DX(WS-I)
           MOVE 0 TO PL-DY(WS-I)
           IF PL-AXIS(WS-I) = "H"
              COMPUTE PL-DX(WS-I) = PL-DIR(WS-I) * PL-SPEED(WS-I)
           ELSE
              COMPUTE PL-DY(WS-I) = PL-DIR(WS-I) * PL-SPEED(WS-I)
           END-IF
      *>   is the player riding this platform? (feet just above it,
      *>   horizontally overlapping, and not moving upward)
           IF P-STATE = "ALIVE" AND P-VY >= 0 AND
              P-Y + 1 = PL-Y(WS-I) AND
              P-X >= PL-X(WS-I) AND
              P-X <= PL-X(WS-I) + PL-WIDTH(WS-I) - 1
              ADD PL-DX(WS-I) TO P-X
              ADD PL-DY(WS-I) TO P-Y
           END-IF
      *>   move the platform
           ADD PL-DX(WS-I) TO PL-X(WS-I)
           ADD PL-DY(WS-I) TO PL-Y(WS-I)
      *>   reverse at range ends (measured from home position)
           IF PL-AXIS(WS-I) = "H"
              IF PL-X(WS-I) >= PL-HOME-X(WS-I) + PL-RANGE(WS-I) OR
                 PL-X(WS-I) <= PL-HOME-X(WS-I)
                 COMPUTE PL-DIR(WS-I) = -1 * PL-DIR(WS-I)
              END-IF
           ELSE
              IF PL-Y(WS-I) >= PL-HOME-Y(WS-I) + PL-RANGE(WS-I) OR
                 PL-Y(WS-I) <= PL-HOME-Y(WS-I)
                 COMPUTE PL-DIR(WS-I) = -1 * PL-DIR(WS-I)
              END-IF
           END-IF.

      *> ==========================================================
      *>  ENEMIES  (Goomba patrol, gravity, wall/ledge turn)
      *> ==========================================================
       UPDATE-ENEMIES.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > ENEMY-COUNT
              IF E-ALIVE(WS-I) = "Y"
                 PERFORM STEP-ONE-ENEMY
              END-IF
           END-PERFORM.

       STEP-ONE-ENEMY.
      *>   gravity: fall if nothing solid below
           COMPUTE CHK-R = E-Y(WS-I) + 1
           MOVE E-X(WS-I) TO CHK-C
           PERFORM QUERY-SOLID
           IF CHK-SOLID = "N"
              ADD 1 TO E-Y(WS-I)
              IF E-Y(WS-I) > FIELD-ROWS
                 MOVE "N" TO E-ALIVE(WS-I)
              END-IF
              EXIT PARAGRAPH
           END-IF
      *>   move horizontally every other frame (slower than player)
           MOVE FRAME-COUNTER TO WS-N
           COMPUTE WS-N = FUNCTION MOD(FRAME-COUNTER, 2)
           IF WS-N NOT = 0
              EXIT PARAGRAPH
           END-IF
           COMPUTE WS-TMPC = E-X(WS-I) + E-VX(WS-I)
      *>   wall ahead?  patrol bound?  ledge ahead?
           MOVE E-Y(WS-I) TO CHK-R
           MOVE WS-TMPC TO CHK-C
           PERFORM QUERY-SOLID
           IF CHK-SOLID = "Y" OR
              WS-TMPC < E-MIN(WS-I) OR WS-TMPC > E-MAX(WS-I)
              COMPUTE E-VX(WS-I) = -1 * E-VX(WS-I)
              EXIT PARAGRAPH
           END-IF
      *>   ledge-turn (polish): don't walk into empty air
           COMPUTE CHK-R = E-Y(WS-I) + 1
           MOVE WS-TMPC TO CHK-C
           PERFORM QUERY-SOLID
           IF CHK-SOLID = "N"
              COMPUTE E-VX(WS-I) = -1 * E-VX(WS-I)
              EXIT PARAGRAPH
           END-IF
           MOVE WS-TMPC TO E-X(WS-I).
       STEP-ENEMY-EXIT.
           EXIT.

      *> ==========================================================
      *>  MUSHROOMS  (emerge, fall, slide, reverse at walls)
      *> ==========================================================
       UPDATE-SHROOMS.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > SHROOM-COUNT
              IF M-ACTIVE(WS-I) = "Y"
                 PERFORM STEP-ONE-SHROOM
              END-IF
           END-PERFORM.

       STEP-ONE-SHROOM.
      *>   gravity
           COMPUTE CHK-R = M-Y(WS-I) + 1
           MOVE M-X(WS-I) TO CHK-C
           PERFORM QUERY-SOLID
           IF CHK-SOLID = "N"
              ADD 1 TO M-Y(WS-I)
              IF M-Y(WS-I) > FIELD-ROWS
                 MOVE "N" TO M-ACTIVE(WS-I)
              END-IF
              EXIT PARAGRAPH
           END-IF
      *>   slide horizontally, bounce off walls
           COMPUTE WS-TMPC = M-X(WS-I) + M-VX(WS-I)
           MOVE M-Y(WS-I) TO CHK-R
           MOVE WS-TMPC TO CHK-C
           PERFORM QUERY-SOLID
           IF CHK-SOLID = "Y" OR WS-TMPC < 1 OR WS-TMPC > W-WIDTH
              COMPUTE M-VX(WS-I) = -1 * M-VX(WS-I)
           ELSE
              MOVE WS-TMPC TO M-X(WS-I)
           END-IF.
       STEP-SHROOM-EXIT.
           EXIT.

      *> ==========================================================
      *>  COLLECTIBLES & COMBAT
      *> ==========================================================
       CHECK-COINS.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > COIN-COUNT
              IF C-GOT(WS-I) = "N"
                 IF C-X(WS-I) = P-X AND
                    (C-Y(WS-I) = P-Y OR
                     (P-SIZE = "B" AND C-Y(WS-I) = P-Y - 1))
                    MOVE "Y" TO C-GOT(WS-I)
                    MOVE SCORE-COIN TO SCORE-AMT
                    PERFORM ADD-SCORE
                    PERFORM ADD-COIN
                 END-IF
              END-IF
           END-PERFORM.

       CHECK-SHROOM-COLLECT.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > SHROOM-COUNT
              IF M-ACTIVE(WS-I) = "Y"
                 IF M-X(WS-I) = P-X AND
                    (M-Y(WS-I) = P-Y OR
                     (P-SIZE = "B" AND M-Y(WS-I) = P-Y - 1))
                    MOVE "N" TO M-ACTIVE(WS-I)
                    MOVE SCORE-SHROOM TO SCORE-AMT
                    PERFORM ADD-SCORE
                    IF P-SIZE = "S"
                       MOVE "B" TO P-SIZE
                    END-IF
                 END-IF
              END-IF
           END-PERFORM.

       CHECK-ENEMY-COLLISIONS.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > ENEMY-COUNT
              IF E-ALIVE(WS-I) = "Y"
                 PERFORM ONE-ENEMY-COLLISION
              END-IF
           END-PERFORM.

       ONE-ENEMY-COLLISION.
      *>   overlap with feet or (big) head?
           IF E-X(WS-I) NOT = P-X
              EXIT PARAGRAPH
           END-IF
           IF E-Y(WS-I) = P-Y OR
              (P-SIZE = "B" AND E-Y(WS-I) = P-Y - 1)
              IF P-VY > 0 AND E-Y(WS-I) = P-Y
      *>          stomp: falling onto the enemy
                 MOVE "N" TO E-ALIVE(WS-I)
                 MOVE STOMP-BOUNCE TO P-VY
                 MOVE "N" TO P-ON-GROUND
                 MOVE SCORE-STOMP TO SCORE-AMT
                 PERFORM ADD-SCORE
              ELSE
                 PERFORM PLAYER-TAKES-HIT
              END-IF
           END-IF.
       OEC-EXIT.
           EXIT.

       PLAYER-TAKES-HIT.
           IF P-INVULN > 0
              EXIT PARAGRAPH
           END-IF
           IF P-SIZE = "B"
              MOVE "S" TO P-SIZE
              MOVE INVULN-FRAMES TO P-INVULN
           ELSE
              PERFORM PLAYER-DIE
           END-IF.
       PTH-EXIT.
           EXIT.

       CHECK-HAZARDS.
      *>   spikes at feet/head, or a fall into a pit
           IF P-Y > FIELD-ROWS
              PERFORM PLAYER-DIE
              EXIT PARAGRAPH
           END-IF
           IF P-Y >= 1 AND P-Y <= FIELD-ROWS AND
              P-X >= 1 AND P-X <= W-WIDTH
              IF W-CELL(P-Y, P-X) = G-SPIKE
                 PERFORM PLAYER-DIE
                 EXIT PARAGRAPH
              END-IF
           END-IF
           IF P-SIZE = "B" AND P-Y - 1 >= 1 AND
              P-X >= 1 AND P-X <= W-WIDTH
              IF W-CELL(P-Y - 1, P-X) = G-SPIKE
                 PERFORM PLAYER-DIE
              END-IF
           END-IF.
       HAZ-EXIT.
           EXIT.

       CHECK-GOAL.
           IF P-Y >= 1 AND P-Y <= FIELD-ROWS AND
              P-X >= 1 AND P-X <= W-WIDTH
              IF W-CELL(P-Y, P-X) = G-FLAG
                 MOVE "LEVELCLEAR" TO GAME-STATE
              END-IF
           END-IF.

       PLAYER-DIE.
           MOVE "DYING" TO P-STATE
           MOVE "DYING" TO GAME-STATE.

      *> ==========================================================
      *>  TIMER / CAMERA / SCORING helpers
      *> ==========================================================
       TICK-TIMER.
           ADD 1 TO TICK-ACC
           IF TICK-ACC >= FRAMES-PER-TICK
              MOVE 0 TO TICK-ACC
              IF TIME-LEFT > 0
                 SUBTRACT 1 FROM TIME-LEFT
              END-IF
              IF TIME-LEFT = 0
                 PERFORM PLAYER-DIE
              END-IF
           END-IF.

       UPDATE-CAMERA.
           COMPUTE WS-PSC = P-X - CAMERA-X + 1
           IF WS-PSC > DEADZONE-RIGHT
              COMPUTE CAMERA-X = CAMERA-X + (WS-PSC - DEADZONE-RIGHT)
           END-IF
           IF WS-PSC < DEADZONE-LEFT
              COMPUTE CAMERA-X = CAMERA-X - (DEADZONE-LEFT - WS-PSC)
           END-IF
           COMPUTE WS-MAXCAM = W-WIDTH - SCR-COLS + 1
           IF WS-MAXCAM < 1
              MOVE 1 TO WS-MAXCAM
           END-IF
           IF CAMERA-X < 1
              MOVE 1 TO CAMERA-X
           END-IF
           IF CAMERA-X > WS-MAXCAM
              MOVE WS-MAXCAM TO CAMERA-X
           END-IF.

       ADD-SCORE.
           ADD SCORE-AMT TO SCORE
              ON SIZE ERROR MOVE 9999999 TO SCORE
           END-ADD.

       ADD-COIN.
           ADD 1 TO COINS
           IF COINS >= COINS-PER-LIFE
              COMPUTE COINS = COINS - COINS-PER-LIFE
              IF LIVES < 99
                 ADD 1 TO LIVES
              END-IF
           END-IF.

      *> ==========================================================
      *>  RENDER  (compose back buffer, diff, paint changed cells)
      *> ==========================================================
       RENDER-FRAME.
           PERFORM COMPOSE-BACK-BUFFER
           PERFORM DIFF-RENDER
           PERFORM RENDER-HUD.

       COMPOSE-BACK-BUFFER.
           MOVE SPACES TO BACK-BUF
      *>   terrain slice
           PERFORM VARYING WS-BR FROM 1 BY 1 UNTIL WS-BR > FIELD-ROWS
              PERFORM VARYING WS-SC FROM 1 BY 1 UNTIL WS-SC > SCR-COLS
                 COMPUTE WS-WC = CAMERA-X + WS-SC - 1
                 IF WS-WC >= 1 AND WS-WC <= W-WIDTH
                    MOVE W-CELL(WS-BR, WS-WC) TO BB-CELL(WS-BR, WS-SC)
                 END-IF
              END-PERFORM
           END-PERFORM
      *>   dynamic entities, painted over terrain
           PERFORM COMPOSE-PLATFORMS
           PERFORM COMPOSE-COINS
           PERFORM COMPOSE-SHROOMS
           PERFORM COMPOSE-ENEMIES
           PERFORM COMPOSE-PLAYER.

       COMPOSE-PLATFORMS.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > PLAT-COUNT
              MOVE PL-Y(WS-I) TO PLOT-R
              MOVE G-PLATFORM TO PLOT-G
              PERFORM VARYING WS-N FROM 0 BY 1
                 UNTIL WS-N > PL-WIDTH(WS-I) - 1
                 COMPUTE PLOT-C = PL-X(WS-I) + WS-N
                 PERFORM PLOT-WC
              END-PERFORM
           END-PERFORM.

       COMPOSE-COINS.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > COIN-COUNT
              IF C-GOT(WS-I) = "N"
                 MOVE C-Y(WS-I) TO PLOT-R
                 MOVE C-X(WS-I) TO PLOT-C
                 MOVE G-COIN TO PLOT-G
                 PERFORM PLOT-WC
              END-IF
           END-PERFORM.

       COMPOSE-SHROOMS.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > SHROOM-COUNT
              IF M-ACTIVE(WS-I) = "Y"
                 MOVE M-Y(WS-I) TO PLOT-R
                 MOVE M-X(WS-I) TO PLOT-C
                 MOVE G-SHROOM TO PLOT-G
                 PERFORM PLOT-WC
              END-IF
           END-PERFORM.

       COMPOSE-ENEMIES.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > ENEMY-COUNT
              IF E-ALIVE(WS-I) = "Y"
                 MOVE E-Y(WS-I) TO PLOT-R
                 MOVE E-X(WS-I) TO PLOT-C
                 MOVE G-GOOMBA TO PLOT-G
                 PERFORM PLOT-WC
              END-IF
           END-PERFORM.

       COMPOSE-PLAYER.
      *>   blink while invulnerable (skip drawing on alternate frames)
           IF P-INVULN > 0
              COMPUTE WS-N = FUNCTION MOD(FRAME-COUNTER, 2)
              IF WS-N = 0
                 EXIT PARAGRAPH
              END-IF
           END-IF
           IF P-SIZE = "B"
              COMPUTE PLOT-R = P-Y - 1
              MOVE P-X TO PLOT-C
              MOVE G-PLAYER-B-TOP TO PLOT-G
              PERFORM PLOT-WC
              MOVE P-Y TO PLOT-R
              MOVE P-X TO PLOT-C
              MOVE G-PLAYER-B-BOT TO PLOT-G
              PERFORM PLOT-WC
           ELSE
              MOVE P-Y TO PLOT-R
              MOVE P-X TO PLOT-C
              MOVE G-PLAYER-S TO PLOT-G
              PERFORM PLOT-WC
           END-IF.
       COMPOSE-PLAYER-EXIT.
           EXIT.

      *>   plot a world cell into the back buffer (clip to viewport)
       PLOT-WC.
           IF PLOT-R < 1 OR PLOT-R > FIELD-ROWS
              EXIT PARAGRAPH
           END-IF
           COMPUTE WS-SC = PLOT-C - CAMERA-X + 1
           IF WS-SC >= 1 AND WS-SC <= SCR-COLS
              MOVE PLOT-G TO BB-CELL(PLOT-R, WS-SC)
           END-IF.
       PLOT-WC-EXIT.
           EXIT.

       DIFF-RENDER.
           PERFORM VARYING WS-BR FROM 1 BY 1 UNTIL WS-BR > FIELD-ROWS
              PERFORM VARYING WS-SC FROM 1 BY 1 UNTIL WS-SC > SCR-COLS
                 IF BB-CELL(WS-BR, WS-SC) NOT = FB-CELL(WS-BR, WS-SC)
                    MOVE BB-CELL(WS-BR, WS-SC) TO DISP-CHAR
                    PERFORM GLYPH-COLOR
                    COMPUTE WS-SL = WS-BR + 1
                    IF WS-HI = 1
                       DISPLAY DISP-CHAR AT LINE WS-SL COLUMN WS-SC
                          WITH FOREGROUND-COLOR WS-FG HIGHLIGHT
                    ELSE
                       DISPLAY DISP-CHAR AT LINE WS-SL COLUMN WS-SC
                          WITH FOREGROUND-COLOR WS-FG
                    END-IF
                    MOVE BB-CELL(WS-BR, WS-SC)
                       TO FB-CELL(WS-BR, WS-SC)
                 END-IF
              END-PERFORM
           END-PERFORM.

      *>   glyph -> colour (colour is an attribute of the glyph, so
      *>   monochrome terminals still read every glyph correctly)
       GLYPH-COLOR.
           MOVE CLR-WHITE TO WS-FG
           MOVE 0 TO WS-HI
           EVALUATE DISP-CHAR
               WHEN G-PLAYER-S
               WHEN G-PLAYER-B-TOP
                    MOVE CLR-WHITE TO WS-FG   MOVE 1 TO WS-HI
               WHEN G-GROUND
                    MOVE CLR-YELLOW TO WS-FG
               WHEN G-HARD
                    MOVE CLR-WHITE TO WS-FG
               WHEN G-PIPE
                    MOVE CLR-GREEN TO WS-FG
               WHEN G-QUESTION
                    MOVE CLR-YELLOW TO WS-FG  MOVE 1 TO WS-HI
               WHEN G-USED
                    MOVE CLR-YELLOW TO WS-FG
               WHEN G-COIN
                    MOVE CLR-YELLOW TO WS-FG  MOVE 1 TO WS-HI
               WHEN G-GOOMBA
                    MOVE CLR-RED TO WS-FG
               WHEN G-SHROOM
                    MOVE CLR-MAGENTA TO WS-FG MOVE 1 TO WS-HI
               WHEN G-SPIKE
                    MOVE CLR-RED TO WS-FG     MOVE 1 TO WS-HI
               WHEN G-FLAG
                    MOVE CLR-GREEN TO WS-FG   MOVE 1 TO WS-HI
               WHEN G-POLE
                    MOVE CLR-GREEN TO WS-FG
               WHEN G-PLATFORM
                    MOVE CLR-CYAN TO WS-FG
               WHEN OTHER
                    MOVE CLR-WHITE TO WS-FG
           END-EVALUATE.

      *>   Diagnostic: show what the terminal reports for each key press.
      *>   Run with:  ./super-cobol-bros --keytest   (press Q to quit)
       RUN-KEYTEST.
           DISPLAY " " AT LINE 1 COLUMN 1 WITH BLANK SCREEN
           DISPLAY "SUPER COBOL BROS. -- key test"
              AT LINE 2 COLUMN 5 WITH FOREGROUND-COLOR CLR-WHITE HIGHLIGHT
           DISPLAY "Press keys to see what your terminal sends."
              AT LINE 4 COLUMN 5
           DISPLAY "Movement should show a char; arrows show a status."
              AT LINE 5 COLUMN 5
           DISPLAY "Press Q to quit."
              AT LINE 6 COLUMN 5
           MOVE "N" TO WS-DONE
           PERFORM UNTIL WS-DONE = "Y"
              MOVE X"00" TO IN-KEY
              MOVE 0 TO KEY-STATUS
              ACCEPT IN-KEY AT LINE MSG-LINE COLUMN 1
                 WITH AUTO TIMEOUT FRAME-TIMEOUT NO ECHO
                 ON EXCEPTION CONTINUE
              END-ACCEPT
              IF KEY-STATUS NOT = K-TIMEOUT OR IN-KEY NOT = X"00"
                 MOVE FUNCTION ORD(IN-KEY) TO WS-N
                 MOVE SPACES TO SCREEN-LINE
                 STRING "last key -> CRT-STATUS=" KEY-STATUS
                        "  char-ord=" WS-N
                        "  char=[" IN-KEY "]   "
                    DELIMITED BY SIZE INTO SCREEN-LINE
                 END-STRING
                 DISPLAY SCREEN-LINE AT LINE 9 COLUMN 5
                    WITH FOREGROUND-COLOR CLR-YELLOW
                 IF FUNCTION LOWER-CASE(IN-KEY) = "q"
                    MOVE "Y" TO WS-DONE
                 END-IF
              END-IF
           END-PERFORM
           PERFORM RESTORE-TERMINAL.

       RENDER-HUD-TEXT.
           MOVE SCORE TO ED-SCORE
           MOVE COINS TO ED-COINS
           MOVE LIVES TO ED-LIVES
           MOVE TIME-LEFT TO ED-TIME
           MOVE CUR-LEVEL TO ED-LVL
           MOVE SPACES TO HUD-TEXT
           STRING "SCORE " ED-SCORE
                  "  COINSx" ED-COINS
                  "  MARIOx" ED-LIVES
                  "  1-" ED-LVL
                  "  TIME " ED-TIME
              DELIMITED BY SIZE INTO HUD-TEXT
           END-STRING.

       RENDER-HUD.
           PERFORM RENDER-HUD-TEXT
           IF HUD-TEXT NOT = HUD-PREV
              DISPLAY HUD-TEXT AT LINE HUD-LINE COLUMN 1
                 WITH FOREGROUND-COLOR CLR-WHITE HIGHLIGHT
              MOVE HUD-TEXT TO HUD-PREV
           END-IF.

       CLEAR-SCREEN-FULL.
           DISPLAY " " AT LINE 1 COLUMN 1 WITH BLANK SCREEN
           MOVE LOW-VALUES TO FRONT-BUF
           MOVE ALL X"01" TO HUD-PREV.

      *> ==========================================================
      *>  SCREENS  (title / level-clear / game-over / win / dying)
      *> ==========================================================
       DO-TITLE.
           PERFORM DRAW-TITLE-SCREEN
           MOVE "N" TO WS-DONE
           PERFORM UNTIL WS-DONE = "Y"
              PERFORM READ-INPUT
              IF WANT-QUIT = "Y"
                 MOVE "QUIT" TO GAME-STATE
                 MOVE "Y" TO WS-DONE
              END-IF
              IF WANT-JUMP = "Y"
                 PERFORM START-NEW-GAME
                 MOVE "Y" TO WS-DONE
              END-IF
           END-PERFORM.

       DRAW-TITLE-SCREEN.
           DISPLAY " " AT LINE 1 COLUMN 1 WITH BLANK SCREEN
           DISPLAY "================================================"
              AT LINE 4 COLUMN 17 WITH FOREGROUND-COLOR CLR-YELLOW
           DISPLAY "        S U P E R   C O B O L   B R O S.        "
              AT LINE 6 COLUMN 17
              WITH FOREGROUND-COLOR CLR-WHITE HIGHLIGHT
           DISPLAY "================================================"
              AT LINE 8 COLUMN 17 WITH FOREGROUND-COLOR CLR-YELLOW
           DISPLAY "An ASCII platformer written in pure GnuCOBOL"
              AT LINE 10 COLUMN 19 WITH FOREGROUND-COLOR CLR-GREEN
           DISPLAY "Move: A / D     Jump: W or SPACE     Quit: Q"
              AT LINE 13 COLUMN 19
           DISPLAY "Stomp Goombas (&), grab coins (o) and the"
              AT LINE 15 COLUMN 19 WITH FOREGROUND-COLOR CLR-CYAN
           DISPLAY "mushroom (m). Reach the flag (F) to win."
              AT LINE 16 COLUMN 19 WITH FOREGROUND-COLOR CLR-CYAN
           DISPLAY "PRESS SPACE TO START"
              AT LINE 19 COLUMN 31
              WITH FOREGROUND-COLOR CLR-WHITE HIGHLIGHT
           DISPLAY "Written in COBOL. Yes, really."
              AT LINE 22 COLUMN 26 WITH FOREGROUND-COLOR CLR-MAGENTA.

       START-NEW-GAME.
           MOVE 0 TO SCORE
           MOVE 0 TO COINS
           MOVE 3 TO LIVES
           MOVE 1 TO CUR-LEVEL
           PERFORM LOAD-LEVEL
           IF LOAD-ERROR = "Y"
              PERFORM ABORT-ON-LOAD-ERROR
              EXIT PARAGRAPH
           END-IF
           PERFORM CLEAR-SCREEN-FULL
           MOVE "PLAY" TO GAME-STATE.
       START-NEW-GAME-EXIT.
           EXIT.

       DO-DYING.
           DISPLAY "  * * *   O U C H !   * * *  "
              AT LINE 12 COLUMN 26
              WITH FOREGROUND-COLOR CLR-RED HIGHLIGHT
           MOVE "N" TO WS-DONE
           PERFORM 6 TIMES
              PERFORM READ-INPUT
              IF WANT-QUIT = "Y"
                 MOVE "QUIT" TO GAME-STATE
                 MOVE "Y" TO WS-DONE
              END-IF
           END-PERFORM
           IF WS-DONE = "Y"
              EXIT PARAGRAPH
           END-IF
           IF LIVES > 1
              SUBTRACT 1 FROM LIVES
              PERFORM LOAD-LEVEL
              IF LOAD-ERROR = "Y"
                 PERFORM ABORT-ON-LOAD-ERROR
                 EXIT PARAGRAPH
              END-IF
              PERFORM CLEAR-SCREEN-FULL
              MOVE "PLAY" TO GAME-STATE
           ELSE
              MOVE 0 TO LIVES
              MOVE "GAMEOVER" TO GAME-STATE
           END-IF.
       DO-DYING-EXIT.
           EXIT.

       DO-LEVELCLEAR.
           COMPUTE SCORE-AMT = TIME-LEFT * TIME-BONUS-PER
           PERFORM ADD-SCORE
           DISPLAY " " AT LINE 1 COLUMN 1 WITH BLANK SCREEN
           DISPLAY "* * *  L E V E L   C O M P L E T E  * * *"
              AT LINE 10 COLUMN 20
              WITH FOREGROUND-COLOR CLR-GREEN HIGHLIGHT
           MOVE TIME-LEFT TO ED-TIME
           MOVE SPACES TO SCREEN-LINE
           STRING "TIME BONUS: " ED-TIME " x 50 points!"
              DELIMITED BY SIZE INTO SCREEN-LINE
           END-STRING
           DISPLAY SCREEN-LINE AT LINE 13 COLUMN 25
              WITH FOREGROUND-COLOR CLR-YELLOW
           DISPLAY "PRESS SPACE TO CONTINUE"
              AT LINE 17 COLUMN 29
           MOVE "N" TO WS-DONE
           PERFORM UNTIL WS-DONE = "Y"
              PERFORM READ-INPUT
              IF WANT-QUIT = "Y"
                 MOVE "QUIT" TO GAME-STATE
                 MOVE "Y" TO WS-DONE
              END-IF
              IF WANT-JUMP = "Y"
                 MOVE "Y" TO WS-DONE
              END-IF
           END-PERFORM
           IF GAME-STATE = "QUIT"
              EXIT PARAGRAPH
           END-IF
           ADD 1 TO CUR-LEVEL
           IF CUR-LEVEL > MAX-LEVELS
              MOVE "WIN" TO GAME-STATE
           ELSE
              PERFORM LOAD-LEVEL
              IF LOAD-ERROR = "Y"
                 PERFORM ABORT-ON-LOAD-ERROR
                 EXIT PARAGRAPH
              END-IF
              PERFORM CLEAR-SCREEN-FULL
              MOVE "PLAY" TO GAME-STATE
           END-IF.
       DO-LEVELCLEAR-EXIT.
           EXIT.

       DO-GAMEOVER.
           DISPLAY " " AT LINE 1 COLUMN 1 WITH BLANK SCREEN
           DISPLAY "G A M E   O V E R"
              AT LINE 11 COLUMN 32
              WITH FOREGROUND-COLOR CLR-RED HIGHLIGHT
           MOVE SCORE TO ED-SCORE
           MOVE SPACES TO SCREEN-LINE
           STRING "FINAL SCORE: " ED-SCORE
              DELIMITED BY SIZE INTO SCREEN-LINE
           END-STRING
           DISPLAY SCREEN-LINE AT LINE 14 COLUMN 33
           DISPLAY "PRESS SPACE FOR THE TITLE SCREEN"
              AT LINE 18 COLUMN 25
           PERFORM WAIT-MENU-KEY
           IF GAME-STATE NOT = "QUIT"
              MOVE "TITLE" TO GAME-STATE
           END-IF.

       DO-WIN.
           DISPLAY " " AT LINE 1 COLUMN 1 WITH BLANK SCREEN
           DISPLAY "*  Y O U   S A V E D   T H E   K I N G D O M  *"
              AT LINE 9 COLUMN 17
              WITH FOREGROUND-COLOR CLR-YELLOW HIGHLIGHT
           DISPLAY "All four worlds cleared. In COBOL. Incredible."
              AT LINE 12 COLUMN 18 WITH FOREGROUND-COLOR CLR-GREEN
           MOVE SCORE TO ED-SCORE
           MOVE SPACES TO SCREEN-LINE
           STRING "FINAL SCORE: " ED-SCORE
              DELIMITED BY SIZE INTO SCREEN-LINE
           END-STRING
           DISPLAY SCREEN-LINE AT LINE 15 COLUMN 33
              WITH FOREGROUND-COLOR CLR-WHITE HIGHLIGHT
           DISPLAY "PRESS SPACE FOR THE TITLE SCREEN"
              AT LINE 19 COLUMN 25
           PERFORM WAIT-MENU-KEY
           IF GAME-STATE NOT = "QUIT"
              MOVE "TITLE" TO GAME-STATE
           END-IF.

       WAIT-MENU-KEY.
           MOVE "N" TO WS-DONE
           PERFORM UNTIL WS-DONE = "Y"
              PERFORM READ-INPUT
              IF WANT-QUIT = "Y"
                 MOVE "QUIT" TO GAME-STATE
                 MOVE "Y" TO WS-DONE
              END-IF
              IF WANT-JUMP = "Y"
                 MOVE "Y" TO WS-DONE
              END-IF
           END-PERFORM.

       ABORT-ON-LOAD-ERROR.
           PERFORM RESTORE-TERMINAL
           DISPLAY "LEVEL LOAD FAILED: " FUNCTION TRIM(LOAD-MSG)
           MOVE "QUIT" TO GAME-STATE
           MOVE 2 TO RETURN-CODE.

      *> ==========================================================
      *>  LEVEL LOADER  (fail loudly: file + line + reason)
      *> ==========================================================
       LOAD-LEVEL.
           MOVE SPACES TO LVL-FNAME
           STRING "levels/world-1-" DELIMITED BY SIZE
                  CUR-LEVEL(2:1)    DELIMITED BY SIZE
                  ".lvl"            DELIMITED BY SIZE
              INTO LVL-FNAME
           END-STRING
           PERFORM LOAD-FROM-FNAME.

      *>   LVL-FNAME is already set by caller (game or selftest)
       LOAD-FROM-FNAME.
           PERFORM RESET-LEVEL-STATE
           MOVE "N" TO LOAD-ERROR
           MOVE SPACES TO LOAD-MSG
           MOVE "HDR" TO PARSE-PHASE
           MOVE 0 TO LINE-NO
           MOVE 0 TO GRID-ROW
           OPEN INPUT LVL-FILE
           IF LVL-STATUS NOT = "00"
              MOVE "Y" TO LOAD-ERROR
              STRING "cannot open " FUNCTION TRIM(LVL-FNAME)
                 DELIMITED BY SIZE INTO LOAD-MSG
              END-STRING
              EXIT PARAGRAPH
           END-IF
           PERFORM READ-LEVEL-LINES
           CLOSE LVL-FILE
           IF LOAD-ERROR = "Y"
              EXIT PARAGRAPH
           END-IF
           PERFORM VALIDATE-LEVEL
           IF LOAD-ERROR = "Y"
              EXIT PARAGRAPH
           END-IF
           PERFORM FINALIZE-LEVEL.
       LOAD-FROM-FNAME-EXIT.
           EXIT.

       RESET-LEVEL-STATE.
           MOVE SPACES TO W-GRID
           MOVE SPACES TO W-NAME
           MOVE 0 TO W-WIDTH
           MOVE 0 TO W-TIME
           MOVE 0 TO W-SPAWN-X
           MOVE 0 TO W-SPAWN-Y
           MOVE 0 TO ENEMY-COUNT
           MOVE 0 TO COIN-COUNT
           MOVE 0 TO PLAT-COUNT
           MOVE 0 TO SHROOM-COUNT
           MOVE 0 TO SPAWN-SEEN
           MOVE 0 TO FLAG-SEEN
           MOVE 1 TO CAMERA-X
           MOVE 0 TO TICK-ACC.

       READ-LEVEL-LINES.
           MOVE "N" TO WS-DONE
           PERFORM UNTIL WS-DONE = "Y"
              READ LVL-FILE
                 AT END MOVE "Y" TO WS-DONE
                 NOT AT END PERFORM DISPATCH-LEVEL-LINE
              END-READ
              IF LOAD-ERROR = "Y"
                 MOVE "Y" TO WS-DONE
              END-IF
           END-PERFORM.

       DISPATCH-LEVEL-LINE.
           ADD 1 TO LINE-NO
           EVALUATE PARSE-PHASE
               WHEN "HDR"  PERFORM PARSE-HEADER-LINE
               WHEN "GRID" PERFORM PARSE-GRID-LINE
               WHEN "ENT"  PERFORM PARSE-ENTITY-LINE
           END-EVALUATE.

       PARSE-HEADER-LINE.
           IF LVL-REC(1:1) = "#"
              EXIT PARAGRAPH
           END-IF
           IF FUNCTION TRIM(LVL-REC) = SPACES
              EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO TK1 TK2 TK3 TK4 TK5 TK6 TK7
           UNSTRING FUNCTION TRIM(LVL-REC)
              DELIMITED BY ALL SPACES
              INTO TK1 TK2 TK3 TK4 TK5 TK6 TK7
           END-UNSTRING
           EVALUATE TK1
               WHEN "NAME"
                    MOVE TK2 TO W-NAME
               WHEN "WIDTH"
                    COMPUTE W-WIDTH = FUNCTION NUMVAL(TK2)
                    IF W-WIDTH < 1 OR W-WIDTH > MAX-WORLD-WIDTH
                       PERFORM SET-LOAD-ERROR-WIDTH
                    END-IF
               WHEN "TIME"
                    COMPUTE W-TIME = FUNCTION NUMVAL(TK2)
               WHEN "GRID"
                    MOVE "GRID" TO PARSE-PHASE
                    MOVE 0 TO GRID-ROW
               WHEN OTHER
                    MOVE "Y" TO LOAD-ERROR
                    STRING "line " LINE-NO
                           ": unknown header keyword '"
                           FUNCTION TRIM(TK1) "'"
                       DELIMITED BY SIZE INTO LOAD-MSG
                    END-STRING
           END-EVALUATE.
       PARSE-HEADER-EXIT.
           EXIT.

       SET-LOAD-ERROR-WIDTH.
           MOVE "Y" TO LOAD-ERROR
           STRING "line " LINE-NO ": WIDTH out of range (1.."
                  MAX-WORLD-WIDTH ")"
              DELIMITED BY SIZE INTO LOAD-MSG
           END-STRING.

       PARSE-GRID-LINE.
           ADD 1 TO GRID-ROW
           IF GRID-ROW > FIELD-ROWS
              MOVE "Y" TO LOAD-ERROR
              STRING "line " LINE-NO
                     ": too many grid rows (max 22)"
                 DELIMITED BY SIZE INTO LOAD-MSG
              END-STRING
              EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO W-ROW(GRID-ROW)
           PERFORM VARYING WS-N FROM 1 BY 1 UNTIL WS-N > W-WIDTH
              IF WS-N <= 256
                 MOVE LVL-REC(WS-N:1) TO W-CELL(GRID-ROW, WS-N)
              END-IF
           END-PERFORM
           IF GRID-ROW = FIELD-ROWS
              MOVE "ENT" TO PARSE-PHASE
           END-IF.
       PARSE-GRID-EXIT.
           EXIT.

       PARSE-ENTITY-LINE.
           IF LVL-REC(1:1) = "#"
              EXIT PARAGRAPH
           END-IF
           IF FUNCTION TRIM(LVL-REC) = SPACES
              EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO TK1 TK2 TK3 TK4 TK5 TK6 TK7
           UNSTRING FUNCTION TRIM(LVL-REC)
              DELIMITED BY ALL SPACES
              INTO TK1 TK2 TK3 TK4 TK5 TK6 TK7
           END-UNSTRING
           EVALUATE TK1
               WHEN "PLATFORM"
                    PERFORM ADD-PLATFORM-FROM-TOKENS
               WHEN OTHER
                    MOVE "Y" TO LOAD-ERROR
                    STRING "line " LINE-NO
                           ": unknown entity keyword '"
                           FUNCTION TRIM(TK1) "'"
                       DELIMITED BY SIZE INTO LOAD-MSG
                    END-STRING
           END-EVALUATE.
       PARSE-ENTITY-EXIT.
           EXIT.

       ADD-PLATFORM-FROM-TOKENS.
      *>   PLATFORM <id> <startCol> <startRow> <axis> <range> <speed>
           IF PLAT-COUNT >= MAX-PLATFORMS
              MOVE "Y" TO LOAD-ERROR
              STRING "line " LINE-NO ": too many platforms (max "
                     MAX-PLATFORMS ")"
                 DELIMITED BY SIZE INTO LOAD-MSG
              END-STRING
              EXIT PARAGRAPH
           END-IF
           ADD 1 TO PLAT-COUNT
           COMPUTE PL-X(PLAT-COUNT)      = FUNCTION NUMVAL(TK3)
           COMPUTE PL-Y(PLAT-COUNT)      = FUNCTION NUMVAL(TK4)
           MOVE PL-X(PLAT-COUNT) TO PL-HOME-X(PLAT-COUNT)
           MOVE PL-Y(PLAT-COUNT) TO PL-HOME-Y(PLAT-COUNT)
           MOVE TK5(1:1)                 TO PL-AXIS(PLAT-COUNT)
           COMPUTE PL-RANGE(PLAT-COUNT)  = FUNCTION NUMVAL(TK6)
           COMPUTE PL-SPEED(PLAT-COUNT)  = FUNCTION NUMVAL(TK7)
           IF PL-SPEED(PLAT-COUNT) < 1
              MOVE 1 TO PL-SPEED(PLAT-COUNT)
           END-IF
           MOVE 1 TO PL-DIR(PLAT-COUNT)
           MOVE 3 TO PL-WIDTH(PLAT-COUNT).
       ADD-PLATFORM-EXIT.
           EXIT.

       VALIDATE-LEVEL.
           IF W-WIDTH < 1
              MOVE "Y" TO LOAD-ERROR
              MOVE "missing or invalid WIDTH header" TO LOAD-MSG
              EXIT PARAGRAPH
           END-IF
           IF GRID-ROW < FIELD-ROWS
              MOVE "Y" TO LOAD-ERROR
              STRING "expected 22 grid rows, found " GRID-ROW
                 DELIMITED BY SIZE INTO LOAD-MSG
              END-STRING
              EXIT PARAGRAPH
           END-IF.
       VALIDATE-EXIT.
           EXIT.

      *>   Scan the grid, lift dynamic entities out into tables,
      *>   leaving only static terrain behind.
       FINALIZE-LEVEL.
           PERFORM VARYING WS-BR FROM 1 BY 1 UNTIL WS-BR > FIELD-ROWS
              PERFORM VARYING WS-SC FROM 1 BY 1 UNTIL WS-SC > W-WIDTH
                 MOVE W-CELL(WS-BR, WS-SC) TO CHK-GLYPH
                 EVALUATE CHK-GLYPH
                     WHEN G-SPAWN    PERFORM LIFT-SPAWN
                     WHEN G-GOOMBA   PERFORM LIFT-GOOMBA
                     WHEN G-COIN     PERFORM LIFT-COIN
                     WHEN G-SHROOM   PERFORM LIFT-SHROOM
                     WHEN "~"        MOVE SPACE
                                        TO W-CELL(WS-BR, WS-SC)
                     WHEN G-FLAG     ADD 1 TO FLAG-SEEN
                     WHEN OTHER      CONTINUE
                 END-EVALUATE
                 IF LOAD-ERROR = "Y"
                    EXIT PARAGRAPH
                 END-IF
              END-PERFORM
           END-PERFORM
           IF SPAWN-SEEN NOT = 1
              MOVE "Y" TO LOAD-ERROR
              STRING "level needs exactly one spawn (P), found "
                     SPAWN-SEEN
                 DELIMITED BY SIZE INTO LOAD-MSG
              END-STRING
              EXIT PARAGRAPH
           END-IF
           IF FLAG-SEEN NOT = 1
              MOVE "Y" TO LOAD-ERROR
              STRING "level needs exactly one goal flag (F), found "
                     FLAG-SEEN
                 DELIMITED BY SIZE INTO LOAD-MSG
              END-STRING
              EXIT PARAGRAPH
           END-IF
      *>   place the player at the spawn, reset per-life state
           PERFORM SPAWN-PLAYER
           MOVE W-TIME TO TIME-LEFT
           MOVE 0 TO TICK-ACC
           MOVE 1 TO CAMERA-X.
       FINALIZE-EXIT.
           EXIT.

       LIFT-SPAWN.
           ADD 1 TO SPAWN-SEEN
           MOVE WS-SC TO W-SPAWN-X
           MOVE WS-BR TO W-SPAWN-Y
           MOVE SPACE TO W-CELL(WS-BR, WS-SC).

       LIFT-GOOMBA.
           IF ENEMY-COUNT >= MAX-ENEMIES
              MOVE "Y" TO LOAD-ERROR
              STRING "too many goombas (max " MAX-ENEMIES ")"
                 DELIMITED BY SIZE INTO LOAD-MSG
              END-STRING
              EXIT PARAGRAPH
           END-IF
           ADD 1 TO ENEMY-COUNT
           MOVE WS-SC TO E-X(ENEMY-COUNT)
           MOVE WS-BR TO E-Y(ENEMY-COUNT)
           MOVE -1 TO E-VX(ENEMY-COUNT)
           MOVE "Y" TO E-ALIVE(ENEMY-COUNT)
           MOVE "G" TO E-TYPE(ENEMY-COUNT)
           MOVE 1 TO E-MIN(ENEMY-COUNT)
           MOVE W-WIDTH TO E-MAX(ENEMY-COUNT)
           MOVE 0 TO E-PHASE(ENEMY-COUNT)
           MOVE SPACE TO W-CELL(WS-BR, WS-SC).
       LIFT-GOOMBA-EXIT.
           EXIT.

       LIFT-COIN.
           IF COIN-COUNT >= MAX-COINS
              MOVE "Y" TO LOAD-ERROR
              STRING "too many coins (max " MAX-COINS ")"
                 DELIMITED BY SIZE INTO LOAD-MSG
              END-STRING
              EXIT PARAGRAPH
           END-IF
           ADD 1 TO COIN-COUNT
           MOVE WS-SC TO C-X(COIN-COUNT)
           MOVE WS-BR TO C-Y(COIN-COUNT)
           MOVE "N" TO C-GOT(COIN-COUNT)
           MOVE SPACE TO W-CELL(WS-BR, WS-SC).
       LIFT-COIN-EXIT.
           EXIT.

       LIFT-SHROOM.
           IF SHROOM-COUNT >= MAX-SHROOMS
              MOVE "Y" TO LOAD-ERROR
              STRING "too many mushrooms (max " MAX-SHROOMS ")"
                 DELIMITED BY SIZE INTO LOAD-MSG
              END-STRING
              EXIT PARAGRAPH
           END-IF
           ADD 1 TO SHROOM-COUNT
           MOVE WS-SC TO M-X(SHROOM-COUNT)
           MOVE WS-BR TO M-Y(SHROOM-COUNT)
           MOVE 1 TO M-VX(SHROOM-COUNT)
           MOVE 0 TO M-VY(SHROOM-COUNT)
           MOVE "Y" TO M-ACTIVE(SHROOM-COUNT)
           MOVE SPACE TO W-CELL(WS-BR, WS-SC).
       LIFT-SHROOM-EXIT.
           EXIT.

       SPAWN-PLAYER.
           MOVE W-SPAWN-X TO P-X
           MOVE W-SPAWN-Y TO P-Y
           MOVE 0 TO P-VX
           MOVE 0 TO P-VY
           MOVE "N" TO P-ON-GROUND
           MOVE "S" TO P-SIZE
           MOVE "ALIVE" TO P-STATE
           MOVE "R" TO P-FACING
           MOVE 0 TO P-INVULN
           MOVE 0 TO P-MOVE-TIMER.

      *> ==========================================================
      *>  SELF-TEST  (headless regression net, no screen mode)
      *> ==========================================================
       RUN-SELFTEST.
           DISPLAY "SUPER COBOL BROS. -- self test"
           MOVE 0 TO TEST-TOTAL
           MOVE 0 TO TEST-FAILS
           PERFORM T-GRAVITY-FALL
           PERFORM T-LAND-ON-FLOOR
           PERFORM T-JUMP-RISES
           PERFORM T-JUMP-RETURNS
           PERFORM T-WALL-BLOCKS
           PERFORM T-HEAD-BONK
           PERFORM T-COIN-COLLECT
           PERFORM T-HUNDRED-COINS
           PERFORM T-STOMP-KILLS
           PERFORM T-SIDE-HIT-SMALL-DIES
           PERFORM T-SIDE-HIT-BIG-SHRINKS
           PERFORM T-MUSHROOM-GROWS
           PERFORM T-PLATFORM-CARRIES
           PERFORM T-CAMERA-CLAMP
           PERFORM T-LOAD-VALID
           PERFORM T-LOAD-ALL-LEVELS
           PERFORM T-LOAD-BAD-WIDTH
           PERFORM T-LOAD-BAD-NOSPAWN
           PERFORM T-LOAD-BAD-ROWS
           PERFORM T-PLAY-INTEGRATION
           PERFORM T-COMPOSE-RENDER
           PERFORM T-REACH-GOAL
           PERFORM T-PIT-DEATH
           DISPLAY "-------------------------------------"
           MOVE TEST-TOTAL TO ED-SCORE
           DISPLAY "TOTAL TESTS: " TEST-TOTAL
           DISPLAY "FAILURES   : " TEST-FAILS
           IF TEST-FAILS = 0
              DISPLAY "RESULT     : ALL PASS"
           ELSE
              DISPLAY "RESULT     : FAILURES PRESENT"
           END-IF.

      *>   Build an empty world with a floor along a given row.
      *>   (floor row passed in WS-N)
       SETUP-EMPTY-WORLD.
           MOVE SPACES TO W-GRID
           MOVE 60 TO W-WIDTH
           MOVE 400 TO W-TIME
           MOVE 0 TO ENEMY-COUNT
           MOVE 0 TO COIN-COUNT
           MOVE 0 TO PLAT-COUNT
           MOVE 0 TO SHROOM-COUNT
           MOVE 1 TO CAMERA-X
           MOVE 0 TO FRAME-COUNTER
           PERFORM SPAWN-PLAYER-AT.

      *>   places player at WS-TMPC (col), WS-TMPR (row)
       SPAWN-PLAYER-AT.
           MOVE WS-TMPC TO P-X
           MOVE WS-TMPR TO P-Y
           MOVE 0 TO P-VX
           MOVE 0 TO P-VY
           MOVE "N" TO P-ON-GROUND
           MOVE "S" TO P-SIZE
           MOVE "ALIVE" TO P-STATE
           MOVE "R" TO P-FACING
           MOVE 0 TO P-INVULN
           MOVE 0 TO P-MOVE-TIMER
           MOVE "N" TO WANT-LEFT
           MOVE "N" TO WANT-RIGHT
           MOVE "N" TO WANT-JUMP.

       BUILD-FLOOR.
      *>   fill row WS-N with ground across the width
           PERFORM VARYING WS-SC FROM 1 BY 1 UNTIL WS-SC > W-WIDTH
              MOVE G-GROUND TO W-CELL(WS-N, WS-SC)
           END-PERFORM.

       T-GRAVITY-FALL.
           MOVE "gravity pulls player down" TO TEST-NAME
           MOVE 20 TO WS-N
           MOVE 10 TO WS-TMPC
           MOVE 5 TO WS-TMPR
           PERFORM SETUP-EMPTY-WORLD
           MOVE 20 TO WS-N
           PERFORM BUILD-FLOOR
           PERFORM STEP-PLAYER-PHYSICS
           MOVE 6 TO EXP-NUM
           MOVE P-Y TO GOT-NUM
           PERFORM ASSERT-EQ.

       T-LAND-ON-FLOOR.
           MOVE "player lands on floor" TO TEST-NAME
           MOVE 10 TO WS-TMPC
           MOVE 5 TO WS-TMPR
           PERFORM SETUP-EMPTY-WORLD
           MOVE 20 TO WS-N
           PERFORM BUILD-FLOOR
           PERFORM 30 TIMES
              MOVE "N" TO WANT-LEFT
              MOVE "N" TO WANT-RIGHT
              MOVE "N" TO WANT-JUMP
              PERFORM STEP-PLAYER-PHYSICS
           END-PERFORM
      *>   floor at row 20 => feet rest at row 19
           MOVE 19 TO EXP-NUM
           MOVE P-Y TO GOT-NUM
           PERFORM ASSERT-EQ
           MOVE "player grounded after landing" TO TEST-NAME
           IF P-ON-GROUND = "Y"
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ.

       T-JUMP-RISES.
           MOVE "jump raises the player" TO TEST-NAME
           MOVE 10 TO WS-TMPC
           MOVE 19 TO WS-TMPR
           PERFORM SETUP-EMPTY-WORLD
           MOVE 20 TO WS-N
           PERFORM BUILD-FLOOR
           MOVE "Y" TO P-ON-GROUND
      *>   one grounded frame, then jump
           MOVE "Y" TO WANT-JUMP
           PERFORM STEP-PLAYER-PHYSICS
           MOVE "N" TO WANT-JUMP
           PERFORM STEP-PLAYER-PHYSICS
           IF P-Y < 19
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ.

       T-JUMP-RETURNS.
           MOVE "jump returns to the ground" TO TEST-NAME
           MOVE 10 TO WS-TMPC
           MOVE 19 TO WS-TMPR
           PERFORM SETUP-EMPTY-WORLD
           MOVE 20 TO WS-N
           PERFORM BUILD-FLOOR
           MOVE "Y" TO P-ON-GROUND
           MOVE "Y" TO WANT-JUMP
           PERFORM STEP-PLAYER-PHYSICS
           MOVE "N" TO WANT-JUMP
           PERFORM 30 TIMES
              PERFORM STEP-PLAYER-PHYSICS
           END-PERFORM
           MOVE 19 TO EXP-NUM
           MOVE P-Y TO GOT-NUM
           PERFORM ASSERT-EQ.

       T-WALL-BLOCKS.
           MOVE "wall blocks horizontal move" TO TEST-NAME
           MOVE 10 TO WS-TMPC
           MOVE 19 TO WS-TMPR
           PERFORM SETUP-EMPTY-WORLD
           MOVE 20 TO WS-N
           PERFORM BUILD-FLOOR
      *>   hard wall just to the right of the player
           MOVE G-HARD TO W-CELL(19, 11)
           MOVE "Y" TO P-ON-GROUND
           MOVE "Y" TO WANT-RIGHT
           PERFORM STEP-PLAYER-PHYSICS
           MOVE "N" TO WANT-RIGHT
           PERFORM STEP-PLAYER-PHYSICS
           PERFORM STEP-PLAYER-PHYSICS
      *>   player started at col 10, wall at 11 => cannot pass 10
           MOVE 10 TO EXP-NUM
           MOVE P-X TO GOT-NUM
           PERFORM ASSERT-EQ.

       T-HEAD-BONK.
           MOVE "head-bonk spends ? block" TO TEST-NAME
           MOVE 10 TO WS-TMPC
           MOVE 19 TO WS-TMPR
           PERFORM SETUP-EMPTY-WORLD
           MOVE 20 TO WS-N
           PERFORM BUILD-FLOOR
      *>   a ? block two cells above the player's head
           MOVE G-QUESTION TO W-CELL(17, 10)
           MOVE "Y" TO P-ON-GROUND
           MOVE "Y" TO WANT-JUMP
           PERFORM STEP-PLAYER-PHYSICS
           MOVE "N" TO WANT-JUMP
           PERFORM 4 TIMES
              PERFORM STEP-PLAYER-PHYSICS
           END-PERFORM
           IF W-CELL(17, 10) = G-USED
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ.

       T-COIN-COLLECT.
           MOVE "coin collect adds score+coins" TO TEST-NAME
           MOVE 10 TO WS-TMPC
           MOVE 19 TO WS-TMPR
           PERFORM SETUP-EMPTY-WORLD
           MOVE 20 TO WS-N
           PERFORM BUILD-FLOOR
           MOVE 0 TO SCORE
           MOVE 0 TO COINS
           MOVE 1 TO COIN-COUNT
           MOVE 10 TO C-X(1)
           MOVE 19 TO C-Y(1)
           MOVE "N" TO C-GOT(1)
           PERFORM CHECK-COINS
           MOVE 1 TO EXP-NUM
           MOVE COINS TO GOT-NUM
           PERFORM ASSERT-EQ
           MOVE "coin marked collected" TO TEST-NAME
           IF C-GOT(1) = "Y"
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ.

       T-HUNDRED-COINS.
           MOVE "100 coins grants a life" TO TEST-NAME
           MOVE 3 TO LIVES
           MOVE 99 TO COINS
           MOVE 0 TO SCORE-AMT
           PERFORM ADD-COIN
           MOVE 4 TO EXP-NUM
           MOVE LIVES TO GOT-NUM
           PERFORM ASSERT-EQ
           MOVE "coins wrap after the life" TO TEST-NAME
           MOVE 0 TO EXP-NUM
           MOVE COINS TO GOT-NUM
           PERFORM ASSERT-EQ.

       T-STOMP-KILLS.
           MOVE "stomp kills goomba + bounce" TO TEST-NAME
           MOVE 10 TO WS-TMPC
           MOVE 18 TO WS-TMPR
           PERFORM SETUP-EMPTY-WORLD
           MOVE 20 TO WS-N
           PERFORM BUILD-FLOOR
           MOVE 1 TO ENEMY-COUNT
           MOVE 10 TO E-X(1)
           MOVE 19 TO E-Y(1)
           MOVE -1 TO E-VX(1)
           MOVE "Y" TO E-ALIVE(1)
           MOVE "G" TO E-TYPE(1)
           MOVE 1 TO E-MIN(1)
           MOVE 40 TO E-MAX(1)
      *>   player is falling onto the goomba
           MOVE 19 TO P-Y
           MOVE 2 TO P-VY
           PERFORM CHECK-ENEMY-COLLISIONS
           IF E-ALIVE(1) = "N"
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ
           MOVE "stomp gives upward bounce" TO TEST-NAME
           IF P-VY < 0
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ.

       T-SIDE-HIT-SMALL-DIES.
           MOVE "side-hit kills small player" TO TEST-NAME
           MOVE 10 TO WS-TMPC
           MOVE 19 TO WS-TMPR
           PERFORM SETUP-EMPTY-WORLD
           MOVE 20 TO WS-N
           PERFORM BUILD-FLOOR
           MOVE "S" TO P-SIZE
           MOVE 0 TO P-VY
           MOVE 1 TO ENEMY-COUNT
           MOVE 10 TO E-X(1)
           MOVE 19 TO E-Y(1)
           MOVE "Y" TO E-ALIVE(1)
           MOVE "G" TO E-TYPE(1)
           MOVE "ALIVE" TO P-STATE
           PERFORM CHECK-ENEMY-COLLISIONS
           IF P-STATE = "DYING"
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ.

       T-SIDE-HIT-BIG-SHRINKS.
           MOVE "side-hit shrinks big player" TO TEST-NAME
           MOVE 10 TO WS-TMPC
           MOVE 19 TO WS-TMPR
           PERFORM SETUP-EMPTY-WORLD
           MOVE 20 TO WS-N
           PERFORM BUILD-FLOOR
           MOVE "B" TO P-SIZE
           MOVE 0 TO P-VY
           MOVE 0 TO P-INVULN
           MOVE 1 TO ENEMY-COUNT
           MOVE 10 TO E-X(1)
           MOVE 19 TO E-Y(1)
           MOVE "Y" TO E-ALIVE(1)
           MOVE "G" TO E-TYPE(1)
           MOVE "ALIVE" TO P-STATE
           PERFORM CHECK-ENEMY-COLLISIONS
           MOVE "big becomes small on hit" TO TEST-NAME
           IF P-SIZE = "S"
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ
           MOVE "big survives the hit" TO TEST-NAME
           IF P-STATE = "ALIVE"
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ.

       T-MUSHROOM-GROWS.
           MOVE "mushroom grows small player" TO TEST-NAME
           MOVE 10 TO WS-TMPC
           MOVE 19 TO WS-TMPR
           PERFORM SETUP-EMPTY-WORLD
           MOVE 20 TO WS-N
           PERFORM BUILD-FLOOR
           MOVE "S" TO P-SIZE
           MOVE 1 TO SHROOM-COUNT
           MOVE 10 TO M-X(1)
           MOVE 19 TO M-Y(1)
           MOVE "Y" TO M-ACTIVE(1)
           PERFORM CHECK-SHROOM-COLLECT
           IF P-SIZE = "B"
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ.

       T-PLATFORM-CARRIES.
           MOVE "platform carries the player" TO TEST-NAME
           MOVE 10 TO WS-TMPC
           MOVE 14 TO WS-TMPR
           PERFORM SETUP-EMPTY-WORLD
      *>   one horizontal platform at row 15, player standing on top
           MOVE 1 TO PLAT-COUNT
           MOVE 9 TO PL-X(1)
           MOVE 15 TO PL-Y(1)
           MOVE 9 TO PL-HOME-X(1)
           MOVE 15 TO PL-HOME-Y(1)
           MOVE "H" TO PL-AXIS(1)
           MOVE 6 TO PL-RANGE(1)
           MOVE 1 TO PL-DIR(1)
           MOVE 1 TO PL-SPEED(1)
           MOVE 3 TO PL-WIDTH(1)
           MOVE 10 TO P-X
           MOVE 14 TO P-Y
           MOVE 0 TO P-VY
           MOVE "Y" TO P-ON-GROUND
           PERFORM UPDATE-PLATFORMS
      *>   platform moved +1 in X, player should be carried to col 11
           MOVE 11 TO EXP-NUM
           MOVE P-X TO GOT-NUM
           PERFORM ASSERT-EQ.

       T-CAMERA-CLAMP.
           MOVE "camera clamps to world left" TO TEST-NAME
           MOVE 10 TO WS-TMPC
           MOVE 19 TO WS-TMPR
           PERFORM SETUP-EMPTY-WORLD
           MOVE 200 TO W-WIDTH
           MOVE 5 TO P-X
           MOVE 50 TO CAMERA-X
           PERFORM UPDATE-CAMERA
           IF CAMERA-X >= 1
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ.

       T-LOAD-VALID.
           MOVE "valid level loads cleanly" TO TEST-NAME
           MOVE "levels/world-1-1.lvl" TO LVL-FNAME
           PERFORM LOAD-FROM-FNAME
           IF LOAD-ERROR = "N"
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ
           MOVE "valid level sets a spawn" TO TEST-NAME
           IF W-SPAWN-X > 0
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ.

       T-LOAD-ALL-LEVELS.
      *>   every shipped level must load + validate cleanly
           PERFORM VARYING CUR-LEVEL FROM 1 BY 1 UNTIL CUR-LEVEL > 4
              PERFORM LOAD-LEVEL
              MOVE SPACES TO TEST-NAME
              STRING "world-1-" CUR-LEVEL(2:1) " loads + validates"
                 DELIMITED BY SIZE INTO TEST-NAME
              END-STRING
              IF LOAD-ERROR = "N"
                 MOVE 1 TO GOT-NUM
              ELSE
                 MOVE 0 TO GOT-NUM
                 DISPLAY "     (reason: " FUNCTION TRIM(LOAD-MSG) ")"
              END-IF
              MOVE 1 TO EXP-NUM
              PERFORM ASSERT-EQ
           END-PERFORM
           MOVE 1 TO CUR-LEVEL.

       T-LOAD-BAD-WIDTH.
           MOVE "loader rejects bad WIDTH" TO TEST-NAME
           MOVE "tests/fixtures/bad-width.lvl" TO LVL-FNAME
           PERFORM LOAD-FROM-FNAME
           IF LOAD-ERROR = "Y"
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ.

       T-LOAD-BAD-NOSPAWN.
           MOVE "loader rejects missing spawn" TO TEST-NAME
           MOVE "tests/fixtures/no-spawn.lvl" TO LVL-FNAME
           PERFORM LOAD-FROM-FNAME
           IF LOAD-ERROR = "Y"
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ.

       T-LOAD-BAD-ROWS.
           MOVE "loader rejects short grid" TO TEST-NAME
           MOVE "tests/fixtures/short-grid.lvl" TO LVL-FNAME
           PERFORM LOAD-FROM-FNAME
           IF LOAD-ERROR = "Y"
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ.

      *>   Integration smoke test: actually "play" level 1-1 for a
      *>   stretch of frames by scripting input through UPDATE-WORLD,
      *>   the exact pipeline the live game runs each frame.
       T-PLAY-INTEGRATION.
           MOVE 1 TO CUR-LEVEL
           PERFORM LOAD-LEVEL
           MOVE "PLAY" TO GAME-STATE     *> earlier tests may have set DYING
           MOVE 0 TO SCORE
           MOVE 0 TO WS-TMPR             *> reuse as max-P-X tracker
           MOVE 0 TO FRAME-COUNTER
      *>   NB: use WS-J here, not WS-I -- UPDATE-WORLD uses WS-I for its
      *>   own entity loops and would clobber a shared counter.
           PERFORM VARYING WS-J FROM 1 BY 1 UNTIL WS-J > 80
              MOVE "N" TO WANT-LEFT
              MOVE "Y" TO WANT-RIGHT
              MOVE "N" TO WANT-JUMP
              IF FUNCTION MOD(WS-J, 8) = 0
                 MOVE "Y" TO WANT-JUMP
              END-IF
              ADD 1 TO FRAME-COUNTER
              IF GAME-STATE = "PLAY"
                 PERFORM UPDATE-WORLD
              END-IF
              IF P-X > WS-TMPR
                 MOVE P-X TO WS-TMPR
              END-IF
           END-PERFORM
           MOVE "play 1-1: player advances right" TO TEST-NAME
           IF WS-TMPR > 20
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ
           MOVE "play 1-1: coins score during run" TO TEST-NAME
           IF SCORE > 0
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ
           MOVE "TITLE" TO GAME-STATE
           MOVE 1 TO CUR-LEVEL.

      *>   Render compositor test: compose the back buffer (no screen)
      *>   and confirm the player + ground land where expected.
       T-COMPOSE-RENDER.
           MOVE 1 TO CUR-LEVEL
           PERFORM LOAD-LEVEL
           MOVE 1 TO CAMERA-X
           PERFORM COMPOSE-BACK-BUFFER
           MOVE "compose: player glyph in buffer" TO TEST-NAME
           COMPUTE WS-SC = P-X - CAMERA-X + 1
           IF BB-CELL(P-Y, WS-SC) = G-PLAYER-S
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ
           MOVE "compose: ground row rendered" TO TEST-NAME
           IF BB-CELL(21, WS-SC) = G-GROUND
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ
           MOVE "TITLE" TO GAME-STATE.

       T-REACH-GOAL.
           MOVE "reaching flag clears level" TO TEST-NAME
           MOVE 1 TO CUR-LEVEL
           PERFORM LOAD-LEVEL
           MOVE "PLAY" TO GAME-STATE
      *>   drop the player onto the goal flag cell
           PERFORM VARYING WS-BR FROM 1 BY 1 UNTIL WS-BR > FIELD-ROWS
              PERFORM VARYING WS-SC FROM 1 BY 1 UNTIL WS-SC > W-WIDTH
                 IF W-CELL(WS-BR, WS-SC) = G-FLAG
                    MOVE WS-BR TO P-Y
                    MOVE WS-SC TO P-X
                 END-IF
              END-PERFORM
           END-PERFORM
           PERFORM CHECK-GOAL
           IF GAME-STATE = "LEVELCLEAR"
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ
           MOVE "TITLE" TO GAME-STATE.

       T-PIT-DEATH.
           MOVE "falling into a pit kills" TO TEST-NAME
           MOVE 1 TO CUR-LEVEL
           PERFORM LOAD-LEVEL
           MOVE "PLAY" TO GAME-STATE
           MOVE "ALIVE" TO P-STATE
           MOVE 25 TO P-Y               *> below the 22-row field
           PERFORM CHECK-HAZARDS
           IF P-STATE = "DYING"
              MOVE 1 TO GOT-NUM
           ELSE
              MOVE 0 TO GOT-NUM
           END-IF
           MOVE 1 TO EXP-NUM
           PERFORM ASSERT-EQ
           MOVE "TITLE" TO GAME-STATE.

      *>   assertion helper: compares EXP-NUM vs GOT-NUM
       ASSERT-EQ.
           ADD 1 TO TEST-TOTAL
           IF EXP-NUM = GOT-NUM
              DISPLAY "  PASS  " FUNCTION TRIM(TEST-NAME)
           ELSE
              ADD 1 TO TEST-FAILS
              DISPLAY "  FAIL  " FUNCTION TRIM(TEST-NAME)
                 "  (expected " EXP-NUM " got " GOT-NUM ")"
           END-IF.

       END PROGRAM SUPER-COBOL-BROS.
