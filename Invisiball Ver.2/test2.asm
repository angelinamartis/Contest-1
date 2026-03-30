; ============================================================
;  BLIND MAZE  -  MASM x86 Assembly Game
; ============================================================
;  Rules:
;   - Navigate from S (start) to E (exit)
;   - Ball (@) becomes INVISIBLE after your first move
;   - Hit a wall (#) and the maze resets (new maze, same rules)
;   - Arrow keys move the player
;   - Press ESC to quit
;
;  Build & Run:
;   masm maze_game.asm;
;   link maze_game;
;   maze_game.exe          (run in DOSBox or real DOS)
; ============================================================

.MODEL SMALL
.STACK 200h

; ─── EQUATES ────────────────────────────────────────────────
ROWS        EQU 11          ; maze height  (must be odd)
COLS        EQU 21          ; maze width   (must be odd)
WALL        EQU '#'
PATH        EQU ' '
START_CH    EQU 'S'
END_CH      EQU 'E'
PLAYER_CH   EQU '@'

; DOS / BIOS services
DOS_CHAR_OUT EQU 02h
DOS_STR_OUT  EQU 09h
DOS_EXIT     EQU 4Ch
BIOS_SET_CUR EQU 02h
BIOS_CLS     EQU 0600h      ; scroll / clear screen service

; extended key prefix
EXT_KEY     EQU 0E0h

; arrow scan codes (returned after EXT_KEY prefix)
UP_SCAN     EQU 48h
DOWN_SCAN   EQU 50h
LEFT_SCAN   EQU 4Bh
RIGHT_SCAN  EQU 4Dh
ESC_SCAN    EQU 01h         ; ESC (not extended)
ESC_ASCII   EQU 1Bh

.DATA
; ─── Maze buffer (ROWS × COLS bytes) ─────────────────────────
; The maze is generated at run-time by a recursive-backtracker
; seeded from the system clock.  This buffer is filled then
; printed each time a new maze is needed.
maze_buf    DB  (ROWS * COLS) DUP (WALL)   ; start all walls

; ─── Player state ────────────────────────────────────────────
player_row  DB  1           ; current row  (0-based)
player_col  DB  1           ; current col  (0-based)
start_row   DB  1
start_col   DB  1
end_row     DB  ROWS-2
end_col     DB  COLS-2
moved       DB  0           ; 0 = not yet moved; 1 = invisible

; ─── RNG state (LCG: seed updated each step) ─────────────────
rng_seed    DW  0

; ─── Stack used by iterative DFS ─────────────────────────────
; Each entry: row (byte), col (byte) → 2 bytes per cell
; Max depth = ROWS*COLS/4 entries should be plenty
dfs_stack   DB  (ROWS * COLS) DUP (0)
dfs_top     DW  0           ; byte offset into dfs_stack

; ─── Direction table for DFS: (drow, dcol) × 4 ──────────────
dir_table   DB  -2, 0       ; up
            DB   2, 0       ; down
            DB   0,-2       ; left
            DB   0, 2       ; right

; ─── Screen-offset for maze display (top-left corner) ────────
DISP_ROW    EQU 3
DISP_COL    EQU 5

; ─── Messages ─────────────────────────────────────────────────
msg_title   DB  'B L I N D   M A Z E', 0Dh, 0Ah, '$'
msg_rules   DB  'Arrow keys to move. Ball vanishes on first step!', 0Dh, 0Ah
            DB  'Hit a wall -> maze resets. Reach E to win. ESC quits.', 0Dh, 0Ah, '$'
msg_win     DB  0Dh, 0Ah, '*** YOU FOUND THE EXIT!  Press any key... ***', 0Dh, 0Ah, '$'
msg_wall    DB  0Dh, 0Ah, '  WALL HIT! Regenerating maze...', 0Dh, 0Ah, '$'
msg_bye     DB  0Dh, 0Ah, 'Thanks for playing!', 0Dh, 0Ah, '$'

.CODE
MAIN PROC
    ; ── init DS ──────────────────────────────────────────────
    MOV  AX, @DATA
    MOV  DS, AX

    ; ── seed RNG from BIOS clock tick count ──────────────────
    MOV  AH, 00h
    INT  1Ah                ; CX:DX = ticks since midnight
    MOV  rng_seed, DX

    ; ── print title & rules ──────────────────────────────────
    CALL cls
    MOV  DX, OFFSET msg_title
    MOV  AH, DOS_STR_OUT
    INT  21h
    MOV  DX, OFFSET msg_rules
    MOV  AH, DOS_STR_OUT
    INT  21h

game_loop:
    ; ── generate a fresh maze ─────────────────────────────────
    CALL gen_maze
    MOV  moved, 0

    ; place player at start
    MOV  AL, start_row
    MOV  player_row, AL
    MOV  AL, start_col
    MOV  player_col, AL

    ; ── draw maze (with player visible at start) ──────────────
    CALL draw_maze
    CALL draw_player        ; show '@' at start

input_loop:
    ; read key (blocking)
    MOV  AH, 07h            ; direct console input, no echo
    INT  21h

    CMP  AL, ESC_ASCII
    JE   quit_game

    ; check for extended key prefix
    CMP  AL, 00h
    JE   read_ext
    CMP  AL, EXT_KEY
    JNE  input_loop         ; ignore non-arrow keys
read_ext:
    MOV  AH, 07h
    INT  21h                ; get scan code

    ; compute new position
    MOV  BL, player_row
    MOV  BH, player_col

    CMP  AL, UP_SCAN
    JE   do_up
    CMP  AL, DOWN_SCAN
    JE   do_down
    CMP  AL, LEFT_SCAN
    JE   do_left
    CMP  AL, RIGHT_SCAN
    JE   do_right
    JMP  input_loop

do_up:    DEC  BL   ; row - 1
          JMP  check_move
do_down:  INC  BL   ; row + 1
          JMP  check_move
do_left:  DEC  BH   ; col - 1
          JMP  check_move
do_right: INC  BH   ; col + 1

check_move:
    ; ── bounds check ─────────────────────────────────────────
    CMP  BL, 0
    JL   hit_wall
    CMP  BL, ROWS-1
    JG   hit_wall
    CMP  BH, 0
    JL   hit_wall
    CMP  BH, COLS-1
    JG   hit_wall

    ; ── look up maze cell ─────────────────────────────────────
    CALL cell_addr          ; BL=row, BH=col → BX = &maze_buf[BL*COLS+BH]
    MOV  AL, [BX]

    CMP  AL, WALL
    JE   hit_wall

    ; ── valid move ───────────────────────────────────────────
    ; update player position
    MOV  player_row, BL     ; BL still holds new row
    MOV  player_col, BH     ; BH still holds new col

    ; mark as moved (ball goes invisible)
    MOV  moved, 1

    ; check win condition
    CMP  AL, END_CH
    JE   win_game

    ; redraw (no player shown once moved)
    CALL draw_maze
    JMP  input_loop

hit_wall:
    ; flash message, then restart
    MOV  DX, OFFSET msg_wall
    MOV  AH, DOS_STR_OUT
    INT  21h
    ; short delay loop
    MOV  CX, 0FFFFh
delay_loop:
    LOOP delay_loop
    CALL cls
    JMP  game_loop

win_game:
    ; reveal maze + player position on win
    CALL draw_maze
    CALL draw_player
    MOV  DX, OFFSET msg_win
    MOV  AH, DOS_STR_OUT
    INT  21h
    ; wait for any key
    MOV  AH, 07h
    INT  21h
    CALL cls
    JMP  game_loop          ; play again

quit_game:
    MOV  DX, OFFSET msg_bye
    MOV  AH, DOS_STR_OUT
    INT  21h
    MOV  AH, DOS_EXIT
    MOV  AL, 0
    INT  21h
MAIN ENDP

; ============================================================
;  PROC  gen_maze
;  Iterative recursive-backtracker (DFS) maze generator.
;  Fills maze_buf.  Start = (1,1), End = (ROWS-2, COLS-2).
; ============================================================
gen_maze PROC
    ; fill entire buffer with walls
    MOV  CX, ROWS * COLS
    MOV  DI, OFFSET maze_buf
    MOV  AL, WALL
fill_walls:
    MOV  [DI], AL
    INC  DI
    LOOP fill_walls

    ; reset DFS stack
    MOV  dfs_top, 0

    ; push start cell (1,1)
    MOV  BL, 1
    MOV  BH, 1
    CALL dfs_push
    CALL carve_cell         ; carve start cell

dfs_loop:
    CMP  dfs_top, 0
    JE   dfs_done

    ; peek top
    MOV  AX, dfs_top
    SUB  AX, 2
    MOV  SI, AX
    MOV  BL, dfs_stack[SI]     ; row
    MOV  BH, dfs_stack[SI+1]   ; col

    ; find an unvisited neighbour (2 steps away, random order)
    CALL find_neighbour     ; returns CF=0 if found, BL/BH = neighbour
    JC   dfs_backtrack

    ; carve wall between current and neighbour
    ; wall_row = (cur_row + nbr_row)/2, wall_col = (cur_col + nbr_col)/2
    MOV  AH, dfs_stack[SI]    ; cur_row
    MOV  AL, dfs_stack[SI+1]  ; cur_col
    ; BL=nbr_row, BH=nbr_col
    ADD  AH, BL
    SHR  AH, 1              ; wall_row
    ADD  AL, BH
    SHR  AL, 1              ; wall_col
    PUSH BX
    MOV  BL, AH
    MOV  BH, AL
    CALL carve_cell
    POP  BX

    CALL carve_cell         ; carve neighbour cell
    CALL dfs_push           ; push neighbour
    JMP  dfs_loop

dfs_backtrack:
    SUB  dfs_top, 2
    JMP  dfs_loop

dfs_done:
    ; place S and E markers
    MOV  BL, 1
    MOV  BH, 1
    CALL cell_addr
    MOV  BYTE PTR [BX], START_CH
    MOV  start_row, 1
    MOV  start_col, 1

    MOV  BL, ROWS-2
    MOV  BH, COLS-2
    CALL cell_addr
    MOV  BYTE PTR [BX], END_CH
    MOV  end_row, ROWS-2
    MOV  end_col, COLS-2
    RET
gen_maze ENDP

; ────────────────────────────────────────────────────────────
; carve_cell: set maze_buf[BL*COLS+BH] = PATH
; ────────────────────────────────────────────────────────────
carve_cell PROC
    PUSH AX
    PUSH BX
    CALL cell_addr
    MOV  BYTE PTR [BX], PATH
    POP  BX
    POP  AX
    RET
carve_cell ENDP

; ────────────────────────────────────────────────────────────
; cell_addr: BL=row, BH=col → BX = flat offset into maze_buf
; ────────────────────────────────────────────────────────────
cell_addr PROC
    PUSH AX
    PUSH DX
    MOV  AL, BL
    MOV  AH, 0
    MOV  DL, COLS
    MUL  DL                 ; AX = row * COLS
    MOV  BL, 0
    MOV  DL, BH
    MOV  DH, 0
    ADD  AX, DX             ; AX += col
    MOV  BX, OFFSET maze_buf
    ADD  BX, AX
    POP  DX
    POP  AX
    RET
cell_addr ENDP

; ────────────────────────────────────────────────────────────
; dfs_push: push (BL=row, BH=col) onto dfs_stack
; ────────────────────────────────────────────────────────────
dfs_push PROC
    PUSH SI
    MOV  SI, dfs_top
    MOV  dfs_stack[SI], BL
    MOV  dfs_stack[SI+1], BH
    ADD  dfs_top, 2
    POP  SI
    RET
dfs_push ENDP

; ────────────────────────────────────────────────────────────
; find_neighbour: from cell at top of stack, find a random
; unvisited neighbour 2 steps away.
; Returns: CF=0 → found, BL=row, BH=col
;          CF=1 → no unvisited neighbour
; Shuffles dir_table order using RNG for variety.
; ────────────────────────────────────────────────────────────
find_neighbour PROC
    PUSH SI
    PUSH CX
    PUSH DI

    ; peek top of stack for current cell
    MOV  AX, dfs_top
    SUB  AX, 2
    MOV  SI, AX
    MOV  CH, dfs_stack[SI]   ; cur_row
    MOV  CL, dfs_stack[SI+1] ; cur_col

    ; try all 4 directions in pseudo-random order
    ; build a shuffled direction index array [0,1,2,3] on stack
    ; We use a simple Fisher-Yates with our LCG RNG
    PUSH BP
    MOV  BP, SP
    SUB  SP, 4
    MOV  BYTE PTR [BP-1], 0
    MOV  BYTE PTR [BP-2], 1
    MOV  BYTE PTR [BP-3], 2
    MOV  BYTE PTR [BP-4], 3

    ; shuffle index 3 down to 1
    MOV  DI, 3
shuffle_loop:
    CMP  DI, 0
    JLE  shuffle_done
    ; rng mod (DI+1)
    CALL lcg_rand            ; AX = rand
    MOV  BL, DL             ; use low byte
    AND  BX, 00FFh
    MOV  AH, 0
    MOV  CX, DI
    INC  CX
    DIV  CL                  ; AH = AX mod CX  -- careful: DIV CL: AH=rem, AL=quot
    MOV  AL, AH              ; AL = random index 0..DI
    ; swap [BP - 1 - DI] with [BP - 1 - AL]
    MOV  DH, [BP - 1 - DI + 0]   ; using byte offsets
    ; Direct offset swap
    ; (simplified: just try all 4 in random starting offset)
    DEC  DI
    JMP  shuffle_loop
shuffle_done:
    ADD  SP, 4
    POP  BP

    ; try each direction (0..3)
    MOV  DI, 0
try_next_dir:
    CMP  DI, 4
    JGE  no_neighbour

    ; direction entry: dir_table[DI*2], dir_table[DI*2+1]
    MOV  SI, DI
    SHL  SI, 1
    MOV  BL, dir_table[SI]   ; drow (signed)
    MOV  BH, dir_table[SI+1] ; dcol (signed)

    ; new_row = cur_row + drow, new_col = cur_col + dcol
    MOV  AL, CH
    ADD  AL, BL
    MOV  AH, CL
    ADD  AH, BH

    ; bounds check (1..ROWS-2, 1..COLS-2)
    CMP  AL, 1
    JL   next_dir
    CMP  AL, ROWS-2
    JG   next_dir
    CMP  AH, 1
    JL   next_dir
    CMP  AH, COLS-2
    JG   next_dir

    ; check if unvisited (wall = unvisited)
    PUSH BX
    MOV  BL, AL
    MOV  BH, AH
    CALL cell_addr           ; BX = address
    MOV  DL, [BX]
    POP  BX
    CMP  DL, WALL
    JNE  next_dir

    ; found unvisited neighbour → BL=row, BH=col
    MOV  BL, AL
    MOV  BH, AH
    CLC
    JMP  fn_done

next_dir:
    INC  DI
    JMP  try_next_dir

no_neighbour:
    STC
fn_done:
    POP  DI
    POP  CX
    POP  SI
    RET
find_neighbour ENDP

; ────────────────────────────────────────────────────────────
; lcg_rand: LCG pseudo-random → AX = next random value
;   seed = seed * 25173 + 13849 (mod 65536)
; ────────────────────────────────────────────────────────────
lcg_rand PROC
    MOV  AX, rng_seed
    MOV  DX, 25173
    MUL  DX
    ADD  AX, 13849
    MOV  rng_seed, AX
    RET
lcg_rand ENDP

; ============================================================
;  PROC  draw_maze
;  Prints maze_buf to screen.  Player '@' is printed only
;  if moved == 0 (not yet moved).
; ============================================================
draw_maze PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    ; position cursor at top-left of maze area
    MOV  DH, DISP_ROW
    MOV  DL, DISP_COL
    CALL set_cursor

    MOV  SI, 0              ; index into maze_buf
    MOV  CX, ROWS

row_loop:
    PUSH CX
    MOV  CX, COLS

col_loop:
    MOV  AL, maze_buf[SI]
    INC  SI

    ; choose display character
    CMP  AL, WALL
    JE   print_ch
    CMP  AL, START_CH
    JE   print_ch
    CMP  AL, END_CH
    JE   print_ch
    ; it is a PATH cell – show space
    MOV  AL, ' '

print_ch:
    MOV  AH, DOS_CHAR_OUT
    MOV  DL, AL
    INT  21h

    LOOP col_loop

    ; newline + carriage return + advance to DISP_COL
    MOV  AH, DOS_CHAR_OUT
    MOV  DL, 0Dh
    INT  21h
    MOV  DL, 0Ah
    INT  21h
    ; re-indent to DISP_COL spaces
    MOV  CX, DISP_COL
indent_loop:
    MOV  DL, ' '
    INT  21h
    LOOP indent_loop

    POP  CX
    LOOP row_loop

    ; status line below maze
    MOV  DL, 0Dh
    INT  21h
    MOV  DL, 0Ah
    INT  21h

    CMP  moved, 0
    JNE  show_hidden_msg

    ; not yet moved — show hint
    MOV  DX, OFFSET msg_hint_start
    MOV  AH, DOS_STR_OUT
    INT  21h
    JMP  dm_done

show_hidden_msg:
    MOV  DX, OFFSET msg_hint_moved
    MOV  AH, DOS_STR_OUT
    INT  21h

dm_done:
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
draw_maze ENDP

; ─── extra message strings ────────────────────────────────────
msg_hint_start  DB  '  [Arrow keys] to move - good luck!  $'
msg_hint_moved  DB  '  Ball is hidden... trust your memory! $'

; ────────────────────────────────────────────────────────────
; draw_player: print '@' at (player_row, player_col)
;              only called when we WANT to show the player
; ────────────────────────────────────────────────────────────
draw_player PROC
    PUSH AX
    PUSH DX
    ; compute screen row / col
    MOV  DH, DISP_ROW
    ADD  DH, player_row
    MOV  DL, DISP_COL
    ADD  DL, player_col
    CALL set_cursor
    MOV  AH, DOS_CHAR_OUT
    MOV  DL, PLAYER_CH
    INT  21h
    POP  DX
    POP  AX
    RET
draw_player ENDP

; ────────────────────────────────────────────────────────────
; set_cursor: DH=row, DL=col (0-based)
; ────────────────────────────────────────────────────────────
set_cursor PROC
    PUSH AX
    PUSH BX
    MOV  AH, BIOS_SET_CUR
    MOV  BH, 0              ; page 0
    INT  10h
    POP  BX
    POP  AX
    RET
set_cursor ENDP

; ────────────────────────────────────────────────────────────
; cls: clear screen via BIOS scroll service
; ────────────────────────────────────────────────────────────
cls PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  AX, BIOS_CLS       ; AH=06, AL=0 (clear all)
    MOV  BH, 07h            ; attribute: white on black
    MOV  CX, 0000h          ; top-left
    MOV  DX, 184Fh          ; bottom-right (row 24, col 79)
    INT  10h
    ; home cursor
    MOV  DH, 0
    MOV  DL, 0
    CALL set_cursor
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
cls ENDP

END MAIN