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

moving_piece equ 0xDB
still_piece equ 0xDF
empty_space equ 0x20
piece_mask equ 0xFB

border_char equ 0x01BA

starting_x equ 4
starting_y equ 0

starting_speed equ 20
speed_change_threshold equ 3
minimum_speed equ 4
speed_decrement_value equ 2
delay_in_microseconds equ 50000

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

board_top times 10 dw 0x0720
board times 200 dw 0x0720

score dw 0
lines dw 0
piece_x db starting_x
piece_y db starting_y

drop db 0
board_update db 1
down_delay db 0
down_threshold db starting_speed

current_piece_ptr dw 0
previous_piece_ptr dw 0

random_seed dw 0

running db 1 

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
    cmp byte [board_update], 1
    jne .skip_board_update
    mov byte [board_update], 0
    mov bh, byte [piece_x]
    mov bl, byte [piece_y]
    mov dl, moving_piece
    mov si, word [current_piece_ptr]
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
.skip_board_update:
    mov ax, 0x0100
    int 0x16
    push ax
    mov ax, 0x0C00
    int 0x21
    pop ax
    cmp ah, rotate_key
    jne .no_rotate
    mov si, word [current_piece_ptr]
    mov word [previous_piece_ptr], si
    mov al, byte [si + 5]
    and al, 0x0F
    test al, al
    jnz .notzero
    add si, 8
    jmp .next
.notzero:
    cmp al, 1
    jne .end_input
    mov si, word [si + 6]
.next:
    xor dh, dh
    mov bh, byte [piece_x]
    mov bl, byte [piece_y]
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
    mov dl, empty_space
    push si
    mov si, word [previous_piece_ptr]
    call put_piece
    pop si
    mov word [current_piece_ptr], si 
    sub byte [piece_x], dh
    mov byte [board_update], 1
    jmp .end_input
.no_rotate:
    cmp ah, down_key
    jne .no_down
.auto_down:
    mov byte [down_delay], 0
.down:
    mov si, word [current_piece_ptr]
    mov bh, byte [piece_x]
    mov bl, byte [piece_y]
    mov dl, empty_space
    call put_piece
    mov byte [board_update], 1
.down_loop:
    mov al, byte [si + 4]
    and al, 0x0F
    mov bl, byte [piece_y]
    add al, bl
    cmp al, 20
    jae .set_piece
    mov bh, byte [piece_x]
    inc bl
    xor dl, dl
    call put_piece
    test al, al
    jnz .set_piece
    mov byte [piece_y], bl
    cmp byte [drop], 1
    je .down_loop
    jmp .end_input
.set_piece:
    mov byte [drop], 0
    mov bh, byte [piece_x]
    mov bl, byte [piece_y]
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
    mov bh, starting_x
    mov bl, starting_y
    mov byte [piece_x], bh
    mov byte [piece_y], bl
    inc bl
    xor dl, dl
    call put_piece
    test al, al
    jz .check_lines
    mov byte [running], 0
    jmp .end_input 
.check_lines:
    mov si, score_multipliers
    mov bx, board
    mov cx, 20
.line_check_y:
    xor al, al
    push cx
    mov cx, 10
.line_check_x:
    cmp byte [bx], still_piece
    je .line_check_x_done
    mov al, 1 
.line_check_x_done:
    add bx, 2
    loop .line_check_x
    test al, al
    jnz .no_line
    add si, 2
    inc word [lines]
    mov dx, word [lines]
    call div10
    test ax, ax
    jnz .no_speed_increase
    cmp byte [down_threshold], minimum_speed 
    jbe .no_speed_increase
    sub byte [down_threshold], speed_decrement_value
.no_speed_increase:
    push bx
.remove_line:
    sub bx, 2
    cmp bx, board
    jb .remove_line_done
    mov ax, word [bx - 20]
    mov word [bx], ax
    jmp .remove_line
.remove_line_done:
    pop bx
.no_line:
    pop cx
    loop .line_check_y
    lodsw
    add word [score], ax
    mov dx, word [score]
    mov di, score_msg + 11
    std
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
    mov bh, byte [piece_x]
    test bh, bh
    jz .end_input
    dec bh
    mov bl, byte [piece_y]
    xor dl, dl
    mov si, word [current_piece_ptr]
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
    mov bh, byte [piece_x]
    add ah, bh
    cmp ah,  10
    je .end_input
    inc bh
    mov bl, byte [piece_y]
    xor dl, dl
    call put_piece
    test al, al
    jnz .end_input
    mov byte [piece_x], bh
    dec bh
.end_horizontal_move:
    mov dl, empty_space
    mov si, word [current_piece_ptr]
    call put_piece
    mov byte [board_update], 1
    jmp .end_input
.no_right:
    cmp al, exit_key
    jne .no_esc
    mov byte [running], 0
    jmp .end_input
.no_esc:
    cmp ax, drop_key
    jne .end_input
    mov byte [drop], 1
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
    cmp byte [running], 1
    je .main_loop
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
