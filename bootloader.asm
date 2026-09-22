; bootloader.asm
; Stage 1: Lock screen + random code generator (x86, BIOS, MBR)

[org 0x7c00]

start:
    ; Set up stack
    xor ax, ax
    mov ss, ax
    mov sp, 0x7c00

    ; Clear screen
    mov ah, 0x00
    mov al, 0x03
    int 0x10

    ; Print title
    mov si, msg_title
    call print_string

    ; Generate a pseudo-random 4-digit code (0–9999)
    ; (Using timer as entropy source)
    mov ah, 0x00
    int 0x1A              ; BIOS time-of-day
    ; CX:DX has ticks; use DX as seed
    mov ax, dx
    ; Simple mod 10000
    mov bx, 10000
    xor dx, dx
    div bx                ; AX = code (0–9999)

    mov [code_value], ax  ; store raw code

    ; Show the code once to the user
    mov si, msg_code
    call print_string
    mov ax, [code_value]
    call print_decimal_4

    ; At this point, Stage 2 would:
    ; - Compute SHA-256(code_value)
    ; - Store hash
    ; - Prompt user to re-enter code
    ; - Compare SHA-256(input) with stored hash
    ; - Boot OS if match, else lock

    ; For now, just hang (placeholder)
hang:
    jmp hang

; -----------------------
; Print string (SI = ptr)
print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0e
    mov bh, 0x00
    mov bl, 0x07
    int 0x10
    jmp print_string
.done:
    ret

; -----------------------
; Print 4-digit decimal in AX (zero-padded)
print_decimal_4:
    ; AX = value 0–9999
    mov bx, 10
    mov cx, 4
    mov di, digits+4

.next_digit:
    xor dx, dx
    div bx          ; AX = AX/10, DX = remainder
    dec di
    add dl, '0'
    mov [di], dl
    loop .next_digit

    mov si, digits
    call print_string
    ret

msg_title db 'LOCK SCREEN BOOTLOADER', 0x0D, 0x0A, 0
msg_code  db 'Your one-time code: ', 0
digits    db '0000', 0

code_value dw 0

times 510 - ($ - $$) db 0
dw 0xAA55
