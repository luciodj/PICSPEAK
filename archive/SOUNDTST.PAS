Program SoundTest;

Uses Crt, Graph;

Const
   MAIN_SIZE = 30000;
   MIN_SIZE = 320+44;

Type
   Tbuffer = array [1..MAIN_SIZE] of byte;
   PTbuffer= ^Tbuffer;
   Lbuffer = record
                 d: PTbuffer;      { puntatore al buffer allocato  }
                 len: integer;     { lunghezza del buffer allocato }
                 end;

Var
   buffer: PTbuffer;

Procedure Beep;
Begin
      Sound(220);
      Delay(200);
      NoSound;
End;

Procedure Cursor(old, new, c: integer);
{ old  vecchia posizione   new nuova posizione  c colore di disegno }
Begin
     SetColor( c);
     SetWriteMode( XORput);
     Line(old*2, 240-128, old*2, 240+128);
     Line(new*2, 240-128, new*2, 240+128);
     SetWriteMode( Normalput);

End; { Cursor }

Procedure Coord( k, cs, cd, c: integer);
Var
    s: string[6];
Begin
     SetFillStyle( EmptyFill, c);
     Bar(0, 0, 100 * 3, 16);
     SetColor( c);
     Str( (cs+k*16):4, s);
     OutTextXY(0, 0, s);

     Str( (cd+k*16):4, s);
     OutTextXY(100, 0, s);

     Str( abs(cd-cs):4, s);
     OutTextXY(200, 0, s);
End;



Procedure Paint(k, cs, cd, c: integer);
{  k offset a passo 16    c: colore di paint }
{  cs e cd sono i due cursori destro e sinistro }
Var
   old, last, i, x:integer;
   s: string[6];

Begin
   ClearViewPort;
   SetColor( c);
   x:= 0;
   old:= 0;     { livello precedente }
   i:= 45+ k*16;  { calcolo punto iniziale }
   WHILE ( x < 340) DO Begin
       Line( (x-1)*2, 240- old , x*2, 240- (buffer^[i]-128));
       PutPixel( x*2, 240, c);
       IF odd(i) THEN Begin
          PutPIxel( x*2, 240 + 64, c);
          PutPixel( x*2, 240 - 64, c);
          PutPIxel( x*2, 240 + 32, c);
          PutPixel( x*2, 240 - 32, c);
          PutPIxel( x*2, 240 + 16, c);
          PutPixel( x*2, 240 - 16, c);
          End;

       IF ((i-45) and $0F = 0) THEN Begin
          IF ((i-45) and $7F = 0) THEN Begin
              Str( (i-45):4, s);
              OutTextXY( x*2, 240+128-2, s);
              Line( x*2, 240-8, x*2, 240+8);
              End
          ELSE
              Line( x*2, 240-2, x*2, 240+2);
          End;

       old:= buffer^[i] - 128;
       Inc(i);
       Inc(x);
       End;

       Cursor( cs, cd, c);   { traccia i due cursori }
       Coord( k, cs, cd, c);

End; { Paint }

Procedure Hex3(var s: string; i: integer);
Const
    Hex= '0123456789ABCDEF';
Begin
    s:= '0'+ Copy(Hex, i div 16+1, 1) + Copy( Hex, i mod 16+1, 1);
End;


Procedure SavePIC(k, cs, cp: integer; ch: char);
Var
   fp: text;
   t: integer;
   s: string[3];
Begin
    {$I-}
    Assign( fp, ch+'.t');
    Rewrite( fp);
    IF IOResult = 0 THEN Begin
        Write(fp, ^I, ^I, 'retlw', ^I);
        Hex3( s, cp-cs);         { numero di campioni come primo elemento }
        WriteLn(fp, s+ ^I +'; numero campioni: ', cp-cs:3);
        FOR t:= 1 TO cp-cs DO Begin
            Write(fp, ^I, ^I, 'retlw', ^I);
            Hex3( s, buffer^[44+ k*16 + cs + t]);
            WriteLn(fp, s);
            End;
        Close( fp)
        End
    ELSE
        Beep;
    {$I+}
End; { savePIC }


Procedure SaveWave( fname: string; start, count: integer);
Var
   fp: file of byte;
   t, h: integer;
Begin
    { calcola e prepara le nuove lunghezze }
    h:= count + 36;        { ckSize di tutto il "RIFF" }
    buffer^[5]:=  Lo( h);
    buffer^[6]:=  Hi( h);
    buffer^[41]:= Lo( count);  { ckSize della parte "data" }
    buffer^[42]:= Hi( count);

    { apre il file in scrittura }
    {$I-}
    Assign( fp, fname);
    Rewrite( fp);
    IF IOResult=0 THEN Begin
        FOR t:= 1 TO 44 DO         { scrittura del nuovo header }
            Write( fp, buffer^[t]);

        FOR t:= 1 TO count DO      { scrittura del blocco dati }
            Write(fp, buffer^[start+ t]);

        Close( fp);
        End
    ELSE
        Beep;
    {$I+}
End; { savewave }

Procedure SaveSegWave(k, cs, cd: integer; ch: char);
Var
    start, count: integer;
    fname: string;

Begin
    { richiama SaveWave }
    start:= 44+ k*16 + cs;
    count:= cd-cs;
    fname:= ch+'.WAV';
    SaveWave(fname, start, count);
End; { SaveSegWave }


Procedure Compress(k, cs, cp: integer; ch: char);
Var
   fp: text;
   t, x: integer;
   s: string[3];

Begin
    Assign( fp, ch+ '.t');
    Rewrite( fp);
    Write(fp, ^I, ^I, 'retlw', ^I);
    Hex3( s, cp-cs);         { numero di campioni come primo elemento }
    WriteLn(fp, s+ ^I +'; numero campioni (compressi): ', cp-cs:3);
    FOR t:= 1 TO (cp-cs) div 2 DO Begin
        Write(fp, ^I, ^I, 'retlw', ^I);
        x:= buffer^[43+ k*16 + cs + t*2] - 128;
        IF abs(x) > 8 THEN OutTextXY(0, 0, 'fuori range');
        x:= (x shl 4) + ((buffer^[45+ k*16 + cs + t*2+1] - 128) and $0F);
        Hex3( s, x and $FF);
        WriteLn(fp, s);
        End;

    IF odd(cp-cs) THEN Begin
        Write(fp, ^I, ^I, 'retlw', ^I);
        x:= ((buffer^[44+ k*16 + cs + (cp-cs)] - 128) and $0F) shl 4;
        Hex3( s, x and $FF);
        WriteLn(fp, s);
        End;

    Close( fp);
End; { compress }


Procedure LoadWave( fname: string;     { nome del file }
                    buffer: PTbuffer;    { puntatore al buffer }
                    maxlen: integer;     { massima lunghezza del buffer }
                    Var rlen: integer);  { numero di byte letti }
Var
    fp: file;
    i : integer;

Begin
    { azzeramento del buffer }
    FOR i:=1 TO maxlen DO
        buffer^[i]:= 128;

    {$I-}
    Assign(fp, fname);
    Reset(fp, 1);
    IF IOResult<>0 THEN
        rlen:= 0
    ELSE Begin
        BlockRead(fp, buffer^, maxlen, rlen);
        Close(fp);
        { la vera lunghezza e' data da ckSize alla locazione 41 e 42 }
        { piu' 44 byte di Header }
        rlen:= buffer^[42] * 256 + buffer^[41]+ 44;
        End;
    {$I+}
End; { LoadWave }


Var
   i, j, x, len: integer;
   k : integer;
   cs, cd: integer;
   color: integer;
   fine: boolean;
   ch: char;
   fname, s: string;
   grDriver : Integer;
   grMode   : Integer;
   ErrCode  : Integer;
   b : array[0..9] of Lbuffer;

Begin
    { alloca il buffer principale e 10 buffer minori }
    GetMem( buffer, sizeof(Tbuffer));
    FOR i:= 0 TO 9 DO Begin
        GetMem( b[i].d, MIN_SIZE);
        b[i].len:= 0;    { inizialmente vuoti anche se allocati }
        End;


    { se non precisato come parametro, chiede il nome di un file }
    IF ParamCount <1 THEN
        Repeat
            Write('Load file: ');
            ReadLn(fname);
        Until (fname <>'')
    ELSE fname:= ParamStr(1);

    LoadWave( fname, buffer, MAIN_SIZE, len);
    IF len = 0 THEN Begin
       WriteLN('Errore: Non trovo il File o File vuoto!');
       Beep;
       Halt(1);
       End;


{ hex dump delle prime 44 locazioni header del file tipo wave
    WriteLN('Il file inizia con i seguenti campioni');
    FOR i:=1 TO 44 DO Begin
        Write(buffer^[i]:4);
        IF chr(buffer^[i]) IN ['0'..'z'] THEN
            Write(chr(buffer^[i]));
        End;
    WriteLn;
ReadLn;
}
   grDriver := Detect;
   InitGraph(grDriver, grMode, '\tp55');
   color:= GetMaxColor;

   cs:= 0;         { cursore sinistro }
   cd:= 319;       { cursore destro }
   k:= 0;          { offset margine sinistro }
   fine:= FALSE;
   Paint( k, cs, cd, color);

   WHILE NOT(fine) DO BEGIN
       ch:= ReadKey;
       IF ch=#0 THEN Begin
          ch:= ReadKey;  { tasto con escape }
          CASE ch OF
          #45 : fine:= TRUE;

          #71 : { Home }
              Begin
                k:= 0;
                Paint( k, cs, cd, color);
                End;

          #79 : { END }
              Begin
                k:= (len-44) div 16;
                IF k < 10 THEN k:= 0
                ELSE k:= k-10;
                cs:= len- 44- k*16;
                cd:= 319;
                Paint( k, cs, cd, color);
                End;

          #73 : { PageUp }
                IF k>=10 THEN Begin
                    Dec(k, 10);
                    Paint( k, cs, cd, color);
                    End;

          #81 : {  PageDown }
                IF k<1800 THEN Begin
                   Inc(k, 10);
                   Paint( k, cs, cd, color);
                   End;
          ELSE Begin
               Str( ord(ch):3, s);
               OutTextXY( 50, 0, '#0+#'+s);
               Beep;
               End;
          End; { CASE }
          End

       ELSE Begin { tasti normali }
           CASE ch OF
           's','S': { salvataggio in formato pic }
                    Begin
                    ch:= UpCase(ReadKey);
                    IF ch IN ['A'..'Z'] THEN
                        SavePIC(k, cs, cd, ch)
                    ELSE
                        Beep;
                    End;

           'k','K': { salva in formato pic con compressione }
                    Begin
                    ch:= UpCase(ReadKey);
                    IF ch IN ['A'..'Z'] THEN
                        Compress(k, cs, cd, ch)
                    ELSE
                        Beep;
                    End;

           'w','W': { salvataggio in formato Wave del segmento selezionato }
                    Begin
                    ch:= UpCase(ReadKey);
                    IF ch IN ['A'..'Z'] THEN
                        SaveSegWave(k, cs, cd, ch)
                    ELSE
                        Beep;
                    End;

           'l','L': { Load di un Wave in un buffer }
                    Begin
                    { prima legge il numero del buffer }
                    ch:= UpCase(ReadKey);
                    IF ch IN ['0'..'9'] THEN Begin
                       j:= ord(ch)- ord('0');
                       { poi legge il nome del file A.WAV }
                       ch:= UpCase(ReadKey);
                       IF ch IN ['A'..'Z'] THEN Begin
                           LoadWave( ch+'.WAV', b[j].d, MIN_SIZE, b[j].len);
                           { toglie l'header }
                           IF b[j].len > 44 THEN Begin
                               Move(b[j].d^[45], b[j].d^[1], b[j].len- 44);
                               Str( b[j].len:6, s);
                               OutTextXY( 0, 20, s+'bytes loaded');
                               Dec(b[j].len, 44);
                               End
                           ELSE { file corto }
                               Beep;
                           End
                       ELSE
                           Beep
                       End
                    ELSE
                        Beep;
                    End;

           'c','C': { copia di un segmento in un buffer }
                    Begin
                    ch:= UpCase(ReadKey); { legge il numero del buffer }
                    IF ch IN ['0'..'9'] THEN Begin
                        j:= ord(ch)- ord('0');
                        FOR i:=1 TO cd-cs DO
                            b[j].d^[i]:= buffer^[44+ k*16+ cs+ i];
                        b[j].len:= cd-cs;
                        End
                    ELSE
                        Beep;
                    End;

           'x','X': { taglia un segmento dal buffer }
                    Begin
                    ch:= UpCase(ReadKey); { legge il numero del buffer }
                    IF ch IN ['0'..'9'] THEN Begin
                        j:= ord(ch)- ord('0');
                        FOR i:=1 TO cd-cs DO
                            b[j].d^[i]:= buffer^[44+ k*16+ cs+ i];
                        b[j].len:= cd-cs;
                        { sposta tutto verso il basso }
                        x:= 44+k*16;
                        Move(buffer^[x+ cd], buffer^[x+cs], len- (x+cd));
                        Dec( len, cd-cs);
                        Paint( k, cs, cd, color);
                        End
                    ELSE
                        Beep;
                    End;

           'p','P': { paste di un segmento nel buffer alla posizione cs }
                    { sposta verso su tutto quello che segue }
                    Begin
                    ch:= UpCase(ReadKey); { legge il numero del buffer }
                    IF ch IN ['0'..'9'] THEN Begin
                        x:= 44+ k*16;
                        j:= ord(ch)- ord('0');

                        { sposta verso l'alto tutto quello che segue }
                        Move( buffer^[x+cs], buffer^[x+cs+b[j].len],
                              len- (x+cs));

                        { poi inserisce il nuovo }
                        FOR i:=1 TO b[j].len DO
                            buffer^[x+ cs+ i]:= b[j].d^[i];

                        { sposta i cursori e centra nella pagina }
                        Inc( len, b[j].len);
                        Inc( cs, b[j].len);
                        WHILE cs>150 DO Begin
                             Inc(k);
                             Dec(cs, 16);
                             End;
                        cd:= 319;
                        Paint( k, cs, cd, color);
                        End
                    ELSE
                        Beep;
                    End;


           'e','E': { pulizia del buffer principale }
                    Begin
                        FOR i:=45 TO MAIN_SIZE DO
                            buffer^[i]:= 128;
                        k:= 0;
                        cs:= 0;
                        cd:= 319;
                        len:= 44;
                        Paint( k, cs, cd, color);
                        End;

           'o','O': { Open di un file Wave nel buffer principale }
                    Begin
                    RestoreCrtMode; { torna in modo testo }
                    ClrScr;         { pulisce la pagina testo }
                    WriteLn( 'Load del buffer principale');
                    Write( 'Nome del file:');
                    ReadLn( fname);
                    WriteLn;
                    IF fname<>'' THEN Begin
                        LoadWave( fname, buffer, MAIN_SIZE, len);
                        IF len<45 THEN
                            Beep;
                        k:= 0;
                        cs:= 0;
                        cd:= 319;
                        End
                    ELSE
                        Beep;
                    SetGraphMode( GetGraphMode); { ritorna in pagina grafica }
                    Paint( k, cs, cd, color);
                    End;

           'y','Y': { Save in formato Wave del buffer principale }
                    Begin
                    RestoreCrtMode; { torna in modo testo }
                    ClrScr;         { pulisce la pagina testo }
                    WriteLn( 'Save del buffer principale ');
                    Write( 'Nome del file:');
                    ReadLn( fname);
                    WriteLn;
                    IF fname<>'' THEN
                        SaveWave( fname, 45, len)
                    ELSE
                        Beep;
                    SetGraphMode( GetGraphMode); { ritorna in pagina grafica }
                    Paint( k, cs, cd, color);
                    End;

           ',' : { a sinistra il cursore sinistro }
                 IF cs>0 THEN Begin
                     Dec(cs);
                     Cursor( cs+1, cs, color);
                     Coord( k, cs, cd, color);
                     End;

           '.' : { a destra il cursore sinistro }
                 IF cs<319 THEN Begin
                     Inc(cs);
                     Cursor( cs-1, cs, color);
                     Coord( k, cs, cd, color);
                     End;

           ';' : { a sinistra il cursore destro }
                 IF cd>0 THEN Begin
                     Dec(cd);
                     Cursor( cd+1, cd, color);
                     Coord( k, cs, cd, color);
                     End;

           '''' : { a destra il cursore destro }
                 IF cd<319 THEN Begin
                     Inc(cd);
                     Cursor( cd-1, cd, color);
                     Coord(k, cs, cd, color);
                     End;

           #27: fine:= TRUE;

          ELSE Begin
               Str( ord(ch):3, s);
               OutTextXY( 50, 0, '#'+s);
               Beep;
               End;

           End; { case }
           End;

    End;

    CloseGraph;
End.
