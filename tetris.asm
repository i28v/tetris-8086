bits 16
org 0x100

jmp start

align 4

scoremsg db "Score:     0"

TN db 0x01, 0x11, 0x21, 0x10, 0x32, 0x00
dw 0x0000
TE db 0x00, 0x01, 0x02, 0x11, 0x23, 0x00
dw 0x0000
TS db 0x00, 0x10, 0x20, 0x11, 0x32, 0x00
dw 0x0000
TW db 0x10, 0x11, 0x12, 0x01, 0x23, 0x01
dw TN
IV db 0x00, 0x01, 0x02, 0x03, 0x14, 0x00
dw 0x0000
IH db 0x03, 0x13, 0x23, 0x33, 0x44, 0x01
dw IV
SRV db 0x00, 0x01, 0x11, 0x12, 0x23, 0x00
dw 0x0000
SRH db 0x01, 0x11, 0x10, 0x20, 0x32, 0x01
dw SRV
SLV db 0x10, 0x11, 0x01, 0x02, 0x23, 0x00
dw 0x0000
SLH db 0x00, 0x10, 0x11, 0x21, 0x32, 0x01
dw SLV
LRN db 0x00, 0x01, 0x02, 0x12, 0x23, 0x00
dw 0x0000
LRE db 0x00, 0x10, 0x20, 0x01, 0x32, 0x00
dw 0x0000
LRS db 0x00, 0x10, 0x11, 0x12, 0x23, 0x00
dw 0x0000
LRW db 0x01, 0x11, 0x21, 0x20, 0x32, 0x01
dw LRN
LLN db 0x10, 0x11, 0x02, 0x12, 0x23, 0x00
dw 0x0000
LLE db 0x00, 0x01, 0x11, 0x21, 0x32, 0x00
dw 0x0000
LLS db 0x00, 0x10, 0x01, 0x02, 0x23, 0x00
dw 0x0000
LLW db 0x00, 0x10, 0x20, 0x21, 0x32, 0x01
dw LLN
O db 0x00, 0x10, 0x01, 0x11, 0x22, 0xFF
dw 0x0000

sp1 dw TE
sp2 dw IV
sp3 dw SRV
sp4 dw SLV
sp5 dw LRS
sp6 dw LLS
sp7 dw O

score resw 1
lines resw 1
piece_x resb 1
piece_y resb 1

collision resb 1
drop resb 1
board_update resb 1
down_delay resb 1
down_threshold resb 1

current_piece_ptr resw 1
previous_piece_ptr resw 1

random_seed resw 1

running resb 1

board resb 200 

screen_buffer equ 0xB800

score_offset equ 3360

rotate_key equ 0x48
down_key equ 0x50
left_key equ 0x4B
right_key equ 0x4D
drop_key equ 0x3920
exit_key equ 0x1B

random_multiplier equ 25173
random_increment_value equ 13849

moving_piece equ 0x23
still_piece equ 0x63
empty_space equ 0x2E
piece_mask equ 0x3F

starting_x equ 4
starting_y equ 0

score_increment_value equ 250

starting_speed equ 20
speed_change_threshold equ 3
minimum_speed equ 2
speed_decrement_value equ 2
delay_in_microseconds equ 50000

align 4

start:
    cld
    xor ax, ax
    mov word [score], ax
    mov word [lines], ax
    mov word [previous_piece_ptr], ax
    mov byte [collision], al 
    mov byte [drop], al
    mov byte [down_delay], al
    mov byte [down_threshold], starting_speed
    mov byte [piece_x], starting_x
    mov byte [piece_y], starting_y
    mov byte [running], 1
    mov byte [board_update], 1
    xor ah, ah
    int 0x1A
    mov word [random_seed], dx
    and dx, 7
    jz .start_piece_is_zero
    dec dx
.start_piece_is_zero:
    shl dx, 1
    lea bx, [sp1]
    add bx, dx
    mov ax, word [bx]
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
    pop es
    mov ax, 0x2E2E
    lea di, [board]
    mov cx, 100
    rep stosw
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
    lea si, [board]
    xor di, di 
    mov cx, 20
.print_board_y: 
    push cx
    mov cx, 10
.print_board_x:
    lodsb
    and al, piece_mask
    stosb
    inc di
    loop .print_board_x
    add di, 140
    pop cx
    loop .print_board_y
    lea si, [scoremsg]
    mov di, score_offset
    mov cx, 12
.print_score:
    movsb
    inc di
    loop .print_score 
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
    jle .check_y
    mov dh, dl
    dec dh
.check_y:
    cmp al, 20
    jg .end_input
    sub bh, dh
    xor dl, dl 
    mov byte [collision], dl
    call put_piece
    cmp byte [collision], 1
    je .end_input
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
    jge .set_piece
    mov bh, byte [piece_x]
    inc bl
    xor dl, dl
    mov byte [collision], dl
    call put_piece
    cmp byte [collision], 1
    je .set_piece
    mov byte [piece_y], bl
    cmp byte [drop], 1
    je .down_loop
    jmp .end_input
.set_piece:
    mov byte [drop], 0
    mov bh, byte [piece_x]
    mov bl, byte [piece_y]
    cmp bl, 3 
    jg .not_at_top
    mov byte [running], 0
    jmp .end_input
.not_at_top:
    mov dl, empty_space
    mov si, word [current_piece_ptr]
    call put_piece
    mov dl, still_piece
    call put_piece
    mov ax, random_multiplier
    mul word [random_seed]
    add ax, random_increment_value
    mov word [random_seed], ax
    and ax, 7
    jz .is_zero
    dec ax
.is_zero:
    shl ax, 1
    lea bx, [sp1]
    add bx, ax
    mov ax, word [bx]
    mov word [current_piece_ptr], ax 
    mov byte [piece_x], starting_x
    mov byte [piece_y], starting_y
    inc word [score]
.check_lines:
    lea bx, [board + 20]
    mov cx, 18 
.line_check_y:
    xor ax, ax
    push cx
    mov cx, 10
.line_check_x:
    cmp byte [bx], still_piece
    je .line_check_x_done
    mov ax, 1 
.line_check_x_done:
    inc bx
    loop .line_check_x
    test ax, ax
    jnz .no_line
    add word [score], score_increment_value
    mov ax, word [lines]
    inc word [lines]
    and ax, speed_change_threshold
    jnz .no_speed_increase
    cmp byte [down_threshold], minimum_speed 
    jle .no_speed_increase
    sub byte [down_threshold], speed_decrement_value
.no_speed_increase:
    push bx
.remove_line:
    dec bx
    cmp bx, board + 20
    jl .remove_line_done
    mov al, byte [bx - 10]
    mov byte [bx], al
    jmp .remove_line
.remove_line_done:
    pop bx
.no_line:
    pop cx
    loop .line_check_y
    mov dx, word [score]
    lea di, [scoremsg + 11]
    std
.div10:
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
    or al, 0x30
    stosb
    test dx, dx
    jnz .div10
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
    mov byte [collision], dl
    mov si, word [current_piece_ptr]
    call put_piece
    cmp byte [collision], 1
    je .end_input
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
    mov byte [collision], dl
    call put_piece
    cmp byte [collision], 1
    je .end_input
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
    jge .auto_down
    inc byte [down_delay]
    xor cx, cx
    mov dx, delay_in_microseconds
    mov ah, 0x86
    int 0x15
    cmp byte [running], 1
    je .main_loop
end:
    mov ah, 1
    mov cx, 0x0607
    int 0x10
    mov ax, 0x0003
    int 0x10
    mov ax, 0x4C00
    int 0x21
    jmp $

align 4

put_piece:
    push ax
    push cx
    push dx
    push si
    push di
    mov cx, 4 
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
    test dl, dl
    jnz .place
    cmp byte [board + di], still_piece
    jne .continue
    mov byte [collision], 1
    jmp .end
.place:
    mov byte [board + di], dl
.continue:
    loop .get_position
.end:
    pop di
    pop si
    pop dx
    pop cx
    pop ax
    ret
