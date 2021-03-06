: beep  7 emit ;
: (  letter 41 = if!0 ret redo ; immediate
: hex  16 base ! ;
: dec  10 base ! ;
hex
: scan  0 >ax 16 int ax> ;
: clip  scan curmv >clip ff and if!0 ret redo ;
query
