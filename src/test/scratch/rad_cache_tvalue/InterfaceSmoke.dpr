program InterfaceSmoke;

{ ISmartCache + TSmartCacheView + NewSmartCache duman testi.
  Kontroller: ARC yaşam süresi (Free yok), interface üzerinden temel API,
  view üzerinden generic okuma (Get<T>/TryGet<T>/GetIntf<T>), factory GetOrAdd.
  Başarı = tüm kontroller OK, exit 0; herhangi bir hata exit 1. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  rad.cache in '..\..\..\core\rad.cache.pas';

type
  IDumanArayuzu = interface
    ['{B3A0D3E1-52D7-4E7B-93F4-6C7A0B1C2D3E}']
    function Deger: Integer;
  end;

  TDumanImpl = class(TInterfacedObject, IDumanArayuzu)
    function Deger: Integer;
  end;

function TDumanImpl.Deger: Integer;
begin
  Result := 314;
end;

var
  HataSayisi: Integer = 0;

procedure Kontrol(const AKosul: Boolean; const AMesaj: string);
begin
  if AKosul then
    Writeln('  OK   : ', AMesaj)
  else
  begin
    Writeln('  HATA : ', AMesaj);
    Inc(HataSayisi);
  end;
end;

procedure Kos;
var
  Cache: ISmartCache;
  View: TSmartCacheView;
  Liste: TStringList;
  Impl: IDumanArayuzu;
  Tam: Integer;
begin
  Cache := NewSmartCache; // ARC — Free yok

  Kontrol(Cache.AddOrSet('sayi', 10), 'interface üzerinden AddOrSet');
  Kontrol(Cache.Get('sayi', 0) = 10, 'interface üzerinden Get(Integer)');
  Kontrol(Cache.AddOrSet('metin', 'abc') and (Cache.Get('metin', '') = 'abc'),
    'interface üzerinden string gidiş-dönüşü');

  View := Cache; // implicit dönüşüm

  Liste := TStringList.Create;
  try
    Liste.Add('x');
    Cache.AddOrSet('liste', Liste);
    Kontrol(View.Get<TStringList>('liste', nil) = Liste, 'View.Get<TStringList> aynı referans');
    Kontrol(View.Get<TStringStream>('liste', nil) = nil, 'View.Get yanlış sınıfta nil');
  finally
    Liste.Free;
  end;

  Kontrol(View.TryGet<Integer>('sayi', Tam) and (Tam = 10), 'View.TryGet<Integer> başarılı yol');
  Kontrol(not View.TryGet<Integer>('metin', Tam), 'View.TryGet<Integer> tip uyuşmazlığında False');

  Impl := TDumanImpl.Create;
  Cache.AddOrSet('aryz', IInterface(Impl));
  Kontrol(Assigned(View.GetIntf<IDumanArayuzu>('aryz')) and
          (View.GetIntf<IDumanArayuzu>('aryz').Deger = 314), 'View.GetIntf<T> GUID sorgusu');

  Kontrol(Cache.GetOrAdd('tembel', function: TValue begin Result := 7 end).AsInteger = 7,
    'interface üzerinden factory GetOrAdd');

  Kontrol(Length(Cache.Keys) = 5, 'Keys sayısı (5 anahtar)');

  Cache := nil; // ARC serbest bırakır — çökme/AV olmamalı
  Kontrol(True, 'ISmartCache := nil (ARC yıkımı) sorunsuz');
end;

begin
  try
    Kos;
    if HataSayisi = 0 then
      Writeln('SONUC: TUM KONTROLLER GECTI')
    else
    begin
      Writeln('SONUC: ', HataSayisi, ' KONTROL BASARISIZ');
      ExitCode := 1;
    end;
  except
    on E: Exception do
    begin
      Writeln('EXCEPTION: ', E.ClassName, ': ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
