# TODO — rad-library

Bekleyen bütün işler burada durur. Yeni bir bulgu ya da ertelenen düzeltme
**bu dosyaya** eklenir.

**Kurallar**

- Her maddenin sabit bir numarası var (`RAD-NN`). Kapanan maddenin numarası
  tekrar kullanılmaz; yeni madde en büyük numaradan devam eder
  (sıradaki: **RAD-16**).
- Kapanan madde listeden **ve** ayrıntısından silinir. Kalıcı kayıt
  `git log` + `CHANGELOG.md`'dir.
- Bu liste yalnızca rad-library'ye ait işleri tutar. Bir tüketici projenin
  (ör. ERPPlus) kendi listesindeki madde, buradaki karşılığına numarasıyla
  atıf yapar.

**Kaynak:** 2026-10-17, ERPPlus'ın `radstudio build` ile Win32 Debug derlemesi
(0 hata, 83 uyarı) ve ERPPlus `TODO.md` incelemesi.

## Liste

### 🟠 Yüksek

- [ ] **RAD-01** — `THash`'a Argon2id eklenmeli; `md5` tuzsuz. (`src/core/rad.hash.pas`; ERPPlus YAP-09)
- [ ] **RAD-02** — Yapılandırmadaki parola düz metin saklanıyor; `rad.config` tarafında şifreli saklama ya da hiç saklamama seçeneği gerekiyor. (ERPPlus YAP-11, YAP-27)

### 🟡 Orta

- [ ] **RAD-03** — Dönüş değeri atanmayan fonksiyonlar ve ilklenmemiş değişken (W1035/W1036).
- [ ] **RAD-04** — Örtük `string` ↔ `UTF8String` dönüşümleri (W1057).

### 🟢 Planlı (ertelendi, önce değerlendirilecek)

- [ ] **RAD-05** — `TcxRadSetting`: `Master` kayıt/bildirim mekanizması (bağımlı master'a kendini kaydeder, master değişince abonelere haber verir).
- [ ] **RAD-06** — `TcxRadSetting`: `DataBinding` alanının değer değişimi olayı (`OnChange`/`OnFieldChange`).
- [ ] **RAD-07** — Bayat/çalışmayan scratch sondaları: `rad_setting` (`share\k.setting.pas` yok), `rad_cache_tvalue` (DUnitX bulunamıyor), `rad_cache_bench` (mORMot yolu eksik).
- [ ] **RAD-08** — `TRadConfig.Destroy` artık kaydetmiyor (`//SaveIfNeeded`); `TRadConfig.Config` global'i ve `Destroy` ile kaydetmeye güvenen çağıranlar kaydı sessizce kaybeder. Bilinçli mi, doğrulanmalı.
- [ ] **RAD-13** — Özel alan filtre ekranı: çerçeve tarafı bitti (`Mode = cfmFilter`, `ApplyFilter`); kalan: ERPPlus liste formlarına bağlama ve ertelenen "sabit DevExpress kontrolünden filtre değeri" işi.
- [ ] **RAD-15** — Script/eklenti sistemi (TMS Scripter 8.1): aşama 2-6 — paket modeli + DB + yükleyici, kanca katmanı (action/click/dataset/form + KP olayları/zamanlayıcı), facade API + `rad-script` skill, tasarımcı, IDE formları. Sonda ve kararlar: `docs/specs/rad.script-spike.md`. 2. aşama **bitti** (2026-11-01: `rad.script.pas`, `TRadUniScriptStore`, testler); 3. aşama **bitti** (2026-11-01: `src/vendor/tms/rad.script.{engine,hooks,jobs}.pas`, `RadScriptTms` paketi, HooksTest 34/34); 4. aşama **bitti** (2026-11-01: facade/komut/tipli kanca/dev/uni birimleri, `rad-script` skill, `docs/script-api.md`); sırada 5. aşama tasarımcı. Spec 4: `docs/specs/rad.script.facade.md`. Spec 3: `docs/specs/rad.script.hooks.md`. Spec 2: `docs/specs/rad.script.md`.
- [ ] **RAD-14** — Özel alan v2: fiziksel `DROP COLUMN` / tip dönüştürme yönetici işlemi, lookup (başka tablodan) tipi, MySQL canlı doğrulaması (DDL geri alınamaz), `TRadCustomFieldsFrame`'in `RegisterComponents` ile palete alınması.

---

## Ayrıntılar

#### RAD-01 — Argon2id

`THash.md5` (`src/core/rad.hash.pas`) tuzsuz MD5 üretiyor. ERPPlus'ın
`kullanici.password` kolonu bununla dolduruluyor ve `Rad-DB` şeması bunun zayıf
olduğunu kendisi yazıyor. Yapılacak: `THash.Argon2id` (ya da eşdeğeri) ve mevcut
MD5 kayıtları için ilk girişte yeniden hash'leyen bir geçiş yolu. Geçiş,
tüketen projelerin hepsini etkiler; imza değişikliği CHANGELOG'da duyurulmalı.

#### RAD-02 — Yapılandırmada parola

`Config.Json.Value._RecordSave<TServerOptions>('Server', rc)` parolayı düz metin
yazıyor (kullanan: ERPPlus `src/Share/db.login.pas`). Çözüm `db.login`'e özel
değil, `rad.config`'te olmalı: ya parola hiç yazılmaz ya da Windows DPAPI /
mevcut `rad.cipher` / `rad.AESObj` ile şifrelenir.

#### RAD-03 — Atanmayan dönüş değerleri

Derleyici aşağıdaki yerlerde dönüş değerinin tanımsız kalabileceğini söylüyor.
Her birinde `Result` tüm yollarda atanmalı:

| Dosya:satır | Uyarı |
|---|---|
| `src/component/Permission.Edit.pas:747` | W1035 `TcxTreeListNodeHelper._SetKod` |
| `src/core/Help.DB.pas:769` | W1035 `TDataSetHelper._LoadValueALL` |
| `src/core/Help.uni.pas:396` | W1035 `TUniConnectionHelper._ServerDate` |
| `src/core/Help.uni.pas:623` | W1035 `TUniConnectionHelper._sqlCount` |
| `src/core/Help.uni.pas:994` | W1035 `TDADataSetyHelper._Transaction` |
| `src/core/help.uni.pas:678` | W1036 `sp` ilklenmemiş olabilir |

#### RAD-04 — `UTF8String` dönüşümleri

Derleme, Delphi 13 / Win32 Debug'da aşağıdaki dosyalarda örtük
`string` ↔ `UTF8String` dönüşümü uyarısı veriyor (satırlar o günkü kaynağa göre):
`Permission.Edit.pas` (471, 478, 551, 552, 594, 595, 601, 689, 734, 826, 831),
`rad.db.pas` (1182, 1277, 1280, 1290, 1980), `Help.DB.pas` (328, 330, 342, 344),
`rad.pas` (210, 237), `rad.thread.pas` (728, 739). Uyarı, kodlama kaybı
riski taşıyor; Türkçe karakterli veride veri bozulabilir. Dönüşümler açık
(`UTF8Encode`/`UTF8ToString`) yazılmalı ya da türler `string`'e çevrilmeli.

#### RAD-05 — `Master` kayıt/bildirim

İlk sürümde `TcxRadSetting` yalnızca ayar taşır (`Key`, `Tag`, `Control1..4`,
`DataBinding`); bildirim yok. Eklenecek: bağımlı `Master`'ı seçince master'ın
`RadSetting`'ine abone olur; master'ın değeri değişince (`DoEditValueChanged`)
abonelere haber gider, mevcut `OnCascade` imzası kullanılabilir. Tasarım
kuralları (konuşmada kararlaştırıldı):

- Bildirim yalnızca `Master` aboneliğinden gider; `Control1..4` bildirimsiz
  düz referanslardır (çelişen iki doğruluk kaynağı olmasın).
- Ömür iki yönlü: master yok edilirse abonenin `Master`'ı `nil`'lenir (DX'in
  `ItemRemoved` deseni, `cxEdit.pas:6495-6507`); abone yok edilirse master'ın
  listesinden düşer (`TcxFreeNotificator`).
- `Assign`/`Clone` abone kaydetmez; grid inplace editör kopyası (`IsInplace`)
  listeyi kirletmemeli.
- Master'ın `RadSetting`'i olmalı; grid sütunuysa `PropertiesClassName` atanmış
  olmalı, yoksa `Master` atanırken açık hata verilir. `Master = kendisi` reddedilir.
- Bildirim sırası, atama sırasına bağlıdır (yuvalardaki sabit sıra yok).
- Test (scratch): DFM'den yükleme, master/abone yok edilince temizlik, gridde
  inplace kopyanın liste kirletmemesi.

#### RAD-06 — `DataBinding` değişim olayı

İlk sürümde `TcxRadSetting.DataBinding` yalnızca bağımsız bir `DataSource` +
`FieldName` taşır ve değeri okunabilir. Ertelenen: alan değeri değişince olay
(`OnFieldChange(Sender, AOld, ANew)`), RAD-05'teki bildirim çekirdeğiyle
paylaşılan. Notlar:

- `RecordChanged` kayıt gezinmesinde de tetiklenir; "değişti" = önceki bildirilen
  değerden farklı olması. Gezinmede bildirilip bildirilmeyeceği karar bekliyor
  (öneri: bildirilsin, master-detail böyle çalışır).
- Kopyalar (`DoAssign`) kendi `TDataLink`'ini açmamalı, yoksa her değişim birden
  fazla kez bildirilir; yalnızca gerçek sahipte bağlanmalı.
- `TDataSource` yok edilirken bağlantıları kendisi koparır (VCL; denenmedi).
  `ActiveChanged`/`LayoutChanged`'de alan yeniden çözülmeli.
- `csDesigning` ve yükleme sırasında olay tetiklenmemeli.
- Ölçüm (cxDBEdit probu): `DataField` ataması düzenleyicinin bağlama kancalarında
  `DataChanged → EditingChanged → DataChanged` üretir; bu yüzden düzenleyicinin
  kendi bağlamasına kanca takmak yerine bağımsız `TDataLink` tercih edilir.

#### RAD-07 — Bayat scratch sondaları

Bu turda çalıştırılan ve kodla ilgisi olmayan nedenlerle derlenemeyen sondalar:
`src/test/scratch/rad_setting/SettingTest.dpr` `..\..\..\share\k.setting.pas` arıyor, dosya
yok (git geçmişinde başka bir dalda var); `rad_cache_tvalue/RunCacheTests.dpr` DUnitX ister;
`rad_cache_bench/build_and_run.bat` `rad.cache.pas`'ın kullandığı `mormot.core.json`
için `-U` yolunu eklemiyor. Her biri ya onarılmalı ya silinmeli.

#### RAD-08 — Kaydetme sözleşmesi

`TRadConfig.Destroy` içindeki `SaveIfNeeded` yorum satırına alınmış. Sonuç: ayarlar yalnızca
açık `SaveIfNeeded` çağrısıyla yazılır; `Free` (ve `finalization`'daki `Config` serbest
bırakma) yazmaz. `rad_config/ConfigTest` 14 ve 20 bunu belgeliyor. Uygulamalar çıkışta
`SaveIfNeeded` çağırmıyorsa son değişiklikler kaybolur. Karar: ya geri aç ya da çağıranları
(ERPPlus dahil) tara.

#### RAD-09 — `rad.filtre.pas` → `rad.sqlfilter` çekirdeği

`TFiltreModel.Olustur` kendi `ILIKE ... ESCAPE '\'` ve parametre üretimini taşıyor;
`rad.sqlfilter` aynı işi yapıyor (`ESCAPE '!'`, lehçe desteği, boş-değer kuralı). İki kopya
`share/rules/layered-function-design.md`'ye aykırı. Yapılacak: `Olustur` içeriden
`TRadSqlFilter.New(...)` kullansın, `LikeKacis` silinsin. `rad.filtre` henüz hiçbir yerde
`uses` edilmiyor; `KosulSayisi` boş-metin kaydını da sayıyor (küçük hata), o da bu işte düzelir.

#### RAD-10 — `rad.sqlfilter` doğrulanmamış lehçeler

- **Firebird Win64:** Win32'de 30/30 geçti (`C:\Users\Public\rad-test\rad_filter_test.fdb`,
  `RAD_FB_*` `test-db.env`'de). Makinede 64-bit `fbclient.dll` yok; 64-bit Firebird istemcisi
  kurulup `RAD_FB_CLIENT64` verilince `SqlFilterLiveTest` Win64'te de çalışır.
- **MySQL:** kurulu değil. `ESCAPE '!'` ve `UPPER()` MySQL 26.7 belgesine göre yazıldı
  (`NO_BACKSLASH_ESCAPES` etkisinden bağımsız). Doğrulanmadı.

#### RAD-11 — `rcSensitive` MSSQL/MySQL'de collation'a kalıyor

`Turkish_CI_AS` veritabanında `Eq('ad','ELA', rcSensitive)` 'Ela'yı buluyor (ölçüldü).
Gerçek duyarlılık için `COLLATE <ad>` eki gerekir; hangi collation'ın kullanılacağı
veritabanına özel. Seçenek: filtreye `Collation('Turkish_CS_AS')` ayarı; verilmişse
`rcSensitive`'te `alan COLLATE ... = :p` üretilir. Ayrıca PostgreSQL varsayılan collation'da
`lower('İ') ≠ 'i'` (ölçüldü, `Contains('ad','ismail')` 'İsmail'i bulmuyor); çözüm veritabanı
tarafında (`tr-TR-x-icu` collation ya da `unaccent`), sınıfta değil.

#### RAD-12 — `rad.sqlfilter` sunucu tarafı sayfalama (OFFSET + keyset)

`IRadSqlFilter`'a `Limit(n)`, `Offset(m)`, `Page(sayfa, boyut)` (1 tabanlı) ve `GetPaging`;
`GetSql` sona ekler, `Clear` siler. Lehçe: PostgreSQL/MySQL `LIMIT n OFFSET m`; SQL Server ve
Firebird 3+ `OFFSET m ROWS FETCH NEXT n ROWS ONLY` (FB: yalnız `SELECT`, `ROWS`/`FIRST..SKIP`
ile karışmaz). Sayılar koddan gelen `Integer`, düz yazılır (parametre değil; tek istisna,
belgelenir). Kurallar:

- `ORDER BY` yoksa **her lehçede** `ERadSqlFilter` (MSSQL zaten sözdizimi hatası verir;
  PG/FB sessizce tutarsız sayfa üretir). `ORDER BY (SELECT NULL)` dolgusu eklenmez.
- Sıralama sonunda benzersiz alan şart (`AddOrderBy('id')`); sınıf zorlayamaz, belgelenir.
- Keyset ("son kayıttan sonrası"): ilk sürümde `Raw('(a > ? OR (a = ? AND id > ?))', ...)` +
  `Limit`; sonra `.After(['a','id'], [v1, v2])` yardımcısı (PG satır karşılaştırması
  `(a,id) > (:1,:2)`, MSSQL/FB açık biçim). Navigator'lı düzenleme formu (ilk/önceki/
  sonraki/son = `LIMIT 1` dört sorgu; "sonraki var mı" için N+1 çekme) bu yolu kullanır.
  Sıralama anahtarı düzenlenen alan olmamalı (`stok_kod`/`id`).
- `Help.uni`'ye `cn._Count('tablo t', LF)` → `select count(*) ... + LF.GetWhere` (sıra ve
  sayfalama olmadan); "3 / 1500" göstergesi için.
- Test: üç sunucuda 1., 2. ve son sayfa karşılaştırması, `ORDER BY`'sız hata, MSSQL `FETCH`
  sözdizimi, keyset ileri/geri `LIMIT 1`.

#### RAD-13 — Özel alan filtre ekranı

`ozel_alan.filtrele_mi` bayrağı tanımda var, hiçbir ekran okumuyor. Hedef: liste/arama formu
`TRadCustomFieldsFrame` benzeri bir "filtre çerçevesi" ile işaretli alanlar için **unbound** editör
üretir, değerleri tipine göre `IRadSqlFilter`'a yazar (`coklu` → `Contains(alan, '|kod|')`, tarih →
`WholeDay`), `Clear` editörleri temizler. Ertelenen "DevExpress kontrolünden değer alma" işiyle
aynı çekirdeği paylaşmalı (`layered-function-design`).

#### RAD-15 — Script/eklenti sistemi

Motor TMS Scripter 8.1 (sonda 2026-11-01, `docs/specs/rad.script-spike.md`). Ölçümden gelen
kısıtlar: facade API'de overload/varsayılan parametre yok; olay kesme kendi RTTI sarmalayıcısı
(`Before` iptal eder) + tipli olaylar için TMS adaptör üreteci; zaman aşımı yalnız `OnExecHook`
+ istisna (asla `Halt`, asla başka thread'den); thread başına scripter; `TForm` kaydı kendi
`DefineClassByRTTI`'mizle (XE7 import'larında `Show` yok). Paket: normal tablolar (`script_paket`,
`script`, `script_parametre`, `script_db`, `script_duzen`), tek dosya dışa/içe aktarma, koruma =
gizleme (belgelenir). KP: `rad.eventbus` adlandırılmış olaylar + zamanlayıcı. Aşamalar sırayla,
her biri spec + test + kullanıcı onayı.

#### RAD-14 — Özel alan v2

- Fiziksel `DROP COLUMN` ve tip dönüştürme: v1'de bilinçli yok (veri kaybı → kullanıcı onayı);
  ayrı yönetici komutu, önce `aktif_mi=false` şartı, DDL önce yedek sorgusu.
- `lookup` tipi (başka tablodan kod/ad): `TcxDBLookupComboBox` + tanımda kaynak sorgu; filtre ekranı
  ile birlikte düşünülmeli.
- MySQL: DDL transaction'da geri alınamaz; `AddField` yarım kalırsa kolon kalır, tanım yazılmaz —
  canlı doğrulanmadı (sunucu yok).
- `TRadCustomFieldsFrame` şu an palette değil (`Rad.Register` kaydı yok); `TFrame` torunu
  `RegisterComponents` ile kaydedilebilir ama `csInline` davranışı ölçülmeli. Şimdilik kodla:
  `TRadCustomFieldsFrame.Create(Form)` + `Parent`.

