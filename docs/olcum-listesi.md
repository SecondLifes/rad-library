# Ölçüm Listesi — biriken doğrulamalar

Çalışma sırasında ölçüm yapılmıyor; doğrulanması gereken her şey buraya
yazılıyor ve **işler bittikten sonra toplu olarak** ölçülüyor.

Bir madde ölçülüp geçtiğinde satır silinir — kalıcı kayıt `git log` ve
`CHANGELOG.md`'dir, burası yalnızca bekleyenlerin listesi.

## Nasıl ölçülür (bu oturumda yerleşen kurallar)

- **Sondalar kendi dizininden derlenir.** `dcc32`, `.dpr` içindeki `in '...'`
  yollarını çalışma dizinine göre çözüyor; depo kökünden derlemek sahte
  "dosya bulunamadı" verir. Mutlak `-U` listesi `%TEMP%\radabs.txt`.
- **Görünür pencere şart** olan testler var: DevExpress, görünmeyen bir gridde
  inplace editör açmıyor (minimize edilmiş pencerede `EditingItem` nil kalıyor).
- **Canlı veri şart:** boş string / 0 / `nil` birim testinde geçerli görünür.
  Doğru *değer* iddiası ancak gerçek veriyle doğrulanır. Yerel PostgreSQL
  hazır; yalnızca `rad_test_*` tabloları yaratılıp silinir, mevcut tablolara
  dokunulmaz.

---

## Bekleyen ölçümler

### Ö-01 · `default` direktifi ↔ constructor uyumu
`ASearchDelay default 500` ve `AMinSearchLength default 3`; constructor da
ikisini atıyor (kaynaktan okundu, çalıştırılmadı). Ölçülecek:

1. Taze bir `TRadLookupComboBoxProperties` gerçekten 500 / 3 ile mi geliyor?
2. Varsayılan değerdeyken DFM'e **yazılmıyor** mu?
3. Değiştirilmiş değer (örn. 250 / 0) DFM'e **yazılıyor** mu ve geri okunuyor mu?

Neden önemli: `default` ile constructor ayrışırsa değer sessizce kaybolur ya da
gereksiz yere streamlenir. Kitin bileşen kuralının özellikle uyardığı hata.
Yeri: `src/test/scratch/rad_dev_repolisteners/DfmRoundTripTest.dpr`.

### Ö-02 · "A" öneki sonrası tam regresyon — ÖLÇÜLDÜ, KAPANDI
Beş kaskad sondası "A" önekine güncellendi; hepsi **Win32 ve Win64'te sıfır
tanıyla derliyor**. Sondalar artık gerçek kapı (RADDEV-008): assert ediyorlar
ve hatada non-zero çıkıyorlar.

| Sonda | Sonuç |
|---|---|
| `PullTest` | 73/73, iki platform |
| `DestructorTest` (yeni) | 6/6, iki platform |
| `RepoListenerTest` | 14/14, iki platform |
| `PerConsumerTest` | 6/6, iki platform |
| `DfmRoundTripTest` | 7/7, iki platform |
| `RuntimeTest` | 8 geçti, **1 atlandı** (Ö-04 — aşağıya bakın), görünür pencereyle koştu |
| `LiveLookupTest` | 18/18, canlı PostgreSQL, iki platform |

> **Kalan tek kısıt: kütükler.** `rad.pas` çalışma ağacında `JclBase`,
> `JclSysInfo` (JEDI JCL) ve `Dext.Types.UUID` kullanıyor; üçü de bu makinede
> yok. Bütün ölçümler geçici kütüklerle yapıldı. Kütükler yalnızca boş klasör
> yolu döndüren fonksiyonlar ve bir tip takma adı içeriyor; bu sondaların
> hiçbiri onları kullanmıyor — ama **gerçek bağımlılıklarla tekrar
> ölçülmelidir**. `build_and_run.bat` `%EXTRAU%` ile ek birim yolu kabul
> ediyor.

### Ö-03 · Tasarım zamanı davranışı — hiç ölçülmedi
IDE dışından yapılamıyor, kullanıcı tarafında:
- Paletten forma bırakma, bileşenlerin görünmesi
- Object Inspector'da `AComponent1..4` açılır listesi doğru bileşenleri veriyor mu
- Yeni property'ler görünüyor ve gerçek bir `.dfm`'e yazılıp geri okunuyor mu
- "A" önekinin amacı: property'ler gerçekten üste toplanıyor mu

**Pull yönüyle gelen yeni yüzey (aynı şekilde ölçülmedi):**
- `AMaster` açılır listesi — editör olmayan bir bileşen seçilince `ERadDev`
  fırlıyor; IDE bunu kullanıcıya makul bir şekilde gösteriyor mu, yoksa
  tasarımcıyı bozuyor mu?
- `AAutoFilter` enum'u Object Inspector'da görünüyor mu (kitin RTTI kuralı:
  açık değer atanmamış, bu yüzden görünmeli — ama doğrulanmadı)
- `TRadChainAuditEditor` — sağ tık menüsünde "Zinciri denetle..." çıkıyor mu ve
  rapor doğru mu? **Bu birim bu araç zincirinde hiç derlenmedi**
  (`DesignEditors.dcu` yok); yalnızca okunarak doğrulandı.

### Ö-04 · Gerçek klavye teslimi — ÖLÇÜLDÜ ve DOĞRULANDI (açık kalıyor)
`DoEditKeyPress` doğrudan çağrıldı; Windows'un tuşu iç edit kontrolüne
ilettiği yol ölçülmedi.

**Artık kanıtı var.** `RuntimeTest`'in A1 durumu (`ASearchDelay = 0`, altı tuş
→ altı arama) **sıfır** ölçüyor ve sonda var olduğundan beri öyle. Sebep
bulundu: gecikme kapalıyken arama `TRadLookupEditLookupData.Locate`
dikişinden tetikleniyor, oraya varmak için tuşun **gerçek pencereli bir iç
edit kontrolüne** teslim edilmesi gerekiyor; sonda `DoEditKeyPress`'i
doğrudan çağırdığı için taban sınıfın tuş işleme yolu hiç koşmuyor.
Geciktirici yolu (A2/A3) etkilenmiyor — orada arama `TTimer`'dan,
`EditingText` ile geliyor, ve o iddialar **geçiyor**.

Sonda bunu artık `[ATLA]` olarak bildiriyor: ne yeşil yalanı ne de bileşen
hatası ima eden kırmızı. Gerçek ölçüm, bir kullanıcının klavyeden yazdığı
canlı bir formda yapılabilir.

### Ö-05 · `PermissionTest.dpr` kırık — karar bekliyor
`IsFieldLinked`, `DataSet`, `TreeField` çağırıyor; `TRadPermission` artık
`DataBinding` + `Storage` kullanıyor. Ölçüm değil, tasarım kararı: yeni API'de
`IsFieldLinked`'in karşılığı ne olmalı?

### Ö-06 · Ayar paneli — tasarım zamanı davranışı
`k.setting.pas` başsız olarak ölçüldü (52/52, Win32+Win64) ama IDE içinde hiç
açılmadı. `AfterConstruction` `csDesigning` durumunda olay bağlamadan çıkıyor;
doğrulanacak:

1. Frame bir forma bırakıldığında IDE hata vermeden açıyor mu?
2. DFM'den tasarım zamanı örnek satırları çıkarıldı — tasarımcıda NavBar ve
   izgara **boş** görünmeli, bu beklenen durum.
3. Çalışma zamanında `AddMenu`/`Register` sonrası NavBar grup+öğe hiyerarşisi
   gerçekten görünüyor mu? (`CreateLink` çağrılmazsa öğe sessizce görünmez —
   kod bunu yapıyor, ama gözle doğrulanmadı.)

### Ö-07 · Ayar paneli — gerçek etkileşim (görünür pencere şart)
Sonda modeli ölçüyor, çizimi değil. Görünür bir formda doğrulanacak:

- NavBar öğesine tıklayınca yalnızca o alt grubun satırları kalıyor mu?
- Arama kutusuna yazınca kategoriler arası filtre gözle doğru mu, kategori
  satırı eşleşmesi olmayınca gizleniyor mu?
- Bir değeri **elle düzenleyince** `OnEditValueChanged` → depo yolu çalışıyor
  mu, `Modified` True oluyor mu? (DevExpress görünmeyen izgarada inplace
  editör açmıyor — bu yüzden başsız ölçülemedi.)
- `FUpdating` sayacı gerçekten döngüyü kesiyor mu (Refresh → satır → olay →
  depo → satır). Kodda var, canlıda görülmedi.

### Ö-08 · Karar: `k.setting` `RadKon.dpk`'ye girsin mi?
Şu an pakette **değil**. Girerse `requires`'a **`dxNavBarRS37`** eklenmesi
gerekir — bugün orada yok (`cxTreeListRS37` ve `cxVerticalGridRS37` var).
Bu, kütüphaneyi kullanan herkese yeni bir DevExpress çalışma zamanı paketi
bağımlılığı demek. `Permission.Edit` pakette çünkü tasarım zamanı editörü;
`k.setting` bir uygulama ekranı — belki uygulamada kalmalı. Karar kullanıcının.

### Ö-09 · Kalıcılık bağlantısı (şirket / kullanıcı kapsamı)
Panel `LoadJson` / `SaveJson` / `Doc` dikişlerini veriyor; DB tarafı henüz
bağlı değil. `radcore.ayar` tablosu ve `kullanici` ile eşleme yapıldığında
ölçülecek: aynı şirkette iki kullanıcının ayarları birbirine karışmıyor mu,
kullanıcıda olmayan bir anahtar şirket seviyesinden düşüyor mu.

### Ö-10 · Ayar paneli — iki görsel karar (ölçüm değil, karar)
Tasarım konuşmasında soruldu, cevaplanmadı, bugüne kadar hiçbir dosyada
yazmıyordu:

1. **Katman rozeti kalsın mı?** Maketlerde her satırın yanında değerin hangi
   katmandan geldiğini gösteren bir rozet vardı (Şirket / Kullanıcı).
   Panelde şu an **yok**. Rozet ancak katmanlama gerçekleşince (Ö-09) anlamlı.
2. **Uygula düğmesi mi, anlık kayıt mı?** Şu an **anlık**: değişiklik hemen
   `IDocDict`'e yazılıyor, `Modified` işaretleniyor, DB'ye yazma anı çağırana
   bırakılıyor. Bu bilinçli bir varsayılan, onaylanmış bir karar değil.

İkisi de Ö-09 ile birlikte ele alınmalı.

### Ö-11 · Pull yönü — popup yolu — ÖLÇÜLDÜ, KAPANDI
`PullPopupTest.dpr` (yeni, görünür pencere), 9/9, Win32 **ve** Win64:

1. `DroppedDown := True` → `AOnFilter` **tam bir kez** tetikleniyor; `AMaster`
   ve `AMasterValue` doğru.
2. **SIRA KANITI.** İşleyici tam o anda listeyi `ulke_id = 2`'ye süzüyor;
   popup açıldıktan **sonra** filtre ayakta ve liste 2 satır (6 olsaydı
   `LockDataChanged` değişikliği bastırmış olurdu). Pull'un `inherited`'dan
   **önce** durmasının tek gerçek ölçümü budur — daha önce yalnızca kaynak
   okumasına dayanıyordu.
3. `AFilterOnPopup := False` iken açılır listeyi açmak hiçbir şey
   tetiklemiyor.
4. Master bir grid **kolonu** iken `AMasterValue` odaklı satırın değerini
   veriyor (2) ve `ASource`'tan `_Host` ile `colSehir`'e ulaşılıyor.

> Bu sondayı yazarken kitin kendi `helper-patterns` kuralındaki tuzağa
> düşüldü ve orada da kayıtlı: **yalnızca EN YAKIN class helper görünür.**
> `uses`'ta `Help.Dev`'i `Rad.Dev`'den önce yazmak `_Host`'u gizliyor ve hata
> `E2029 ')' expected but identifier '_Host' found` olarak çıkıyor — sebebi
> hiç belli olmayan cinsten. `Help.Dev` en sonda olmalı.

### Ö-12 · Pull yönü — canlı veritabanı — ÖLÇÜLDÜ, KAPANDI
`LiveLookupTest` M5b + M6-M9, yerel PostgreSQL, Win32 **ve** Win64, 18/18:

- **M6** bir açılışta **tek** sorgu; `ulke_id` kurulu, arama nötr değerle
  açılmış, Türkiye için 4 satır.
- **M7** üç harf yazınca ikinci sorgu koşuyor ve `ulke_id` **hâlâ** doğru —
  parametreler birbirinin `Close`/`Open`'ını atlatıyor.
- **M8** master değişip liste açılınca eski arama metni **etkisiz**; Almanya 2
  satır (eski metin kalsaydı 0 olurdu).
- **M9** 40 şehirli ülkede SQL'in `limit 15`'i tutuyor.
- **M5b** `SQL.Text`'i baştan atayan bir işleyicinin master parametresini yok
  ettiği canlıda ölçüldü (`Parameter 'ulke_id' not found`).

Yalnızca `rad_test_*` tabloları yaratıldı ve çıkarken silindi.
