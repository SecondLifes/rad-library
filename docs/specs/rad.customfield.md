# Specification: `rad.customfield` — tabloya çalışma zamanında özel alan ekleme

## Bağlam

ERP'de müşteri, `cari`/`stok` gibi tablolara kendi alanlarını ekler ("özel
alan"). Referans: Wolvox ERP'nin "Özel Alan Tanımları" (kategori → alan,
üretilen kolon adı `OZELALANTANIM_N`, kategori = sekme, "Ayar" düğmesi).
Değerler **gerçek kolon** olarak ana tabloda tutulur (karar 2026-10-31):
böylece grid, rapor, `rad.sqlfilter`, `TcxDB*` editörler ve UniDAC ek kod
olmadan çalışır. JSONB/EAV reddedildi (filtre/rapor ikinci sınıf kalır,
MSSQL/Firebird düşer).

İki birim:

| Birim | Bağımlılık | İçerik |
|---|---|---|
| `src/core/rad.customfield.pas` | RTL + `rad.sqlfilter` (lehçe enum'u); veri erişimi `Help.uni.pas` üzerinden | tanım modeli, kolon adı üretimi, lehçeye göre DDL, tanım tabloları CRUD, ana dataset'e kolon ekleme yardımcıları |
| `src/component/rad.dev.customfields.pas` (+`.dfm`) | DevExpress (`dxLayoutControl`, `cxDBEdit*`), `rad.dev` (`TRadCheckComboBox`) | `TRadCustomFieldsFrame`: layout/çubuk/düğmeler DFM'de, sekme-item-editör kodla; tip → editör eşlemesi, düzen kaydı |
| `src/component/rad.dev.customfielddesigner.pas` (+`.dfm`) | DevExpress | `TRadCustomFieldDesigner` tanım diyaloğu (tamamen DFM, davranış kodda) |

## Veri modeli

Tanım tabloları (ERP DB'sinde, Türkçe adlandırma, DB'nin geri kalanıyla uyumlu):

```
ozel_alan_grup   -- kategori = sekme
  id            integer  PK
  tablo_adi     varchar(63)  not null      -- 'cari'
  adi           varchar(100) not null      -- sekme başlığı
  sira          integer  not null default 0
  aktif_mi      boolean  not null default true
  unique (tablo_adi, adi)

ozel_alan
  id            integer  PK
  grup_id       integer  FK ozel_alan_grup
  tablo_adi     varchar(63)  not null      -- grup ile aynı; sorgu kolaylığı
  kolon_adi     varchar(63)  not null      -- 'ozel_7', üretilir, DEĞİŞMEZ
  baslik        varchar(100) not null      -- editör etiketi, serbestçe değişir
  veri_tipi     varchar(20)  not null      -- aşağıdaki tablo
  uzunluk       integer                    -- metin
  ondalik       integer                    -- ondalıklı
  zorunlu_mu    boolean  not null default false
  varsayilan    varchar(500)
  secenekler    text                       -- liste tipleri: satır başına "kod|başlık"
  filtrele_mi   boolean  not null default false
  sira          integer  not null default 0
  aktif_mi      boolean  not null default true
  olusturan, olusturma_zamani
  unique (tablo_adi, kolon_adi)

ozel_alan_duzen  -- kullanıcı başına layout (TdxLayoutControl.SaveToStream)
  tablo_adi     varchar(63), kullanici_id integer, duzen blob/bytea
  PK (tablo_adi, kullanici_id)
```

Kolon adı: `ozel_` + (tablo başına `max(N)+1`). Silinen numara yeniden
kullanılmaz; sayaç mevcut kolonlardan değil `ozel_alan`'dan okunur, ama DDL'den
önce `INFORMATION_SCHEMA`/sistem kataloğunda kolonun var olmadığı doğrulanır.

### Veri tipleri

| `veri_tipi` | PostgreSQL | MSSQL | Firebird | MySQL | Editör |
|---|---|---|---|---|---|
| `metin` | `varchar(n)` | `nvarchar(n)` | `varchar(n)` | `varchar(n)` | `TcxDBTextEdit` (`MaxLength=n`) |
| `not` | `text` | `nvarchar(max)` | `blob sub_type text` | `text` | `TcxDBMemo` |
| `tamsayi` | `integer` | `int` | `integer` | `int` | `TcxDBSpinEdit` |
| `ondalik` | `numeric(18,d)` | `numeric(18,d)` | `numeric(18,d)` | `decimal(18,d)` | `TcxDBCalcEdit` |
| `para` | `numeric(18,4)` | `numeric(18,4)` | `numeric(18,4)` | `decimal(18,4)` | `TcxDBCurrencyEdit` |
| `tarih` | `date` | `date` | `date` | `date` | `TcxDBDateEdit` |
| `saat` | `time` | `time` | `time` | `time` | `TcxDBTimeEdit` |
| `tarihsaat` | `timestamp` | `datetime2` | `timestamp` | `datetime` | `TcxDBDateEdit` (`ckDateTime`) |
| `evethayir` | `boolean` | `bit` | `boolean` | `tinyint(1)` | `TcxDBCheckBox` |
| `tekli` | `varchar(50)` | `nvarchar(50)` | `varchar(50)` | `varchar(50)` | `TcxDBImageComboBox` (kod → başlık) |
| `coklu` | `varchar(500)` | `nvarchar(500)` | `varchar(500)` | `varchar(500)` | `TRadCheckComboBox` (item `Value` = kod) |

`coklu` saklama biçimi: `|kod1|kod2|` — baş ve sonda da ayraç, böylece
`rad.sqlfilter.Contains(alan, '|kod1|')` tek kodu kesin bulur (`|a|` `|ab|`
ile çakışmaz). Ayraç `|`: hiçbir lehçede `LIKE` jokeri değil, `;` gibi deyim
ayracı da değil. Seçenek kodlarında `|` yasak (tanım diyaloğu reddeder).
`TRadValueList.Join`'a "çevre ayraç" seçeneği eklenir.

## İşlevsel gereksinimler

### Çekirdek API (`rad.customfield`)

```pascal
TRadCustomFieldType = (cfText, cfMemo, cfInteger, cfDecimal, cfMoney, cfDate,
  cfTime, cfDateTime, cfBoolean, cfSingleChoice, cfMultiChoice);

TRadCustomFieldDef = class            // bir ozel_alan satırı
  Id, GroupId: Integer; TableName, ColumnName, Caption: string;
  FieldType: TRadCustomFieldType; Length, Decimals: Integer;
  Required: Boolean; DefaultValue: string; Options: TArray<TPair<string,string>>;
  Filterable, Active: Boolean; Order: Integer;

TRadCustomFieldGroupDef = class       // bir ozel_alan_grup satırı + Fields

IRadCustomFieldStore = interface      // tanımların kaynağı; UniDAC uygulaması Help.uni'de
  function LoadGroups(const ATable: string; AIncludeInactive: Boolean): TObjectList<TRadCustomFieldGroupDef>;
  function AddField(ADef: TRadCustomFieldDef): TRadCustomFieldDef;   // kolon adı üretir, DDL + insert, tek transaction
  procedure UpdateField(ADef: TRadCustomFieldDef);                   // başlık/sıra/aktif/zorunlu/varsayılan/seçenekler; tip ve kolon adı DEĞİŞMEZ
  procedure ExtendLength(ADef: TRadCustomFieldDef; ANewLength: Integer); // yalnız genişletme
  // grup CRUD; düzen Load/Save(ATable, AUserId, AStream)

TRadCustomFieldDdl = class            // saf metin üretici, bağlantısız, birim test edilir
  class function AddColumn(ADialect: TRadSqlDialect; const ATable: string; ADef: TRadCustomFieldDef): string;
  class function AlterLength(...): string;
  class function ColumnExistsSql(ADialect; ATable, AColumn): string;
```

Ana dataset yardımcıları (`Help.uni`):

- `TUniConnection._CustomFieldColumns(ATable, AAlias): string` → `', c.ozel_1, c.ozel_2'`
  (baş virgüllü; alan yoksa `''`). Açık kolon listeli sorgular için UniDAC
  makrosu: `select c.id, c.kod &ozel from cari c` + `_ApplyCustomFieldMacro('ozel', 'cari', 'c')`.
- `TCustomDADataSet._EnsureCustomFields(ATable)`: dataset kapalıyken
  `FieldDefs.Update`, `Fields`'ta olmayan her `ozel_*` için `FieldDef.CreateField`.
  Persistent `TField` kullanan formlar için; dinamik field'lı formda işlemsiz.

### Frame (`TRadCustomFieldsFrame`)

| Üye | Anlam |
|---|---|
| `TableName: string` | tanımların ve kolonların tablosu |
| `DataSource: TDataSource` | ana dataset; editörler buna bağlanır |
| `Store: IRadCustomFieldStore` | tanım kaynağı; atanmamışsa sınıf düzeyindeki `DefaultStore` (uygulama açılışında bir kez) |
| `UserId: Integer` | düzen kaydı anahtarı |
| `CanDesign: Boolean` | "Ayar" düğmesi görünürlüğü (yetki) |
| `Rebuild` | tanımları yükle, layout'u sıfırdan kur, düzeni uygula |
| `ShowDesigner` | tanım diyaloğu; kapanınca `Rebuild` |
| `OnFieldAdded/OnFieldChanged: TNotifyEvent` | ana form dataset'ini yeniden açsın diye |

Kurulum: her aktif grup → `ldTabbed` kök grubu altında bir `TdxLayoutGroup`
(`Name = 'grp_' + grup_id`); her aktif alan → editör (`Name = 'ed_' + kolon_adi`,
`DataBinding.DataSource/DataField`) + `CreateItemForControl` (`Name = 'li_' + kolon_adi`,
`CaptionOptions.Text = baslik`). Sıra: `sira`, sonra `id`.
`BeginUpdate/EndUpdate` içinde.

Düzen: `Customization := True` (kullanıcı sürükler, gizler); popup'ta "Düzeni
kaydet" → `SaveToStream` → `Store.SaveLayout`; "Düzeni sıfırla" → kaydı sil +
`Rebuild`. `Rebuild` önce varsayılan düzeni kurar, kayıtlı düzen varsa
`LoadFromStream`, sonra **düzende olmayan yeni alanları** kendi grubunun
sonuna ekler (adlar deterministik olduğu için eşleşme `Name` üzerinden).

Tanım diyaloğu (Wolvox düzeni): sol kategori listesi (ad, aktif, sıra), sağ
alan listesi + alan formu (başlık, tip, uzunluk/ondalık, zorunlu, varsayılan,
seçenekler, filtrele, aktif, sıra). Kolon adı salt okunur. Tip kaydedildikten
sonra kilitlenir. Silme = `aktif_mi=false`; fiziksel `DROP COLUMN` yok.

### Filtre kipi (`Mode = cfmFilter`)

Aynı çerçeve, bağsız editörler; `DataSource` ve kancalar devre dışı; `FilterFlaggedOnly` (varsayılan
açık) yalnız `filtrele_mi` alanlarını gösterir. `ApplyFilter(AFilter, AAlias)` editör değerlerini
koşula çevirir, `ClearFilter` boşaltır, `HasFilterValues` değer var mı der:

| Tip | Editör | Koşul |
|---|---|---|
| metin, not | `TcxTextEdit` | `Contains` |
| tamsayı, ondalık, para, tarih, tarih-saat, saat | iki editör (`ed_ozel_N`, `ed_ozel_N_2`) | `Between` (tek taraf boş → `>=`/`<=`; tarih `WholeDay`) |
| evethayir | `TcxCheckBox` üç durumlu | gri = koşul yok; `Equal(True/False)` |
| tekli | `TcxImageComboBox` + "(tümü)" | `Equal(kod)` |
| coklu | `TRadCheckComboBox` | `BeginOr` … `Contains('|kod|')` … `EndOr` |

Boş editör koşul üretmez (`rfmSkipEmpty`). Düzen kaydı anahtarı `tablo:f`.

### Kabul ölçütleri (EARS)

1. **WHEN** `AddField` çağrılır **THE SYSTEM SHALL** `ozel_N` üretir, kolonun
   tabloda bulunmadığını doğrular, `ALTER TABLE` + `ozel_alan` insert'ini tek
   transaction'da yapar; biri başarısızsa ikisi de geri alınır
   (PG/MSSQL/Firebird transactional DDL; MySQL'de DDL geri alınamaz → belgelenir).
2. **WHEN** tanım `zorunlu_mu=true` **THE SYSTEM SHALL** kolonu `NULL`'a izinli
   yaratır; zorunluluk editörde (`Required`, kayıt öncesi kontrol) uygulanır.
   Gerekçe: mevcut satırlar için `NOT NULL` DDL'i başarısız olur.
3. **WHEN** `varsayilan` dolu **THE SYSTEM SHALL** değeri yeni kayıtta
   `OnNewRecord`'da yazar, DDL `DEFAULT` kullanmaz (mevcut satırlar değişmez,
   tip dönüşümü tek yerde).
4. **WHEN** `UpdateField` tip ya da kolon adı değiştirmeye kalkar
   **THE SYSTEM SHALL** `ERadCustomField` fırlatır.
5. **WHEN** `ExtendLength` yeni uzunluk eskisinden küçük **THE SYSTEM SHALL**
   hata fırlatır (daraltma yok).
6. **WHEN** `coklu` değer yazılır **THE SYSTEM SHALL** `|k1|k2|` biçimini
   üretir; boş seçim `NULL`.
7. **WHEN** `Rebuild` çağrılır ve kayıtlı düzen var **THE SYSTEM SHALL** düzeni
   yükler ve düzende bulunmayan aktif alanları ekler, pasif alanları göstermez.
8. **WHEN** `CanDesign=false` **THE SYSTEM SHALL** "Ayar" düğmesini gizler;
   düzen kaydı yine çalışır.
9. **WHEN** `_EnsureCustomFields` persistent field'lı kapalı dataset'te
   çağrılır **THE SYSTEM SHALL** eksik `ozel_*` `TField`'larını yaratır; açık
   dataset'te hata fırlatır.
10. **WHEN** seçenek kodu `|` içerir **THE SYSTEM SHALL** kaydı reddeder.
11. **WHEN** `Mode = cfmFilter` ve `ApplyFilter` çağrılır **THE SYSTEM SHALL** yalnız değer girilmiş
    editörler için koşul ekler; düzenleme kipinde `ERadCustomField` fırlatır.

## İşlevsel olmayan gereksinimler

- Delphi 13, Win32 + Win64. Çekirdek birim testleri bağlantısız (DDL metni,
  kolon adı üretimi, `coklu` biçimi). Canlı testler: PostgreSQL 18 (`testdb`),
  SQL Server (`rad_filter_test`), Firebird 5 — tablo yarat, alan ekle, değer
  yaz/oku, `rad.sqlfilter` ile `coklu` filtrele, transaction geri alma. MySQL
  kurulu değil → "doğrulanmadı".
- Frame testi: scratch VCL projesi, `TdxLayoutControl` üzerinde kurulum,
  düzen kaydet/yükle/yeni alan ekleme (ölçüm: item adları eşleşiyor mu).
- DDL yetkisi yoksa `AddField` DB hatasını `ERadCustomField` içinde özgün
  mesajla iletir; frame kullanıcıya gösterir, tanım satırı yazılmaz.

## Ölçümler (canlı, 2026-10-31)

| Durum | PostgreSQL 18 (`testdb`) | SQL Server 2025 (`rad_filter_test`) | Firebird 5.0.4 |
|---|---|---|---|
| `CustomFieldLiveTest` | 49/49 Win32+Win64 | 49/49 Win32+Win64 | 48/48 Win32 (Win64: 64-bit `fbclient.dll` yok) |
| `AddField` insert patlayınca DDL geri alındı mı | evet | evet | evet — yalnız ayrı `TUniTransaction` + sorgu `AutoCommit=False` ile |
| Çekirdek `CustomFieldTest` (bağlantısız) | 91/91 Win32+Win64 | | |
| `CustomFieldsFrameTest` (çerçeve + diyalog + filtre kipi, PG) | 91/91 Win32+Win64 | | |

Ölçülüp spec'e geri yazılan düzeltmeler:

- **Firebird (UniDAC InterBase):** bağlantı transaction'ı içinde `Connection.ExecSQL(DDL)` +
  `Rollback` kolonu geri almaz; `AutoCommit` her değişiklikten sonra `CommitRetaining` yapar
  (`FbDdlProbe` A). Ayrı `TUniTransaction` ve sorgularda `AutoCommit=False` ile geri alınır (H/I).
  Her SELECT varsayılan transaction'ı açık bırakır; `InTransaction` Firebird'de "kullanıcı
  transaction'ı var" anlamına gelmez. Ana sorgu açıkken `ALTER TABLE` çalıştı (J: "object in use" yok).
- **SQL Server Türkçe collation:** `information_schema.tables` küçük harfle bulunamaz
  (`Turkish_CI_AS`'ta `i`≠`I`); katalog sorguları `INFORMATION_SCHEMA.COLUMNS`/`TABLES` büyük harf.
  PG ve MySQL tırnaksız adı küçük harfe katladığı için aynı metin üçünde de çalışır.
- **Firebird katalog:** `rdb$relation_fields` adları büyük harf ve boşluk dolgulu →
  `trim(...) = :c` ve `CatalogName` büyük harfe çevirir.
- **Delphi `Format`:** `%0:s` gibi indeksli belirteçten sonraki indekssiz `%s` sırayı o indeksten
  devam ettirir; FK referansı ID tanımını aldı, üç sunucuda `CREATE TABLE` patladı. Açık `%16:s`.
- **DevExpress `TdxLayoutControl`:** `Parent := Layout` verilen kontrole layout kendiliğinden item
  açar; `CreateItemForControl` ikinciyi `EdxException` ile reddeder (Parent verilmez). Akış kaydı
  `ItemsOwner.Name` öneki kullanır → kontrolün adı sabit (`lcRadCustomFields`). `SaveToStream` item
  `Visible`'ını **saklamaz** (`GetStoredProperties`: IsUserDefined/ParentName/Index/Align/Width/
  Height/IsFloat); görünürlük çerçevenin kendi başlığında (`-li_ozel_5`) taşınır.
  `Customization := True` pencere ister (`CanAllocateHandle`); gösterilmemiş formda sessizce reddeder.
  **Host DFM yüklenirken kodla yaratılan `TdxLayoutControl`'ün kök grubu yoktur**
  (`CreateRootGroup`: `IsGlobalLoading and IsRootStored` → atla); `Items` nil, `Name` ataması AV.
  Çerçeve UI'yi `EnsureUi` ile sahip zinciri `csLoading/csReading`'den çıkınca kurar
  (`HostDfmProbe`: düz form + layout item içinde inline, 2/2).
- **UniDAC persistent `TField`:** `Close; FieldDefs.Updated := False; FieldDefs.Update;
  FieldDef.CreateField` (Devart belgesi, canlı doğrulandı: `_EnsureCustomFields` L29–L34).
- **PostgreSQL satır sırası:** güncellenen satır fiziksel olarak sona gider; `select *` ilk satır
  varsayımı yanlış (`order by id`).

## Kapsam dışı (v1)

- Lookup (başka tablodan seçim), script/hesaplanan alan, fiziksel kolon silme,
  tip dönüştürme, uzunluk daraltma.
- Filtre ekranında `filtrele_mi` alanlarının otomatik gösterimi (bayrak
  tanımda var; ekran ayrı iş, ertelenen "DevExpress kontrolünden filtre" ile).
- Çok kullanıcılı eşzamanlı tanım değişikliği kilidi.
