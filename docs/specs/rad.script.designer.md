# Specification: `rad.script` 5. aşama — tasarımcı (mevcut form özelleştirme + script penceresi)

Durum: **onaylandı ve uygulandı** (2026-11-01; kod `src/core/rad.script.override.pas`,
`src/vendor/tms/rad.script.design.pas` + `.design.bar` + `.design.tools` (DFM), paket `RadScriptTmsDesign`;
testler `src/test/scratch/rad_script_design/` OverrideTest 21/21 Win32+Win64, DesignVclTest 35/35 Win32). Önceki aşamalar: `rad.script.md` (paket/store),
`rad.script.hooks.md` (motor, kanca, KP), `rad.script.facade.md` (facade, `komut`, tipli olaylar).
Bu aşama **kod yazmadan** yapılabilecek iki işi tanımlar: (A) var olan bir ERP formunun görünüşünü
değiştirmek (başlık, görünürlük, salt okunurluk, yerleşim), (B) script'in kendi penceresini
tasarlamak. Kod editörü, hata ayıklayıcı ve paket yönetim ekranı **6. aşama** (IDE formları).

## Bağlam ve kısıtlar

- **Görsel tasarım DFM'de** (kural 2026-11-01): tasarımcının kendi pencereleri (araç çubuğu, inspector,
  palet, form tasarım penceresi) `.dfm` ile yazılır; kodla yalnız veriye bağlı parça üretilir.
- Bağlanma anahtarı yine **bileşen adı**: adsız bileşen ne kancalanır ne özelleştirilir. ERPPlus
  `base.kayit` formunun `FLyt`, grupları ve editörleri **kodla ve adsız** yaratılıyor; o formlarda
  tasarımcı yalnız adı olan bileşenleri görür. Host sözleşmesi (4. aşama) bunu zaten istiyor.
- Paket şirket geneli; **kullanıcıya özel düzen bu aşamada yok** (özel alanlardaki `ozel_alan_duzen`
  gibi bir tablo açılmaz). Tasarımcı bir pakete yazar, o paket herkese uygulanır.
- Korumalı paket (`korumali_mi`) tasarımcıda seçilemez; gizleme = koruma (2. aşama kararı).
- TMS tarafı: script formu `TScriptForm` (`Vcl.ScriptForm`), `{$FORM TAd, dosya.dfm}` yönergesi,
  `TatScript.DesignFormResource` (DFM metnini dosya yerine bellekten verir), `LoadFormEvents`
  (DFM'deki `OnClick = Button1Click` → script rutini), `TIDEEngine` + `TIDEFormDesigner` +
  `TIDEInspector` + `TIDEPaletteToolbar` (`demos/formdesigner`: canlı Delphi formu üstünde tasarım,
  projesiz). Hepsi kaynaktan doğrulandı (`source/core/atScript.pas`, `source/ide/*.pas`).
- Tasarımcı birimleri `TMSScripter_IDE` paketine bağımlı; KP bunu yüklemesin diye **ayrı paket**.

## Birimler

| Birim | Paket | Bağımlılık | İçerik |
|---|---|---|---|
| `src/core/rad.script.override.pas` | `RadKon` | RTL, `TypInfo`, mORMot JSON | Özellik anlık görüntüsü, fark, JSON, uygulama (`TRadPropSnapshot`, `TRadOverrides`) |
| `src/vendor/tms/rad.script.form.pas` | `RadScriptTms` | `Vcl.ScriptForm` | `TRadScriptForm = class(TScriptForm)`; motorun `ScriptFormClass`'ı |
| `src/vendor/tms/rad.script.design.pas` | `RadScriptTmsDesign` | `rad.script.hooks`, TMS IDE | `TRadScriptDesigner`: tasarım oturumu (mevcut form / pencere), kaydet, geri al |
| `src/vendor/tms/rad.script.design.bar.pas/.dfm` | `RadScriptTmsDesign` | VCL | Üstte yüzen araç çubuğu: paket seçimi, seçili bileşen, Yerleşim, Kaydet, Vazgeç, Kapat |
| `src/vendor/tms/rad.script.design.tools.pas/.dfm` | `RadScriptTmsDesign` | TMS IDE | Yan pencere: `TIDEInspector` (özellik/olay), pencere kipinde `TIDEPaletteToolbar` |
| `src/packages/RadScriptTmsDesign.dpk` | — | `RadScriptTms`, `TMSScripter_IDE` | Tasarımcı paketi (çalışma zamanı; ERP'ye kurulur, KP'ye kurulmaz) |

`rad.script` modeli ve `Help.uni` store'u küçük eklemeler alır (aşağıda). `RadScriptTms`'e yalnız
`rad.script.form` girer; `TMSScripter_IDE` gereksinimi `RadScriptTmsDesign`'da kalır.

## Model ve store eklemeleri (`rad.script`, `Help.uni`)

- `TRadScriptKind`'a **`skWindow`**, kodu **`pencere`**: kendi formunu bildiren script. `hedef` boş.
  Kaynak `{$FORM T<Kod>Form, <kod>.dfm}` yönergesi içerir; DFM metni aynı paketin
  `script_kaynak` kaydında `<kod>.dfm` adıyla durur. `Validate`: `pencere` için kaynakta `$FORM`
  yönergesi ve pakette `<kod>.dfm` kaynağı şart.
- `TRadScriptResource.PackageId` (okuma için; `ResourcesNamed` doldurur).
- `IRadScriptStore.ResourcesNamed(const AFileName: string): TObjectList<TRadScriptResource>` —
  **aktif** paketlerin bu addaki kaynakları, `paket.sira` sırasıyla. Tek sorgu
  (`script_kaynak` ⋈ `script_paket`). Attach başına bir çağrı.
- `LibrariesOf` artık `tur in ('kutuphane', 'pencere')` döndürür: pencere script'leri de aynı paketin
  diğer script'lerine `uses <Kod>;` ile açılır. Yeni yükleme yolu yoktur.
- `.radpaket` biçimi değişmez (kaynaklar zaten base64 taşınıyor; `tur` yeni değer alır).

## A. Mevcut formu özelleştirme (`duzen`)

### Nasıl saklanır: özellik farkı, JSON

Tasarımcı **script üretmez**, DFM farkı da saklamaz; adlı bileşenlerin yayımlanmış özelliklerinden
**değişenlerin listesini** saklar. Paket kaynağı `<FormSınıfı>.duzen.json`:

```json
{ "format": 1, "form": "Tkasa_k",
  "props": { "Form.Caption": "Kasa (şube)", "btnKaydet.Caption": "Kaydet*",
             "edtAd.Properties.ReadOnly": "True", "lytItemNot.Visible": "False",
             "edtTutar.Properties.DisplayFormat": "#,##0.00" } }
```

- Anahtar: `<BileşenAdı>.<Özellik>[.<AltÖzellik>…]`; formun kendisi `Form.` (script'teki adla aynı).
- Değer: **DFM metin biçimi** (`TypInfo` ile yazılır/okunur): sayılar ve mantıksal `True/False`,
  enum adı, küme `[a,b]`, metin ham, bileşen başvurusu (örn. `DataSource`) **bileşen adı**.
- Alt nesneler (`Properties`, `Font`, `Margins`, `Style`) yayımlanmış `TPersistent` özellikleri
  üzerinden en çok 4 seviye. Olay (`tkMethod`), `Name`, `ComponentIndex`, `Tag` dışı okunmaz;
  `Left/Top/Width/Height` dahil (yerleşim dışı formlarda taşıma bununla saklanır).
- Neden script değil: tasarımcı farkı tekrar okuyup "değişmiş" göstermeli (round-trip); JSON bunu
  verir, üretilmiş Pascal'ı yeniden ayrıştırmak gerekmez. Script yazarı isterse `Form_AfterCreate`
  ile aynı şeyi yine yapabilir; JSON **önce**, script **sonra** uygulanır, script kazanır.
- Yerleşim (`TdxLayoutControl` sürükleme/gruplama): DevExpress'in kendi `Customization` kipiyle
  yapılır, `SaveToStream` çıktısı `<FormSınıfı>.<LayoutAdı>.layout` kaynağına yazılır. DevExpress
  akışı `Visible` saklamaz (özel alanlarda ölçüldü) — gizleme zaten `lytItemX.Visible` özelliği
  olarak `duzen.json`'a düşer; özel alanlardaki ad listesi mekanizmasına gerek kalmaz.

### Uygulama (`TRadScriptBinder.Attach`)

Sıra: (1) `ClassChain` için her sınıf adına `ResourcesNamed('<Sınıf>.duzen.json')` → paket sırasıyla
uygula (sonraki kazanır); (2) `<Sınıf>.<Lyt>.layout` kaynakları `LoadFromStream`; (3) mevcut
`LoadInto` + kancalar + `Form_AfterCreate`. **Attach artık script olmasa da çalışır**: yalnız düzen
olan paket için motor yaratılmaz, `Result` o zaman da nil kalır.

Uygulamada bulunamayan bileşen/özellik ya da tip uyuşmazlığı **durdurmaz**: `OnWarning` ile
bildirilir, kalan özellikler uygulanır. Sürüm atlamasında form değişince düzen sessizce bozulmasın
diye uyarı metni paket kodu + anahtarı taşır.

### Tasarım oturumu (`TRadScriptDesigner.Start(AForm, APackageCode)`)

Host açık bir formda çağırır (menü ya da kısayol, host'un kararı; yetki host'ta). Oturum:

1. **Anlık görüntü**: `TRadPropSnapshot.Capture(AForm)` (form + adlı bileşenler).
2. **TMS tasarımcısı canlı formun üstünde**: `TIDEFormDesigner.Create(AForm)`, `Active := True`,
   seçim + grab handle; mevcut formda **silme, ekleme, kopyalama yok** (`ProtectedControls`/
   `LockedControls` ile; Wolvox'un `LockAll([lmNoDelete, lmNoInsertIn, lmNoCopy])` karşılığı).
   `TdxLayoutControl` içindeki kontroller için taşıma/boyut **kilitli** (yerleşim DevExpress'in işi).
3. **Inspector**: `TIDEInspector` seçili bileşenin özelliklerini düzenler (olay sekmesi mevcut
   formda **gizli**: olaylar kancayla değişir, elle bağlanmaz).
4. **Yerleşim** düğmesi: adlı her `TdxLayoutControl` için `Customization := True/False`.
5. **Kaydet**: yeni anlık görüntü − ilk = fark → `duzen.json`; `Customization` kullanıldıysa
   `.layout`; pakete kaynak olarak yazılır, `Store.SavePackage`. Aynı pakette eski düzen varsa
   **üstüne yazılır** (fark önce eski düzenle birleştirilir: eski + yeni, yeni kazanır; "orijinale
   döndür" = anahtarı sil).
6. **Vazgeç**: ilk anlık görüntü geri uygulanır (`TRadOverrides.Apply` ile, aynı yol).
7. **Kapat**: tasarımcı serbest, form normal çalışır (kancalar oturum boyunca **askıda**: tasarım
   sırasında tıklama olay çalıştırmaz, TMS tasarımcı zaten yutar; kapanınca eski haline).

Fark şu durumda da doğrudur: kullanıcı inspector'da değiştirip geri eski değere getirirse anahtar
düşmez (fark boştur), JSON'a girmez.

## B. Script penceresi (`pencere`)

### Çalışma zamanı

- Motor `Scripter.ScriptFormClass := TRadScriptForm`, `LoadFormEvents := True`.
- `AddScript`: script `pencere` ise paketten `<kod>.dfm` okunup `S.DesignFormResource := metin`;
  TMS `$FORM`'u görünce dosya yerine bunu kullanır (`CompileForm`, kaynaktan doğrulandı).
- Script'ten kullanım (aynı paket, başka script):

```pascal
uses CariOzet;                       // pencere script'inin kodu
procedure btnOzet_After(Sender: TObject);
var F: TCariOzetForm;
begin
  F := TCariOzetForm.Create(Form);   // TMS'nin form kurucusu; sahibi ERP formu
  F.edtKod.Text := qry.FieldByName('kod').AsString;
  F.ShowModal;
  F.Release;
end;
```

- `Create` burada TMS'nin `DefineFormClass` ile kaydettiği form kurucusudur, `TObject.Create` değil;
  4. aşamanın "Create/Free/Destroy silinir" kuralı `TRadScriptForm`'a **uygulanmaz** (ölçüm 1).
  `Free` yine yoktur; kapatma `Release` ya da sahip formun ölümü.
- Pencere script'inin olayları TMS'nin kendi yoludur: DFM'de `OnClick = btnTamamClick`, script'te
  `procedure btnTamamClick(Sender: TObject)`. `_Before/_After` kancası pencere script'ine **yok**
  (kanca ERP formları içindir). Facade (`Db`, `Msg`, …) pencere script'inde de hazırdır (aynı motor).
- `Form` globali pencere script'inde **ERP formu değil**; pencerenin kendisi `Self`'tir (TMS).

### Tasarım

`TRadScriptDesigner.StartWindow(APackageCode, AScriptCode)`:

1. Boş `TRadScriptForm` yaratılır; `<kod>.dfm` varsa `TIDEFormDesigner.LoadFromStream(dfmText)`.
2. Aynı `TIDEEngine` + `TIDEFormDesigner` + `TIDEInspector`; bu kipte **palet açık**
   (`TIDEPaletteToolbar`): sayfalar `Standart` (VCL), `DevExpress` (`TRadScriptDev.RegisterAll`
   listesindeki `TControl` türevleri), `Veri` (`TDataSource`, `TUniQuery`); `IDEEngine.RegisterComponent`.
   Ekleme/silme/taşıma serbest.
3. Olay bağlama: `PreventDefaultEventCreation := True` (kod editörü 6. aşamada). Inspector olay
   sekmesinde rutin adı yazılır; DFM'ye `OnClick = <ad>` düşer, script'te aynı adlı rutin yoksa
   derlemede hata (TMS `LoadFormEvents` davranışı) — tasarımcı Kaydet'te bunu **uyarı** olarak gösterir
   (rutin adlarını motorun `RoutineNames` listesinden karşılaştırır).
4. **Kaydet**: `SaveToStream(dfmText)` → `<kod>.dfm` kaynağı; script kaynağı yoksa iskelet üretilir:
   `{$FORM T<Kod>Form, <kod>.dfm}` + boş `begin end.`. `Store.SavePackage`.
5. Kaydedilen pencere **hemen denenir**: yeni motor, paket kütüphaneleri, `Compile`; hata varsa
   satır/sütunla gösterilir, kayıt yine kalır (yarım iş kaybolmasın).

## Host sözleşmesi (ERPPlus)

- `RadScriptTmsDesign.bpl` ERP'ye kurulur; KP yalnız `RadScriptTms`.
- Tasarım kipini açan menü/kısayol ve **yetki** host'ta: `TRadScriptDesigner.Start(Form, PaketKodu)`
  çağrısı, paket seçimi için `Store.LoadPackages(False)` (korumalılar listelenmez).
- `base.kayit`'in kodla yarattığı `FLyt`, grup ve editörlere **ad verilmeli** (sözleşmede zaten var);
  adsız kalanlar tasarımcıda görünmez ve `duzen.json`'a giremez.
- Script penceresi paketleri için ek bir şey gerekmez; `uses` ile ulaşılır.

## Ölçülecekler (uygulama sırasında, spec'e yazılır)

1. `TRadScriptForm` sınıfı için `Create`/`ShowModal`/`Release`'in script'ten görünürlüğü
   (`ExportReference` çıktısıyla).
2. `TIDEFormDesigner` bir `TdxLayoutControl` + `TcxGrid` taşıyan canlı ERP formunda: seçim çalışır,
   kilitli kontrol taşınmaz, kapatınca form bozulmaz. **Olmazsa yedek plan:** seçim için
   `Application.OnMessage` ile tıklama yakalama + `TcxRTTIInspector` (sonda raporundaki plan).
3. `TRadPropSnapshot.Capture` süresi ve anahtar sayısı `cari_k` büyüklüğünde bir formda (hedef
   < 50 ms); `TRadOverrides.Apply` süresi.
4. `TIDEInspector` olay sekmesinde rutin adı elle yazılabiliyor mu; yazılamıyorsa "Olay bağla"
   küçük diyaloğu (DFM) DFM metnine satırı ekler.
5. `DesignFormResource` ile derlenen pencerenin `ShowModal` sonrası `Release` ile sızıntısız
   kapandığı (`ReportMemoryLeaksOnShutdown`).

## Uygulamada sapmalar ve ölçümler (2026-11-01)

- `rad.script.form.pas` açılmadı: `TRadScriptForm` `rad.script.engine` içinde (motor `ScriptFormClass` olarak atar; ayrı birim
  döngüsel `uses` olurdu).
- **Form ata zinciri motorda kayıtlı** (`TComponent`…`TCustomForm`, `TForm`, `TScriptForm`, `TRadScriptForm`; class constructor).
  TMS yalnız kayıtlı ata adını bağlar; `TScriptForm`'u scripter kurulurken kaydettiğinden atası boş kalıyordu →
  `RelinkAncestors`. **VCL birimleri metot RTTI'si üretmez** (ölçüldü: `TCustomForm` methods=17, `Show` yok) →
  `DefineVclMethods`: `Show/Hide/BringToFront/Refresh` (TControl), `SetFocus` (TWinControl), `Close/Release/ShowModal`
  (TCustomForm) elle tanımlı. `TComponent`'in `DestroyComponents/DestroyComponent/RemoveComponent/InsertComponent/
  FreeOnRelease` gizli. `TScriptForm` zincirinde `Create` (TMS form kurucusu) silinmez. Ölçüm 1: `TOzetForm` sınıfında
  `Create`, `ShowModal`, `Release` var, `Free` yok.
- **Olaylar:** TMS tasarımcısı DFM olay satırını okumaz, olayları `TScriptForm.SaveEvents`'te tutar; kaydedilen DFM
  `SaveEvents.Strings = ('btnTamam.OnClick=btnTamamClick')` biçimindedir ve çalışma zamanı yükleyicisi bunu bağlar
  (`TScriptFormLoader`). Elle/AI yazılmış `OnClick = btnTamamClick` satırları `TRadScriptDesigner.ExtractDfmEvents`
  ile yüklemede SaveEvents'e taşınır; iki biçim de çalışır (DesignVclTest S07b2). Ölçüm 4: `TIDEInspector` olay
  sekmesi rutin adını elle yazmayı destekler (`SetEventPropertyValue` → SaveEvents); ERPPlus'ta görsel doğrulama bekler.
- Yerleşim akışı için `TRadScriptBinder.RegisterLayoutClass(TdxLayoutControl, Load/Save/Customize)`; kaydı
  `rad.script.dev` yapar, `rad.script.hooks` DevExpress'siz kaldı. `Attach` artık script yokken de düzeni uygular
  (`ApplyOverrides` public). DevExpress akışı bozuksa uyarı, form ayakta.
- Fark gürültü filtresi (tasarımcı `Changes`): `Form.Left/Top`, yerleşim çocuğu kontrollerin `Left/Top/Width/Height`,
  `.AssignedValues` (DevExpress defteri), `Form.ActiveControl`. Ölçüldü: `edt.Style.Color := 255` tek başına 12 anahtar
  oynatıyordu (StyleFocused/StyleHot/AssignedValues...).
- `TRadPropSnapshot`: salt okunur sınıf özellikleri (Font, Properties) içine inilir, bileşen başvurusu yalnız yazılabilirse
  anahtar olur; `ToJsonBytes/FromJsonBytes` (UTF-8, Türkçe doğrulandı).
- `TIDEPaletteToolbar` `Visible/TabOrder` yayımlamaz → DFM'de yok, kodda kapatılır. Kapat düğmesi `TThread.ForceQueue`
  (düğmenin sahibi yıkılıyor). `OnClosed/OnMessage` anonim metot.
- Ölçüm 2 (TMS tasarımcı `TdxLayoutControl`+`TcxGrid` taşıyan canlı formda fare etkileşimi) konsol testinde yalnız
  `Active`/`Select`/`Close` + form bütünlüğü ölçüldü; sürükleme/seçim ERPPlus'ta görsel doğrulama bekler. Yedek plan
  (`TcxRTTIInspector` + tıklama yakalama) uygulanmadı.
- Fake store `LoadPackage` listeden çıkarır (gerçek store yeni nesne verir, sahiplik tasarımcıda).

| Ölçüm | Sonuç |
|---|---|
| `Capture` 200 bileşen / 3.001 anahtar (RTL) | 0 ms Win32+Win64 |
| `Capture` TKasaK (cxTextEdit + dxLayout) | 742 anahtar, 7 ms |
| `Start` (TMS tasarımcı + inspector + görüntü) | 102 ms |
| OverrideTest | 21/21 Win32+Win64 |
| DesignVclTest (pencere, düzen, öncelik, yerleşim, oturum) | 35/35 Win32 |
| Regresyon | ScriptModelTest 43/43 W32+W64, ScriptLiveTest 87/87 PG/MS/FB, HooksTest 34/34 W32+W64, FacadeTest 24/24, FacadeVclTest 7/7 |
| Paketler | `RadScriptTms` (TMSScripter_VCL eklendi), `RadScriptTmsDesign` (3 birim) MSBuild Win32 Release |

## Kabul ölçütleri (EARS)

**Model/store**
- WHEN `tur = 'pencere'` olan bir script `Validate` edilir, THEN kaynakta `$FORM` yönergesi ve pakette
  `<kod>.dfm` yoksa `ERadScript` yükselir.
- WHEN `ResourcesNamed('Tkasa_k.duzen.json')` çağrılır, THEN yalnız aktif paketlerin kaynakları
  `paket.sira` sırasıyla ve `PackageId` dolu döner; pasif paketinki dönmez.
- WHEN `LibrariesOf` çağrılır, THEN `kutuphane` ve `pencere` script'leri birlikte döner.

**Override**
- WHEN bir formun anlık görüntüsü alınıp `btnKaydet.Caption` ve `edt.Properties.ReadOnly`
  değiştirilir ve fark alınır, THEN fark tam o iki anahtarı içerir, başka anahtar içermez.
- WHEN değer değiştirilip eski değere döndürülür, THEN fark boştur.
- WHEN JSON'daki bir bileşen formda yoksa, THEN `OnWarning` çağrılır ve kalan anahtarlar uygulanır.
- WHEN aynı anahtar iki aktif pakette varsa, THEN `sira`sı büyük olan paket kazanır.
- WHEN düzeni olan ama script'i olmayan bir paket varsa, THEN `Attach` düzeni uygular ve nil döner.
- WHEN düzen ve `Form_AfterCreate` aynı özelliği değiştirirse, THEN script'in değeri kalır.
- WHEN adsız bir bileşenin özelliği değişirse, THEN farkta görünmez (yakalanmaz, hata da vermez).

**Pencere**
- WHEN pakette `pencere` script'i ve `<kod>.dfm` varken başka bir script `uses` ile onu alıp
  `T<Kod>Form.Create(Form)` ve `ShowModal` çağırırsa, THEN form DFM'deki bileşenlerle açılır ve
  DFM'de bağlı olay script rutinini çalıştırır.
- WHEN `<kod>.dfm` eksikse, THEN derleme `ERadScriptCompile` ile ve kaynak adını söyleyerek düşer.
- WHEN pencere script'inde `Db.Sayi(...)` çağrılırsa, THEN facade çalışır (aynı motor).

**Tasarımcı**
- WHEN `Start` açılıp Kaydet basılırsa, THEN paket kaynağı `<Sınıf>.duzen.json` yazılır ve formu
  yeniden açınca değişiklik uygulanmış görünür.
- WHEN `Start` açılıp Vazgeç basılırsa, THEN form ilk anlık görüntüsüne döner, paket değişmez.
- WHEN korumalı paket seçilmek istenirse, THEN listede yoktur.
- WHEN `StartWindow` ile palet'ten bir `TcxTextEdit` eklenip kaydedilirse, THEN `<kod>.dfm`
  o bileşeni adıyla içerir ve derleme geçer.
- WHEN tasarımcı açıkken ERP formundaki bir düğmeye tıklanırsa, THEN düğmenin olayı ve kancası
  çalışmaz (seçim olur).

## İşlevsel olmayan

- Kancalar/facade değişmez; 3–4. aşama testleri (HooksTest 34, FacadeTest 24, FacadeVclTest 7,
  ScriptLiveTest 78) yeşil kalır; `ScriptLiveTest` `ResourcesNamed` + `pencere` için büyür.
- Override birimi `rad.script.override` VCL'siz (RTL `System.Classes` + `TypInfo` + mORMot JSON):
  Win32 + Win64 birim testi; TMS/DevExpress'li testler Win32.
- Tasarımcı pencereleri DFM; kodla yalnız palet sayfaları ve inspector bağlama.
- Tasarım oturumu başına tek `TIDEEngine`; oturum kapanınca hepsi serbest (sızıntı testi).

## Kapsam dışı (5. aşama)

- Kod editörü, sözdizimi vurgulama, hata ayıklayıcı, paket yönetim/içe-dışa aktarma ekranları,
  KP'de tasarım — **6. aşama**.
- Kullanıcıya özel düzen (kişi başına), düzenlerin sürüm/geri alma geçmişi.
- Pencere script'lerinde `_Before/_After` kancası; pencere için ayrı menü kaydı (`komut` ile açılır).
- Kodla yaratılmış adsız bileşenlerin otomatik adlandırılması (host işi).

## Açık kararlar (onaydan önce)

1. Yeni tür adı **`pencere`** (alternatif: `ekran`). Önerim `pencere`.
2. Düzen saklama **JSON fark** (alternatif: üretilmiş `Form_AfterCreate` script'i). Önerim JSON;
   gerekçe yukarıda (round-trip, script yine üstüne yazabilir).
3. Mevcut formda **TMS tasarımcı + TIDEInspector** (tek mekanizma iki kip için); ölçüm 2 başarısız
   olursa `TcxRTTIInspector` yedek planı. Onay ikisini de kapsasın mı?
4. Tasarımcı **ayrı paket** `RadScriptTmsDesign` (KP'ye IDE bağımlılığı girmesin). Önerim ayrı.
