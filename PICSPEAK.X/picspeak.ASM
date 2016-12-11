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

SW		equ     3               ; (input) trigger di inizio
LED		equ     1		;
PWM		equ	0		; (output) PWM

; Valori del registro flag di compressione e scalaggio
VOL1            equ     00      ; volume al 100%
VOL14           equ     10      ; volume al 25%
VOL12           equ     20      ; volume al 50%
VOL34           equ     30      ; volume al 75%
S14             equ     4
S12             equ     5
COMPRESSED      equ     6       ; due nibble per campione
LAST            equ     7       ; marca l'ultimo Flag

SILENCE         equ     0ff     ; signature
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
		movlw	D'124'          ; 32kHz (FOSC/4 /1 / (124+1)
		movwf	PR2             ; 8kHz interrupt TMR2IF

PWM1_Init
        movlw   D'64'           ; valore centrale di riposo
        movwf   PWM1DCH
		movlw	B'11000000'     ; PWM1 enable, output enable
		movwf	PWM1CON         ;
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
                ESTRAI			; estrae dalla pagina giusta un sample
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
		btfss   PIR1,TMR2IF     ; se sono passati 125us
		goto	Output
		bcf     PIR1,TMR2IF

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
Brano3          retlw   Sistemax-TabIn
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

; tabella di composizione del brano "sistemax.wav"

Sistemax        retlw   7               ; numero delle parti componenti

; prima parte   la consonante S
        retlw   0               ; pag. 1
        retlw   (PezzoS-TabIn)   ; puntatore al pezzo
        retlw   1<<COMPRESSED | .3 | 1<<LAST

; 2 parte   la vocale I
        retlw   1               ; pag. 1
        retlw   PezzoI-TabIn2   ; puntatore al pezzo
        retlw   VOL14 | 2
        retlw   VOL1  | 4
        retlw   VOL34 | 2
        retlw   VOL12 | 2
        retlw   VOL14 | 2 | 1<<LAST

; 3 parte un bel silenzio
        retlw   0               ; pag
        retlw   SILENCE         ; puntatore a 1/60s di silenzio
        retlw   VOL1  | .6 | 1<<LAST ; 1/10s silenzio

; 4 parte   la consonante S di nuovo
        retlw   0               ; pag
        retlw   (PezzoS-TabIn)  ; puntatore al pezzo
        retlw   1<<COMPRESSED | .3 | 1<<LAST

; 5 parte   la vocale E
        retlw   1               ; pag
        retlw   PezzoE-TabIn2
        retlw   VOL1 | 4        ; colpo sulla E
        retlw   VOL34 | 1
        retlw   VOL12 | 1
        retlw   VOL14 | 1 | 1<<LAST

; 6 parte  la consonante M
        retlw   1               ; pag
        retlw   (PezzoM-TabIn2) ; puntatore al pezzo
        retlw   VOL34 | 4
        retlw   VOL1  | 4 | 1<<LAST

; 7 parte   la vocale A
        retlw   1               ; pag
        retlw   PezzoA-TabIn2   ; puntatore al pezzo
        retlw   VOL1  | 7
        retlw   VOL12 | 4 | 1<<LAST


;;-----------------------------------------------------------------------------
;; MA
;Ma              retlw   2               ; numero delle parti componenti
;; 1 parte  la consonante M
;                retlw   1               ; pag. 1
;                retlw   PezzoM-TabIn2   ; puntatore al pezzo
;                retlw   VOL34 | 4
;                retlw   VOL1  | 4 | LAST
;
;; 2 parte   la vocale A
;                retlw   0               ; pag. 0
;                retlw   PezzoA-TabIn
;                retlw   VOL1  | 8
;                retlw   VOL12 | 4 | LAST
;
;----------------------------------------------------------------------------
; IES
;
;Ies             retlw   3               ; numero delle parti componenti
;
;; 1 parte   la vocale I
;                retlw   1               ; pag. 1
;                retlw   PezzoI-TabIn2   ; puntatore al pezzo e
;                retlw   VOL14 | 2
;                retlw   VOL1  | 2       ;
;                retlw   VOL34 | 2
;                retlw   VOL12 | 2 | LAST
;
;; 2 parte   la vocale E
;                retlw   0               ; pag. 0
;                retlw   PezzoE-TabIn
;                retlw   VOL14 | 1       ; accento sul fondo della E
;                retlw   VOL12 | 1
;                retlw   VOL34 | 1
;                retlw   VOL12 | 1
;                retlw   VOL14 | 4 | LAST
;
;; 3 parte   la consonante S di nuovo
;                retlw   1               ; pag. 1
;                retlw   PezzoS-TabIn2   ; puntatore al pezzo e
;                retlw   COMPRESSED | 3 | LAST
;
;;-----------------------------------------------------------------------------
;Si              retlw   2               ; numero delle parti componenti
;
;; prima parte   la consonante S
;                retlw   1               ; pag. 1
;                retlw   PezzoS-TabIn2   ; puntatore al pezzo e
;                retlw   COMPRESSED | 3 | LAST
;
;; 2 parte   la vocale I
;                retlw   1               ; pag. 1
;                retlw   PezzoI-TabIn2   ; puntatore al pezzo e
;                retlw   VOL14 | 2
;                retlw   VOL1  | 4
;                retlw   VOL34 | 2
;                retlw   VOL12 | 2
;                retlw   VOL14 | 2 | LAST
;
;----------------------------------------------------------------------------
;
PezzoS  retlw   .107*2     ; numero campioni (compressi): 2x
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
		retlw	009
		retlw	03D
		retlw	0FB
		retlw	00A
		retlw	026
		retlw	0E0
		retlw	05F
		retlw	050
;		retlw	0F6

;Sinus
;		retlw	.16
;		retlw	.128	; 0
;		retlw	.148	; 1
;		retlw	.168	; 2
;		retlw	.178	; 3
;		retlw	.184	; 4
;		retlw	.178	; 5
;		retlw	.168	; 6
;		retlw	.148	; 7
;		retlw	.128	; 8
;		retlw	.108	; 9
;		retlw	.88	; 10
;		retlw	.78	; 11
;		retlw	.74	; 12
;		retlw	.78	; 13
;		retlw	.88	; 14
;		retlw	.108	; 15


;****************************************************************************
;
                ORG     100             ; inizio seconda pagina dati

Estrai1         movf    Puntatore,W     ;
                addwf   PCL             ; somma l'offset in W al PC
;
TabIn2          ; offset inizio tabella in pag 2

PezzoA          retlw   .79     ; numero campioni
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

PezzoE          retlw   .65     ; numero campioni
		retlw	067
		retlw	05A
		retlw	06A
		retlw	07F
		retlw	079
		retlw	061
		retlw	06A
		retlw	07E
		retlw	07D
		retlw	0A6
		retlw	0FE
		retlw	081
		retlw	080
		retlw	0DF
		retlw	0D5
		retlw	08A
		retlw	05D
		retlw	052
		retlw	04D
		retlw	080
		retlw	048
		retlw	01B
		retlw	05F
		retlw	0AB
		retlw	0AF
		retlw	094
		retlw	0A0
		retlw	0B3
		retlw	0CB
		retlw	0B9
		retlw	06C
		retlw	03E
		retlw	07D
		retlw	087
		retlw	060
		retlw	04E
		retlw	076
		retlw	099
		retlw	0AB
		retlw	0A1
		retlw	096
		retlw	0BF
		retlw	0B9
		retlw	08C
		retlw	070
		retlw	074
		retlw	06C
		retlw	06A
		retlw	065
		retlw	065
		retlw	083
		retlw	09A
		retlw	092
		retlw	08C
		retlw	09B
		retlw	099
		retlw	088
		retlw	07E
		retlw	070
		retlw	074
		retlw	079
		retlw	080
		retlw	080
		retlw	080
		retlw	07F

PezzoI  retlw   .48     ; numero campioni
        retlw   077
        retlw   075
        retlw   08D
        retlw   0AD
        retlw   079
        retlw   07D
        retlw   0BA
        retlw   0B0
        retlw   090
        retlw   097
        retlw   0B2
        retlw   0A4
        retlw   08A
        retlw   080
        retlw   07A
        retlw   080
        retlw   072
        retlw   050
        retlw   059
        retlw   074
        retlw   064
        retlw   05B
        retlw   073
        retlw   080
        retlw   080
        retlw   087
        retlw   091
        retlw   098
        retlw   09C
        retlw   0A2
        retlw   09E
        retlw   09D
        retlw   097
        retlw   08D
        retlw   086
        retlw   082
        retlw   074
        retlw   06C
        retlw   06F
        retlw   070
        retlw   066
        retlw   067
        retlw   074
        retlw   078
        retlw   076
        retlw   078
        retlw   080
        retlw   081

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

        END
