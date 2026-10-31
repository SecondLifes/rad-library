program SpikeCore;

(* TMS Scripter 8.1 cekirdek sondasi (VCL'siz): derleme, hiz, RTTI kayit kapsami,
   p-code kaydet/yukle, thread, calisma zamani hatasi, Halt ile zaman asimi.
   Olcumler [OLCUM] satirlarinda; karar docs/specs/rad.script-spike.md'ye yazilir. *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.Diagnostics, System.Threading,
  System.SyncObjs, System.Rtti, System.TypInfo,
  atScript, atPascal, ap_Classes, ap_SysUtils,
  Vcl.ScripterInit;   // DefaultMachineClass bunu kurar; olmadan EatInternalError (olculdu)

type
  TProbe = class
  private
    FValue: Integer;
  public
    function Add(A, B: Integer): Integer; overload;
    function Add(A, B, C: Integer): Integer; overload;
    function Greet(const AName: string; const ASuffix: string = '!'): string;
    function Sum(const A: array of Integer): Integer;
    function Names: TArray<string>;
    procedure Bump;
    property Value: Integer read FValue write FValue;
  end;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;
  GHookCount: Integer = 0;

procedure Kontrol(const AAd: string; ABasarili: Boolean; const ADetay: string = '');
begin
  if ABasarili then
  begin
    Inc(GBasari);
    Writeln('  [OK]   ', AAd);
  end
  else
  begin
    Inc(GHata);
    Writeln('  [HATA] ', AAd, '  ', ADetay);
  end;
end;

procedure Olcum(const AAd, ADeger: string);
begin
  Writeln('  [OLCUM] ', AAd, ' = ', ADeger);
end;

{ TProbe }

function TProbe.Add(A, B: Integer): Integer;
begin
  Result := A + B;
end;

function TProbe.Add(A, B, C: Integer): Integer;
begin
  Result := A + B + C;
end;

function TProbe.Greet(const AName, ASuffix: string): string;
begin
  Result := 'Merhaba ' + AName + ASuffix;
end;

function TProbe.Sum(const A: array of Integer): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i in A do Inc(Result, i);
end;

function TProbe.Names: TArray<string>;
begin
  Result := ['a', 'b'];
end;

procedure TProbe.Bump;
begin
  Inc(FValue);
end;

function NewScripter: TatPascalScripter;
begin
  Result := TatPascalScripter.Create(nil);
  Result.AddLibrary(TatClassesLibrary);
end;

function MethodList(AScripter: TatCustomScripter; const AClassName: string): string;
var
  C: TatClass;
  i: Integer;
begin
  Result := '';
  C := AScripter.Classes.ClassByName(AClassName);
  if C = nil then Exit('(sinif yok)');
  for i := 0 to C.Methods.Count - 1 do
    Result := Result + C.Methods[i].Name + ' ';
  Result := Result + '| props: ';
  for i := 0 to C.Properties.Count - 1 do
    Result := Result + C.Properties[i].Name + ' ';
end;

var
  LResults: array[0..3] of Integer;

function MakeWorker(AIdx: Integer): TProc;
begin
  Result := procedure
    var
      LS: TatPascalScripter;
    begin
      LS := NewScripter;
      try
        LS.SourceCode.Text :=
          'function Work: integer; var i, s: integer; begin s := 0; for i := 1 to 100000 do s := s + (i mod 7); result := s; end;' + sLineBreak +
          'begin end;';
        LS.Compile;
        LResults[AIdx] := LS.ExecuteSubroutineAsVariant('Work');
      finally
        LS.Free;
      end;
    end;
end;

type
  THookObj = class
    Deadline: TStopwatch;
    LimitMs: Int64;
    procedure ExecHook(Sender: TObject);
    procedure DeadlineHook(Sender: TObject);
  end;

procedure THookObj.ExecHook(Sender: TObject);
begin
  Inc(GHookCount);
  if GHookCount >= 200000 then
    TatCustomScripter(Sender).Halt;
end;

type
  ERadScriptTimeout = class(Exception);

procedure THookObj.DeadlineHook(Sender: TObject);
begin
  // Halt yerine istisna: Halt komut ortasinda VM'yi tutarsiz birakip AV uretti (C9 olcumu).
  if Deadline.ElapsedMilliseconds > LimitMs then
    raise ERadScriptTimeout.Create('script sure asimi');
end;

var
  GHook: THookObj;

var
  S, S2: TatPascalScripter;
  LExpected, LOk: Integer;
  P: TProbe;
  SW: TStopwatch;
  i: Integer;
  V: Variant;
  LSrc: TStringList;
  LMem: TMemoryStream;
  LTasks: array[0..3] of ITask;
  LErr: string;
begin
  try
    // C1: basit derleme + calistirma
    S := NewScripter;
    try
      S.SourceCode.Text :=
        'function F(a: integer): integer;' + sLineBreak +
        'begin result := a + 1; end;' + sLineBreak +
        'begin end;';
      SW := TStopwatch.StartNew;
      S.Compile;
      Olcum('C1 kucuk script derleme', SW.ElapsedMilliseconds.ToString + ' ms');
      V := S.ExecuteSubroutineAsVariant('F', [41]);
      Kontrol('C1 F(41) = 42', V = 42, VarToStr(V));

      // C3: 10.000 alt program cagrisi
      SW := TStopwatch.StartNew;
      for i := 1 to 10000 do
        V := S.ExecuteSubroutineAsVariant('F', [i]);
      Olcum('C3 10.000 ExecuteSubroutine', SW.ElapsedMilliseconds.ToString + ' ms');
    finally
      S.Free;
    end;

    // C2: 500 satirlik script derleme suresi
    LSrc := TStringList.Create;
    S := NewScripter;
    try
      for i := 1 to 100 do
      begin
        LSrc.Add(Format('procedure P%d(a: integer);', [i]));
        LSrc.Add('var i: integer;');
        LSrc.Add('begin');
        LSrc.Add('  i := a * 2; if i > 10 then i := i - 1;');
        LSrc.Add('end;');
      end;
      LSrc.Add('begin end;');
      S.SourceCode := LSrc;
      SW := TStopwatch.StartNew;
      S.Compile;
      Olcum('C2 ' + LSrc.Count.ToString + ' satir derleme', SW.ElapsedMilliseconds.ToString + ' ms');
      Kontrol('C2 derlendi', True);
    finally
      S.Free;
      LSrc.Free;
    end;

    // C4/C5: RTTI ile sinif kaydi, kapsam, script -> Delphi metot cagrisi hizi
    S := NewScripter;
    P := TProbe.Create;
    try
      SW := TStopwatch.StartNew;
      S.DefineClassByRTTI(TProbe);
      Olcum('C4 DefineClassByRTTI(TProbe)', SW.ElapsedMilliseconds.ToString + ' ms');
      S.AddObject('Probe', P);
      Olcum('C5 TProbe kayitli uyeler', MethodList(S, 'TProbe'));
      S.SourceCode.Text :=
        'procedure Loop(n: integer);' + sLineBreak +
        'var i: integer;' + sLineBreak +
        'begin for i := 1 to n do Probe.Add(i, 1); end;' + sLineBreak +
        'function Greet2: string; begin result := Probe.Greet(''Ali'', ''?''); end;' + sLineBreak +
        'function Greet1: string; begin result := Probe.Greet(''Ali''); end;' + sLineBreak +
        'procedure SetVal; begin Probe.Value := 7; Probe.Bump; end;' + sLineBreak +
        'function Add3: integer; begin result := Probe.Add(1, 2, 3); end;' + sLineBreak +
        'begin end;';
      try
        S.Compile;
        Olcum('C5 overload Add(a,b)', 'derlendi (ilk overload kayitli)');
      except
        on E: Exception do
        begin
          Olcum('C5 overload Add(a,b)', StringReplace(E.Message, sLineBreak, ' / ', [rfReplaceAll]));
          // Olculen: overload'da SON bildirilen Add(a,b,c) kaydoluyor (belge "ilki" diyor). Uc parametreyle devam.
          S.SourceCode.Text :=
            'procedure Loop(n: integer);' + sLineBreak +
            'var i: integer;' + sLineBreak +
            'begin for i := 1 to n do Probe.Add(i, 1, 0); end;' + sLineBreak +
            'function Greet2: string; begin result := Probe.Greet(''Ali'', ''?''); end;' + sLineBreak +
            'procedure SetVal; begin Probe.Value := 7; Probe.Bump; end;' + sLineBreak +
            'function Add3: integer; begin result := Probe.Add(1, 2, 3); end;' + sLineBreak +
            'begin end;';
          S.Compile;
          try
            // ana blok (begin end;) sondadir; Greet1 ONUNE eklenir
            S.SourceCode.Text := StringReplace(S.SourceCode.Text, 'begin end;',
              'function Greet1: string; begin result := Probe.Greet(''Ali''); end;' + sLineBreak + 'begin end;', []);
            S.Compile;
          except
            on E2: Exception do
            begin
              Olcum('C5 varsayilan parametre', 'desteklenmiyor: ' + StringReplace(E2.Message, sLineBreak, ' / ', [rfReplaceAll]));
              S.SourceCode.Text := StringReplace(S.SourceCode.Text,
                'function Greet1: string; begin result := Probe.Greet(''Ali''); end;' + sLineBreak, '', []);
              S.Compile;
            end;
          end;
        end;
      end;
      SW := TStopwatch.StartNew;
      S.ExecuteSubroutine('Loop', [10000]);
      Olcum('C4 script icinden 10.000 Delphi metot cagrisi', SW.ElapsedMilliseconds.ToString + ' ms');
      Kontrol('C5 iki parametreli Greet', S.ExecuteSubroutineAsVariant('Greet2') = 'Merhaba Ali?');
      try
        if S.SourceCode.Text.Contains('Greet1') then
          Kontrol('C5 varsayilan parametre (Greet1)', S.ExecuteSubroutineAsVariant('Greet1') = 'Merhaba Ali!');
      except
        on E: Exception do Olcum('C5 varsayilan parametre', 'calisma zamaninda hata: ' + E.Message);
      end;
      try
        Kontrol('C5 overload Add(1,2,3)', S.ExecuteSubroutineAsVariant('Add3') = 6);
      except
        on E: Exception do Olcum('C5 overload', 'desteklenmiyor: ' + E.Message);
      end;
      S.ExecuteSubroutine('SetVal');
      Kontrol('C5 ozellik yaz + metot', P.Value = 8, P.Value.ToString);

      // C6: p-code kaydet / kaynaksiz yukle
      LMem := TMemoryStream.Create;
      S2 := NewScripter;
      try
        S.SaveCodeToStream(LMem);
        Olcum('C6 p-code boyutu', LMem.Size.ToString + ' bayt');
        LMem.Position := 0;
        S2.DefineClassByRTTI(TProbe);
        S2.AddObject('Probe', P);
        S2.LoadCodeFromStream(LMem);
        P.Value := 0;
        S2.ExecuteSubroutine('SetVal');
        Kontrol('C6 p-code ile kaynaksiz calisti', (P.Value = 8) and (S2.SourceCode.Count = 0), 'Value=' + P.Value.ToString + ' src=' + S2.SourceCode.Count.ToString);
      finally
        S2.Free;
        LMem.Free;
      end;
    finally
      S.Free;
      P.Free;
    end;

    // C7: thread'ler, her birinin kendi scripter'i (indeks closure'a fabrika ile baglanir)
    LExpected := 0;
    for i := 1 to 100000 do Inc(LExpected, i mod 7);
    for i := 0 to 3 do
    begin
      LResults[i] := -1;
      LTasks[i] := TTask.Run(MakeWorker(i));
    end;
    TTask.WaitForAll(LTasks);
    LOk := 0;
    for i := 0 to 3 do if LResults[i] = LExpected then Inc(LOk);
    Olcum('C7 4 thread, ayri scripter, dogru sonuc', LOk.ToString + '/4 (beklenen ' + LExpected.ToString + ')');
    Kontrol('C7 thread: ayri ornekler sorunsuz', LOk = 4);

    // C8: calisma zamani hatasi
    S := NewScripter;
    try
      S.SourceCode.Text := 'function Bad: integer; var z: integer; begin z := 0; result := 10 div z; end;' + sLineBreak + 'begin end;';
      S.Compile;
      LErr := '';
      try
        S.ExecuteSubroutine('Bad');
      except
        on E: Exception do LErr := E.ClassName + ': ' + E.Message;
      end;
      Kontrol('C8 calisma zamani hatasi yakalandi', LErr <> '', LErr);
      Olcum('C8 hata metni', LErr);
    finally
      S.Free;
    end;

    // C9: sonsuz dongu -> OnExecHook ile Halt (zaman asimi taklidi)
    S := NewScripter;
    try
      S.SourceCode.Text := 'var x: integer;' + sLineBreak + 'begin x := 0; while true do x := x + 1; end;';
      GHook := THookObj.Create;
      S.Compile;
      // IKISI DE Compile'dan SONRA: Compile sanal makineyi yeniden kurar, onceki OnExecHook kaybolur;
      // CallExecHookEvent varsayilani False. Iki sirali hata da sonsuz donguyle olculdu (surec olduruldu).
      S.OnExecHook := GHook.ExecHook;
      S.CallExecHookEvent := True;
      Writeln('  C9 basliyor (hook etkin=', S.CallExecHookEvent, ')');
      GHookCount := 0;
      SW := TStopwatch.StartNew;
      LErr := '';
      try
        S.Execute;
      except
        on E: Exception do LErr := E.ClassName + ': ' + StringReplace(E.Message, sLineBreak, ' / ', [rfReplaceAll]);
      end;
      Olcum('C9 Halt ile durdurma', SW.ElapsedMilliseconds.ToString + ' ms, hook sayisi ' + GHookCount.ToString +
        ', Halted=' + BoolToStr(S.Halted, True) + ', istisna=' + LErr);
      Kontrol('C9 sonsuz dongu Halt ile bitti', GHookCount >= 200000);
    finally
      S.Free;
      GHook.Free;
    end;

    // C10: KP zaman asimi. OLCULDU: baska thread'den S.Halt guvenilmez (Win32'de 312 ms'de durdu, Win64'te
    // 5 s beklemedi; Free "Cannot clear script while script is running" ile patladi, surec asili kaldi).
    // Dogru yol: script'in kendi thread'inde OnExecHook icinde sure kontrolu + istisna.
    S := NewScripter;
    GHook := THookObj.Create;
    try
      S.SourceCode.Text := 'var x: integer;' + sLineBreak + 'begin x := 0; while true do x := x + 1; end;';
      S.Compile;
      GHook.Deadline := TStopwatch.StartNew;
      GHook.LimitMs := 300;
      S.OnExecHook := GHook.DeadlineHook;
      S.CallExecHookEvent := True;
      SW := TStopwatch.StartNew;
      LErr := '';
      LTasks[0] := TTask.Run(procedure
        begin
          try
            S.Execute;
          except
            on E: Exception do LErr := E.ClassName;
          end;
        end);
      Kontrol('C10 thread''deki script sure asiminda (hook+istisna) durdu', LTasks[0].Wait(5000));
      Olcum('C10 300 ms sinir, bitis', SW.ElapsedMilliseconds.ToString + ' ms, istisna=' + LErr);
    finally
      S.Free;
      GHook.Free;
    end;
  except
    on E: Exception do
    begin
      Inc(GHata);
      Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
    end;
  end;
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then Halt(1);
end.
