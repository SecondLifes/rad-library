# Specification: `rad.formstate` — form ve DataModule durumunu JSON olarak saklama

Durum: **uygulandı** (2026-11-03, A0–A6). Açık kalan tek madde: tasarım editörünün IDE içinde
kullanıcı tarafından denenmesi (A5). Kullanıcı kararları: thread sistemi yok; mORMot
`E:\system\dev\Delphi\src\git\synopse\mORMot2` (en güncel kopya, `RadKon.dproj`'un da kullandığı).
`src/component/rad.vcl.pas` içindeki çalışma kopyası (DevExpress `cxPropertiesStore` türevi, commit
edilmedi) bu sistemle **değiştirilir**, genişletilmez.

## Bağlam

Kullanıcının seçtiği bileşen özelliklerini (genişlik, sütun, splitter konumu, son seçim...), pencere
yerleşimini ve elle verilen anahtar/değer çiftlerini form kapanırken kaydedip açılırken geri yüklemek.
Kayıt yeri değiştirilebilir (dosya, host fonksiyonu, veritabanı), içerik şifrelenebilir.

İncelenen örnekler ve alınan dersler (kod alınmadı, yalnız davranış):

| Kaynak | Alınan | Alınmayan |
|---|---|---|
| JVCL `JvFormPlacement` (MPL 1.1) | `GetWindowPlacement` ile normal sınırlar, ekran dışı kontrolü, `Version`, "restore edilmeden kaydetme", `CanClose` + `OnDestroy` iki aşamalı kayıt | Tüm hataları yutan `except` (satır 1039), değer başına XOR "şifreleme" (1177), PPI farkında yerleşimi atma |
| JVCL `JvFormPropertiesForm` | Sıralanabilir seçili liste, pencere seçenekleri | Yalnız üst düzey özellik, İptal'den önce `Designer.Modified` |
| DevExpress `cxPropertiesStore` | Bileşen referansıyla saklama (ad değişikliğine dayanıklı), DPI farkında ölçekleme | Pencere yerleşimi yok |
| DevExpress `cxPropertiesStoreEditor` | Üç durumlu ağaç, bileşene/özelliğe göre gruplama, tümünü seç, sıfırla | Tanımlı ama kullanılmayan `Filter`, koleksiyon öğesi seçilememesi |

İki kütüphanede ortak hata: bileşen runtime'da oluşturulursa `Loaded` çalışmaz, ama destructor formun
`OnCreate`/`OnDestroy` olaylarını yine geri yazar ve onları siler (cx'te tasarım anında da).

### Ölçümler (Delphi 37.0 Win32, `-$O+`, 50 `TEdit`, 300 özellik, 5,6 KB JSON, yerel disk)

| Adım | Süre |
|---|---|
| Capture (mORMot RTTI, tek `TJsonWriter`) | 0,047 ms |
| JSON parse (`DocDict`, `mFastFloat`) | 0,015 ms |
| AES-GCM şifrele / çöz (`TAesGcm.MacAndCrypt`) | 0,005 / 0,006 ms |
| Dosya yaz + oku | 0,10 ms; geçici dosya + yeniden adlandırma 0,41 ms |
| **Apply, değerler değişirken, kilitsiz** | **40,6 ms** |
| **Apply, `DisableAlign` + `WM_SETREDRAW`** | **15,4 ms** |

Maliyetin tamamı VCL setter'larında ve ana thread'e bağlı; dosya ve şifreleme önemsiz. Bu yüzden thread
yok. Veritabanı gecikmesi ve gerçek grid ölçülmedi; veritabanında her form açılışında bir sorgu yerine
girişte tek sorguluk senkron `Prefetch` var.

### Doğrulanmış mORMot davranışları

`.agents/skills/mormot2-integration/references/verified-api-traps.md` → "Reading and writing single
published properties of VCL objects". Özet: `ObjectToJson`, `GetInstanceByPath`, `GetValueText`,
`PropertyFromJson`, `DocVariantToObject` bu iş için kullanılmaz. Çalışan yol: kendi yol çözücü
(`Props.Find` + `GetObjProp` + `TCollection.Items[]`), okumada `AddValueJson(woEnumSetsAsText)`, yazmada
`JsonToObject(LInst, '{"Leaf":değer}')`; sınıf yaprağında `GetObjProp` + `JsonToObject`.

## Kararlar

1. **Anahtar:** `Scope` + `ClassName` (+ isteğe bağlı `StorageName` eki). `Owner.Name` kullanılmaz:
   aynı formun ikinci örneği `Form1_1` olur (`System.Classes` → `FindUniqueName`). `OnGetKey` ile
   değiştirilebilir.
2. **Scope:** ayrı alan (kullanıcı/şirket, ör. `emrah`). Anahtar metin değil kayıt tipidir; her depo
   kendi kurallarıyla temizler (`..`, `\`, `/`, `:`, ayrılmış Windows adları).
3. **Thread yok.** Yükleme ve kayıt ana thread'de, senkron.
4. **Veritabanı:** host'un bağlantısı kullanılır; tablo adı ayarlanabilir; çekirdek UniDAC'a bağlanmaz.
5. **Taban sınıf:** düz `TComponent`; runtime kodunda DevExpress yok. Editör tasarım paketinde,
   DevExpress kontrolleriyle (DFM).
6. **Bileşen adı korunur:** `TRadPropertiesStore` (palette kayıtlı; repoda onu kullanan DFM yok).
7. **Paket:** editör `RadKon` içinde, `Rad.Editor` yanında. `RadKon`'un runtime + `designide`
   karışımı (`component-patterns.md` ihlali) ayrı bir iş.

## Birimler

| Birim | Bağımlılık | İçerik |
|---|---|---|
| `src/core/rad.formstate.core.pas` | RTL, mORMot | `TRadStateKey`, yol çözücü + capture/apply (`TRadStatePaths`), doküman kuralları (`TRadStateDoc`), `TRadStateScale`, `IRadStateful` |
| `src/core/rad.formstate.store.pas` | `rad.formstate.core`, `rad.cipher` | `IRadStateStore`, `TRadFileStateStore`, `TRadCallbackStateStore`, şifreleme zarfı, önbellek + `Prefetch`, hash ile yazma atlama |
| `src/vendor/unidac/rad.formstate.uni.pas` | UniDAC | `TRadUniStateStore` (PostgreSQL, SQL Server, Firebird) |
| `src/component/rad.formstate.component.pas` | VCL, yukarıdakiler | `TRadPropertiesStore`, öğe ve değer koleksiyonları, olay zinciri, pencere yerleşimi |
| `src/component/rad.formstate.pas` | hepsi | **Giriş birimi:** alias'lar + `TRadFormState.Kur/Kapat/Prefetch` |
| `src/packages/rad.formstate.editor.pas` + `.dfm` | DesignIntf, DevExpress | Tasarım editörü, bileşen ve özellik editörü |

`rad.vcl.pas` HEAD'deki boş haline döner; `Rad.Register` yeni birimi kaydeder.

## Doküman şeması (`schema = 1`)

```json
{
  "schema": 1,
  "version": 3,
  "key": "emrah\\TLoginForm",
  "class": "TLoginForm",
  "ppi": 144,
  "savedAt": "2026-11-03T10:00:00Z",
  "form":   { "state": "wsNormal", "normal": [100, 80, 900, 700], "activeControl": "edtKod" },
  "props":  { "edtKod": { "Width": 111, "Font.Style": ["fsBold"], "Panels.0.Width": 77 } },
  "values": { "sonSekme": 2, "sonTarih": "2026-11-03T12:00:00" },
  "custom": { "ActionList1": { } }
}
```

- `props` altında anahtar, yolun kendisidir (düz `"Font.Size"`); `PathDelim` ağacı kurulmaz.
- Enum ve set'ler adla yazılır (`woEnumSetsAsText`).
- `custom`: `IRadStateful` uygulayan bileşenlerin kendi verisi (`TRadActionList` ilk örnek).
- Doküman modeli `mFastFloat`. `mFastExtended` kullanılmaz (tırnaksız anahtar üretir).

Kurallar:

- `schema` desteklenenden büyükse doküman tümden yok sayılır ve loglanır.
- `version` bileşendeki `Version` ile eşit değilse `form` ve `props` atlanır, **`values` korunur**.
- `ppi` farklıysa `form.normal` ölçeklenir; `props` içindeki `Left/Top/Width/Height/ClientWidth/
  ClientHeight` yaprakları ölçeklenir, diğerleri olduğu gibi.
- Geri yüklemede JSON anahtarları değil bileşenin `Items` listesi dolaşılır: düzenlenmiş bir dosya
  listede olmayan özelliği (`Name` dahil) yazamaz.
- Tek bir yolun hatası diğerlerini durdurmaz; hata metni sonuçta döner ve loglanır.

## `Variant` değerleri

`StoredValue[...]` yazımda her tipi kabul eder. JSON tipi korumaz: `varDate` → ISO metin,
`Currency` → double (ölçüldü). Bu yüzden her `StoredValues` öğesinin bir `ValueType`'ı var
(`svtVariant` varsayılan, `svtString`, `svtInteger`, `svtFloat`, `svtDateTime`, `svtBoolean`):

- Okuma sırası: çalışma anı değeri → tasarım varsayılanı (`Value`) → türün boş değeri (`''`, `0`,
  `0.0`, tarih `0`, `False`). Çevrilemeyen bir değer bir sonrakine düşer; istisna yok.
- `svtVariant` ve bildirilmemiş ad JSON'daki tipi döndürür, hiçbir şey yoksa `Null` (eski davranış).
- Metin çözme (`TRadStoredValue.Convert`): sayı önce değişmez (`1.5`), sonra yerel biçim; tarih önce
  ISO 8601 (JSON'un sakladığı), sonra yerel; mantıksal `True/False/0/1`. Kesirli metin tamsayıya
  çevrilmez (`4.2` → başarısız), sessiz kırpma yok.
- `GetInteger/GetDouble/GetString/GetBoolean/GetDate` kendi türlerine aynı zincirle çevirir; hiçbiri
  yoksa çağıranın varsayılanını döndürür.

## Yaşam döngüsü

| Sahip | Yükleme | Kayıt |
|---|---|---|
| `TForm` | `form`, `props`, `values`, `custom`: kullanıcının `OnCreate`'inden önce. `activeControl`: ilk `OnShow`'da | `OnCloseQuery` (`CanClose = True`), kaydedilmemişse `OnDestroy` başında |
| `TDataModule` | `OnCreate` öncesi | `OnDestroy` başında |

- Yerleşim `OnShow`'da değil `OnCreate`'te uygulanır: VCL `CMShowingChanged` içinde `DoShow`'u
  ortalamadan **önce** çağırıyor, `poScreenCenter` yerleşimi ezerdi. `OnCreate`'te handle yok;
  `Position := poDesigned` yeniden pencere oluşturmadan yazılır.
- Kanca yalnız `Loaded` içinde ve yalnız runtime'da takılır; sahip başına **tek** gizli kanca
  bileşeni (`TRadStateHook`) olayları bir kez alır, tüm store'lar ona kayıt olur. Böylece iki store
  birbirinin işleyicisini zincirlemez; hangisi önce serbest kalırsa kalsın diğeri ve formun kendi
  olayları sağlam kalır. Son store ayrılınca kanca olayları, hâlâ kendisinde ise geri verir.
  Runtime'da oluşturulan store kanca takmaz; host `Load`/`Save` çağırır.
- `TRadFormState.Kapat`, yüklenip henüz kaydetmemiş açık store'ları kaydeder: uygulama kapanırken
  açık kalan formlar aksi halde depo serbest kaldıktan sonra yok edilir.
- `Kur` çağrılmadıysa varsayılan dosya deposu (`%LOCALAPPDATA%\<exe>\state`) kullanılır; `Kapat`
  sonrasında store'lar hiçbir şey yazmaz.
- `Restored = False` iken (hata ya da kayıt yok değil, hiç yüklenmemiş) kayıt yapılmaz: hatalı açılan
  formun kullanıcı ayarlarını varsayılanla ezmemek için.
- Apply sırasında form `DisableAlign` + `WM_SETREDRAW` kilidinde.
- Kayıt, kullanıcının `OnDestroy`'undan **önce**: kullanıcı kodu yoldaki nesneleri serbest bırakabilir.

## Olaylar

```pascal
TRadStateEvent = procedure(Sender: TRadPropertiesStore; const ABefore: Boolean) of object;
TRadStateKeyEvent = procedure(Sender: TRadPropertiesStore; var AKey: TRadStateKey) of object;
```

- `OnLoad(Sender, True)`: doküman okundu, uygulanmadı (`Sender.Doc` değiştirilebilir).
  `OnLoad(Sender, False)`: uygulandı.
- `OnSave(Sender, True)`: capture öncesi (son `StoredValue` yazımları burada).
  `OnSave(Sender, False)`: depoya yazıldı.

## Depolar

```pascal
IRadStateStore = interface
  function Load(const AKey: TRadStateKey; out AData: RawByteString): Boolean;
  procedure Save(const AKey: TRadStateKey; const AData: RawByteString);
  procedure Delete(const AKey: TRadStateKey);
  function LoadScope(const AScope: RawUtf8): TRadStateEntries;   // Prefetch için
end;
```

Depolar bayt taşır; şifreleme bu yüzden üçüne de aynı şekilde uygulanır.

| Depo | Yer | Notlar |
|---|---|---|
| `TRadFileStateStore` | varsayılan `%LOCALAPPDATA%\<exe>\state\<scope>\<Class>.state`; `FileStore(srExeFolder, 'ayar')` exe yanı, klasör boşsa kökün kendisi | Geçici dosya + `MoveFileEx(REPLACE)`; okunamayan kayıt yok sayılır, loglanır, sonraki kayıt üstüne yazar |
| `TRadCallbackStateStore` | `TRadFormState.DoSave/DoLoad` class var fonksiyonları | Host'un kendi saklama yolu |
| `TRadUniStateStore` | tablo (ad ayarlanabilir) | `UPDATE`, etkilenen satır 0 ise `INSERT` (üç DB'de aynı); host'un bağlantısı |

Tablo (PostgreSQL; SQL Server `varbinary(max)`/`datetime2`, Firebird `blob sub_type 0`/`timestamp`):

```sql
create table rad_form_state (
  scope      varchar(100) not null,
  form_key   varchar(200) not null,
  payload    bytea        not null,
  updated_at timestamp    not null,
  primary key (scope, form_key)
);
```

Tabloyu bileşen oluşturmaz; DDL host'un migration'ına girer.

### Önbellek, `Prefetch`, yazma atlama

- `TRadFormState.Prefetch(Scope)`: `LoadScope` ile tek sorguda okur, belleğe alır (senkron). Form önce
  önbelleğe bakar, yoksa depodan tek kaydı okur. Kayıt önbelleği günceller.
- Payload bir önceki yazılanla aynıysa (hash) depoya yazılmaz.

## Şifreleme

- Zarf: düz JSON `{` ile başlar; şifreli payload `RADS` + sürüm baytı + `IRadCipher` çıktısı.
  Okuyucu ikisini de tanır, böylece şifreleme sonradan açılabilir.
- Varsayılan: `rad.cipher` `TRadAesGcmCipher` (kurcalama yakalanır). Sınır: anahtar uygulamada
  gömülü, yani at-rest gizleme; EXE'ye sahip olan açar.
- Kurcalama/çözme hatası: kayıt yok sayılır, loglanır; form varsayılanla açılır.
- Şifreli payload veritabanında `jsonb` olamaz; bu yüzden tablo bayt tipinde.

## Tasarım editörü

DFM ile, DevExpress kontrolleriyle. Bileşen editörü fiili + `Items` için `paDialog` özellik editörü.

- Sol: sahip bileşenlerin ağacı, üç durumlu onay; bileşene veya özelliğe göre gruplama; koleksiyon
  öğeleri (`Panels.0.Width`) dahil.
- Yazarken süzen arama; "yalnız seçililer" filtresi.
- Her satırda tip ve mevcut değer; geri yüklenemeyen özellik (setter yok, `TComponent` referansı,
  desteklenmeyen tür) pasif ve gerekçesi değer sütununda. Olaylar hiç listelenmez.
- Sağ: seçili yolların sıralanabilir listesi (apply sırası anlamlı: `Align` önce, boyut sonra).
- Hazır seçimler: "Pencere", "Splitter konumları", "Sayfa (ActivePageIndex)".
- Sekmeler: Özellikler, Değerler (`StoredValues`: Ad, Tür, Varsayılan değer), Seçenekler (`Options`, `Version`).
- `Designer.Modified` yalnız Tamam'da.
- Tasarım anında mORMot `Rtti` çağrılmaz (sınıfların VMT'sine yazar); editör `TypInfo` kullanır.

## Entry Unit and Setup Call

- **Giriş birimi:** `rad.formstate` (tüketicinin eklediği tek birim; bileşen forma bırakılınca IDE
  `rad.formstate.component`'i kendisi ekler).
- **Re-export:** `TRadPropertiesStore`, `IRadStateStore`, `TRadStateKey`, `TRadFileStateStore`,
  `TRadCallbackStateStore`, `TRadUniStateStore`, `IRadStateful`, `TRadStateEvent`,
  `TRadStateKeyEvent`.
- **Alias olamayan:** `TRadStateOption` değerleri → gerçek sabitler (`soPlacement = ...`);
  `TRadStateEntries` açık generic değil, alias'lanır.
- **Kurulum:**

```pascal
uses rad.formstate;
TRadFormState.Kur(TRadFormState.FileStore, 'emrah', TRadAesGcmCipher.Create(AppKey));
TRadFormState.Prefetch;   // isteğe bağlı, veritabanında önerilir
...
TRadFormState.Kapat;      // açık formları kaydeder; iki kez çağrılabilir
```

  **A8 (2026-11-03) — form başına depo:** `Kur` yalnız varsayılan depoyu verir.
  `TRadFormState.AddStorage(AName, AStore, ACipher)` açılışta adlı depolar ekler; store'un published
  `Storage` özelliği adı seçer (büyük/küçük harf duyarsız), boşsa varsayılan. Eklenmemiş ad: okuma ve
  yazma yok, `Errors`'a satır; varsayılana düşmek veriyi yanlış yere yazacağı için reddedildi. Scope
  kullanıcının kimliğidir, depo ayarı değildir: global kalır.

  `Kur` önceki kurulumu önce kapatır; şifreleme anahtarı uygulamanındır (`rad.cipher`), bu yüzden
  parametre boolean değil `IRadCipher`. `FileStore(AFolder)`, `FileStore(srLocalAppData|srExeFolder,
  AFolder = 'state')`, `CallbackStore` (A4: `DbStore`)
  yardımcıları yalnız oluşturup döndürür.
- **Kabul:** host yalnız `rad.formstate` ekleyip `Kur` çağırarak sistemi çalıştırır; test ile kanıtlanır.

## Kabul ölçütleri (EARS)

1. **WHEN** form kapanıp aynı sınıfla yeniden açıldığında **THE SYSTEM SHALL** `Items` içindeki her yolu,
   `form` yerleşimini ve `StoredValues`'u kaydedildiği değere döndürmek.
2. **WHEN** yol bir getter'lı sınıf özelliği, set, enum, `TStrings` veya koleksiyon indeksi içerdiğinde
   **THE SYSTEM SHALL** gidiş-dönüşte değeri korumak.
3. **WHEN** kayıttaki `version` bileşenden farklı olduğunda **THE SYSTEM SHALL** `form` ve `props`'u
   atlamak, `values`'u yüklemek.
4. **WHEN** kayıt dosyası `Items`'ta olmayan bir anahtar içerdiğinde **THE SYSTEM SHALL** o anahtarı
   uygulamamak.
5. **WHEN** kayıt şifreli ve tek bir bayt değiştirilmiş olduğunda **THE SYSTEM SHALL** kaydı yok
   sayıp formu varsayılanla açmak ve olayı loglamak.
6. **WHEN** bileşen runtime'da oluşturulup canlı formda serbest bırakıldığında **THE SYSTEM SHALL**
   formun `OnCreate`, `OnShow`, `OnCloseQuery`, `OnDestroy` olaylarını değiştirmemek.
7. **WHEN** aynı forma iki bileşen bırakıldığında ve biri önce serbest bırakıldığında **THE SYSTEM
   SHALL** diğerinin kancasını ve formun orijinal olaylarını bozmamak.
8. **WHEN** kaydedilen pencere hiçbir monitörde görünmediğinde **THE SYSTEM SHALL** yerleşimi
   uygulamamak.
9. **WHEN** payload son yazılanla aynı olduğunda **THE SYSTEM SHALL** depoya yazmamak.
10. **WHEN** restore hiç yapılmamışken form kapandığında **THE SYSTEM SHALL** kaydetmemek.
11. **WHEN** Scope `..\x` veya geçersiz karakter içerdiğinde **THE SYSTEM SHALL** dosya deposunda
    kök klasörün dışına yazmamak.
12. **WHEN** sahip `TDataModule` olduğunda **THE SYSTEM SHALL** `props`, `values`, `custom`'ı
    saklamak, `form` bölümünü yazmamak.
13. **WHEN** bir yolun setter'ı istisna fırlattığında **THE SYSTEM SHALL** kalan yolları uygulamaya
    devam etmek ve hatayı sonuçta bildirmek.

## İşlevsel olmayan

- **Hız:** 300 yolluk apply, Release Win32'de ≤ 20 ms (ölçülen 15,4 ms). Kayıt, dosya deposunda
  I/O dahil ≤ 2 ms.
- **Uyumluluk:** Delphi 13+, Win32 ve Win64; VCL. FMX ve TFrame kapsam dışı.
- **Veritabanı:** PostgreSQL, SQL Server, Firebird (Firebird yalnız Win32 test edilir, 32-bit
  `fbclient`).

## Aşamalar ve görevler

Her aşama kendi testiyle kapanır; bir aşama bitmeden sonrakine geçilmez.

**A0 — temizlik** (2026-11-03, tamam)
- [x] `src/component/rad.vcl.pas` HEAD'deki haline döndü (çalışma kopyası scratchpad'e yedeklendi).
- [x] `Rad.Register` kaydı A3'e kadar yorumda.

**A1 — çekirdek (`rad.formstate.core`)** (2026-11-03, tamam)
- [x] `TRadStateKey`.
- [x] Yol çözücü: `Props.Find`, `GetObjProp`, koleksiyon indeksi.
- [x] Capture (tek `TJsonWriter`), apply (yaprak türüne göre, yol başına hata yalıtımı), ppi ölçeği.
- [x] `TRadStateDoc`: `schema`/`version` kuralları, doküman iskeleti; `IRadStateful`.
- [x] DUnitX `src/test/unit/rad.formstate.core.Tests.pas`, koşucu `src/test/scratch/rad_formstate/`
  (ölçüt 2, 3, 4, 13): 20/20 Win32 + Win64, sızıntı yok.

**A2 — depolar (`rad.formstate.store`)** (2026-11-03, tamam)
- [x] Dosya deposu (atomik yazma, temizleme), callback deposu.
- [x] Şifreleme zarfı (düz/şifreli tanıma, algoritma etiketi).
- [x] `TRadStateRepository`: önbellek, `Prefetch`, hash ile yazma atlama.
- [x] DUnitX `rad.formstate.store.Tests.pas` (ölçüt 5, 9, 11): 45/45 (A1 ile birlikte) Win32 + Win64.

**A3 — bileşen + giriş birimi** (2026-11-03, tamam)
- [x] `TRadPropertiesStore`, `Items`, `StoredValues`, olaylar, kanca/söküm, yerleşim.
- [x] `rad.formstate` facade, `Rad.Register` kaydı, `RadKon.dpk/.dproj` (ve örtük giren `rad.cipher`).
- [x] VCL testi `src/test/scratch/rad_formstate/RunFormStateVclTests` (DFM'li formlar ve DataModule;
  ölçüt 1, 6, 7, 8, 10, 12): 13/13 Win32 + Win64.
- [x] Ölçüm: 300 yol (50 `TEdit` × 6), görünür form, değerler değişirken.

**A4 — veritabanı deposu (`rad.formstate.uni`)** (2026-11-03, tamam)
- [x] Upsert, `LoadScope`, sağlayıcı başına DDL (`CreateTableSql`), giriş biriminde `DbStore`, `RadKon`.
- [x] Canlı test `RunFormStateDbTests`: PostgreSQL `testdb`, SQL Server `rad_filter_test` (Win32 + Win64),
  Firebird (yalnız Win32): 20/20.

**A5 — tasarım editörü** (2026-11-03, IDE doğrulaması dışında tamam)
- [x] `Rad.Editor.FormState.Model` (IDE'siz, `TypInfo`), `Rad.Editor.FormState` + `.dfm` (form),
  `Rad.Editor` içinde bileşen editörü ("Durum Editörü...") ve `Items` için `paDialog` özellik editörü.
- [x] IDE'siz test `RunFormStateEditorTests`: model + DFM'li form, 13/13 Win32 + Win64. `RadKon` Win32 derlendi.
- [ ] IDE'de elle doğrulama (kullanıcı): sağ tık fiili, Object Inspector'dan `Items`, seçim, sıralama,
  arama, İptal'in formu değiştirmemesi, Tamam sonrası DFM'e yazılma.

**A6 — kapanış** (2026-11-03, tamam)
- [x] `TRadActionList` için `IRadStateful` (`ToJson`/`LoadFromJson` biçimi aynen); editörde
  `IRadStateful` bileşenler için yolsuz "(durum)" satırı.
- [x] Bu spec'in durum satırı, `CHANGELOG.md`, `src/README.md`.

## Uygulamada sapmalar ve ölçümler

**A1 (2026-11-03)**

- `JSONPARSER_TOLERANTOPTIONS` `jpoNullDontReleaseObjectInstance` içermiyor; mORMot belgesine göre
  `null` iç içe nesneyi serbest bırakır. Yükleme seçenekleri buna `jpoNullDontReleaseObjectInstance` ve
  `jpoSetterNoCreate` ekler; ayrıca sınıf yaprağına gelen `null` doğrudan reddedilir. Bu koruma
  kaldırıldığında `null` iki yaprakta "uygulandı" sayıldı (test kırmızı).
- `JSONPARSER_TOLERANTOPTIONS` tipli sabit: ondan gerçek sabit türetmek E2026 veriyor; seçenekler bir
  fonksiyonda.
- Delphi DUnitX'i yalnız Win32 DCU olarak getiriyor (`lib\win32\release`; `source\DUnitX` yok). Koşucu
  `E:\system\dev\Delphi\src\git\VSoftTechnologies\DUnitX\Source` (`fbad5c9`) ile iki platformu da derler.
  `rad_cache_tvalue` koşucusu aynı nedenle derlenmiyor.
- Testlerin bağımsızlığı mutasyonla doğrulandı: `null` koruması, desteklenmeyen yaprak filtresi ve
  yol başına istisna yalıtımı ayrı ayrı kaldırıldı; her biri ilgili testi kırmızıya çevirdi.

**A2 (2026-11-03)**

- Dosya uzantısı `.json` değil `.state`: içerik şifreli olabilir.
- `.bad` yok: okunamayan kayıt yok sayılır ve loglanır (`LastError`, `TSynLog`), form varsayılanla
  açılır, sonraki kayıt üstüne yazar. Arayüze yalnız dosya deposunun anlamlı bulacağı bir işlem
  eklememek için.
- Önbellek, `Prefetch` ve hash, depoların üstünde tek sınıfta: `TRadStateRepository`. Depolar yalnız
  bayt taşır.
- Hash `savedAt` hariç içerikten alınır; `savedAt` yazma kararından sonra damgalanır. Yükleme de hash'i
  kaydeder, böylece değişmeden kapanan form diske hiç yazmaz.
- Zarf algoritma etiketini taşır (`rad.cipher`'ın istediği gibi); etiket uymazsa çözme denenmez.
- `DocDict(TDocVariantData)` zayıf referans döndürüyor; yerel kayıttan dönerken `DocDictCopy` şart.
  Zayıf referansla iki test kırmızıydı (`verified-api-traps.md`).
- Mutasyon: zayıf `DocDict`, hash atlama, dosya adı temizleme ve `Prefetch` kısa yolu ayrı ayrı
  kaldırıldı; her biri en az bir testi kırmızıya çevirdi. Temizleme kaldırılınca `FileNameOf`
  kök dışı yolu yine reddetti (ikinci savunma).
- `Save` ölçümü (≤ 2 ms hedefi) A3'te, gerçek form dokümanıyla alınacak.

**A3 (2026-11-03)**

- Ölçüm (dcc varsayılan seçenekler, `$O+`; Release yapılandırması değil):

  | | Kayıt (dosya dahil) | Yükleme + uygulama |
  |---|---|---|
  | Win32 | 0,89 – 1,17 ms | 14,22 – 15,00 ms |
  | Win64 | 0,87 ms | 12,38 ms |

  `WM_SETREDRAW` kilidi olmadan Win32 yükleme 25,21 ms idi; kilit spec'teydi ama ilk yazımda unutulmuştu.
- Yerleşim `OnCreate`'te (bkz. Yaşam döngüsü). `Position := poDesigned` kaldırılınca yeniden açılan
  form ortalandı ve test kırmızıydı: ölçülmüş bir sebep.
- `DestroyComponents`, `csFreeNotification` taşımayan çocuğu diğerlerine haber vermeden siliyor. Kanca
  her store'a `FreeNotification` ile bağlanmasaydı store ölü kancaya `Detach` çağırıyordu: dokuz test
  AV ile düştü.
- Sahip yok edilirken her çocukta `csDestroying` zaten var: öğe o anda silinmez, yalnız bileşen
  referansı unutulur (ölü bileşende `RemoveFreeNotification` çağrılmaz).
- `TRadStateItem.SetComponent`, eski bileşenin bildirimini yalnız başka öğe onu kullanmıyorsa kaldırır.
- `RadKon` Win32 MSBuild ile scratchpad'e derlendi (kurulu BPL'e dokunulmadı); yeni birimlerde uyarı yok.
  IDE'de paletten bırakma ve DFM'e yazma A5'te kullanıcıyla doğrulanacak.
- Mutasyon: kanca `FreeNotification`'ı, yüklemeden kaydetme koruması, `poDesigned` ve monitör kontrolü
  ayrı ayrı kaldırıldı; her biri en az bir testi kırmızıya çevirdi.

**A4 (2026-11-03)**

- Thread olmadığı için depo host'un bağlantısını kullanır; ayrı bağlantı (`_NewConnection`) yok.
- Yük `ftBlob` + `SetBlobData` ile yazılır, `Fields[i].AsBytes` ile okunur. 300 KB'lık, her bayt değerini
  (`#0` dahil) içeren yük üç veritabanında da birebir döndü.
- **PostgreSQL bulgusu:** `UseUnicode` yokken `'TCariForm.İkinci Ω'` anahtarı `'TCariForm.?kinci ?'` olarak
  saklandı. Yazma ve okuma aynı biçimde bozduğu için arama yine eşleşiyor, gidiş-dönüş testi geçiyor;
  ancak farklı Türkçe kapsamlar tek kayda düşebilir. Yalnız `LoadScope`'un döndürdüğü saklanan ad
  bunu gösterdi; test buna göre güçlendirildi. `UseUnicode=True` ile sorun yok. Depo bağlantıyı
  değiştirmez (alan sınıflarını tüm uygulama için değiştirir), yalnız `TSynLog` uyarısı yazar. Projedeki
  bağlantıların hiçbiri `UseUnicode` ayarlamıyor; diğer tabloların Türkçe metni için doğrulanmadı.
- SQL Server: `nvarchar` sütun + geniş parametre yeterli. ANSI parametre mutasyonu bu makinede Türkçe ile
  yakalanmadı (kod sayfası 1254); 1254 dışındaki `Ω` ile yakalandı.
- Ölçüm (yerel sunucular, 6 KB): kayıt PostgreSQL 0,25 ms, SQL Server 0,20 ms, Firebird 0,69 ms; okuma
  0,64 / 0,08 / 0,59 ms.
- Win64'te Firebird testleri atlanır (64-bit `fbclient` yok); DUnitX bunları "geçti" sayar.
- Mutasyon: yalnız `INSERT`, ANSI anahtar parametresi ve tablo adı doğrulaması ayrı ayrı bozuldu; her biri
  en az bir testi kırmızıya çevirdi.

**A5 (2026-11-03)**

- Editör iki birim: model (`TypInfo`, IDE ve DevExpress yok, test edilebilir) ve form (DFM). Bileşen ve
  özellik editörü sınıfları kurala uyarak `Rad.Editor.pas`'ta; formu yalnız `Execute` ile çağırırlar.
- DevExpress yalnız ağaçta: `TcxTreeList`, `OptionsView.CheckGroups`, düğüm başına `CheckGroupType :=
  ncgCheckGroup` + `AllowGrayed`, arama için yerleşik Find Panel (`fpdmAlways`, `fcbFilter`). Liste,
  sekmeler, düğmeler ve değer tablosu (`TValueListEditor`) sade VCL.
- Ağaç bileşen → yol adımları; "özelliğe göre grupla" yol → bileşenler. Geri yüklenemeyen yol (bileşen
  referansı, salt okunur, desteklenmeyen tür) listelenir ama düğümü kapalıdır, gerekçe değer sütununda.
  Derinlik 3 adım, koleksiyon başına 50 öğe.
- Hazır seçimler: "sayfa/sekme" (`ActivePageIndex`/`TabIndex`/`ItemIndex`'ten yazılabilir published olan ilki)
  ve "splitter boyutları" (kenara yaslı denetimin `Width`/`Height`'ı). "Pencere" hazır seçimi yerine
  Seçenekler sekmesindeki yerleşim kutusu.
- `TPageControl.ActivePageIndex` public, published değil: ne `TypInfo` ne mORMot yol çözücü görür.
  Hazır seçim `TabIndex`'i (published, `stored False`) seçer; `TabIndex` yazılınca aktif sayfa gerçekten
  değişiyor (test, ölçüldü).
- Grup düğümü işaretlenince `TcxTreeList` her alt düğüm için ayrı `OnNodeCheckChanged` yayınlıyor: grup
  için kendi özyinelemem kaldırıldığında test yine geçti (ölçüldü), kod buna göre sadeleşti.
- Değerler sekmesi metin düzenler; tamsayıya benzeyen değer `Integer`, diğerleri `string` saklanır.
- Kayıt sırası bileşen bazında gruplanır (store öğeleri bileşen başına); bileşenler arası sıra ilk görülüşe göre.
- Mutasyon: store'un kendini listelemesi ve bileşen referansının saklanabilir sayılması ayrı ayrı denendi;
  her biri testi kırmızıya çevirdi.

**A6 (2026-11-03)**

- `TRadActionList.SaveState` `ToJson`'ı, `LoadState` `LoadFromJson`'ı kullanır: kısayol eylem adıyla ya da
  `GlobalKey` ile. Store bunu form başına `custom` bölümünde saklar; bir `GlobalKey`'i formlar arasında
  paylaştırmak hâlâ `TRadActionList.OnLoad/OnSave`'in işi.
- Editör modeli `IRadStateful` bileşen için "(durum)" sözde yolu listeler; seçilince store'a yolsuz bir öğe
  yazılır. Böyle bir bileşenin herhangi bir öğesi varsa çalışma anında durumu zaten kaydedilir; editör de
  açılışta satırı işaretli gösterir.
- Testler: kısayol gidiş-dönüşü (VCL) ve "(durum)" satırı (editör), Win32 + Win64. `IRadStateful` bildirimi
  kaldırılınca kısayol testi kırmızı (`16467` yerine `0`).
- `rad.rtl.pas`'ın kendi eski kodunda ipuçları var (kullanılmayan `sc`, `GetActions`, `mormot.core.text`
  inline'ı); bu değişikliğin kapsamı dışında bırakıldı.

**A7 — kök ve değer türü (2026-11-03)**

- Kök ve klasör bileşen özelliği değil, `FileStore` parametresi. (A8 bunu değiştirdi: form başına
  depo artık adla seçiliyor.) `srExeFolder` Program Files altında yazılamaz; kayıt hatası loglanır, form kapanır.
- `ValueType` olmadan `StoredValue['when']` kaydedilen tarihi ISO metin olarak döndürüyordu (test bunu da
  sabitliyor). Bildirilince `varDate` döner.
- Bulunan hata: `GetInteger/GetDouble/GetDate/GetBoolean` kayıt ve varsayılan yokken `ADefault` yerine `0`
  döndürüyordu; mORMot `Variant` dönüştürücüleri `Null`'ı `0` sayıp başarı bildiriyor. Okuyucular artık
  `TRadStoredValue.Convert` kullanıyor.
- Editör Değerler sekmesi `TValueListEditor` yerine `TcxTreeList` (tür sütunu `TcxComboBoxProperties`,
  `lsFixedList`, öğeler enum sırasında; test sırayı enum adlarıyla karşılaştırır). Hücre düzenlemesi
  `HideEdit` ile işlenir; türe uymayan ya da tekrar eden ad `OnCloseQuery`'de Tamam'ı engeller.
- Mutasyon: tasarım varsayılanına düşme, değişmez sayı çözümü, editörde tekrar denetimi ve kökte sondaki
  ayırıcı ayrı ayrı bozuldu; her biri en az bir testi kırmızıya çevirdi.

## Riskler

- **`RadKon` hem runtime hem `designide`:** editör eklenince karışım büyür. Ayrıştırma ayrı iş.
- **Grid düzenleri** (`TcxGridDBTableView` sütunları) published özellik olarak saklanabilir ama
  ağırdır; ilk sürümde `IRadStateful` adaptörü yok.
- **Yavaş veritabanı:** senkron kayıt form kapanışını geciktirir; `Prefetch` yalnız yüklemeyi çözer.
  Ölçülmedi; A4'te ölçülecek.

## Kapsam dışı (ilk sürüm)

- Thread'li yükleme/kayıt.
- Registry/INI deposu, `MinMaxInfo`, `PreventResize`, değer başına şifreleme.
- TFrame, FMX.
- Katmanlı varsayılan (kullanıcı → şirket → DFM), makineye özel yerleşim, `OnMigrate`.
- Tasarım anında JSON önizleme (mORMot `Rtti` tasarım anında kullanılmıyor).
