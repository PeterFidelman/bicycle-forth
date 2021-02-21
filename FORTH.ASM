; Bicycle Forth
;
; This is a literate-programmed Forth in the spirit of Jonesforth, with the
; following goals:
; - Run on 80186+
; - Minimum effort to working kernel
; - Brutal simplicity, at the cost of size & speed
; - Easily remove unnecessary parts
;
; And the following design choices:
; - Subroutine-threaded (STC)
; - Monolithic outer interpreter
; - Single-segment COM file (max 64k)
;
; Things Bicycle Forth will not be good at:
; - Not fastest possible applications
; - Not smallest possible applications
; - Not F83 or ANSI compliant (but surely influenced!)
;
; The first thing we need to do is decide on a memory map and set up Forth's
; virtual registers.
;
; Here is the memory map.  Sections marked * are only needed if you will be
; running an interactive Forth which includes the outer interpreter.
;
; 0000-00FF: DOS program segment prefix (PSP)
; 0100-....: Entry point / Forth setup code (You are here)
;*....-....: Forth outer interpreter*
; ....-....: Forth dictionary (grows towards higher addresses)
;    ...
;*FB80-FB81: Reserved for INT 21h function 0Ah*
;*FB82-FBFF: Forth line input buffer (126 chars)*
; FC00-....: Forth data stack (grows towards higher addresses)
; ....-FFFF: Forth return stack (grows towards lower addresses)
;            Note: Because of STC, the return stack is the x86 hardware stack.
; 1k of space for both stacks will be more than enough.  You can decrease this
; based on the needs of the hosted application.
;
; And here are the register assignments.  I'll put a "f" in front of Forth's
; virtual register names, so we don't confuse them with the x86 registers.
;
; fW:   General purpose register       --> BX (but not really needed for STC)
; fIP:  Interpreter pointer            --> IP (inevitably, because of STC)
; fPSP: Parameter (data) stack pointer --> BP
; fRSP: Return stack pointer           --> SP (inevitably, because of STC)
;
; We'll use a "full", not "empty", stack, meaning that fPSP points at
; top-of-stack.  This matches how x86 maintains fRSP, and has practical
; benefits too (no pointer math to peek at TOS).  In a "full" stack, 0FC00h
; would be the address of the first item on the stack -- so when the stack is
; empty, fPSP will be "one below" that, at 0FBFEh.
;
; Now let's start filling in our memory map.

.186
ASSUME cs:Code,ds:Code,es:Code,ss:Code
Code SEGMENT WORD PUBLIC USE16 'CODE'
ORG 0100h
EntryPoint:
; Initialize the Forth runtime and enter the "outer interpreter".
    jmp bCOLD

; You don't need an "inner interpreter" to run STC threaded code, because it
; is native code.  Just CALL the first word and off you go.  Here is an
; example.
;
;   mov bp, 0FBFEh  ; Set up fPSP for an empty data stack.  See the memory map.
;   call DEMO
;   ret
;
; This runtime can execute any STC threaded code that we give it.  But it
; doesn't have an outer interpreter that can compile an input text stream
; into threaded code.  To make the outer interpreter, we need:
; - An input source filling an input buffer.  We'll define a word named
;   LINE as the console input source.
; - WORD, to fetch a whitespace-delimited token (word) from the input buffer.
; - NUMBER, to translate a word to a number.
; - FIND, to translate a word to a dictionary entry.
; - ABORT, to reset the interpreter's state on error
; - COLD, the interpreter's entry point
; - [, to enter interpreting mode
; - ], to enter compiling mode
;
; Because we're about to define our first Forth word, we also need to pick a
; dictionary format, so the interpreter can find these words later (this is
; relevant if we re-use any of them in user programs).
;
; Link pointer --> 2 bytes
; Name         --> 4 bytes (Forth Inc. standard, e.g. 1+xx 2ORx 3DUP 4LOO ...)
; Code/Data    --> ...
;
; The name field is 4 bytes because it follows the Forth Inc. standard of
; storing the length plus up to three bytes of the name.  For longer names,
; only the first three bytes are significant.  This is not as awful as it
; sounds, because the length helps resolve conflicts.
;
; For example OVER and OVERT can co-exist as 4OVE and 5OVE, respectively.
; But OVER and OVEN are both 4OVE so they would collide.
;
; Note the length byte of the name field also has flags in its high bits.
; The flags aren't important yet.  They will be explained later.  For now just
; know they exist.  Here is the flag format:
;
;     i x h nnnnn
;
;     nnnnn: = Word length, 0..31
;     h: if 1, word is hidden (smudge)
;     x: reserved for future use, always 0
;     i: if 1, word is immediate

; OK, now let's write the pieces of the outer interpreter.

printdx MACRO
    ; $-terminated string at DS:DX
    mov ah, 09h
    int 21h
ENDM

; Reads keys into the console input buffer, until CR.
; ( -- )
; Out: a = address of buffer
LINE:
    ; Use DOS function 0Ah to read a line
    mov bx, 0FB80h
    mov word ptr [bx], 126
    mov dx, bx
    mov ah, 0Ah
    int 21h
    ; Reset the (globally visible) input cursor to point at the first
    ; character read.
    mov word ptr [vINPUT_CURSOR], 0FB82h
    ; Emit CR+LF to move past line just typed (for some reason DOS doesn't)
    lea dx, word ptr [crlf_]
    printdx
    ret
errmsg_: db '?'
crlf_: db 13, 10, '$'

; Selects which input source (and buffer) to use.
; We'll start off by reading from "Free", i.e. the end of the COM file,
; under the assumption that a startup script has been stashed there.
; Because "Free" is also the default starting location for compilation,
; input stream consumption will race compilation, and if the latter
; catches up you're in for !!FUN!! (and an ? error message if you're lucky).

vINPUT_CURSOR: dw Free - 1 ; Address of first unread character in input buffer
vINPUT_SOURCE_FN: dw adv   ; Address of function to refill the buffer

adv:
    inc word ptr [vINPUT_CURSOR]
    ret

; Retrieves a letter from the input buffer
; If the letter is non-0Dh then moves to the next letter
; ( -- n )
hLETTER:
    dw 0  ; This is the first word in the dictionary.
    db 6, 'let'
bLETTER:
    mov si, word ptr [vINPUT_CURSOR]
    xor ax, ax
    mov al, [si]
    add bp, 2
    mov [bp], ax
    cmp al, 0Dh
    je @@eol
    inc word ptr [vINPUT_CURSOR]
@@eol: ret

; Retrieves a whitespace-delimited word from the input buffer.
; ( -- a n | x 0 )
; Out: n = number of bytes at a, a = word start
; Out: 0 = end of buffer reached (0Dh)
hWORD:
    dw hLETTER
    db 4, 'wor'
bWORD:
    mov si, word ptr [vINPUT_CURSOR]
    add bp, 4
@@seeking_word:
    mov al, [si]
    cmp al, 0Dh
    je @@terminator
    cmp al, 20h
    ja @@in_word
    inc si
    jmp @@seeking_word
@@in_word:
    mov di, si
@@seeking_end:
    inc di
    mov al, [di]
    cmp al, 20h
    ja @@seeking_end
; found: di points at the whitespace at end of word
    mov word ptr [vINPUT_CURSOR], di
    mov [bp - 2], si
    sub di, si
    mov [bp], di
    ret
@@terminator:
    mov word ptr [bp], 0
    ret

; Converts a word to a number.
; ( a len -- n f )
; In: len = word length, a = word address
; Out: n = the number, f = conversion succeeded?
hNUMBER:
    dw hWORD
    db 6, 'num'
bNUMBER:
    mov cx, [bp]
    mov si, [bp - 2]
    xor ax, ax  ; accumulated sum
    xor bx, bx  ; digit
    xor di, di  ; negative?
; assume failure
    mov word ptr [bp], 0
; negative number?
    cmp byte ptr [si], '-'
    jne @@length_check
    inc si
    inc di
    dec cx
@@length_check:
    cmp cx, 0
    jle @@bail
@@parse_digit:
    mov bl, [si]
    sub bl, '0'
    cmp bl, 9
    ja @@bail
    mul word ptr [@@base]
    add ax, bx
    inc si
    loop @@parse_digit
; if the number started with '-', negate it here
    and di, di
    jz @@ok
    neg ax
@@ok:
    mov word ptr [bp - 2], ax
    mov word ptr [bp], -1
@@bail:
    ret
@@base:
    dw 10

; Finds a word in the dictionary.
; ( a len -- a len immed? xt )
; In: len = word length, a = word address
; Out: xt = execution token of word or 0 if not found
;      immed? = whether this word is immediate
hFIND:
    dw hNUMBER
    db 4, 'fin'
bFIND:
    lea bx, [vLATEST]
    add bp, 4
@@next:
    mov cx, [bp - 4]  ; needle length
    mov si, [bp - 6]  ; needle cursor
    mov bx, [bx]
; are we at the null pointer?
    and bx, bx
    jz @@fail
; does the length match?
    mov ch, [bx + 2]
    and ch, 07fh      ; mask out the flags, except the "hidden" flag
    cmp ch, cl
    jne @@next
; the length matches, does the word match?
    xor ch, ch
    cmp cl, 4
    jb @@check_name
    mov cl, 3
@@check_name:
    lea di, [bx + 3]
    repe cmpsb
    jne @@next
; matched!
    mov ah, [bx + 2]
    sar ax, 15
    mov word ptr [bp - 2], ax
; (advance past header)
    add bx, 6
    mov word ptr [bp], bx
    ret
@@fail:
    mov word ptr [bp], 0
    ret

; Called when the outer interpreter encounters an error.
; ( -- d: r: )
; d: = clears the data stack; r: = clears the return stack
hABORT:
    dw hFIND
    db 5, 'abo'
bABORT:
    mov word ptr [vINPUT_SOURCE_FN], offset Line
    lea dx, word ptr [errmsg_]
    printdx
    jmp WARM


; This tells the outer interpreter whether to interpret words or compile words.
vINTERPRETING: dw 0FFFFh  ; 0 = compiling, nonzero = interpreting

; Switches to interpreting mode
; ( -- )
hLBRACKET:
    dw hABORT
    db 81h, '[..'  ; immediate
bLBRACKET:
    mov word ptr [vINTERPRETING], 0FFFFh
    ret

; Switches to compiling mode
; ( -- )
hRBRACKET:
    dw hLBRACKET
    db 1, ']..'
bRBRACKET:
    mov word ptr [vINTERPRETING], 0
    ret

; We now have defined everything we'll need for the outer interpreter so let's
; write it!
;
; The interpreter works as follows:
;
;   >>>>>>>>>>>>>>>>>>>>>>  Consume word.
;
;                           Find:
;   If word in dictionary:  XT OF WORD
;   If word is a number:    CODE TO PUSH NUMBER ONTO STACK
;   Otherwise:              ERROR :-(
;
;                           Then:
;   If word is immediate    EXECUTE IT
;   If interpreting         EXECUTE IT
;   If compiling            APPEND IT TO DICTIONARY
;
;                           When out of words try to get more.

hCOLD:
    dw hRBRACKET
    db 4, 'col'
bCOLD:
    ; TODO: Reset the dictionary.
WARM:
    ; Set up fPSP for an empty data stack.  See the memory map.
    mov bp, 0FBFEh

    ; Clear the return stack
    mov sp, 0FFFEh

    ; Clear an annoying piece of x86 statefulness
    cld

    ; Switch to interpreting
    call bLBRACKET

QUERY:
    call [word ptr vINPUT_SOURCE_FN]
INTERPRET:
@@get_word:
    call bWORD                 ; stack: ( a len )
    cmp word ptr [bp], 0
    jne @@is_word
; no more words
    sub bp, 4
    jmp QUERY
@@is_word:
    call bFIND                 ; ( a len immed? xt )
    mov bx, [bp]
    mov ax, [bp - 2]
    sub bp, 4                  ; ( a len )
    and bx, bx
    jz @@try_number
    sub bp, 4                  ; (stack is empty)
; found in dictionary, ax = immediate?, bx = xt
    mov dx, word ptr [vINTERPRETING]
    or ax, dx
; nonzero if immediate or interpreting
    jz @@compile_call
    call bx                    ; execute the word
    jmp @@get_word
@@compile_call:
    mov di, word ptr [vHERE]
    mov si, di
    neg si
    mov al, 0E8h               ; call
    stosb
    lea ax, [bx + si - 3]      ; compute the rel16 call target
    stosw
    mov word ptr [vHERE], di
    jmp @@get_word
@@try_number:
    call bNUMBER               ; ( n is-number? )
    cmp word ptr [bp], 0
    jz @@err
    sub bp, 2                  ; ( n )
; is a valid number, on stack
    cmp word ptr [vINTERPRETING], 0
    je @@compile_push          ; compiling. generate code to push n onto stack
    jmp @@get_word             ; interpreting, leave n on stack and move on
@@compile_push:
    mov bx, [bp]
    sub bp, 2                  ; stack is empty, bx = n
    mov di, word ptr [vHERE]
    mov ax, 0C583h             ; add bp, 2 ;; mov [bp], value_to_push
    stosw                      ; ...
    mov ax, 0C702h             ; ...
    stosw                      ; ...
    mov ax, 0046h              ; ...
    stosw                      ; ...
    mov ax, bx                 ; the value to push
    stosw
    mov word ptr [vHERE], di
    jmp @@get_word
@@err:
    jmp bABORT

; The "LATEST" variable points at the dictionary header of the newest word.
; This uses the "lastheader" constant set in the file included below.
vLATEST: dw lastheader

; The "HERE" variable points at the first free byte in the memory image.
vHERE: dw Free

; --- End of interpreter ---

; --- Start of primitive (assembly) words ---
INCLUDE FORTHLIB.ASM

; --- End of assembly primitives ---

; --- End of binary ---
Free:

CODE ENDS
END EntryPoint