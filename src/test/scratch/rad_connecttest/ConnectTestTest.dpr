program ConnectTestTest;

{$APPTYPE CONSOLE}

{
  _ConnectTest'in "hatali olmasina ragmen True donuyor" sikayetinin olcumu.

  Iki bagimsiz sonda:
    A) TResult<T> yerel degiskeni SIFIRLANIYOR MU? (dil davranisi)
    B) _ConnectTest yonlendirilemez bir adrese karsi ne donuyor? (semptom)

  Hedef 192.0.2.1 (RFC 5737 TEST-NET-1) - tanim geregi yonlendirilemez.
}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  Uni,
  UniProvider,
  PostgreSQLUniProvider,
  mormot.core.base,
  rad.core   in '..\..\..\core\rad.core.pas',
  rad.thread in '..\..\..\core\rad.thread.pas',
  Help.uni   in '..\..\..\core\Help.uni.pas';

var
  GOk, GFail: Integer;

procedure Chk(ADogru: Boolean; const AMesaj: string);
begin
  if ADogru then
  begin
    Inc(GOk);
    Writeln('  [GECTI] ', AMesaj);
  end
  else
  begin
    Inc(GFail);
    Writeln('  [KALDI] ', AMesaj);
  end;
  Flush(Output);
end;

{ ---- A) Yerel TResult<T> gercekten sifirlaniyor mu ---------------------- }

procedure YiginiKirlet;
var
  LBuf: array[0..511] of Byte;
  i   : Integer;
begin
  for i := Low(LBuf) to High(LBuf) do
    LBuf[i] := $FF;
  { Derleyici optimize edip atmasin diye disari sizdiriyoruz. }
  if LBuf[0] <> $FF then
    Writeln('olmaz');
end;

function DokunulmamisKayit: TResult<Boolean>;
var
  rs: TResult<Boolean>;
begin
  { rs'ye HIC dokunulmuyor - tam olarak _ConnectTest'teki durum. }
  Result := rs;
end;

procedure KayitSifirlanmasi;
var
  r: TResult<Boolean>;
begin
  Writeln;
  Writeln('=== A) Yerel TResult<Boolean> sifirlaniyor mu ===');

  YiginiKirlet;
  r := DokunulmamisKayit;

  Writeln(Format('  dokunulmamis kayit -> IsSuccess=%s  ErrorMsg=%s',
    [BoolToStr(r.IsSuccess, True), '"' + r.ErrorMsg + '"']));

  { Delphi yerel kayitta YALNIZCA yonetilen alanlari (burada FErrorMsg:string)
    sifirlar; Boolean gibi yonetilmeyen alanlar yigindan geleni korur.
    OLCULDU: bu koruma eklenmeden once IsSuccess=True cikiyordu ve deger 0/1
    disinda oldugu icin `IsSuccess` ile `not IsSuccess` AYNI ANDA dogruydu.
    TResult<T>.Initialize operatoru bu bosluğu kapatiyor - 02 onun bekcisi. }
  Chk(r.ErrorMsg = '', '01 yonetilen alan (ErrorMsg) SIFIRLANDI');
  Chk(not r.IsSuccess, '02 dokunulmamis kayit DETERMINISTIK basarisiz (Initialize)');
end;

{ ---- B) _ConnectTest'in gercek davranisi -------------------------------- }

procedure BaglantiSonucu;
var
  cn: TUniConnection;
  r : TResult<Boolean>;
  LBas: UInt64;
begin
  Writeln;
  Writeln('=== B) _ConnectTest yonlendirilemez adrese karsi ===');

  cn := TUniConnection.Create(nil);
  try
    cn.ProviderName := 'PostgreSQL';
    cn.Server       := '192.0.2.1';
    cn.Port         := 5432;
    cn.Username     := 'yok';
    cn.Password     := 'yok';
    cn.Database     := 'yok';
    cn.LoginPrompt  := False;
    cn.SpecificOptions.Values['ConnectionTimeout'] := '3';

    LBas := GetTickCount64;
    r := cn._ConnectTest;
    Writeln(Format('  sure=%d ms  IsSuccess=%s  ErrorMsg="%s"',
      [GetTickCount64 - LBas, BoolToStr(r.IsSuccess, True), r.ErrorMsg]));

    Chk(not r.IsSuccess, '03 basarisiz baglanti IsSuccess=False dondurmeli');
    Chk(r.ErrorMsg <> '', '04 basarisiz baglanti SEBEBINI tasimali');

    { Yan etki kontrolu: _ConnectTest cagirmak kaynak bilesenin
      ConnectString'ini DEGISTIRMEMELI. }
    Chk(cn.Server = '192.0.2.1', '05 kaynak baglantinin Server''i degismedi');
    Chk(not cn.Connected, '06 kaynak baglanti acilmadi');
  finally
    cn.Free;
  end;
end;

procedure ParametreliCagri;
var
  cn, cn2 : TUniConnection;
  r       : TResult<Boolean>;
  LOnceki : string;
  LIkinci : string;
begin
  Writeln;
  Writeln('=== B2) Parametreyle verilen connection string ===');

  cn := TUniConnection.Create(nil);
  try
    cn.ProviderName := 'PostgreSQL';
    cn.Server       := '192.0.2.1';
    cn.Port         := 5432;
    cn.Username     := 'yok';
    cn.Password     := 'yok';
    cn.Database     := 'yok';
    cn.LoginPrompt  := False;
    cn.SpecificOptions.Values['ConnectionTimeout'] := '3';
    LOnceki := cn.ConnectString;

    { Dizeyi ELLE yazmiyoruz: UniDAC'in kendi parametre adlari saglayiciya
      gore degisir ('Provider=' kabul edilmiyor, EConnectionStringError atar).
      Ikinci bir baglantiyi yapilandirip ConnectString'ini okumak, saglayici
      ne bekliyorsa tam onu verir. }
    cn2 := TUniConnection.Create(nil);
    try
      cn2.ProviderName := 'PostgreSQL';
      cn2.Server       := '192.0.2.2';    // FARKLI, yine yonlendirilemez
      cn2.Port         := 5432;
      cn2.Username     := 'baska';
      cn2.Password     := 'baska';
      cn2.Database     := 'baska';
      cn2.LoginPrompt  := False;
      cn2.SpecificOptions.Values['ConnectionTimeout'] := '3';
      LIkinci := cn2.ConnectString;
    finally
      cn2.Free;
    end;

    r := cn._ConnectTest(LIkinci);

    Chk(not r.IsSuccess, '07 parametreli cagri da basarisiz olmali');
    Chk(r.ErrorMsg <> '', '08 parametreli cagri da SEBEBINI tasimali');

    { ESKI HALDE BOZUKTU: `finally ConnectString := TempStr` ve TempStr
      parametre verildiginde AConnectionString'e esitti - yani test etmek,
      test edilen dizeyi bilesenin uzerine KALICI olarak yaziyordu. }
    Chk(cn.ConnectString = LOnceki,
      '09 cagri kaynak bilesenin ConnectString''ini DEGISTIRMEDI');
    Chk(cn.Server = '192.0.2.1',
      '10 kaynak Server hala kendi degeri');
  finally
    cn.Free;
  end;
end;

begin
  GOk := 0;
  GFail := 0;

  TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(90000);
      Writeln;
      Writeln('  [BEKCI] 90 sn doldu - takilma var.');
      Flush(Output);
      Halt(3);
    end).Start;

  Application.Initialize;
  try
    KayitSifirlanmasi;
    BaglantiSonucu;
    ParametreliCagri;
  except
    on E: Exception do
    begin
      Inc(GFail);
      Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
    end;
  end;

  Writeln;
  Writeln(Format('SONUC: %d gecti, %d kaldi.', [GOk, GFail]));
  if GFail > 0 then
    ExitCode := 1;
end.
