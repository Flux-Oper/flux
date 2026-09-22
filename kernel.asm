; kernel.asm
; Minimal real-mode kernel for your volcanic boot chain

[org 0x1000]        ; must match where Stage 2 loads us

start:
    ; Clear screen
    mov ah, 0x00
    mov al, 0x03
    int 0x10

    ; Print message
    mov si, msg
    call print_string

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

msg db '🔥 ONLINE - running', 0
msg db '🐎 Starting your computer...', 0

times 4096 - ($ - $$) db 0
