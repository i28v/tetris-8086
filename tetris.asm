bits 16
org 0x0100

jmp start_game

align 4

screen_buffer equ 0xB800

board_offset equ 64
score_offset equ 3422
lines_offset equ 3582

rotate_key equ 0x48
down_key equ 0x50
left_key equ 0x4B
right_key equ 0x4D
drop_key equ 0x3920
exit_key equ 0x1B
pause_key equ 'p'

moving_piece equ 0xDB
still_piece equ 0xDF
empty_space equ 0x20
piece_mask equ 0xFB

border_char equ 0x01BA

paused       equ 1
board_update equ 1 << 1
drop         equ 1 << 2

starting_x equ 4
starting_y equ 0

starting_pos equ starting_y | (starting_x << 8)

starting_speed equ 20
speed_change_threshold equ 3
minimum_speed equ 4
speed_decrement_value equ 2
delay_in_microseconds equ 64000

score_msg db "Score:     0"
lines_msg db "Lines:     0"

TN db 0x01, 0x11, 0x21, 0x10, 0x32, 0x50
dw 0x0000
TE db 0x00, 0x01, 0x02, 0x11, 0x23, 0x50
dw 0x0000
TS db 0x00, 0x10, 0x20, 0x11, 0x32, 0x50
dw 0x0000
TW db 0x10, 0x11, 0x12, 0x01, 0x23, 0x51
dw TN
IV db 0x00, 0x01, 0x02, 0x03, 0x14, 0x30
dw 0x0000
IH db 0x03, 0x13, 0x23, 0x33, 0x44, 0x31
dw IV
SRV db 0x00, 0x01, 0x11, 0x12, 0x23, 0x20
dw 0x0000
SRH db 0x01, 0x11, 0x10, 0x20, 0x32, 0x21
dw SRV
SLV db 0x10, 0x11, 0x01, 0x02, 0x23, 0x40
dw 0x0000
SLH db 0x00, 0x10, 0x11, 0x21, 0x32, 0x41
dw SLV
LRN db 0x00, 0x01, 0x02, 0x12, 0x23, 0x60
dw 0x0000
LRE db 0x00, 0x10, 0x20, 0x01, 0x32, 0x60
dw 0x0000
LRS db 0x00, 0x10, 0x11, 0x12, 0x23, 0x60
dw 0x0000
LRW db 0x01, 0x11, 0x21, 0x20, 0x32, 0x61
dw LRN
LLN db 0x10, 0x11, 0x02, 0x12, 0x23, 0x90
dw 0x0000
LLE db 0x00, 0x01, 0x11, 0x21, 0x32, 0x90
dw 0x0000
LLS db 0x00, 0x10, 0x01, 0x02, 0x23, 0x90
dw 0x0000
LLW db 0x00, 0x10, 0x20, 0x21, 0x32, 0x91
dw LLN
O db 0x00, 0x10, 0x01, 0x11, 0x22, 0xE2
dw 0x0000

starting_pieces:
dw TE
dw IV
dw SRV
dw SLV
dw LRS
dw LLS
dw O

score_multipliers:
dw 1
dw 40
dw 100
dw 300
dw 1200

board_top times 20 dw 0x0720
board times 200 dw 0x0720

score dw 0
lines dw 0

piece_pos:
piece_y db starting_y
piece_x db starting_x

flags db board_update

down_delay db 0
down_threshold db starting_speed

current_piece_ptr dw 0

random_seed dw 0

align 4

start_game:
    cld
    xor ah, ah
    int 0x1A
    mov word [random_seed], dx
    and dx, 7
    jz .start_piece_is_zero
    dec dx
.start_piece_is_zero:
    shl dx, 1
    mov bx, dx
    mov ax, word [starting_pieces + bx]
    mov word [current_piece_ptr], ax
    mov ah, 1
    mov cx, 0x2607
    int 0x10
    push es
    mov ax, screen_buffer
    mov es, ax
    mov ax, 0x0720
    xor di, di
    mov cx, 2000
    rep stosw 
    mov ax, border_char
    mov di, 62
    mov cx, 20 
.draw_borders:
    stosw
    add di, 20
    stosw
    add di, 136
    loop .draw_borders
    mov si, score_msg
    mov di, score_offset
    mov cx, 6
.draw_score_text:
    movsb
    inc di
    loop .draw_score_text
    mov si, lines_msg
    mov di, lines_offset
    mov cx, 6
.draw_lines_text:
    movsb
    inc di
    loop .draw_lines_text
    pop es
.main_loop:
    test byte [flags], board_update
    jz .get_input
    and byte [flags], ~board_update
    mov bx, word [piece_pos]
    mov si, word [current_piece_ptr]
    mov dl, moving_piece
    call put_piece
    push es
    mov ax, screen_buffer
    mov es, ax
    mov si, board
    mov di, board_offset
    mov cx, 20
.print_board_y: 
    push cx
    mov cx, 10
.print_board_x:
    lodsw
    and al, piece_mask
    stosw
    loop .print_board_x
    add di, 140
    pop cx
    loop .print_board_y
    mov si, score_msg + 6
    mov di, score_offset + 12
    mov cx, 6
.print_score:
    movsb
    inc di
    loop .print_score 
    mov si, lines_msg + 6
    mov di, lines_offset + 12
    mov cx, 6
.print_lines:
    movsb
    inc di
    loop .print_lines
    pop es
.get_input:
    mov ax, 0x0100
    int 0x16
    push ax
    mov ax, 0x0C00
    int 0x21
    pop ax
    cmp al, pause_key
    jne .no_pause
    xor byte [flags], paused
.no_pause:
    cmp al, exit_key
    je end_game
    test byte [flags], paused
    jz .not_paused
    xor cx, cx
    mov dx, delay_in_microseconds
    mov ah, 0x86
    int 0x15
    jmp .get_input
.not_paused:
    cmp ah, rotate_key
    jne .no_rotate
    mov si, word [current_piece_ptr]
    mov al, byte [si + 5]
    and al, 0x0F
    jnz .notzero
    add si, 8
    jmp .next
.notzero:
    cmp al, 1
    jne .end_input
    mov si, word [si + 6]
.next:
    xor dh, dh
    mov bx, word [piece_pos]
    mov al, byte [si + 4]
    mov ah, al 
    and al, 0x0F
    shr ah, 4
    mov dl, al
    add ax, bx
    cmp ah, 10
    jb .check_y
    mov dh, dl
    dec dh
.check_y:
    cmp al, 20
    ja .end_input
    sub bh, dh
    xor dl, dl 
    call put_piece
    test al, al
    jnz .end_input
    add bh, dh
    push si
    mov si, word [current_piece_ptr]
    mov dl, empty_space
    call put_piece
    pop si
    mov word [current_piece_ptr], si
    sub byte [piece_x], dh
    or byte [flags], board_update
    jmp .end_input
.no_rotate:
    cmp ah, down_key
    jne .no_down
.auto_down:
    mov byte [down_delay], 0
.down:
    mov bx, word [piece_pos]
    mov si, word [current_piece_ptr]
    mov dl, empty_space
    call put_piece
    or byte [flags], board_update
.down_loop:
    mov al, byte [si + 4]
    and al, 0x0F
    mov bx, word [piece_pos]
    add al, bl
    cmp al, 20
    jae .set_piece
    inc bl
    xor dl, dl
    call put_piece
    test al, al
    jnz .set_piece
    mov byte [piece_y], bl
    test byte [flags], drop
    jnz .down_loop
    jmp .end_input
.set_piece:
    and byte [flags], ~drop
    mov bx, word [piece_pos]
    mov dl, still_piece
    call put_piece
    mov bx, word [random_seed]
    mov ax, bx
    shl ax, 7
    xor bx, ax
    mov ax, bx
    shr ax, 9
    xor bx, ax
    mov ax, bx
    shl ax, 8
    xor bx, ax
    mov word [random_seed], bx
    and bx, 7
    jz .is_zero
    dec bx
.is_zero:
    shl bx, 1
    mov ax, word [starting_pieces + bx]
    mov word [current_piece_ptr], ax 
    mov bx, starting_pos
    mov word [piece_pos], bx
    inc bl
    xor dl, dl
    call put_piece
    test al, al
    jnz end_game
    std
    mov di, board
    mov bx, score_multipliers
    mov cx, 20
.line_check_y:
    push cx
    mov cx, 10
.line_check_x:
    cmp byte [di], still_piece
    je .piece
    shl cx, 1
    add di, cx
    jmp .line_check_done
.piece:
    add di, 2
    loop .line_check_x
.line:
    add bx, 2
    inc word [lines]
    mov dx, word [lines]
    call div10
    test ax, ax
    jnz .move_lines
    cmp byte [down_threshold], minimum_speed 
    jbe .move_lines
    sub byte [down_threshold], speed_decrement_value
.move_lines:
    push di
    sub di, 2
    lea si, [di - 20]
    lea cx, [di - board]
    shr cx, 1
    rep movsw
    pop di
.line_check_done:
    pop cx
    loop .line_check_y
    mov ax, word [bx]
    add word [score], ax
    mov dx, word [score]
    mov di, score_msg + 11
.write_score:
    call div10
    or al, 0x30
    stosb
    test dx, dx
    jnz .write_score
    mov dx, word [lines]
    mov di, lines_msg + 11
.write_lines:
    call div10
    or al, 0x30
    stosb
    test dx, dx
    jnz .write_lines
    cld
    jmp .end_input
.no_down:  
    cmp ah, left_key
    jne .no_left
    mov bx, word [piece_pos]
    test bh, bh
    jz .end_input
    dec bh
    mov si, word [current_piece_ptr]
    xor dl, dl
    call put_piece
    test al, al
    jnz .end_input
    mov byte [piece_x], bh
    inc bh
    jmp .end_horizontal_move
.no_left:
    cmp ah, right_key
    jne .no_right
    mov si, word [current_piece_ptr]
    mov ah, byte [si + 4]
    shr ah, 4
    mov bx, word [piece_pos]
    add ah, bh
    cmp ah,  10
    je .end_input
    inc bh
    xor dl, dl
    call put_piece
    test al, al
    jnz .end_input
    mov byte [piece_x], bh
    dec bh
.end_horizontal_move:
    mov dl, empty_space
    call put_piece
    or byte [flags], board_update
    jmp .end_input
.no_right:
    cmp ax, drop_key
    jne .end_input
    or byte [flags], drop
    jmp .down
.end_input:
    mov al, byte [down_threshold]
    cmp byte [down_delay], al
    jae .auto_down
    inc byte [down_delay]
    xor cx, cx
    mov dx, delay_in_microseconds
    mov ah, 0x86
    int 0x15
    jmp .main_loop
end_game:
    mov ah, 1
    mov cx, 0x0607
    int 0x10
    mov ax, 0x0003
    int 0x10
    mov ax, 0x4C00
    int 0x21
    jmp $

align 4

div10:
    push bx
    mov ax, dx
    mov bx, dx
    shr dx, 1 
    shr bx, 2 
    add dx, bx 
    mov bx, dx
    shr bx, 4
    add dx, bx
    mov bx, dx
    shr bx, 8
    add dx, bx
    shr dx, 3
    mov bx, dx
    shl bx, 2
    add bx, dx
    shl bx, 1
    sub ax, bx
    cmp ax, 10 
    jl .skipcarry
    inc dx
    sub ax, 10
.skipcarry:
    pop bx
    ret

align 4

put_piece:
    push cx
    push dx
    push si
    push di
    mov cx, 4
    mov dh, 7
    cmp dl, empty_space
    jbe .get_position
    mov dh, byte [si + 5]
    shr dh, 4
.get_position:
    lodsb
    mov ah, al
    and al, 0x0F
    shr ah, 4
    add ax, bx
    mov di, ax
    shl al, 1
    shl di, 3
    add al, ah
    add di, ax
    and di, 0x00FF
    shl di, 1
    test dl, dl
    jnz .place
    xor al, al
    cmp byte [board + di], still_piece
    jne .continue
    mov al, 1
    jmp .end
.place:
    mov word [board + di], dx
.continue:
    loop .get_position
.end:
    pop di
    pop si
    pop dx
    pop cx
    ret
