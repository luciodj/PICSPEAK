LIST C=132,R=HEX
;----------------------------------------------------------------------------
;
; SOFTWARE DEL DECOMPRESSORE AUDIO "PICSPEAK"
;
;----------------------------------------------------------------------------
;
; CONTROLLER : PIC 16CR56
; CLOCK      : 4 Mhz
;
; NOTA       : In programmazione disattivare il WATCHDOG
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
;
;----------------------------------------------------------------------------
;
; PINOUT PIC16CR56                | Struttura interna
;                                 |
;         -------_-------         | Address                | Registers
;  Start | 1 RA2  RA1  18| Sel1   |                        |
;  Enable| 2 RA3  RA0  17| Sel0   | 00     INDIRECT ADDR.  | STACK1
;    VDD | 3 RTCC OSC1 16| OSCIn  | 01     RTCC            | STACK2
;  Reset | 4 MCLR OSC2 15| OSCOut | 02     PC (9bit)       | TRIS A
;    VSS | 5 VSS  VDD  14| VDD    | 03     STATUS          | TRIS B
;   DAC0 | 6 RB0  RB7  13| DAC7   | 04     FSR             | OPTION
;   DAC1 | 7 RB1  RB6  12| DAC6   | 05     PORT A          | W (working reg.)
;   DAC2 | 8 RB2  RB5  11| DAC5   | 06     PORT B          |
;   DAC3 | 9 RB3  RB4  10| DAC4   | 07-1F  GENERAL PURPOSE |
;         ---------------
;
;----------------------------------------------------------------------------

                include "pic56reg.equ"

;----------------------------------------------------------------------------
CLK             equ     2       ; 4 MHz

; ===== Assignments =========================================================

; Pin number della porta A

PinA_Sel0       equ     0               ; (input) selezione del brano
PinA_Sel1       equ     1               ; (input)     '      '    '
PinA_Start      equ     2               ; (input) trigger di inizio
PinA_Enable     equ     3               ; (input) abilitazione

NORMAMASK       equ     0F              ; normalmente tutti in input

; Pin number della porta B
; sono tutti usati per pilotare il DAC

NORMBMASK       equ     0               ; tutti in output quindi

; velocita' di esecuzione
RATE            equ     D'60'*CLK       ; @8kHz -> 120us +  overhead
;RATE            equ     D'45' * CLK    ; @11kHz -> 90us +  overhead

; Valori del registro flag di compressione e scalaggio
VOL1            equ     00              ; volume al 100%
VOL14           equ     10              ; volume al 25%
VOL12           equ     20              ; volume al 50%
VOL34           equ     30              ; volume al 75%
COMPRESSED      equ     40              ; due nibble per campione
LAST            equ     80              ; marca l'ultimo Flag

SILENCE         equ     00              ; il pezzo zero e' silenzio
; usare sempre VOL1 con il silenzio

; Flag definiti

Flag_Sil        equ     0               ; il pezzo e' un silenzio


; numero sample per 1/60s di silenzio
SILNUMSAMPLE    equ     D'133'           ; @ 8kHz
;SILNUMSAMPLE    equ     D'183'          ; @ 11kHz

; ===== Data RAM assignment =================================================
Puntatore       equ     07      ; puntatore di lavoro
PuntPezzo       equ     08      ; pezzo in esecuzione per la parte attuale
PuntParte       equ     09      ; parte attuale
NumParti        equ     0A      ; numero delle parti componenti il brano
NumRipetizioni  equ     0B      ; numero di ripetizioni del pezzo
NumSample       equ     0C      ; numero di sample componenti la parte
FlagEsecu       equ     0D      ; valore di scala o decompressione
Flags           equ     0E      ; flag vari di uso generale
PageS           equ     0F      ; pagina selezionata
Acc             equ     1F      ; accumulatore per decompressione e scalaggio

;
; MACRO per la lettura da tabella nella pagina selezionata da Page
ESTRAI          MACRO
                bcf     Status,PA0      ; resetta il selettore a pagina 0
                btfsc   PageS,0         ; seleziona la pagina
                bsf     Status,PA0
                call    Estrai          ; estrai il dato
                bcf     Status,PA0      ; resetta il selettore a pagina 0
                ENDM
;
; ===========================================================================
; struttura delle tabelle dati in pagina 0
;
                ORG     0               ; inizio pagina 0

Estrai          movf    Puntatore,W     ;
                addwf   PC              ; somma l'offset in W al PC (TabIn)

; la tabella brani inizia dalla posizione TabIn
TabIn   ; offset per i salti calcolati in pag1

Brano0          retlw   Ma-TabIn     ; offset alla tabella del brano
Brano1          retlw   Si-TabIn
Brano2          retlw   Ies-TabIn
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
                retlw   1               ; pag. 1
                retlw   PezzoS-TabIn2   ; puntatore al pezzo e
                retlw   COMPRESSED | 3 | LAST

; 2 parte   la vocale I
                retlw   1               ; pag. 1
                retlw   PezzoI-TabIn2   ; puntatore al pezzo e
                retlw   VOL14 | 2
                retlw   VOL1  | 4       ;
                retlw   VOL34 | 2
                retlw   VOL12 | 2
                retlw   VOL14 | 2 | LAST

; 3 parte un bel silenzio
                retlw   0               ; pag. 0
                retlw   SILENCE         ; puntatore a 1/60s di silenzio
                retlw   VOL1  | 6 | LAST ; 1/10s silenzio

; 4 parte   la consonante S di nuovo
                retlw   1               ; pag. 1
                retlw   PezzoS-TabIn2   ; puntatore al pezzo
                retlw   COMPRESSED | 3 | LAST

; 5 parte   la vocale E
                retlw   0               ; pag. 0
                retlw   PezzoE-TabIn
                retlw   VOL1 | 4        ; colpo sulla E
                retlw   VOL34 | 1
                retlw   VOL12 | 1
                retlw   VOL14 | 1 | LAST


; 6 parte  la consonante M
                retlw   1               ; pag. 1
                retlw   PezzoM-TabIn2   ; puntatore al pezzo
                retlw   VOL34 | 4
                retlw   VOL1  | 4 | LAST

; 7 parte   la vocale A
                retlw   0               ; pag. 0
                retlw   PezzoA-TabIn    ; puntatore al pezzo
                retlw   VOL1  | 8
                retlw   VOL12 | 4 | LAST

;-----------------------------------------------------------------------------
; MA
Ma              retlw   2               ; numero delle parti componenti
; 1 parte  la consonante M
                retlw   1               ; pag. 1
                retlw   PezzoM-TabIn2   ; puntatore al pezzo
                retlw   VOL34 | 4
                retlw   VOL1  | 4 | LAST

; 2 parte   la vocale A
                retlw   0               ; pag. 0
                retlw   PezzoA-TabIn
                retlw   VOL1  | 8
                retlw   VOL12 | 4 | LAST

;----------------------------------------------------------------------------
; IES
;
Ies             retlw   3               ; numero delle parti componenti

; 1 parte   la vocale I
                retlw   1               ; pag. 1
                retlw   PezzoI-TabIn2   ; puntatore al pezzo e
                retlw   VOL14 | 2
                retlw   VOL1  | 2       ;
                retlw   VOL34 | 2
                retlw   VOL12 | 2 | LAST

; 2 parte   la vocale E
                retlw   0               ; pag. 0
                retlw   PezzoE-TabIn
                retlw   VOL14 | 1       ; accento sul fondo della E
                retlw   VOL12 | 1
                retlw   VOL34 | 1
                retlw   VOL12 | 1
                retlw   VOL14 | 4 | LAST

; 3 parte   la consonante S di nuovo
                retlw   1               ; pag. 1
                retlw   PezzoS-TabIn2   ; puntatore al pezzo e
                retlw   COMPRESSED | 3 | LAST

;-----------------------------------------------------------------------------
Si              retlw   2               ; numero delle parti componenti

; prima parte   la consonante S
                retlw   1               ; pag. 1
                retlw   PezzoS-TabIn2   ; puntatore al pezzo e
                retlw   COMPRESSED | 3 | LAST

; 2 parte   la vocale I
                retlw   1               ; pag. 1
                retlw   PezzoI-TabIn2   ; puntatore al pezzo e
                retlw   VOL14 | 2
                retlw   VOL1  | 4
                retlw   VOL34 | 2
                retlw   VOL12 | 2
                retlw   VOL14 | 2 | LAST

;----------------------------------------------------------------------------
;
PezzoE          retlw   041     ; numero campioni:  65
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

PezzoA          retlw   04D     ; 4f numero campioni:  79
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

;****************************************************************************
;
                ORG     200             ; inizio seconda pagina dati

Estrai2         movf    Puntatore,W     ;
                addwf   PC              ; somma l'offset in W al PC

TabIn2          ; offset inizio tabella in pag 2

Silenz          retlw   010     ; numero campioni:  16
                retlw   080
                retlw   080
                retlw   080
                retlw   080
                retlw   080
                retlw   080
                retlw   080
                retlw   080
                retlw   080
                retlw   080
                retlw   080
                retlw   080
                retlw   080
                retlw   080
                retlw   080
                retlw   080

PezzoI          retlw   032     ; numero campioni:  50
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
                retlw   080
                retlw   080
                retlw   081

PezzoM          retlw   045     ; numero campioni:  69
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
		retlw	080
		retlw	080
		retlw	080
		retlw	080
		retlw	080
		retlw	080
		retlw	080
		retlw	080
		retlw	080
		retlw	080
		retlw	080
		retlw	080
		retlw	07E

;
PezzoS          retlw   0D0     ; DAnumero campioni (compressi): 218
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
		retlw	0F6

;****************************************************************************
; INIZIO CODICE
; il codice inizia nella seconda pagina per lasciare posto alle tabelle dati
; per inserire le tabelle dati nella prima va usato un apposito linker
;****************************************************************************

                ORG     100             ; prima pagina codice

;----------------------------------------------------------------------------
; MAIN
;----------------------------------------------------------------------------

;
main            movlw   NORMAMASK       ; tutti in ingresso
                tris    Port_A
                movlw   NORMBMASK       ; tutti in uscita
                tris    Port_B
                movlw   B'001000'       ; il prescaler non viene usato
                option                  ; RTCC incrementato ogni 2us

                clrf    Port_A          ;
                movlw   D'128'          ; valore centrale di riposo
                movwf   Port_B
                clrf    PageS           ; seleziona le tabelle in  pagina 0
;
; loop principale di attesa di un comando
mainL           btfss   Port_A,PinA_Start ; attesa fronte di salita
                goto    mainL

startL          btfsc   Port_A,PinA_Start ; attesa fronte di discesa
                goto    startL

                movf    Port_A,W
                andlw   3               ; solo i due bit bassi

; inizio decompressione brano
;
; dalla tabella dei brani seleziona il brano richiesto e punta al suo inizio
;
Brano           movwf   Puntatore       ;
                call    Estrai          ; legge dalla tabella il puntatore
                                        ; al brano in W (solo in pag. 0)
                movwf   Puntatore       ; e lo salva in Puntatore
                call    Estrai          ; legge il numero di pezzi in W
                movwf   NumParti        ; init del contatore di parti
                incf    Puntatore       ; punta all'inizio della prima parte

; loop sulle parti di un brano
Parte           call    Estrai          ; legge il selettore di pagina
                movwf   PageS           ; mette da parte il valore

                incf    Puntatore
                call    Estrai          ; legge il Puntatore al pezzo
                movwf   PuntPezzo       ; di questa parte

                bsf     Flags,Flag_Sil  ; verifica che non si tratti di un
                incfsz  PuntPezzo,W     ; silenzio
                bcf     Flags,Flag_Sil  ; setta il flag in accordo

                incf    Puntatore
                call    Estrai          ; legge i flag di esecuzione
                movwf   FlagEsecu       ; salva i flag di esecuzione
                andlw   0F              ; separa il numero di ripetizioni
                movwf   NumRipetizioni

                incf    Puntatore,W
                movwf   PuntParte       ; salva il puntatore al prox

PezzoL          movlw   SILNUMSAMPLE    ;
                btfsc   Flags,Flag_Sil  ; se il pezzo e' un silenzio
                goto    SetNumSample    ; NumSample e' noto a priori

                movf    PuntPezzo,W     ; dal pezzo attuale legge il NumSample
                movwf   Puntatore       ; dalla tabella pezzo
                ESTRAI                  ; estraendolo dalla pagina giusta

SetNumSample    movwf   NumSample       ;
                incf    Puntatore       ; punta al primo sample del pezzo

; loop di 10us si accorge di essere arrivato mediamente con 2us di ritardo
SampleL         movlw   RATE            ; se sono passati 60x2us +5us(medi)
                subwf   RTCC,W          ; w= (f-w) CY se RTCC > 60
                BNC     SampleL         ; 8000 sample per secondo

                ESTRAI                  ; estrae dalla pagina giusta un sample
                movwf   Acc             ; lo salva nell'accumulatore

; se e' un silenzio si setta il campione a 128 e basta
                movlw   D'128'
                btfsc   Flags,Flag_Sil
                movwf   Acc

; ora bisogna scalare il campione o decomprimerlo a seconda dei flag di parte

                movlw   070             ; maschera solo i flag di scalaggio
                andwf   FlagEsecu,W
                SKPNZ
                goto    Output          ; output immediato se VOL1

                btfss   FlagEsecu,6     ; se COMPRESSED inizia ad espandere
                goto    Scalaggio       ; else scalaggio

Expand          btfsc   NumSample,0     ; i dispari stanno in alto
                swapf   Acc             ; bisogna ruotarli giu'
                movlw   0F
                andwf   Acc,W           ; maschera solo il nibble basso
                btfsc   Acc,3           ; estensione del segno
                iorlw   0F0
                movwf   Acc
                goto    AddOffs

; ELSE scalaggio
; altrimenti prende il valore -128 e lo divide se necessario
Scalaggio       movlw   D'128'          ;
                subwf   Acc             ; f=f-w
                CLRC
                btfsc   Acc,7           ; se negativo, estende il segno
                SETC
                rrf     Acc             ; valore 1/2
                CLRC
                btfsc   Acc,7           ; se negativo, estende il segno
                SETC
                rrf     Acc,W           ; valore 1/4 in W
                btfss   FlagEsecu,1
                clrf    Acc             ; butta via il 1/2
                btfsc   FlagEsecu,0
                addwf   Acc             ; somma il valore 1/4
AddOffs         movlw   D'128'          ; riaggiunge il 128
                addwf   Acc             ; risomma

Output          movf    Acc,W
                movwf   Port_B          ; lo mette subito in uscita
                clrf    RTCC            ; ri-azzera il timer interno

                btfss   FlagEsecu,3     ; se non sta espandendo
                goto    NextSample      ; avanza sempre

                btfss   NumSample,0     ; se espande: sui dispari non avanza
NextSample      incf    Puntatore       ; punta al prox sample
                decfsz  NumSample       ; finiti i campioni ?
                goto    SampleL         ; no avanti un altro

                decfsz  NumRipetizioni  ; finite le ripetizioni ?
                goto    PezzoL          ; no va a ripetere il pezzo

; si la parte attuale e' finita, ora sono possibili due casi:
; a) FlagEsecu ha il bit 7 (LAST) settato
;       in tal caso: parte finita bisogna valutare se ci sono altre parti
; b) ELSE
;       PuntParte punta gia' al prox valore di scalaggio/compressione
;       in tal caso bisogna ripetere il brano con i nuovi flag
;
NextParte       movf    PuntParte,W     ; recupera il puntatore nella tab parti
                movwf   Puntatore

                btfss   FlagEsecu,7     ; testa il bit di LAST
                goto    Parte           ;

; caso a) parte finita
                decfsz  NumParti        ; ci sono altre parti da eseguire
                goto    Parte           ; si va a preparare la prox
                goto    main            ; no brano terminato

;----------------------------------------------------------------------------

                ORG     PIC56

start           goto    main

                END
