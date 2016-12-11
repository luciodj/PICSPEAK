;----------------------------------------------------------------------------
;
; SOFTWARE DEL DECOMPRESSORE AUDIO "PICSPEAK"
;
;----------------------------------------------------------------------------
;
; CONTROLLER : PIC10F322 // 16CR56
; CLOCK      : 16 Mhz // 4MHz
;
;----------------------------------------------------------------------------
;
; CREATO DA  :  Lucio Di Jasio
; VERSIONE   : 1.00     05/04/94  prima stesura
; VERSIONE   : 1.01     07/04/94  campioni di E ed I + debug HW
; VERSIONE   : 1.02     20/04/94  scalaggio e debug HW
; VERSIONE   : 1.03     21/04/94  nuovi campioni
; VERSIONE   : 1.04     26/04/94  nuovi campioni estratti da sistemax.wav
; VERSIONE   : 1.05     27/04/94  versione per pic56 su due pagine
; VERSIONE   : 1.06     28/04/94  tabelle brani/parti piu' compatte
; VERSIONE   : 2.00     20/11/16  porting to PIC10F322
; VERSIONE   : 2.01     12/12/16  using NCO to scale vowels tables
;----------------------------------------------------------------------------
;
; PINOUT PIC10F322                | Struttura interna
;                                 |
;         -------_-------         | Address                | Registers
; A0-PWM | 1 VSS  VDD  14| A3-SW  | 03     STATUS          | TRIS A
;    VSs | 2 RB0  RB7  13| VDD    | 04     FSR             | OPTION
; A1-LED | 3 RB1  RB6  12| A2-POT | 05     PORT A          | W (working reg.)
;         ---------------
;
;----------------------------------------------------------------------------

 include "p10f322.inc"
; __config 0xFFA6
 __CONFIG _FOSC_INTOSC & _BOREN_ON & _WDTE_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _LVP_ON & _LPBOR_ON & _BORV_LO & _WRT_OFF

; ===== Assignments =========================================================

SW		equ     3       ; (input) trigger di inizio
LED		equ     1		;
PWM		equ     0		; (output) PWM

; Valori del registro flag di compressione e scalaggio
VOL1            equ     00      ; volume al 100%
VOL14           equ     10      ; volume al 25%
VOL12           equ     20      ; volume al 50%
VOL34           equ     30      ; volume al 75%
S14             equ     4
S12             equ     5
COMPRESSED      equ     6       ; due nibble per campione
LAST            equ     7       ; marca l'ultimo Flag

SILENCE         equ     0ff      ; silenzio
; usare sempre VOL1 con il silenzio

; Flag definiti
Flag_Sil        equ     0       ; il pezzo e' un silenzio

; numero sample per 1/60s di silenzio
SILNUMSAMPLE    equ     .133    ; 1/60s @ 8kHz

; ===== Data RAM assignment =================================================
Puntatore       equ     40      ; puntatore di lavoro
PuntPezzo       equ     41      ; pezzo in esecuzione per la parte attuale
PuntParte       equ     42      ; parte attuale
NumParti        equ     43      ; numero delle parti componenti il brano
NumRipetizioni  equ     44      ; numero di ripetizioni del pezzo
NumSample       equ     45      ; numero di sample componenti la parte
FlagSegm        equ     46      ; valore di scala o decompressione
Flags           equ     47      ; flag vari di uso generale
PageS           equ     48      ; pagina selezionata
Acc             equ     49      ; accumulatore per decompressione e scalaggio

;
; MACRO per la lettura da tabella nella pagina selezionata da Page
ESTRAI  MACRO
        btfsc   PageS,0         ; seleziona la pagina
		goto	$+3
		call	Estrai0
		goto	$+2
		call    Estrai1         ; estrai il dato
        ENDM
;
; ===========================================================================
; struttura delle tabelle dati in pagina 0
;
        ORG     0               ; reset vector
start
IO_Init
        clrf	ANSELA          ; all input digital
        bcf     TRISA,PWM       ; make A0-PWM an output
		bcf     TRISA,1

        movlw   B'01110000'     ; set 16MHz internal clock
        movwf	OSCCON

T2_Init
        movlw   B'000011100'	; T2on, T2pre = 1:1, T2post = 1:4
		movwf	T2CON
		movlw	D'124'          ; 32kHz (FOSC/4 /1 / (124+1) = PWM period
		movwf	PR2             ; 8kHz = TMR2IF period

PWM1_Init
        movlw   D'64'           ; valore centrale di riposo
        movwf   PWM1DCH
		movlw	B'11000000'     ; PWM1 enable, output enable
		movwf	PWM1CON         ;

#define EIGHTK  .524            ; NCO will produce an 8kHz pulse

NCO_Init
        movlw   LOW(EIGHTK)
        movwf   NCO1INCL
        movlw   HIGH(EIGHTK)
        movwf   NCO1INCH
        movlw   B'00000010'     ; NCO clk = 16MHz, output 1 clock
        movwf   NCO1CLK
        movlw   B'10000000'     ; NCO enabled, fixed duty cycle mode, no output
        movwf   NCO1CON
main
        clrf    PageS           ; seleziona le tabelle in  pagina 0
;
; loop principale di attesa di un comando
;mainL           btfsc   PORTA,SW	; attesa fronte di discesa
;                goto    mainL

;startL          btfss   PORTA,SW	; attesa fronte di salita (no debounce)
;                goto    startL

		clrw                    ; always select brano 0

; inizio decompressione brano
;
; dalla tabella dei brani seleziona il brano richiesto e punta al suo inizio
;
Brano
		bcf     PCLATH,0        ; tutti i brani sono in pag 0
		movwf   Puntatore       ;
        call    Estrai0         ; legge dalla tabella il puntatore
                                ; al brano in W (solo in pag. 0)
        movwf   Puntatore       ; e lo salva in Puntatore
        call    Estrai0         ; legge il numero di pezzi in W
        movwf   NumParti        ; init del contatore di parti
        incf    Puntatore       ; punta all'inizio della prima parte
Parte
; loop sulle parti di un brano
		bcf     PCLATH,0        ; tutti i brani sono in pag 0
		call    Estrai0         ; legge il selettore di pagina
        movwf   PageS           ; mette da parte il valore
        incf    Puntatore
        call    Estrai0         ; legge il Puntatore al pezzo
        movwf   PuntPezzo       ; di questa parte

        bsf     Flags,Flag_Sil  ; verifica che non si tratti di un
        incfsz  PuntPezzo,W     ; silenzio
        bcf     Flags,Flag_Sil  ; setta il flag in accordo
        incf    Puntatore

		bcf     PCLATH,0
        call    Estrai0         ; get NCOINC
        movwf   NCO1INCH
        incf    Puntatore
		bcf     PCLATH,0
        call    Estrai0
        movwf   NCO1INCL
        incf    Puntatore
Segment
		bcf     PCLATH,0
        call    Estrai0         ; legge i flag di Segment
        movwf   FlagSegm        ; salva
        andlw   0F              ; separa il numero di ripetizioni
        movwf   NumRipetizioni

        incf    Puntatore,W
        movwf   PuntParte       ; salva il puntatore al prox

PezzoL  movlw   SILNUMSAMPLE    ;
        btfsc   Flags,Flag_Sil  ; se il pezzo e' un silenzio
        goto    SetNumSample    ; NumSample e' noto a priori

        movf    PuntPezzo,W     ; dal pezzo attuale legge il NumSample
        movwf   Puntatore       ; dalla tabella pezzo

		btfsc	PageS,0
		bsf     PCLATH,0
        ESTRAI                  ; estraendolo dalla pagina giusta

SetNumSample
        movwf   NumSample       ;
        incf    Puntatore       ; punta al primo sample del pezzo

SampleL
        movlw   D'128'
		btfsc   Flags,Flag_Sil	; silence samples are predef.
		goto	SaveS
        ESTRAI                  ; estrae dalla pagina giusta un sample
SaveS
		movwf   Acc             ; lo salva nell'accumulatore

; ora bisogna scalare il campione o decomprimerlo a seconda dei flag di parte
        movlw   070             ; if not compressed, nor scaled
        andwf   FlagSegm,W
        SKPNZ
        goto    Output          ; output immediato se VOL100%

        btfss   FlagSegm,COMPRESSED
        goto    Scalaggio       ; else scalaggio

Espandi
        btfsc   NumSample,0     ; i dispari stanno in alto
        swapf   Acc             ; bisogna ruotarli giu'
        movlw   0F
        andwf   Acc,W           ; maschera solo il nibble basso
        btfsc   Acc,3           ; estensione del segno
        iorlw   0f0
        movwf   Acc
        goto    AddOffs

; ELSE scalaggio
; altrimenti prende il valore -128 e lo divide se necessario
Scalaggio
        movlw   D'128'          ;
        subwf   Acc             ; f=f-w
        CLRC
        btfsc   Acc,7           ; se negativo, estende il segno
        SETC
        rrf     Acc             ; Acc = valore 1/2
        CLRC
        btfsc   Acc,7           ; se negativo, estende il segno
        SETC
        rrf     Acc,W           ; W = valore 1/4
        btfss   FlagSegm,S12
        clrf    Acc             ; butta via il 1/2
        btfsc   FlagSegm,S14
        addwf   Acc             ; somma il valore 1/4
AddOffs
        movlw   D'128'          ; riaggiunge il 128
        addwf   Acc             ; risomma

Output
; loop di 10us si accorge di essere arrivato mediamente con 2us di ritardo
;		btfss   PIR1,TMR2IF     ; se sono passati 125us
		btfss   PIR1,NCO1IF     ; time to update?
		goto	Output
;		bcf     PIR1,TMR2IF
		bcf     PIR1,NCO1IF

		CLRC
		rrf     Acc,W
        movwf   PWM1DCH         ; lo mette subito in uscita

        btfss   FlagSegm,COMPRESSED ; se non sta espandendo
        goto    NextSample      ; avanza sempre

        btfss   NumSample,0     ; se espande: sui dispari non avanza
NextSample
        incf    Puntatore       ; punta al prox sample
        decfsz  NumSample       ; finiti i campioni ?
        goto    SampleL         ; no avanti un altro

        decfsz  NumRipetizioni  ; finite le ripetizioni ?
        goto    PezzoL          ; no va a ripetere il pezzo

; si la parte attuale e' finita, ora sono possibili due casi:
; a) FlagSegm ha il bit 7 (LAST) settato
;       in tal caso: parte finita bisogna valutare se ci sono altre parti
; b) ELSE
;       PuntParte punta gia' al prox segmento
;       in tal caso bisogna ripetere il brano con i nuovi flag
;
NextParte
        movf    PuntParte,W     ; recupera il puntatore nella tab parti
        movwf   Puntatore

        btfss   FlagSegm,LAST  ; if last segment
        goto    Segment         ;

; caso a) parte finita
        decfsz  NumParti        ; ci sono altre parti da eseguire
        goto    Parte           ; si va a preparare la prox
        goto    main            ; no brano terminato

;-------------------------------------------------------------------------------
Estrai0
        movf    Puntatore,W     ;
        addwf   PCL             ; somma l'offset in W al PC (TabIn)

; la tabella brani inizia dalla posizione TabIn
TabIn   ; offset per i salti calcolati in pag1

;Brano0          retlw   Ma-TabIn     ; offset alla tabella del brano
;Brano1          retlw   Si-TabIn
;Brano2          retlw   Ies-TabIn
Brano3          retlw   Hackaday-TabIn
;
; ogni brano e' composto da un campo "numero di parti"
; Brano0NP      retlw   X               ; numero delle parti a seguire
;
; e da una lista di parti corrispondenti dove ogni parte e' cosi' composta:
; Brano0PXTB    retlw   pagina della tabella
; Brano0PXPZ    retlw   puntatore_al_pezzoY
; Brano0PXFL    retlw   flag di riduzione 1, 3/4, 1/2, 1/4 o decompressione
;                       | numero di ripetizioni | flag fine lista (LAST)
;
; i pezzi sono cosi' composti
; PezzoYNS      retlw   numero_dei_samples
; PezzoYS0      retlw   sample_0
; PezzoYS1      retlw   sample_1
; PezzoYS2      retlw   sample_2
; PezzoYS..     etc...
;

#define VOWELA  .524
#define VOWELE  .645
#define VOWELI  .870

; tabella di composizione del brano "Hackaday"

Hackaday        retlw   8               ; numero delle parti componenti

; 'A
        retlw   1               ; pag
        retlw   PezzoA-TabIn2   ; puntatore al pezzo
        retlw   HIGH(VOWELA)
        retlw   LOW(VOWELA)
        retlw   VOL1  | 8 | 1<<LAST

; silenzio
        retlw   0               ; pag
        retlw   SILENCE         ; puntatore a 1/60s di silenzio
        retlw   HIGH(EIGHTK)
        retlw   LOW(EIGHTK)
        retlw   VOL1  | .1 | 1<<LAST ; 1/10s silenzio

; short S (k)
        retlw   1               ; pag
        retlw   PezzoS-TabIn2   ; puntatore al pezzo
        retlw   HIGH(EIGHTK)
        retlw   LOW(EIGHTK)
        retlw   1<<COMPRESSED | .3 | 1<<LAST

; 'A
        retlw   1               ; pag
        retlw   PezzoA-TabIn2   ; puntatore al pezzo
        retlw   HIGH(VOWELA)
        retlw   LOW(VOWELA)
        retlw   VOL1  | 8 | 1<<LAST

; D
        retlw   1               ; pag
        retlw   PezzoM-TabIn2   ; puntatore al pezzo
        retlw   HIGH(EIGHTK)
        retlw   LOW(EIGHTK)
        retlw   VOL34 | 4
        retlw   VOL1  | 4 | 1<<LAST

; E
        retlw   1               ; pag. 1
        retlw   PezzoA-TabIn2   ; puntatore al pezzo
        retlw   HIGH(VOWELE)
        retlw   LOW(VOWELE)
        retlw   VOL1 | .8
        retlw   VOL12 | .4| 1<<LAST

; I
        retlw   1               ; pag. 1
        retlw   PezzoA-TabIn2   ; puntatore al pezzo
        retlw   HIGH(VOWELI)
        retlw   LOW(VOWELI)
        retlw   VOL12 | 8
;        retlw   VOL1  | 4
;        retlw   VOL34 | 4
        retlw   VOL12 | 4
        retlw   VOL14 | 4 | 1<<LAST

; silenzio
        retlw   0               ; pag
        retlw   SILENCE         ; puntatore a 1/60s di silenzio
        retlw   HIGH(EIGHTK)
        retlw   LOW(EIGHTK)
        retlw   VOL1  | .15 | 1<<LAST ; 1/10s silenzio

;****************************************************************************
;
                ORG     100             ; inizio seconda pagina dati

Estrai1         movf    Puntatore,W     ;
                addwf   PCL             ; somma l'offset in W al PC
;
TabIn2          ; offset inizio tabella in pag 2

        nop
PezzoA  retlw   .80     ; numero campioni
		retlw	082
		retlw	084
		retlw	084
		retlw	085
		retlw	086
		retlw	085
		retlw	082
		retlw	07D
		retlw	06F
		retlw	05B
		retlw	062
		retlw	06F
		retlw	076
		retlw	092
		retlw	095
		retlw	08E
		retlw	093
		retlw	08D
		retlw	081
		retlw	080
		retlw	07C
		retlw	073
		retlw	072
		retlw	077
		retlw	07E
		retlw	088
		retlw	091
		retlw	08C
		retlw	085
		retlw	082
		retlw	07A
		retlw	076
		retlw	076
		retlw	074
		retlw	076
		retlw	07D
		retlw	081
		retlw	086
		retlw	08C
		retlw	08B
		retlw	085
		retlw	081
		retlw	07C
		retlw	079
		retlw	079
		retlw	07B
		retlw	07B
		retlw	080
		retlw	082
		retlw	083
		retlw	082
		retlw	081
		retlw	080
		retlw	080
		retlw	080
		retlw	07F
		retlw	080
		retlw	081
		retlw	081
		retlw	082
		retlw	082
		retlw	081
		retlw	080
		retlw	080
		retlw	080
		retlw	07F
		retlw	080
		retlw	080
		retlw	080
		retlw	081
		retlw	081
		retlw	082
		retlw	082
		retlw	081
		retlw	080
		retlw	07F
		retlw	07F
		retlw	080
		retlw	081
        retlw   080


PezzoM          retlw   .57     ; numero campioni
		retlw	07E
		retlw	07E
		retlw	07F
		retlw	076
		retlw	07D
		retlw	07D
		retlw	07D
		retlw	07D
		retlw	074
		retlw	074
		retlw	071
		retlw	07D
		retlw	080
		retlw	088
		retlw	07D
		retlw	076
		retlw	081
		retlw	094
		retlw	08A
		retlw	088
		retlw	096
		retlw	08C
		retlw	081
		retlw	08C
		retlw	08F
		retlw	08A
		retlw	08F
		retlw	088
		retlw	081
		retlw	07E
		retlw	080
		retlw	07F
		retlw	07F
		retlw	080
		retlw	076
		retlw	078
		retlw	07D
		retlw	078
		retlw	074
		retlw	076
		retlw	078
		retlw	076
		retlw	074
		retlw	076
		retlw	074
		retlw	078
		retlw	078
		retlw	078
		retlw	07E
		retlw	07E
		retlw	07E
		retlw	07D
		retlw	07F
		retlw	080
		retlw	07F
		retlw	080
		retlw	07E
;----------------------------------------------------------------------------
;
;PezzoS          retlw   .107*2     ; numero campioni (compressi): 2x
PezzoS          retlw   .98*2     ; numero campioni (compressi): 2x
		retlw	00E
		retlw	00F
		retlw	00E
		retlw	001
		retlw	0F0
		retlw	000
		retlw	00F
		retlw	02F
		retlw	0FF
		retlw	00E
		retlw	0E0
		retlw	000
		retlw	000
		retlw	00D
		retlw	000
		retlw	00E
		retlw	00E
		retlw	0F0
		retlw	00F
		retlw	000
		retlw	010
		retlw	020
		retlw	001
		retlw	0F0
		retlw	001
		retlw	0E0
		retlw	0D0
		retlw	0F1
		retlw	0EF
		retlw	0D2
		retlw	032
		retlw	000
		retlw	000
		retlw	000
		retlw	0BF
		retlw	003
		retlw	001
		retlw	020
		retlw	000
		retlw	0FE
		retlw	0DD
		retlw	0CC
		retlw	0B0
		retlw	0F1
		retlw	0F0
		retlw	010
		retlw	031
		retlw	010
		retlw	00E
		retlw	000
		retlw	00F
		retlw	00E
		retlw	0F0
		retlw	0E0
		retlw	0E0
		retlw	00F
		retlw	00F
		retlw	010
		retlw	003
		retlw	005
		retlw	002
		retlw	004
		retlw	01E
		retlw	0DC
		retlw	0FC
		retlw	0DF
		retlw	0E0
		retlw	0F0
		retlw	0E0
		retlw	001
		retlw	0E0
		retlw	0DE
		retlw	0F0
		retlw	0FF
		retlw	0F0
		retlw	000
		retlw	0DF
		retlw	0CF
		retlw	0ED
		retlw	0B1
		retlw	021
		retlw	004
		retlw	01D
		retlw	0E0
		retlw	0EC
		retlw	0D1
		retlw	0C0
		retlw	0FF
		retlw	0F0
		retlw	001
		retlw	090
		retlw	0FD
		retlw	0C1
		retlw	0B0
		retlw	012
		retlw	0E4
		retlw	010
		retlw	00D
		retlw	01F
		retlw	02B
;		retlw	009
;		retlw	03D
;		retlw	0FB
;		retlw	00A
;		retlw	026
;		retlw	0E0
;		retlw	05F
;		retlw	050
;		retlw	0F6

        END
