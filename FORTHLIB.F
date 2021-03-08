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
: write ( fh a n -- fh cc ) >cx >dx dup >bx 4000 >ax 21 int flags 1 and ;
: close ( fh -- cc )  >bx 3e00 >ax 21 int flags 1 and ;
: nbytes ( -- n ) tape find^z tape - 1 + ;
: save ( name -- cc ) creat tape nbytes write swap close or if!0 beep ;
: ," drop r> drop ;
: ," letter dup 22 = if!0 ," c, redo ;
: ," letter drop ," ;
: $. ( a$ -- ) >dx 0900 >ax 21 int ; 