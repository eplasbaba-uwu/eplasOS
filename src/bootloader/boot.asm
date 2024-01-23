; Difference between directive and instruction: 
; A directive gives a clue to the assembler that will affect how prgm gets compiled (not translated to machine code)
; An instruction is translated to machine code that the CPU will execute

; ORG directive - tells assembler where we expect our code to be loaded. 
[org 0x7c00] 
[bits 16]

; defining var to use later on (while printing a str)
%define ENDL 0x0D, 0x0A 


; FAT12 HEADER
jmp short start
nop

bdb_oem: db 'MSWIN4.1'
bdb_bps: dw 512 ; bytes per sector
bdb_spc: db 1 ; sectors per cluster
bdb_res_s: dw 1 ; reserved sectors
bdb_fat_count: db 2
dbd_dir_entry: dw 0E0h
bdb_total_sectors: dw 2880
bdb_media_desc: db 0F0h
bdb_spf: dw 9 ; sectors per fat
bdb_spt: dw 18 ; sectors per track
bdb_heads: dw 2
bdb_hide_s: dd 0 ; hidden sectors
bdb_large_s: dd 0 ; large sector count


; extended boot record
ebr_num: db 0 ; 0x00 floppy, 0x80 hdd, useless
db 0 ; reserved byte
ebr_sign: db 29h 
ebr_vol: db 12h, 34h, 56h, 78h ; serial numbers, values dont matter here
ebr_lab: db 'eplasOS    ' ; 11 bytes (characters) required, i filled it with spaces
ebr_sys: db 'FAT12   ' ; 8 bytes, also filled the remaining chars with spaces



start:
    jmp main


; params - ds:si points to string
puts: ; prints string to the screen
    ; save registers for modification
    push si 
    push ax
    push bx
.loop:
    lodsb ; loads next char into al
    or al, al ; verify if next char is null. if yes, zero flag is true.
    jz .done ; conditional jump, jumps to destination if zero flag is set.

    mov ah, 0x0e ; BIOS interrupt
    mov bh, 0 ; page num set to 0
    int 0x10
    jmp .loop

.done:
    pop ax
    pop bx
    pop si
    ret



main: 

    ; setup data segments
    mov ax, 0 ; cannot write to ds/es directly so use intermediary register
    mov ds, ax
    mov es, ax

    ;setup stack
    mov ss, ax
    mov sp, 0x7c00 ; stack grows downwards from where we are loaded in memory


    ;;
    ;; DISK READING PROCESS
    ;;
    mov [ebr_num], dl ; setting the BIOS to the drive number
    mov ax, 1 ; LBA=1, reading second sector
    mov cl, 1 ; 1 sector to read only
    mov bx, 0x7E00 ; data stored is after the bootloader
    call disk_read

    ; print msg
    mov si, msg_str
    call puts

    cli ; disables all interrupts so that CPU doesnt get out of hlt state
    hlt ; stops CPU from executing (can be resumed by an interrupt)

error:
    mov si, msg_err
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h ; INTERRUPT FOR USR KEYPRESS
    jmp 0FFFFh:0 ; jumps to the beginning of BIOS, effectively rebooting it


.halt:
    cli
    hlt 

;
; DISK ROUTINES
; Parameters:
;   - ax: LBA address
; Returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dh: head
;

lba_chs:
    push ax
    push dx
    xor dx, dx ; sets dx to 0
    div word [bdb_spt] ; ax = LBA / Sectors per track, bx = LBA % Sectors per track
    inc dx ; dx = (LBA % Sectors per track + 1), aka the sector
    mov cx, dx ; sets cx to sector

    xor dx, dx ; clear dx again
    div word [bdb_heads] ; ax = (LBA / sectors per track) / HEADS, aka the cylinder
                         ; dx = (LBA / sectors per track) % HEADS, aka the head
    mov dh, dl  ; set dh to head (the lower 8 bits of dx is dl)
    mov ch, al ; set ch to cylinder (again, lower 8 bits of ax)
    shl ah, 6 ; perform logical shift of 6 bits to the left for the ah register
    or cl, ah ; bitwise OR operator on cl and ah, puts upper 2 bits in cylinder

    pop ax
    mov dl, al ; restores dl
    pop ax
    ret




disk_read:

    ;; SAVING REGISTERS FOR USE LATER
    push ax
    push bx
    push cx
    push dx
    push di

    push cx ; saving num of sectors to read
    call lba_chs ; CHS computed
    ; AL is the num of sectors to read (1)
    pop ax
    mov ah, 02h
    mov di, 3 ; BIOS will retry thrice.

.retry:
    pusha ; saving all registers in case BIOS modifies something
    stc ; CARRY FLAG - SOME BIOS DONT DO IT AUTOMATICALLY
    int 13h ; if carry flag cleared, then success
    jnc .done


    popa ; in case of a failed disk read
    call reset_d

    dec di
    test di, di
    jnz .retry

.fail:
    jmp error


.done:
    popa
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
    ; all registers restored

reset_d:
    pusha
    mov ah, 0
    stc
    int 13h
    jc error
    popa
    ret


msg_str: db "Read success :D", ENDL, 0
msg_err: db "Read failed :(", ENDL, 0
; DB directive - stands for "define byte(s)". writes given byte(s) to the assembled binary file.
; TIMES directive - repeats given instructions 

times 510-($-$$) db 0 
; $ sign - special symbol equal to memory offset of current line
; $$ sign - equal to memory offset of whole prgm
; $-$$ - gives, in bytes, the size of our prgm so far
dw 0xaa55 ; CPU requires this word to execute bootloader



;Referencing a memory location in assembly:
;syntax-->  segment: [base + index * scale + displacement]
;potential values for segment --> CS, DS, ES, FS, GS, SS
;potential values for base --> for 16 bits, BP/BX. for 32/64 bits, any general purpose register
;potential values for index --> for 16 bits, SI/DI. for 32/64 bits, any general purpose register
;potential values for scale --> only for 32/64 bits. 1, 2, 4 or 8
;potential values for displacement --> a signed constant value

; MOV destination, source - copies data from source (register, memory reference, constant) to destination (register or memory reference)

;What is a stack?
;ans. stack is a piece of memory accessed in a first in first out manner using push and pop instructions. 
;     special purpose - when calling a function, the return addr is saved into the stack
;     it grows downwards, so we set it to the start of the prgm
