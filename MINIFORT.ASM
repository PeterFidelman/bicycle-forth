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

; (  -- a )
hBASE:
    dw hFROMRETURN
    db 4, 'bas'
bBASE:
    lea ax, [vBASE]
    pushreg ax
    ret

; --- Memory ---

; ( n addr -- )
hBANG:
    dw hBASE
    db 1, '!..'
bBANG:
    int 3
    popreg bx  ; addr
    popreg ax  ; value
    mov es:[bx], ax
    ret


; --- Control flow ---

; ( f -- )
hIFNZ:
    dw hBANG
    db 2, 'if.'
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

; ( n -- )
hCCOMMA:
    dw hCOMMA
    db 2, 'c,.'
bCCOMMA:
    popreg ax
    mov bx, word ptr [vHERE]
    mov [bx], al
    add word ptr [vHERE], 1
    ret

; Specify the phase II action of a defining-word
hCTOR:
    dw hCCOMMA
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

lastheader = hIMPL