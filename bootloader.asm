[BITS 16]
[ORG 0x7c00] 

start:
    ; Set up segment registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; print welcome message
    mov si, msg_welcome
    call print_string

    ; read sectors into memory at 0x7e00
    mov bx, 0x7e00
    call read_sector

    jmp 0x0000:0x7e00  

print_string:
    lodsb
    cmp al, 0
    jz done_print
    mov ah, 0x0e
    int 0x10
    jmp print_string
done_print:
    ret

; read the next 5 sectors
read_sector:
    mov ah, 0x02
    mov al, 5
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, 0x80
    int 0x13
    jc disk_error

    ret

disk_error:
    mov si, msg_error
    call print_string
    hlt 

msg_welcome db "Welcome to SheepOS!", 0
msg_error db "Disk read error!", 0

times 510-($-$$) db 0
dw 0xaa55
