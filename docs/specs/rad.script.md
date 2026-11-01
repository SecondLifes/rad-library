# Specification: `rad.script` — script/eklenti sistemi, 2. aşama (paket modeli + DB + yükleyici)

Durum: **onaylandı ve uygulandı** (2026-11-01; kod `src/core/rad.script.pas`, `Help.uni.pas`
`TRadUniScriptStore`; testler `src/test/scratch/rad_script/`). Motor kararı ve ölçümler:
`rad.script-spike.md`. Bu belge yalnız 2. aşamayı kodlanacak düzeyde tanımlar;
3-6. aşamalar (kanca katmanı, facade, tasarımcı, IDE) kendi spec'leriyle gelir.

## Bağlam

ERP kullanıcısı (veya yapay zeka) programı yeniden derlemeden davranış ekler:
Kaydet'ten önce kontrol, kayıttan sonra yan etki, formu değiştirme, KP'de
zamanlanmış/olaya bağlı iş, menüden açılan kendi formu. Referans Wolvox
(PascalScript, tek `SCRIPT` blob'u, `USER_DB_SQL`); biz **normal tablolar** ve
tek dosya dışa/içe aktarma kullanıyoruz. Koruma = kaynağı tasarımcıda gizleme;
gerçek güvenlik değil, belgelenir.

Onaylı kullanım kararları (2026-11-01):

- Bağlama anahtarı = **form sınıf adı** (`Tkasa_k`) + **bileşen `Name`'i**.
  Adsız bileşen erişilemez; host kodla yarattığı düğmelere `Name` verir.
- Kanca alt programları İngilizce: `<Bileşen>_Before(Sender): Boolean`
  (`False` → orijinal çalışmaz), `<Bileşen>_After(Sender)`, `Form_AfterCreate`.
- `_After` içindeki hata loglanır ve gösterilir, kayıt **geri alınmaz**;
  transaction isteyen iş `_Before`'a yazılır.

## Birimler (2. aşama)

| Birim | Bağımlılık | İçerik |
|---|---|---|
| `src/core/rad.script.pas` | RTL + mORMot2 (`IDocDict`) + `rad.sqlfilter` (lehçe) | paket/script/parametre/DB adımı/kaynak modeli, doğrulama, `IRadScriptStore`, `TRadScriptDdl` (tanım tabloları DDL), `TRadScriptPackageFile` (dışa/içe aktarma) |
| `src/core/Help.uni.pas` | UniDAC | `TRadUniScriptStore` (`TRadUniCustomFieldStore` kalıbı: Firebird ayrı transaction, `INFORMATION_SCHEMA` büyük harf) |

TMS Scripter **bu aşamada bağlanmaz**; motor sarmalayıcısı 3. aşamada
`src/vendor/tms/rad.script.engine.pas`.

## Veri modeli

Şirket DB'sinde, Türkçe adlandırma (`ozel_alan*` ile aynı dil):

```
script_paket                      -- dağıtım birimi (Wolvox "paket")
  id              integer PK
  kod             varchar(50)  not null unique   -- 'firma.kasa-kontrol', dosya adı da bu
  adi             varchar(100) not null
  aciklama        varchar(500)
  surum           varchar(20)  not null default '1.0.0'
  yazar           varchar(100)
  aktif_mi        boolean not null default true
  korumali_mi     boolean not null default false  -- tasarımcı kaynağı gizler
  sira            integer not null default 0      -- aynı hedefe birden çok paket: çalışma sırası
  olusturma_zamani, degisim_zamani

script
  id              integer PK
  paket_id        integer FK script_paket on delete cascade
  kod             varchar(50)  not null            -- paket içinde benzersiz
  adi             varchar(100) not null
  tur             varchar(10)  not null            -- aşağıdaki tablo
  hedef           varchar(200) not null            -- tür'e göre anlam
  sira            integer not null default 0
  aktif_mi        boolean not null default true
  kaynak          text    not null                 -- Pascal kaynağı, p-code saklanmaz
  degisim_zamani
  unique (paket_id, kod)

script_parametre                  -- paket ayarları (mail adresi, eşik...) script Param.Deger('x') ile okur
  id, paket_id FK cascade, adi varchar(50), deger varchar(1000), aciklama varchar(200)
  unique (paket_id, adi)

script_db                         -- paketin kendi tabloları için migrasyon adımları (Wolvox USER_DB_SQL)
  id, paket_id FK cascade, sira integer, aciklama varchar(200), sql_metni text,   -- 'sql' bazı lehçelerde ayrılmış sözcük
  uygulandi_mi boolean default false, uygulama_zamani
  unique (paket_id, sira)

script_kaynak                     -- DFM ve diğer dosyalar ({$FORM TfmKur, kur.dfm})  [spec'te önce script_duzen denmişti]
  id, paket_id FK cascade, dosya_adi varchar(100), icerik blob/bytea
  unique (paket_id, dosya_adi)
```

`script.tur` / `hedef`:

| tur | hedef | Ne zaman çalışır (3. aşama) |
|---|---|---|
| `form` | form sınıf adı (`Tkasa_k`, `Tbase_kayit`) | `Attach(AForm)`: sınıf **ve ataları** için aktif script'ler, önce ata; kancalar kaynaktaki `_Before/_After/Form_*` adlarından bulunur, ayrı tablo yok |
| `olay` | `rad.eventbus` kanal adı (`efatura.gelen`) | KP: kanala abone, `Calistir(Olay)` çağrılır |
| `zaman` | `rad.date.TDtSchedule` maskesi (Quartz, 6-7 alan: `0 0 8 * * ?`) | KP zamanlayıcısı, `Calistir(Olay)` |
| `komut` | modül sınıf adı (`Tkasa_modul`) | modül `Register`'da menüye komut eklenir, `<Kod>_Execute(Sender)` |
| `kutuphane` | boş | aynı paketin diğer script'lerine `uses` ile açılır |

Tek tablo, ayrımı `tur` yapar: `hedef` doğrulaması tür'e göre `TRadScript.Validate`'te
(`form`/`komut`: `T` ile başlayan tanımlayıcı; `olay`: boş değil; `zaman`: cron parse;
`kutuphane`: boş olmalı).

## İşlevsel gereksinimler

### Model (`rad.script`, saf RTL, birim test)

```pascal
TRadScriptKind = (skForm, skEvent, skSchedule, skCommand, skLibrary);   // tur kodu: 'form','olay','zaman','komut','kutuphane'
TRadScript        : Id, PackageId, Code, Name, Kind, Target, Order, Active, Source, Modified; Validate; KindCode/KindOfCode
TRadScriptParam   : Id, Name, Value, Description
TRadScriptDbStep  : Id, Order, Description, Sql, Applied, AppliedAt
TRadScriptResource: Id, FileName, Content: TBytes
TRadScriptPackage : Id, Code, Name, Description, Version, Author, Active, Protected, Order,
                    Scripts/Params/DbSteps/Resources (owned lists); Validate (kod biçimi, benzersiz script kodları, tüm script'ler geçerli)
TRadScriptPackages = TObjectList<TRadScriptPackage>
// cron yazılmadı: kit'teki rad.date.TDtSchedule (Quartz maskesi, NextTime) kullanılır; Validate maskeyi SetAsString ile dener
```

Paket kodu: küçük harf/rakam ile başlar, sonra küçük harf/rakam/`.`/`-`, 2-50 karakter;
dosya adı olarak kullanılır.

### Store (`IRadScriptStore`, `TRadUniScriptStore`)

```pascal
function  Dialect: TRadSqlDialect;
procedure EnsureDefinitionTables;                              // idempotent, 5 tablo
function  LoadPackages(AIncludeInactive: Boolean): TRadScriptPackages;   // tam graf, sahiplik çağırana
function  LoadPackage(const ACode: string): TRadScriptPackage;           // nil = yok
procedure SavePackage(APkg: TRadScriptPackage);                // insert veya kod'a göre update; alt kayıtlar: silinen silinir, tek transaction
procedure ImportPackage(APkg: TRadScriptPackage);              // aynı kod varsa mevcut parametre değerlerini korur, sonra SavePackage
procedure DeletePackage(const ACode: string);                  // cascade; script_db ile yaratılan tablolara DOKUNMAZ (belgelenir)
function  ScriptsFor(AKind: TRadScriptKind; const ATarget: string): TRadScripts;   // yalnız aktif paket + aktif script, sıra: paket.sira, script.sira
procedure ApplyPendingDbSteps(APkg: TRadScriptPackage);        // uygulanmamış adımlar sırayla; biri hata verirse durur, hata yükseltilir, uygulananlar işaretli kalır
function  LoadResource(APackageId: Integer; const AFileName: string; AStream: TStream): Boolean;
```

`ScriptsFor(skForm, 'Tkasa_k')` yalnız tam eşleşme döner; ata zinciri 3. aşamadaki
`Attach`'ın işi (RTTI'den `ClassParent` yürür, her sınıf adı için bir çağrı).

### Dışa/içe aktarma (`TRadScriptPackageFile`)

- Tek dosya `<kod>.radpaket`, içerik JSON (`IDocDict`): `{"format":1,"paket":{...},"scriptler":[...],"parametreler":[...],"db":[...],"kaynaklar":[{"dosya_adi":..,"icerik":"<base64>"}]}`.
- `ExportPackage(APkg): RawUtf8` ve `ImportPackage(const AJson): TRadScriptPackage` (Id'ler 0,
  `Applied=False`, `Validate` geçmezse `ERadScriptFormat`).
- `korumali_mi` dosyaya **aynen** yazılır; kaynak dosyada okunabilir. Gizleme tasarımcı
  seviyesindedir, bu belgede ve README'de açık yazılır.
- İçe aktarmada aynı `kod` varsa: store'un `ImportPackage`'ı mevcut `script_parametre.deger`
  değerlerini dosyadakinin üstüne koyar (kurulum ayarı kaybolmasın), yeni parametreler dosyadan
  gelir, sonra `SavePackage` **üzerine yazar** (surum karşılaştırması UI'nin işi). `SavePackage`
  tek başına verilen nesneyi aynen yazar (tasarımcı parametre değiştirebilsin).
- Eksik isteğe bağlı anahtar (aciklama, yazar, aktif_mi, sira...) hata değil, varsayılan alır:
  dosya elle yazılabilir.

### Host sözleşmesi (3. aşamada ERPPlus'a düşecek, şimdiden bilinsin)

1. `Tbase_kayit`: `FBtnKaydet.Name := 'btnKaydet'`, `FBtnVazgec.Name := 'btnVazgec'`,
   `FQry.Name := 'qry'`, `FLyt.Name := 'lyt'`.
2. `KayitFormuAc`: `Create` ile `Ac(AId)` arasına `TRadScript.Attach(LForm)`.
3. `Tbase_modul.ListeAc`: `Create`'ten sonra `Attach(Result)`.
4. `TRadScriptStore` için `class var DefaultStore` (özel alanla aynı kalıp), bir kez atanır.

### Kabul ölçütleri (EARS)

1. **WHEN** `EnsureDefinitionTables` iki kez çağrılır **THE SYSTEM SHALL** ikinci çağrıda
   hiçbir DDL çalıştırmaz (PG, MSSQL, Firebird).
2. **WHEN** `SavePackage` yeni paketle çağrılır **THE SYSTEM SHALL** paket + tüm alt kayıtları
   tek transaction'da yazar; alt kayıtlardan biri başarısızsa paket de yazılmaz.
3. **WHEN** `SavePackage` mevcut kodla çağrılır ve bir script listede yoksa **THE SYSTEM SHALL**
   o script'i siler, kalanları `kod`'a göre günceller (Id'ler korunur).
4. **WHEN** `ScriptsFor(skForm,'Tkasa_k')` çağrılır **THE SYSTEM SHALL** yalnız aktif paketlerin
   aktif `form` script'lerini `paket.sira, script.sira` sırasıyla döner; pasif paketin aktif
   script'i gelmez.
5. **WHEN** `ApplyPendingDbSteps` 3 adımdan ikincisinde hata alır **THE SYSTEM SHALL** 1.
   adımı `uygulandi_mi=true` bırakır, 2 ve 3'ü uygulanmamış bırakır, hatayı yükseltir; tekrar
   çağrıda 2'den devam eder.
6. **WHEN** `Export` sonra `Import` yapılır **THE SYSTEM SHALL** `Id`/`Applied` dışında eşit
   bir paket üretir (kaynaklar bayt bayt).
7. **WHEN** `Import` geçersiz paket kodu, bilinmeyen `tur`, yanlış cron veya `format>1` görür
   **THE SYSTEM SHALL** `ERadScriptFormat` yükseltir, hiçbir şey yazmaz.
8. **WHEN** aynı kodlu paket içe aktarılır **THE SYSTEM SHALL** mevcut parametre değerlerini
   korur, dosyadaki yeni parametreleri ekler, dosyada olmayanları siler.
9. **WHEN** `zaman` script'inin hedefi `TDtSchedule.SetAsString` ile parse edilemez **THE SYSTEM SHALL**
   `Validate` hatası verir (`'60 * *'`); `'0 0 8 * * ?'` geçer. (Zamanlama `rad.date`'in kendi testindedir.)
10. **WHEN** `DeletePackage` çağrılır **THE SYSTEM SHALL** 5 tablodan paketin satırlarını siler,
    `script_db` ile yaratılmış kullanıcı tablolarına dokunmaz.

## Ölçümler (canlı, 2026-11-01, Win32; Win64 PG+MS aynı)

| | PG 17 | MSSQL | Firebird 5 |
|---|---|---|---|
| 5 tanım tablosu DDL | 22 ms | 6 ms | 25 ms |
| `SavePackage` (3 script, 2 param, 2 db adımı, 2000 baytlık kaynak) | 12 ms | 15 ms | 14 ms |
| Test | 24/24 | 24/24 | 24/24 |

Öğrenilenler: Firebird'de `blob sub_type text` parametresi `ftMemo` ile "Malformed string" verir →
`ftWideMemo`; okumada aynı alan `TMemoField` gelir ve `AsString` UTF-8 baytlarını ANSI çözer ('ş' iki
karakter) → `TRadUniStoreBase.MemoText` yalnız Firebird'de `AsBytes`+UTF-8; PG'de ise `AsBytes`
yolu `EEncodingError` verir, `AsString` doğrudur. `with` deyimi yasak olduğu için `ImportPackage`
değişkenle yazıldı. Model testi 37/37 Win32+Win64.

## İşlevsel olmayan gereksinimler

- Model testleri (`ScriptModelTest`) Win32 + Win64; store testleri (`ScriptLiveTest`) PG `testdb`,
  MSSQL `rad_filter_test`, Firebird; `src/test/scratch/rad_script/`.
- `kaynak` için `text`/`varchar(max)`/`blob sub_type text`; `icerik` için `bytea`/`varbinary(max)`/`blob`.
- Store thread-safe değil (bağlantı başına bir store); KP her görev thread'inde kendi store'unu açar.
- Public API'de overload/varsayılan parametre yok (facade'a örnek olacağı için aynı disiplin).

## Kapsam dışı (2. aşama)

Motor, kanca, `Attach`, facade, tasarımcı, KP zamanlayıcı döngüsü, imza/şifreleme, paket
bağımlılıkları (paket A paket B'yi gerektirir), sürüm yükseltme sihirbazı.
