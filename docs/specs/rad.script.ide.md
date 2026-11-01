# Specification: `rad.script` 6. aşama — IDE formları (paket yöneticisi + gömülü TMS IDE)

Durum: **onaylandı ve uygulandı** (2026-11-01; kod `src/vendor/tms/rad.script.ide.pas`, `rad.script.packages.pas/.dfm`,
`rad.script.newscript.pas/.dfm`, motor `TRadScriptEngine.CreateFor/AdoptScript`; paket `RadScriptTmsDesign` (6 birim,
`TMSScripter_Memo` eklendi); test `src/test/scratch/rad_script_ide/` IdeTest 18/18 Win32). Önceki aşamalar: `rad.script.md` (paket/store),
`rad.script.hooks.md` (motor, kanca, KP), `rad.script.facade.md` (facade, `komut`, tipli olaylar),
`rad.script.designer.md` (düzen, `pencere`, tasarımcı). Bu aşama script'in ERP içinden **yazıldığı,
derlendiği, denendiği ve paketlendiği** ekranları tanımlar. RAD-15'in son aşamasıdır.

## Bağlam ve kısıtlar

- **Görsel tasarım DFM'de**: paket yöneticisi formu `.dfm`; kodla yalnız veriye bağlı parça.
- TMS Scripter 8.1 `TMSScripter_IDE` paketi tam bir IDE taşır: `TIDEDialog` (menü/araç çubuklu editör
  penceresi), `TIDEMemo` (sözdizimi boyama, kod tamamlama `CodeInsight` ile scripter'ın kayıtlı sınıf ve
  nesnelerinden), form tasarımcısı + inspector + palet (5. aşamada kullanıldı), hata ayıklayıcı (kesme noktası,
  `DebugStepOver/DebugTraceInto/RunToCursor`, `Watches`). Proje modeli dosya tabanlıdır ama
  `OnLoadFile/OnSaveFile/OnOpenDialog/OnSaveDialog/OnConfirmSaveFile` (`var Handled`) ile **tamamen
  sanallaştırılabilir** — diske hiçbir şey yazılmadan "paket = proje, script = dosya" eşlemesi yapılır.
  Kaynaktan doğrulandı (`source/ide/idemain.pas`, `IDEDialog.pas`).
- IDE'nin scripter'ı `TIDEScripter = class(TatScripter)`; bizim `TRadScriptEngine` kendi
  `TatPascalScripter`'ını kurar. Sınıf kayıtları, facade, form zinciri ve VCL metot tanımları
  `TatCustomScripter` API'siyle yapıldığından motor **dışarıdan verilen scripter'ı sarabilir**; IDE'nin
  scripter'ı böylece aynı dünyayı (Db, Msg, Kullanici, kayıtlı DevExpress/UniDAC sınıfları, `pencere`
  formları) görür ve kod tamamlama bunlardan beslenir.
- Koruma = gizleme (2. aşama kararı): korumalı paket yöneticide listelenir, aktif/pasif yapılır, silinir,
  dışa aktarılır; **kaynağı açılmaz, IDE'de açılmaz, tasarlanmaz**.
- Deneme çalıştırmaları **şirket veritabanına** bağlıdır (facade `Db` host bağlantısını kullanır); Wolvox'ta da
  böyledir. IDE başlığı ve ilk çalıştırmada bir onay bunu söyler; ayrı "deneme bağlantısı" bu aşamada yok.
- Form kanca script'leri (`tur = form`) ve `komut` IDE'de **derlenir ama çalıştırılmaz** (canlı form/modül
  gerekir); `olay`, `zaman`, `kutuphane`, `pencere` script'leri IDE'de çalıştırılıp hata ayıklanır.

## Birimler

| Birim | Paket | Bağımlılık | İçerik |
|---|---|---|---|
| `src/vendor/tms/rad.script.engine.pas` | `RadScriptTms` | — | `TRadScriptEngine.CreateFor(AScripter: TatCustomScripter)` (sahiplik dışarıda); mevcut `Create` kendi scripter'ını kurup aynı yola gider |
| `src/vendor/tms/rad.script.ide.pas` | `RadScriptTmsDesign` | TMS IDE, `rad.script.facade` | `TRadScriptIde`: paketi `TIDEDialog`'da açar (sanal dosyalar), kaydı DB'ye yazar, çalıştırma/deneme kuralları |
| `src/vendor/tms/rad.script.packages.pas/.dfm` | `RadScriptTmsDesign` | DevExpress (`cxGrid`, `dxLayoutControl`) | `TRadScriptPackagesForm`: paket listesi + sekmeler (script'ler, parametreler, DB adımları, kaynaklar), içe/dışa aktarma, IDE'de aç, tasarla |
| `src/vendor/tms/rad.script.newscript.pas/.dfm` | `RadScriptTmsDesign` | VCL | Yeni script diyaloğu: kod, ad, tür, hedef (türe göre ipucu: sınıf adı / kanal / Quartz maskesi), iskelet |

`RadScriptTmsDesign` `TMSScripter_Memo`'yu da gerektirir (IDE zaten gerektiriyor). Çekirdek `rad.script`
ve `Help.uni` değişmez (gerekirse `ScriptsFor` dışında bir "paket özeti" sorgusu eklenir — ölçüme göre).

## Paket yöneticisi (`TRadScriptPackagesForm`)

Tek form, DFM: üstte paket grid'i (`TcxGrid`: kod, ad, sürüm, yazar, sıra, aktif, korumalı, değişim),
altta seçili paketin sekmeleri (`TcxPageControl`): **Script'ler** (kod, ad, tür, hedef, sıra, aktif),
**Parametreler** (ad, değer, açıklama — değer düzenlenir), **DB adımları** (sıra, açıklama, uygulandı,
zaman; "Uygula" = `ApplyPendingDbSteps`, hata satırıyla gösterilir), **Kaynaklar** (dosya adı, boyut;
dışa al/değiştir/sil — `duzen.json`/`.dfm`/`.layout` dahil). Eylemler:

| Eylem | Davranış |
|---|---|
| Yeni paket | kod/ad/sürüm/yazar diyaloğu; `IsValidCode`; `SavePackage` |
| Sil | onay; `DeletePackage` (cascade; script_db ile yaratılan tablolar kalır — uyarı metninde yazar) |
| Aktif / Pasif, Sıra | satırda düzenlenir, anında `SavePackage` |
| Dışa aktar | `TRadScriptPackageFile.SaveToFile` → `<kod>.radpaket`; korumalı işaretlenebilir (kaynak dosyada okunur, belgelenir) |
| İçe aktar | `LoadFromFile` → `ImportPackage` (mevcut parametre değerleri korunur) → listede seçili; bekleyen DB adımı varsa sorar |
| Yeni script | `TRadScriptNewScriptForm`: kod (tanımlayıcı), ad, tür, hedef; türe göre iskelet (form: `Form_AfterCreate`; olay/zaman: `Calistir(Olay)`; komut: `<Kod>_Execute`; kütüphane: boş; pencere: `{$FORM}` + boş DFM kaynağı) |
| Script sil / aktif-pasif / sıra | satırda; `SavePackage` |
| **IDE'de aç** | seçili paketi `TRadScriptIde.Open(paket, [seçili script])` ile açar (korumalı → kapalı düğme) |
| Tasarla | `pencere` script'i seçiliyse `TRadScriptDesigner.StartWindow`; `form` script'i seçiliyse host'un `OnOpenFormForDesign(sınıf adı)` geri çağrısı (host formu açar ve `TRadScriptDesigner.Start` çağırır); yoksa düğme kapalı |
| Yenile | `LoadPackages(True)` |

Form `Store` ve `Context` ister (`TRadScriptBinder.Store`, `TRadScriptFacade` bağlamı); yetki host'ta
(menüyü kim görür). Grid düzeni kullanıcıya özel saklanmaz (6. aşamada yok).

## Gömülü IDE (`TRadScriptIde`)

```pascal
TRadScriptIde = class(TComponent)
  class function Open(APackage: TRadScriptPackage; const AScriptCode: string): TRadScriptIde;  // tek IDE açık
  property Package; property Modified; property OnSaved: TProc<TRadScriptPackage>;
end;
```

- **Proje = paket.** `TIDEEngine.NewProject`; her script bir `TIDEProjectFile`: `kutuphane/olay/zaman/komut/form`
  → unit (`<kod>.pas` adıyla), `pencere` → form unit (`LoadFormFromString(<kod>.dfm)`; `ExtractDfmEvents`
  5. aşamadaki gibi). Ana birim = açılırken seçilen script. Dosya adı = script kodu; yeniden adlandırma IDE'de
  kapalı (`OnSaveDialog` → `Handled`, kod yöneticide değişir).
- **Sanal dosyalar.** `OnLoadFile`: içerik DB'deki `Source`/DFM, `Handled := True`. `OnSaveFile`: `Source`
  (ve `pencere` için `<kod>.dfm` kaynağı, `SaveFormToString`) pakete yazılır, `Store.SavePackage`, `Handled`.
  `OnOpenDialog`: IDE'nin "dosya aç/ekle" menüsü **kapalı** (script yöneticide eklenir; `ResultOk := False`).
  `OnConfirmSaveFile`: bizim Türkçe onayımız. Diske hiçbir şey yazılmaz (ölçüm 2).
- **Scripter.** `TIDEScripter` yaratılır, `TRadScriptEngine.CreateFor(IDEScripter)` ile sarılır: sınıf
  kayıtları (RegisterClasses + form zinciri + VCL metotları), `ScriptFormClass`, paket kütüphaneleri/pencereleri
  (`SetFormResource`), **facade** (`TRadScriptFacade.Install(engine, Context)`; `Form` globali yok — form
  script'inde `Form`/bileşen adları çözülmez, bu yüzden form script'leri yalnız "Derle" ile sözdizimi
  denetlenir, bkz. aşağı). Kod tamamlama `Db.`, `Msg.`, kayıtlı sınıflar ve pencere bileşenleri için çalışır
  (ölçüm 3).
- **Çalıştır / hata ayıkla.** IDE'nin kendi Run/Step/Breakpoint/Watch'ı `olay/zaman/kutuphane/pencere`
  script'lerinde çalışır. `olay/zaman` için `Calistir(Olay)` argüman ister: IDE'de "Deneme olayı" paneli
  (kanal, JSON) → ana blok yerine `TRadScriptIde` `Olay` nesnesini kurup `Calistir`'ı çağırır (`RunScript`
  öncesi `AddObject('Olay')`, ana birim boş `begin end.` ise motor rutini çağırır). `form`/`komut`
  script'lerinde Run düğmesi kapalı, "Derle" açık: `Form`, `Modul` ve bileşen adları çözülemeyeceğinden
  derleme hatası "bilinmeyen tanımlayıcı" verir → IDE scripter'ına **form kalıbı** eklenir: host
  `TRadScriptIde.RegisterFormClass(TKasaK)` ile sınıf verirse boş bir örnek yaratılmadan sınıfın yayımlanmış
  bileşen alanları `DefineProp` ile `Form` sahte nesnesine tanıtılır (TMS `DefineFormClass` kalıbı) —
  ölçüm 5; olmazsa form script'leri IDE'de yalnız kaydedilir, derleme ERP formu açılınca yapılır (bugünkü
  davranış, `OnError`).
- **Zaman sınırı / güvenlik.** IDE çalıştırması `SetDeadline` ile sınırlanmaz (hata ayıklamada adımlama var);
  `Msg.Soru` gerçek diyalog açar; `Db` canlı: ilk Run'da "Şirket veritabanında çalışacak, devam?" onayı
  (oturumda bir kez).
- **Kapanış.** Değişiklik varsa kaydet/vazgeç/iptal; `OnSaved` ile yönetici listesi tazelenir. Kapanınca
  motor, scripter, IDE engine serbest (sızıntı testi).

## Host sözleşmesi (ERPPlus)

- Menü: Sistem → "Script paketleri" → `TRadScriptPackagesForm` (yetki host'ta). `RadScriptTmsDesign.bpl`
  yalnız ERP'de.
- `TRadScriptPackagesForm.OnOpenFormForDesign := procedure(const AClassName: string)` — host o sınıfın
  formunu açıp `TRadScriptDesigner.Start(Form, PaketKodu)` çağırır.
- İsteğe bağlı: `TRadScriptIde.RegisterFormClass` ile sık kullanılan form sınıfları (form script'lerinin IDE'de
  derlenebilmesi için).
- KP'de değişiklik yok; KP paketleri yeniden okur (`TRadScriptJobs.Refresh`) — host KP'ye "paketler değişti"
  olayı yayınlar (`rad.eventbus`, kanal `script.paket.degisti`), yönetici her `SavePackage` sonrası yayınlar.

## Ölçülecekler (uygulama sırasında, spec'e yazılır)

1. `TRadScriptEngine.CreateFor(TIDEScripter)`: `DefineClassByRTTI`, facade, `pencere` derleme IDE scripter'ında
   aynen çalışır (HooksTest/FacadeTest'in IDE scripter'lı tekrarı).
2. `OnLoadFile/OnSaveFile/OnOpenDialog/OnSaveDialog` ile IDE hiçbir diske dokunmaz (`%TEMP%` ve çalışma
   klasörü izlenir).
3. Kod tamamlama listesinde `Db`, `Msg`, `Kullanici`, kayıtlı sınıflar ve pencere bileşenleri.
4. Kesme noktası + adımlama + watch bir `kutuphane` rutininde; `olay` script'i deneme olayıyla.
5. Form kalıbı (`RegisterFormClass`) ile form script'i IDE'de derlenir; olmazsa yedek plan.
6. Yönetici: içe aktar → DB adımı uygula → IDE'de aç → kaydet → dışa aktar döngüsü; korumalı paket kapalı.
7. IDE açılış süresi (paket 10 script) ve kapanışta sızıntı.

## Uygulamada sapmalar ve ölçümler (2026-11-01)

- **Ölçüm 1 (`CreateFor`)**: `TIDEScripter` (`TatScripter`, çok dilli) `TatCustomScripter` API'siyle aynen sarıldı; tek fark
  script ekleme (`TatScripter.AddScript(slPascal)`, dil şart) — `AddScript` iki yolu da bilir, `AdoptScript` IDE'nin
  yarattığı `TatScript`'i koda bağlar. HooksTest/FacadeTest kendi scripter'ıyla yeşil kaldı.
- **Ölçüm 2 (sanal dosyalar)**: `OnCheckValidFile` (varsayılan `FileExists`!) + `OnLoadFile/OnSaveFile/OnOpenDialog/
  OnSaveDialog/OnConfirmSaveFile`; IdeTest çalışma klasöründe dosya sayısı değişmedi. `OpenFile('<kod>.pas')` ile
  yüklenir; `pencere` için `iftForm` yolu DFM'yi verir ve `DesignFormResource`'a koyar (IDE derlemesi dosya aramasın).
- **Olaylar**: IDE de DFM `OnX =` satırını okumaz; `ExtractDfmEvents` + `SaveEvents` (5. aşama yolu). Kayıtta kök sınıf
  adı `T<Kod>Form` olarak düzeltilir; `pencere` dosyasında `.pas` ve `.dfm` kaydı art arda gelir, paket DFM'de yazılır.
- **Deneme çalıştırması**: TMS menüsüne `Deneme` eklenir (TMS formu bizim değil; tek çalışma zamanı menüsü). `RunTest`:
  `RunScript(rmActiveUnit)` (editör → kaynak, derleme, hata listesi, ana blok) ardından `olay/zaman` için
  `Calistir(Olay)`; `form/komut` yalnız derlenir. TMS Run/adım eylemleri form script'inde adına göre kapatılır (en iyi
  çaba). Kesme noktası/watch IDE'nin kendi Run'ında; `Calistir` çağrısı aynı scripter'dan geçer (manuel doğrulama bekler).
- **Ölçüm 5 (form kalıbı) uygulanmadı**: scripter'da tek `Form` globali var, bir pakette birden çok form script'i
  farklı sınıfları hedefleyebilir; sahte `Form` + sahte bileşenler ancak etkin dosyaya göre değişirdi ve ERPPlus'ın kodla
  yarattığı adsız bileşenleri zaten kapsamazdı. Form script'leri IDE'de kaydedilir, derleme ERP formu açılınca
  (`OnError`). Yedek plan budur.
- Script'te `const` parametre yok (TMS Pascal: `Syntax error`); skill'e yazıldı.
- Programatik `TRadScriptIde.Close` kaydedilmemiş değişikliği sormadan atar (pencere X'i sorar); yöneticinin kapanışı
  açık IDE'yi kapatır. `TRadScriptIde` yalnız `TIDEDialog.Show` (modal değil).
- Yönetici `cxGrid` unbound (`DataController.Values`), satır içi düzenleme `OnEditValueChanged` → `SavePackage`;
  yeni paket/kod `InputQuery` (stok diyalog), yeni script `TRadScriptNewScriptForm` (DFM) + türe göre iskelet;
  `OnPackagesChanged` host'a (KP yayını host'un işi, kanal adı host'ta).

| Ölçüm | Sonuç |
|---|---|
| IDE açılış (4 script, TMS IDE formu, palet) | 430–490 ms |
| IdeTest (CreateFor, sanal dosya, SaveEvents, deneme olayı, yönetici) | 18/18 Win32 |
| Regresyon | HooksTest 34/34 W32+W64, DesignVclTest 35/35, FacadeTest 24/24, FacadeVclTest 7/7, ScriptModelTest 43/43 |
| Paket | `RadScriptTmsDesign` 6 birim, MSBuild Win32 Release, 307 KB |

## Kabul ölçütleri (EARS)

**Yönetici**
- WHEN yeni paket kodu geçersizse, THEN diyalog kapanmaz ve `IsValidCode` nedeni gösterilir.
- WHEN korumalı paket seçilirse, THEN IDE'de aç/Tasarla kapalı, aktif-pasif/sil/dışa aktar açıktır.
- WHEN `.radpaket` içe aktarılırsa, THEN mevcut parametre değerleri korunur ve bekleyen DB adımı varsa sorulur.
- WHEN DB adımı hata verirse, THEN hata adım sırasıyla gösterilir, uygulananlar işaretli kalır.
- WHEN yeni `pencere` script'i yaratılırsa, THEN kaynak `{$FORM}` iskeletiyle ve boş `<kod>.dfm` kaynağıyla
  gelir, `Validate` geçer.

**IDE**
- WHEN IDE'de bir script düzenlenip kaydedilirse, THEN DB'deki `Source` değişir ve diskte dosya oluşmaz.
- WHEN `pencere` script'i IDE'de açılırsa, THEN form tasarımcısı DFM kaynağıyla gelir, kaydet DFM'yi yazar
  (olaylar `SaveEvents` ile korunur).
- WHEN `kutuphane` script'inde kesme noktası konup Run yapılırsa, THEN duraklar, watch değer gösterir.
- WHEN `olay` script'i deneme olayıyla çalıştırılırsa, THEN `Calistir(Olay)` verilen kanal/JSON ile çağrılır.
- WHEN `form` script'i açılırsa, THEN Run kapalı, Derle açıktır (form kalıbı varsa derlenir).
- WHEN IDE kapatılırken kaydedilmemiş değişiklik varsa, THEN Türkçe kaydet/vazgeç/iptal sorulur.
- WHEN kod tamamlama `Db.` için açılırsa, THEN `Sorgu/Deger/Sayi/...` listelenir.

## İşlevsel olmayan

- Önceki aşama testleri yeşil; yeni testler `src/test/scratch/rad_script_ide/` (sanal dosya, CreateFor, deneme
  olayı; IDE formu konsolda açılır/kapanır).
- Tüm formlar DFM; IDE penceresi TMS'nin kendi `TIDEEditorForm`'u (değiştirilmez).
- Tek IDE ve tek tasarımcı aynı anda; IDE açıkken `TRadScriptDesigner.Start` reddedilir (çakışan scripter).

## Kapsam dışı (6. aşama)

- Ayrı "deneme veritabanı"; kullanıcıya özel grid düzeni; paket sürüm geçmişi/karşılaştırma; çoklu kullanıcı
  eşzamanlı düzenleme kilidi; KP'de IDE.
- Script marketi/indirme; p-code saklama.

## Açık kararlar (onaydan önce)

1. IDE = **TMS `TIDEDialog` gömülü** (editör+tasarımcı+hata ayıklayıcı hazır) — alternatif kendi editörümüz
   (`TIDEMemo` + kendi formumuz, hata ayıklayıcı yok). Önerim gömülü.
2. Deneme çalıştırmaları **canlı şirket DB'si** + onay — alternatif Run'ı tamamen kapatmak. Önerim canlı+onay.
3. Form script'leri için **form kalıbı** (`RegisterFormClass`) denenir; olmazsa yalnız kaydet. Onay ikisini kapsasın mı?
4. Yönetici formu DevExpress (`cxGrid`+`dxLayoutControl`) — ERP'nin geri kalanıyla aynı. Önerim evet.
