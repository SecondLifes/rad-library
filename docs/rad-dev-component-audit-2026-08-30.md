# Rad.Dev Component Denetim Raporu

> ## Durum — 2026-08-30, denetim sonrası uygulama
>
> Bu rapordaki sekiz bulgunun her biri **koda karşı yeniden doğrulandı**
> (rapor bir anlık görüntüye ait iddiadır), sonra uygulandı:
>
> | ID | Durum | Kanıt |
> |---|---|---|
> | RADDEV-001 | **KAPANDI** | Kırmızı-önce `EAccessViolation` ile üretildi; `DestructorTest.dpr` 6/6 |
> | RADDEV-002 | **KAPANDI** | `PullTest` T25 kırmızı-önce; paylaşılan item'te önbellek devre dışı |
> | RADDEV-003 | **KAPANDI** | `Leave` en iç `finally`'ye alındı (kaynak gerekçeli; gözlenebilir yolu T19 ölçüyor) |
> | RADDEV-004 | **KAPANDI** | `PullTest` T20 kırmızı-önce |
> | RADDEV-005 | **AÇIK — kullanıcı kararıyla ertelendi** | Paket ayrımı public API kararı; kullanıcı "yapma" dedi |
> | RADDEV-006 | **KAPANDI** | `PullTest` T18 kırmızı-önce |
> | RADDEV-007 | **KAPANDI, rapordan GENİŞ** | Editör kaydı yetmiyordu: denetim combo Properties'i hiç incelemiyordu; `CascadeWarning` eklendi, T24 |
> | RADDEV-008 | **KAPANDI** | Beş sonda assert'e çevrildi; **üç ölü ölçüm** bulundu (M1, M5, RuntimeTest A1) |
>
> RADDEV-005 açık kaldığı için bu dosya `analysis-output.md`'nin saklama
> kuralı gereği **silinmedi**. O bulgu da kapandığında silinecek; kalıcı kayıt
> `git log` + `CHANGELOG.md`.
>
> Rapordaki iki tespit **düzeltildi**: RADDEV-007'nin "en küçük düzeltmesi"
> yetersizdi, ve RADDEV-008 `PullTest`'i de yalnızca-yazdıran sayıyordu (o
> zaten assert ediyordu). Buna karşılık raporun "Tu" tespiti **canlıda
> doğrulandı** ve bir kardeşi olduğu ortaya çıktı.

**Tarih:** 2026-08-30  
**Hedef:** `src/component/Rad.Dev.pas`  
**Kapsam:** Component lifecycle, correctness, cache, exception safety, DFM/design-time entegrasyonu, paketleme, vendor kullanımı ve test altyapısı  
**Mod:** Audit-only — kaynak kod değiştirilmedi

## Yönetici özeti

`Rad.Dev.pas` iyi düşünülmüş bir DevExpress component ailesidir; ancak henüz production-safe veya “mükemmel” kabul edilemez. Bir kritik lifecycle hatası, birkaç yüksek öncelikli correctness/mimari riski ve eksik test kapıları bulunmaktadır.

En acil konu `TRadEditRepositoryItem.Destroy` içindeki use-after-free riskidir. Ardından cache kapsamı, exception sonrasında kilit temizliği ve runtime/design-time paket ayrımı ele alınmalıdır.

## İncelenen alanlar

- `TRadLookupComboBoxProperties`
- `TRadLookupComboBoxRepository`
- `TRadCustomLookupComboBox`
- `TRadLookupComboBox`
- `TRadDBLookupComboBox`
- `TRadComboBoxProperties`
- `TRadComboBoxRepository`
- `TRadComboBox`
- `TRadDBComboBox`
- `TRadEditRepositoryItem`
- `TRadEditSlots`
- `TRadBusyDataSets`
- `RadChainAudit`
- `Rad.Register.pas`, `Rad.Editor.pas` ve `RadKon.dpk`
- İlgili scratch testleri
- Kurulu DevExpress RS37 vendor kaynakları

## Bulgular

### RADDEV-001 — Repository destructor use-after-free

- **Kategori:** Correctness bug / Resource lifecycle
- **Önem:** Critical
- **Konum:** `src/component/Rad.Dev.pas:1078-1081`
- **Karar:** VERIFIED
- **Kanıt:** Kaynak + kurulu DevExpress `cxEdit.pas` lifecycle akışı

`TRadEditRepositoryItem.Destroy`, önce `FConsumers` listesini serbest bırakıp ardından `inherited Destroy` çağırmaktadır. DevExpress’in `TcxEditRepositoryItem.Destroy` metodu bağlı listener’ları kaldırırken sanal `RemoveListener` metodunu çağırır. Sanal çağrı tekrar `TRadEditRepositoryItem.RemoveListener` metoduna düşerse serbest bırakılmış `FConsumers` nesnesine erişilir.

**Hata senaryosu:** Repository item, kendisini kullanan editor veya kolonlar hâlâ bağlıyken elle silinir → inherited cleanup listener’ı kaldırır → override edilmiş `RemoveListener`, silinmiş listeyi kullanır → AV/use-after-free.

**En küçük düzeltme:** `FConsumers`, inherited listener cleanup tamamlanana kadar canlı tutulmalı; destructor sırası bu özel sanal-callback gereksinimine göre düzenlenmeli ve regresyon testi eklenmelidir.

### RADDEV-002 — Cache paylaşılan tüketiciyi ayırt etmiyor

- **Kategori:** Correctness bug
- **Önem:** High
- **Konum:** `src/component/Rad.Dev.pas:408-412`, `1994-2007`, `2074-2095`
- **Karar:** VERIFIED
- **Kanıt:** Kaynak analizi

Lookup cache yalnızca anahtarı saklamaktadır. Dosyanın desteklediği “tek RepositoryItem, tüketici başına farklı sorgu” kullanımında iki tüketici aynı sayısal anahtarı farklı anlamlarla kullanabilir. İkinci tüketicinin `OnLocate` çağrısı bastırılabilir veya ilk tüketicinin çözülmüş metni tekrar kullanılabilir.

**En küçük düzeltme:** Cache kimliği yalnızca `AKey` olmamalı; tüketici/sorgu-generation bağlamını da içermelidir. Paylaşılan Properties için per-consumer cache veya güvenli cache-disable politikası gerekir.

### RADDEV-003 — Exception sonrasında dataset kalıcı busy kalabilir

- **Kategori:** Missing guard/path / Concurrency-state
- **Önem:** High
- **Konum:** `src/component/Rad.Dev.pas:1882-1890`
- **Karar:** PARTIALLY_VERIFIED
- **Kanıt:** Kaynak + DevExpress `CheckLookupList` uygulaması

`DoFilter` cleanup yolunda `ResetCaches`, `TRadBusyDataSets.Leave` çağrısından önce çalışır. `ResetCaches` veya `CheckLookupList` exception üretirse `Leave` atlanır. Dataset bundan sonra sürekli busy görünür ve sonraki filtrelemeler sessizce geçilir.

**En küçük düzeltme:** `Leave`, ayrı bir iç `finally` bloğuyla mutlak garanti altına alınmalıdır.

### RADDEV-004 — Başarısız arama stale cache bırakıyor

- **Kategori:** Coherence gap
- **Önem:** Medium
- **Konum:** `src/component/Rad.Dev.pas:2125-2138`
- **Karar:** VERIFIED
- **Kanıt:** Kaynak analizi

`AOnSearch` dataset’i değiştirip exception üretirse metodun sonundaki `ResetCaches` çalışmaz. `DoFilter` aynı ihtimali cleanup yolunda ele alırken `DoSearch` almamaktadır.

**En küçük düzeltme:** Cache invalidation exception-safe bir `finally` yoluna taşınmalıdır; lock ve busy cleanup sırası korunmalıdır.

### RADDEV-005 — Runtime/design-time ve vendor izolasyonu yok

- **Kategori:** Project-rule violation / Architecture
- **Önem:** High
- **Konum:** `src/component/Rad.Dev.pas:966-967`, `src/packages/RadKon.dpk:30-75`, `src/core/Help.Dev.pas`
- **Karar:** VERIFIED
- **Kanıt:** Kaynak + Win32/Win64 build denemesi

Tek `RadKon` paketi runtime componentleri, `designide`, registration/editor unitleri, DevExpress, UniDAC ve JEDI bağımlılıklarını bir araya getirmektedir. Ayrıca `Rad.Dev`, `Help.Dev` üzerinden `rad.db`, `rad`, mORMot ve JEDI bağımlılık zincirini çekmektedir. `afParam` doğrudan UniDAC `DBAccess` tipine bağlıdır.

Sonuç olarak yalnızca `Rad.Dev` testini derlemek bile unrelated `JclBase` bağımlılığında durmaktadır.

**Önerilen yapı:**

- DevExpress runtime paketi
- DevExpress design-time paketi
- Opsiyonel DevExpress + UniDAC bridge paketi
- Sadece gerekli consumer-access fonksiyonlarını içeren minimal DevExpress helper unit

Bu değişiklik public paket/API kararıdır ve uygulama öncesinde kullanıcı onayı gerektirir.

### RADDEV-006 — Public index API array dışı erişime açık

- **Kategori:** Missing guard/path / Memory safety
- **Önem:** High
- **Konum:** `src/component/Rad.Dev.pas:1204-1239`, `src/packages/RadKon.dpk:17`
- **Karar:** VERIFIED
- **Kanıt:** Kaynak analizi

`TRadEditSlots.Get` ve `Put`, index doğrulaması yapmaz. Paket range checking’i kapatmaktadır. Public API üzerinden `Get(0)` veya `Put(5, ...)` çağrısı array dışı okuma/yazma ve bellek bozulması oluşturabilir.

**En küçük düzeltme:** Metotları dış erişime kapatmak veya `1..CCount` doğrulayıp `EArgumentOutOfRangeException` üretmek.

### RADDEV-007 — Combo ailesinde design-time audit erişilemiyor

- **Kategori:** Coherence gap / Design-time UX
- **Önem:** Medium
- **Konum:** `src/packages/Rad.Editor.pas:124-125`
- **Karar:** VERIFIED
- **Kanıt:** Kaynak analizi

`TRadChainAuditEditor` yalnızca `TRadLookupComboBox` ve `TRadDBLookupComboBox` için kaydedilmiştir. `TRadComboBox` ve `TRadDBComboBox` da cascade slotlarına sahip olduğu halde “Zinciri denetle...” menüsünü alamaz.

**En küçük düzeltme:** Aynı component editor’ü iki combo sınıfına da kaydetmek.

### RADDEV-008 — Güvenilir kalıcı test kapısı yok

- **Kategori:** Project-rule violation / Testability
- **Önem:** High
- **Konum:** `src/test/scratch/rad_dev_*`
- **Karar:** VERIFIED
- **Kanıt:** Test kaynakları + build çıktısı

Testler kalıcı DUnitX testleri yerine scratch console projeleridir. Birçoğu beklenen değerleri yalnızca ekrana yazar ve yanlış sonuçta non-zero exit üretmez.

Örneğin canlı test iki karakterli `"Tu"` araması yapmaktadır; component varsayılanı `AMinSearchLength = 3` olduğundan arama handler’ı çalışmaz. Test bunu assertion ile başarısızlığa dönüştürmez.

Gerekli DUnitX testleri:

- Bağlı consumer varken RepositoryItem destructor
- Aynı key kullanan farklı consumer’lar
- Search/filter handler exception yolları
- Busy-list cleanup garantisi
- Cache invalidation
- DFM round-trip
- Package load/unload
- Win32 ve Win64

## Hazır mekanizma araştırması

### Code graph sorguları

`rad-library` codebase-memory grafiğinde indeksli değildir. İndeksli `Rad-DB` projesinde aşağıdaki sorgular çalıştırılmıştır:

- `TRadLookupComboBoxProperties cascade lookup search delay` → 0 sonuç
- `lookup combo repository item` → 0 sonuç
- `cascade filter master detail` → 0 sonuç
- `debounced search dataset` → 0 sonuç

### Kurulu DevExpress RS37 kaynaklarında bulunanlar

- `TcxFreeNotificator`: Component reference lifecycle için hazır; mevcut kod bunu doğru yönde kullanıyor.
- `TcxEditRepositoryItem.AddListener/RemoveListener`: Consumer takibi için doğru extension seam; mevcut kod kullanıyor.
- `CheckLookupList`: DevExpress lookup cache temizleme mekanizması; mevcut kod kullanıyor.
- `LockDataChanged/UnlockDataChanged`: Lookup data değişiklik koruması.
- `TcxTimer.Reset`: Gecikmeli arama için mevcut `Vcl.ExtCtrls.TTimer` yerine değerlendirilebilecek vendor-native mekanizma.

`TcxTimer` shared timer-window altyapısını kullanır ve mevcut `cxClasses` bağımlılığı içinde hazırdır. Performans kazancı ölçülmeden kesin iddia edilmemeli; ancak DevExpress component ailesiyle daha tutarlı bir seçimdir.

## Güçlü taraflar

- `csLoading`, `csDestroying` ve `csDesigning` korumaları
- Kullanıcının `OnEditValueChanged` olayının tüketilmemesi
- `DoAssign` içinde özel alan ve event kopyalama
- Duplicate slot için doğru free-notification yaklaşımı
- Push ve pull reentrancy durumlarının ayrı tutulması
- Published default değerlerinin constructor ile uyumu
- Own/active Properties ayrımının belgelenmesi
- DevExpress’in `TcxFreeNotificator`, listener ve lookup cache mekanizmalarının doğrudan kullanılması
- Design-time zincir audit fikri

## Ek özellik adayları

Bu maddeler mevcut contract’ın hatası değil, isteğe bağlı geliştirmelerdir:

1. `TcxTimer` tabanlı debounce ve açık `CancelPendingSearch` metodu.
2. Dataset/list değişikliğinde otomatik cache-generation artırımı.
3. String yerine structured `TRadChainIssue` sonuçları; IDE, log ve testlerin aynı modeli kullanması.
4. `SkippedFilterCount` için okunabilir/sıfırlanabilir diagnostics API.
5. Sabit dört push slotu yerine geriye uyumlu collection tabanlı yeni API; eski DFM property’leri shim olarak korunmalı.
6. Aynı anda gelen arama sonuçlarında eski sorgunun yeni sonucu ezmesini önleyen request-generation/cancellation modeli.

## Önerilen uygulama sırası

1. `RADDEV-001` destructor use-after-free hatasını düzelt ve regresyon testi ekle.
2. `RADDEV-006` index sınırlarını koru.
3. Cache’i consumer/query-generation farkındalıklı hale getir.
4. Bütün busy/lock/cache cleanup yollarını nested `finally` ile güvenceye al.
5. DUnitX test projesini ve Win32/Win64 kapısını oluştur.
6. Runtime/design-time paketlerini ayır.
7. DevExpress ile UniDAC entegrasyonunu bridge unit/pakete taşı.
8. Ölçüm sonrasında `TcxTimer` ve diğer feature adaylarını değerlendir.

## Doğrulama kaydı

- **Derleyici:** Embarcadero Delphi 37.0
- **Platformlar:** Win32 ve Win64 denendi
- **Komut:** `build_and_run.bat Win32 PullTest`, `build_and_run.bat Win64 PullTest`
- **Sonuç:** Her iki build, hedef unit doğrulanmadan önce `F2613 Unit 'JclBase' not found` ile durdu.
- **İkinci deneme:** Kurulu JCL ve Dext yolları `EXTRAU` ile verildi; build script include path’i aktarmadığı için `F1026 File not found: 'jcl.inc'` oluştu.
- **Canlı DB testi:** Kimlik bilgisi ve dış veri gerektirdiği için çalıştırılmadı.
- **GUI testi:** Audit sırasında pencere açmamak için çalıştırılmadı.
- **Kaynak değişikliği:** Yapılmadı.

## Son karar

Component tasarımı güçlü bir temele sahiptir; fakat kritik destructor hatası, paylaşılan cache bağlamı, exception-safe cleanup ve paket izolasyonu çözülmeden production-ready kabul edilmemelidir.

**Kalite önerisi:** İlk düzeltme ile birlikte “RepositoryItem bağlı consumer’lar varken silinir” DUnitX regresyon testi zorunlu yapılmalıdır; en yüksek AV riskini sürekli olarak kapatan test budur.
