16 base !
: ,x 468b , 4d00 , 4d c, c, 0046 , ;
: | [ 09 ,x ] ;
: & [ 21 ,x ] ;
: + [ 01 ,x ] ;
: - [ 29 ,x ] ;
: emit [ 468b , 4d00 , 314d , b4db , cd0e , 9010 , ] ;
: ax 4600 ; : cx 4e00 ; : dx 5600 ; : bx 5e00 ;
: ,r 8b | , 00 c, 4d4d , ;
: r, 4545 , 89 | , 00 c, ;
: xchg [ ax ,r c486 , ax r, ] ;
: ,int cd00 | xchg , ;
: emit 0e00 | [ ax ,r ] 0 [ bx ,r 10 ,int ] ;
: key 0 [ ax ,r 16 ,int ax r, ] ff & ;
: far [ cc c, 76ff , 4d00 , 074d , ] ;
: near [ 070e , ] ;
