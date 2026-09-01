program CacheDocProbe;

{$APPTYPE CONSOLE}

{
  SORU: TSmartCache'e TDocVariantData nasil konur?

  Bu bir SONDA, kalici test degil - amaci "bugun ne calisiyor"u olcmek ki
  tasarim onerisi tahmine degil olcume dayansin.

  FileLoad/LoadJson KULLANILMAZ: su an kilitleniyorlar (WriteLock icinden
  AddOrSet). Sonda yalnizca AddOrSet/Get yolunu olcer.
}

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  System.Variants,
  mormot.core.base,
  mormot.core.text,      // TTextWriterJsonFormat
  mormot.core.json,
  mormot.core.variants,
  rad.core  in '..\..\..\core\rad.core.pas',
  rad.cache in '..\..\..\core\rad.cache.pas';

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

const
  CJson = '{"aile":{"baba":"emrah","cocuk":{"sayisi":3}}}';

{ --- A) Variant olarak (TValue.FromVariant) ------------------------------- }

procedure VariantYolu;
var
  c  : TSmartCache;
  d  : TDocVariantData;
  v  : Variant;
  LV : TValue;
  LGeri: Variant;
begin
  Writeln;
  Writeln('=== A) TValue.FromVariant(variant(doc)) ===');
  c := TSmartCache.Create;
  try
    { Variant(d) KAYIT CAST'i gecersiz - EVariantTypeCastError verdi.
      mORMot'un kendi deyimi _Json(): dogrudan variant dondurur. }
    v := _Json(CJson);
    Writeln('    kaynak VarType = ', VarType(v), '  DocVariantVType = ', DocVariantVType);
    Flush(Output);

    { ADIM ADIM: hangi cagri patliyor? }
    try
      LV := TValue.FromVariant(v);
      Chk(False, 'A0a TValue.FromVariant DocVariant''i KABUL ETMEMELIYDI');
    except
      { BEKLENEN. RTL'nin FromVariant'i ozel variant tiplerini bilmiyor.
        SetDoc bu yuzden From<Variant> kullanir - bu iddia o kararin bekcisi. }
      on EVariantTypeCastError do
        Chk(True, 'A0a TValue.FromVariant DocVariant''i TASIYAMIYOR (beklenen)');
    end;

    try
      LV := TValue.From<Variant>(v);
      Chk(True, 'A0b TValue.From<Variant> kabul etti');
    except
      on E: Exception do
        Chk(False, 'A0b TValue.From<Variant> PATLADI -> ' + E.ClassName);
    end;

    try
      Chk(c.AddOrSet('cfg', TValue.From<Variant>(v)), 'A1 AddOrSet kabul etti');
    except
      on E: Exception do
        Chk(False, 'A1 AddOrSet PATLADI -> ' + E.ClassName + ': ' + E.Message);
    end;

    LV := c.GetValue('cfg', TValue.Empty);
    Writeln('    TValue.Kind = ', GetEnumName(TypeInfo(TTypeKind), Ord(LV.Kind)));
    Chk(LV.Kind = tkVariant, 'A2 tkVariant olarak saklandi');

    LGeri := LV.AsVariant;
    Chk(DocVariantType.IsOfType(LGeri), 'A3 geri okundugunda HALA DocVariant');
    Chk(_Safe(LGeri)^.Count = 1, 'A4 icerik korundu (1 ust anahtar)');
    Writeln('    geri: ', Utf8ToString(_Safe(LGeri)^.ToJson));

    { Ayni degeri IKINCI kez yazmak: ValuesEqual variant'i karsilastirabiliyor
      mu, yoksa patliyor/hep "degisti" mi diyor? }
    try
      Chk(c.AddOrSet('cfg', TValue.From<Variant>(v)),
        'A5 ayni degeri TEKRAR yazmak patlamadi (ValuesEqual DocVariant''i kaldirdi)');
    except
      on E: Exception do
        Chk(False, 'A5 ValuesEqual PATLADI -> ' + E.ClassName + ': ' + E.Message);
    end;

    { KOPYA MI PAYLASIM MI - SetDoc'un derin kopya yapmasi gerekip
      gerekmedigini bu belirler. Kaynak variant'a SONRADAN bir alan ekleyip
      saklanana yansiyor mu diye bakiyoruz.
      (Ilk hâlde burada baslatilmamis bir 'd' kaydi Clear ediliyordu; o test
       hicbir sey kanitlamiyordu - duzeltildi.) }
    _Safe(v)^.AddValue('sonradan', 1);
    LGeri := c.GetValue('cfg', TValue.Empty).AsVariant;
    Chk(not _Safe(LGeri)^.Exists('sonradan'),
      'A6 KOPYA semantigi: kaynaga sonradan eklenen saklanana YANSIMADI');
  finally
    c.Free;
  end;
end;

{ --- B) IDocDict olarak (mevcut IInterface asiri yuklemesi) --------------- }

procedure ArayuzYolu;
var
  c  : TSmartCache;
  dd : IDocDict;
  LGeri: IDocDict;
begin
  Writeln;
  Writeln('=== B) IDocDict (mevcut AddOrSet IInterface asiri yuklemesi) ===');
  c := TSmartCache.Create;
  try
    dd := DocDict(CJson);
    Chk(c.AddOrSet('cfg', dd), 'B1 AddOrSet(IInterface) kabul etti');

    LGeri := c.GetIntf<IDocDict>('cfg');
    Chk(Assigned(LGeri), 'B2 GetIntf<IDocDict> geri dondurdu');
    if Assigned(LGeri) then
    begin
      Writeln('    geri: ', Utf8ToString(LGeri.ToJson(TTextWriterJsonFormat.jsonCompact, [])));
      Chk(LGeri.Exists('aile'), 'B3 icerik korundu');

      { Arayuz PAYLASILIR: geri alinan referans uzerinden yazmak
        cache'tekini de degistirir mi? }
      LGeri.I['yeni'] := 7;
      Chk(c.GetIntf<IDocDict>('cfg').Exists('yeni'),
        'B4 PAYLASIMLI - disaridan yapilan degisiklik cache''e YANSIDI');
    end;
  finally
    c.Free;
  end;
end;

{ --- C) Ic ice yol erisimi cache uzerinden -------------------------------- }

procedure YolErisimi;
var
  c: TSmartCache;
  v: Variant;
begin
  Writeln;
  Writeln('=== C) Saklanan belgede yol erisimi ===');
  c := TSmartCache.Create;
  try
    c.AddOrSet('cfg', TValue.From<Variant>(_Json(CJson)));
    v := c.GetValue('cfg', TValue.Empty).AsVariant;
    Chk(_Safe(v)^.GetValueByPath('aile.cocuk.sayisi') = 3,
      'C1 saklanan belgede GetValueByPath calisiyor');
  finally
    c.Free;
  end;
end;

{ --- D) SetDoc / GetDoc ------------------------------------------------- }

procedure BelgeApi;
var
  c : TSmartCache;
  v : Variant;
  g : Variant;
begin
  Writeln;
  Writeln('=== D) SetDoc / GetDoc ===');
  c := TSmartCache.Create;
  try
    v := _Json(CJson);
    Chk(c.SetDoc('cfg', v), 'D1 SetDoc kabul etti');
    Chk(c.GetDoc('cfg', g), 'D2 GetDoc True dondu');
    Chk(DocVariantType.IsOfType(g), 'D3 geri gelen DocVariant');
    Chk(_Safe(g)^.GetValueByPath('aile.cocuk.sayisi') = 3,
      'D4 ic ice yapi ve yol erisimi korundu');

    { KOPYA semantigi: cagiranin elindekini degistirmek cache'i etkilemez. }
    _Safe(v)^.AddValue('sonradan', 1);
    Chk(c.GetDoc('cfg', g) and not _Safe(g)^.Exists('sonradan'),
      'D5 SetDoc KOPYA sakladi - kaynak degisikligi sizmadi');

    { Geri alinan kopyayi degistirmek de cache'i etkilememeli. }
    c.GetDoc('cfg', g);
    _Safe(g)^.AddValue('disaridan', 1);
    Chk(c.GetDoc('cfg', g) and not _Safe(g)^.Exists('disaridan'),
      'D6 GetDoc KOPYA dondurdu - ic belgeye isaretci SIZMADI');

    Chk(not c.GetDoc('yok', g), 'D7 olmayan anahtar -> False');

    c.AddOrSet('duz', 42);
    Chk(not c.GetDoc('duz', g), 'D8 belge OLMAYAN deger -> False');
  finally
    c.Free;
  end;
end;

{ --- E) SectionKeys ------------------------------------------------------ }

procedure BolumAnahtarlari;
var
  c : TSmartCache;
  k : TArray<string>;
  s : string;
begin
  Writeln;
  Writeln('=== E) SectionKeys ===');
  c := TSmartCache.Create;
  try
    c.FileLoad;   // dosya yok, onemli degil - elle dolduruyoruz
    c.AddOrSet('aile.baba', 'emrah');
    c.AddOrSet('aile.anne', 'Senay');
    c.AddOrSet('aile.cocuk.sayisi', 3);
    c.AddOrSet('db.host', 'localhost');

    k := c.SectionKeys('aile');
    s := string.Join('|', k);
    Writeln('    aile -> ', s);
    Chk(Length(k) = 3, 'E1 aile bolumunde 3 anahtar');
    Chk(s.Contains('baba') and s.Contains('cocuk.sayisi'),
      'E2 onek SOYULDU (baba, cocuk.sayisi)');
    Chk(not s.Contains('aile.'), 'E3 sonuclarda onek KALMADI');
    Chk(Length(c.SectionKeys('db')) = 1, 'E4 db bolumunde 1 anahtar');
    Chk(Length(c.SectionKeys('yok')) = 0, 'E5 olmayan bolum -> bos');
    Chk(Length(c.SectionKeys('')) = c.Count, 'E6 bos bolum -> TUM anahtarlar');
  finally
    c.Free;
  end;
end;

{ --- F) Silinen anahtar bildirimi ---------------------------------------- }

procedure SilinenBildirimi;
var
  c        : TSmartCache;
  LSilindi : Boolean;
  LYeniDeger: Boolean;
begin
  Writeln;
  Writeln('=== F) AClearFirst ile silinen anahtar bildiriliyor mu ===');
  LSilindi   := False;
  LYeniDeger := False;

  c := TSmartCache.Create;
  try
    c.AddOrSet('gidecek', 1);
    c.AddOrSet('kalacak', 2);

    c.RegisterEvent('gidecek',
      function(AKey: string; AOld, ANew: TValue): Boolean
      begin
        { ANew boş = anahtar artık yok }
        if ANew.IsEmpty then
          LSilindi := True
        else
          LYeniDeger := True;
        Result := True;
      end);

    { Yeni belgede 'gidecek' YOK - silinmeli ve abone haberdar olmali. }
    c.LoadJson('{"kalacak":9}', True);

    Chk(not c.ContainsKey('gidecek'), 'F1 anahtar gercekten silindi');
    Chk(c.Get<Int64>('kalacak', 0) = 9, 'F2 yeni deger yuklendi');
    Chk(LSilindi, 'F3 SILINME abone tarafindan DUYULDU (eski hâlde sessizdi)');
    Chk(not LYeniDeger, 'F4 silinen anahtar icin yeni-deger olayi tetiklenmedi');
  finally
    c.Free;
  end;
end;

begin
  GOk := 0;
  GFail := 0;

  TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(20000);
      Writeln;
      Writeln('  [BEKCI] 20 sn - takilma. Tamamlanan: ', GOk);
      Flush(Output);
      Halt(3);
    end).Start;

  try
    VariantYolu;
    ArayuzYolu;
    YolErisimi;
    BelgeApi;
    BolumAnahtarlari;
    SilinenBildirimi;
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
