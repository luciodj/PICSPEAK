; LIST L=OFF
;**************************     PIC16C56 Header *************************
;
;
PIC56   equ     3FFH
;
F0      equ     0
RTCC    equ     1h
PC      equ     2h
Status  equ     3h              ; F3 Reg is STATUS Reg.
FSR     equ     4h
;
Port_A  equ     5h
Port_B  equ     6h              ; I/O Port Assignments
;
;
;*************************************************************************
;
;                               ; STATUS REG. Bits
CARRY   equ     0h              ; Carry Bit is Bit.0 of F3
C       equ     0h
DCARRY  equ     1h
DC      equ     1h
Z_bit   equ     2h              ; Bit 2 of F3 is Zero Bit
Z       equ     2h
P_DOWN  equ     3h
PD      equ     3h
T_OUT   equ     4h
TO      equ     4h
PA0     equ     5h      ;16C5X Status bits
PA1     equ     6h      ;16C5X Status bits
PA2     equ     7h      ;16C5X Status bits
;
;
Same    equ     1h
;
LSB     equ     0h
MSB     equ     7h
;
TRUE    equ     1h
YES     equ     1h
FALSE   equ     0h
NO      equ     0h
;
;*************************************************************************
;LIST L=ON
