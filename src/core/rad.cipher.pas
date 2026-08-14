unit rad.cipher;

{
  RAD Library — sifreleme katmani.

  Bagimliliklar: rad.core (istisna agaci) + mORMot crypt. Baska rad.* birimi
  YOK — bu birim rad.config'in altinda durur, ustunde degil.

  ===========================================================================
  BU KATMANIN NE OLDUGU — ve ne OLMADIGI
  ===========================================================================

  Tasarim karari (kullanici onayli): anahtar UYGULAMANIN ICINE gomulur, her
  makinede acilabilmesi icin. Bunun dogrudan bir sonucu var ve burada acikca
  yazilmasi gerekir:

    Bu katman AT-REST GIZLEME saglar, gercek anlamda sifreleme DEGIL.

  KORUDUGU seyler (bunlar az degil):
    * Ag paylasimindaki, yedekteki, destek talebine eklenen ekran
      goruntusundeki dosyada duz metin sizmaz
    * Elle kurcalama YAKALANIR (AES-GCM kimlik dogrulama etiketi)
    * Ayar degerleri log'a veya hata mesajina kazara dusmez

  KORUMADIGI tek sey:
    * Uygulamanin ikilisine (.exe) sahip olan biri. Anahtar oradadir.

  Bu yuzden buraya kredi karti numarasi, saglik verisi veya baskasinin
  sirrini KOYMAYIN. Kendi uygulamanizin baglanti parolasi, API anahtari gibi
  "gorulmesin ama kaybi felaket degil" seviyesindeki veriler icindir.
  Gercek gizlilik gerekiyorsa anahtar kullanicidan alinmali (parola sorma)
  veya bir vault'tan gelmelidir — IRadCipher arayuzu bunu sonradan eklemeye
  aciktir, bu birimi degistirmeden.

  ===========================================================================
  NEDEN AesPkcs7 DEGIL, TAesGcm.MacAndCrypt — OLCULDU
  ===========================================================================

  mORMot'ta iki hazir yol var ve ikisi de cazip gorunuyor. Ikisi de OLCULDU;
  biri bu is icin YANLIS:

  1) AesPkcs7'nin PAROLA surumu — KULLANILAMAZ.
     Kaynagi okundu (mormot.crypt.core.pas): PBKDF2 ciktisinin alt 128 bitini
     anahtar, UST 128 bitini IV olarak kullaniyor. Sabit parola + sabit salt
     = her sifrelemede AYNI IV. Varsayilan mod mCtr (akis sifresi) oldugundan
     iki kayit arasinda C1 xor C2 = P1 xor P2 olur. Ayar dosyasi kayittan
     kayda az degisir ve yapisi tahmin edilebilirdir; iki surumu ele geciren
     biri icerigi buyuk olcude cozer.

  2) AesPkcs7'nin ANAHTAR surumu, mGcm ile — KURCALAMAYI YAKALAMIYOR.
     Rastgele IV uretmesi dogru, ama GCM kimlik dogrulama ETIKETINI
     saklamiyor. Olcum: 54 bayt duz metin -> 80 bayt sifreli. 54'un PKCS7
     ile 64'e dolgusu + 16 bayt IV = 80. Etikete yer YOK. Ortadaki bir bit
     cevrildiginde cozme basariyla dondu ve BOZULMUS duz metin verdi.
     (Yanlis anahtarin yakalanmasi yaniltmasin: o, PKCS7 dolgu kontrolune
     takiliyor, kimlik dogrulamayla degil.)

  3) TAesGcm.MacAndCrypt — DOGRU YOL, kullanilan bu.
     54 bayt -> 96 bayt (64 dolgulu + 16 IV + 16 MAC). 96 baytin HEPSI tek
     tek cevrilip denendi:
        92 bayt -> cozme reddedildi (kurcalama yakalandi)
         4 bayt -> reddedilmedi, AMA duz metin DOGRU cozuldu
     O 4 bayt, 16 baytlik IV alaninin son 4 baytidir. GCM 96-bit nonce +
     32-bit sayac kullanir; son 4 bayt (sayac baslangici) GCM tarafindan
     zaten yeniden kuruluyor, yani OLU ALAN. Duz metni degistirebilecek her
     mudahale yakalaniyor.

  ---------------------------------------------------------------------------
  THREAD GUVENLIGI
  ---------------------------------------------------------------------------

  Her cagrida YENI bir TAesGcm ornegi yaratiliyor. Sebebi: TAesGcm ic durum
  (sayac, MAC birikimi) tasir; paylasilan tek ornek uzerinde iki thread'in
  ayni anda MacAndCrypt cagirmasi durumu bozar. Anahtar genisletmenin
  maliyeti var ama sifreleme yalnizca dosya kaydet/yukle aninda calisiyor —
  sicak yol degil. Boylece bu sinif kilit gerektirmeden thread-safe.
}

interface

uses
  System.SysUtils,
  mormot.core.base,
  mormot.core.text,    // FormatUtf8
  mormot.crypt.core,   // TAesGcm, TAesAbstract, THash256
  rad.core;            // ERadCore

type

{$REGION 'Istisnalar'}

  /// <summary>Sifreleme katmaninin ortak istisna atasi.</summary>
  ERadCipher = class(ERadCore);

  /// <summary>Gecersiz anahtar (desteklenmeyen boyut).</summary>
  ERadCipherKey = class(ERadCipher);

  /// <summary>
  ///   Cozme basarisiz: yanlis anahtar VEYA veri kurcalanmis/bozulmus.
  /// </summary>
  /// <remarks>
  ///   GCM kimlik dogruladigi icin bu iki durumu birbirinden AYIRAMAYIZ —
  ///   ve ayirmamaliyiz da: hangisinin oldugunu soylemek saldirgana bilgi
  ///   verir. Mesaj bilerek ikisini birlikte anar.
  /// </remarks>
  ERadCipherData = class(ERadCipher);

{$ENDREGION}

{$REGION 'IRadCipher'}

  /// <summary>Bayt dizisi sifreleyen/cozen soyutlama.</summary>
  /// <remarks>
  ///   Bilerek DAR tutuldu: sadece bayt girer, bayt cikar. Base64, zarf,
  ///   dosya bicimi gibi seyler bu arayuzun isi DEGIL — onlar rad.config'in
  ///   sorumlulugunda. Boylece testlerde sahte bir cipher yazmak uc satir
  ///   surer ve ileride farkli bir anahtar kaynagi (parola, vault, HSM)
  ///   eklemek bu birimi hic degistirmez.
  /// </remarks>
  IRadCipher = interface
    ['{6F3B1C74-9A2E-4D58-B0E1-7C4A2D9F5E38}']
    /// <summary>
    ///   Duz metni sifreler. Bos girdi bos sonuc dondurur.
    /// </summary>
    /// <remarks>
    ///   Ayni girdi her cagrida FARKLI cikti verir (rastgele IV). Bu bir
    ///   hata degil, sartir — bkz. birim basligindaki IV aciklamasi.
    ///   Cagiran tarafta "degisti mi" karsilastirmasi DUZ METIN uzerinden
    ///   yapilmalidir, sifreli cikti uzerinden degil.
    /// </remarks>
    function Encrypt(const APlain: RawByteString): RawByteString;

    /// <summary>Sifreli veriyi cozer.</summary>
    /// <exception cref="ERadCipherData">
    ///   Yanlis anahtar veya kurcalanmis/bozulmus veri.
    /// </exception>
    function Decrypt(const ACipher: RawByteString): RawByteString;

    /// <summary>
    ///   Zarfa yazilacak algoritma etiketi, ornegin 'aes-gcm-256'.
    /// </summary>
    /// <remarks>
    ///   Cozerken dosyadaki etiketle karsilastirilir. Etiketsiz bir zarf,
    ///   algoritma degistigi gun sessiz bozulmaya donusur.
    /// </remarks>
    function AlgorithmId: RawUtf8;
  end;

{$ENDREGION}

{$REGION 'TRadAesGcmCipher'}

  /// <summary>
  ///   AES-GCM ile sifreleyen IRadCipher uygulamasi. Anahtar HAM BAYT
  ///   olarak verilir.
  /// </summary>
  /// <remarks>
  ///   ANAHTARI IKILIDE NASIL TASIMALI
  ///
  ///   Gomulu anahtarin gercek dusmani `strings` ve hex arama — vakalarin
  ///   buyuk cogunlugu budur. Anahtari bitisik bir sabit olarak yazmayin;
  ///   parcalayip calisma aninda birlestirin:
  ///
  ///   <code>
  ///   const
  ///     P1: array[0..15] of Byte = ($3A,$7F,$C2,$18,$9B,$04,$E6,$5D,
  ///                                 $11,$A8,$72,$3C,$D0,$4F,$96,$28);
  ///     P2: array[0..15] of Byte = ($6E,$B3,$05,$D9,$47,$AC,$1F,$82,
  ///                                 $50,$29,$EB,$74,$C6,$3D,$08,$A1);
  ///     XM = $5C;   // maskeleme sabiti
  ///
  ///   function AppKey: THash256;
  ///   var i: Integer;
  ///   begin
  ///     for i := 0 to 15 do
  ///     begin
  ///       Result[i]      := P1[i] xor XM;
  ///       Result[i + 16] := P2[i] xor XM;
  ///     end;
  ///   end;
  ///
  ///   // kullanim
  ///   LKey := AppKey;
  ///   try
  ///     LCipher := TRadAesGcmCipher.Create(LKey);
  ///   finally
  ///     FillZero(LKey);          // yigindan hemen sil
  ///   end;
  ///   </code>
  ///
  ///   Bu tersine muhendisligi DURDURMAZ; amaci o degil. Dosyayi goren ama
  ///   ikiliyi gormeyen kisiye karsi korur — bkz. birim basligi.
  ///
  ///   HER UYGULAMA KENDI ANAHTARINI URETMELIDIR. Bu kit hicbir varsayilan
  ///   anahtar tasimaz ve tasimamalidir: ortak bir varsayilan, bu kitle
  ///   uretilen her uygulamanin birbirinin dosyasini acabilmesi demektir.
  /// </remarks>
  TRadAesGcmCipher = class(TInterfacedObject, IRadCipher)
  private
    FKey: THash256;
    FKeyBits: Integer;
    FAlgorithmId: RawUtf8;
  public
    /// <summary>Ham anahtar baytlariyla kurar.</summary>
    /// <param name="AKey">
    ///   Anahtar baytlari. AKeySizeBits/8 kadari okunur; cagiran tarafta
    ///   en az o kadar bayt bulunmasi sarttir.
    /// </param>
    /// <param name="AKeySizeBits">128, 192 veya 256. Varsayilan 256.</param>
    /// <exception cref="ERadCipherKey">Desteklenmeyen boyut.</exception>
    constructor Create(const AKey; AKeySizeBits: Integer = 256);

    /// <summary>Anahtari bellekten siler.</summary>
    destructor Destroy; override;

    { IRadCipher }
    function Encrypt(const APlain: RawByteString): RawByteString;
    function Decrypt(const ACipher: RawByteString): RawByteString;
    function AlgorithmId: RawUtf8;
  end;

{$ENDREGION}

implementation

{$REGION 'TRadAesGcmCipher'}

constructor TRadAesGcmCipher.Create(const AKey; AKeySizeBits: Integer);
begin
  inherited Create;
  // DIKKAT: burada "in [128, 192, 256]" YAZILAMAZ. Delphi'de set elemanlari
  // 0..255 araligindadir; 256 tasar ve E1012 verir. Acik karsilastirma sart.
  if (AKeySizeBits <> 128) and (AKeySizeBits <> 192) and
     (AKeySizeBits <> 256) then
    raise ERadCipherKey.CreateFmt(
      'TRadAesGcmCipher: anahtar boyutu %d bit desteklenmiyor ' +
      '(128, 192 veya 256 olmali).', [AKeySizeBits]);
  FKeyBits := AKeySizeBits;
  FillCharFast(FKey, SizeOf(FKey), 0);
  MoveFast(AKey, FKey, AKeySizeBits shr 3);
  FAlgorithmId := FormatUtf8('aes-gcm-%', [AKeySizeBits]);
end;

destructor TRadAesGcmCipher.Destroy;
begin
  FillZero(FKey);   // anahtari yigindan sil
  inherited Destroy;
end;

function TRadAesGcmCipher.AlgorithmId: RawUtf8;
begin
  Result := FAlgorithmId;
end;

function TRadAesGcmCipher.Encrypt(const APlain: RawByteString): RawByteString;
var
  LAes: TAesAbstract;
begin
  if APlain = '' then
  begin
    Result := '';
    Exit;
  end;
  // Her cagrida yeni ornek: bkz. birim basligindaki "Thread guvenligi".
  LAes := TAesGcm.Create(FKey, FKeyBits);
  try
    // IVAtBeginning=True: rastgele IV uretilip ciktinin basina konur, ve
    // GCM kimlik dogrulama etiketi de eklenir. Bu yuzden ayni duz metin
    // her seferinde FARKLI sifreli metin verir.
    Result := LAes.MacAndCrypt(APlain, {Encrypt=}True, {IVAtBeginning=}True);
  finally
    LAes.Free;
  end;
  if Result = '' then
    raise ERadCipherData.Create('TRadAesGcmCipher: sifreleme basarisiz.');
end;

function TRadAesGcmCipher.Decrypt(const ACipher: RawByteString): RawByteString;
var
  LAes: TAesAbstract;
begin
  if ACipher = '' then
    raise ERadCipherData.Create('TRadAesGcmCipher: cozulecek veri bos.');
  LAes := TAesGcm.Create(FKey, FKeyBits);
  try
    // MacAndCrypt basarisizlikta '' donduruyor, istisna atmiyor. Gecerli
    // sifreli metin hicbir zaman bos duz metne cozulmez (Encrypt bos girdiyi
    // zaten sifrelemiyor), dolayisiyla '' burada KESIN basarisizlik demek.
    Result := LAes.MacAndCrypt(ACipher, {Encrypt=}False, {IVAtBeginning=}True);
  finally
    LAes.Free;
  end;
  if Result = '' then
    raise ERadCipherData.Create(
      'Cozme basarisiz: anahtar yanlis ya da veri kurcalanmis/bozulmus.');
end;

{$ENDREGION}

end.
