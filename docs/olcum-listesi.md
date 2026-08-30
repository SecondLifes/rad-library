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

### Ö-02 · "A" öneki sonrası tam regresyon — KISMEN ÖLÇÜLDÜ
Property adları değişti (`AComponent1`, `ACascadeField`, `ASearchDelay`, …).

**Ölçüldü (2026-08-30):** beş kaskad sondası da "A" önekine güncellendi ve
**Win32'de beşi de derliyor**; `RepoListenerTest`, `PullTest`,
`PerConsumerTest`, `DfmRoundTripTest` koşuyor ve yeşil. `PullTest` +
`RepoListenerTest` ayrıca **Win64**'te de derlendi ve koştu.
`DfmRoundTripTest` çıktısı `Properties.ACascadeField = 'kolon_yuku'`
gösteriyor — yeni adlar DFM'e yazılıp geri okunuyor.

**Bekleyen:**
1. `RuntimeTest` — görünür pencere + mesaj döngüsü şart, çalıştırılmadı.
2. `LiveLookupTest` — PostgreSQL kimlik bilgisi şart, çalıştırılmadı.
3. Kalan üç sondanın Win64 koşusu.
4. `Rad.Dev.pas` + `help.Dev.pas` **uyarısız** derleme iddiası hâlâ
   ölçülmedi; bugünkü derlemelerde `rad.config.pas` W1055 ve `help.uni`/
   `rad.db` kaynaklı bir dizi W1057/H2164 var (hepsi bu işten önce vardı).

> **Bu ölçümler bir KÜTÜKLE yapıldı.** `rad.pas`, çalışma ağacında
> `JclBase`/`JclSysInfo` (JEDI JCL) ve `Dext.Types.UUID` kullanıyor; üçü de
> bu makinede **yok** (`Dext.Types.UUID` hiçbir yerde, JCL yalnızca ilgisiz
> bir projenin çıktı klasöründe ve orada eski bir `SysUtils.dcu` gerçek
> RTL'i gölgeliyor). Sondalar geçici kütüklerle derlendi. **Gerçek
> bağımlılıklarla tekrar ölçülmeli** — `build_and_run.bat` artık `%EXTRAU%`
> ile ek birim yolu kabul ediyor.

### Ö-03 · Tasarım zamanı davranışı — hiç ölçülmedi
IDE dışından yapılamıyor, kullanıcı tarafında:
- Paletten forma bırakma, bileşenlerin görünmesi
- Object Inspector'da `AComponent1..4` açılır listesi doğru bileşenleri veriyor mu
- Yeni property'ler görünüyor ve gerçek bir `.dfm`'e yazılıp geri okunuyor mu
- "A" önekinin amacı: property'ler gerçekten üste toplanıyor mu

### Ö-04 · Gerçek klavye teslimi
`DoEditKeyPress` doğrudan çağrıldı; Windows'un tuşu iç edit kontrolüne
ilettiği yol ölçülmedi. Çalışan bir formda yazıp debounce'un hissedildiğini
görmek gerek.

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

### Ö-11 · Pull yönü — popup yolu (görünür pencere şart)
`AMaster`/`AOnFilter` başsız ölçüldü (`PullTest`, 22/22, Win32+Win64) ama pull
**elle** (`FilterNow`) tetiklenerek. Gerçek popup yolu başsız ölçülemez:
`TcxCustomDropDownEdit.DropDown`, `if not IsWindowVisible(Handle) then Exit`
ile başlıyor (`cxDropDownEdit.pas:3252`). Görünür bir formda ölçülecek:

1. `DroppedDown := True` → `AOnFilter` **bir kez** tetikleniyor mu?
2. **Sıra kanıtı:** `AOnFilter` içinde liste dataset'inin filtresi
   değiştirilince, açılan popup **yeni** filtrenin satırlarını mı gösteriyor?
   Bu, `LockDataChanged`'in (`cxLookupEdit.pas:309`) değişikliği
   bastırmadığını — yani pull'un `inherited`'dan **önce** durmasının doğru
   olduğunu — kanıtlayan tek ölçüm.
3. Grid inplace: `AMaster` bir **kolon** iken, odaklı satır değişince
   `AMasterValue` onu takip ediyor mu? `ASource._Host` kolonu veriyor mu?
4. `AFilterOnPopup := False` iken açılır listeyi açmak hiçbir şey
   tetiklemiyor mu?

### Ö-12 · Pull yönü — canlı veritabanı
`rad_test_ulke` / `rad_test_sehir` ile (`LiveLookupTest` deseni):

1. Popup açılışında **gerçek parametreli sorgu** koşuyor ve liste ülkeye göre
   süzülüyor mu — `AOnCascade` **atanmadan**?
2. Ülke değişip şehir listesi **hiç açılmadığında**, şehrin değeri
   `AClearTargetsOnCascade` ile temizleniyor mu? (Başsız ölçüldü ama gerçek
   veriyle değil.)
3. `FLookupList` bayatlığı: `GridMode := True` ile bir anahtar çözülüp
   önbelleğe girdikten sonra liste değişince, `ResetDisplayCache` olmadan eski
   metin dönüyor mu? Bu, `CheckLookupList` çağrısının gerekçesini ölçen tek
   test — şu an yalnızca kaynak okumasına dayanıyor.
