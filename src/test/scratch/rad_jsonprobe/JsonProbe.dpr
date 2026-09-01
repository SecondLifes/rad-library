program JsonProbe;

{$APPTYPE CONSOLE}

{
  Aşama 2 ÖLÇÜMÜ - kod yazmadan önce.

  Üç soru, üçü de tasarımı belirliyor:
    1. SetVar(key, docVariant) ALT BELGE olarak mı yerleşiyor, opak skaler mi?
       -> AddVar'in birlestirme yolunu bu belirler.
    2. MergeObject DERIN mi, AddOrUpdateObject SIG mi? (prose oyle diyor;
       prose bu oturumda bir kez YALAN CIKTI - Flatten'in sayac vaadi)
    3. Duzlestirilmis belge nasil gorunuyor -> Unflatten neyi geri kurmali,
       ve cakismada (hem 'a' skaler hem 'a.b') ne yapmali?
}

uses
  System.SysUtils,
  System.Variants,
  mormot.core.base,
  mormot.core.text,
  mormot.core.json,
  mormot.core.variants,
  help.mormot in '..\..\..\core\help.mormot.pas';

procedure Yaz(const ABaslik, AJson: string);
begin
  Writeln('    ', ABaslik, ': ', AJson);
  Flush(Output);
end;

{ --- 1) SetItem bir DocVariant'i nasil yerlestiriyor ---------------------- }

procedure SetItemDavranisi;
var
  d, alt: TDocVariantData;
  v: Variant;
begin
  Writeln;
  Writeln('=== 1) SetItem(key, DocVariant) ===');
  d.InitJson('{"kok":1}', JSON_FAST);
  alt.InitJson('{"x":10,"y":20}', JSON_FAST);
  v := Variant(alt);

  d.AddOrUpdateValue('db', v);
  Yaz('sonuc', Utf8ToString(d.ToJson));
  Writeln('    db bir NESNE mi: ',
    BoolToStr(_Safe(d.GetValueByPath('db'))^.Kind = dvObject, True));
  Writeln('    db.x yol ile okunuyor mu: ', VarToStr(d.GetValueByPath('db.x')));
  Flush(Output);
end;

{ --- 2) MergeObject vs AddOrUpdateObject --------------------------------- }

procedure MergeDavranisi;
var
  a, b: TDocVariantData;
begin
  Writeln;
  Writeln('=== 2) DERIN mi SIG mi ===');
  Writeln('    taban : {"db":{"host":"eski","port":1},"log":1}');
  Writeln('    ezme  : {"db":{"host":"yeni"}}');

  { MergeObject }
  a.InitJson('{"db":{"host":"eski","port":1},"log":1}', JSON_FAST);
  b.InitJson('{"db":{"host":"yeni"}}', JSON_FAST);
  a.MergeObject(Variant(b));
  Yaz('MergeObject      ', Utf8ToString(a.ToJson));
  Writeln('    -> port KORUNDU mu (derin): ',
    BoolToStr(not VarIsEmpty(a.GetValueByPath('db.port')), True));

  { AddOrUpdateObject }
  a.InitJson('{"db":{"host":"eski","port":1},"log":1}', JSON_FAST);
  b.InitJson('{"db":{"host":"yeni"}}', JSON_FAST);
  a.AddOrUpdateObject(Variant(b));
  Yaz('AddOrUpdateObject', Utf8ToString(a.ToJson));
  Writeln('    -> port KORUNDU mu: ',
    BoolToStr(not VarIsEmpty(a.GetValueByPath('db.port')), True));

  { AddOrUpdateObject + RecursiveUpdate }
  a.InitJson('{"db":{"host":"eski","port":1},"log":1}', JSON_FAST);
  b.InitJson('{"db":{"host":"yeni"}}', JSON_FAST);
  a.AddOrUpdateObject(Variant(b), False, True);
  Yaz('AddOrUpdate+Rec  ', Utf8ToString(a.ToJson));
  Writeln('    -> port KORUNDU mu: ',
    BoolToStr(not VarIsEmpty(a.GetValueByPath('db.port')), True));
  Flush(Output);
end;

{ --- 3) Unflatten neyi geri kurmali -------------------------------------- }

procedure UnflattenGirdisi;
var
  d: TDocVariantData;
begin
  Writeln;
  Writeln('=== 3) Duzlestirilmis belge (Unflatten''in girdisi) ===');
  d.InitJson('{"aile":{"baba":"emrah","cocuk":{"sayisi":3}},"renk":["a","b"]}',
    JSON_FAST);
  TMormot.Flatten(d, fcOverwrite, '.', 0);
  Yaz('duz', Utf8ToString(d.ToJson));
  Writeln('    -> Unflatten bunu ozgun hâline dondurebilmeli.');
  Writeln('    -> DIKKAT: renk.0/renk.1 bir DIZI miydi yoksa "0","1" adli');
  Writeln('       anahtarlari olan bir NESNE mi? Duz belgede bu BILGI YOK.');

  Writeln;
  Writeln('=== 3b) Unflatten CAKISMASI ===');
  Writeln('    girdi: {"a":5,"a.b":1}  -> "a" hem SKALER hem KAP olamaz.');
  Writeln('    Karar gerekiyor: istisna mi, skaleri mi ez, a.b''yi mi atla?');
  Flush(Output);
end;

begin
  try
    SetItemDavranisi;
    MergeDavranisi;
    UnflattenGirdisi;
  except
    on E: Exception do
      Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
  end;
  Writeln;
  Writeln('--- olcum bitti ---');
end.
