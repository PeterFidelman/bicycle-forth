; --- Macros ---
oldlink = hCOLD

pushreg MACRO a
    add bp, 2
    mov [bp], a
ENDM

pushval MACRO n
    add bp, 2
    mov word ptr [bp], n
ENDM

popreg MACRO a
    mov a, [bp]
    sub bp, 2
ENDM

; --- Stack manipulation ---

; ( a -- a a )
hDUP:
    dw oldlink
    db 3, 'dup'
bDUP:
    mov ax, [bp]
    add bp, 2
    mov [bp], ax
    ret

; ( a b -- b a )
hSWAP:
    dw hDUP
    db 4, 'swa'
bSWAP_:
    mov ax, [bp]
    mov bx, [bp - 2]
    mov [bp], bx
    mov [bp - 2], ax
    ret

; ( n -- )
hDROP:
    dw hSWAP
    db 4, 'dro'
bDROP:
    sub bp, 2
    ret

; ( n -- r:n )
hTORETURN:
    dw hDROP
    db 2, '>r.'
bTORETURN:
    ; This is a slow implementation -- could be done inline instead!
    popreg ax
    pop bx
    push ax
    push bx
    ret

; ( r:n -- n )
hFROMRETURN:
    dw hTORETURN
    db 2, 'r>.'
bFROMRETURN:
    ; This is a slow implementation -- could be done inline instead!
    pop bx
    pop ax
    pushreg ax
    push bx
    ret

; --- HW Interaction ---

; ( n -- reg:ax )
hTOAX:
    dw hFROMRETURN
    db 3, '>ax'
bTOAX:
    popreg ax
    ret

; ( reg:ax -- n )
hFROMAX:
    dw hTOAX
    db 3, 'ax>'
bFROMAX:
    pushreg ax
    ret

; ( n -- reg:bx )
hTOBX:
    dw hFROMAX
    db 3, '>bx'
bTOBX:
    popreg bx
    ret

; ( reg:bx -- n )
hFROMBX:
    dw hTOBX
    db 3, 'bx>'
bFROMBX:
    pushreg bx
    ret

; ( n -- reg:cx )
hTOCX:
    dw hFROMBX
    db 3, '>cx'
bTOCX:
    popreg cx
    ret

; ( reg:cx -- n )
hFROMCX:
    dw hTOCX
    db 3, 'cx>'
bFROMCX:
    pushreg cx
    ret

; ( n -- reg:dx )
hTODX:
    dw hFROMCX
    db 3, '>dx'
bTODX:
    popreg dx
    ret

; ( reg:dx -- n )
hFROMDX:
    dw hTODX
    db 3, 'dx>'
bFROMDX:
    pushreg dx
    ret

; ( n -- )
hINT:
    dw hFROMDX
    db 3, 'int'
bINT:
    push ax
    mov ax, [bp]             ; get X, top item on stack... 
    mov byte ptr [intx], al  ; ...modify code to call interrupt X
    jmp flush                ; ..."useless" jump flushes instruction cache
flush:                       ;    (see Agner: optimizing_assembly.pdf)
    pop ax
    db 0cdh                  ; "int"
intx:  db 03h
    sub bp, 2                ; pop X from stack
    ret

; ( -- n )
hFLAGS:
    dw hINT
    db 5, 'fla'
bFLAGS:
    lahf
    mov al, ah
    pushreg ax
    ret

; --- I/O ---

; ( -- n )
hKEY:
    dw hFLAGS
    db 3, 'key'
bKEY:
    xor ah, ah
    int 16h
    xor ah, ah
    pushreg ax
    ret

; ( n -- )
hEMIT:
    dw hKEY
    db 4, 'emi'
bEMIT:
    popreg ax
    xor bx, bx
    mov ah, 0eh
    int 10h
    ret

; ( n -- )
hDOT:
    dw hEMIT
    db 1, '...'
bDOT:
    popreg ax
    mov bx, word ptr [vBASE]
    cmp bx, 10
    jne @@decrec
    cmp ax, 0
    jge @@decrec
    ; add leading '-'
    neg ax
    push ax
    mov ax, 0e2dh
    int 10h
    pop ax
@@decrec:
    call @@Entry
    ; add trailing space
    mov ax, 0e20h
    int 10h
    ret
@@Entry:
    xor dx, dx
    cmp ax, bx
    jb @@BaseCase
; Recursive case
    div bx
    push dx
    call @@Entry
    pop ax          ; remainder into al
@@BaseCase:         ; fall through...
    mov si, ax
    mov al, byte ptr [higits + si]
    mov ah, 0eh
    int 10h
    ret

; (  -- a )
hBASE:
    dw hDOT
    db 4, 'bas'
bBASE:
    lea ax, [vBASE]
    pushreg ax
    ret

; --- Arithmetic ---

; ( a b -- a+b )
hADD:
    dw hBASE
    db 1, '+..'
bADD:
    popreg ax
    add [bp], ax
    ret

; ( a b -- a-b )
hSUB:
    dw hADD
    db 1, '-..'
bSUB:
    popreg ax
    sub [bp], ax
    ret

; ( a b -- a&b )
hAND:
    dw hSUB
    db 3, 'and'
bAND:
    popreg ax
    and [bp], ax
    ret

; ( a b -- a|b )
hOR:
    dw hAND
    db 2, 'or.'
bOR:
    popreg ax
    or [bp], ax
    ret

; ( ahal -- alah )
hXCHG:
    dw hOR
    db 4, 'xch'
bXCHG:
    mov ax, [bp]
    xchg al, ah
    mov [bp], ax
    ret

; ( a b -- f )
hEQ:
    dw hXCHG
    db 1, '=..'
bEQ:
    xor bx, bx
    mov ax, [bp - 2]
    cmp ax, [bp]
    jne @@not_eq
    dec bx
@@not_eq:
    sub bp, 2
    mov [bp], bx
    ret

; ( a -- f )
hGT0:
    dw hEQ
    db 2, '>0.'
bGT0:
    xor bx, bx
    mov ax, [bp]
    cmp ax, 0
    jle @@not_gt
    dec bx
@@not_gt:
    mov [bp], bx
    ret

; --- Control flow ---

; ( f -- )
hIFNZ:
    dw hGT0
    db 4, 'if!'
bIFNZ:
    popreg ax
    and ax,ax
    jnz @@done
    pop ax    ; Skip three bytes forward (= 1 STC instruction)
    add ax,3  ; Cannot skip a compiled "push literal" directive because
    push ax   ; those are bigger than three bytes.
@@done: ret

; ( -- )
hRET:
    dw hIFNZ
    db 3, 'ret'
bRET:
    pop ax  ; consume our return address, sp now = caller's return address
    ret     ; return from caller

; ( -- )
hREDO:
    dw hRET
    db 84h, 'red'  ; immediate
bREDO:
    mov bx, word ptr [vLATEST]  ; dictionary header of word being defined...
    add bx, 6                   ; ...first statement of word being defined...
    mov di, word ptr [vHERE]
    mov si, di
    mov al, 0e9h                ; "jmp"
    stosb
    neg si
    lea ax, [bx + si - 3]
    stosw
    mov word ptr [vHERE], di
    ret

; --- Compiler/interpreter ---

; Adds a dictionary header.  Its name is read from the input stream.
; ( -- )
hCREATE:
    dw hREDO
    db 6, 'cre'
bCREATE:
    mov di, word ptr [vHERE]
; emit link pointer (address of newest word, which is at LATEST),
; and update LATEST to point at us.
    mov ax, word ptr [vLATEST]
    mov word ptr [vLATEST], di
    stosw
; emit length
    push di
    call bWORD    ; stack: ( a n )
    pop di
    mov si, bp
    movsb
; emit name
    mov si, [bp - 2]
    movsw
    movsb
; update HERE
    mov word ptr [vHERE], di
; clean up the data stack and return
    sub bp, 4
    ret

; Toggle bitmask "ah" of latest word's header
FlipHeader:
    mov bx, word ptr [vLATEST]  ; start of dictionary entry
    add bx, 2                   ; advance to length/flags field
    mov al, [bx]
    xor al, ah
    mov [bx], al
    ret

; Mark the current word as immediate.
; ( -- )
hIMMEDIATE:
    dw hCREATE
    db 89h, 'imm'  ; this word is itself immediate!
bIMMEDIATE:
    mov ah, 80h
    jmp FlipHeader

; Begins a colon definition.  Its name is read from the input stream.
; ( -- )
hCOLON:
    dw hIMMEDIATE
    db 1, ':..'
bCOLON:
    call bCREATE
    call bRBRACKET
    mov ah, 20h    ; smudge
    jmp FlipHeader

; Terminates a colon definition.
; ( -- )
hSEMICOLON:
    dw hCOLON
    db 81h, ';..'                 ; immediate
bSEMICOLON:
    mov di, word ptr [vHERE]
    mov al, 0C3h                  ; "ret"
    stosb
    mov word ptr [vHERE], di
    call bLBRACKET                ; enter interpreting mode
    mov ah, 20h                   ; unsmudge
    jmp FlipHeader
    ret

; ( n -- )
hCOMMA:
    dw hSEMICOLON
    db 1, ',..'
bCOMMA:
    popreg ax
    mov bx, word ptr [vHERE]
    mov [bx], ax
    add word ptr [vHERE], 2
    ret

; Specify the phase II action of a defining-word
hCTOR:
    dw hCOMMA
    db 5, 'cto'
bCTOR:
    call bCREATE
    mov di, word ptr [vHERE]
    mov al, 0E8h
    stosb          ; "call"
    stosw          ; emit placeholder for call target, to be filled in later
    mov word ptr [vHERE], di
    ret

CtorFixup:
    ; Find call source
    mov si, word ptr [vLATEST]  ; start of dictionary entry for instance word
    add si, 6                   ; advance to CALL instruction
    ; Find call target
    pop bx                      ; our return address (in the class word)
    push bx
    inc bx                      ; advance past "ret" to 1st inst of IMPL> part
    ; Now do the fixup
    neg si
    lea ax, [bx + si - 3]
    neg si
    mov [si + 1], ax
    ret

; Specify the phase III action of a defining-word
hIMPL:
    dw hCTOR
    db 85h, 'imp'  ; immediate
bIMPL:
    mov di, word ptr [vHERE]
    mov si, di
    neg si
    mov al, 0E8h   ; "call"
    stosb
    lea bx, CtorFixup
    lea ax, [bx + si - 3]  ; compute the rel16 call target of the function
    stosw                  ; that fixes the call target in the instance word
    mov al, 0C3h   ; "ret"
    stosb
    mov ax, 4558h  ; move datafield address from return stack to data stack
    stosw
    mov ax, 8945h
    stosw
    mov ax, 0046h
    stosw
    mov word ptr [vHERE], di
    ret

; ( -- xt )
hXT:
    dw hIMPL
    db 82h, 'xt.'     ; immediate
bXT:
    call bWORD        ; a n
    call bFIND        ; a n imm? xt
    sub bp, 6
    mov ax, [bp + 6]
    mov [bp], ax      ; xt
    ret

; --- Memory ---

; ( addr -- n )
hAT:
    dw hXT
    db 1, '@..'
bAT:
    mov bx, [bp]
    mov bx, [bx]
    mov [bp], bx
    ret

; ( addr -- n )
hCAT:
    dw hAT
    db 2, 'c@.'
bCAT:
    mov bx, [bp]
    mov bl, [bx]
    xor bh, bh
    mov [bp], bx
    ret

; ( n addr -- )
hBANG:
    dw hCAT
    db 1, '!..'
bBANG:
    popreg bx  ; addr
    popreg ax  ; value
    mov [bx], ax
    ret

; ( n addr -- )
hCBANG:
    dw hBANG
    db 2, 'c!.'
bCBANG:
    popreg bx  ; addr
    popreg ax  ; value
    mov [bx], al
    ret

; --- Editor ---

; ( -- a )
hTAPE:
    dw hCBANG
    db 4, 'tap'
bTAPE:
    mov ax, offset [Free]
    pushreg ax
    ret

PushVideoBase:
    mov ah, 0fh
    int 10h      ; get active page
    xor bl, bl   ; page 0 -> bx=0000, page 1 -> bx=0100
    add bh, 0b8h ; page 0 -> bx=b800, page 1 -> bx=b900
    pop dx       ; dx := return address
    push bx
    jmp dx       ; return to caller, leaving base address on stack

hM2S:
    dw hTAPE
    db 2, '>s.'
bM2S:
    lea si, Free
    xor di, di
    mov cx, 2000
@@expand_area:
    call PushVideoBase
    pop es
@@expand:
    lodsb
    mov ah, 07h
    stosw
    loop @@expand
    push ds
    pop es
    ret

hS2M:
    dw hM2S
    db 2, 's>.'
bS2M:
    xor si, si
    lea di, Free
    mov cx, 2000
@@condense_area:
    call PushVideoBase
    pop ds
@@condense:
    lodsw
    stosb
    loop @@condense
    push es
    pop ds
    ret

; Find first ctrl-Z in startup script region and replace it (and the rest
; of the region) with spaces.  Useful for clearing out uninitialized memory.
Trim:
    lea di, Free
    mov cx, 2000
    mov al, 26    ; Ctrl-Z
    repne scasb
    mov al, 32
    rep stosb
    ret

; ( n -- n )
hCURMV:
    dw hS2M
    db 5, 'cur'
bCURMV:
    mov ax, [bp]
CursorMove:
    push ax
    mov ah, 0fh
    int 10h      ; get active page
    mov ah, 03h
    int 10h      ; get cursor position: dh=row, dl=col
    pop ax
    cmp al, 0    ; extended character?
    jne @@crt    ; ...no? then advance cursor
    cmp ah, 48h
    je @@cup
    cmp ah, 50h
    je @@cdn
    cmp ah, 4bh
    je @@clt
    cmp ah, 4dh
    je @@crt
    cmp ah, 49h
    je @@cpgup
    cmp ah, 51h
    je @@cpgdn
    cmp ah, 47h
    je @@chome
    cmp ah, 4fh
    je @@cend
    ret
@@cpgup:
    sub dh, 4
    jmp @@cmove
@@cpgdn:
    add dh, 4
    jmp @@cmove
@@chome:
    sub dl, 4
    jmp @@cmove
@@cend:
    add dl, 4
    jmp @@cmove
@@cup:
    dec dh
    jmp @@cmove
@@cdn:
    inc dh
    jmp @@cmove
@@clt:
    dec dl
    jmp @@cmove
@@crt:
    inc dl
    ; fall through...
@@cmove:
    mov ah, 0fh
    int 10h      ; get active page
    mov ah, 02h
    int 10h      ; set cursor position
@@cdone:
    ret

LineStartAddr:
    mov ah, 0fh
    int 10h         ; get active page
    mov ah, 03h
    int 10h         ; get cursor position: dh=row, dl=col
    mov al, dh
    mul byte ptr [scrwidth] ; ax := al*160
    ret
scrwidth: db 160

; Copy current line to clipboard
; ( -- )
hTOCLIP:
    dw hCURMV
    db 5, '>cl'
bTOCLIP:
    call LineStartAddr
    mov si, ax      ; start address of line
    mov di, 0fb00h  ; clipboard
    mov cx, 80      ; entire line
    jmp @@condense_area

; Paste clipboard to screen
FromClip:
    call LineStartAddr
    mov si, 0fb00h  ; clipboard
    mov di, ax      ; start address of line
    mov cx, 80      ; entire line
    jmp @@expand_area

; ( -- )
hEDIT:
    dw hTOCLIP
    db 4, 'edi'
bEDIT:
    mov ax, 0501h
    int 10h      ; switch to page 1
    call Trim
    call bM2S
    xor dx, dx
    mov bh, 1
    mov ah, 02h
    int 10h      ; move cursor to 0,0 (top left)
@@eloop:
    xor ah, ah
    int 16h      ; get keystroke
    cmp al, 9    ; tab
    je @@edone
    cmp al, 03h  ; ctrl-c
    je @@ecopy
    cmp al, 16h  ; ctrl-v
    je @@epaste
    cmp al, 0    ; extended char
    je @@emove
    push ax
    mov ah, 0ah
    xor bx, bx
    inc bh       ; page 1
    mov cx, 1
    int 10h      ; write character
    pop ax
@@emove:
    call CursorMove
    jmp @@eloop
@@ecopy:
    call bTOCLIP
    jmp @@eloop
@@epaste:
    call FromClip
    jmp @@eloop
@@edone:
    call bS2M
    mov ax, 0500h
    int 10h      ; switch to page 0
    ret

lastheader = hEDIT