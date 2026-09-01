unit help.mormot;


{$REGION 'Açıklama'}


(*
  mORMot2 icin yardimci islevler.

  ADLANDIRMA VE YAPI (kit kurali - helper-patterns.md, "Vendor yardimci
  birimleri"):
    * Dosya adi vendor basinadir: help.{vendor}.pas
      (help.uni.pas -> UniDAC, help.mormot.pas -> mORMot2)
    * Once CLASS/RECORD HELPER denenir.
    * Helper yazilamiyorsa vendor takma adiyla bir sinif acilir ve uyeler
      STATIC olur.

  BURADA NEDEN HELPER DEGIL DE TMormot:
    Islevlerin hedefi iki farkli tip - TDocVariantData (record) ve IDocDict
    (interface). Record icin helper yazilabilir, ama Delphi ARAYUZLER icin
    helper'i DESTEKLEMEZ. Tek bir helper ikisini birden kapsayamayacagi icin
    API iki ayri bicime bolunurdu. Ikinci gerekce: bir tip icin yalnizca EN
    YAKIN helper gorunur; TDocVariantData'ya helper eklemek, ileride mORMot
    kendi helper'ini eklerse onu sessizce gizlerdi (bugun yok - arandi,
    dogrulandi). Bu yuzden static sinif tercih edildi.

  DIKKAT - yorum ayraci: bu blok bilincli olarak yildizli-parantez bicimindedir.
  Asagida JSON ornekleri var ve suslu-parantez bicimli bir yorum, ornekteki ilk
  kapanis susu gordugu yerde BITER (E2029 + E2038). Ayni tuzak rad.json.pas'ta
  bizzat yasandi; ayrinti icin delphi-conventions.md.



(*
  ===========================================================================
  TTextWriterWriteObjectOption  —  ObjectToJson / WriteObject ayarlari
  ---------------------------------------------------------------------------
  Kaynak : mormot.core.text.pas (enum), mormot.core.json.pas (hazir kumeler)
  Durum  : asagidaki ciktilarin cogu OLCULDU (Delphi 37.0 Win32); olculmeyenler
           "[olculmedi]" ile isaretli.
  ===========================================================================

  A) NEYIN YAZILIP NEYIN ATLANACAGI  —  "bazi alanlar gelmiyor"un sebebi burasi
  ---------------------------------------------------------------------------
  woDontStoreDefault      default direktifine ESIT degerdeki property'yi ATLAR.
                          ObjectToJson'in VARSAYILANIDIR - hicbir sey yazmasan
                          bile aciktir.
                            [woDontStoreDefault] -> {"Normal":"deger"}
                            []                   -> {"Normal":"deger","Varsayilanli":5}

  woDontStoreVoid         Sayisal 0 ve bos string '' olanlari atlar.
                            -> {"Normal":"deger","Renk":2}   BosMetin ve Sifir dustu

  woStoreStoredFalse      'stored False' isaretli property'leri YINE DE yazar
                          (sartli 'stored <metot>' dahil). Ayar dosyasi kaydinda
                          sarttir; log'a yazarken bilerek kapali birakilir.
                            -> {"StoredFalse":"gizli","SaklamaKosullu":"kosullu"}

  woDontStoreInherited    Yalnizca EN ALT sinifin kendi published property'leri;
                          atadan gelenler yazilmaz.
                            []                     -> {"AtadaPublished":"x","Kind":3}
                            [woDontStoreInherited] -> {"Kind":3}

  B) INSAN GOZU ICIN BICIM
  ---------------------------------------------------------------------------
  woHumanReadable                  Satir sonu + tab girintisi ekler.

  woEnumSetsAsText                 Enum ve set'leri SAYI yerine METIN yazar.
                                     Renkler:7 -> Renkler:["rKirmizi","rYesil","rMavi"]
                                   Ayar dosyasinda onemli: vendor enum'a yeni
                                   deger eklerse ordinal kayar, metin kaymaz.

  woHumanReadableFullSetsAsStar    Set'in TAMAMI doluysa ["*"] yazar.

  woHumanReadableEnumSetAsComment  Satir sonuna olasi degerleri yorum olarak ekler:
                                     "Renk": "rMavi" // rKirmizi/rYesil/rMavi

  C) TESHIS / HATA AYIKLAMA  —  ayar dosyasinda KULLANMA
  ---------------------------------------------------------------------------
  woStoreClassName        Basa "ClassName":"TDeneme" ekler. Geri okurken dogru
                          sinifi uretmek icin de kullanilir.

  woStorePointer          "Address":"018d3750" ekler; ic ice nesnelere de.

  woFullExpand            Hata ayiklayici duzeni: sinif adi + adres SARMALAYICI
                          ANAHTAR olur, enum'lar metne cevrilir.
                            {"TDeneme(018d3750)":{"Renkler":["rKirmizi","rYesil"],
                              "Ic":{"TIcNesne(018a0f00)":{"Ad":"ic-nesne"}}}}
                          TSynLog ve ObjectToJsonFull bunu kullanir.

  D) TIP BICIMLERI
  ---------------------------------------------------------------------------
  woDateTimeWithZSuffix        ISO-8601 sonuna Z ekler (deger UTC demektir).
                                 "2026-08-26T14:30:00" -> "2026-08-26T14:30:00Z"

  woDateTimeNullAsVoidString   TDateTime = 0 icin null yerine "" yazar.
                                 "BosTarih":null -> "BosTarih":""

  woDateTimeWithMagic          ISO metnin basina U+FFF1 sihirli karakteri koyar;
                               mORMot katmanlari bunu "bu bir tarih" isareti
                               olarak tanir. DIS DUNYAYA giden JSON'da kullanma.
                               [olculmedi]

  woTimeLogAsText              TTimeLog (sikistirilmis Int64 tarih) sayi yerine
                               okunabilir tarih olur.
                                 "Zaman":135995254656 -> "Zaman":"2026-08-26T14:30:00"

  woInt64AsHex                 Int64/QWord onaltilik METIN olur. JavaScript'in
                               53-bit sinirini asan sayilarda kayip olmasin diye.
                                 305419896 -> "0000000012345678"

  woIDAsIDstr                  TOrm.ID icin ek "ID_str":"..." alani yazar; ayni
                               53-bit sinir icin. ORM'e ozgu. [olculmedi]

  woRawBlobAsBase64            RawBlob varsayilan olarak null yazilir; bu ayarla
                               base64 olur.
                                 "Veri":null -> "Veri":"aWtpbGktdmVyaQ=="

  woRawByteStringAsBase64Magic RawByteString icin ayni is, basina sihirli isaret
                               koyarak. [olculmedi]

  E) GUVENLIK
  ---------------------------------------------------------------------------
  woHideSensitivePersonalInformation
                          rcfSpi isaretli tipleri (orn. TObjectWithPassword.
                          Password) "***" yazar. Nesneyi log'a dokerken.
                          [olculmedi - rcfSpi kaydi gerektiriyor]

  F) DIGER
  ---------------------------------------------------------------------------
  woObjectListWontStoreClassName
                          TObjectList varsayilan olarak eleman basina ClassName
                          yazar; bu ayar onu KAPATIR.

  woRttiMethodsLock       Serilestirme boyunca TSynLockedWithRttiMethods
                          Lock/Unlock cagirir. Kaynaktaki tanimi: "paranoid".

  ---------------------------------------------------------------------------
  HAZIR KUMELER  (mormot.core.json.pas)
  ---------------------------------------------------------------------------
  DEFAULT_WRITEOPTIONS[False] = [woDontStoreDefault, woRawBlobAsBase64]
  DEFAULT_WRITEOPTIONS[True]  = [woDontStoreDefault, woDontStoreVoid,
                                 woRawBlobAsBase64]
  SETTINGS_WRITEOPTIONS       = [woHumanReadable, woStoreStoredFalse,
                                 woHumanReadableFullSetsAsStar,
                                 woHumanReadableEnumSetAsComment, woInt64AsHex]
  SERVICELOG_WRITEOPTIONS     = [woDontStoreDefault, woDontStoreVoid,
                                 woHideSensitivePersonalInformation]

  ---------------------------------------------------------------------------
  PRATIK SECIM
  ---------------------------------------------------------------------------
  Ayar dosyasi (hicbir sey kaybolmasin)
      [woHumanReadable, woStoreStoredFalse, woEnumSetsAsText]
  Ag / API (kucuk olsun)
      [woDontStoreDefault, woDontStoreVoid]
  Log / hata ayiklama
      [woFullExpand]   ya da   SERVICELOG_WRITEOPTIONS
  Yalnizca alt sinifin kendi alanlari
      + woDontStoreInherited

  UYARI: ayar dosyasinda woDontStoreDefault ve woDontStoreVoid'den UZAK DUR.
  Kullanici bir degeri varsayilana cekince satir dosyadan kaybolur ve
  "ayarim silindi" der.

  BIR ALAN HIC GELMIYORSA sirasiyla kontrol et:
    1. Property published mi?  public/protected/private HICBIR ayarla gelmez.
    2. default direktifi var ve deger ona esit mi?  woDontStoreDefault duserir.
    3. stored False mi?  woStoreStoredFalse gerekir.
    4. woDontStoreVoid acik mi?  0 ve '' duser.
    5. Sinifin published RTTI'si var mi?  M+ yoksa ve TPersistent soyundan
       degilse published bolum RTTI uretmez.
*)




{$ENDREGION}




interface

uses
  System.SysUtils,
  System.Generics.Collections,
  mormot.core.base,
  mormot.core.data,      // TDocVariantOptions - mormot.core.variants'ta DEGIL
  mormot.core.fmt,       // YamlToJson / XmlToJson / JsonToYaml / JsonToXml
  mormot.core.variants;

type
  /// <summary>Duzlestirme sirasinda olusan hatalar.</summary>
  /// <remarks>
  ///   Adi bilerek rad.json'un EJsonFlatten'inden FARKLIDIR. Eskiden ikisi de
  ///   EJsonFlatten adini tasiyordu: iki birimi birden uses'a alan bir cagirici
  ///   icin `on E: EJsonFlatten` uses SIRASINA gore farkli bir tipi yakaliyor,
  ///   derleyici hicbir sey soylemiyordu. rad.json bu tipi yakalar ve kendi
  ///   EJson agacindaki EJsonFlatten'a cevirir.
  /// </remarks>
  EMormotFlatten = class(Exception);

  /// <summary>
  ///   Duzlestirme sonunda AYNI anahtar birden fazla kez olustugunda ne
  ///   yapilacagi.
  /// </summary>
  TFlattenCollision = (
    /// <summary>
    ///   VARSAYILAN. EMormotFlatten atar ve cakisan anahtarlari mesajda sayar.
    ///   Hicbir deger kaybolmaz.
    /// </summary>
    fcRaise,
    /// <summary>
    ///   Ikinci ve sonraki tekrarlara _2, _3 ... eki verir. Hicbir deger
    ///   kaybolmaz; mevcut anahtarlarin adlari da korunur.
    /// </summary>
    fcRename,
    /// <summary>
    ///   SONRAKI deger oncekini EZER - sozluk atamasi gibi. Anahtar ILK
    ///   gorundugu KONUMDA kalir, yalnizca degeri degisir.
    ///   DIKKAT: tek DEGER KAYBEDEN mod budur, ve sessizce kaybeder.
    /// </summary>
    fcOverwrite
  );

  /// <summary>mORMot2 yardimcilari. Ornek uretilmez; tum uyeler static.</summary>
  TMormot = class
  public
    /// <summary>
    ///   Ic ice JSON nesnesini TEK SEVIYE, noktali anahtarli bir belgeye
    ///   donusturur. Yerinde calisir.
    /// </summary>
    /// <remarks>
    ///   Girdi:  bir "aile" nesnesi icinde baba/anne ve bir "cocuk" alt nesnesi
    ///   Cikti:  aile.baba, aile.anne, aile.cocuk.sayisi anahtarlari
    ///
    ///   YIKICI ISLEMDIR: alt nesneler kaybolur, artik bir alt agaci butun
    ///   olarak alamazsiniz. Ayrica noktali anahtar artik TEK PARCA BIR ADDIR,
    ///   yol degil - GetValueByPath duzlestirmeden sonra bos doner; erisim
    ///   Exists / GetValueIndex ile yapilir. Amaciniz yalnizca noktali yolla
    ///   DEGER OKUMAKSA duzlestirmeyin: GetValueByPath ic ice yapida zaten
    ///   calisir ve belgeyi bozmaz.
    ///
    ///   Diziler varsayilan olarak OLDUGU GIBI kalir. AArrayStartIndex=0
    ///   verilirse eleman basina indeksli anahtar uretilir (arr.0, arr.1).
    ///
    ///   Donen deger: kac tur donuldugu (her tur bir seviye). Tanilama icindir.
    /// </remarks>
    class function Flatten(var ADoc: TDocVariantData;
      const ACollision: TFlattenCollision = fcRaise;
      const ASep: AnsiChar = '.';
      const AArrayStartIndex: PtrInt = -1): Integer; overload; static;

    /// <summary>IDocDict uzerinden ayni islem.</summary>
    class function Flatten(const ADoc: IDocDict;
      const ACollision: TFlattenCollision = fcRaise;
      const ASep: AnsiChar = '.';
      const AArrayStartIndex: PtrInt = -1): Integer; overload; static;

    /// <summary>
    ///   Belgede birden fazla kez gecen anahtarlari dondurur (her biri BIR kez
    ///   listelenir). Bos dizi = cakisma yok.
    /// </summary>
    class function DuplicateKeys(const ADoc: TDocVariantData): TRawUtf8DynArray; static;

    (* ── Bicim donusumleri ────────────────────────────────────────────────
       YAML/XML <-> JSON. mORMot'un mormot.core.fmt yordamlarina koprudur;
       burada yeni ayristirici YAZILMAZ.

       UTF-8 BOM ATILIR (olculdu - rad.cache'te bu tam olarak sessiz BOS
       YUKLEME uretiyordu: JSON yolunda ayristirici bos nesne donuyor, YAML
       yolunda BOM anahtarin ADINA yapisiyordu). *)

    /// <summary>YAML metnini JSON'a cevirir.</summary>
    class function YamlToJsonText(const AYaml: RawByteString): RawUtf8; static;
    /// <summary>XML metnini JSON'a cevirir.</summary>
    class function XmlToJsonText(const AXml: RawByteString): RawUtf8; static;
    /// <summary>JSON'u YAML'a cevirir.</summary>
    class function JsonToYamlText(const AJson: RawUtf8): RawUtf8; static;
    /// <summary>JSON'u XML'e cevirir.</summary>
    class function JsonToXmlText(const AJson: RawUtf8): RawUtf8; static;
    /// <summary>Bastaki UTF-8 BOM'u (EF BB BF) varsa atar.</summary>
    class function StripBom(const AText: RawByteString): RawByteString; static;
  end;

    TDocVariantDataHelp = record helper for TDocVariantData
   function _RecordLoad<T>(const aKey: string; var ARec: T): Boolean;
   function _RecordSave<T>(const aKey: string; var ARec: T): Boolean;
  end;

implementation

uses
  mormot.core.unicode;   // StringToUtf8 - arayuz bolumunde gerekmiyor

const
  /// Duzlestirme dongusu icin sigorta. FlattenFromNestedObjects tek seviye
  /// isler ve "degisiklik oldu mu" dondurur; sonlanma belgede GARANTI EDILMIS
  /// degildir. Bos ic nesneyle test edildi (sorun yok), ama bilinmeyen bir
  /// girdide sonsuz dongu yerine acik hata almak yeglenir.
  CMaxTur = 64;

{ ── Yardimcilar (birim-yerel) ───────────────────────────────────────────── }

function TurDondur(var ADoc: TDocVariantData; const ASep: AnsiChar;
  const AArrayStartIndex: PtrInt): Integer;
begin
  Result := 0;
  while ADoc.FlattenFromNestedObjects(ASep, AArrayStartIndex) do
  begin
    Inc(Result);
    if Result >= CMaxTur then
      raise EMormotFlatten.CreateFmt(
        'Duzlestirme %d turda sonlanmadi; belge beklenenden derin ya da dongusel.',
        [CMaxTur]);
  end;
end;

function BenzersizAd(const ABase: RawUtf8;
  const AKullanilan: TDictionary<RawUtf8, Integer>): RawUtf8;
var
  n: Integer;
begin
  n := AKullanilan[ABase];
  { Uretilen adin KENDISI de zaten kullaniliyor olabilir (ornegin belgede hem
    a.b hem a.b_2 varsa). Bos bir yuva bulana kadar ilerle. }
  repeat
    Inc(n);
    Result := ABase + '_' + RawUtf8(IntToStr(n));
  until not AKullanilan.ContainsKey(Result);
  AKullanilan[ABase] := n;
end;

procedure TekrarlariAdlandir(var ADoc: TDocVariantData);
var
  LAdlar     : TRawUtf8DynArray;
  LDeger     : TVariantDynArray;
  LSecenek   : TDocVariantOptions;
  LKullanilan: TDictionary<RawUtf8, Integer>;   // rezerve edilmis TUM adlar
  LGorulen   : TDictionary<RawUtf8, Boolean>;   // bu turda daha once gecti mi
  i: Integer;
begin
  { Copy() SART: GetNames "ayni ornegi, yeniden ayirma yapmadan" dondurur -
    yani dizi ADoc ile PAYLASILIR. Kopyalamadan yazmak belgenin kendi
    dizisini altindan degistirirdi. }
  LAdlar   := Copy(ADoc.GetNames);
  LDeger   := Copy(ADoc.Values);
  LSecenek := ADoc.Options;

  LKullanilan := TDictionary<RawUtf8, Integer>.Create;
  LGorulen    := TDictionary<RawUtf8, Boolean>.Create;
  try
    { 1) TUM mevcut adlari ONCE rezerve et.

      Bu adim olmadan yeni uretilen ad, belgede ZATEN VAR OLAN bir anahtarin
      yerini kapabiliyordu: girdi a.b (ic ice), a.b (duz) ve a.b_2 tasidiginda
      ikinci a.b "a.b_2"ye tasiniyor, gercek a.b_2 ise "a.b_2_2"ye itiliyordu.
      Deger kaybi yoktu ama kullanicinin DOKUNULMAMIS bir anahtarinin adi
      degisiyordu. Rezervasyondan sonra bu mumkun degil. }
    for i := 0 to High(LAdlar) do
      if not LKullanilan.ContainsKey(LAdlar[i]) then
        LKullanilan.Add(LAdlar[i], 1);

    { 2) Her adin ILK gorulusu adini korur; sonrakiler yeniden adlandirilir. }
    for i := 0 to High(LAdlar) do
      if LGorulen.ContainsKey(LAdlar[i]) then
      begin
        LAdlar[i] := BenzersizAd(LAdlar[i], LKullanilan);
        LKullanilan.Add(LAdlar[i], 1);
      end
      else
        LGorulen.Add(LAdlar[i], True);
  finally
    LGorulen.Free;
    LKullanilan.Free;
  end;

  { Names salt okunur (read VName), o yuzden belge yeniden kuruluyor.
    LAdlar/LDeger bagimsiz kopyalar oldugu icin Clear guvenli. }
  ADoc.Clear;
  ADoc.InitObjectFromVariants(LAdlar, LDeger, LSecenek);
end;

{ Ayni ada sahip girdilerden yalnizca SONUNCUSUNUN degerini tutar; anahtarin
  konumu ILK gorundugu yerdir. TDictionary.AddOrSetValue ve cogu JSON
  ayristiricisinin "son deger kazanir" davranisiyla ayni. }
procedure SonDegeriKoru(const AAdlar: TRawUtf8DynArray;
  const ADeger: TVariantDynArray;
  out AYeniAdlar: TRawUtf8DynArray; out AYeniDeger: TVariantDynArray);
var
  LKonum: TDictionary<RawUtf8, Integer>;
  i, n, LPos: Integer;
begin
  SetLength(AYeniAdlar, Length(AAdlar));
  SetLength(AYeniDeger, Length(ADeger));
  n := 0;
  LKonum := TDictionary<RawUtf8, Integer>.Create;
  try
    for i := 0 to High(AAdlar) do
      if LKonum.TryGetValue(AAdlar[i], LPos) then
        AYeniDeger[LPos] := ADeger[i]          // EZ: sonraki deger kazanir
      else
      begin
        LKonum.Add(AAdlar[i], n);
        AYeniAdlar[n] := AAdlar[i];
        AYeniDeger[n] := ADeger[i];
        Inc(n);
      end;
  finally
    LKonum.Free;
  end;
  SetLength(AYeniAdlar, n);
  SetLength(AYeniDeger, n);
end;

procedure TekrarlariUzerineYaz(var ADoc: TDocVariantData);
var
  LAdlar, LYeniAdlar: TRawUtf8DynArray;
  LDeger, LYeniDeger: TVariantDynArray;
  LSecenek: TDocVariantOptions;
begin
  { Copy() gerekcesi TekrarlariAdlandir'daki ile ayni: GetNames belgenin KENDI
    dizisini dondurur. }
  LAdlar   := Copy(ADoc.GetNames);
  LDeger   := Copy(ADoc.Values);
  LSecenek := ADoc.Options;

  SonDegeriKoru(LAdlar, LDeger, LYeniAdlar, LYeniDeger);

  ADoc.Clear;
  ADoc.InitObjectFromVariants(LYeniAdlar, LYeniDeger, LSecenek);
end;

procedure CakismalariCoz(var ADoc: TDocVariantData;
  const ACollision: TFlattenCollision);
var
  LTekrar: TRawUtf8DynArray;
begin
  LTekrar := TMormot.DuplicateKeys(ADoc);
  if Length(LTekrar) = 0 then
    Exit;

  { OLCULDU: mORMot belgesi "any name collision will append a counter to make
    it unique" diyor, ama olcumde SAYAC EKLENMIYOR - belge cift anahtarli
    kaliyor. Ornek: girdi bir "a" nesnesi icinde "b" ve ayrica duz bir "a.b"
    anahtari tasiyorsa cikti IKI TANE a.b icerir. Deger kaybolmaz ama belge
    belirsizlesir: Exists True der, hangisinin okundugu belli degildir ve
    anahtar/deger tablosuna yazilirsa birincil anahtar catisir.
    Bu yuzden burada sessiz gecilmiyor. }
  case ACollision of
    fcRename:
      TekrarlariAdlandir(ADoc);
    fcOverwrite:
      TekrarlariUzerineYaz(ADoc);
  else
    raise EMormotFlatten.CreateFmt(
      'Duzlestirme %d anahtarda cakisma uretti (ilki: "%s"). Kaynak belgede ' +
      'hem ic ice bir nesne hem ayni yola karsilik gelen duz bir anahtar var. ' +
      'Kaynagi duzeltin, ya da fcRename (hicbir sey kaybolmaz) veya ' +
      'fcOverwrite (son deger kazanir) kullanin.',
      [Length(LTekrar), Utf8ToString(LTekrar[0])]);
  end;
end;

{ ── TMormot ─────────────────────────────────────────────────────────────── }

class function TMormot.DuplicateKeys(const ADoc: TDocVariantData): TRawUtf8DynArray;
var
  LSayac: TDictionary<RawUtf8, Integer>;
  LAd   : RawUtf8;
  i, n  : Integer;
begin
  Result := nil;
  LSayac := TDictionary<RawUtf8, Integer>.Create;
  try
    for i := 0 to ADoc.Count - 1 do
    begin
      LAd := ADoc.Names[i];
      if LSayac.TryGetValue(LAd, n) then
      begin
        LSayac[LAd] := n + 1;
        if n = 1 then                    // ilk tekrar: listeye BIR kez ekle
        begin
          SetLength(Result, Length(Result) + 1);
          Result[High(Result)] := LAd;
        end;
      end
      else
        LSayac.Add(LAd, 1);
    end;
  finally
    LSayac.Free;
  end;
end;

class function TMormot.Flatten(var ADoc: TDocVariantData;
  const ACollision: TFlattenCollision; const ASep: AnsiChar;
  const AArrayStartIndex: PtrInt): Integer;
begin
  Result := TurDondur(ADoc, ASep, AArrayStartIndex);
  CakismalariCoz(ADoc, ACollision);
end;

class function TMormot.StripBom(const AText: RawByteString): RawByteString;
begin
  Result := AText;
  if (Length(Result) >= 3) and (Result[1] = #$EF) and
     (Result[2] = #$BB) and (Result[3] = #$BF) then
    Delete(Result, 1, 3);
end;

class function TMormot.YamlToJsonText(const AYaml: RawByteString): RawUtf8;
begin
  Result := YamlToJson(StripBom(AYaml));
end;

class function TMormot.XmlToJsonText(const AXml: RawByteString): RawUtf8;
begin
  Result := mormot.core.fmt.XmlToJson(StripBom(AXml));
end;

class function TMormot.JsonToYamlText(const AJson: RawUtf8): RawUtf8;
begin
  Result := JsonToYaml(AJson);
end;

class function TMormot.JsonToXmlText(const AJson: RawUtf8): RawUtf8;
begin
  Result := JsonToXml(AJson);
end;

class function TMormot.Flatten(const ADoc: IDocDict;
  const ACollision: TFlattenCollision; const ASep: AnsiChar;
  const AArrayStartIndex: PtrInt): Integer;
begin
  if ADoc = nil then
    raise EMormotFlatten.Create('TMormot.Flatten: belge nil olamaz.');
  Result := Flatten(ADoc.Value^, ACollision, ASep, AArrayStartIndex);
end;

{ TDocVariantDataHelp }

function TDocVariantDataHelp._RecordLoad<T>(const aKey: string;
  var ARec: T): Boolean;
var
 v:PDocVariantData;
begin

  if GetAsObject(StringToUtf8(aKey),v) then
   begin
    v.ToRtti(ARec,System.TypeInfo(T));
    Result := True;

   end
   else
   result := False;

end;

function TDocVariantDataHelp._RecordSave<T>(const aKey: string;
  var ARec: T): Boolean;
var
  LDeger: Variant;
begin
  LDeger := GetVariantFromRtti(ARec, System.TypeInfo(T));
  Result := TVarData(LDeger).VType > varNull;
  if not Result then
    Exit;
  if not IsObject then
    InitFast(dvObject);

  AddOrUpdateValue(StringToUtf8(aKey), LDeger);
end;

end.
