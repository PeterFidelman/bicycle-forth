: beep 7 emit ;
: ( letter 41 = if!0 ret redo ; immediate
: hex 16 base ! ;
: dec 10 base ! ;
hex
: scan 0 >ax 16 int ax> ;
: clip scan curmv >clip ff and if!0 ret redo ;
: find^z ( a -- a ) dup c@ 1a = if!0 ret 1 + redo ;
: def ctor> impl> ;
: creat ( name -- fh ) >dx 0 >cx 3c00 >ax 21 int ax> ;
: write ( fh a n -- fh cc ) >cx >dx dup >bx 4000 >ax 21 int flags> 1 and ;
: close ( fh -- cc )  >bx 3e00 >ax 21 int flags> 1 and ;
: nbytes ( -- n ) tape find^z tape - 1 + ;
: save ( name -- cc ) creat tape nbytes write swap close or if!0 beep ;
: ," drop r> drop ;
: ," letter dup 22 = if!0 ," c, redo ;
: ," letter drop ," ;
: $. ( a$ -- ) >dx 0900 >ax 21 int ;
: t% ( a -- delim? ) c@ 1a - >0 0 = ;
: t. ( a -- a' ) dup t% if!0 ret dup c@ emit 1 + redo ;
: t. ( a -- a ) dup t. drop ;
: tn ( a -- a' ) dup t% if!0 ret 1 + redo ;
: tn ( a -- a' ) tn dup c@ 1a = if!0 ret 2 + ( don't overrun ) ;
: t* ( a -- a ) dup t% if!0 ret t. tn d emit a emit redo ;
: t* ( -- ) tape t* drop ;
: over ( b a -- b a b ) swap dup >r swap r> ;
: cpy ( d s -- d+1 s+1 ) over over c@ swap c! 1 + swap 1 + swap ;
: ncpy ( d s n -- d' s' 0 ) >r cpy r> 1 - dup if!0 redo ret ;
: ncpy ( d s n -- d' s' ) ncpy drop ;
def daz 0d c, 0a c, 1a c,
: ta ( -- ) tape find^z fb00 4e ncpy drop daz 3 ncpy drop drop ;
: cr ( -- ) d emit a emit ;
: tz ( a n -- a' 0 ) >r t. r> 1 - dup 0 = if!0 ret >r tn r> cr redo ;
: tz ( a n -- a' ) tz drop ;
