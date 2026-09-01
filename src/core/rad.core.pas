unit rad.core;

{
  RAD Library — cekirdek birim.

  Buranin kurali: hicbir rad.* birimine bagimli olmaz. Taban tipler, taban
  siniflar, ortak sabitler ve ortak istisna agaci burada yasar; ustteki her
  birim (rad.cache, rad.json, ...) buradan beslenir, tersi olmaz.

  ===========================================================================
  IKI KILIT TIPI — AYNI YUZ, FARKLI SOZLESME
  ===========================================================================

    TRadLock     mORMot TRWLock uzerine   cok okur / tek yazar, uc gercek seviye
    TRadOSLock   mORMot TOSLock uzerine   tek girisli ozyinelemeli kritik bolum

  Ikisi de ayni metotlari sunar (ReadLock/UpdateLock/WriteLock + LockedXxx),
  boylece bir sinifin kilit stratejisini degistirmek TEK SATIRLIK alan tipi
  degisikligidir:

      FLock: TRadLock;      ->      FLock: TRadOSLock;

  Bilerek TEK bir tip icine mod secici koymadik (mORMot'un TSynLocker'i oyle
  yapar). Sebebi asagidaki yuvalama tablosu: iki primitifin yuvalama
  sozlesmesi FARKLI, ve tek tipte bu "moda bagli" hale gelirdi. Hata bicimi
  istisna degil SESSIZ SONSUZ DONME oldugu icin, "duruma gore" yazan bir
  belgeye guvenmek istemedik. Ayrica tek tip, iki primitifi de her ornekte
  tasimak ve her cagrida dagitim yapmak demekti.

  ---------------------------------------------------------------------------
  HANGISINI SECMELIYIM — olculdu, tahmin degil (Win32, Release -$O+)
  ---------------------------------------------------------------------------

  Okuma agirlikli, 8 thread, kisa kritik bolum:
    TRadLock   ............   36 ms       <-- okurlar PARALEL
    dislayici  ............  107 ms

  Yazma agirlikli, 64 thread (cekirdek x2), kisa kritik bolum:
    TRadLock   ............ 2759 ms duvar /  83406 ms CPU  <-- donerek bekler
    TRadOSLock ............  898 ms duvar /  26047 ms CPU

  Ayni test, uzun kritik bolum:
    TRadLock   ............  162 ms duvar /   4984 ms CPU
    TRadOSLock ............  205 ms duvar /    266 ms CPU  <-- 19x az CPU

  Ozet: okurlar cogunluktaysa TRadLock. Kilit neredeyse hep dislayici
  aliniyorsa VE thread sayisi cekirdek sayisini asiyorsa TRadOSLock.
  Sebep: TRWLock beklerken ~50us kadar doner (DoSpin, ustel geri cekilme,
  sonra SwitchToThread); TOSLock ise cekirdek olayinda UYUR. Cok thread'li
  dislayici cekismede donmek, kilidi tutan thread'den cekirdek calar.

  VARSAYILAN TRadLock'tur. TRadOSLock'a ancak OLCUM gosterdiginde gec.

  ---------------------------------------------------------------------------
  YUVALAMA — iki tipin TEK gercek davranis farki
  ---------------------------------------------------------------------------

  TRadLock (mormot.core.os.pas kaynagindan dogrulanmistir):

    Distaki      Icteki       Sonuc
    -----------  -----------  ---------------------------------------------
    UpdateLock   ReadLock     GUVENLI
    UpdateLock   WriteLock    GUVENLI  (yukseltme yolu budur)
    WriteLock    WriteLock    GUVENLI  (ayni thread, yeniden girisli)
    ReadLock     ReadLock     GUVENLI  (sayac artar)
    ReadLock     WriteLock    KILITLENIR
    WriteLock    ReadLock     KILITLENIR

  Son iki satir sessizce sonsuz doner, istisna atmaz. Sebebi: WriteLock
  "while Flags > 3" ile TUM okurlarin bitmesini bekler ve kendi thread'ini
  muaf tutmaz; ReadLock ise yazma bitini maskeleyip CAS yaptigi icin yazma
  bayragi setliyken asla basarili olamaz.

  TRadOSLock: uc seviyenin UCU DE ayni ozyinelemeli kritik boluma duser,
  dolayisiyla HER yuvalama guvenlidir.

  ==> TEHLIKE, TEK YONLU: TRadOSLock ile gelistirilip test edilen kod
      TRadLock'a cevrildiginde KILITLENEBILIR. Tersi olmaz. Gelistirmeyi
      TRadLock ile yap; TRadOSLock'a gecis her zaman guvenli yondedir.

  Pratik kural (her iki tipte de dogru): bir cagri yigini ya bastan sona
  okuma, ya bastan sona yazma olsun. Ikisini ayni islemde karistirman
  gerekiyorsa giris noktasi UpdateLock olmali.

  Ucuncu seviyenin adi SQL Server'in U (Update) kilidinden gelir; VCL'deki
  BeginUpdate/EndUpdate ile hicbir ilgisi yoktur.

  ---------------------------------------------------------------------------
  ORTAK KURALLAR
  ---------------------------------------------------------------------------

  * Init cagirmak ZORUNLU DEGILDIR. Ikisinde de sifirlanmis bellek dogal
    olarak "kilit etkin" demektir. Init yalnizca kilidi bastan devre disi
    birakmak (Init(False)) icin gereklidir.

  * TRadOSLock omur sonunda Done ISTER (isletim sistemi kaynagi birakir).
    TRadLock'ta Done yoktur, gerekmez. Tek asimetri budur.

  * Enabled bayragi YAZILABILIR ama ON KOSULLUDUR: degistirildigi anda kilit
    TUTULMUYOR olmali. Tutuluyorsa setter ERadLock firlatir.

    Sebep: ReadLock ile ReadUnlock IKI AYRI andir ve ikisi de bu bayraga
    bakar. Bayrak aralarinda degisirse cift bozulur — acikken kapatirsan
    unlock atlanir, okuma sayaci SIZAR ve o kilitteki her WriteLock sonsuza
    kadar doner; kapaliyken acarsan hic alinmamis bir kilit birakilir ve
    sayac ALTTAN TASAR. JCL'in TJclAbstractLockable'i (JclAbstractContainers.
    pas, SetThreadSafe) bunu bekcisiz yapar ve ayni sekilde bozulur.

    Bekcinin GOREMEDIGI tek durum, kilit KAPALIYKEN acmaktir: kapali kilitte
    IsLocked her zaman False doner, dolayisiyla "ReadLock cagirdi ama islemsiz
    gecti" durumundaki thread gorunmez. Bu yuzden pratik kural: bayragi, nesne
    baska thread'lerle PAYLASILMADAN once ayarla (kur -> tek thread'de yukle ->
    ac -> dagit).

    Setter alttaki kilit primitifine DOKUNMAZ. Init cagirmasi cazip gorunur ama
    olculdu (2026-08-24): Init tabanli bir setter tutulan kilitte IsLocked'i
    False'a dusuruyor, ReadLock icindeyken WriteLock aninda geciyor — yani
    karsilikli dislama sessizce kayboluyor; TRadOSLock'ta ayrica her cagri bir
    OS kritik bolumu sizdiriyor (Init, Done cagirmadan yeniden kurar).

    Alan ters mantikla tutuluyor (FDisabled), boylece sifirlanmis bellek
    guvenli tarafa — "kilit etkin" — dusuyor.

  * DEGER OLARAK KOPYALAMAYIN (L2 := L1). Kopya, kilit sayaclarinin ikinci
    bir kopyasini ve TRadOSLock'ta ayni kritik bolumun ikinci bir sahibini
    uretir. Her zaman ALAN olarak tutun; gerekiyorsa isaretcisini gecirin.
}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils,System.Classes,Data.DB,
  mormot.core.base,  // TRWLock/TOSLock'un inline metotlarinin ACILABILMESI icin
                     // sart: olmadan derleyici H2443 verip inline'i geri ceviriyor
  mormot.core.variants, mormot.core.fmt,
  mormot.core.os;    // TRWLock, TOSLock

const
  WM_CMD = WM_USER + 2000;
  WM_EVENT_AFTERSHOW = WM_CMD + 1;
  WM_EVENT_LOAD = WM_CMD + 2;

type


IDBComponent = interface

end;


{$REGION 'Istisnalar'}

  /// <summary>Bu kutuphanedeki tum istisnalarin ortak atasi.</summary>
  ERadCore = class(Exception);

  /// <summary>Kilit disiplininin ihlal edildigi durumlar.</summary>
  ERadLock = class(ERadCore);

{$ENDREGION}


{$REGION 'TResult<T>'}

  /// <summary>Basarili/basarisiz sonucu hata mesajiyla birlikte tasir.</summary>
  /// <remarks>
  ///   DIKKAT - Success/Failure/FromException hepsi `class function ... static`,
  ///   yani YENI bir kayit URETIR, mevcut olani DEGISTIRMEZ. Dogru kullanim
  ///   ATAMADIR:
  ///   <code>
  ///   rs := TResult&lt;Boolean&gt;.Failure('...');   // DOGRU
  ///   rs.Failure('...');                          // DERLENIR, HICBIR SEY YAPMAZ
  ///   </code>
  ///   Ikincisi derleyiciden ses cikarmaz (Delphi static class function'i ornek
  ///   uzerinden cagirmaya izin verir) ve donen kaydi sessizce atar.
  /// </remarks>
  TResult<T> = record
  private
    FValue: T;
    FErrorMsg: string;
    FSuccess: Boolean;
    function GetValue: T;
  public
    { BASLANGIC DURUMU - olculdu, tahmin degil.

      Bu operator eklenmeden once yerel bir TResult<T> degiskeninin FSuccess
      alani COP degeri tasiyordu: derleyici yerel kayitta yalnizca YONETILEN
      alanlari (burada FErrorMsg: string) sifirlar, Boolean gibi yonetilmeyen
      alanlar yigindan ne geldiyse onu korur.

      Sonucu sadece "rastgele True" degildi: 0/1 disinda bir bayt (olcumde
      $02) tasiyan Boolean icin hem `if X` hem `not X` sifirdan farkli cikar,
      yani ayni degisken iki zit soruya birden "evet" der. Gercek bir
      _ConnectTest cagrisi bu yuzden basarisiz baglantida True donuyordu.

      Artik baslangic deterministik ve GUVENLI TARAFTA: basarisiz. }
    class operator Initialize(out ADest: TResult<T>);

    { --- URETEN bicim: yeni bir kayit dondurur, ATANMALIDIR --- }

    { Başarı durumunda sonuç üretir }
    class function Success(const AValue: T): TResult<T>; static;
    { Hata durumunda mesajla sonuç üretir }
    class function Failure(const AErrorMsg: string): TResult<T>; static;
    { Exception durumunda otomatik hata sonucu üretir }
    class function FromException(const E: Exception): TResult<T>; static;

    { --- DEGISTIREN bicim: kaydin KENDISINI gunceller ---

      Yukaridaki uclunun tersine bunlar bir sey dondurmez, dolayisiyla
      "cagirdim ama hicbir sey olmadi" hatasi YAPILAMAZ - bir procedure'un
      sonucunu yanlislikla atmak mumkun degildir.

      Asil kullanim yeri closure'lardir; disaridaki bir degiskeni yerinde
      guncellemek gerektiginde uretilen kaydi elle geri atamak zorunda
      kalmazsiniz:
      <code>
      .OnError  (procedure(t: TRadTask) begin rs.SetFailure(t.ErrorMsg) end)
      .OnSuccess(procedure(t: TRadTask) begin rs.SetSuccess(True)       end)
      </code> }

    /// <summary>Kaydi BASARILI duruma alir; hata mesajini temizler.</summary>
    procedure SetSuccess(const AValue: T);
    /// <summary>Kaydi BASARISIZ duruma alir; degeri sifirlar.</summary>
    procedure SetFailure(const AErrorMsg: string);
    /// <summary>Kaydi istisnanin mesajiyla BASARISIZ duruma alir.</summary>
    procedure SetException(const E: Exception);

    { Güvenli veri okuma pattern'i }
    function TryGetValue(out AValue: T): Boolean;

    { Özellikler }
    property Value: T read GetValue;
    property ErrorMsg: string read FErrorMsg;
    property IsSuccess: Boolean read FSuccess;

  end;

{$ENDREGION}


{$REGION 'TRadLock — cok okur / tek yazar'}

  PRadLock = ^TRadLock;

  /// <summary>
  ///   Okuma agirlikli erisim icin cok-okur / tek-yazar kilidi.
  ///   mORMot'un TRWLock'u uzerine kurulur. VARSAYILAN TERCIH.
  /// </summary>
  /// <remarks>
  ///   HANGI SEVIYEYI SECMELIYIM
  ///   <code>
  ///   Ne yapiyorsun                  Digerleri ne yapabilir    Hangisi
  ///   -----------------------------  ------------------------  -----------
  ///   Sadece okuyorum                okur: EVET                ReadLock
  ///                                  guncelleyici: EVET
  ///                                  yazar: bekler
  ///
  ///   Okuyup karar verecegim,        okur: EVET                UpdateLock
  ///   belki yazacagim                guncelleyici: bekler
  ///                                  yazar: bekler
  ///
  ///   Kosulsuz yaziyorum             okur: bekler              WriteLock
  ///                                  guncelleyici: bekler
  ///                                  yazar: bekler
  ///   </code>
  ///
  ///   HANGISI HANGISININ ICINDE CAGRILABILIR
  ///   <code>
  ///   Distaki      Icteki       Sonuc
  ///   -----------  -----------  -------------------------------------------
  ///   UpdateLock   ReadLock     GUVENLI
  ///   UpdateLock   WriteLock    GUVENLI  (yukseltme yolu budur)
  ///   WriteLock    WriteLock    GUVENLI  (ayni thread, yeniden girisli)
  ///   ReadLock     ReadLock     GUVENLI  (sayac artar)
  ///   ReadLock     WriteLock    KILITLENIR
  ///   WriteLock    ReadLock     KILITLENIR
  ///   </code>
  ///   Son iki satir istisna atmaz, SESSIZCE sonsuz doner. Bir cagri yigini
  ///   ya bastan sona okuma, ya bastan sona yazma olsun; ikisini ayni islemde
  ///   karistirman gerekiyorsa giris noktasi UpdateLock olmali.
  ///
  ///   Yazma yolu cok thread'le sicaksa TRadOSLock'a bak — ayni metotlari
  ///   sunar, alan tipini degistirmek yeterlidir. Olcum sayilari birim
  ///   basligindadir.
  ///
  ///   Init cagirmak zorunlu degildir (sifirlanmis bellek = etkin), Done
  ///   diye bir sey de yoktur. Record oldugu icin kalitim agacindan
  ///   bagimsizdir. DEGER OLARAK KOPYALAMAYIN.
  /// </remarks>
  TRadLock = record
  private
    /// Ters mantik: False (= sifirlanmis bellek) kilit ETKIN demektir.
    FDisabled: Boolean;
    FLock: TRWLock;
  public
    /// <summary>
    ///   Kilidi hazirlar. Sinif alanlari icin cagrilmasi zorunlu degildir.
    /// </summary>
    /// <param name="AEnabled">
    ///   False verilirse tum kilitleme cagrilari islemsiz hale gelir; tek
    ///   thread'li kullanimda maliyeti sifirlar. Bu deger nesnenin omru
    ///   boyunca SABITTIR — sonradan degistirmek kilit sayacini bozar,
    ///   bu yuzden setter yoktur.
    /// </param>
    procedure Init(AEnabled: Boolean = True);

    /// <summary>Paylasimli okuma. Ayni anda sinirsiz okur girebilir.</summary>
    /// <remarks>Icinde WriteLock cagirmak KILITLENIR — bkz. yukaridaki tablo.</remarks>
    procedure ReadLock;          {$IFDEF HASINLINE} inline; {$ENDIF}
    /// <summary>ReadLock'u serbest birakir.</summary>
    procedure ReadUnlock;        {$IFDEF HASINLINE} inline; {$ENDIF}

    /// <summary>Dislayici yazma: tek yazar, hicbir okur yok.</summary>
    /// <remarks>
    ///   Ayni thread'ten yeniden girislidir. Icinde ReadLock cagirmak
    ///   KILITLENIR.
    /// </remarks>
    procedure WriteLock;         {$IFDEF HASINLINE} inline; {$ENDIF}
    /// <summary>WriteLock'u serbest birakir.</summary>
    procedure WriteUnlock;       {$IFDEF HASINLINE} inline; {$ENDIF}

    /// <summary>
    ///   Guncelleme niyetiyle okuma: okurlari ENGELLEMEZ, diger yazar
    ///   adaylarini engeller. Icinden WriteLock cagirmak serbesttir.
    /// </summary>
    /// <remarks>
    ///   "Oku, karar ver, belki yaz" deseninin giris noktasi budur. Ad,
    ///   SQL Server'in ayni isi yapan U (Update) kilidinden gelir.
    ///   DIKKAT: VCL'deki BeginUpdate/EndUpdate ile ILGISIZDIR — orasi ekran
    ///   tazelemesini erteler, burasi bir es zamanlilik kilididir.
    /// </remarks>
    procedure UpdateLock;        {$IFDEF HASINLINE} inline; {$ENDIF}
    /// <summary>UpdateLock'u serbest birakir.</summary>
    procedure UpdateUnlock;      {$IFDEF HASINLINE} inline; {$ENDIF}

    /// <summary>ABody'yi paylasimli okuma kilidi altinda calistirir.</summary>
    procedure LockedRead(const ABody: TProc);
    /// <summary>ABody'yi dislayici yazma kilidi altinda calistirir.</summary>
    procedure LockedWrite(const ABody: TProc);
    /// <summary>
    ///   ABody'yi guncelleme niyetiyle okuma altinda calistirir; ABody icinde
    ///   WriteLock/WriteUnlock cagirmak guvenlidir.
    /// </summary>
    procedure LockedUpdate(const ABody: TProc);

    /// <summary>Kilit su an herhangi bir seviyede tutuluyor mu.</summary>
    /// <remarks>
    ///   Thread'e OZEL DEGILDIR — baska bir thread tutuyorsa da True doner.
    ///   Akis kontrolu icin kullanilamaz, yalnizca teshis amaclidir.
    /// </remarks>
    function IsLocked: Boolean;  {$IFDEF HASINLINE} inline; {$ENDIF}

    /// <summary>
    ///   Kilidin notr durumda oldugunu dogrular, degilse ERadLock firlatir.
    /// </summary>
    /// <remarks>
    ///   Teshis amaclidir. DESTRUCTOR ICINDEN CAGIRMAYIN: yikim sirasinda
    ///   firlayan istisna asil istisnayi maskeler ve Free'yi yarida birakir.
    /// </remarks>
    procedure AssertUnlocked;

    function GetEnabled: Boolean;                       {$IFDEF HASINLINE} inline; {$ENDIF}
    procedure SetEnabled(const AValue: Boolean);

    /// <summary>Kilitleme etkin mi. YAZILABILIR, ama on kosulu vardir.</summary>
    /// <remarks>
    ///   ON KOSUL: degistirildigi anda bu kilit TUTULMUYOR olmalidir. Tutuluyorsa
    ///   setter ERadLock firlatir — sessizce bozmaktansa yuksek sesle durur.
    ///
    ///   NEDEN on kosul var: ReadLock ile ReadUnlock IKI AYRI andir ve ikisi de
    ///   bu bayraga bakar. Bayrak aralarinda degisirse cift bozulur —
    ///   acikken kapatirsan unlock atlanir ve okuma sayaci SIZAR (o kilitteki
    ///   her WriteLock sonsuza kadar doner); kapaliyken acarsan hic alinmamis
    ///   bir kilit birakilir ve sayac ALTTAN TASAR.
    ///
    ///   BEKCININ GOREMEDIGI TEK DURUM: kilit KAPALIYKEN acmak. IsLocked kapali
    ///   kilitte her zaman False dondugu icin, o sirada "ReadLock cagirdi ama
    ///   islemsiz gecti" durumundaki bir thread gorunmez; sonra ReadUnlock
    ///   ettiginde sayac alttan tasar. Bu yuzden pratik kural degismiyor:
    ///   bayragi nesne BASKA THREAD'LERLE PAYLASILMADAN once ayarla.
    ///
    ///   Setter alttaki TRWLock'a DOKUNMAZ (Init cagirmaz): bekci sayesinde
    ///   ortada silinecek bir kilit durumu zaten yoktur, ve Init cagirmak
    ///   TRadOSLock'ta OS kaynagi sizdirirdi (Init, Done cagirmadan yeniden
    ///   kurar). Olculdu (2026-08-24): Init tabanli bir setter, tutulan bir
    ///   kilitte IsLocked'i False'a dusuruyor ve ReadLock icindeyken WriteLock
    ///   aninda geciyordu — karsilikli dislama sessizce kayboluyordu.
    /// </remarks>
    property Enabled: Boolean read GetEnabled write SetEnabled;
  end;

{$ENDREGION}


{$REGION 'TRadOSLock — dislayici, cekirdek beklemeli'}

  PRadOSLock = ^TRadOSLock;

  /// <summary>
  ///   Dislayici, ozyinelemeli kritik bolum kilidi. mORMot'un TOSLock'u
  ///   (yani isletim sisteminin kritik bolumu) uzerine kurulur.
  /// </summary>
  /// <remarks>
  ///   TRadLock ile AYNI metotlari sunar, boylece bir sinifin kilidini
  ///   degistirmek tek satirlik alan tipi degisikligidir. Iki fark vardir:
  ///
  ///   1) PARALEL OKUMA YOKTUR. ReadLock, UpdateLock ve WriteLock ucu de
  ///      ayni dislayici kilide duser; okurlar birbirini bekler.
  ///
  ///   2) HER YUVALAMA GUVENLIDIR. Kritik bolum ozyinelemeli oldugu icin
  ///      TRadLock'un kilitlenen iki satiri burada sorunsuz calisir.
  ///      Bu yuzden TRadOSLock'ta yazilip test edilen kod TRadLock'a
  ///      cevrildiginde KILITLENEBILIR — tersi olmaz.
  ///
  ///   NE ZAMAN: kilit neredeyse hep dislayici aliniyorsa VE thread sayisi
  ///   cekirdek sayisini asiyorsa. Olcum (Win32, 64 thread, kisa kritik
  ///   bolum): TRadLock 2759 ms duvar / 83406 ms CPU, TRadOSLock 898 ms /
  ///   26047 ms. Uzun kritik bolumde duvar sureleri yakin ama CPU farki
  ///   19 kat. Buna karsilik 8 thread'lik OKUMA testinde TRadLock 36 ms,
  ///   dislayici 107 ms — yani varsayilan tercih hala TRadLock.
  ///
  ///   Init cagirmak zorunlu degildir (kritik bolum ilk kullanimda
  ///   thread-safe olarak kurulur), ama omur sonunda Done CAGRILMALIDIR —
  ///   TRadLock'tan tek yapisal farki budur. DEGER OLARAK KOPYALAMAYIN.
  /// </remarks>
  TRadOSLock = record
  private
    /// Ters mantik: False (= sifirlanmis bellek) kilit ETKIN demektir.
    FDisabled: Boolean;
    /// TOSLock IsLocked sunmuyor, biz sayiyoruz. Yalnizca kilit ELDE
    /// tutulurken degistirildigi icin ayrica korumaya gerek yok.
    /// (mORMot'un TSynLocker'i da tam bu sebeple fLockCount tasir.)
    FLockCount: Integer;
    FLock: TOSLock;
    procedure Enter;             {$IFDEF HASINLINE} inline; {$ENDIF}
    procedure Leave;             {$IFDEF HASINLINE} inline; {$ENDIF}
  public
    /// <summary>
    ///   Kilidi hazirlar. Cagrilmasi zorunlu degildir: kritik bolum ilk
    ///   kilitlemede thread-safe sekilde kurulur.
    /// </summary>
    /// <param name="AEnabled">
    ///   Omur boyunca SABITTIR; setter yoktur. Gerekcesi birim basliginda.
    /// </param>
    procedure Init(AEnabled: Boolean = True);

    /// <summary>
    ///   Isletim sistemi kaynagini birakir. TRadLock'tan farkli olarak
    ///   BU CAGRILMALIDIR. Birden fazla cagrilmasi ve hic kilitlenmemis bir
    ///   kilit uzerinde cagrilmasi guvenlidir.
    /// </summary>
    procedure Done;

    /// <summary>Kilidi alir. Paylasimli DEGILDIR — okurlar birbirini bekler.</summary>
    procedure ReadLock;          {$IFDEF HASINLINE} inline; {$ENDIF}
    /// <summary>ReadLock'u serbest birakir.</summary>
    procedure ReadUnlock;        {$IFDEF HASINLINE} inline; {$ENDIF}

    /// <summary>Kilidi alir. Ayni thread'ten yeniden girislidir.</summary>
    procedure WriteLock;         {$IFDEF HASINLINE} inline; {$ENDIF}
    /// <summary>WriteLock'u serbest birakir.</summary>
    procedure WriteUnlock;       {$IFDEF HASINLINE} inline; {$ENDIF}

    /// <summary>
    ///   Kilidi alir. TRadLock'takinin aksine burada okurlari ENGELLER —
    ///   ayri bir ara seviye yoktur, arayuz uyumu icin vardir.
    /// </summary>
    procedure UpdateLock;        {$IFDEF HASINLINE} inline; {$ENDIF}
    /// <summary>UpdateLock'u serbest birakir.</summary>
    procedure UpdateUnlock;      {$IFDEF HASINLINE} inline; {$ENDIF}

    /// <summary>ABody'yi kilit altinda calistirir.</summary>
    procedure LockedRead(const ABody: TProc);
    /// <summary>ABody'yi kilit altinda calistirir.</summary>
    procedure LockedWrite(const ABody: TProc);
    /// <summary>ABody'yi kilit altinda calistirir.</summary>
    procedure LockedUpdate(const ABody: TProc);

    /// <summary>Kilit su an tutuluyor mu (ozyineleme derinligi &gt; 0).</summary>
    /// <remarks>Thread'e OZEL DEGILDIR; yalnizca teshis amaclidir.</remarks>
    function IsLocked: Boolean;  {$IFDEF HASINLINE} inline; {$ENDIF}

    /// <summary>
    ///   Kilidin notr durumda oldugunu dogrular, degilse ERadLock firlatir.
    /// </summary>
    /// <remarks>DESTRUCTOR ICINDEN CAGIRMAYIN.</remarks>
    procedure AssertUnlocked;

    function GetEnabled: Boolean;                       {$IFDEF HASINLINE} inline; {$ENDIF}
    procedure SetEnabled(const AValue: Boolean);

    /// <summary>Kilitleme etkin mi. Sozlesme TRadLock ile AYNI - gerekce orada.</summary>
    /// <remarks>
    ///   Burada ek bir sebep daha var: setter FLock'a dokunmaz. Dokunsaydi
    ///   (Init cagirsaydi) her degisim bir OS kritik bolumu sizdirirdi, cunku
    ///   TRadOSLock.Init, Done cagirmadan FLock.Init yapar ve FLockCount'u
    ///   sifirlayip ozyineleme sayimini bozar.
    /// </remarks>
    property Enabled: Boolean read GetEnabled write SetEnabled;
  end;

{$ENDREGION}


{$REGION 'ILockable / TAbstractLockable'}

  /// <summary>Kilitlenebilir nesnelerin ortak sozlesmesi.</summary>
  /// <remarks>
  ///   Sekli JCL'in IJclLockable'indan gelir (JclContainerIntf.pas:276) ama
  ///   iki farkla: guncelleme seviyesi acikca yer alir, ve ThreadSafe
  ///   YAZILABILIR degildir — yalnizca okunur.
  /// </remarks>

  ILockable = interface
    ['{0EA1D538-09FC-412E-862D-55FA7296C447}']
    procedure ReadLock;
    procedure ReadUnlock;
    procedure WriteLock;
    procedure WriteUnlock;
    procedure UpdateLock;
    procedure UpdateUnlock;
    function  IsThreadSafe: Boolean;
    function GetSafe: PRadLock;
  end;

  /// <summary>ILockable'i TRadLock'a delege eden taban sinif.</summary>
  /// <remarks>
  ///   Kalitim agaci uygun olan siniflar bundan turer. Uygun OLMAYANLAR —
  ///   ornegin TSynAutoCreateFields soyundan gelen ayar siniflari — bunun
  ///   yerine dogrudan bir TRadLock (veya TRadOSLock) ALANI tasir; davranis
  ///   birebir aynidir, cunku ikisi de ayni record'u kullanir.
  ///
  ///   TRadOSLock isteyen bir taban sinif henuz YOK: ihtiyac ciktiginda
  ///   ayni sablonla eklenir (tek fark alan tipi ve destructor'da Done).
  ///
  ///   PAYLASILAN KILIT: butun kilit metotlari kendi FLock'una DEGIL,
  ///   GetLock'un dondurdugu isaretciye gider ve GetLock SANALDIR. Bir soyagac
  ///   ayni veriyi paylasan nesneler uretiyorsa (ornek: rad.json'daki alt
  ///   belgeler — IDocDict agacin icine REFERANSLA bakar, kopya degildir)
  ///   cocuk GetLock'u override edip KOKUN kilidini dondurur; boylece iki
  ///   kilit tek veri yapisini korumaya calismaz. Override etmeyen sinif icin
  ///   davranis degismez: GetLock kendi FLock'unu dondurur.
  /// </remarks>
  TAbstractLockable = class(TInterfacedObject, ILockable)
  private
    procedure SetThreadSafe(const Value: Boolean);
  protected
    FSafe: TRadLock;
    /// <summary>Kilit metotlarinin GERCEK hedefi. Varsayilan: kendi FLock'u.</summary>
    /// <remarks>
    ///   SANALDIR ve bu yuzden inline DEGILDIR: paylasilan kilit senaryosunda
    ///   cocugun kokun kilidine yonlendirebilmesi buna bagli. Sanal cagrinin
    ///   maliyeti kilit isleminin yaninda olculemez.
    /// </remarks>
    function GetSafe: PRadLock; virtual;
  public
    /// <param name="AThreadSafe">
    ///   Nesnenin omru boyunca sabittir; sonradan degistirilemez.
    /// </param>
    { Kilit ETKIN olarak kurar. Sifirlanmis bellek zaten "etkin" demektir
      (birim basligi), o yuzden burada Init cagrilmaz. }
    constructor Create; overload; virtual;
    { Kilidi bastan devre disi birakmak icin: Create(False).

      VARSAYILAN DEGER YOK, ve bu zorunlu: `AThreadSafe: Boolean = True`
      yazilirsa parametresiz `Create` ile bu asiri yukleme AYNI cagriya uyar ve
      derleyici E2251 "Ambiguous overloaded call to 'Create'" verir. }
    constructor Create(const AThreadSafe: Boolean); reintroduce; overload; virtual;

    { ILockable }
    procedure ReadLock;          {$IFDEF HASINLINE} inline; {$ENDIF}
    procedure ReadUnlock;        {$IFDEF HASINLINE} inline; {$ENDIF}
    procedure WriteLock;         {$IFDEF HASINLINE} inline; {$ENDIF}
    procedure WriteUnlock;       {$IFDEF HASINLINE} inline; {$ENDIF}
    procedure UpdateLock;        {$IFDEF HASINLINE} inline; {$ENDIF}
    procedure UpdateUnlock;      {$IFDEF HASINLINE} inline; {$ENDIF}
    function  IsThreadSafe: Boolean;

    /// <summary>
    ///   Kilide dogrudan erisim: LockedRead / LockedWrite / LockedUpdate ve
    ///   IsLocked buradan cagrilir.
    /// </summary>
    /// <remarks>
    ///   ISARETCI dondurur, kopya degil — record'u deger olarak veren bir
    ///   property gecici kopya uretme riski tasirdi, yazilabilir olsaydi da
    ///   kilit durumu tek atamada ezilebilirdi.
    /// </remarks>
    property Safe: PRadLock read GetSafe;

    /// <summary>Kilit etkin mi. SALT OKUNUR - omur boyu sabittir.</summary>
    /// <remarks>
    ///   SETTER YOK, ve bu bilincli: yazilabilir bir bayrak OLCULEREK bozuk
    ///   bulundu (2026-08-24, Delphi 37.0 Win32). Setter FSafe.Init cagirmak
    ///   zorundadir, Init ise TRWLock'u da SIFIRLAR - yani CANLI kilit durumunu
    ///   siler:
    ///   <code>
    ///   o.ReadLock;                 // IsLocked = True
    ///   o.ThreadSafe := False;      // IsLocked = False  &lt;-- tutulan kilit ucdu
    ///   o.WriteLock;                // ANINDA gecti - oysa ReadLock icinde
    ///                               //   WriteLock KILITLENMELIYDI
    ///   </code>
    ///   Sonuc: bir thread korumali bolumdeyken baskasi yazabilir; karsilikli
    ///   dislama sessizce kaybolur. JEDI'nin ayni desendeki SetThreadSafe'i
    ///   (birim basligi) yalnizca sayac sizdiriyordu; bu daha kotusunu yapar.
    ///
    ///   Korumasiz bir ornek gerekiyorsa KURUCUDA sec: Create(False).
    /// </remarks>
    property ThreadSafe: Boolean read IsThreadSafe write SetThreadSafe;
  end;

{$ENDREGION}

implementation

{$REGION 'TResult<T>'}

{ TResult<T> }

class operator TResult<T>.Initialize(out ADest: TResult<T>);
begin
  { YALNIZCA yonetilmeyen alana dokunulur. FErrorMsg (string) ve yonetilen bir
    T, bu operator cagrilmadan once derleyici tarafindan zaten sifirlanmistir;
    buraya yazmak gereksiz olmakla kalmaz, sifirlama SIRASINA bagimlilik
    yaratirdi. Olculdu: dokunulmamis kayitta ErrorMsg='' iken FSuccess cop. }
  ADest.FSuccess := False;
end;

procedure TResult<T>.SetSuccess(const AValue: T);
begin
  FValue    := AValue;
  FSuccess  := True;
  FErrorMsg := '';
end;

procedure TResult<T>.SetFailure(const AErrorMsg: string);
begin
  FValue    := Default(T);   // basarisiz sonucun degeri okunmamali; yine de bayat veri birakma
  FSuccess  := False;
  FErrorMsg := AErrorMsg;
end;

procedure TResult<T>.SetException(const E: Exception);
begin
  SetFailure(E.Message);
end;

class function TResult<T>.Success(const AValue: T): TResult<T>;
begin
  Result.FValue := AValue;
  Result.FSuccess := True;
  Result.FErrorMsg := '';
end;

class function TResult<T>.Failure(const AErrorMsg: string): TResult<T>;
begin
  Result.FSuccess := False;
  Result.FErrorMsg := AErrorMsg;
  // FValue default(T) olarak kal�r (Managed record de�ilse manuel s�f�rlanabilir)
end;

class function TResult<T>.FromException(const E: Exception): TResult<T>;
begin
  Result := TResult<T>.Failure(E.Message);
end;

function TResult<T>.GetValue: T;
begin
  if not FSuccess then
    raise EInvalidOpException.Create('Hatalı bir sonucun degeri okunamaz. Hata: ' + FErrorMsg);
  Result := FValue;
end;

function TResult<T>.TryGetValue(out AValue: T): Boolean;
begin
  Result := FSuccess;
  if Result then
    AValue := FValue;
end;

{$ENDREGION}


{$REGION 'TRadLock'}

procedure TRadLock.Init(AEnabled: Boolean);
begin
  FDisabled := not AEnabled;
  FLock.Init;
end;

function TRadLock.GetEnabled: Boolean;
begin
  Result := not FDisabled;
end;

procedure TRadLock.SetEnabled(const AValue: Boolean);
begin
  { BEKCI: kilit tutuluyorken bayragi degistirmek, acik olan bir lock/unlock
    ciftini bozar. Sessizce bozmak yerine burada duruyoruz. Gerekce ve
    bekcinin goremedigi tek durum: tipin bildirimindeki aciklama. }
  if IsLocked then
    raise ERadLock.Create(
      'TRadLock.Enabled: kilit TUTULURKEN degistirilemez. Acik bir lock/unlock ' +
      'cifti bozulur (sayac sizar ya da alttan tasar). Bayragi, nesne baska ' +
      'thread"lerle paylasilmadan once ayarlayin.');
  { Alttaki kilide DOKUNULMAZ: bekci gectiyse sifirlanacak bir durum yok. }
  FDisabled := not AValue;
end;

procedure TRadLock.ReadLock;
begin
  if not FDisabled then
    FLock.ReadOnlyLock;
end;

procedure TRadLock.ReadUnlock;
begin
  if not FDisabled then
    FLock.ReadOnlyUnLock;
end;

procedure TRadLock.WriteLock;
begin
  if not FDisabled then
    FLock.WriteLock;
end;

procedure TRadLock.WriteUnlock;
begin
  if not FDisabled then
    FLock.WriteUnlock;
end;

procedure TRadLock.UpdateLock;
begin
  if not FDisabled then
    FLock.ReadWriteLock;
end;

procedure TRadLock.UpdateUnlock;
begin
  if not FDisabled then
    FLock.ReadWriteUnLock;
end;

procedure TRadLock.LockedRead(const ABody: TProc);
begin
  ReadLock;
  try
    ABody();
  finally
    ReadUnlock;
  end;
end;

procedure TRadLock.LockedWrite(const ABody: TProc);
begin
  WriteLock;
  try
    ABody();
  finally
    WriteUnlock;
  end;
end;

procedure TRadLock.LockedUpdate(const ABody: TProc);
begin
  UpdateLock;
  try
    ABody();
  finally
    UpdateUnlock;
  end;
end;

function TRadLock.IsLocked: Boolean;
begin
  Result := (not FDisabled) and FLock.IsLocked;
end;

procedure TRadLock.AssertUnlocked;
begin
  if IsLocked then
    raise ERadLock.Create('TRadLock: kilit hala tutuluyor.');
end;

{$ENDREGION}


{$REGION 'TRadOSLock'}

procedure TRadOSLock.Init(AEnabled: Boolean);
begin
  FDisabled := not AEnabled;
  FLockCount := 0;
  if not FDisabled then
    FLock.Init;
end;

procedure TRadOSLock.Done;
begin
  // DeleteCriticalSectionIfNeeded: hic kurulmamis olsa da guvenli, ve
  // birden fazla cagrilabilir.
  FLock.Done;
  FLockCount := 0;
end;

function TRadOSLock.GetEnabled: Boolean;
begin
  Result := not FDisabled;
end;

procedure TRadOSLock.SetEnabled(const AValue: Boolean);
begin
  { BEKCI: kilit tutuluyorken bayragi degistirmek, acik olan bir lock/unlock
    ciftini bozar. Sessizce bozmak yerine burada duruyoruz. Gerekce ve
    bekcinin goremedigi tek durum: tipin bildirimindeki aciklama. }
  if IsLocked then
    raise ERadLock.Create(
      'TRadOSLock.Enabled: kilit TUTULURKEN degistirilemez. Acik bir lock/unlock ' +
      'cifti bozulur (sayac sizar ya da alttan tasar). Bayragi, nesne baska ' +
      'thread"lerle paylasilmadan once ayarlayin.');
  { Alttaki kilide DOKUNULMAZ: bekci gectiyse sifirlanacak bir durum yok. }
  FDisabled := not AValue;
end;

procedure TRadOSLock.Enter;
begin
  // LockAndInitIfNeeded: kritik bolum sifirlanmis ise cift kontrollu,
  // thread-safe olarak kurar. Init'i unutmak bu sayede hata degil.
  FLock.LockAndInitIfNeeded;
  Inc(FLockCount);   // kilit ELDE tutulurken artiriliyor: yaris yok
end;

procedure TRadOSLock.Leave;
begin
  Dec(FLockCount);
  FLock.UnLock;
end;

procedure TRadOSLock.ReadLock;
begin
  if not FDisabled then
    Enter;
end;

procedure TRadOSLock.ReadUnlock;
begin
  if not FDisabled then
    Leave;
end;

procedure TRadOSLock.WriteLock;
begin
  if not FDisabled then
    Enter;
end;

procedure TRadOSLock.WriteUnlock;
begin
  if not FDisabled then
    Leave;
end;

procedure TRadOSLock.UpdateLock;
begin
  if not FDisabled then
    Enter;
end;

procedure TRadOSLock.UpdateUnlock;
begin
  if not FDisabled then
    Leave;
end;

procedure TRadOSLock.LockedRead(const ABody: TProc);
begin
  ReadLock;
  try
    ABody();
  finally
    ReadUnlock;
  end;
end;

procedure TRadOSLock.LockedWrite(const ABody: TProc);
begin
  WriteLock;
  try
    ABody();
  finally
    WriteUnlock;
  end;
end;

procedure TRadOSLock.LockedUpdate(const ABody: TProc);
begin
  UpdateLock;
  try
    ABody();
  finally
    UpdateUnlock;
  end;
end;

function TRadOSLock.IsLocked: Boolean;
begin
  Result := (not FDisabled) and (FLockCount > 0);
end;

procedure TRadOSLock.AssertUnlocked;
begin
  if IsLocked then
    raise ERadLock.Create('TRadOSLock: kilit hala tutuluyor.');
end;

{$ENDREGION}


{$REGION 'TAbstractLockable'}

constructor TAbstractLockable.Create(const AThreadSafe: Boolean);
begin
  Create;
  FSafe.Init(AThreadSafe);

end;

constructor TAbstractLockable.Create;
begin
  inherited Create;
end;

function TAbstractLockable.GetSafe: PRadLock;
begin
  Result := @FSafe;
end;

{ Asagidakilerin hepsi FLock'a DEGIL GetLock^'a gider: paylasilan kilit
  senaryosunda (bkz. tip basligi) cocuk GetLock'u override eder ve butun
  kilit yuzeyi tek noktadan yonlendirilmis olur. }

function TAbstractLockable.IsThreadSafe: Boolean;
begin
  Result := FSafe.Enabled;
end;

procedure TAbstractLockable.ReadLock;
begin
  FSafe.ReadLock;
end;

procedure TAbstractLockable.ReadUnlock;
begin
  FSafe.ReadUnlock;
end;

procedure TAbstractLockable.SetThreadSafe(const Value: Boolean);
begin
   if Self = nil then
    raise ERadLock.Create('SetThreadSafe: nesne nil - Create cagrilmamis ' +
      'ya da nesne yok edilmis olabilir.');
  FSafe.Enabled := Value;    { bekci zaten iceride: kilitliyse ERadLock }
end;

procedure TAbstractLockable.WriteLock;
begin
  FSafe.WriteLock;
end;

procedure TAbstractLockable.WriteUnlock;
begin
  FSafe.WriteUnlock;
end;

procedure TAbstractLockable.UpdateLock;
begin
  FSafe.UpdateLock;
end;

procedure TAbstractLockable.UpdateUnlock;
begin
  FSafe.UpdateUnlock;
end;

{$ENDREGION}

end.
