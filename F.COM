�t����~ �Ӵ
�!�"����	�!�?
$�&�"�  que�$�+let�6"3�����F <t�"�8wor�6"���<t!<t< wF���G�< w��>"�v�+��~ ��F   �Unum�N �v�3�3��F   �<-uFICS�� ~(PQ������O�+�YX:�s�&��F���F ��[#�t�؉F��0123456789abcdef
 �fin�#���N��v��#�t*�o��:�u�2��r���uڊg���F����^ ��F   ��abo�$��	�!�A���?�[..�U���W]..�U  �dcol���#���%���"�&�$��
 ����������$���~  u��<u��{����B��^ �F���#�t$���U�t���̋>%���ް認@���>%����~  t+���>U t뢋^ ���>%��ū�ǫ�F ��ë�>%��"���qdup�F ���F �'swa�F �^��^ �F��7dro���J>r.�F ��[PS�Tr>.[X���F S�d>ax�F ���tax>���F Á>bx�^ ��Îbx>���^ Û>cx�N ��ècx>���N õ>dx�V ����dx>���V ��intP�F ����X�����fla��ă��F ��key2��2���F �emi�F ��3۴��...�F ������
u=  }	��P�-�X� � ��3�;�r��R���X��������)bas�����F �m+..�F ��F �}-..�F ��)F Íand�F ��!F Ýor.�F ��	F íxch�F �ĉF ý=..3ۋF�;F uK���^ ��>0.3ۋF =  ~K�^ ��if.�F ��#�uX P��retX��red�#���>%�����ލ@���>%�cre�>%�#�>#�W��_����v����>%��Ë#���2Ĉ�8�imm����m:..������ ��w�;..�>%�ê�>%���� ���,..�F ���%��%ßc,.�F ���%��%÷cto�g��>%�誫�>%Ë6#��[SC�ލ@��މD���imp�>%���ް誻��@���ê�XE��E���F ��>%���xt.�-�������F�F �%@..�^ ��^ �;c@.�^ �2��^ �J!..�^ ���F ����[c!.�^ ���F ����ptap�����F ô�2ۀǸZS��>s.��3�����������âs>.3������������ÿ����� �ýcur�F P����X< uP��Ht<��Pt<��Kt<��Mt<��It��Qt��Gt��OtÀ��$��������������������������´���ô������&fà�>cl����� ��P �P����� ����P �'�gedi���?���3ҷ��2��<	t(<t<t< tP�
3��ǹ �X�(��������������� ��: beep 7 emit ;
: ( letter 41 = if ret redo ; immediate
: hex 16 base ! ;
: dec 10 base ! ;
hex
: scan 0 >ax 16 int ax> ;
: clip scan curmv >clip ff and if ret redo ;
: find^z ( a -- a ) dup c@ 1a = if ret 1 + redo ;
: def ctor> impl> ;
: creat ( name -- fh ) >dx 0 >cx 3c00 >ax 21 int ax> ;
: write ( fh a n -- fh cc ) >cx >dx dup >bx 4000 >ax 21 int flags> 1 and ;
: close ( fh -- cc )  >bx 3e00 >ax 21 int flags> 1 and ;
: nbytes ( -- n ) tape find^z tape - 1 + ;
: save ( name -- cc ) creat tape nbytes write swap close or if beep ;
: ," drop r> drop ;
: ," letter dup 22 = if ," c, redo ;
: ," letter drop ," ;
: $. ( a$ -- ) >dx 0900 >ax 21 int ;
: t% ( a -- delim? ) c@ 1a - >0 0 = ;
: t. ( a -- a' ) dup t% if ret dup c@ emit 1 + redo ;
: t. ( a -- a ) dup t. drop ;
: tn ( a -- a' ) dup t% if ret 1 + redo ;
: tn ( a -- a' ) tn dup c@ 1a = if ret 2 + ( don't overrun ) ;
: t* ( a -- a ) dup t% if ret t. tn d emit a emit redo ;
: t* ( -- ) tape t* drop ;
: over ( b a -- b a b ) swap dup >r swap r> ;
: cpy ( d s -- d+1 s+1 ) over over c@ swap c! 1 + swap 1 + swap ;
: ncpy ( d s n -- d' s' 0 ) >r cpy r> 1 - dup if redo ret ;
: ncpy ( d s n -- d' s' ) ncpy drop ;
def daz 0d c, 0a c, 1a c,
: ta ( -- ) tape find^z fb00 4e ncpy drop daz 3 ncpy drop drop ;
: cr ( -- ) d emit a emit ;
: tz ( a n -- a' 0 ) >r t. r> 1 - dup 0 = if ret >r tn r> cr redo ;
: tz ( a n -- a' ) tz drop ;
