%define FILENAME_SIZE   255
%define FILE_SIZE       65536
%define STACK_SIZE      65536
;65536

section .data
noinputmsg:     db      'No input file given...', 10         ; input msg error
noinputlen      equ     $ - noinputmsg

copyerrormsg:   db      'Error : filename too long...', 10    ; copy error msg
copyerrormsglen equ     $ - copyerrormsg

errormsg:       db      'Error at runtime...', 10
errormsglen     equ     $ - errormsg

trymsg:         db      'Working...', 10
trymsglen       equ     $ - trymsg

section .bss
filename:       resb    FILENAME_SIZE
filebuffer:     resb    FILE_SIZE           ; buffer for the file content
fd_input:       resb    4
filesize:       resb    4

section .text
global _start               ; for the linker

print:              ; print : esi = char*, edx = size_t
    pusha               ; save registers
    mov ecx, esi        ; char*
    mov ebx, 1          ; std_out
    mov eax, 4          ; sys_write
    int 0x80             ; system call to kernel
    popa                ; reload registers
    ret                 ; return from procedure
    
    
print_number:           ; number in eax
    pusha               ; save registers
    push ebp
    mov ebp, esp        ; new frame
    xor ecx, ecx        ; our counter for later
    
.loopy:
    push ecx            ; save ecx
    xor edx, edx        ; set edx to 0
    mov ecx, 10
    div ecx             ; div by 10
    pop ecx             ; restore ecx
    add edx, '0'        ; the remainder converted to ASCII
    push edx            ; push the remainder onto the stack
    inc ecx             ; increment the counter
    test eax, eax       ; quotient in eax: if 0, goto end
    jz .end
    jmp .loopy          ; jump to loopy
    
.end:
    mov esi, esp
    lea edx, [ecx*4]
    call print
    leave
    popa
    ret
    
    

readfile:               ; readfile : esi = char*
.openfile:                  ; open the file
    pusha                   ; save registers state
    mov eax, 5              ; sys_open
    mov ebx, esi            ; char* filename
    mov ecx, 0              ; read-only
    mov edx, 777            ; file permissions
    int 0x80
    mov dword[fd_input], eax    ; save the file descriptor
    
.readfile:              ; read the entire file
    mov eax, 3              ; sys_read
    mov ebx, [fd_input]     ; ebx : file descriptor
    mov ecx, filebuffer     ; ecx : buffer
    mov edx, FILE_SIZE      ; edx : number of chars to read
    int 0x80
    
    mov dword[filesize], eax    ; store the length of the file, just in case
    
.closefile:
    mov eax, 6              ; sys_close
    mov ebx, [fd_input]     ; file descriptor
    int 0x80
.end:
    popa                    ; restore registers
    ret
    
    
error:              ; error msg in esi, size in edx
    call print
    ret
    

    
_start:             ; main procedure
    push ebp
    mov ebp, esp
    lea esi, [ebp+4]                ; points to argc
    mov ecx, [esi]                  ; ecx contains the number of args
    cmp ecx, 2                      ; case args < 2 or args > 2 : exit
    je .input
    
.noinput:
    mov esi, noinputmsg
    mov edx, noinputlen
    call error                      ; call an error the exit
    jmp .end
    
.input:                             ; if an input filename was given...
    mov esi, [esi+8]                ; get adress of second argument
    mov edi, filename               ; copy this arg to a reserved section
    xor ecx, ecx                    ; get the size of the string
    
.copy:
    lodsb
    cmp al, 0                       ; if al = 0, then it's the end
    je .copyend
    cmp ecx, FILENAME_SIZE          ; because we don't want to have a buffer overflow...
    je .copyerror
    stosb                           ; copy to [edi]
    inc ecx                         ; increment our counter
    jmp .copy
    
.copyerror:                         ; display a msg error if an error occur
    mov esi, copyerrormsg
    mov edx, copyerrormsglen
    call error
    jmp .end
    
.copyend:                           ; end of copy : read the file and copy it to buffer
    mov esi, filename
    call readfile                   ; read the file
    call interpreter                ; goto our interpreter
    
.end:
    leave
    mov	eax,1             ;system call number (sys_exit)
    int	0x80              ;call kernel
    
    
    
interpreter:                ; our real interpreter, since the code is loaded into memory...
    push ebp
    mov ebp, esp            ; create a new frame
    
    sub esp, STACK_SIZE     ; create the stack for our bf compiler
    mov edi, esp            ; edi is the bf stack pointer
    mov edx, esp            ; stack may change...
    mov esi, filebuffer     ; the code to interpreter
    
.L1:                ; the main loop
    lodsb                   ; load the instruction
    test al, al
    jz .end
    
    ;push eax
    ;mov eax, edi
    ;sub eax, edx
    ;call print_number
    ;pop eax
    
    ;push edx
    ;dec esi
    ;mov edx, 1
    ;call print
    ;inc esi
    ;pop edx
    
    cmp al, '>'
    je .incSP
    cmp al, '<'
    je .decSP
    cmp al, '+'
    je .incMem
    cmp al, '-'
    je .decMem
    cmp al, '.'
    je .output
    cmp al, '['
    je .makeLoop
    cmp al, ']'
    je .endLoop
    jmp .finally
    
.incSP:             ; increment the bf stack pointer
    inc edi
    
    ;push esi
    ;push edx
    ;mov esi, trymsg
    ;mov edx, trymsglen
    ;call print
    ;pop edx
    ;pop esi
    
    cmp edi, ebp            ; case the bf sp is more than the stack size
    je .error
    jmp .finally
.decSP:             ; decrement the bf stack pointer

    ;push esi
    ;push edx
    ;mov esi, trymsg
    ;mov edx, trymsglen
    ;call print
    ;pop edx
    ;pop esi

    dec edi
    cmp edi, edx            ; case the bf sp is less than 0
    jl .error
    jmp .finally
    
.incMem:
    inc byte[edi]
    jmp .finally
.decMem:
    dec byte[edi]
    jmp .finally
    
.output:
    push esi
    push edx
    mov esi, edi
    mov edx, 1
    call print
    pop edx
    pop esi
    jmp .finally
    
.makeLoop:
    cmp byte[edi], 0            ; if mem at edi is 0, then goto next ]
    je .nextLoop
    push esi                    ; else, we push the 'return' adress
    
    ;push esi
    ;push edx
    ;mov esi, trymsg
    ;mov edx, trymsglen
    ;call print
    ;pop edx
    ;pop esi
    
    jmp .L2end                  ; jump to the end
.nextLoop:
    mov ecx, 1                  ; put ecx at 1
.L2:
    cmp ecx, 0                  ; if ecx is 0, then we have found the next ]
    je .found
    lodsb                       ; else, we get the char at esi
    cmp al, 0                   ; if it is 0, then we reached the end, and that means that there is an error
    je .error           
    cmp al, '['                 ; if [, then add 1 to ecx
    je .addBracket
    cmp al, ']'                 ; if ], then sub 1 to ecx
    je .subBracket
    jmp .L2                     ; jump to our loop
.addBracket:
    inc ecx
    jmp .L2
.subBracket:
    dec ecx
    jmp .L2
.found:
.L2end:
    jmp .finally
    
.endLoop:
    cmp byte[edi], 0
    je .iszero
    pop esi
    push esi
    jmp .finally
.iszero:
    add esp, 4
    jmp .finally
    
.finally:
    jmp .L1
.error:
    mov esi, errormsg
    mov edx, errormsglen
    call print
.end:
    leave                   ; leave the function
    ret
    
