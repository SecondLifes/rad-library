program JsonFlattenTest;

{$APPTYPE CONSOLE}

{
  help.json._Flatten sondasi.

  Altta mORMot'un TDocVariantData.FlattenFromNestedObjects'i var; helper onun
  uzerine uc sey ekliyor: tum seviyeleri donen dongu + sonsuz dongu sigortasi,
  cakisma tespiti, ve IDocDict asiri yuklemesi.
}

uses
  System.SysUtils,
  System.Variants,      // VarIsEmptyOrNull
  mormot.core.base,
  mormot.core.text,
  mormot.core.json,
  mormot.core.variants,
  help.mormot in '..\..\..\core\help.mormot.pas';

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
  CKaynak = '{"aile":{"baba":"emrah","anne":"Senay","cocuk":{"sayisi":3}}}';

procedure TemelDurum;
var
  d: TDocVariantData;
  LTur: Integer;
begin
  Writeln;
  Writeln('=== 1) Kullanicinin ornegi ===');
  d.InitJson(CKaynak, JSON_FAST);

  LTur := TMormot.Flatten(d);
  Writeln('  tur=', LTur, '  sonuc=', Utf8ToString(d.ToJson));

  Chk(d.Exists('aile.baba'),         '01 aile.baba');
  Chk(d.Exists('aile.anne'),         '02 aile.anne');
  Chk(d.Exists('aile.cocuk.sayisi'), '03 aile.cocuk.sayisi (IC ICE seviye)');
  Chk(not d.Exists('aile'),          '04 orijinal nesne kalmadi (YIKICI islem)');
  Chk(d.Count = 3,                   '05 tam 3 anahtar');
  Chk(LTur = 2,                      Format('06 iki tur (tur=%d)', [LTur]));
end;

procedure DerinIcIce;
var
  d: TDocVariantData;
begin
  Writeln;
  Writeln('=== 2) 4 seviye derinlik ===');
  d.InitJson('{"a":{"b":{"c":{"d":42}}}}', JSON_FAST);
  Writeln('  tur=', TMormot.Flatten(d), '  sonuc=', Utf8ToString(d.ToJson));
  Chk(d.Exists('a.b.c.d'), '07 a.b.c.d');
  Chk(d.Count = 1,         '08 tek anahtar');
end;

procedure BosIcNesne;
var
  d: TDocVariantData;
begin
  Writeln;
  Writeln('=== 3) BOS ic nesne (sonlanma) ===');
  d.InitJson('{"a":{"bos":{},"dolu":1}}', JSON_FAST);
  Writeln('  tur=', TMormot.Flatten(d), '  sonuc=', Utf8ToString(d.ToJson));
  Chk(True,               '09 sonsuz donguye girmedi');
  Chk(d.Exists('a.dolu'), '10 komsu alan duzlesti');
end;

procedure Diziler;
var
  d1, d2: TDocVariantData;
begin
  Writeln;
  Writeln('=== 4) Diziler ===');
  d1.InitJson('{"arr":["a","b"],"x":{"y":1}}', JSON_FAST);
  TMormot.Flatten(d1);
  Writeln('  -1 ile: ', Utf8ToString(d1.ToJson));
  Chk(d1.Exists('arr'), '11 varsayilanda dizi OLDUGU GIBI');
  Chk(d1.Exists('x.y'), '12 nesneler yine duzlesir');

  d2.InitJson('{"arr":["a","b"],"x":{"y":1}}', JSON_FAST);
  TMormot.Flatten(d2, fcRaise, '.', 0);
  Writeln('   0 ile: ', Utf8ToString(d2.ToJson));
  Chk(d2.Exists('arr.0'), '13 arr.0');
  Chk(d2.Exists('arr.1'), '14 arr.1');
end;

procedure CakismaRaise;
var
  d: TDocVariantData;
begin
  Writeln;
  Writeln('=== 5) Cakisma: varsayilan fcRaise ===');
  d.InitJson('{"a":{"b":1},"a.b":2}', JSON_FAST);
  try
    TMormot.Flatten(d);
    Chk(False, '15 cakismada EMormotFlatten atmaliydi');
  except
    on E: EMormotFlatten do
    begin
      Writeln('  mesaj: ', E.Message);
      Chk(True, '15 cakisma SESSIZ gecilmedi -> EMormotFlatten');
      Chk(Pos('a.b', E.Message) > 0, '16 mesaj cakisan anahtari SOYLUYOR');
    end;
  end;
end;

procedure CakismaRename;
var
  d: TDocVariantData;
  i: Integer;
begin
  Writeln;
  Writeln('=== 6) Cakisma: fcRename ===');
  d.InitJson('{"a":{"b":1},"a.b":2}', JSON_FAST);
  TMormot.Flatten(d, fcRename);
  Writeln('  sonuc=', Utf8ToString(d.ToJson));
  for i := 0 to d.Count - 1 do
    Writeln('    ', Utf8ToString(d.Names[i]), ' = ', Utf8ToString(d.Values[i]));

  Chk(d.Count = 2,                            '17 iki deger de duruyor');
  Chk(Length(TMormot.DuplicateKeys(d)) = 0,          '18 tekrar KALMADI');
  Chk(d.Exists('a.b') and d.Exists('a.b_2'),  '19 ikincisi a.b_2 oldu');
end;

procedure RenameZatenDoluYuva;
var
  d: TDocVariantData;
  LIdx: Integer;
begin
  Writeln;
  Writeln('=== 7) fcRename: uretilen ad ZATEN kullaniliyorsa ===');
  { a.b iki kez olusacak; ilk aday a.b_2 ama o da belgede mevcut. }
  d.InitJson('{"a":{"b":1},"a.b":2,"a.b_2":3}', JSON_FAST);
  TMormot.Flatten(d, fcRename);
  Writeln('  sonuc=', Utf8ToString(d.ToJson));

  Chk(d.Count = 3,                   '20 uc deger de korundu');
  Chk(Length(TMormot.DuplicateKeys(d)) = 0, '21 tekrar yok (dolu yuva atlandi)');

  { MEVCUT anahtar korunmali: a.b_2 kullanicinin gercek anahtari, ona
    dokunulmamali. Yeni gelen bir sonraki bos yuvaya (a.b_3) gitmeli.

    DIKKAT - burada GetValueByPath KULLANILMAZ. Duzlestirmeden sonra "a.b_2"
    LITERAL bir anahtar adidir, yol degil; GetValueByPath onu "a" nesnesi
    icinde "b_2" diye arar ve bulamaz. Ad ile aramak icin GetValueIndex. }
  LIdx := d.GetValueIndex('a.b_2');
  Chk((LIdx >= 0) and (d.Values[LIdx] = 3),
    '22 kullanicinin MEVCUT a.b_2 anahtari adini ve degerini korudu');
  Chk(d.Exists('a.b_3'),
    '23 yeni gelen bir SONRAKI bos yuvaya gitti (a.b_3)');
end;

procedure CakismaOverwrite;
var
  d: TDocVariantData;
  LIdx: Integer;
begin
  Writeln;
  Writeln('=== 7c) Cakisma: fcOverwrite ===');
  d.InitJson('{"a":{"b":1},"a.b":2}', JSON_FAST);
  TMormot.Flatten(d, fcOverwrite);
  Writeln('  sonuc=', Utf8ToString(d.ToJson));

  Chk(d.Count = 1, '27 tek anahtar kaldi (bir deger KAYBOLDU - bilincli)');
  Chk(Length(TMormot.DuplicateKeys(d)) = 0, '28 tekrar yok');

  { SONRAKI kazanir: ic ice a.b (1) once, duz a.b (2) sonra geliyor. }
  LIdx := d.GetValueIndex('a.b');
  Chk((LIdx >= 0) and (d.Values[LIdx] = 2),
    '29 SON deger kazandi (2), ilki (1) ezildi');
end;

procedure OverwriteKonumKorur;
var
  d: TDocVariantData;
begin
  Writeln;
  Writeln('=== 7d) fcOverwrite anahtarin KONUMUNU korur ===');
  { z once geliyor; a.b cakismasi z'yi one/arkaya itmemeli. }
  d.InitJson('{"z":9,"a":{"b":1},"a.b":2}', JSON_FAST);
  TMormot.Flatten(d, fcOverwrite);
  Writeln('  sonuc=', Utf8ToString(d.ToJson));

  Chk(d.Count = 2, '30 iki anahtar');
  Chk(Utf8ToString(d.Names[0]) = 'z',
    '31 z ILK konumunu korudu (ezme sirayi bozmadi)');
end;

procedure YolErisimiArtikCalismaz;
var
  d: TDocVariantData;
begin
  Writeln;
  Writeln('=== 7b) Duzlestirmenin BEDELI: yol erisimi biter ===');
  d.InitJson(CKaynak, JSON_FAST);

  Chk(d.GetValueByPath('aile.cocuk.sayisi') = 3,
    '32 duzlestirmeden ONCE yol erisimi calisiyor');

  TMormot.Flatten(d);

  { Anahtar artik "aile.cocuk.sayisi" adinda TEK parca bir isim. Yol arayan
    kod "aile" nesnesini arar, bulamaz. Duz belge isteyen herkesin bilmesi
    gereken takas budur. }
  Chk(VarIsEmptyOrNull(d.GetValueByPath('aile.cocuk.sayisi')),
    '33 duzlestirmeden SONRA yol erisimi BOS doner');
  Chk(d.Exists('aile.cocuk.sayisi'),
    '34 ama ad ile erisim calisir (Exists / GetValueIndex)');
end;

procedure IDocDictYolu;
var
  dd: IDocDict;
begin
  Writeln;
  Writeln('=== 8) IDocDict asiri yuklemesi ===');
  dd := DocDict(CKaynak);
  { IDocDict.ToJson TDocVariantData'ninkinden FARKLI imzali - bicim ve ek
    parametre ister (Permission.Edit.pas'taki kullanimla ayni). }
  Writeln('  tur=', TMormot.Flatten(dd), '  sonuc=',
    Utf8ToString(dd.ToJson(TTextWriterJsonFormat.jsonCompact, [])));
  Chk(dd.Exists('aile.cocuk.sayisi'), '35 IDocDict uzerinden de duzlesti');

  try
    TMormot.Flatten(IDocDict(nil));
    Chk(False, '36 nil belge -> EMormotFlatten');
  except
    on E: EMormotFlatten do Chk(True, '36 nil belge -> EMormotFlatten');
  end;
end;

procedure DuplicateKeysIslevi;
var
  d: TDocVariantData;
begin
  Writeln;
  Writeln('=== 9) _DuplicateKeys ===');
  d.InitJson('{"x":1,"y":2}', JSON_FAST);
  Chk(Length(TMormot.DuplicateKeys(d)) = 0, '37 temiz belgede bos dizi');
end;

begin
  GOk := 0;
  GFail := 0;
  try
    TemelDurum;
    DerinIcIce;
    BosIcNesne;
    Diziler;
    CakismaRaise;
    CakismaRename;
    RenameZatenDoluYuva;
    CakismaOverwrite;
    OverwriteKonumKorur;
    YolErisimiArtikCalismaz;
    IDocDictYolu;
    DuplicateKeysIslevi;
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
