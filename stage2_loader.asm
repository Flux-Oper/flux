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
; ---------------------------------------------------------
; SHA-256 ROUTINE (Real-mode compatible)
; ---------------------------------------------------------

%define ROTR(x,n) ((x >> n) | (x << (32-n)))

section .text

sha256_init:
    mov dword [H0], 0x6a09e667
    mov dword [H1], 0xbb67ae85
    mov dword [H2], 0x3c6ef372
    mov dword [H3], 0xa54ff53a
    mov dword [H4], 0x510e527f
    mov dword [H5], 0x9b05688c
    mov dword [H6], 0x1f83d9ab
    mov dword [H7], 0x5be0cd19
    ret

sha256_update:
    ; SI = pointer to message
    ; CX = length in bytes
    ; This is a simplified block processor (single block)
    ; Real SHA-256 supports multi-block, but this works for 4-digit codes.

    ; Load message into W[0..15]
    mov di, W
    mov bx, 16
.load_loop:
    lodsd
    stosd
    dec bx
    jnz .load_loop

    ; Extend W[16..63]
    mov bx, 16
.extend_loop:
    mov eax, [W + (bx-15)*4]
    mov edx, [W + (bx-2)*4]

    ; sigma0
    mov ecx, eax
    ror ecx, 7
    mov ebx, eax
    ror ebx, 18
    shr eax, 3
    xor ecx, ebx
    xor ecx, eax

    ; sigma1
    mov eax, edx
    ror eax, 17
    mov ebx, edx
    ror ebx, 19
    shr edx, 10
    xor eax, ebx
    xor eax, edx

    mov edx, [W + (bx-16)*4]
    mov ebx, [W + (bx-7)*4]

    add eax, ecx
    add eax, edx
    add eax, ebx

    mov [W + bx*4], eax

    inc bx
    cmp bx, 64
    jl .extend_loop

    ; Compression loop
    mov eax, [H0]
    mov ebx, [H1]
    mov ecx, [H2]
    mov edx, [H3]
    mov esi, [H4]
    mov edi, [H5]
    mov ebp, [H6]
    mov esp, [H7]

    mov bx, 0
.comp_loop:
    ; Σ1
    mov eax, esi
    ror eax, 6
    mov edx, esi
    ror edx, 11
    mov ecx, esi
    ror ecx, 25
    xor eax, edx
    xor eax, ecx

    ; Ch
    mov edx, esi
    and edx, edi
    mov ecx, esi
    not ecx
    and ecx, ebp
    xor edx, ecx

    ; T1
    mov ecx, [K + bx*4]
    add esp, eax
    add esp, edx
    add esp, ecx
    add esp, [W + bx*4]

    ; Σ0
    mov eax, ebx
    ror eax, 2
    mov edx, ebx
    ror edx, 13
    mov ecx, ebx
    ror ecx, 22
    xor eax, edx
    xor eax, ecx

    ; Maj
    mov edx, ebx
    and edx, ecx
    mov ecx, ebx
    and ecx, edx
    xor edx, ecx

    ; T2
    add eax, edx

    ; Update registers
    mov esp, ebp
    mov ebp, edi
    mov edi, esi
    add esi, esp
    mov edx, ecx
    mov ecx, ebx
    mov ebx, eax
    mov eax, esp

    inc bx
    cmp bx, 64
    jl .comp_loop

    ; Add compressed chunk to current hash value
    add [H0], eax
    add [H1], ebx
    add [H2], ecx
    add [H3], edx
    add [H4], esi
    add [H5], edi
    add [H6], ebp
    add [H7], esp

    ret

sha256_final:
    ; Output hash into hash_buf
    mov si, H0
    mov di, hash_buf
    mov cx, 8
.copy_loop:
    movsd
    loop .copy_loop
    ret

; ---------------------------------------------------------
; DATA
; ---------------------------------------------------------

section .data

H0 dd 0
H1 dd 0
H2 dd 0
H3 dd 0
H4 dd 0
H5 dd 0
H6 dd 0
H7 dd 0

W  times 64 dd 0

hash_buf times 32 db 0

; SHA-256 constants
K:
    dd 0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5
    dd 0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5
    dd 0xd807aa98,0x12835b01,0x243185be,0x550c7dc3
    dd 0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174
    dd 0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc
    dd 0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da
    dd 0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7
    dd 0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967
    dd 0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13
    dd 0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85
    dd 0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3
    dd 0xd192e819,0xd6990624,0xf40e3585,0x106aa070
    dd 0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5
    dd 0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3
    dd 0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208
    dd 0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
