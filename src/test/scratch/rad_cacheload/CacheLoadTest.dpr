program CacheLoadTest;

{$APPTYPE CONSOLE}

{
  TSmartCache.FileLoad sondasi.

  FileLoad bu oturumdan once HIC DERLENMEMISTI (const parametreye atama,
  E2064) ve govdesi de yarimdi: `case i of` atanmamis bir degiskene bakiyor,
  okunan belge FDic'e hic yazilmiyordu.

  Olculen sozlesme: json/yml/xml -> duzlestir -> FDic. Ayrica abonelik
  korunmasi, hata raporlama ve tip sadakati.
}

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Rtti,
  System.TypInfo,       // GetEnumName
  System.IOUtils,
  mormot.core.base,
  rad.core       in '..\..\..\core\rad.core.pas',
  help.mormot    in '..\..\..\core\help.mormot.pas',
  rad.cache      in '..\..\..\core\rad.cache.pas';

var
  GOk, GFail: Integer;
  GKlasor: string;

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

function Yaz(const AAd, AIcerik: string): string;
begin
  Result := TPath.Combine(GKlasor, AAd);
  TFile.WriteAllText(Result, AIcerik, TEncoding.UTF8);
end;

procedure Dok(const AC: TSmartCache; const ABaslik: string);
var
  k: string;
begin
  Writeln('  ', ABaslik, ' (', AC.Count, ' anahtar):');
  for k in AC.Keys do
    Writeln('    ', k, ' = ', AC.GetValue(k, TValue.Empty).ToString);
  Flush(Output);
end;

{ ------------------------------------------------------------------ }

procedure JsonYukleme;
var
  c: TSmartCache;
  f: string;
begin
  Writeln;
  Writeln('=== 1) JSON: ic ice -> duz ===');
  f := Yaz('t1.json',
    '{"aile":{"baba":"emrah","anne":"Senay","cocuk":{"sayisi":3}},"aktif":true}');

  c := TSmartCache.Create;
  try
    Chk(c.FileLoad(f), '01 FileLoad True dondu');
    Dok(c, 'sonuc');
    Chk(c.ContainsKey('aile.baba'),         '02 aile.baba olustu');
    Chk(c.ContainsKey('aile.cocuk.sayisi'), '03 aile.cocuk.sayisi (IC ICE)');
    Chk(not c.ContainsKey('aile'),          '04 ic ice nesne anahtar olarak KALMADI');
    Chk(c.Get('aile.baba', '') = 'emrah',   '05 string degeri dogru');
  finally
    c.Free;
  end;
end;

procedure TipSadakati;
var
  c: TSmartCache;
  f: string;
  LV: TValue;
begin
  Writeln;
  Writeln('=== 2) Dogal tipler korunuyor mu ===');
  f := Yaz('t2.json', '{"sayi":42,"ondalik":3.5,"bayrak":true,"metin":"x"}');

  c := TSmartCache.Create;
  try
    c.FileLoad(f);

    LV := c.GetValue('sayi', TValue.Empty);
    Writeln('  sayi TValue.Kind = ', GetEnumName(TypeInfo(TTypeKind), Ord(LV.Kind)));

    Chk(c.Get<Int64>('sayi', 0) = 42,        '06 Get<Int64> = 42');
    Chk(c.Get('ondalik', 0.0) = 3.5,         '07 Double = 3.5');
    Chk(c.Get('bayrak', False) = True,       '08 Boolean = True');
    Chk(c.Get('metin', '') = 'x',            '09 string = x');

    { DIKKAT: JSON tam sayilari Int64 gelir. Sinifin sozlesmesi "tip
      uyusmazligi = bulunamadi" oldugu icin Get<Integer> varsayilani
      dondurebilir. Iddia degil, OLCUM - sonuc ne cikarsa raporlanir. }
    Writeln('  Get(''sayi'', 0) [Integer overload] = ', c.Get('sayi', 0));
    Flush(Output);
  finally
    c.Free;
  end;
end;

procedure Diziler;
var
  c: TSmartCache;
  f: string;
begin
  Writeln;
  Writeln('=== 3) Diziler indeksli anahtara aciliyor mu ===');
  f := Yaz('t3.json', '{"renk":["kirmizi","mavi"]}');

  c := TSmartCache.Create;
  try
    c.FileLoad(f);
    Dok(c, 'sonuc');
    Chk(c.ContainsKey('renk.0'), '10 renk.0 olustu');
    Chk(c.ContainsKey('renk.1'), '11 renk.1 olustu');
    Chk(c.Get('renk.0', '') = 'kirmizi', '12 renk.0 degeri dogru');
  finally
    c.Free;
  end;
end;

procedure YamlVeXml;
var
  c: TSmartCache;
  f: string;
begin
  Writeln;
  Writeln('=== 4) YAML ===');
  f := Yaz('t4.yml', 'aile:'#13#10'  baba: emrah'#13#10'  anne: Senay'#13#10);
  c := TSmartCache.Create;
  try
    Chk(c.FileLoad(f), '13 .yml yuklendi');
    Dok(c, 'yaml');
    Chk(c.ContainsKey('aile.baba'), '14 YAML ic ice yapisi duzlesti');
  finally
    c.Free;
  end;

  Writeln;
  Writeln('=== 5) XML ===');
  f := Yaz('t5.xml', '<root><aile><baba>emrah</baba></aile></root>');
  c := TSmartCache.Create;
  try
    Chk(c.FileLoad(f), '15 .xml yuklendi');
    Dok(c, 'xml');
    Chk(c.Count > 0, '16 XML''den en az bir anahtar cikti');
  finally
    c.Free;
  end;
end;

procedure TemizlemeVeBirlestirme;
var
  c: TSmartCache;
  f: string;
begin
  Writeln;
  Writeln('=== 6) AClearFirst ===');
  f := Yaz('t6.json', '{"yeni":1}');

  c := TSmartCache.Create;
  try
    c.AddOrSet('eski', 99);
    c.FileLoad(f, True);
    Chk(not c.ContainsKey('eski'), '17 AClearFirst=True eski anahtari sildi');
    Chk(c.ContainsKey('yeni'),     '18 dosyadaki anahtar yuklendi');
  finally
    c.Free;
  end;

  c := TSmartCache.Create;
  try
    c.AddOrSet('eski', 99);
    c.AddOrSet('yeni', 5);
    c.FileLoad(f, False);
    Chk(c.ContainsKey('eski'),        '19 AClearFirst=False eskiyi KORUDU');
    Chk(c.Get<Int64>('yeni', 0) = 1,  '20 cakisan anahtarda DOSYA kazandi');
  finally
    c.Free;
  end;
end;

procedure AbonelikKorunmasi;
var
  c: TSmartCache;
  f: string;
  LSayac: Integer;
begin
  Writeln;
  Writeln('=== 7) Yeniden yukleme abonelikleri koparmiyor ===');
  f := Yaz('t7.json', '{"k":1}');
  LSayac := 0;

  c := TSmartCache.Create;
  try
    c.RegisterEvent('k',
      function(AKey: string; AOld, ANew: TValue): Boolean
      begin
        Inc(LSayac);
        Result := True;
      end);

    c.FileLoad(f, True);
    Chk(LSayac = 1, Format('21 yukleme abone olayini tetikledi (%d)', [LSayac]));

    { TSmartCache.Clear FDicEvents'i de bosaltir; FileLoad onu CAGIRMAMALI,
      yoksa ikinci yukleme sessizce aboneliksiz kalirdi. }
    Yaz('t7.json', '{"k":2}');
    c.FileLoad(f, True);
    Chk(LSayac = 2, Format('22 IKINCI yukleme de tetikledi - abonelik YASIYOR (%d)', [LSayac]));
  finally
    c.Free;
  end;
end;

type
  { TSmartCacheErrorEvent `of object` oldugu icin anonim metot ATANAMAZ
    (E2010) - gercek bir nesne metodu gerekiyor. }
  THataYakalayici = class
  public
    Mesaj: string;
    procedure Yakala(const AKey: string; const AError: Exception);
  end;

procedure THataYakalayici.Yakala(const AKey: string; const AError: Exception);
begin
  Mesaj := AError.Message;
end;

procedure HataYollari;
var
  c: TSmartCache;
  f: string;
  LY: THataYakalayici;

  function LHata: string;
  begin
    Result := LY.Mesaj;
  end;

  procedure Kur(const AC: TSmartCache);
  begin
    LY.Mesaj := '';
    AC.OnError := LY.Yakala;
  end;

begin
  LY := THataYakalayici.Create;
  try
  Writeln;
  Writeln('=== 8) Hata yollari SESSIZ degil ===');

  c := TSmartCache.Create;
  try
    Kur(c);
    Chk(not c.FileLoad(TPath.Combine(GKlasor, 'yok.json')), '23 olmayan dosya -> False');

    f := Yaz('t8.csv', 'a,b');
    Chk(not c.FileLoad(f), '24 desteklenmeyen .csv -> False');
    Writeln('  hata: ', LHata);
    Chk(Pos('uzantisi', LHata) > 0, '25 OnError SEBEBI soyledi (uzanti)');

    f := Yaz('t9.json', '{bozuk json');
    Kur(c);
    Chk(not c.FileLoad(f), '26 bozuk JSON -> False');
    Chk(LHata <> '', '27 OnError bozuk JSON icin de tetiklendi');

    f := Yaz('t10.json', '[1,2,3]');
    Kur(c);
    Chk(not c.FileLoad(f), '28 JSON DIZISI (nesne degil) -> False');
    Writeln('  hata: ', LHata);
    Chk(Pos('NESNESI', LHata) > 0, '29 sebep: nesne degil');
    finally
      c.Free;
    end;
  finally
    LY.Free;
  end;
end;

procedure KaydetYukleGidisDonusu;
var
  Kaynak: TSmartCache;
  JsonHedef: TSmartCache;
  XmlHedef: TSmartCache;
  YamlHedef: TSmartCache;
  f: string;
  IlkIcerik: string;
begin
  Writeln;
  Writeln('=== 9) FileSave / FileLoad gidis-donusu ===');
  Kaynak := TSmartCache.Create;
  try
    Kaynak.AddOrSet('sayi', 42);
    Kaynak.AddOrSet('metin', 'Merhaba Dünya');
    Kaynak.AddOrSet('bayrak', True);

    f := TPath.Combine(GKlasor, 'save.json');
    Kaynak.FileSave(f);
    IlkIcerik := TFile.ReadAllText(f, TEncoding.UTF8);
    Chk(Pos('FSaveFileName', IlkIcerik) = 0,
      '30 JSON yalniz cache verisini iceriyor');
    Kaynak.FileSave(f);
    Chk(TFile.ReadAllText(f, TEncoding.UTF8) = IlkIcerik,
      '31 ayni veri kararli JSON uretiyor');
    JsonHedef := TSmartCache.Create;
    try
      Chk(JsonHedef.FileLoad(f), '32 kaydedilen JSON yuklendi');
      Chk(JsonHedef.Get<Int64>('sayi', -1) = 42, '33 JSON sayi gidis-donusu');
      Chk(JsonHedef.Get('metin', '') = 'Merhaba Dünya',
        '34 JSON metin gidis-donusu');
      Chk(JsonHedef.Get('bayrak', False), '35 JSON boolean gidis-donusu');
    finally
      JsonHedef.Free;
    end;

    f := TPath.Combine(GKlasor, 'save.yaml');
    Kaynak.FileSave(f);
    YamlHedef := TSmartCache.Create;
    try
      Chk(YamlHedef.FileLoad(f), '36 kaydedilen YAML yuklendi');
      Chk(YamlHedef.Get<Int64>('sayi', -1) = 42, '37 YAML sayi gidis-donusu');
    finally
      YamlHedef.Free;
    end;

    f := TPath.Combine(GKlasor, 'save.xml');
    Kaynak.FileSave(f);
    XmlHedef := TSmartCache.Create;
    try
      Chk(XmlHedef.FileLoad(f), '38 kaydedilen XML yuklendi');
      Chk(XmlHedef.Count = 3, '39 XML tum anahtarlari geri yukledi');
    finally
      XmlHedef.Free;
    end;
  finally
    Kaynak.Free;
  end;
end;

procedure KaydetmeHataGuvenligi;
const
  ONCEKI_ICERIK = 'onceki-icerik';
var
  c: TSmartCache;
  Arayuz: IInterface;
  f: string;
  HataOlustu: Boolean;
begin
  Writeln;
  Writeln('=== 10) FileSave hata guvenligi ===');
  c := TSmartCache.Create;
  try
    c.AddOrSet('gizli', 'deger');
    f := TPath.Combine(GKlasor, 'cipher.json');
    if TFile.Exists(f) then
      TFile.Delete(f);
    HataOlustu := False;
    try
      c.FileSave(f, True);
    except
      on E: ESmartCacheJson do
        HataOlustu := True;
    end;
    Chk(HataOlustu, '40 ACipher=True acik hata uretti');
    Chk(not TFile.Exists(f), '41 ACipher=True duz metin yazmadi');

    f := Yaz('atomik.json', ONCEKI_ICERIK);
    Arayuz := TInterfacedObject.Create;
    c.AddOrSet('arayuz', Arayuz);
    HataOlustu := False;
    try
      c.FileSave(f);
    except
      on E: ESmartCacheJson do
        HataOlustu := True;
    end;
    Chk(HataOlustu, '42 desteklenmeyen TValue acik hata uretti');
    Chk(TFile.ReadAllText(f, TEncoding.UTF8) = ONCEKI_ICERIK,
      '43 basarisiz save mevcut hedefi korudu');
  finally
    c.Free;
  end;
end;

procedure EszamanliKaydetme;
var
  c: TSmartCache;
  Hedef: TSmartCache;
  Isci: TThread;
  f: string;
  IsciHatasi: Integer;
begin
  Writeln;
  Writeln('=== 11) Eszamanli FileSave ===');
  c := TSmartCache.Create(True);
  try
    IsciHatasi := 0;
    Isci := TThread.CreateAnonymousThread(
      procedure
      begin
        try
          for var i := 1 to 5000 do
            c.AddOrSet('k' + IntToStr(i mod 50), i);
        except
          on E: Exception do
            TInterlocked.Increment(IsciHatasi);
        end;
      end);
    try
      Isci.FreeOnTerminate := False;
      Isci.Start;
      f := TPath.Combine(GKlasor, 'concurrent.json');
      for var i := 1 to 50 do
        c.FileSave(f);
      Isci.WaitFor;
    finally
      Isci.Free;
    end;
    Chk(IsciHatasi = 0, '44 eszamanli yazar exception uretmedi');

    Hedef := TSmartCache.Create;
    try
      Chk(Hedef.FileLoad(f), '45 eszamanli kaydedilen dosya gecerli JSON');
      Chk(Hedef.Count > 0, '46 eszamanli snapshot bos degil');
    finally
      Hedef.Free;
    end;
  finally
    c.Free;
  end;
end;

procedure SinirDurumlari;
var
  Birinci: TSmartCache;
  BosHedef: TSmartCache;
  Ikinci: TSmartCache;
  LValue: TValue;
  f: string;
  HataOlustu: Boolean;
begin
  Writeln;
  Writeln('=== 12) Sinir durumlari ===');
  Birinci := TSmartCache.Create;
  try
    Birinci.AddOrSet('korunacak', 7);
    Ikinci := TSmartCache.Create;
    try
      Ikinci.AddOrSet('diger', 9);
    finally
      Ikinci.Free;
    end;
    Chk(Birinci.Get('korunacak', -1) = 7,
      '47 iki cache ornegi birbirinden bagimsiz');

    Birinci.Clear;
    f := TPath.Combine(GKlasor, 'empty.yaml');
    Birinci.FileSave(f);
    BosHedef := TSmartCache.Create;
    try
      Chk(BosHedef.FileLoad(f), '48 bos YAML yuklendi');
      Chk(BosHedef.Count = 0, '49 bos YAML bos cache uretti');
    finally
      BosHedef.Free;
    end;

    Birinci.AddOrSet('bos', TValue.Empty);
    Birinci.AddOrSet('uint64', TValue.From<UInt64>(UInt64(High(Int64))));
    f := TPath.Combine(GKlasor, 'boundaries.json');
    Birinci.FileSave(f);
    BosHedef := TSmartCache.Create;
    try
      Chk(BosHedef.FileLoad(f), '50 null ve UInt64 JSON yuklendi');
      Chk(BosHedef.TryGetValue('bos', LValue) and LValue.IsEmpty,
        '51 JSON null TValue.Empty olarak korundu');
      Chk(BosHedef.Get<UInt64>('uint64', 0) = UInt64(High(Int64)),
        '52 desteklenen UInt64 kayipsiz gidis-donus');
    finally
      BosHedef.Free;
    end;

    Birinci.AddOrSet('fazla-buyuk', TValue.From<UInt64>(High(UInt64)));
    HataOlustu := False;
    try
      Birinci.FileSave(f);
    except
      on E: ESmartCacheJson do
        HataOlustu := True;
    end;
    Chk(HataOlustu, '53 JSON sinirini asan UInt64 acikca reddedildi');
  finally
    Birinci.Free;
  end;
end;

begin
  GOk := 0;
  GFail := 0;
  GKlasor := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'veri');
  TDirectory.CreateDirectory(GKlasor);

  { Beklenmeyen deadlock/regresyon test sürecini sonsuza kadar askıda
    bırakmasın diye sert süre sınırı. }
  TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(20000);
      Writeln;
      Writeln('  [BEKCI] 20 sn doldu - KILITLENME. Son tamamlanan iddia: ', GOk);
      Flush(Output);
      Halt(3);
    end).Start;

  try
    KaydetYukleGidisDonusu;
    JsonYukleme;
    TipSadakati;
    Diziler;
    YamlVeXml;
    TemizlemeVeBirlestirme;
    AbonelikKorunmasi;
    HataYollari;
    KaydetmeHataGuvenligi;
    EszamanliKaydetme;
    SinirDurumlari;
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
