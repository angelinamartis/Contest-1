INCLUDE Irvine32.inc

.data

maze BYTE \
"--------------------------",0dh,0ah,\
"|S             |         |",0dh,0ah,\
"|  +----+  +---+   +-----|",0dh,0ah,\
"|  |    |  |       |     |",0dh,0ah,\
"|     +-+  |  -+      |  |",0dh,0ah,\
"|  +--|    |   |   |  |  |",0dh,0ah,\
"|  |  +--------|   +--+  |",0dh,0ah,\
"|     |        |   |     |",0dh,0ah,\
"|--+  +----  --+   |  ---|",0dh,0ah,\
"|  |               |     |",0dh,0ah,\
"|  |  +----  +-----|---  |",0dh,0ah,\
"|     |      | E         |",0dh,0ah,\
"--------------------------",0

.code
main PROC

    ; Print the maze
    mov edx, OFFSET maze
    call WriteString

    call Crlf

    exit
main ENDP

END main
