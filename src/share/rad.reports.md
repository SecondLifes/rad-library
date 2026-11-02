# RadReports (`rad-library/src/share/rad.reports` + `rad.reports.manage`)

FastReport VCL tabanlı ortak rapor sistemi; bir bileşen gibi her programda kullanılır. Kurulu kaynak: FastReport
2026.1.1 VCL Extended. Sahibiyle 2026-11-01'de netleşen sözleşme: **yetki, sahiplik, paylaşım, tür YOK**; iki arayüz,
tek giriş noktası; iş nesnesi; `Data(qry, 'ad')`; Ribbon yönetim formu; thread desteği şimdilik yok.

## Kullanım — bir birim yeter

Programa yalnız `rad.reports.pas` eklenir (`.dpr`: `rad.reports in '..\..\..\rad-library\src\share\rad.reports.pas'
{RadReportsDM: TDataModule}`). `rad.reports.manage` aynı klasörde durur; derleyici kendisi bulur.

```pascal
uses rad.reports;

Reports := TRadReports.New(dmERP.cnSirketDB, Oturum.UserName);     // bir kez, bağlantı başına (dmERP'de bir alan)

// düğme: Ctrl → yönetim formu; tasarım yoksa tasarımcı; tek tasarım → önizleme; birden çok → menü
Reports.Report('kasa.liste').Data(sql_arama, 'Kasalar').Data(sql_bakiye, 'Kasa Bakiye').Run;
Reports.Report('kasa.liste').RunDefault;                              // sormadan varsayılan tasarım
Reports.Report('kasa.liste').Data(qry).Param('baslik', 'Kasa').FileName('kasa-{Kasalar|kod}-{tarih}').Export(rfPdf, 'c:\cikti');
Reports.Report('kasa.liste').Data(qry).AddToMenu(mnuRaporlar);        // formun sağ tık menüsüne
Reports.Shared(qrySirket, 'sirket');                                  // her rapora giren sabit veri kümesi
Reports.LoadDefaults('..\asset\rapor');                               // yalnız eksik tasarımları oluşturur (elle)
```

- **İş nesnesi** (`Report(...)` her çağrıda yenisini verir): `Data`, `Param`, `FileName`, `OnFileName/OnBeforeExport/OnAfterExport`;
  `Run`, `RunDefault`, `Preview`, `Design`, `Print` (diyaloglu), `Export`, `Mail`, `Upload`, `Manage`; `Actions`, `AddToMenu`;
  `List`, `Versions`, `Copy`, `Delete`, `SetDefault`, `Restore`, `DeleteOldVersions`, `ResetVersions`, `SyncToLocal`,
  `PushFromLocal`. Her iş nesnesinin **kendi `TfrxReport` motoru** vardır: iki formun işleri birbirine karışmaz
  (`TwoJobs_DoNotMix` testi). Export filtreleri, bulut taşıyıcıları ve tasarımcı ortaktır (durum taşımazlar).
- **Servis**: `Report`, `Shared/Unshare`, `LoadDefaults`, `SetupMail`, `SetupCloud`, `LocalFolder`, varsayılan olaylar.
- `Export`/`Mail`/`Upload` birden çok tasarımda ad verilmezse `ERadReportDesignRequired` atar (menü çıkmaz);
  `Run`/`Preview`/`Print`/`Design` menü çıkarır.
- `AddToMenu(AMenu)`: ● varsayılan / tasarımlar → Önizle; Yazdır; Dışa aktar ▸ (biçimler, kaydet diyaloğu); E-posta ile gönder
  (FastReport posta diyaloğu); Tasarla ▸; Yeni tasarım; Rapor Yöneticisi. Tasarım yoksa yalnız son ikisi. Bağlı `TPopupMenu`'nün
  `OnPopup`'ında yenilenir (mevcut `OnPopup` korunur). Dataset'ler tıklama anında açık olmalı (sahibi host).
- Cephe adı **`RaporDM`/`Rapor` değil `Reports`**: bir `rad.reports.*` birimini kullanan kodda `Rapor.X` yazımı birim adı öneki
  sayılır (derleme hatası, denendi). Host değişkenine istediği adı verir.

## Veri ve dosya adı

- `Data(qry, 'ad')`: ad boşsa `qry.Name`, o da boşsa `ERadReport`. Aynı adla ikinci çağrı öncekinin yerine geçer; servisin
  `Shared` veri kümesini gölgeler. Köprü (`TfrxDBDataset`) komut süresince yaşar, komut bitince bırakılır; dataset'e dokunulmaz.
- Dosya adı şablonu `{veri|alan}` ve `{param}`: tarih `yyyy-mm-dd`, tutar 2 ondalık nokta ayraçlı, `\ / : * ? " < > |`
  temizlenir, yol 240 karakteri aşmaz, aynı ad varsa `-2`, `-3`. Olaylar `OnFileName → OnBeforeExport → (yaz) → OnAfterExport`;
  iş nesnesindeki olay servistekinin önüne geçer. PNG/JPEG sayfa başına dosya yazar (`ad.1.png`); bildirilen yol ilk sayfadır.
- Varsayılan tasarım dosyaları: `<anahtar>.fr3` (tasarım `Varsayılan`) ya da `<anahtar>@<tasarım>.fr3`. `LoadDefaults` **yalnız
  eksik** tasarımı oluşturur, var olana dokunmaz, otomatik çağrılmaz (silinen tasarım açılışta geri gelmesin diye).

## Tasarımlar ve sürümler

- Bir anahtarın birden çok tasarımı; `(anahtar, ad)` benzersiz; ilk tasarım varsayılan, varsayılan silinirse en eski kalan
  devralır. Tasarım yoksa `Design` boş tasarımcı açar, Kaydet ilk tasarımı yaratır; `Report(key, 'Yeni ad').Design` adlı tasarım
  yaratır. Kaydet = yeni sürüm; **çakışma SHA-256 ile** (sürüm numarası sıfırlamadan sonra yeniden kullanılır).
- `Delete`, `DeleteOldVersions`, `ResetVersions` öncesinde içerik `<LocalFolder>\_deleted\<anahtar>@<tasarım>_v<N>_<zaman>.fr3`
  olarak yedeklenir. `LocalFolder` varsayılanı `%APPDATA%\<uygulama adı>\Reports`.
- Yerel çalışma kopyası: `SyncToLocal` → `<LocalFolder>\<anahtar>\<tasarım>.fr3` + `.report.json` (id, sürüm, SHA);
  `PushFromLocal` değişmişse yeni sürüm, DB de değişmişse `ERadReportConflict`.

## Yönetim formu (`rad.reports.manage`)

`TRadReportManageForm : TdxRibbonForm` — Tasarımlar (Önizle, Yenile | Tasarla, Yeni tasarım, Kopyala, Varsayılan yap, Kalıcı sil),
Sürümler (Geri yükle, Eskileri sil, Sürümü sıfırla), Yerel dosya (Yerele eşitle, Değişikliği yükle, Klasörü aç). Ribbon belgeli
koda dayalı yöntemle kurulur (`TdxBarManager` + `TdxRibbon`); gridler, eylemler ve sağ tık menüleri DFM'de. Simgeler
`Segoe MDL2 Assets` yazı tipinden üretilir (Windows 10+). Form `ui-components.md` standart 1'in bilinçli istisnasıdır: Ribbon
yalnız `TdxRibbonForm` ile doğru çalışır ve kütüphane ERP'ye özgü `base.form`'a bağlanamaz. Önizle/Tasarla, verilen iş
nesnesinin veri kümelerini `IRadReportInternal.Clone` ile seçili tasarıma taşır.

## Bileşen kümesi (bilerek dar)

Var: nesne modülleri (barkod, grafik, rich, OLE, cross, tablo, harita, hücresel metin, posta kodu, onay kutusu, gradyan, HTML,
PDF nesnesi, GZip, Crypt), PascalScript + Classes/Graphics/DB/Chart RTTI; export PDF, XLSX, DOCX, PPTX, HTML, CSV, RTF, ODS, ODT,
XML, metin, PNG, JPEG, SVG; posta (`TfrxMailExport`); bulut Dropbox, OneDrive, Box, Google Drive, GMail, Yandex Disk, Outlook,
NextCloud, S3, FTP. Yok: dot-matrix, ZPL, PostScript, DBF, EMF, BMP, GIF, diyalog sayfaları, ADO/FireDAC/JScript script
modülleri. **Script güvenliği:** `.fr3` PascalScript içerir ve çalıştıranın oturumunda yürür; yetki olmadığından her kullanıcı
her tasarımı değiştirebilir (sahibin kararı). FastReport'un script kısıtı sunup sunmadığı doğrulanmadı (ERPPlus YAP-64).

## Dersler (denemeyle bulundu)

- **Köprüler şablon yüklenmeden ÖNCE kurulur** (`CreateBridges`, sonra `LoadFromStream`, sonra `BindData`). `UseGlobalDataSetList`
  kapalıyken bant ve görünümler `DataSetName`'i yükleme anında `EnabledDataSets`'te arar; bulamazlarsa `DataSet` nil kalır ve sonradan
  bağlanmaz. Sonuç hatasızdır ama satırsızdır, tasarımcıda bant "atanmamış" görünür; `.fr3` sağlamdır. Bu yüzden testler dosya adını
  değil çıktının içeriğini denetler.
- `TfrxDBDataset` varsayılan aralıkta (`rbFirst`) imleci geri getirmez ve bağlı grid'i dolaşır: `AddBridge` yer imi alıp
  `DisableControls` çağırır, `PrepareSilent` sonrası ve `UnbindData`'da seçili satıra dönülür (dosya adı şablonu hazırlıktan sonra okunur).
- Açık menüde alt menü yenilenmez: Windows alt menüyü açarken `WM_INITMENUPOPUP` gönderir, VCL bunu öğenin `Click`'ine çevirir
  (`TMenu.DispatchPopup`; `TJvPopupMenu` de aynı yoldan). Orada `Clear` + yeniden doldurmak hem her gezişte SQL çalıştırır hem de
  sayı sıfıra düşüp yeniden çıktığı için üst menüyü söküp takar (`TMenuItem.Delete/Insert`, `MenuChanged(True)`): alt menü gelmez, ekran
  titrer. Açılır menüde liste yalnız `OnPopup`'ta yenilenir; `FillMenu` yeni öğeleri ekledikten sonra eskileri siler.
- `UseGlobalDataSetList` yalnız kurucuda atanır; `Clear` ve yükleme sıfırlamaz (`frxClass.pas`), iki formun veri kümeleri karışmaz.
- `TfrxReport.DataSets` her çalıştırmada yeniden kurulmalı (`Clear` + `Add(köprü)`); yalnız `EnabledDataSets` ikinci çalıştırmada
  `ana."alan"` ifadesini `Identifier expected` ile bozuyordu.
- Ekransız çalıştırmada FastReport hata kutusu açar ve uygulamayı kilitler: `EngineOptions.NewSilentMode := simReThrow`.
- FastReport birimleri `Vcl.Forms`'tan önce sonlanır: host servisi Application'a bağlı bir nesnede tutuyorsa onu çok geç bırakır
  ve kapanışta `Runtime error 216` çıkar. `rad.reports` kendi `finalization`'ında canlı servislerin FastReport nesnelerini
  bırakır; host bir şey çağırmaz.
- Delphi `out` parametresi girişte kaydı sıfırlar: `FindById(LInfo.Id, LInfo)` boş kimlik gönderiyordu; kimlik önce ayrı
  değişkene alınır. Aynı tuzak `SaveFromDesigner`'da da vardı (`Find(FKey, FDesigningInfo.Design, FDesigningInfo)`): bulunamayınca
  anahtar ve ad siliniyor, satır boş anahtarla yazılıp hiçbir listede görünmüyordu. Sonuç her zaman ayrı değişkene alınır.
- Bir arayüzde aynı adla hem yordam hem özellik bildirmek derleme hatası VERMEDİ (Delphi 13, Win32): `procedure Design` ile
  `property Design: string` birlikte derlendi ve `J.Design;` tasarımcıyı açmak yerine getter'ı çağırıp sonucu attı. Yönetim
  formunda Tasarla ve Yeni tasarım hiçbir ileti olmadan etkisiz kaldı. Özellik `DesignName` yapıldı.
- Kısmi UNIQUE indeksli kolonda tek `UPDATE ... set x = (id = :id)` satır satır işlenirken ara durumda iki `true` görür ve ihlal
  verir; önce hepsi kapatılır, sonra biri açılır (transaction içinde).
- `TJSONValue.GetValue<T>` anahtardaki noktayı yol ayracı sayar; yan dosyada `Values[]` ile okunur.
- Birim başlık yorumunda `{ ... }` içinde `{anahtar}` geçerse yorum erken kapanır; `(* *)` kullan.
- Zincir metodu olan bir sınıfta `Copy`, `Delete` adları `System.Copy`'yi gölgeler; içeride `System.Copy` yazılır.
- Tasarımcının Kaydet'i yalnız global `frxDesignerComp.OnSaveReport`'a bakar (`frxDesgn.pas`); bu global en son yaratılan
  `TfrxDesigner`'a işaret eder ve HERHANGİ bir `TfrxDesigner` yok edilince koşulsuz `nil` olur. Şirket değişiminde yeni servis
  kurulup eski servis sonra bırakılınca kanca kayboluyor ve Kaydet dosya diyaloğuna düşüyordu (tasarım DB'ye hiç yazılmadı).
  Çözüm: her `DesignReport` öncesi `frxDesignerComp := DM.frxDesigner`; `Shutdown` sonrası yaşayan başka servise geri bağla
  (test: `TwoServices_DesignerHookSurvivesRelease`). Ayrıca `TfrxReport.Clear` sayfasız bırakır; yeni tasarım boş bir
  `TfrxReportPage` (`CreateUniqueName` + `SetDefaults`) ile açılır.

## Testler

DUnitX, `rad-library/src/test`: `unit/rad.reports.Tests.pas` (dosya adı, yerel eşitleme, sabitler; veritabanı gerekmez) ve
`unit/rad.reports.db.Tests.pas` (depo, servis/iş API'si, yönetim formu). Veritabanı testleri atılabilir bir PostgreSQL
veritabanı yaratır (`radreports_test_<rastgele>`), şemayı `Rad-DB\sql\schema.sql`'in rapor bölümünden kurar, bitince siler;
`RAPOR_TEST_PGPWD` yoksa "atlandı" diye geçer (`RAPOR_TEST_PGHOST` 127.0.0.1, `RAPOR_TEST_PGPORT` 5432, `RAPOR_TEST_PGUSER`
postgres varsayılan). `RunTests.dproj`'un arama yolu eski makinenin `D:\dev\...` yollarını taşır ve `src/vendor/vsofttechnologies`
(DUnitX) klonlu değilse derleme `F1026` verir (`vendor.bat`).

Kapsam (68 test): depo (ilk tasarım varsayılan, aynı içerik sürüm üretmez, bayat SHA çakışma, sürüm içeriği, sıralama, kopya,
varsayılanın devri, zincirleme silme, varsayılan değiştirme, eski sürümleri silme, sıfırlama ve sonrası); API (LoadDefaults yalnız
eksik, `@` ayracı, dosya adı şablonu, olay sırası/iptali/önceliği, çok tasarımda istisna, 14 biçim, eksik değişkende sessiz hata,
**iki iş nesnesi karışmaz**, sabit veri kümesi ve gölgeleme, adsız Data hatası, yerel eşitleme/çakışma, silme ve sıfırlama yedeği,
geri yükleme, kopya/varsayılan, eylem kümesi, `AddToMenu` öğeleri, yönetim formu listesi/komut kapatma, servis bırakılınca iş
nesnesinin yaşaması). Ribbon formunun görünümü geçici bir uygulamayla ekran görüntüsü alınarak denendi.

**Denenmedi** (elle): önizleme penceresi, tasarımcıdan Kaydet, `Run`'ın açılır menüsü ve Ctrl davranışı, `Print`, `Mail` (SMTP),
`Upload` (dış hesap), menü/ribbon düğmelerine tıklama, host skini altında görünüm, Win64.
