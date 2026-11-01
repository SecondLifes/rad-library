# Specification: `rad.script` 3. aşama — motor sarmalayıcısı, kanca katmanı, KP görevleri

Durum: **onaylandı ve uygulandı** (2026-11-01; kod `src/vendor/tms/rad.script.engine.pas`,
`rad.script.hooks.pas`, `rad.script.jobs.pas`; paket `src/packages/RadScriptTms`; test
`src/test/scratch/rad_script_hooks/HooksTest.dpr` 34/34 Win32+Win64). Önceki aşamalar: `rad.script-spike.md` (motor
seçimi, ölçümler), `rad.script.md` (paket modeli + store, uygulandı). Bu aşama script'i
**çalıştıran** katmandır; facade nesneleri (`Db`, `Msg`, `Kullanici`...) 4. aşamadadır.

## Bağlam ve onaylı kararlar

- Bağlama anahtarı: form sınıf adı + bileşen `Name`'i. Adsız bileşen görünmez.
- Kanca adları İngilizce: `<Bileşen>_Before(Sender): Boolean` (`False` iptal), `<Bileşen>_After(Sender)`.
- `_After` hatası loglanır/gösterilir, kayıt geri alınmaz. Derleme hatası formu **açmayı engellemez**:
  hata gösterilir, form script'siz açılır (ERP durmaz).
- Ölçümden gelen kısıtlar: olay kesme kendi RTTI sarmalayıcımızla (TMS `EventBroker` iptal
  edemiyor); zaman aşımı yalnız `OnExecHook` + istisna, `Compile`'dan **sonra** bağlanır, asla
  `Halt`, asla başka thread'den; scripter nesnesi thread başına; `Vcl.ScripterInit` şart;
  `TForm` sınıfı `DefineClassByRTTI` ile biz kaydediyoruz.

## Birimler

| Birim | Bağımlılık | İçerik |
|---|---|---|
| `src/vendor/tms/rad.script.engine.pas` | TMS Scripter 8.1 (`atScript`, `atPascal`, `Vcl.ScripterInit`), `rad.script` | `TRadScriptEngine`: scripter sarmalayıcısı, sınıf kaydı, kaynak dosyaları, zaman aşımı, hata çevirisi |
| `src/vendor/tms/rad.script.hooks.pas` | `rad.script.engine`, VCL (`System.TypInfo`, `Vcl.Forms`) | `TRadNotifyHook`, `TRadScriptAttachment`, `TRadScriptBinder.Attach` |
| `src/vendor/tms/rad.script.jobs.pas` | `rad.script.engine`, `rad.eventbus`, `rad.worker`, `rad.date` | `TRadScriptJobs`: `olay` ve `zaman` script'lerini KP'de çalıştırır |

Vendor klasörü: TMS zorunlu bağımlılık değil; `rad.script` (çekirdek) TMS'siz derlenir, bu üç birim
`RadKon`'a değil ayrı `RadScriptTms` paketine girer (runtime; design-time yok).

## `TRadScriptEngine`

```pascal
TRadScriptEngine = class
  constructor Create;                                  // TatPascalScripter(nil) + TatClassesLibrary + kayıtlı sınıflar
  destructor Destroy; override;
  class procedure RegisterClass(AClass: TClass);       // global liste; her Create'te DefineClassByRTTI (8 sınıf 2 ms)
  class procedure RegisterClasses(const AClasses: array of TClass);
  procedure AddScript(AScript: TRadScript);            // TatScript; ScriptInfo.Name := AScript.Code (uses için)
  procedure AddResources(APackageId: Integer; AStore: IRadScriptStore; const ANames: array of string);
                                                       // %LOCALAPPDATA%\rad\script\<paket_id>\ içine yazar, LibOptions.SearchPath'e ekler, FormFileExt '.dfm'
  procedure Expose(const AName: string; AObject: TObject);        // AddObject
  procedure ExposeComponent(AComponent: TComponent);              // AddComponent (Name şart)
  procedure Compile;                                   // hata → ERadScriptCompile(ScriptCode, Line, Col, Msg); OnCompileError satır/sütunu verir
  function HasRoutine(const AScriptCode, AName: string): Boolean;    // UYGULAMA: aynı ad birden çok pakette olabilir → script kodu zorunlu
  function RoutineNames(const AScriptCode: string): TArray<string>;  // ___MAIN___ hariç
  function Call(const AScriptCode, AName: string; const AArgs: array of const): Variant;   // nesneler NativeInt tutamak; EatScripterRuntime → ERadScriptRuntime(Row, Col)
  procedure SetDeadline(AMs: Cardinal);                // Compile sonrası: OnExecHook + CallExecHookEvent; süre dolunca hook ERadScriptTimeout yükseltir
  property Scripter: TatPascalScripter read FScripter; // kaçış kapısı; facade/tasarımcı kullanır
end;
```

Hata sınıfları `rad.script`'e eklenir (TMS'siz): `ERadScriptCompile`, `ERadScriptRuntime`,
`ERadScriptTimeout` (hepsi `ERadScript`), `ScriptCode/Line/Col` alanlarıyla.

Varsayılan kayıtlı sınıflar (`RegisterClass` ile host ekler; motor kendisi şunları kaydeder):
`TComponent`, `TControl`, `TWinControl`, `TForm`, `TAction`, `TDataSet`, `TField`. DevExpress/
`TRadQuery` kaydı host'un işidir (ERPPlus `dmERP` başlangıcı); kit tarafında `rad.dev` için
`RegisterClasses([TcxButton, TcxTextEdit, ...])` çağrısı `rad.script.dev.pas` adlı küçük birimde
hazır verilir (isteğe bağlı, DevExpress'e bağımlı).

## Kanca katmanı

### `TRadNotifyHook`

Sondadaki sınıf, kalıcı hale gelir: `GetMethodProp/SetMethodProp` ile olayı sarar, `Before`
`False`/`Null` değilse orijinali ve `After`'ı çağırır, `Detach` eskiyi geri koyar. İmza kısıtı:
**tek nesne parametreli** olaylar (`TNotifyEvent`, `TDataSetNotifyEvent`, `TCloseQueryEvent` hariç).
`TypInfo` ile olay tipinin parametre sayısı 1 ve türü sınıf değilse kanca **reddedilir** (loglanır).
Var parametreli/tipli olaylar (DevExpress `OnValidate` vb.) bu aşamada yok; 4. aşamada adaptör
üreteciyle gelir.

### Kanca adı çözümleme

Script'teki her alt program adı şu kalıplara bakılır (büyük/küçük harf duyarsız):

| Kalıp | Hedef olay | Örnek |
|---|---|---|
| `<Bileşen>_Before` / `<Bileşen>_After` | bileşenin **ana olayı**: `TBasicAction` → `OnExecute`, diğerleri → `OnClick` (yoksa reddedilir) | `btnKaydet_Before` |
| `<Bileşen>_<OlayAdı>_Before` / `_After` | adı verilen published olay özelliği | `qry_BeforePost_Before`, `Form_OnClose_After` |
| `Form_AfterCreate` | olay değil: `Attach` içinde `Compile`'dan hemen sonra çağrılır | |

`<Bileşen>` formun `FindComponent` ile bulunan adı; `Form` sözcüğü formun kendisi. Bileşen yok /
olay yok / imza uymuyor → kanca kurulmaz, `TRadScriptBinder.OnWarning` ile bildirilir (form açılır).
Aynı olaya birden fazla paketten kanca gelirse zincir: paket sırasına göre iç içe sarılır; herhangi
bir `Before` `False` derse orijinal çalışmaz, sonraki `Before`'lar da çağrılmaz, hiçbir `After`
çalışmaz.

### `TRadScriptAttachment` ve `TRadScriptBinder`

Uygulamada eklenen: `TRadHookChain` — aynı (nesne, olay) üzerindeki kancaların ortak iptal durumu;
içteki `Before` `False` deyince dıştakiler `After`'ı atlar (EARS 2, `B1,B2` sonrası hiçbir `A`).
Yalnız **açık `False`** iptal eder: `procedure` (Empty) ve `Null` geçer.

```pascal
TRadScriptAttachment = class(TComponent)                 // Owner = form; form ölünce kancalar çözülür, motor serbest
  property Engine: TRadScriptEngine;
  property Hooks: TObjectList<TRadNotifyHook>;
  property Scripts: TRadScripts;                        // bağlanan script'ler (ata önce), bilgi için
  procedure Detach;                                     // tüm kancaları geri al
end;

TRadScriptBinder = class
  class var Store: IRadScriptStore;                     // bir kez atanır (özel alanla aynı kalıp)
  class var OnError: TProc<TRadScriptAttachment, Exception>;    // nil → ShowMessage benzeri varsayılan (Vcl.Dialogs) + rad.core log
  class var OnWarning: TProc<string>;                   // kanca reddi, bulunamayan bileşen
  class function Attach(AForm: TCustomForm): TRadScriptAttachment;   // script yoksa nil (maliyet: 1 sorgu/ata sınıf)
  class function AttachmentOf(AForm: TCustomForm): TRadScriptAttachment;
end;
```

`Attach` adımları: (1) `ClassType`'tan `TForm`'a kadar sınıf zinciri, atadan başlayarak her ad için
`Store.ScriptsFor(skForm, ad)`; hiçbiri yoksa `nil`. (2) `TRadScriptEngine.Create`, önce `kutuphane`
türündeki script'ler aynı paketlerden (`ScriptsFor(skLibrary, '')` değil: paket id'leri üzerinden,
store'a `LibrariesOf(APackageIds)` eklenir), sonra form script'leri. (3) `Expose('Form', AForm)`,
`DefineClassByRTTI(AForm.ClassType)` (ata sınıflar dahil otomatik), adı olan her bileşen
`ExposeComponent`. (4) kaynaklar (`AddResources`). (5) `Compile`; hata → `OnError`, motor serbest,
`nil` döner. (6) kanca keşfi + kurulum. (7) `Form_AfterCreate` varsa çağrılır. Süre hedefi: 3 script,
20 bileşenli formda `Attach` ≤ 30 ms (ölçülür).

Hata akışı çalışma zamanında: `Before` istisna → `OnError`, olay **iptal** (kullanıcı kararı:
emniyetli taraf). `After` istisna → `OnError`, yutulur. Orijinal olayın istisnası dokunulmaz geçer
(`After` çalışmaz).

## KP görevleri (`TRadScriptJobs`)

```pascal
TRadScriptEvent = class                 // script'e 'Olay' olarak gider; DefineClassByRTTI
  Channel: string; Json: string; Time: TDateTime; PackageCode, ScriptCode: string;
end;

TRadScriptJobs = class
  constructor Create(AStore: IRadScriptStore; ABus: TChannelBus; AWorkers: TRadWorkers; ADeadlineMs: Cardinal);
  procedure Start;        // olay: her 'olay' script'i için Bus.Subscribe(hedef, cdAsync|Json); zaman: Workers.Plan(TDtSchedule.Create(hedef))
  procedure Refresh;      // store'u yeniden okur: kalkan abonelik/plan iptal, yeni eklenir (paket kaydedildikten sonra çağrılır)
  procedure Stop;
  property OnError: TProc<TRadScript, Exception>;
end;
```

Her tetiklemede **yeni** `TRadScriptEngine` (thread başına scripter kuralı; derleme 9 ms/500 satır
sorun değil), aynı paketin `kutuphane` script'leri eklenir, `Expose('Olay', LEvent)`, `Compile`,
`SetDeadline(ADeadlineMs)`, `Call('Calistir', [LEvent])`. Zaman aşımı/istisna `OnError`'a gider,
görev döngüsü devam eder. Aynı script'in bir önceki çalışması bitmeden yeni tetikleme gelirse
**atlanır** ve loglanır (paralel çalıştırma yok; e-fatura/mail işleri yeniden girişe dayanıklı değil).

## Host sözleşmesi (ERPPlus)

1. `Tbase_kayit`: `FBtnKaydet.Name := 'btnKaydet'`, `FBtnVazgec.Name := 'btnVazgec'`, `FQry.Name := 'qry'`,
   `FLyt.Name := 'lyt'`.
2. `KayitFormuAc`: `Create` ile `Ac(AId)` arasında `TRadScriptBinder.Attach(LForm)`.
3. `Tbase_modul.ListeAc`: `Create`'ten sonra `Attach(Result)`.
4. Başlangıçta: `TRadScriptBinder.Store := dmERP.cnSirketDB._Scripts`,
   `TRadScriptEngine.RegisterClasses([TcxButton, TcxGrid, TdxLayoutControl, TRadQuery, ...])`
   (veya `rad.script.dev`'in hazır listesi).
5. KP: `TRadScriptJobs.Create(Store, Bus, Workers, 60000).Start`.

`komut` türü (modül menüsüne komut ekleme) bu aşamada **yok**: `Tbase_modul.Komut` host'ta;
4. aşamada facade ile birlikte gelir.

## Uygulamada sapmalar ve ölçümler (2026-11-01)

- **Form sınıfı TMS'ye tanıtılmaz.** `DefineClassByRTTI(TKasaK)` yapılınca TMS kalıtımı koparıyor:
  `Form.Caption` bile "Unknown member identifier" (Probe P1; `Ancestor` ataması ve `ARecursive` de
  çözmedi, P1d). Tanıtılmayınca TMS en yakın kayıtlı ataya (`TForm`) bağlıyor ve çalışıyor (P1c).
  Bedel: formun **kendi** public metotları script'ten çağrılamaz; bileşenler adlarıyla açık.
- `RoutineNames` TMS'nin `___MAIN___` sözde alt programını eler (Probe P2).
- `Compile`/`DefineClassByRTTI` global kilit altında: thread'ler arası derleme sondada sorun çıkarmadı
  (Probe P3) ama KP'de her saniye yeni motor kurulurken kilit ucuz bir emniyet.
- `TRadScriptJobs.Run` paketi doğrudan taşır (`PackageOf` araması yok); `OnPrepare` ile host motora
  nesne açar (facade 4. aşama); `OnRun`/`OnSkipped`/`OnError` callback'leri.
- `IRadScriptStore.LibrariesOf(APackageIds)` 2. aşama store'una eklendi (ScriptLiveTest S23, üç sunucu).
- Nesne argümanları `Call` içinde `NativeInt` tutamağa çevrilir (Win64'te `Integer(Pointer)` kesilirdi).

| Ölçüm (Win32 = Win64) | Sonuç |
|---|---|
| `Attach` 3 script + 24 bileşen (derleme + kanca kurulumu) | 3 ms (hedef ≤ 30) |
| Zaman aşımı `SetDeadline(300)` sonsuz döngüde | 301 ms'de `ERadScriptTimeout`, VM sağlam |
| HooksTest | 34/34 Win32, 34/34 Win64 |
| `RadScriptTms` paketi | MSBuild Win32 Release derlendi (RadKon örtük derlendi, `requires` edildi) |

## Kabul ölçütleri (EARS)

Testler `src/test/scratch/rad_script_hooks/` (VCL konsol, gerçek `TForm` + `TButton`/`TAction`/
`TClientDataSet`; store **bellek içi sahte** `IRadScriptStore`, DB yok), Win32 + Win64.

1. **WHEN** form sınıfı için `_Before` `False` döndüren script bağlıysa ve düğme tıklanır
   **THE SYSTEM SHALL** orijinal `OnClick`'i ve `_After`'ı çalıştırmaz; `True` dönerse sıra
   `Before, orijinal, After` olur.
2. **WHEN** aynı olaya iki paketten kanca varsa **THE SYSTEM SHALL** `paket.sira`'ya göre
   `B1, B2, orijinal, A2, A1` sırasını üretir; `B1=False` ise `B2` çağrılmaz.
3. **WHEN** `TAction` için `_Before` yazılır **THE SYSTEM SHALL** `OnExecute`'u sarar; `Action.Execute`
   üzerinden iptal çalışır.
4. **WHEN** `qry_BeforePost_Before` `False` döner **THE SYSTEM SHALL** `TDataSet.Post`'un
   `BeforePost`'unu çağırmaz (dataset olayları tek nesne parametreli). Not: `Post`'un kendisi yine olur;
   kaydı durdurmak isteyen script `Before`'da hata fırlatır (iptal + `OnError`).
5. **WHEN** `Form_AfterCreate` varsa **THE SYSTEM SHALL** `Attach` dönmeden önce bir kez çağırır ve
   script içinden `Form.Caption`/bileşen özelliği yazılabilir.
6. **WHEN** script `btnYok_Before` tanımlar **THE SYSTEM SHALL** `OnWarning` çağırır, formu bağlamaya
   devam eder.
7. **WHEN** script `edt_OnValidate_Before` (var parametreli olay) ister **THE SYSTEM SHALL** kancayı
   reddeder (`OnWarning`), AV üretmez.
8. **WHEN** script derlenemez **THE SYSTEM SHALL** `OnError`'a `ERadScriptCompile`(kod, satır) verir,
   `nil` döner, form olaysız çalışır, motor serbest kalır (bellek sızıntısı yok: `ReportMemoryLeaksOnShutdown`).
9. **WHEN** `_Before` istisna fırlatır **THE SYSTEM SHALL** `OnError` çağırır ve olayı iptal eder;
   `_After` istisnası `OnError`'a gider, çağırana yayılmaz.
10. **WHEN** form `Free` edilir **THE SYSTEM SHALL** kancaları çözer ve motoru yıkar; `Detach`
    sonrası orijinal olay doğrudan çalışır.
11. **WHEN** ata sınıf (`TBaseKayit`) ve alt sınıf (`TKasaK`) için script varsa **THE SYSTEM SHALL**
    ikisini de yükler, ata önce; `kutuphane` script'indeki fonksiyon form script'inden çağrılır.
12. **WHEN** `olay` script'i bağlı kanala `Publish` yapılır **THE SYSTEM SHALL** script'in
    `Calistir(Olay)`'ını çalıştırır, `Olay.Channel/Json` dolu gelir; aynı script'in önceki çalışması
    sürüyorsa ikinci tetikleme atlanır ve loglanır.
13. **WHEN** `zaman` script'i `TDtSchedule` maskesine uyar **THE SYSTEM SHALL** `rad.worker` planıyla
    çalıştırır (test: saniyelik maske, 3 s içinde ≥ 2 çalışma).
14. **WHEN** script sonsuz döngüye girer ve `SetDeadline(300)` verilmişse **THE SYSTEM SHALL**
    ≤ 400 ms'de `ERadScriptTimeout` ile döner, VM sağlam kalır (sonraki `Call` çalışır).
15. **WHEN** `Attach` 3 script + 20 bileşenli forma uygulanır **THE SYSTEM SHALL** süreyi ölçer ve
    rapor eder (hedef ≤ 30 ms; aşılırsa sayı raporlanır, test geçer).

## İşlevsel olmayan gereksinimler

- Birimler `src/vendor/tms/`; paket `RadScriptTms` (runtime, Win32+Win64) `RadKon`'u requires eder.
- Public API'de overload/varsayılan parametre yok (`RegisterClass`/`RegisterClasses` iki ad).
- Hiçbir birim `with` kullanmaz; `TRadScriptAttachment` `TComponent` sahipliğiyle yaşam döngüsünü çözer,
  ayrıca `FreeNotification` gerekmez (form sahibi).
- Thread: `TRadScriptBinder` ana thread; `TRadScriptJobs` görev thread'inde kendi motoru, UI'ye dokunmaz.

## Kapsam dışı (3. aşama)

Facade nesneleri (`Db`, `Msg`, `Kullanici`, `Sirket`, `Mail`, `Log`), `komut` türü, var parametreli/
tipli olay adaptörleri, tasarımcı/IDE, p-code saklama, script'ten script'e paketler arası `uses`.
