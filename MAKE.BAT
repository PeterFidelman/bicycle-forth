tasm /t forth.asm
tlink /t /n forth.obj
@del core.com
@ren forth.com core.com
@meld