# Bicycle Forth

 This is a literate-programmed Forth in the spirit of Jonesforth, with the
 following goals:
 - Run on 80186+
 - Minimum effort to working kernel
 - Brutal simplicity, at the cost of size & speed
 - Easily remove unnecessary parts

 And the following design choices:
 - Subroutine-threaded (STC)
 - Monolithic outer interpreter
 - Single-segment COM file (max 64k)

 Things Bicycle Forth will not be good at:
 - Not fastest possible applications
 - Not smallest possible applications
 - Not F83 or ANSI compliant (but surely influenced!)
