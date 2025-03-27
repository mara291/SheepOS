[BITS 16]
[ORG 0x7e00]
; TO 0x8900
; 2560 bytes

start:
    call enter
    call enter

    mov si, sheep_art
    call print_si
    jmp main


init_allocation_map:
    ; check if allocation map was alr initialized
    mov word [sector], 10
    call lba_read
    mov si, msg_map
    mov di, 0x9000
init_allocation_map_loop:
    mov al, [si]
    mov ah, [di]
    inc si
    inc di
    cmp al, 0
    je alr_initialised
    cmp al, ah
    jne uninitialised
    jmp init_allocation_map_loop
    
alr_initialised:
    ret

; should only happen once
uninitialised:
    ; put msg_map on disk and then fill with 1 (free)
    mov si, msg_map

    xor ax, ax
    mov es, ax
    mov di, 0x9000
    mov cx, 4

    mov cx, 512 
init_fill_loop2:
    mov byte [di], '1'
    inc di
    loop init_fill_loop2

    mov di, 0x9000
    mov byte[di], 'm'
    mov byte[di+1], 'a'
    mov byte[di+2], 'p'
    mov byte[di+3], '!'
    call lba_write

    ; also reset here
    mov word [sector], 20
    call write_to_address_lba
    call lba_write

    ret


; print until 0 found
print_si:
    mov al, [si]
    inc si
    cmp al, 0
    je print_ret

    mov ah, 0x0e
    int 0x10
    jmp print_si

print_ret:
    ret


; print 512 characters
print_si_512:
    mov cx, 512
print_si_512_loop:
    mov al, [si]
    inc si
    mov ah, 0x0e
    int 0x10
    loop print_si_512_loop

    ret

; print 12 characters
print_si_12:
    mov cx, 12
print_si_12_loop:
    mov al, [si]
    inc si
    mov ah, 0x0e
    int 0x10
    loop print_si_12_loop

    ret


; compare strings stored at si and di
; null terminated string should be in si
cmp_si_di:
    xor cl, cl
cmp_loop:
    mov al, [si]
    mov ah, [di]
    cmp al, 0
    je cmp_ret
    cmp al, ah
    jne cmp_different
    inc si
    inc di
    jmp cmp_loop

cmp_different:
    ; strings not equal so inc cx and return
    inc cl
    ret
    
cmp_ret:
    ret


; compare file names (12 characters)
; file from disk is in si
; dl = 0 means name match
cmp_file_name:
    xor dl, dl
    mov cx, 12
cmp_file_name_loop:
    mov bl, [si]
    mov bh, [di]

    cmp bl, bh
    jne cmp_file_name_different
cmp_file_name_different_back:
    inc si
    inc di
    loop cmp_file_name_loop

    ; save file address if match
    cmp dl, 0
    je save
    add si, 4
    ret

cmp_file_name_different:
    ; strings not equal so inc dl
    inc dl
    jmp cmp_file_name_different_back

save:
    mov ax, [si]
    mov [file_address], ax

    add si, 4
    ret


return:
    ret


enter:
    mov ah, 0x0e

    mov al, 0x0d
    int 0x10

    mov al, 0x0a
    int 0x10

    ret


get_first_empty:
    ; loop in allocation map and remember first empty space's position
    ; hardcoded for one sector allocation map only
    mov word [sector], 10
    call lba_read
    mov di, 0x9000

    mov cx, 1
get_first_empty_loop:
    mov al, [di]

    ; if empty space found it is offset + cx
    cmp al, '1'
    je first_empty_found

    ; if no space left print disk full message
    cmp cx, 512
    je no_space_left

    inc cx
    inc di
    jmp get_first_empty_loop
    

no_space_left:
    mov si, msg_no_space
    call print_si
    ret

first_empty_found:
    mov byte [di], '2'
    ; save cx in file_address
    mov word [file_address], cx
    call lba_write
    ret


lba_read:
    call enter

    ; set ES:BX to point to memory address 0x9000
    xor ax, ax
    mov es, ax
    mov bx, 0x9000 
    mov ax, [sector]
    mov word [disk_packet + 8], ax
    mov word [disk_packet + 10], 0 
    mov word [disk_packet + 12], 0 
    mov word [disk_packet + 14], 0 

    mov ah, 0x42 ; LBA read
    mov dl, 0x80 
    mov si, disk_packet ; disk packet address
    int 0x13

    jc error

    ret


write_to_address_lba:
    xor ax, ax
    mov es, ax
    mov di, 0x9000
    mov cx, 512
    
fill_loop:
    mov byte [di], '_'
    inc di
    loop fill_loop

    ret


lba_write:
    mov ax, [sector]
    mov word [disk_packet + 8], ax
    mov word [disk_packet + 12], 0
    mov word [disk_packet + 14], 0 

    mov ah, 0x43 ; LBA write
    mov dl, 0x80 
    mov si, disk_packet ; disk packet address
    int 0x13

    jc error 

    ret


disk_packet:
    db 0x10   ; packet size (16 bytes)
    db 0x00   ; reserved (must be 0)
    dw 1      ; number of sectors to write
    dw 0x9000 ; memory location
    dw 0x0000 ; buffer segment
    dq 0      ; LBA sector number (updated dynamically)


; 31 files per sector
; 12 bytes name
; 4 bytes address
create_file:
    ; to create file, find an empty address to store file in
    mov word [sector], 10
    call get_first_empty
    ; now file address is stored in file_address

    ; read sector into memory at 0x9000
    mov word [sector], 20
    call lba_read

    mov word [sector], 20

    mov si, create_msg
    call print_si

    ; read 12 characters max
    mov cx, 0
    mov di, [name]
create_read:
    cmp cx, 12
    je name_filled
    ; read character
    mov ah, 0x00 
    int 0x16
    ; if enter
    cmp al, 0x0D
    je enter_pressed
    ; print character
    mov ah, 0x0e
    int 0x10
    ; save character in name
    mov byte [di], al
    inc di
    inc cx
    jmp create_read

enter_pressed:
    mov byte [di], '_'
    inc di
    inc cx
    cmp cx, 12
    je name_filled
    jmp enter_pressed

name_filled:
    call enter

    mov si, [name]
    ; find first empty destination address
    mov di, 0x9000
    ; counter for address location
    mov dh, 1
    
find_empty_address:
    cmp byte [di], '_' 
    je found_empty
    add di, 0x10
    inc dh
    cmp di, 0x9200
    jl find_empty_address
    jmp error

found_empty:

    mov cx, 12

copy_name_to_buffer:
    mov al, [si] 
    mov [di], al
    inc si
    inc di
    loop copy_name_to_buffer
    
    xor ax, ax
    mov ax, [file_address]
    add ax, 48
    ; ax contains the file address

    mov [di], ax
    mov byte [di+2], '_'
    mov byte [di+3], '_'

    mov si, 0x9000
    call lba_write
    jc error

    ret


edit_file:
    call enter

    mov si, create_msg
    call print_si

    mov di, 0x9300

    ; read max 12 characters and fill rest with '_'
    mov cx, 12
edit_file_name:
    cmp cx, 0
    je name_filled2
    ; read character
    mov ah, 0x00 
    int 0x16
    ; if enter
    cmp al, 0x0D
    je enter_pressed2
    ; print character
    mov ah, 0x0e
    int 0x10
    ; save character in di
    mov byte [di], al
    inc di
    dec cx
    jmp edit_file_name

enter_pressed2:
    mov byte [di], '_'
    inc di
    dec cx
    cmp cx, 0
    je name_filled2
    jmp enter_pressed2

name_filled2:
    call enter

    ; search for file with the entered name
    mov word [sector], 20
    call lba_read
    ; compare 0x9000, 0x8210, 0x8220..

find_file:
    mov si, 0x9000
find_file_loop:
    mov di, 0x9300
    call cmp_file_name
    cmp dl, 0
    je file_found

    cmp si, 0x9100
    jae file_not_found
    jmp find_file_loop

file_found:
    ; memorize address of file
    ; address is at si+12
    add si, 12

    call read_file_content
    ret

file_not_found:
    mov si, msg_no_file
    call print_si
    ret

read_file_content:
    xor ax, ax
    mov es, ax
    mov bx, 0x9000
    mov ax, word [file_address]
    mov word [disk_packet + 8], ax
    mov word [disk_packet + 12], 0 
    mov word [disk_packet + 14], 0 

    mov ah, 0x42
    mov dl, 0x80 
    mov si, disk_packet
    int 0x13

    jc error

    ; switch to page 1
    mov ah, 0x05
    mov al, 1 
    int 0x10 

    call clear_screen_page1
    ; set cursor on 0,0
    mov ah, 0x02
    mov bh, 1
    mov dh, 0
    mov dl, 0
    int 0x10

    mov si, 0x9000
    call print_si_512

    mov ah, 0x0e
    mov al, 'E'
    int 0x10
    mov al, 'O'
    int 0x10
    mov al, 'F'
    int 0x10

    ; move cursor back to location
    mov ah, 0x02
    mov bh, 0x01
    mov dh, [cursor_row]
    mov dl, [cursor_column]
    int 0x10

    mov di, 0x9000

read_file_characters:
    ; read character
    mov ah, 0x00 
    int 0x16

    ; check if any arrow is pressed
    cmp ah, 0x4b
    je arrow_left

    cmp ah, 0x4d
    je arrow_right

    cmp ah, 0x50
    je arrow_down

    cmp ah, 0x48
    je arrow_up

    ; backspace
    cmp al, 0x08
    je backspace

    ; if esc pressed exit and switch page
    cmp al, 0x1B
    je edit_done

    ; if enter pressed exit and switch page
    cmp al, 0x0D
    je edit_done

    ; save character in di
    mov byte [di], al
    inc di

    ; print character
    mov ah, 0x0e
    int 0x10

    jmp read_file_characters

backspace:
    ; check if at beginning
    cmp di, 0x9200
    je read_file_characters

    ; move back one position in memory
    dec di

    ; erase char in buffer
    mov byte [di], ' '

    ; get cursor position
    mov ah, 0x03
    mov bh, 0x01
    int 0x10

    ; move cursor one left
    dec dl

    ; move cursor
    mov ah, 0x02
    mov bh, 0x01
    int 0x10

    ; print space to erase previous character
    mov ah, 0x0e
    mov al, ' '
    int 0x10

    ; move cursor back again
    mov ah, 0x02
    mov bh, 0x01
    int 0x10

    jmp read_file_characters


arrow_left:
    ; get cursor position
    mov ah, 0x03 
    mov bh, 0x01
    int 0x10

    ; if position on 0 do not update
    cmp dl, 0
    je read_file_characters

    ; update cursor to left
    mov ah, 0x02
    mov bh, 0x01
    dec dl
    int 0x10

    dec di

    jmp read_file_characters

arrow_right:
    ; get cursor position
    mov ah, 0x03 
    mov bh, 0x01
    int 0x10

    ; update cursor to right
    mov ah, 0x02
    mov bh, 0x01
    inc dl
    int 0x10

    inc di

    jmp read_file_characters

arrow_down:
    ; get cursor position
    mov ah, 0x03 
    mov bh, 0x01
    int 0x10

    ; update cursor to down
    mov ah, 0x02
    mov bh, 0x01
    inc dh
    int 0x10

    add di, 80

    jmp read_file_characters

arrow_up:
    ; get cursor position
    mov ah, 0x03 
    mov bh, 0x01
    int 0x10

    ; if position on 0 do not update
    cmp dh, 0
    je read_file_characters

    ; update cursor to down
    mov ah, 0x02
    mov bh, 0x01
    dec dh
    int 0x10

    sub di, 80

    jmp read_file_characters

edit_done:
    ; switch back to page 0
    mov ah, 0x05
    mov al, 0
    int 0x10

    ; write changes to disk
    mov ax, [file_address]
    mov word [sector], ax
    call lba_write
    ret

clear_screen_page1:
    push ax
    push cx
    push dx

    mov ah, 0x06
    mov al, 0
    mov bh, 0x07
    mov cx, 0x0000
    mov dx, 0x184F
    mov bh, 0x07
    int 0x10

    pop dx
    pop cx
    pop ax
    ret


list:
    call enter
    mov word [sector], 20
    call lba_read
    ; all files are now at 0x9000
    ; print only names 
    mov si, 0x9000
list_loop:
    cmp si, 0x9200
    je list_done

    call list_print

    add si, 0x10
    jmp list_loop

list_print:
    mov cx, 12
    mov di, si 

    ; if filename starts with _ then no file in that location
    mov al, [di]
    cmp al, '_'
    je return 

list_print_loop:
    mov al, [di]

    cmp al, '_'
    je list_print_done

    mov ah, 0x0e
    int 0x10

    inc di

    loop list_print_loop

list_print_done:
    call enter
    ret

list_done:
    ret


; similar to edit but just prints file contents
view:
    call enter
    ; call enter name routine
    call enter_name

    ; search for file with the entered name
    mov word [sector], 20
    call lba_read
    ; compare 0x9000, 0x8210, 0x8220..

find_file2:
    mov si, 0x9000

find_file_loop2:
    mov di, 0x9300
    call cmp_file_name
    cmp dl, 0
    je file_found2

    cmp si, 0x9100
    jae file_not_found2
    jmp find_file_loop2

file_found2:
    sub si, 4
    call enter

    mov si, msg_view
    call print_si

    call enter
    call view_file

    ret

file_not_found2:
    mov si, msg_no_file
    call print_si
    ret

view_file:
    xor ax, ax
    mov es, ax
    mov bx, 0x9000
    mov ax, word [file_address]
    mov word [disk_packet + 8], ax
    mov word [disk_packet + 12], 0 
    mov word [disk_packet + 14], 0 

    mov ah, 0x42
    mov dl, 0x80 
    mov si, disk_packet
    int 0x13

    jc error

    mov si, 0x9000
    call print_si_512

    ret


delete:
    ; call enter name routine
    call enter_name

    ; name is at 0x9300
    ; search for file with the entered name
    mov word [sector], 20
    call lba_read
    ; compare 0x9000, 0x8210, 0x8220..

find_file3:
    mov si, 0x9000

find_file_loop3:
    mov di, 0x9300
    call cmp_file_name
    cmp dl, 0
    je file_found3

    cmp si, 0x9100
    jae file_not_found3
    jmp find_file_loop3

file_found3:
    call enter

    ; si has address of file entry in root
    sub si, 16
    ; make next 16 characters '_'
    mov cx, 16

file_found3_loop:
    mov byte [si], '_'
    inc si
    loop file_found3_loop

    mov si, msg_delete
    call print_si

    ; write changes to disk
    mov word [sector], 20
    call lba_write

    call delete_map_entry
    call delete_file_data

    ret

file_not_found3:
    mov si, msg_no_file
    call print_si
    ret

delete_map_entry:
    ; read entry
    mov word [sector], 10
    call lba_read
    mov di, 0x9000

    ; get address to edit in dl
    xor dx, dx
    mov dx, [file_address]
    sub dx, 48

    dec dx ; bcs mapping starts from 1
    add di, dx

    ; mark spot as empty
    mov byte [di], '1'

    ; write back to disk
    call lba_write

    ret

delete_file_data:
    ; read file data
    mov ax, [file_address]
    mov word [sector], ax
    call lba_read

    ; overwrtite contents from 0x9000 with spaces
    mov di, 0x9000
    mov cx, 512
delete_file_data_loop:
    mov byte [di], ' '
    inc di

    loop delete_file_data_loop

    ; write changes back
    call lba_write

    ret


; enter name and save it at 0x9300
enter_name:
    call enter

    mov si, create_msg
    call print_si

    mov di, 0x9300

    ; read max 12 characters and fill rest with '_'
    mov cx, 12
enter_name_characters:
    cmp cx, 0
    je name_filled0
    ; read character
    mov ah, 0x00 
    int 0x16
    ; if enter
    cmp al, 0x0D
    je enter_pressed0
    ; print character
    mov ah, 0x0e
    int 0x10
    ; save character in di
    mov byte [di], al
    inc di
    dec cx
    jmp enter_name_characters

enter_pressed0:
    mov byte [di], '_'
    inc di
    dec cx
    cmp cx, 0
    je name_filled0
    jmp enter_pressed0

name_filled0:
    ret


help:
    call enter
    call enter
    
    mov si, help0
    call print_si
    call enter

    mov si, help1
    call print_si
    call enter

    mov si, help2
    call print_si
    call enter

    mov si, help3
    call print_si
    call enter

    mov si, help4
    call print_si
    call enter

    mov si, help5
    call print_si
    call enter

    mov si, help6
    call print_si
    call enter

    mov si, help7
    call print_si
    call enter

    mov si, help8
    call print_si
    call enter

    mov si, help9
    call print_si
    call enter

    ret


info:
    call enter
    mov si, msg_info
    call print_si
    ret


sheep:
    call enter
    call enter
    mov si, sheep_art
    call print_si

    ret


main:
    call enter

    call init_allocation_map

    mov word [sector], 20
    call lba_read

    jmp main_loop

main_loop:
    mov si, prompt
    call print_si

    ; reset di
    mov di, 0x9900

print_character:
    ; read character
    mov ah, 0x00 
    int 0x16

    ; add character to buffer
    mov byte [di], al
    inc di

    ; if enter pressed review command
    cmp al, 0x0D
    je review_command

    ; print character
    mov ah, 0x0e
    int 0x10

    jmp print_character

print_newline:
    ; print newline
    mov ah, 0x0e

    mov al, 0x0d
    int 0x10

    mov al, 0x0a
    int 0x10

    jmp main_loop

review_command:
    ; compare input with commands and call functions

    ; READ
    mov di, 0x9900
    mov si, command_read
    call cmp_si_di
    cmp cl, 0
    je call_lba_read

    ; WRITE
    mov di, 0x9900
    mov si, command_write
    call cmp_si_di
    cmp cl, 0
    je call_lba_write

    ; CREATE
    mov di, 0x9900
    mov si, command_create
    call cmp_si_di
    cmp cl, 0
    je call_create_file

    ; EDIT
    mov di, 0x9900
    mov si, command_edit
    call cmp_si_di
    cmp cl, 0
    je call_edit_file

    ; RESET
    mov di, 0x9900
    mov si, command_reset
    call cmp_si_di
    cmp cl, 0
    je call_reset

    ; LIST
    mov di, 0x9900
    mov si, command_list
    call cmp_si_di
    cmp cl, 0
    je call_list

    ; VIEW
    mov di, 0x9900
    mov si, command_view
    call cmp_si_di
    cmp cl, 0
    je call_view

    ; DELETE
    mov di, 0x9900
    mov si, command_delete
    call cmp_si_di
    cmp cl, 0
    je call_delete

    ; RANDOM
    mov di, 0x9900
    mov si, command_random
    call cmp_si_di
    cmp cl, 0
    je call_random

    ; HELP
    mov di, 0x9900
    mov si, command_help
    call cmp_si_di
    cmp cl, 0
    je call_help

    ; INFO
    mov di, 0x9900
    mov si, command_info
    call cmp_si_di
    cmp cl, 0
    je call_info

    ; SHEEP
    mov di, 0x9900
    mov si, command_sheep
    call cmp_si_di
    cmp cl, 0
    je call_sheep

    jmp print_newline


call_lba_write:
    mov word [sector], 20
    ;call lba_write
    jmp print_newline

call_lba_read:
    mov word [sector], 20
    ;call lba_read
    jmp print_newline

call_create_file:
    mov word [sector], 20
    call create_file
    jmp print_newline

call_edit_file:
    mov word [sector], 30
    call edit_file
    jmp print_newline

call_reset:
    mov word [sector], 20
    ;call write_to_address_lba
    ;call lba_write
    jmp print_newline

call_list:
    call list
    jmp print_newline

call_view:
    call view
    jmp print_newline

call_delete:
    call delete
    jmp print_newline

call_random:
    jmp print_newline

call_help:
    call help
    jmp print_newline

call_info:
    call info
    jmp print_newline

call_sheep:
    call sheep
    jmp print_newline

test:
    mov ah, 0x0e
    mov al, 'p'
    int 0x10

error:
    mov si, msg_error
    call print_si
    hlt


prompt db "sheep:", 0
msg_error db "ERROR", 0
create_msg db "Enter name: ", 0
name db "------------"
data1 db "mara", 0
msg_map db "map!", 0
msg_no_space db "No space left on disk!", 0
msg_edit db " is opened for editing:", 0
msg_no_file db "File does not exist!", 0
msg_view db "File contents:", 0
msg_delete db "File was deleted!", 0
msg_info db "Stay tuned, some info will be added soon!", 0

command_read db "read", 0
command_write db "write", 0
command_create db "create", 0
command_edit db "edit", 0
command_reset db "reset", 0
command_list db "list", 0
command_view db "view", 0
command_delete db "delete", 0
command_random db "random", 0
command_help db "help", 0
command_info db "info", 0
command_sheep db "sheep", 0

buffer dw 0x9900
sector dw 20
file_address dw 0 ; real number +48
allocation_map dw 10 ; 10-20
root dw 20 ; 20-30
files dw 30 ; 30-100
files_offset dw 25
cursor_row db 0
cursor_column db 0

help0 db "Type a command and press enter. For the commands requiring a file name you will have a special prompt.", 0
help1 db "Available commands:", 0
help2 db "create - create a new file", 0
help3 db "delete - delete a file", 0
help4 db "edit - edit a file", 0
help5 db "help - provides a list of all commands", 0
help6 db "info - prints detailed info for all commands", 0
help7 db "list - list all files", 0
help8 db "sheep - prints a sheep", 0
help9 db "view - view contents of a file", 0

sheep_art db "     ,~'``'~;'``'~,", 0x0D, 0x0A
          db "   _(              )", 0x0D, 0x0A
          db " ,'o''(             )>", 0x0D, 0x0A
          db "(__,-'              )", 0x0D, 0x0A
          db "   (               )", 0x0D, 0x0A
          db "    `-'._.-~~-;_.-'", 0x0D, 0x0A
          db "       |||    |||", 0x0D, 0x0A
          db 0

times 2560-($-$$) db 0
