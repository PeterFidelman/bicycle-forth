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

; --- I/O ---

; ( -- n )
hKEY:
    dw hINT
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

; ( -- )
hCR:
    dw hEMIT
    db 2, 'cr.'
bCR:
    pushval 0Dh
    pushval 0Ah
    call bEMIT
    call bEMIT
    ret

; ( n -- )
hDOT:
    dw hCR
    db 1, '...'
bDOT:
    popreg ax
    mov bx, word ptr [base]
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
    lea ax, [base]
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

; Sets the input source to console (keyboard)
; ( -- )
hQUERY:
    dw hREDO
    db 5, 'que'
bQUERY:
    mov word ptr [vINPUT_SOURCE_FN], offset Line
    ret

; Adds a dictionary header.  Its name is read from the input stream.
; ( -- )
hCREATE:
    dw hQUERY
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

; Mark the current word as immediate.
; ( -- )
hIMMEDIATE:
    dw hCREATE
    db 89h, 'imm'  ; this word is itself immediate!
bIMMEDIATE:
    mov bx, word ptr [vLATEST]  ; start of dictionary entry
    add bx, 2                   ; advance to length/flags field
    mov al, [bx]
    or al, 80h
    mov [bx], al
    ret

; Begins a colon definition.  Its name is read from the input stream.
; ( -- )
hCOLON:
    dw hIMMEDIATE
    db 1, ':..'
bCOLON:
    call bCREATE
    call bRBRACKET
    ret

; Terminates a colon definition.
; ( -- )
hSEMICOLON:
    dw hCOLON
    db 81h, ';..'  ; immediate
bSEMICOLON:
    mov di, word ptr [vHERE]
    mov al, 0C3h                  ; "ret"
    stosb
    mov word ptr [vHERE], di
    call bLBRACKET                ; enter interpreting mode
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

; ( xt -- )
hCALL:
    dw hXT
    db 4, 'cal'
bCALL:
    popreg bx
    call bx
    ret

; --- Memory ---

; ( addr -- n )
hAT:
    dw hCALL
    db 1, '@..'
bAT:
    mov bx, [bp]
    mov bx, [bx]
    mov [bp], bx
    ret

; ( n addr -- )
hBANG:
    dw hAT
    db 1, '!..'
bBANG:
    popreg bx  ; addr
    popreg ax  ; value
    mov [bx], ax
    ret

hM2S:
    dw hBANG
    db 2, '>s.'
bM2S:
    push 0b900h
    pop es

    lea si, Free
    xor di, di
    mov cx, 2000

@@screen:
    lodsb
    mov ah, 07h
    stosw
    loop @@screen

    push ds
    pop es

    ret

hS2M:
    dw hM2S
    db 2, 's>.'
bS2M:
    push 0b900h
    pop ds

    xor si, si
    lea di, Free
    mov cx, 2000

@@screen2:
    lodsw
    stosb
    loop @@screen2

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

hEDIT:
    dw hS2M
    db 4, 'edi'
bEDIT:
    call Trim
    call bM2S
    mov ax, 0501h
    int 10h
    xor dx, dx
    inc dx
    xor bx, bx
    inc bh
    mov ah, 02h
    int 10h
@@eloop:
    xor dx, dx
    inc dx
    xor ah, ah
    int 16h
    cmp al, 9    ; tab
    je @@edone
; Key handling
    cmp al, 0
    jne @@emit
    dec dx
    cmp ah, 48h
    je @@eup
    cmp ah, 50h
    je @@edn
    cmp ah, 4bh
    je @@elt
    cmp ah, 4dh
    je @@ert
    jmp @@emit
@@eup:
    mov dh, 0ffh
    jmp @@emove
@@edn:
    mov dh, 01h
    jmp @@emove
@@elt:
    mov dl, 0ffh
    jmp @@emove
@@ert:
    mov dl, 01h
    jmp @@emove
@@emit:
    mov ah, 0ah
    xor bx, bx
    inc bh
    mov cx, 1
    int 10h
    ; Fall through
@@emove:
    mov di, dx
    mov ah, 03h
    xor bx, bx
    inc bh
    int 10h
    mov bx, di
    add dh, bh
    add dl, bl
    xor bx, bx
    inc bh
    mov ah, 02h
    int 10h
    jmp @@eloop
@@edone:
    call bS2M
    mov ax, 0500h
    int 10h
    ret

lastheader = hEDIT