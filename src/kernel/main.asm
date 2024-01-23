; Difference between directive and instruction: 
; A directive gives a clue to the assembler that will affect how prgm gets compiled (not translated to machine code)
; An instruction is translated to machine code that the CPU will execute

; ORG directive - tells assembler where we expect our code to be loaded. 
[org 0x7c00] 
[bits 16]

; defining var to use later on (while printing a str)
%define ENDL 0x0D, 0x0A 


start:
    jmp main


; params - ds:si points to string
puts: ; prints string to the screen
    ; save registers for modification
    push si 
    push ax
.loop:
    lodsb ; loads next char into al
    or al, al ; verify if next char is null. if yes, zero flag is true.
    jz .done ; conditional jump, jumps to destination if zero flag is set.

    mov ah, 0x0e ; BIOS interrupt
    mov bh, 0
    int 0x10
    jmp .loop

.done:
    pop ax
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

    ; print msg
    mov si, msg_str
    call puts

    hlt ; stops CPU from executing (can be resumed by an interrupt)
.halt:
    jmp .halt ; jumps to given location, unconditionally


msg_str: db "os is working :D", ENDL, 0
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
