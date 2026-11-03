# Specification: `rad.script` 4. aşama — facade API, `komut` türü, tipli olay adaptörleri, `rad-script` skill'i

Durum: **onaylandı ve uygulandı** (2026-11-01; kod `src/vendor/tms/rad.script.facade.pas`,
`rad.script.commands.pas`, `rad.script.typedhooks.pas`, `rad.script.dev.pas`, `rad.script.uni.pas`;
skill `.agents/skills/rad-script/`; referans `docs/script-api.md`; testler
`src/test/scratch/rad_script_facade/` FacadeTest 24/24 Win32+Win64, FacadeVclTest 7/7 Win32). Önceki aşamalar: `rad.script.md` (paket/store),
`rad.script.hooks.md` (motor, kanca, KP görevleri). Bu aşama script yazarının (insan ya da yapay
zeka) **eline verilen dünyayı** tanımlar: hangi nesneler, hangi sınıflar, hangi adlar.

## Bağlam ve kısıtlar

- Ölçümden gelen kurallar: facade API'de **overload yok, varsayılan parametre yok** (RTTI kaydında
  son bildirilen kazanır, varsayılan zorunlu olur). Her metot tek imza, tüm parametreler açık.
- Formun kendi sınıfı TMS'ye tanıtılmaz (3. aşama sapması); script formu `TForm` olarak görür,
  bileşenleri adlarıyla.
- Güvenlik = yalnız kapalı alanlar (lisans bilgisi); sandbox yok. Facade lisans/sunucu parolası
  gibi bilgileri **hiç açmaz**; `Db` host'un verdiği bağlantıyı kullanır, bağlantı dizesini vermez.
- `Vcl.ScripterInit` şart; TMS `ap_Forms` kullanılmaz (`Show` yok, sonda V5).

## Birimler

| Birim | Bağımlılık | İçerik |
|---|---|---|
| `src/vendor/tms/rad.script.facade.pas` | UniDAC (`Help.uni`), VCL (`Vcl.Dialogs`), `rad.script.engine` | `TRadScriptContext` (host'un doldurduğu bağlam), facade sınıfları `TRadScriptDb/Query/Msg/Kullanici/Sirket/Param/Log/Mail`, `TRadScriptFacade.Install(AEngine, AContext)` |
| `src/vendor/tms/rad.script.commands.pas` | `rad.script.engine`, `rad.script.hooks` | `komut` türü: modüle menü komutu ekleme |
| `src/vendor/tms/rad.script.typedhooks.pas` | DevExpress (`cxEdit`), VCL | var parametreli olaylar için adaptörler (`TCloseQueryEvent`, `TcxEditValidateEvent`) |
| `src/vendor/tms/rad.script.dev.pas` | DevExpress | `TRadScriptDev.RegisterAll` (hazır sınıf listesi) |
| `src/vendor/tms/rad.script.uni.pas` | UniDAC | `TRadScriptUni.RegisterAll` (`TDataSet`, `TField`, `TUniQuery`, `TRadQuery`) |
| `.agents/skills/rad-script/` | — | yapay zeka ve insan için script yazma skill'i + üretilen API referansı |

Hepsi `RadScriptTms` paketine girer (`cxLibraryRS37`, `dac370` requires eklenir); çekirdek `rad.script`
TMS'siz kalır.

## Bağlam (`TRadScriptContext`)

Host bir kez doldurur, `TRadScriptBinder.Context` ve `TRadScriptJobs.Context` olarak verilir:

```pascal
TRadScriptContext = class
  Connection: TUniConnection;          // şirket DB'si; script'e bağlantı dizesi verilmez
  Store: IRadScriptStore;              // Param için
  UserId: Integer; UserName, UserCode: string;
  CompanyCode, CompanyName: string;
  Mailer: IRadScriptMailer;            // nil → Mail.Gonder ERadScript ("posta ayarlanmadı")
  OnLog: TProc<string>;                // nil → mORMot TSynLog
  ConfirmProc: TFunc<string, Boolean>; // nil → Vcl.Dialogs.MessageDlg; KP'de host False döndürür (soru yok)
end;
IRadScriptMailer = interface  procedure Send(const ATo, ASubject, ABody: string);  end;
```

## Facade nesneleri (script'ten görünen adlar)

Script'te global: `Form` (form script'i), `Olay` (KP), `Db`, `Msg`, `Kullanici`, `Sirket`, `Param`,
`Log`, `Mail`. Standart TMS kütüphaneleri: `ap_System, ap_SysUtils, ap_StrUtils, ap_DateUtils, ap_Math,
ap_Variants, ap_Classes` (`IntToStr`, `FormatDateTime`, `Now`, `Pos`… hazır).

```pascal
Db
  function Sorgu(const ASql: string): TRadScriptQuery;   // parametreli sorgu kurucu (aşağıda)
  function Deger(const ASql: string): Variant;           // tek hücre, parametresiz kısa yol
  function Sayi(const ASql: string): Integer;            // count(*) kısa yolu
  procedure Calistir(const ASql: string);                // parametresiz DML/DDL
  procedure BaslaIslem; procedure Onayla; procedure GeriAl;   // transaction; iç içe yok (InTransaction ise hata)

TRadScriptQuery   // Db.Sorgu(...) döner; zincir: Db.Sorgu('... :id').Param('id', 5).Deger
  function Param(const AName: string; const AValue: Variant): TRadScriptQuery;
  function Deger: Variant;
  function Sayi: Integer;
  procedure Calistir;
  function Ac: TDataSet;        // açık TUniQuery; sahibi facade, script Kapat demezse form/çalıştırma sonunda serbest
  procedure Kapat;

Msg
  procedure Bilgi(const AText: string); procedure Uyari(const AText: string); procedure Hata(const AText: string);
  function Soru(const AText: string): Boolean;   // KP'de Context.ConfirmProc nil → False

Kullanici: Id: Integer; Ad, Kod: string (salt okunur)
Sirket:    Kod, Ad: string
Param:     function Deger(const AName: string): string;              // bağlı paketin script_parametre'si; yoksa ''
           function DegerVarsayilan(const AName, ADefault: string): string;
Log:       procedure Yaz(const AText: string); procedure Hata(const AText: string);
Mail:      procedure Gonder(const ATo, ASubject, ABody: string);
```

`Db.Sorgu` nesneleri bir `TObjectList` içinde tutulur ve `TRadScriptFacade` ile (form attachment /
KP çalıştırma sonunda) serbest bırakılır; script `Free` çağırmaz (TMS'de nesne yıkımı script'e
açılmaz: `TObject.Free` kaydı yok).

## `komut` türü (`rad.script.commands`)

Script `tur='komut'`, `hedef = modül sınıf adı` (`Tkasa_modul`), alt program `<Kod>_Execute(Sender)`.
Host modül `Register`'ında:

```pascal
TRadScriptAddCommand = reference to procedure(const ACode, ACaption: string; AOnExecute: TNotifyEvent);
class function TRadScriptCommands.Attach(AModule: TComponent; const AAdd: TRadScriptAddCommand): TRadScriptAttachment;
```

`Attach` modül sınıf adı için `ScriptsFor(skCommand, ad)` okur, motoru kurar (facade dahil), her
script için `AAdd(S.Code, S.Name, LHandler)` çağırır; handler `Engine.Call(code, code + '_Execute', [Sender])`.
ERPPlus: `Tbase_modul.Register` sonunda `TRadScriptCommands.Attach(Self, procedure(...) begin
Komut(ACode, ACaption, 'Script', '', -1, AOnExecute, False) end)`.

## Tipli olay adaptörleri (`rad.script.typedhooks`)

3. aşama yalnız tek nesne parametreli olayları sarar. Bu aşamada iki var parametreli olay için
elle yazılmış adaptör (sonda V4 kalıbı, TMS `TatEventDispatcher` **kullanılmaz**; kendi
`TRadTypedHook` tabanı, aynı `Before/After` + `TRadHookChain` semantiği):

| Olay tipi | Script imzası | İptal etkisi |
|---|---|---|
| `TCloseQueryEvent` (`Form_OnCloseQuery_Before`) | `function (Sender: TObject; CanClose: Boolean): Boolean` | `False` → `CanClose := False`, orijinal çağrılmaz |
| `TcxEditValidateEvent` (`edt_OnValidate_Before`) | `function (Sender: TObject; DisplayValue: Variant; ErrorText: string): Boolean` | `False` → `Error := True`, `ErrorText := Msg.SonHata` (script `Msg.HataMetni('…')` ile koyar), orijinal çağrılmaz |

Var parametreler script'e **değerle** gider (ölçüm V4); geri yazma yalnız yukarıdaki iki alan.
`TRadScriptBinder` kanca kurarken önce `TRadNotifyHook.CanHook`, değilse `TRadTypedHook.Registry`
(tip bilgisi → adaptör sınıfı) bakar; ikisi de yoksa uyarı (3. aşama davranışı). Yeni tip eklemek =
bir `TRadTypedHook` alt sınıfı + `Registry.Add(TypeInfo(...), sınıf)`.

## Sınıf kayıt listeleri

- `TRadScriptUni.RegisterAll`: `TDataSet, TField, TUniQuery, TRadQuery, TUniConnection`
  (bağlantı sınıfı yalnız `InTransaction/Connected` gibi masum üyeler için; `Password/Server`
  **görünmesin** → `DefineClassByRTTI` sonrası TMS sınıf tanımından `Password`, `Server`,
  `ConnectString`, `Username`, `Database` üyeleri silinir; test eder).
- `TRadScriptDev.RegisterAll`: `TcxButton, TcxTextEdit, TcxDBTextEdit, TcxMemo,
  TcxDBMemo, TcxComboBox, TcxDBLookupComboBox, TcxDateEdit, TcxDBDateEdit, TcxCurrencyEdit,
  TcxDBCurrencyEdit, TcxCheckBox, TcxDBCheckBox, TcxGrid, TcxGridDBTableView, TcxGridLevel,
  TdxLayoutControl, TdxLayoutItem, TdxLayoutGroup, TcxLabel, TcxPageControl, TcxTabSheet` (RTTI ile
  2 ms/8 sınıf ölçüldü; 22 sınıf ≤ 10 ms hedef, ölçülür).
- Motorun kendi kaydı: `TComponent, TControl, TWinControl, TForm, TAction, TDataSet, TField` (3. aşama).

## `rad-script` skill'i

`.agents/skills/rad-script/SKILL.md`: ne zaman kullanılır (ERP davranışı script ile değiştirme),
kanca adı kuralları, facade özeti, "yapılmaz" listesi (overload yok, `Free` yok, `Halt` yok, UI
yalnız form script'inde), 5 örnek (3. aşama spec'indekiler). `references/api.md` **üretilir**:
`TRadScriptEngine.ExportReference(AStream)` kayıtlı her sınıfın metot/özellik imzalarını Markdown
yazar; `src/test/scratch/rad_script_facade/` testi bunu `docs/script-api.md`'ye üretir, skill ona
bağlanır (elle yazılmış kopya yok; drift olmaz).

## Host sözleşmesi (ERPPlus)

1. Başlangıç: `Context := TRadScriptContext.Create; Context.Connection := dmERP.cnSirketDB; Context.Store :=
   cnSirketDB._Scripts; Kullanici/Sirket alanları; TRadScriptBinder.Context := Context;
   TRadScriptUni.RegisterAll; TRadScriptDev.RegisterAll`.
2. `Tbase_modul.Register` → `TRadScriptCommands.Attach`.
3. KP: `TRadScriptJobs.Context := Context` (Mailer burada dolu; ConfirmProc nil).
4. 3. aşamadaki maddeler (düğme adları, `Attach` çağrıları) hâlâ host tarafında bekliyor.

## Uygulamada sapmalar ve ölçümler (2026-11-01)

- `Context.OnLog/OnMessage/OnConfirm` adları (spec'te `OnLog/ConfirmProc`); `OnMessage` nil → `MessageDlg`.
- `Param` facade sınıfı `TRadScriptParams` (model sınıfı `TRadScriptParam` ile çakışmasın); store'a
  `ParamsOf(APackageIds)` eklendi, `LoadPackages` taranmaz.
- Facade nesnelerinin sahibi motor (`TRadScriptEngine.AddOwned`); binder `OnInstallFacade`, jobs `OnPrepare`
  ile kurulur (`TRadScriptFacade.Bind` / `PrepareProc`). Motor `PackageIds` taşır.
- **Create/Free/Destroy her sınıftan silinir**: RTTI kaydı TObject'in bu metotlarını her sınıfa kopyalıyordu
  (`docs/script-api.md` ilk üretimde `Free()` listeliyordu); script nesne yaratamaz/yıkamaz.
- DevExpress editörlerinin olayları `Properties` alt nesnesindedir; binder `edt_OnValidate` adını
  `edt.Properties.OnValidate`'e çözer (tipli kanca testi bunu buldu).
- `TcxEditValidateEvent` adaptörü `ErrorText`'i yalnız script `Msg.HataMetni` koyduysa değiştirir.
- `TRadScriptBinder.LoadInto` (yükle + derle + facade) `Attach` ve `TRadScriptCommands.Attach`'ın ortak
  çekirdeği; `ClassChain` `TComponent`/`TDataModule`'e kadar yürür (modüller için).
- `TRadScriptDev.RegisterAll` 24 sınıf; `dxLayoutControl`/`cxPC` paketleri RS37'de `cxLibraryRS37` içinde,
  `RadScriptTms` requires: `dxCoreRS37, cxLibraryRS37, cxGridRS37, dac370, unidac370, RadKon, TMSScripter`.
- Script içinde `BoolToStr` yok (TMS `ap_SysUtils` kapsamı); skill'e yazıldı.

| Ölçüm | Sonuç |
|---|---|
| Motor kurulumu (24 DevExpress + facade + VCL sınıfları, DefineClassByRTTI) | 5 ms |
| `docs/script-api.md` | 1.068 satır, `Free/Create/Destroy` 0 |
| FacadeTest (PG canlı) | 24/24 Win32, 24/24 Win64 |
| FacadeVclTest (DevExpress) | 7/7 Win32 |
| Regresyon | HooksTest 34/34 Win32+Win64, ScriptLiveTest 78/78 Win32 |

## Kabul ölçütleri (EARS)

Testler `src/test/scratch/rad_script_facade/`: `FacadeTest` (PG `testdb` canlı; MSSQL/FB aynı
senaryolar), `TypedHookTest` (VCL + DevExpress), `CommandsTest`, Win32 + Win64 (DevExpress testi Win32).

1. **WHEN** script `Db.Sorgu('select ad from t where id = :id').Param('id', 3).Deger` çağırır
   **THE SYSTEM SHALL** parametreli sorguyu çalıştırıp değeri döndürür; `Param` adı yoksa `ERadScript`.
2. **WHEN** script `Db.Sorgu(...).Ac` ile dataset açar ve `Kapat` demez **THE SYSTEM SHALL**
   form/çalıştırma sonunda sorguyu serbest bırakır (sızıntı yok, `ReportMemoryLeaksOnShutdown`).
3. **WHEN** `Db.BaslaIslem` sonra `Db.GeriAl` **THE SYSTEM SHALL** DML'i geri alır; `BaslaIslem`
   zaten transaction içindeyken `ERadScript`.
4. **WHEN** `Msg.Soru` KP'de (`ConfirmProc = nil`) çağrılır **THE SYSTEM SHALL** `False` döner,
   diyalog açmaz.
5. **WHEN** `Param.Deger('MailAdresi')` çağrılır **THE SYSTEM SHALL** bağlı paketin parametresini
   döner; tanımsızda `''`, `DegerVarsayilan` verileni.
6. **WHEN** `Mail.Gonder` `Mailer = nil` iken çağrılır **THE SYSTEM SHALL** `ERadScript` ("posta
   ayarlanmadı"); sahte mailer ile çağrı kaydedilir.
7. **WHEN** `komut` script'i `Tkasa_modul` için varsa **THE SYSTEM SHALL** `AAdd`'i kod/ad ile
   çağırır, handler `<Kod>_Execute`'u çalıştırır, modül yıkılınca motor serbest kalır.
8. **WHEN** `Form_OnCloseQuery_Before` `False` döner **THE SYSTEM SHALL** `CanClose := False` yapar,
   orijinal `OnCloseQuery` çalışmaz; `True` dönerse sıra `Before, orijinal, After`.
9. **WHEN** `edt_OnValidate_Before` `False` döner ve `Msg.HataMetni('x')` koymuşsa **THE SYSTEM SHALL**
   `Error := True`, `ErrorText = 'x'`.
10. **WHEN** `TRadScriptUni.RegisterAll` çağrılır **THE SYSTEM SHALL** script `TUniConnection.Password`
    erişiminde derleme hatası alır ("Unknown member"), `Connected` okunur.
11. **WHEN** `ExportReference` çağrılır **THE SYSTEM SHALL** kayıtlı her sınıf için `## TSınıf`
    başlığı ve üye imzaları olan Markdown üretir; `Db.Sorgu`, `Msg.Soru` listede.
12. **WHEN** facade metotları RTTI ile kaydedilir **THE SYSTEM SHALL** her metot script'ten tam
    parametreyle çağrılabilir (overload/varsayılan yok testi: kaydedilen metot sayısı = bildirilen).

## İşlevsel olmayan

- Facade sınıfları `TObject` (TComponent değil), script'e `Free` açılmaz.
- `Db` çağrıları script thread'inde; KP'de thread başına bağlantı host'un sorumluluğu (`Context`
  klonu `TRadScriptJobs.OnPrepare`'da verilir: `ContextFactory: TFunc<TRadScriptContext>`).
- Public API'de overload/varsayılan parametre yok; `ExportReference` çıktısı bunu kanıtlar.

## Kapsam dışı (4. aşama)

Tasarımcı/IDE (5-6), p-code, script formu DFM editörü, DevExpress grid olayları dışındaki tipli
olaylar (liste uzatılabilir), rapor/FastReport facade'ı, dosya/HTTP facade'ı (ihtiyaç çıkınca).
