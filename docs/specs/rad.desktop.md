# Specification: ERP masaüstü (`rad.desktop`)

Durum: **uygulandı** (2026-11-04; ölçümler en altta). Kullanıcı tasarım konuşmasından sonra "hiçbir şey sormadan bütün
fazları yap" dedi. Bu yüzden açık kararlar, konuşmada önerilen varsayılanlarla kapatıldı. Hepsi aşağıda
**Varsayılan karar** olarak işaretli; kullanıcı dönünce itiraz edebilir.

## Bağlam

Büyük bir ERP'de (ERPPlus) yüzlerce komut var. Kullanıcı sık kullandıklarını, gerçek masaüstündeki gibi
gruplar halinde bir "masaüstüne" dizmek istiyor. Gruplar, Stardock Fences'teki gibi her zaman açık kutu ya
da Wolvox'taki gibi tıklayınca açılan klasör olabilir. Bunun yanında script ile beslenen canlı
kutucuklar (widget) ve DevExpress BI Dashboard'larına açılan kutucuklar da olacak. Görünüm şık olmalı.

### İncelenenler ve çıkan dersler

- **AkınSoft `TASAnaMenuDesktop` (2006):**
  - Konumu piksel olarak INI'ye yazıyor.
  - Kısayolu `FindComponent(Name)` ile buluyor; ad değişince kısayol sessizce kayboluyor.
  - Kaydetmeyi destructor'da yapıyor.
  - Yetki kontrolü yok.
  - İyi fikirleri: yazarak bulma ve ok tuşlarıyla en yakın öğeye geçiş. Bu ikisi alındı.
- **Wolvox 26:** Renkli klasör grupları, sağ tık menüleri ve özellikler popup'ı var. Görünümü kopyalanmadı,
  yalnızca rakip referansı olarak kullanıldı.
- **Fences 6:** Grup katlama (roll-up), sekmeler, hızlı gizleme ve sayfalar. En uzun süredir yaşadığı
  hata, çözünürlük değişince düzenin kaybolması. Bu yüzden konumlar **piksel değil, hücre** olarak
  saklanır.
- **SAP Fiori:** Yönetici varsayılanı ile kullanıcı farkı ayrı katmanlarda tutulur ve "varsayılana dön"
  vardır. Sayfa başına öneri: en çok 25 uygulama.
- **Rainmeter:** Script çizmez, değer üretir; yenileme hızı kısılır. Widget modeli buradan alındı.
- **DevExpress ExpressDashboards:** 100 MB'lık bir x64 .NET süreci (`VCLBackend.exe`), named pipe ve
  WebView2 kullanıyor; Windows 10 ve üstünü istiyor.
  - Müşteriler **ortak RDS sunucusunda** çalıştığı için bu bileşen hep açık duran masaüstüne konmaz.
  - Yalnız tıklanınca açılan ayrı bir öğe türü olur.
- **Çizim seçenekleri:**
  - Skia: `sk4d.dll` dağıtımı gerektiriyor.
  - WebView2 / CEF: kullanıcı başına süreç açıyor ve RDS'de bu süreçler çoğalıyor.
  - Image32: yeni bir vendor ekliyor.
  - **Seçilen: RTL'deki GDI+ (`Winapi.GDIPOBJ`).** Yazılımla çizer, GPU istemez; RDS'de tutarlı
    davranır, ek bağımlılık getirmez.

## Kararlar

| # | Karar | Durum |
|---|---|---|
| 1 | Çizim: RTL GDI+, tek pencere, kendi çizen yüzey (`TCustomControl`) | Varsayılan karar |
| 2 | Yerleşim: ızgaraya oturan serbest yerleşim; konum hücre olarak saklanır | Varsayılan karar |
| 3 | Grup biçimi: `kutu` (Fences, her zaman açık, katlanır) ve `klasör` (tıklayınca açılan panel) | Varsayılan karar |
| 4 | Widget: script veri üretir, hazır şablonlar çizer | Varsayılan karar |
| 5 | Kalıcılık: şirket katmanı ve kullanıcı katmanı, `TRadStateRepository` üzerinden | Varsayılan karar |
| 6 | Dashboard: ayrı öğe türü, ilk tıklamada açılır; masaüstü DevExpress Dashboards'a bağımlı değildir | Varsayılan karar |
| 7 | Uzak oturum (`SM_REMOTESESSION`): animasyon ve blur kapanır | Ölçümle doğrulanacak |

## Kullanıcı hikâyeleri

1. **Kullanıcı olarak** sık kullandığım menü komutlarını gruplar halinde masaüstüne koymak istiyorum,
   **böylece** menüde aramadan tek tıkla açarım.
2. **Kullanıcı olarak** grupları sürükleyip yerleştirmek, renk ve ikon vermek, katlamak istiyorum.
3. **Kullanıcı olarak** klavyeyle (oklar, Enter, yazarak bulma) kısayolları kullanmak istiyorum.
4. **Yönetici olarak** şirkete varsayılan bir masaüstü vermek istiyorum. Kullanıcı bunu kendine göre
   değiştirebilmeli ve "varsayılana dön" ile geri alabilmeli.
5. **Script yazarı olarak** veriyi script'le üreten bir widget (KPI, liste, mini grafik) eklemek
   istiyorum, **böylece** derleme yapmadan canlı bilgi gösterebilirim.
6. **Kullanıcı olarak** bir Dashboard kutucuğuna tıklayınca BI dashboard'unun açılmasını istiyorum.

## Kabul kriterleri (EARS)

1. **WHEN** bir kısayolun hedef komutu bulunamazsa **THE SYSTEM SHALL** kısayolu silmeden soluk ve
   "kırık" olarak çizer; tıklandığında çalıştırmaz.
2. **WHEN** kullanıcının komuta yetkisi yoksa **THE SYSTEM SHALL** kısayolu çizimde gizler. Yetki her
   çizimde çözülür, kayıt anında değil.
3. **WHEN** bir kısayola tıklanırsa ya da odaktayken Enter'a basılırsa **THE SYSTEM SHALL** komutu
   kaynağı üzerinden çalıştırır (`TAction.Execute`, `TMenuItem.Click`, `ICmds.Execute`).
4. **WHEN** bir grup bırakılırsa **THE SYSTEM SHALL** onu en yakın boş hücreye oturtur. Çakışan grupları
   aşağı iter.
5. **WHEN** pencere boyutu ya da DPI değişirse **THE SYSTEM SHALL** grupları kaybetmez. Sığmayan grup en
   yakın görünür hücreye taşınır; kayıttaki hücre değişmez.
6. **WHEN** bir kutu grubunun başlığına çift tıklanırsa **THE SYSTEM SHALL** grubu katlar ya da açar.
   Durum kalıcıdır.
7. **WHEN** bir klasör grubuna tıklanırsa **THE SYSTEM SHALL** öğelerini grubun yanında bir panelde
   açar. Dışarı tıklanınca ya da Esc'ye basılınca panel kapanır.
8. **WHEN** kullanıcı harf yazarsa **THE SYSTEM SHALL** başlığı Türkçe büyük/küçük harf duyarsız eşleşen
   ilk görünür kısayola odaklanır. Yazım 1 saniye susunca sıfırlanır.
9. **WHEN** ok tuşuna basılırsa **THE SYSTEM SHALL** o yöndeki en yakın kısayola odaklanır.
10. **WHEN** düzen değişirse **THE SYSTEM SHALL** kaydı geciktirerek (debounce) yazar, destructor'da
    değil. Hiçbir değişiklik kaybolmaz: `Flush` ve `Kapat` bekleyen kaydı yazar.
11. **WHEN** şirket katmanına yeni bir grup ya da öğe eklenirse **THE SYSTEM SHALL** onu kendi düzenini
    değiştirmiş kullanıcılara da ekler. Kullanıcının kaldırdığı şirket öğeleri geri gelmez.
12. **WHEN** "Varsayılana dön" seçilirse **THE SYSTEM SHALL** kullanıcı kaydını siler ve şirket düzenini
    gösterir.
13. **WHEN** widget'ın yenileme süresi dolarsa **THE SYSTEM SHALL** veriyi sağlayıcıdan alır. Bir
    sağlayıcının hatası yalnız o widget'ta "hata" olarak çizilir, masaüstünü düşürmez.
14. **WHEN** uygulama uzak masaüstü oturumunda çalışırsa **THE SYSTEM SHALL** animasyonları ve blur'u
    kapatır.

## Fonksiyonel olmayan gereksinimler

- **Performans:** Arka plan ve grup çerçeveleri önbellekli bir bitmap'te tutulur; değişince yeniden
  çizilir. Hover ve odak yalnızca önbelleğin üstüne çizilir. 200 kısayolluk bir düzende ölçüm sonucu
  test kaydına yazılır.
- **Uyumluluk:** Delphi 13 ve üstü (37.0), Win32 ve Win64, VCL. Yalnız RTL GDI+ kullanılır.
- **DPI:** Bütün ölçüler 96 DPI mantıksal piksel olarak tanımlanır ve `ScaleValue` ile ölçeklenir.

## Veri modeli

`src/core/rad.desktop.core.pas` (RTL + mORMot):

- `TRadDeskItem`:
  - `Id`
  - `Kind`: `dkShortcut`, `dkWidget` ya da `dkDashboard`
  - `Target`: komut kimliği, widget sağlayıcı kimliği ya da dashboard adı
  - `Caption`: boşsa kaynaktan gelir
  - `Size`: widget için `dsSmall`, `dsWide` ya da `dsLarge`
  - `Settings`: JSON metni
- `TRadDeskGroup`:
  - `Id`, `Title`
  - `Color` (ARGB)
  - `Style`: `gsBox` ya da `gsFolder`
  - Konum ve boyut hücre olarak: `Col`, `Row`, `Cols`, `Rows`
  - `Collapsed`
  - `Items`
- `TRadDeskLayout`:
  - `Groups`
  - `Removed`: kullanıcının kaldırdığı şirket kimlikleri
  - `BaseVersion`
  - `ToJson` / `FromJson`, `MergeBase`
- `TRadDeskGrid`: hücre yerleşimi, boş hücre bulma, çakışma çözme. Saf mantık, test edilir.
- `TRadDeskNav`: yöndeki en yakın dikdörtgen ve Türkçe harf duyarsız eşleşme.

JSON örneği:

```json
{"schema":1,"baseVersion":3,"removed":["g-satis"],
 "groups":[{"id":"g1","title":"Satış","color":4282557941,"style":"box","col":0,"row":0,
   "cols":4,"rows":3,"collapsed":false,
   "items":[{"id":"i1","kind":"shortcut","target":"act:actFatura"}]}]}
```

Kayıt anahtarları (`TRadStateKey`):
- Şirket katmanı: `desktop\base`.
- Kullanıcı katmanı: `desktop\user.<kullanıcı>`.

## Komut kaynakları

`src/core/rad.desktop.commands.pas`:

- `IRadDeskCommandSource`: `Prefix`, `Enumerate`, `Find`, `Execute`.
- `TRadDeskCommands`: kaynakları toplar. Bir kimlik `önek:ad` biçimindedir. Yetki kontrolü
  `TFunc<string, Boolean>` ile ya da `rad.permission` üzerinden yapılır.
- `rad.cmd` kaynağı: `ICmds` bir başlık, kategori ve ikon tutmuyordu. Bu bilgileri tanım kaydı
  (`Describe`) ekler.

`src/component/rad.desktop.sources.pas` (VCL):
- `act:`: `TCustomActionList` kaynağı. `Update` çağrılarak `Enabled` okunur.
- `menu:`: `TMenu` kaynağı. Kategori, üst menü başlıklarından kurulur.

## Görünüm

`src/component/rad.desktop.view.pas`:

- `TRADDesktopView`:
  - Çizim ve önbellek.
  - Fare: tıklama, hover, sürükleme, bırakma.
  - Klavye.
  - Klasör paneli.
  - Düzenleme işlemleri: grup ekle, sil, yeniden adlandır, renk.
- `src/component/rad.desktop.paint.pas`: tema ve GDI+ çizim yardımcıları (yuvarlak dikdörtgen, gölge,
  cam, klasör glifi).
- Sağ tık menüleri ve diyaloglar DFM'dedir: `rad.desktop.dialogs.pas/.dfm`.
- Yeni kısayol seçicisinde aranabilir bir komut listesi vardır.

## Widget

- `src/core/rad.desktop.widgets.pas`:
  - `TRadDeskWidgetData`: başlık, değer, alt metin, eğilim, liste, seri.
  - `IRadDeskWidgetProvider` ve kayıt.
  - Hazır sağlayıcı: `clock`.
- `src/vendor/tms/rad.desktop.script.pas`: script sağlayıcı. Bir paket script'indeki
  `<Kod>_Yenile(W)` yordamı veriyi doldurur. Script dili TMS'in desteklediği herhangi biri olabilir.

## Dashboard

`dkDashboard` öğesi `OnOpenDashboard` olayını tetikler. Dashboard bileşeni host tarafında açılır.
Masaüstü ExpressDashboards'a bağımlı değildir; RDS'de yönetici bu öğe türünü kapatabilir
(`AllowDashboards`).

## Entry Unit and Setup Call

- **Entry unit:** `rad.desktop`.
- **Re-exported types:**
  - `TRADDesktopView`
  - `TRadDeskLayout`, `TRadDeskGroup`, `TRadDeskItem`
  - `IRadDeskCommandSource`, `TRadDeskCommands`
  - `IRadDeskWidgetProvider`, `TRadDeskWidgetData`
  - `TRadDeskTheme`
- **Cannot be aliased:** Enum değerleri. Bunlar `const` olarak yeniden verilir (`dkShortcut`, `gsBox`
  vb.).
- **Setup call:**
  - `TRadDesktop.Kur(AView, ARepository, AUser)` kaydı bağlar, şirket ve kullanıcı katmanlarını yükler.
  - `TRadDesktop.Ekle(ASource)` bir komut kaynağı ekler.
  - `TRadDesktop.Kapat` bekleyen kaydı yazar.
- **Acceptance:** Demo uygulaması yalnız `rad.desktop` unit'ini ekleyerek çalışır.

## Uygulama notları ve ölçümler (2026-11-04)

Uygulandı. Testler Win32 ve Win64'te: çekirdek 33/33, görünüm + mağaza + facade 25/25, script widget 5/5.
Demo uygulaması `src/test/scratch/rad_desktop/DesktopDemo.exe -shot <klasör>` ile 7 ekran görüntüsü üretir.

- **Ölçüm** (1184×761 piksel, 200 kutucuk, 5 tekrarın ortalaması):
  - Sahnenin yeniden çizimi: Win32 87 ms, Win64 92 ms.
  - Yalnız hover ya da odak yenilemesi: 1,1 / 1,2 ms.
  - Sahne yalnız düzen ya da widget verisi değişince yeniden çizilir; widget verisinin `Signature`'ı
    karşılaştırılır. Saat bu yüzden saniyede bir değil, dakikada bir yeniden çizdirir.
- **Spec'ten sapmalar:**
  - "Düzenleme modu" yerine `Locked` özelliği var. Sürükleme Fences'teki gibi her zaman açıktır;
    `Locked` açıkken sürükleme ve düzenleme menüleri kapanır.
  - Grup yüksekliği içeriğe göre otomatik hesaplanır; yalnız genişlik (`Cols`) saklanır.
- **DPI:** Pencereli bir kontrolde `CurrentPPI`, `GetDpiForWindow` değerini döndürür. Form `Scaled`
  değilse `ChangeScale`'in kaydettiği değer döner. Bu yüzden DPI testi `Scaled := False` ve
  `ChangeScale(144, 96, True)` kullanır. Bu, VCL'in `WM_DPICHANGED` sırasında yaptığı çağrının
  aynısıdır. `ScaleForPPI`, DPI-aware olmayan bir konsol uygulamasında hiçbir şey yapmaz (ölçüldü).
- **TMS script:** İstisna `raise Exception.Create(...)` ile değil, `Raise('mesaj')` ile atılır.
  İlki derlemede "method 'raise' expects 1 parameter" hatası verir.
- **İkon:** Masaüstü, ikonu `Images` listesinin kendi boyutunda çizer. Yüksek DPI'da net ikon için
  host'un SVG tabanlı bir `TVirtualImageList` vermesi gerekir. İkonu olmayan komut, baş harfli renkli
  bir kare olarak çizilir.
- **Paket derlemesi:** RadKon ve RadKonD depo içindeki geçici bir klasöre derlendi; kurulu BPL'lere
  dokunulmadı. MSBuild, birimlerin C++ başlıklarını (`rad.desktop*.hpp`) yine de
  `%PUBLIC%\Documents\Embarcadero\Studio\37.0\hpp\Win32` klasörüne yazdı.

## Kapsam dışı

- Birden çok sayfa ve sekmeli grup. İleride eklenebilir.
- Kullanıcının widget'ı kendi elle çizmesi (script'le `Canvas`'a çizim).
- DevExpress Dashboard'un kendisini açmak. Bu, host'un işidir.
