# ERP Yol Haritası — çerçeve seviyesinde eksikler

Modüler bir ERP'nin bu kütüphane üzerine oturması için gereken, **çerçeve
seviyesinde** çözülmesi gereken işler. Hepsinin ortak teması aynı: iş kuralı
koda gömülü kalmasın, veriye taşınsın.

Mevcut durum kısaca: veri katmanı olgun — `TRadQuery`'de akıcı sorgu kurucu,
`TRadUnitOfWork`, `_GenID`, `AuditCapture` (değişen alanları `IDocDict`'e
snapshot'lar), `TRadAutoValues` (olay bazlı otomatik alan doldurma), async
açma/çalıştırma. Aşağıdakiler bunun üzerine gelir.

---

## ✅ Tamamlandı — Lookup tanım kayıt defteri

`src/core/rad.lookup.pas` + `Rad.Dev.pas`'taki `LookupCode` property'si.

Formda `LookupCode := 'MARKA'` yazılır; sorgu, anahtar/liste alanı, üst tanım
ve parametre adları kayıt defterinden gelir. **Yeni bir tanım türü eklemek
form değişikliği değil, bir satır eklemektir.**

Kayıt defteri sorgu çalıştırmaz — yalnızca "ne" sorusunu cevaplar, "nasıl"
uygulamanındır. Bu yüzden `src/core`'da vendor'suz durur ve aynı tanımlar
UniDAC, FireDAC ya da bellek içi bir kaynakla da kullanılabilir.

`Validate` yapılandırmayı işletmeden önce denetler: döngüsel üst zinciri, var
olmayan üst kod, SQL'de karşılığı olmayan parametre bildirimi, ve SQL'de geçip
hiçbir alanda bildirilmemiş parametre. Bir yapılandırma tablosunun en büyük
riski sessizce yanlış olmasıdır.

---

## 1. Zorunlu okuma-tarafı kapsam (`TRadScope`) — en kritik

**Sorun.** `TRadAutoValues` yazma tarafını çözüyor: insert'te `sirket_id`
doldurulabilir. Okuma tarafında hiçbir zorlama yok. `TRadFilterCollection`
kullanıcıya görünen filtre paneli modeli (`Caption`, `FilterType`), güvenlik
kapsamı değil.

ERP'de en pahalı hata sınıfı budur: bir sorguda `where sirket_id = :x`
unutulur, başka şirketin verisi ekrana gelir — ve **hiçbir şey patlamaz**,
sadece fazla satır döner.

**Öneri.** Açılışta SQL'e predicate enjekte eden, varsayılan açık, kapatılması
bilinçli ve loglanan bir kapsam:

```pascal
Q.Text('select * from stok').Open;      // otomatik: and sirket_id = :_scope_sirket
Q.Scope.Bypass('konsolide rapor');       // gerekçe ZORUNLU, loglanır
```

`Bypass`'ın gerekçe istemesi tasarımın parçası: denetimde "kim neden kapattı"
sorusunun cevabı olur.

---

## 2. Belge numaralandırma (`TRadDocNumber`)

**Sorun.** `_GenID(AScopeName)` ham bir sayaç. ERP'de fatura/irsaliye numarası
**seri + yıl + şirket + maske** ister (`FTR-2026-000123`).

"Boşluk olabilir mi" bir *iş kuralıdır*, teknik detay değil: iptal edilen
faturanın numarası mali mevzuata göre geri kullanılamaz ama boşluk da
bırakılamayabilir — ülkeye ve belge türüne göre değişir.

**Öneri.** Ayrı bileşen: seri tanımı, maske, sıfırlama periyodu (yıllık/aylık/
hiç), tahsis anı (peşin mi commit'te mi).

---

## 3. İyimser kilit — sessiz kayıp güncelleme

**Sorun.** İki kullanıcı aynı cari kartı açıp kaydederse ikincisi birincinin
yazdığını **sessizce ezer**. `AuditCapture` ne olduğunu sonradan gösterir,
engellemez.

**Öneri.** PostgreSQL'de ucuz: `xmin` sistem sütunu. Açılışta oku, update'te
`where xmin = :okunan_xmin`, etkilenen satır 0 ise `ERadConcurrent`.
`TRadQuerySetting.OptimisticLock` bayrağıyla her sorguya gelir.

---

## 4. Modül kayıt defteri + şema göçü

**Sorun.** `Rad.Register.pas` tasarım zamanı. Çalışma zamanında bir modülün
kendini tanıtması gerekiyor: menü girdileri, **yetki düğümleri**, DB göç
adımları, bağımlılıkları. Bu olmadan "modüler" iddiası kod ayrımından ibaret
kalır.

İkisi birleşir: her modül kendi göçlerini getirir ve `TRadPermission` ağacına
kendi düğümlerini **kod içinden** kaydeder (şu an DFM'e elle yazılıyor —
`Storage` property'si bunun için eklendi ama kaynağı hâlâ elle).

Göç olmadan "müşteri veritabanını yeni sürüme taşıma" her seferinde elle SQL
demektir; ERP'de en can yakan operasyon budur.

---

## 5. Sorgunun ne yaptığını bildirmesi

**Sorun.** Bir sorgunun hangi tabloya dokunduğunu ve hangi yetkiyi
gerektirdiğini anlamak için SQL metnini okumak gerekiyor. Ne statik denetim
ne de bir yardımcı bunu doğrulayabilir.

**Öneri.**

```pascal
Q.Touches(['stok','stok_hareket']).Requires('STOK.OKU')
```

1. maddeyle aynı altyapı üzerine oturur — kapsam zaten sorgunun hangi tabloya
gittiğini bilmek zorunda.

---

## Küçük not

`TRadQuery._GenID`, `_Transaction`, `_DetailsOpen`... `_` öneki kitin
`helper-patterns.md` kuralında **helper** üyeleri içindir; `TRadQuery` bir
bileşen. Aynı sınıfta `Text`, `Param`, `ScalarInt` öneksiz — karışık bir yüzey.
Kuralı gevşetmek de geçerli bir seçim, ama seçim yapılmalı.
