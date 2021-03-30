tasm /t /dMINI forth.asm
tlink /t /n forth.obj
@del minicore.com
@ren forth.com minicore.com
@minimeld