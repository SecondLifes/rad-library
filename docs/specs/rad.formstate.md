# Specification: `rad.formstate` — form ve DataModule durumunu JSON olarak saklama

Durum: **onaylandı, uygulanıyor** (2026-11-03). Kullanıcı kararları: thread sistemi yok; mORMot
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

`StoredValue[...]` yazımda her tipi kabul eder, okumada JSON tipini döndürür. Ölçülen kayıplar:
`varDate` → ISO metin, `Currency` → double. Bu yüzden tipli okuyucular var:
`GetDate`, `GetCurrency`, `GetInteger`, `GetString`, `GetBoolean` (hepsi varsayılan değerli).

## Yaşam döngüsü

| Sahip | Yükleme | Kayıt |
|---|---|---|
| `TForm` | `props`, `values`, `custom`: `OnCreate` öncesi. `form`: ilk `OnShow` öncesi (handle ve DPI hazır) | `OnCloseQuery` (`CanClose = True`), kaydedilmemişse `OnDestroy` başında |
| `TDataModule` | `OnCreate` öncesi | `OnDestroy` başında |

- Kanca yalnız `Loaded` içinde ve yalnız runtime'da takılır (`FHooked`). Söküm, olay hâlâ bize aitse
  yapılır; aksi halde dokunulmaz. Runtime'da oluşturulan bileşen kanca takmaz; host `Load`/`Save`
  çağırır.
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
| `TRadFileStateStore` | varsayılan `%LOCALAPPDATA%\<exe>\state\<scope>\<Class>.state` | Geçici dosya + `MoveFileEx(REPLACE)`; okunamayan kayıt yok sayılır, loglanır, sonraki kayıt üstüne yazar |
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
  olay) pasif ve gerekçesi ipucunda.
- Sağ: seçili yolların sıralanabilir listesi (apply sırası anlamlı: `Align` önce, boyut sonra).
- Hazır seçimler: "Pencere", "Splitter konumları", "Sayfa (ActivePageIndex)".
- Sekmeler: Özellikler, Değerler (`StoredValues`), Seçenekler (`Options`, `Version`).
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
TRadFormState.Kur(TRadFormState.DbStore(dm.Connection), 'emrah', {Encrypt=}True);
TRadFormState.Prefetch;   // isteğe bağlı, veritabanında önerilir
...
TRadFormState.Kapat;      // iki kez çağrılabilir
```

  `Kur` önceki kurulumu önce kapatır. `FileStore(AFolder)`, `DbStore(AConnection, ATable)`,
  `CallbackStore` yardımcıları yalnız oluşturup döndürür.
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

**A3 — bileşen + giriş birimi**
- [ ] `TRadPropertiesStore`, `Items`, `StoredValues`, olaylar, kanca/söküm, yerleşim.
- [ ] `rad.formstate` facade, `Rad.Register` güncellemesi.
- [ ] VCL testi `src/test/scratch/rad_formstate/` (ölçüt 1, 6, 7, 8, 10, 12; Win32 + Win64).
- [ ] Ölçüm: 300 yolluk apply Release Win32/Win64.

**A4 — veritabanı deposu (`rad.formstate.uni`)**
- [ ] Upsert, `LoadScope`.
- [ ] Canlı test: PostgreSQL `testdb`, SQL Server `rad_filter_test`, Firebird (Win32).

**A5 — tasarım editörü**
- [ ] DFM + editör kodu, bileşen ve özellik editörü kaydı.
- [ ] IDE'de elle doğrulama (kullanıcı): seçim, sıralama, arama, İptal'in hiçbir şey değiştirmemesi.

**A6 — kapanış**
- [ ] `TRadActionList` için `IRadStateful`.
- [ ] Bu spec'in durum satırı, `CHANGELOG.md`, `src/README.md`.

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
