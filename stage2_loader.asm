; stage2_loader.asm
; Stage 2: SHA-256 lock screen + kernel chainload (skeleton)

[org 0x8000]          ; assume Stage 1 loaded us here

start:
    ; Clear screen
    mov ah, 0x00
    mov al, 0x03
    int 0x10

    mov si, msg_title
    call print_string

    mov si, msg_prompt
    call print_string

    ; Read 4-digit code from keyboard into buffer
    mov di, input_buf
    mov cx, 4

.read_loop:
    mov ah, 0x00
    int 0x16          ; BIOS keyboard
    cmp al, 0x0D      ; Enter?
    je .done_input
    ; Only accept '0'–'9'
    cmp al, '0'
    jb .read_loop
    cmp al, '9'
    ja .read_loop

    stosb
    loop .read_loop

.done_input:
    mov al, 0
    stosb             ; null-terminate

    ; ---------------------------
    ; Placeholder: SHA-256(input_buf)
    ; In a real build, you’d link or include
    ; a full SHA-256 implementation here.
    ; ---------------------------

    ; For now, pretend we computed hash into hash_buf
    ; and compare with expected_hash (from Stage 1).

    mov si, hash_buf
    mov di, expected_hash
    mov cx, 32        ; 32 bytes = 256 bits

.compare_loop:
    repe cmpsb
    jne auth_fail

auth_ok:
    mov si, msg_ok
    call print_string
    ; TODO: load and jump to kernel.bin here
hang_ok:
    jmp hang_ok

auth_fail:
    mov si, msg_fail
    call print_string
hang_fail:
    jmp hang_fail

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

msg_title      db 'STAGE 2: SHA-256 LOCK', 0x0D, 0x0A, 0
msg_prompt     db 'Re-enter your 4-digit code: ', 0
msg_ok         db 0x0D, 0x0A, 'ACCESS GRANTED - BOOTING KERNEL...', 0
msg_fail       db 0x0D, 0x0A, 'ACCESS DENIED - SYSTEM LOCKED.', 0

input_buf      times 8 db 0
hash_buf       times 32 db 0          ; placeholder
expected_hash  times 32 db 0          ; fill from Stage 1 / disk

times 4096 - ($ - $$) db 0           ; pad to a small binary size
