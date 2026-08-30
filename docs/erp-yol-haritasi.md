# ERP Yol Haritası — çerçeve seviyesinde eksikler

Modüler bir ERP'nin bu kütüphane üzerine oturması için gereken, **çerçeve
seviyesinde** çözülmesi gereken işler. Hepsinin ortak teması aynı: iş kuralı
koda gömülü kalmasın, veriye taşınsın.

Mevcut durum kısaca: veri katmanı olgun — `TRadQuery`'de akıcı sorgu kurucu,
`TRadUnitOfWork`, `_GenID`, `AuditCapture` (değişen alanları `IDocDict`'e
snapshot'lar), `TRadAutoValues` (olay bazlı otomatik alan doldurma), async
açma/çalıştırma. Aşağıdakiler bunun üzerine gelir.

---

## ✅ Tamamlandı — Paylaşılan RepositoryItem + tüketici-başına yük

Bir `TRadLookupComboBoxRepository` ortak davranışı ve **tek** olay işleyicisini
taşır; her tüketici kendi `Properties.CascadeField`'inde hangi tanım olduğunu
söyler. İşleyici bunu `ASource` üzerinden okur.

```pascal
// DM'de: tek item, tek işleyici
riTanim.Properties.OnSearch := DM.TanimAra;

// Formlarda: her combo kendi türünü söyler
cbMarka.RepositoryItem := riTanim;   cbMarka.Properties.CascadeField := 'marka';
cbTip.RepositoryItem   := riTanim;   cbTip.Properties.CascadeField   := 'musteri_tipi';
```

Ölçüldü (`LiveLookupTest` M5): `ASource` doğru editörü veriyor,
`_OwnProperties(ASource).CascadeField` doğru türü döndürüyor, paylaşılan
`Sender` ise ikisinde de ortak değeri veriyor.

Bunun mümkün olması için `OnSearch` ve `OnLocate` imzalarına `ASource`
eklendi — `Sender` paylaşılan Properties örneği olduğu için tek başına
tüketiciyi ayırt etmiyordu.

**Sınır:** `OnLocate` çizim yolundan da tetikleniyor
(`GetDisplayLookupText`) ve orada kaynak **yok** — `ASource` nil gelir.
İşleyici bunu kontrol etmeli.

---

## ⏸ Ertelendi — Lookup tanım kayıt defteri

Bir kez yazıldı (`rad.lookup.pas`, commit `e30ff8a`) ve **geri alındı**.
Gerekçe kaybolmasın diye burada duruyor.

Fikir: tanımları (`sorgu`, `anahtar alan`, `üst tanım`, parametre adları) bir
tabloya taşımak; formda yalnızca `LookupCode := 'MARKA'` yazmak. Yeni tanım
türü eklemek form değişikliği değil, bir satır eklemek olur.

**Neden geri alındı:** yukarıdaki RepositoryItem deseni aynı ihtiyacı
karşılıyor ve hiçbir ek altyapı gerektirmiyor. `tanimlar` gibi tek tablolu bir
tasarımda SQL her tür için **aynı** — değişen sadece parametre. Kayıt defteri
bu durumda fazladan bir dolaylılık katmanı.

**Hangi koşullarda yeniden değerlendirilmeli** — biri doğru olduğunda:

1. **SQL türe göre gerçekten değişiyorsa** — `marka` bir tablodan, `doviz`
   başka bir tablodan, `birim` bir view'dan. Tek parametreyle çözülmüyorsa.
2. **Yeniden derlemeden değiştirmek gerekiyorsa** — müşteri "listede kod da
   görünsün" dediğinde EXE dağıtmak istemiyorsan.
3. **Müşteri kendi tanım türünü ekliyorsa** — derleme anında var olmayan bir
   şey için `RepositoryItem` bırakamazsın.

Kaldırılan sürümün taşıdığı ve tekrar yazılırsa korunması gereken parça
`Validate` idi: döngüsel üst zinciri, var olmayan üst kod, SQL'de karşılığı
olmayan parametre bildirimi, ve SQL'de geçip hiçbir alanda bildirilmemiş
parametre. Sonuncusu en sinsisi — yanlış parametre adı çalışma zamanında hata
değil, **sessiz boş liste** olarak görünür. Ayrıca ayrıştırıcısı PostgreSQL
cast'ini (`::text`) parametre saymıyordu; saysaydı her cast sahte bir
doğrulama hatası üretirdi.

Kaynağı: `analysis/_retired/rad-lookup/` (gitignore'da) ve git geçmişinde
`e30ff8a`.

---

## 1. Şube yetkilendirmesi — şirket kapsamı DEĞİL

> **Düzeltildi.** Bu madde önce "zorunlu okuma-tarafı **şirket** kapsamı
> (`TRadScope`)" olarak yazılmıştı. Yanlıştı; şemadan doğrulandı.

**Şirket boyutu zaten çözülmüş — üstelik daha iyi bir şekilde.** `radcore`
merkezî kimlik veritabanı ve `sirket` tablosu şunları taşıyor:

```
sirket: db_host, db_port, db_adi, db_kullanici, db_sifre_sifreli
```

Her şirketin kendi veritabanı var; kullanıcı giriş sonrası o DB'ye bağlanıyor.
Şirket ayrımı **bağlantı sınırında** duruyor — sorguya predicate enjekte
etmeye gerek yok, çünkü unutulabilecek bir `where` hiç yok. Tek-veritabanı-
çok-kiracı tasarımından daha sağlam.

**Gerçek ihtiyaç şube boyutunda ve daha zor.** Şirket tek bir predicate'ti;
şube bir **matris**:

| | görebilsin | yazsın | düzeltsin |
|---|---|---|---|
| Merkez | ✓ | ✓ | ✓ |
| Şube A | ✓ | ✓ | ✗ |
| Şube B | ✗ | ✗ | ✗ |

Ve şirketin aksine şubeyi **hiçbir şey zorlamıyor** — bağlantı sınırı yok. Bir
raporda `where sube_id in (...)` unutulursa kullanıcı göremeyeceği şubenin
verisini görür ve yine hiçbir şey patlamaz.

**Bilinen (karar verildi):** yetki **iki yerde birden** duracak — rol JSON'ı
(`kullanici_rol.rol_yetkisi`) genel yetkiyi, şirket veritabanı şube listesini
ve kullanıcı-şube atamalarını tutacak. `TRadPermission`'ın ağaç modeli ve
`Storage = psDatabase` saklaması buna hazır; `radcore`'da yetkiler zaten üç
ayrı JSONB sütununda duruyor (`ayar.yetkiler`, `kullanici_rol.rol_yetkisi`,
`tokens.yetki_kapsami`).

**Açık soru (sonraya bırakıldı):** kullanıcı aynı anda **tek şube** mi görüyor,
**birden çok şube** mi, yoksa **ekrana göre mi** değişiyor? Cevap tasarımı
belirliyor:

- *Tek aktif şube* → tek predicate; şirket çözümünün aynısı, çok basit.
- *Çok şube* → `sube_id in (...)` **ve** satır bazında yazma/düzeltme denetimi;
  gerçek matris.
- *Ekrana göre* → en esnek, en çok kural.

Bu cevaplanmadan tasarıma girilmemeli — üç seçenek üç farklı bileşen demek.

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
