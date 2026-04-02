INCLUDE Irvine32.inc
includelib Irvine32.lib

.data
titleMsg BYTE "GET TO E! (use WASD keys)",0
normalWinMsg BYTE "WOW didnt expect that <3",0
easyWinMsg BYTE "thanks for trying ig...",0

attempts BYTE 0 ;counts times player hit wall
easyMode BYTE 0 
moveCount BYTE 0

playerX BYTE 1
playerY BYTE 1

; Regular Maze
maze0  BYTE "--------------------------",0
maze1  BYTE "|              |         |",0
maze2  BYTE "|  +----+  +---+   +-----|",0
maze3  BYTE "|  |    |  |       |     |",0
maze4  BYTE "|     +-+  |  ++      +  |",0
maze5  BYTE "|  +--|    |   |   |  |  |",0
maze6  BYTE "|  |  +--------|   +--+  |",0
maze7  BYTE "|     |        |   |     |",0
maze8  BYTE "|--+  +---+  +-+   |  ---|",0
maze9  BYTE "|  |               |     |",0
maze10 BYTE "|  |  +---+  +-----|---  |",0
maze11 BYTE "|     |      | E         |",0
maze12 BYTE "--------------------------",0

; Easy Maze
easy0  BYTE "--------",0
easy1  BYTE "| E    |",0
easy2  BYTE "|      |",0
easy3  BYTE "--------",0

.code
main PROC
    call Draw
    call GameLoop
    exit
main ENDP

GameLoop PROC
L1:
    call ReadChar

    cmp al,'w'
    je GoUp
    cmp al,'W'
    je GoUp

    cmp al,'s'
    je GoDown
    cmp al,'S'
    je GoDown

    cmp al,'a'
    je GoLeft
    cmp al,'A'
    je GoLeft

    cmp al,'d'
    je GoRight
    cmp al,'D'
    je GoRight

    jmp L1

GoUp:
    mov bl,playerX
    mov bh,playerY
    dec bh
    call TryMove
    jmp CheckWin

GoDown:
    mov bl,playerX
    mov bh,playerY
    inc bh
    call TryMove
    jmp CheckWin

GoLeft:
    mov bl,playerX
    mov bh,playerY
    dec bl
    call TryMove
    jmp CheckWin

GoRight:
    mov bl,playerX
    mov bh,playerY
    inc bl
    call TryMove
    jmp CheckWin

CheckWin:
    mov bl,playerX
    mov bh,playerY
    call GetMazeChar
    cmp al,'E'
    jne L1

    mov dh,15
    mov dl,0
    call Gotoxy

    mov al,easyMode
    cmp al,1
    je ShowEasyWin

    mov edx,OFFSET normalWinMsg
    jmp ShowWinMsg

ShowEasyWin:
    mov edx,OFFSET easyWinMsg

ShowWinMsg:
    call WriteString
    call ReadChar
    ret
GameLoop ENDP

TryMove PROC USES eax
    call GetMazeChar

    cmp al,'|'
    je HitWall
    cmp al,'-'
    je HitWall
    cmp al,'+'
    je HitWall

    mov playerX,bl
    mov playerY,bh

    mov al,moveCount
    inc al
    mov moveCount,al

    call Draw
    ret

HitWall:
    mov al,attempts
    inc al
    mov attempts,al

    cmp al,2
    jl ResetPlayer
    mov easyMode,1

ResetPlayer:
    mov playerX,1
    mov playerY,1
    mov moveCount,0
    call Draw
    ret
TryMove ENDP

Draw PROC
    call Clrscr
    call DrawCurrentMaze
    call DrawTitle
    call DrawPlayer
    ret
Draw ENDP

DrawTitle PROC
    mov dh,14
    mov dl,0
    call Gotoxy
    mov edx,OFFSET titleMsg
    call WriteString
    ret
DrawTitle ENDP

DrawCurrentMaze PROC
    mov al,easyMode
    cmp al,1
    je DrawEasyMaze

    mov dh,0
    mov dl,0
    call Gotoxy
    mov edx,OFFSET maze0
    call WriteString

    mov dh,1
    mov dl,0
    call Gotoxy
    mov edx,OFFSET maze1
    call WriteString

    mov dh,2
    mov dl,0
    call Gotoxy
    mov edx,OFFSET maze2
    call WriteString

    mov dh,3
    mov dl,0
    call Gotoxy
    mov edx,OFFSET maze3
    call WriteString

    mov dh,4
    mov dl,0
    call Gotoxy
    mov edx,OFFSET maze4
    call WriteString

    mov dh,5
    mov dl,0
    call Gotoxy
    mov edx,OFFSET maze5
    call WriteString

    mov dh,6
    mov dl,0
    call Gotoxy
    mov edx,OFFSET maze6
    call WriteString

    mov dh,7
    mov dl,0
    call Gotoxy
    mov edx,OFFSET maze7
    call WriteString

    mov dh,8
    mov dl,0
    call Gotoxy
    mov edx,OFFSET maze8
    call WriteString

    mov dh,9
    mov dl,0
    call Gotoxy
    mov edx,OFFSET maze9
    call WriteString

    mov dh,10
    mov dl,0
    call Gotoxy
    mov edx,OFFSET maze10
    call WriteString

    mov dh,11
    mov dl,0
    call Gotoxy
    mov edx,OFFSET maze11
    call WriteString

    mov dh,12
    mov dl,0
    call Gotoxy
    mov edx,OFFSET maze12
    call WriteString
    ret

DrawEasyMaze:
    mov dh,0
    mov dl,0
    call Gotoxy
    mov edx,OFFSET easy0
    call WriteString

    mov dh,1
    mov dl,0
    call Gotoxy
    mov edx,OFFSET easy1
    call WriteString

    mov dh,2
    mov dl,0
    call Gotoxy
    mov edx,OFFSET easy2
    call WriteString

    mov dh,3
    mov dl,0
    call Gotoxy
    mov edx,OFFSET easy3
    call WriteString
    ret
DrawCurrentMaze ENDP

DrawPlayer PROC
    mov al,moveCount
    cmp al,1
    ja HidePlayer

    mov dh,playerY
    mov dl,playerX
    call Gotoxy
    mov al,'O'
    call WriteChar

HidePlayer:
    ret
DrawPlayer ENDP

GetMazeChar PROC USES edx
    mov al,easyMode
    cmp al,1
    je EasyRows

NormalRows:
    cmp bh,0
    je N0
    cmp bh,1
    je N1
    cmp bh,2
    je N2
    cmp bh,3
    je N3
    cmp bh,4
    je N4
    cmp bh,5
    je N5
    cmp bh,6
    je N6
    cmp bh,7
    je N7
    cmp bh,8
    je N8
    cmp bh,9
    je N9
    cmp bh,10
    je N10
    cmp bh,11
    je N11
    jmp N12

EasyRows:
    cmp bh,0
    je E0
    cmp bh,1
    je E1
    cmp bh,2
    je E2
    cmp bh,3
    je E3

N0:
    mov edx,OFFSET maze0
    jmp ReadCell
N1:
    mov edx,OFFSET maze1
    jmp ReadCell
N2:
    mov edx,OFFSET maze2
    jmp ReadCell
N3:
    mov edx,OFFSET maze3
    jmp ReadCell
N4:
    mov edx,OFFSET maze4
    jmp ReadCell
N5:
    mov edx,OFFSET maze5
    jmp ReadCell
N6:
    mov edx,OFFSET maze6
    jmp ReadCell
N7:
    mov edx,OFFSET maze7
    jmp ReadCell
N8:
    mov edx,OFFSET maze8
    jmp ReadCell
N9:
    mov edx,OFFSET maze9
    jmp ReadCell
N10:
    mov edx,OFFSET maze10
    jmp ReadCell
N11:
    mov edx,OFFSET maze11
    jmp ReadCell
N12:
    mov edx,OFFSET maze12
    jmp ReadCell

E0:
    mov edx,OFFSET easy0
    jmp ReadCell
E1:
    mov edx,OFFSET easy1
    jmp ReadCell
E2:
    mov edx,OFFSET easy2
    jmp ReadCell
E3:
    mov edx,OFFSET easy3
    jmp ReadCell

ReadCell:
    movzx eax,bl
    mov al,[edx+eax]
    ret
GetMazeChar ENDP

END main