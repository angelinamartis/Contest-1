.386
.model flat, stdcall
option casemap:none

include windows.inc
include user32.inc
include kernel32.inc
include gdi32.inc

includelib user32.lib
includelib kernel32.lib
includelib gdi32.lib

WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD
WndProc  PROTO :DWORD,:DWORD,:DWORD,:DWORD

CELL_SIZE equ 50
ROWS      equ 6
COLS      equ 6

VK_LEFT_K  equ 25h
VK_UP_K    equ 26h
VK_RIGHT_K equ 27h
VK_DOWN_K  equ 28h

.data
ClassName db "MazeClass",0
AppTitle  db "Invisiball",0
WinMsg    db "You reached the end!",0

playerRow dd 0
playerCol dd 0
goalRow   dd 5
goalCol   dd 5

; 0=open, 1=wall
maze db \
0,0,1,0,0,0,\
1,0,1,0,1,0,\
0,0,0,0,1,0,\
0,1,1,0,0,0,\
0,0,0,1,1,0,\
1,1,0,0,0,0

wc  WNDCLASSEX <>
msg MSG <>
ps  PAINTSTRUCT <>

.code

start:
    invoke GetModuleHandle, NULL
    invoke WinMain, eax, NULL, NULL, SW_SHOWDEFAULT
    invoke ExitProcess, eax

WinMain PROC hInst:DWORD, hPrev:DWORD, lpCmd:DWORD, nShow:DWORD

    mov wc.cbSize, SIZEOF WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, OFFSET WndProc
    mov wc.cbClsExtra, 0
    mov wc.cbWndExtra, 0
    mov eax, hInst
    mov wc.hInstance, eax
    invoke LoadIcon, NULL, IDI_APPLICATION
    mov wc.hIcon, eax
    mov wc.hIconSm, eax
    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax
    invoke GetStockObject, WHITE_BRUSH
    mov wc.hbrBackground, eax
    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, OFFSET ClassName

    invoke RegisterClassEx, ADDR wc

    invoke CreateWindowEx,\
        0,\
        ADDR ClassName,\
        ADDR AppTitle,\
        WS_OVERLAPPEDWINDOW,\
        CW_USEDEFAULT,\
        CW_USEDEFAULT,\
        340,\
        370,\
        NULL,\
        NULL,\
        hInst,\
        NULL

    mov ebx, eax

    invoke ShowWindow, ebx, SW_SHOWNORMAL
    invoke UpdateWindow, ebx

msg_loop:
    invoke GetMessage, ADDR msg, NULL, 0, 0
    cmp eax, 0
    je end_loop
    invoke TranslateMessage, ADDR msg
    invoke DispatchMessage, ADDR msg
    jmp msg_loop

end_loop:
    mov eax, msg.wParam
    ret

WinMain ENDP

WndProc PROC hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
    LOCAL hdc:DWORD
    LOCAL row:DWORD
    LOCAL col:DWORD
    LOCAL x1:DWORD
    LOCAL y1:DWORD
    LOCAL x2:DWORD
    LOCAL y2:DWORD
    LOCAL idx:DWORD
    LOCAL newRow:DWORD
    LOCAL newCol:DWORD
    LOCAL hPen:DWORD
    LOCAL hBrushWall:DWORD
    LOCAL hBrushBall:DWORD
    LOCAL hBrushGoal:DWORD
    LOCAL hBrushStart:DWORD
    LOCAL oldObj:DWORD

    cmp uMsg, WM_DESTROY
    je do_destroy

    cmp uMsg, WM_KEYDOWN
    je do_key

    cmp uMsg, WM_PAINT
    je do_paint

default_msg:
    invoke DefWindowProc, hWnd, uMsg, wParam, lParam
    ret

do_destroy:
    invoke PostQuitMessage, 0
    xor eax, eax
    ret

do_key:
    ; copy current position
    mov eax, playerRow
    mov newRow, eax
    mov eax, playerCol
    mov newCol, eax

    ; LEFT
    cmp wParam, VK_LEFT_K
    jne check_right
    cmp newCol, 0
    je key_done
    dec newCol
    jmp try_move

check_right:
    cmp wParam, VK_RIGHT_K
    jne check_up
    cmp newCol, COLS-1
    je key_done
    inc newCol
    jmp try_move

check_up:
    cmp wParam, VK_UP_K
    jne check_down
    cmp newRow, 0
    je key_done
    dec newRow
    jmp try_move

check_down:
    cmp wParam, VK_DOWN_K
    jne key_done
    cmp newRow, ROWS-1
    je key_done
    inc newRow

try_move:
    ; idx = newRow * COLS + newCol
    mov eax, newRow
    imul eax, COLS
    add eax, newCol
    mov idx, eax

    mov esi, OFFSET maze
    add esi, idx
    movzx eax, byte ptr [esi]
    cmp eax, 1
    je key_done

    ; valid move
    mov eax, newRow
    mov playerRow, eax
    mov eax, newCol
    mov playerCol, eax

    invoke InvalidateRect, hWnd, NULL, TRUE

    ; win check
    mov eax, playerRow
    cmp eax, goalRow
    jne key_done
    mov eax, playerCol
    cmp eax, goalCol
    jne key_done

    invoke MessageBox, hWnd, ADDR WinMsg, ADDR AppTitle, MB_OK

key_done:
    xor eax, eax
    ret

do_paint:
    invoke BeginPaint, hWnd, ADDR ps
    mov hdc, eax

    invoke CreatePen, PS_SOLID, 1, 00000000h
    mov hPen, eax
    invoke SelectObject, hdc, hPen

    invoke CreateSolidBrush, 00C0C0C0h
    mov hBrushWall, eax

    invoke CreateSolidBrush, 0000FF00h
    mov hBrushGoal, eax

    invoke CreateSolidBrush, 00FFFF00h
    mov hBrushStart, eax

    invoke CreateSolidBrush, 000000FFh
    mov hBrushBall, eax

    ; draw cells
    mov row, 0

row_loop:
    mov eax, row
    cmp eax, ROWS
    jge draw_lines

    mov col, 0

col_loop:
    mov eax, col
    cmp eax, COLS
    jge next_row

    ; x1 = col * CELL_SIZE
    mov eax, col
    imul eax, CELL_SIZE
    mov x1, eax

    ; y1 = row * CELL_SIZE
    mov eax, row
    imul eax, CELL_SIZE
    mov y1, eax

    mov eax, x1
    add eax, CELL_SIZE
    mov x2, eax

    mov eax, y1
    add eax, CELL_SIZE
    mov y2, eax

    ; idx = row * COLS + col
    mov eax, row
    imul eax, COLS
    add eax, col
    mov idx, eax

    ; draw wall?
    mov esi, OFFSET maze
    add esi, idx
    movzx eax, byte ptr [esi]
    cmp eax, 1
    jne check_start

    invoke SelectObject, hdc, hBrushWall
    mov oldObj, eax
    invoke Rectangle, hdc, x1, y1, x2, y2
    invoke SelectObject, hdc, oldObj
    jmp after_special

check_start:
    mov eax, row
    cmp eax, 0
    jne check_goal
    mov eax, col
    cmp eax, 0
    jne check_goal

    invoke SelectObject, hdc, hBrushStart
    mov oldObj, eax
    invoke Rectangle, hdc, x1, y1, x2, y2
    invoke SelectObject, hdc, oldObj
    jmp after_special

check_goal:
    mov eax, row
    cmp eax, goalRow
    jne after_special_check
    mov eax, col
    cmp eax, goalCol
    jne after_special_check

    invoke SelectObject, hdc, hBrushGoal
    mov oldObj, eax
    invoke Rectangle, hdc, x1, y1, x2, y2
    invoke SelectObject, hdc, oldObj

after_special_check:
after_special:
    inc col
    jmp col_loop

next_row:
    inc row
    jmp row_loop

draw_lines:
    ; vertical lines
    mov col, 0

v_loop:
    mov eax, col
    cmp eax, COLS+1
    jge h_lines

    mov eax, col
    imul eax, CELL_SIZE
    mov x1, eax

    invoke MoveToEx, hdc, x1, 0, NULL
    invoke LineTo, hdc, x1, ROWS*CELL_SIZE

    inc col
    jmp v_loop

h_lines:
    mov row, 0

h_loop:
    mov eax, row
    cmp eax, ROWS+1
    jge draw_ball

    mov eax, row
    imul eax, CELL_SIZE
    mov y1, eax

    invoke MoveToEx, hdc, 0, y1, NULL
    invoke LineTo, hdc, COLS*CELL_SIZE, y1

    inc row
    jmp h_loop

draw_ball:
    ; ball position inside current cell
    mov eax, playerCol
    imul eax, CELL_SIZE
    add eax, 15
    mov x1, eax

    mov eax, playerRow
    imul eax, CELL_SIZE
    add eax, 15
    mov y1, eax

    mov eax, x1
    add eax, 20
    mov x2, eax

    mov eax, y1
    add eax, 20
    mov y2, eax

    invoke SelectObject, hdc, hBrushBall
    mov oldObj, eax
    invoke Ellipse, hdc, x1, y1, x2, y2
    invoke SelectObject, hdc, oldObj

    invoke DeleteObject, hPen
    invoke DeleteObject, hBrushWall
    invoke DeleteObject, hBrushGoal
    invoke DeleteObject, hBrushStart
    invoke DeleteObject, hBrushBall

    invoke EndPaint, hWnd, ADDR ps
    xor eax, eax
    ret

WndProc ENDP

END start