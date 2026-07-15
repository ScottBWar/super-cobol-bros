      *> ==========================================================
      *>  world.cpy  --  static terrain grid + level metadata
      *>  The grid holds ONLY static terrain after load; coins,
      *>  enemies, mushrooms and platforms are lifted into the
      *>  dynamic tables in entities.cpy.
      *> ==========================================================
       01  WORLD.
           05  W-NAME            PIC X(20).
           05  W-WIDTH           PIC 9(4)  VALUE 0.
           05  W-TIME            PIC 9(4)  VALUE 0.
           05  W-SPAWN-X         PIC 9(4)  VALUE 0.
           05  W-SPAWN-Y         PIC 9(4)  VALUE 0.
           05  W-GRID.
               10  W-ROW OCCURS 22 TIMES.
                   15  W-CELL OCCURS 240 TIMES PIC X.
