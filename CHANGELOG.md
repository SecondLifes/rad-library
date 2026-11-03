# Changelog

All notable changes to RAD Library AI Spec-Kit are documented here.

## Mandatory: record every file that was added, removed or renamed

**Any commit that adds, deletes or renames a file under `.agents/rules/`,
`.agents/commands/`, `.agents/skills/`, `tools/`, or any root-level document
must name that file here, in the same commit.** Not "updated the rules" —
the actual path, and one clause saying what it is for.

Three things in this kit read the file inventory and go wrong silently when
it drifts: `docs/proje-haritasi.md` states what exists and how many, and the
count gate in `tools/verify-kit.ps1` compares those claims against disk;
`tools/generate-ai-configs.ps1` produces one copy or link per source file, so
a file nobody recorded is a file nobody notices going stale; and anyone
auditing this kit later reconstructs what happened from this file plus
`git log`.

A change that only edits the *contents* of an existing file needs no
inventory line — describe the behavior that changed instead. The rule is
about files appearing, disappearing or moving, because those are the changes
that break something else in the kit.

## [Unreleased]

### Added

- `docs/specs/rad.formstate.md` — form/DataModule durum saklama sistemi spec'i (onaylandı; thread yok): JSON şeması, anahtar ve Scope, dosya/callback/UniDAC depoları, şifreleme zarfı, senkron `Prefetch`, tasarım editörü, EARS ölçütleri, ölçümler ve A0-A6 aşamaları.
- `src/core/rad.formstate.core.pas` — form durum sisteminin çekirdeği (RTL + mORMot): `TRadStateKey`, `TRadStatePaths` (nokta yollu published özellik okuma/yazma; getter'lı sınıf, set, enum, `TStrings`, koleksiyon indeksi; yol başına hata yalıtımı; ppi ölçeği), `TRadStateDoc` (`schema`/`version`/`ppi`), `IRadStateful`.
- `src/test/unit/rad.formstate.core.Tests.pas`, `src/test/scratch/rad_formstate/RunFormStateTests.dpr`, `build_and_run.bat` — DUnitX, 20/20 Win32 + Win64; DUnitX git kaynağından derlenir.
- `.agents/skills/mormot2-integration/references/verified-api-traps.md`: üç yeni tuzak (ölçüldü, Win32): VCL nesnelerinde tek özellik okuma/yazma (`ObjectToJson`, `GetInstanceByPath`, `GetValueText`, `PropertyFromJson`, `DocVariantToObject` sessizce yanlış çalışır; çalışan yol eklendi), `mFastExtended` tırnaksız anahtar üretir, `d.D[key] := child` kopya saklar.
- `src/core/rad.formstate.store.pas` — form durum depoları: `IRadStateStore`, `TRadFileStateStore` (kayıt başına `.state` dosyası, geçici dosya + `MoveFileEx`, Windows dosya adı temizleme ve kök dışı yol reddi), `TRadCallbackStateStore` (host fonksiyonları `class var DoLoad/DoSave/DoDelete/DoLoadScope`), `TRadStateEnvelope` (düz JSON ya da `RADS` + algoritma etiketi + `IRadCipher`), `TRadStateRepository` (önbellek, senkron `Prefetch`, `savedAt` hariç hash ile yazma atlama).
- `src/test/unit/rad.formstate.store.Tests.pas` — 25 test; `RunFormStateTests` toplam 45/45 Win32 + Win64.
- `.agents/skills/mormot2-integration/references/verified-api-traps.md`: `DocDict(TDocVariantData)` zayıf referanstır, yerel kayıttan `DocDictCopy` gerekir (ölçüldü); `UpperCase` de mORMot gölgeleme listesinde.
- `src/component/rad.formstate.component.pas` — `TRadPropertiesStore` (form ve DataModule; `Items` bileşen + nokta yollu özellikler, `StoredValues` + `StoredValue[]` ve tipli okuyucular, `Options`, `Version`, `StorageName`, `OnLoad`/`OnSave(Sender, ABefore)`, `OnGetKey`). Sahip başına tek gizli kanca: yükleme kullanıcının `OnCreate`'inden önce, kayıt `OnCloseQuery`/`OnDestroy`'da; yerleşim `OnCreate`'te `poDesigned` ile (VCL `OnShow`'dan sonra ortalıyor). Runtime'da oluşturulan store forma kanca takmaz.
- `src/component/rad.formstate.pas` — giriş birimi: alias'lar ve `TRadFormState.Kur/Kapat/Prefetch/SetScope/FileStore/CallbackStore`. `Kapat` açık formları kaydeder.
- `src/test/scratch/rad_formstate/RunFormStateVclTests.dpr`, `FormStateVclTests.pas`, `FormStateTestA/Two/Dm/Plain.pas` + `.dfm` — DFM'li VCL testleri, 13/13 Win32 + Win64; 300 yollu ölçüm (yükleme Win32 ~15 ms, Win64 ~12 ms; kayıt ~1 ms).
- `src/vendor/unidac/rad.formstate.uni.pas` — `TRadUniStateStore`: host bağlantısında tablo deposu (`UPDATE`, değişmezse `INSERT`; `ftBlob` yük; geniş anahtar parametreleri; tablo adı doğrulaması) ve `CreateTableSql` (PostgreSQL, SQL Server, Firebird). `PostgreSQL`/`Firebird` bağlantısında `UseUnicode` yoksa uyarı loglar. Giriş birimine `TRadFormState.DbStore`, `RadKon`'a birim eklendi.
- `src/test/scratch/rad_formstate/RunFormStateDbTests.dpr`, `FormStateDbTests.pas` — canlı testler: PostgreSQL ve SQL Server Win32 + Win64, Firebird Win32; 20/20.
- `.agents/skills/unidac-data-access/SKILL.md`: PostgreSQL'de `UseUnicode` yokken Türkçe ve Unicode parametreler kayıplı saklanır (ölçüldü); gidiş-dönüş testi bunu göstermez.
- `src/packages/Rad.Editor.FormState.Model.pas`, `Rad.Editor.FormState.pas` + `.dfm` — `TRadPropertiesStore` tasarım editörü: bileşen/özellik ağacı (`TcxTreeList`, üç durumlu onay, arama paneli, "özelliğe göre grupla", "yalnız seçililer"), tür ve mevcut değer sütunları, geri yüklenemeyen yolları kapalı gösterme, sıralanabilir kayıt listesi, "sayfa/sekme" ve "splitter boyutları" hazır seçimleri, Değerler ve Seçenekler sekmeleri; store'a yalnız Tamam'da yazar. Model `TypInfo` kullanır (tasarım anında mORMot `Rtti` yok). `Rad.Editor`: "Durum Editörü..." bileşen editörü ve `Items` özellik editörü; `RadKon`'a iki birim eklendi.
- `src/test/scratch/rad_formstate/RunFormStateEditorTests.dpr`, `FormStateEditorTests.pas` — IDE'siz editör testleri (model + DFM'li form), 13/13 Win32 + Win64.
- `rad.rtl`: `TRadActionList` `IRadStateful` uygular (kısayollar mevcut `ToJson`/`LoadFromJson` biçimiyle, `TRadPropertiesStore`'un `custom` bölümüne); editör bu tür bileşenler için yolsuz "(durum)" satırı gösterir. `src/README.md`: form durumu bölümü.
- Form durumu ayarları: `TRadStorageRoot` (`srLocalAppData`, `srExeFolder`) ve klasör adı (varsayılan `RAD_STATE_FOLDER = 'state'`, boşsa kökün kendisi) — `TRadFileStateStore.Create(ABase, AFolder)`/`RootOf`, `TRadFormState.FileStore(srExeFolder, 'ayar')`. `TRadStoredValue.ValueType` (`svtVariant`, `svtString`, `svtInteger`, `svtFloat`, `svtDateTime`, `svtBoolean`): `StoredValue[]` bildirilen türü döndürür; çevrilemeyen değerde tasarım varsayılanına, o da yoksa türün boş değerine düşer, istisna atmaz. `TRadStoredValue.Convert` metni değişmez ve yerel sayı, ISO 8601 ve yerel tarih olarak çözer. Editörün Değerler sekmesi `TcxTreeList` oldu (Ad / Tür / Varsayılan değer); türe uymayan ya da tekrar eden ad Tamam'ı engeller. Testler: 46 + 16 + 17 + 20, Win32 + Win64; dört mutasyon ayrı ayrı kırmızı.
- Form durumu global katılımcı sistemi (`docs/specs/rad.formcustomizer.md`): `IRadStateProvider` (uygulama başına kaydedilen sağlayıcı, `ext.<ad>` bölümü; `TRadFormState.RegisterProvider`, `Kapat` temizler), `IRadStateVersion` (isteğe bağlı bölüm sürümü), `TRadPropertiesStore.Attach/Detach` (`Items`'a girmeden `IRadStateful` katılımı), `ResetSaved` ve `TRadFormState.ResetForm` + host kancası `TRadFormState.Reopen` (kayıt sil + formu yeniden aç). Bir katılımcının istisnası diğerlerini durdurmaz, `Errors`'a yazılır. Boş bölüm kaydedilmez.
- `src/component/rad.formstate.dev.pas` — DevExpress sağlayıcıları: `TRadGridStateProvider` (`cxgrid`: adlı her grid view'ın sütun sırası/genişliği/görünürlüğü/sıralaması/gruplaması; geri yükleme sütun yaratmaz/silmez) ve `TRadLayoutStateProvider` (`dxlayout`: adlı her layout control). `IRadStateDesignBound` ile tasarım parmak izi: geliştirici bileşeni değiştirince kullanıcının eski düzeni uygulanmaz. RadKon'a eklendi; testler `src/test/scratch/rad_formstate/FormStateDevTests.pas`.
- `src/component/rad.formstate.customizer.pas` — `TRadFormCustomizer`: kullanıcıya özel görsel değişiklik için izin listesi (`Allowed`: bileşen + nokta yollu özellikler), Türkçe başlıklar (`Captions` + yerleşik), sahibin store'una kendiliğinden katılım, yalnız farkı saklama, ppi ölçeği, `Commit`/`ResetPath`/`ResetAll`, `Customize` (oturum TMS paketinden kaydolur). `TRadPropertiesStore.Reapply`/`ReapplyOwner`, `TRadFormState.Reapply`; `rad.script.hooks.ApplyOverrides` sonunda kullanıcı katmanını şirket düzeninin üstüne geri koyar. `TRadStateItem` bildirimi her `TComponent` sahibi için çalışır. Testler `FormStateTestCustom.pas/.dfm`, `FormStateCustomizerTests.pas`.
- `.agents/rules/delphi-conventions.md`: "Public functions live in static classes" kuralı. `.agents/rules/helper-patterns.md`, `AGENTS.md` ve üç kimlik dosyası buna göre güncellendi. `Self` (E2003), `virtual` (E2376) ve `of object` olay ataması (E2009) `static` ile derlenmediği için istisnadır (Delphi 37.0 Win32'de ölçüldü).
- `src/test/scratch/rad_fluentgen` eski adların sarmalayıcı olarak çalıştığını da denetler.
- `rad.utils`: `fgoIncludeInherited` — atalardan gelen public üyeleri de üretir (`TObject`, `TPersistent`, `TInterfacedObject` hariç; varsayılanda kapalı). Her ad için en türemiş sınıftaki bildirim alınır: override tek üye olur, gizlenmiş overload ve property üretilmez. `CountFluentMembers` çıktının boyutunu önceden verir.
- `src/packages/Rad.Editor.FluentOptions.pas`, `.dfm` — RadMenü'nün üretimden önce açtığı seçenek formu: seçili sınıfları üye sayılarıyla listeler, kalıtılan üyeleri sorar (kapalı başlar). Tasarım DFM'de, form komut çalışınca oluşturulur. `RadKon.dpk/.dproj` bu birime bağlandı.
- `src/test/scratch/rad_fluentgen/FluentGenTest.dpr`, `FluentGenFixture.pas`, `build_and_run.bat` — `GenerateFluentUnit` tuzak sınıfları ve birleştirme hedefleri; Win32/Win64'te üretilen her birimi ayrıca derler.
- `rad.utils`: `CFluentUnitDefaultOptions` — `CFluentGenDefaultOptions` + `fgoQualifiedTypeNames`.
- **RadMenü**: `Rad.Editor` IDE ana menüsüne Tools'tan sonra üst düzey bir menü ekler (`INTAServices`; bileşen editörü kaydı yok, mevcut editörler etkilenmez, menü `finalization`'da kalkar). İlk araç **Seçili Komponenti Fluent'e Çevir**: seçili bileşenlerin sınıfları için `GenerateFluentUnit` çalıştırır, kayıt yolunu sorar, dosya varsa bölgeleri birleştirir, sonucu editörde açar. Sağ tık menüsünde de `TSelectionEditor` ile bir RadMenü alt menüsü var; ana menüdeki araçları kopyalar, yeni araç iki yerde birden görünür (form ve frame kökünde gizli). Menü servisi öğenin sahipliğini devralsa da paket kaldırılınca öğe temizlenir. Form/frame kökü çevrilemez. Sınıf kaynağı IDE'nin Browsing/Search yollarında aranır.
- `src/packages/Rad.Editor.Tools.pas` — RadMenü'nün IDE'siz kısmı (`TRadToolMenu`, `RadFluentSelection`, `RadFluentDefaultFileName`, `RadFluentFindSource`, `RadFluentLibraryPath`, `RadFluentWriteUnit`); `DesignIntf`/`ToolsAPI` kullanmaz. `RadKon.dpk/.dproj` bu birime bağlandı.
- `src/test/scratch/rad_radmenu/RadMenuToolsTest.dpr`, `build_and_run.bat` — Win32/Win64 konsol testi; üretilen birimi de derler, map dosyasında IDE birimi arar.
- `Help.Dev`: `_EditGetValue`/`_EditSetValue` — editör değerini dilden bağımsız saklar ve geri yazar (`TcxCheckComboBox` JSON dizisi, tarih ISO metni).
- `Help.Dev`: `_EditToFilter(F, alan, editör)` — editör değerini türüne göre `IRadSqlFilter` koşuluna çevirir (metin `Contains`, `TcxCheckComboBox` `InList`, diğerleri `Equal`).
- `src/test/scratch/rad_sqlfilter/FilterEditTest.dpr` — `_EditToFilter` testi.
- `Help.Dev`: `_ActiveEdit` — odaktaki DevExpress editörü (odak editörün iç denetimindedir, `ActiveControl is TcxCustomEdit` her zaman False'tur).
- `Help.uni`: `_UseFilter(F)` ve `_OpenFilter(F)` — filtrenin bütün akışı tek çağrıda, her UniDAC dataset'inde (`TUniQuery`, `TRadQuery`, `TUniTable`). Geliştiricinin `WHERE`, `ORDER BY` ve parametrelerini korur (`SaveSQL`/`RestoreSQL`); `_ApplyFilter` yalnız parametre yazan alt düzey çağrı olarak kalır.
- `rad.sqlfilter`: `RadSqlHasSetOperator(ASql)` — üst düzey `UNION`/`INTERSECT`/`EXCEPT` tespiti; `_UseFilter` böyle bir sorguya koşul yazmayı reddeder (`AddWhere` yalnız ilk kola uygulanırdı).
- `src/test/scratch/rad_sqlfilter/FilterFlowLiveTest.dpr` — `_UseFilter`/`_OpenFilter` canlı testi (oturuma özel geçici tablo).
- `src/share/rad.reports.pas`, `src/share/rad.reports.dfm` — **RadReports**: FastReport VCL tabanlı rapor sistemi, bir bileşen gibi kullanılır. TEK çekirdek birim: `IRadReports` servis (`TRadReports.New(bağlantı, kullanıcı)`) + `IRadReport` iş nesnesi (`Report(key).Data(qry, 'ad').Run`), tipler, dosya adı şablonu, yerel eşitleme, depo, FastReport bileşenleri. Yetki/sahiplik/paylaşım/tür yok (sahibin kararı); bir anahtarın birden çok tasarımı, varsayılan tasarım, SHA ile çakışma kontrolü, silme öncesi yerel yedek, `AddToMenu`/`Actions`, `LoadDefaults` (yalnız eksik). Her iş nesnesinin kendi `TfrxReport` motoru vardır. (Aynı gün içindeki `rapor.dm`/`rapor.yonetim` taslakları bununla değiştirildi.)
- `src/share/rad.reports.manage.pas`, `src/share/rad.reports.manage.dfm` — DevExpress Ribbon yönetim formu (`TRadReportManageForm : TdxRibbonForm`); `IRadReport.Manage` açar.
- `src/share/rad.reports.md` — RadReports notları (kullanım, sözleşme, dersler, testler).
- `src/test/unit/rad.reports.Tests.pas` — veritabanı gerektirmeyen DUnitX testleri (dosya adı, yerel eşitleme, sabitler).
- `src/test/unit/rad.reports.db.Tests.pas` — depo, servis/iş API'si ve yönetim formu testleri (iki iş nesnesinin karışmaması dâhil). Atılabilir bir PostgreSQL veritabanı yaratıp siler; `RAPOR_TEST_PGPWD` yoksa "atlandı" diye geçer. `src/test/RunTests.dpr/.dproj` bunlara bağlandı.
- `rad.searchexpr`: operatör (`>`, `>=`, `=`, `<>` ...), joker (`*`, `?`) ve `..` çevresindeki boşluklar yok sayılır (`> 1`, `0 555 *`, `10 .. 20`); tırnak içi korunur.
- `src/core/rad.searchexpr.pas` — liste "genel arama" kutusunun ifade çözümleyicisi (veritabanından bağımsız): `RadSearchParse` metni terimlere ayırır (boşlukla ayrı terimler, `"tırnak"`, `=`, `>`, `>=`, `<`, `<=`, `<>`/`!=`, aralık `a..b`/`a..`/`..b`), `RadSearchValue` terimi alan türüne göre çevirir (tamsayı yalnız rakam, ondalık `1.234,56`/`1,234.56`/`12.5` ama `12e3` değil, tarih yerel ya da `yyyy-mm-dd`, evet/hayır), `RadSearchApply` koşulu `IRadSqlFilter`'a yazar (metin: içerir, `=` tam eşit; sayı/tarih: karşılaştırma; tarihte `rad.sqlfilter` WholeDay anlamı). Joker: `*` (her şey), `?` (tek karakter), `\*` `\?` `\` düz karakter; `kasa*` başlar, `*5595` biter, `a*b` ortada (PostgreSQL `ILIKE ... ESCAPE '!'`, `%`/`_` kaçırılır). `skDigits` rakam alanı türü (telefon): terimin rakam dışı karakterleri atılır, alan ifadesini geliştirici verir. Test: `src/test/scratch/rad_sqlfilter/SearchExprTest.dpr` (59/59; `build_and_run.bat Win32 SearchExprTest`).
- **`rad.rtl`: `IRadGlobalKey`, `TRadDataSetPost`, `TRadDataSetCancel`, `RadGlobalKeyOf`.**
  Genel (form bağımsız) kısayol anahtarı artık `TRadAction`'a özel değil, arayüz: `TRadActionList`
  (`LoadFromJson/ToJson`) ve `Kisayol.Edit` `RadGlobalKeyOf(act)` ile her eylem türünden okur.
  `TRadDataSetPost/Cancel` standart `TDataSetPost/Cancel`'dir (veri kümesi Edit/Insert durumundaysa
  etkin; `DataSource` boşsa odaktaki veri-bağlı denetimin kaynağı) ve `GlobalKey` taşır; Post/Cancel'dan
  önce `RadCommitEditors`/`RadCancelEditors` kancaları (satır içi düzenleyiciyi kapatmak için, `rad.dev`
  atayacak) çalışır. `Rad.Register` yeni eylemleri `RadKon` paletine ekler. Paket `RadKon` yeniden
  derlenip IDE'ye kurulmalı (çalışan IDE `RadKon.bpl`'yi kilitlediği için komut satırı çıktısı yazamadı;
  kaynaklar hatasız derlendi).
- **`rad.sqlfilter`: `GetOrderByFields`** — `ORDER BY` öneksiz sıralama listesi (`k.ad DESC, b.doviz ASC`), UniDAC
  `SetOrderBy` bu biçimi bekler; `GetOrderBy` artık bunun üstüne kurulur (SqlFilterTest T15g–T15i).
  `rad.dev.customfields`: metin/not alanlarının süzgeci `rcInsensitive` `Contains` (varsayılan mod `rcDatabase` olduğu için).

### Changed

- **Paket ayrımı:** `RadKon` artık yalnız çalışma paketi (`{$RUNONLY}`; `designide` ve `dclcxLibraryRS37` kalktı); tasarım birimleri (`Rad.Register`, `Rad.Editor`, `Rad.Editor.FormState(.Model)`, `Rad.Editor.Tools`, `Rad.Editor.FluentOptions`) yeni `src/packages/RadKonD.dpk/.dproj/.res`'te (`{$DESIGNONLY}`, requires `RadKon`). Önceden örtük giren `rad.tms.formtabs` RadKon'a açıkça eklendi; yoksa tasarım paketine kayardı. **IDE'de:** eski RadKon kaldırılır, RadKonD kurulur. RadKon, RadKonD, RadScriptTms, RadScriptTmsDesign Win32 derlendi.
- `TRadPropertiesStore`: `Version` artık yalnız yerleşimi (`form`, `props`) kapılar; `custom` ve `ext` bölümleri kökteki `sections` haritasındaki kendi sürümleriyle kapılanır. Önceden sürüm artınca `TRadActionList` kısayolları da kayboluyordu. `TRadStoredValue.ValueType` değişince tasarım `Value`'su yeni türe çevrilir, uymazsa temizlenir.
- `RadKon`: `TRadPropertiesStore` `rad.formstate.component`'ten kaydedilir; paket `rad.cipher` (önceden örtük) ve dört `rad.formstate` birimini içerir.
- `TRadPropertiesStore.GetInteger/GetDouble/GetDate/GetBoolean`: kayıtlı ve varsayılan değer yokken çağıranın varsayılanı yerine `0` dönüyordu (mORMot `VariantToInteger`/`VariantToDateTime` `Null`'ı `0` sayıp başarı döndürüyor); artık `ADefault`. Metin olarak saklanan sayı da (`'5'`) okunur.
- **Public serbest fonksiyonlar `static` sınıf üyelerine taşındı.** Eski adlar bir minor sürüm boyunca `deprecated` sarmalayıcı olarak kalır, derleyici yeni adı gösterir: `rad.utils` → `TRadFluent` (`GenerateCode`, `GenerateUnit`, `ListRegions`, `PruneRegions`, `CountMembers`) ve `TRadDate` (`EQ`, `LT`, `LE`, `GT`, `GE`, `Fix`, `DayOfMonth`); `rad.cache` → `TSmartCache.New`/`Global`; `rad.eventbus` → `TChannelBus.New`/`Global`; `rad` → `TRadApp.Instance`/`Config`; `rad.cmd` → `TRadCmds.New`; `rad.permission` → `TRadPermissions.New`; `rad.thread` → `TRadCancellation.NewSource`; `rad.date` → `TDtCalendar.IsWorkDay`; `rad.searchexpr` → `TRadSearch`; `rad.sqlfilter` → `TRadSqlFilter.HasSetOperator`; `rad.db` → `TRadDbFilter.ToSql`; `Rad.Dev` → `TRadChain.Audit`; `rad.rtl` → `TRadGlobalKey.KeyOf`; `help.Dev` → `TDev`; `rad.script.dev`/`.uni` → `TRadScriptDev`/`TRadScriptUni.RegisterAll`. `rad.pas` içindeki tarih fonksiyonu kopyaları kaldırıldı, sarmalayıcılar `TRadDate`'e gider. Bu sürümde yeni olan `RadFluent*` adları sarmalayıcısız değişti: `TRadFluentDesign`, `TRadFluentOptionsForm.Ask`.
- `GenerateFluentUnit`: varsayılan seçenek artık `CFluentUnitDefaultOptions`; tip adları nitelenmiş üretilir, çünkü kısa ad `uses` sırasına göre başka tipe bağlanabiliyordu (`TBitmap`: `Vcl.Graphics` / `Winapi.Windows`). `fgoQualifiedTypeNames` artık sarmalanan sınıfın kendi adına da uygulanır. `GenerateFluentCode` çıktısı değişmedi.
- `GenerateFluentUnit` birleştirme: BOM'suz UTF-8 dosyada Türkçe metin kalıcı bozuluyordu, artık baytlar denetlenir. `uses` cümlesi yorumlara, `;` içeren yorumlara ve `UsesTls` gibi alanlara karşı konum korunarak okunur. Yalnız `implementation` tarafında bulunan unit, E2004 vermemesi için interface'e taşınır.
- `GenerateFluentUnit` kaynak tarama: ileri bildirim (`TX = class;`), metasınıf ve gövdesiz sınıf başlık sanılmıyor; iç içe tiplerin üyeleri sınıfa karışmıyor; `end {$IFDEF X} ... {$ENDIF};` sınıf sonu sayılıyor; bilinen sembollere bağlı etkin olmayan `{$IF}` dalları okunmuyor; kaynak `uses` listesinden yalnızca süreçte bağlı unit'ler alınıyor.
- `GenerateFluentUnit` üretim: erişimci gerçek bir metotla çakışınca metot adını korur, erişimci `Prop` soneki alır (`GetTextProp`); `AsInstance`/`New` ile çakışan metot `Method` soneki alır. Ayrılmış sözcükler `&` ile kaçırılır. Generic ve iç içe sınıflar geçerli ada iner (`IGen_System_Integer`). Parametreli overload'lar, parametresiz kardeşleri yüzünden artık düşürülmez.
- `GenerateFluentUnit`: iç içe tip kullanan sınıflarda (`TButton`, `TCustomButton.TButtonStyle`) dış sınıfı unit sanıp `uses`'a yazıyordu, üretilen birim F2613 ile derlenmiyordu. Metin taraması artık yalnız generic argümanlara bakıyor.
- `src/share/rad.reports.pas`: `AddToMenu` alt menüsü açılmıyor, SQL sürekli çalışıyor, ekran titriyordu. Açılır menüde öğenin `OnClick`'ine
  artık bağlanılmaz (liste `OnPopup`'ta yenilenir); `FillMenu` `Clear` yerine önce ekleyip sonra siler, öğe sayısı sıfıra düşmez. Testler:
  `rad.reports.db.Tests` `AddToMenu_SubmenuOpen_DoesNotRebuild`, `AddToMenu_MainMenu_RefreshesOnClick`.
- `src/share/rad.reports.pas`: raporlar veri satırı basmıyordu, tasarımcıda bant veri kümesi boş görünüyordu. Köprüler şablon yüklendikten
  sonra kuruluyordu ve FastReport adı yükleme anında çözüyor. Artık köprüler yüklemeden önce kurulur (`CreateBridges`). Rapor gerçekten
  satır dolaştığı için liste imleci korunur: denetimler kapatılır, hazırlık sonrası ve iş bitince seçili satıra dönülür. Testler:
  `rad.reports.db.Tests` `Export_RendersDataRows_EveryRun`, `Design_LoadedTemplate_BandKeepsDataSet`, `Export_KeepsCursorAndControls`.
- `src/share/rad.reports.pas`: **`IRadReport.Design` özelliği `DesignName` oldu** (getter `GetDesignName`). Aynı adlı `procedure Design`'ı
  gizliyordu; yönetim formunun Tasarla ve Yeni tasarım düğmeleri tasarımcıyı açmadan sessizce dönüyordu. Ayrıca `SaveFromDesigner`
  adlı yeni tasarımı `out` parametresi yüzünden boş anahtarla yazıyordu; düzeltildi. Testler: `rad.reports.db.Tests`
  `ManageForm_DesignButton_OpensDesigner`, `NewNamedDesign_SavedUnderItsKey` (ikisi de düzeltmeden önce kırmızı doğrulandı).
- `src/share/rad.reports.pas`: tasarımcıdan Kaydet, servis yeniden kurulduktan sonra (şirket değişimi) FastReport'un dosya
  diyaloğuna düşüyor ve tasarım veritabanına yazılmıyordu — `TfrxDesigner.Destroy` global `frxDesignerComp`'u koşulsuz `nil`
  yapıyor. Artık her tasarım açılışında ve servis kapanışında global yaşayan servisin bileşenine bağlanır; yeni tasarım boş bir
  sayfayla açılır. Test: `rad.reports.db.Tests` `TwoServices_DesignerHookSurvivesRelease` (düzeltme kapalıyken kırmızı doğrulandı).
- **`rad.dev`: `TRadValueList.Wrap` + `TRadCheckComboBoxProperties.AValueWrap`** (published,
  varsayılan `False`): açıkken `EditValue` baş/son ayraçlı yazılır (`|a|b|`), okuma zaten boş
  parçaları attığı için simetrik. `rad.customfield`'ın çoklu seçim biçimi için. `DoAssign` artık
  `AValueDelimiter`/`AValueWrap`'ı da kopyalıyor (önceden yalnız `RadSetting`+`Items` kopyalanıyor,
  ayraç kaynakta kalıyordu). `CheckComboTest` 43/43 Win32 yeniden koşturuldu.
- `.agents/rules/delphi-conventions.md` — yeni bölüm: `Format` içinde `%0:s` gibi indeksli bir
  belirteçten sonraki indekssiz `%s`'ler sırayı o indeksten devam ettirir (ölçüldü: FK referansı
  yanlış argümanı aldı, üç sunucuda DDL patladı).
- `.agents/skills/unidac-data-access/SKILL.md` — yeni bölüm: Firebird'de bağlantı transaction'ı
  + `AutoCommit` DDL'i anında commit eder; geri alınabilir DDL için ayrı `TUniTransaction` ve sorgu
  düzeyinde `AutoCommit=False` (ölçüldü, `FbDdlProbe`). Her SELECT varsayılan transaction'ı açık
  bırakır, `InTransaction` Firebird'de yanıltıcı.
- `.agents/skills/devexpress-components/SKILL.md` — `TdxLayoutControl` bölümüne üç ölçülmüş not:
  `Parent := Layout` atanan kontrole layout kendiliğinden item açar (`CreateItemForControl` ikinciyi
  reddeder); akış kaydı kontrolün `Name`'ini önek yapar; `SaveToStream` item `Visible`'ını saklamaz.
- **`rad.sqlfilter`: varsayılan harf modu `rcDatabase` (düz işleç).** Önceden `rcInsensitive`'ti:
  metin değerli her `Equal/NotEqual` `lower(alan) = lower(:p)` olarak yazılıyor, `uuid` ve kod
  alanlarında indeksi devre dışı bırakıyordu (`lower(k.id) = lower('{…}')`). Artık `lower/UPPER/ILIKE`
  yalnız `CaseSensitive(False)`, `CaseMode(rcInsensitive)` ya da çağrı başına `rcInsensitive` ile
  yazılır. `CaseMode(rcDefault)` de `rcDatabase`'e döner. `SqlFilterTest.dpr`'de 13 test açık
  `CaseSensitive(False)` ile korundu, üç yeni varsayılan test eklendi (138/138 Win32+Win64);
  `SqlFilterLiveTest.dpr` filtreyi açık duyarsız kurar (canlı sunucularda çalıştırılmadı, derlendi).

### Added

- `src/core/rad.customfield.pas` — **özel alan çekirdeği** (RTL + `rad.sqlfilter`): bir tabloya
  çalışma zamanında alan ekleme modeli. `TRadCustomFieldDef`/`TRadCustomFieldGroupDef` (kategori =
  sekme), 11 tip (`metin, not, tamsayi, ondalik, para, tarih, saat, tarihsaat, evethayir, tekli,
  coklu`), kolon adı üretimi `ozel_N` (tablo başına sayaç, hiç yeniden kullanılmaz, kullanıcı yalnız
  başlığı değiştirir), `TRadCustomFieldDdl` (dört lehçede `ADD COLUMN`/uzunluk genişletme/katalog
  sorguları/üç tanım tablosunun DDL'i — `ozel_alan_grup`, `ozel_alan`, `ozel_alan_duzen`),
  `TRadMultiChoice` (`|k1|k2|` biçimi: `Contains(alan, '|k1|')` kısmi eşleşmez), `IRadCustomFieldStore`
  arayüzü. Değerler **gerçek kolon**: grid/rapor/`rad.sqlfilter`/`TcxDB*` ek kodsuz çalışır.
  Silme = `aktif_mi=false`; tip ve kolon adı kaydedildikten sonra değişmez; uzunluk yalnız genişler.
  `CustomFieldTest` 91/91 Win32+Win64. Spec: `docs/specs/rad.customfield.md`.
- `src/core/Help.uni.pas` — `TRadUniCustomFieldStore` (UniDAC uygulaması; `AddField` = DDL + insert
  tek transaction, Firebird'de ayrı `TUniTransaction`), `TUniConnection._CustomFields`,
  `_CustomFieldColumns(tablo, alias)` (`', c.ozel_1, c.ozel_2'`), `TCustomDADataSet
  ._ApplyCustomFieldMacro('ozel', tablo, alias)` (açık kolon listeli sorgu için `&ozel` makrosu) ve
  `_EnsureCustomFields` (persistent `TField`'lı kapalı dataset'e eksik `ozel_*` alanlarını yaratır).
  `CustomFieldLiveTest`: PostgreSQL 18 / SQL Server / Firebird 5 146/146 Win32, PG+MS 98/98 Win64;
  DDL geri alma üçünde de ölçüldü.
- `src/component/rad.dev.customfields.pas` + `.dfm` — **`TRadCustomFieldsFrame`**: tanımları okur,
  her alan için DB-bağlı DevExpress editörü (`TcxDBTextEdit/Memo/SpinEdit/CalcEdit/CurrencyEdit/
  DateEdit/TimeEdit/CheckBox/ImageComboBox`, çoklu seçim için `TRadDBCheckComboBox` + `AValueWrap`)
  yaratıp `TdxLayoutControl`'de kategori sekmelerine yerleştirir; kullanıcı başına düzen
  (`Customizing`, `SaveLayout/ResetLayout`; görünürlük çerçevenin kendi başlığında taşınır çünkü
  DevExpress akışı saklamaz; sonradan eklenen alan kendi grubunun sonuna gelir), `BeforePost`
  zorunlu alan kontrolü ve `OnNewRecord` varsayılanları (mevcut işleyiciler zincirlenir, ayrılırken
  geri konur), `CanDesign` ile "Ayar" düğmesi → **`TRadCustomFieldDesigner`** (Wolvox düzeni: sol
  kategori, sağ alan; kodla kurulur, DFM yok). `CustomFieldsFrameTest` 58/58 Win32+Win64 (PG).
  Çerçeve tasarım zamanında forma bırakılıp DFM'den akıtılınca (`inline`) `CreateLayout` AV
  veriyordu: DevExpress, sahip zincirinde `csLoading` varken (`IsGlobalLoading`) layout'un kök
  grubunu DFM'den bekleyip yaratmıyor, `Name` ataması nil kökle `CanSetItemName`'de patlıyor
  (ERPPlus `kasa.k.pas`'ta görüldü, `HostDfmProbe` ile iki biçimde yeniden üretildi). Çubuk ve
  layout artık `EnsureUi` ile sahip zinciri yüklemeyi bitirince kurulur (`Loaded`/`CreateWnd`/
  `Rebuild`); `Rebuild` yükleme bitmeden çağrılırsa açık `ERadCustomField`. Probe 2/2.
  **Sonra (aynı gün) statik parça DFM'ye taşındı:** `rad.dev.customfields.dfm` artık
  `lcRadCustomFields` (`TdxLayoutControl`, kök grup `ldTabbed`), `pnlBar` ve dört `TcxButton`'ı
  taşıyor; `EnsureUi`/`Loaded`/`CreateWnd` sarmalaması silindi (kök grup DFM'den geldiği için
  `IsGlobalLoading` tuzağı kalmadı). `Rebuild` layout'u yıkmak yerine `ClearItems` ile editör/item/
  grupları söküyor. Sekme, item ve editörler tanımdan geldiği için hep kodla.
- `src/component/rad.dev.customfielddesigner.pas` + `.dfm` — **`TRadCustomFieldDesigner`** kendi
  birimine taşındı ve tamamen DFM'ye alındı (bir birimde tek `{$R *.dfm}` formu olabilir):
  `lcMain` layout, sol `grpGroups` (liste, ad, sıra, aktif, iki düğme), sağ `grpFields` (liste,
  kolon adı, başlık, tip, uzunluk, ondalık, varsayılan, seçenekler, sıra, üç bayrak, iki düğme),
  altta Tamam. Test erişimi için `EdCaption`/`SaveField` gibi public üyeler korundu;
  `CustomFieldsFrameTest` değişmeden 58/58, `HostDfmProbe` 2/2, paket derlendi.
- `TRadCustomFieldsFrame` **filtre kipi** (`Mode = cfmFilter`, TODO RAD-13'ün ilk yarısı): editörler
  bağsız (`TcxTextEdit/SpinEdit/CalcEdit/CurrencyEdit/DateEdit/TimeEdit/CheckBox/ImageComboBox`,
  çoklu için `TRadCheckComboBox`), `DataSource`/zorunlu/varsayılan kancaları devre dışı, varsayılan
  olarak yalnız `filtrele_mi` işaretli alanlar (`FilterFlaggedOnly`). `ApplyFilter(IRadSqlFilter,
  alias)`: metin/not → `Contains`; tamsayı/ondalık/para/tarih/tarih-saat/saat → iki editör ("…den /
  …e", `ed_ozel_N` + `ed_ozel_N_2`) → `Between` (tek taraf boş olabilir; tarihte `WholeDay`);
  evet/hayır → üç durumlu kutu, gri = koşul yok; tekli → `Equal` ("(tümü)" seçeneği = koşul yok);
  çoklu → seçili kodların `BeginOr…EndOr` içinde `Contains('|kod|')`'u. `ClearFilter`,
  `HasFilterValues`, `EditorToOf`. Düzen kaydı filtre kipinde `tablo:f` anahtarıyla ayrı. Sayı
  editörleri yaratılırken `Clear` ile boşaltılır ('0' doğuyordu; boş = koşul yok). Kodla yaratılan
  çerçevenin DFM'den gelen adı siliniyor: aynı forma düzenleme + filtre çerçevesi konunca
  `EComponentError` veriyordu. `CustomFieldsFrameTest` +30 (PG canlı): 88/88 Win32+Win64.
- `TRadCustomFieldsFrame.DefaultStore` (class var): `Store` atanmamış her çerçeve bunu kullanır;
  uygulama açılışında bir kez atanır, şirket bağlantısı değişince yenilenir, bağlantı kapanmadan nil
  yapılır (depo bağlantıyı tutar). Diyalogda yeni alanın "Filtrele" varsayılanı artık işaretli:
  işaretsiz varsayılan + `FilterFlaggedOnly` birleşince filtre kipi boş kalıyordu (ERPPlus
  `kasa.liste`'de görüldü). `CustomFieldsFrameTest` 91/91 Win32+Win64.
- `src/packages/RadKon.dpk`/`.dproj` — `rad.sqlfilter` (artık açık), `rad.customfield`,
  `rad.dev.customfields` eklendi. MSBuild Win32 Debug geçici klasöre derlendi/linklendi; kurulu
  `RadKon.bpl` IDE açık olduğu için yazılamadı (F2039) — IDE'den yeniden derlenmeli.
- `docs/specs/rad.customfield.md` — spec (EARS ölçütleri + ölçümler).
- `src/core/rad.script.pas` — **script sistemi 2. aşama (RAD-15):** paket/script/parametre/DB adımı/kaynak
  modeli ve doğrulaması, `IRadScriptStore`, `TRadScriptDdl` (5 tablo, 4 lehçe), `TRadScriptPackageFile`
  (`.radpaket` JSON, kaynaklar base64, eksik anahtar varsayılan alır). Cron yazılmadı: `zaman` hedefi
  `rad.date.TDtSchedule` maskesi. `Help.uni.pas`: ortak `TRadUniStoreBase` (Q/Exec/CountOf/TableExists/
  InTransaction/MemoText) çıkarıldı, `TRadUniCustomFieldStore` ona bağlandı, yeni `TRadUniScriptStore`
  (SavePackage tek transaction + alt kayıt senkronu, ImportPackage parametre koruması, ScriptsFor harf
  duyarsız, ApplyPendingDbSteps kaldığı yerden), `TUniConnection._Scripts`. Firebird: blob metin
  parametresi `ftWideMemo`, okuma `MemoText` (UTF-8 bayt yolu yalnız Firebird; PG'de `AsBytes`
  `EEncodingError` verir) — aynı düzeltme özel alan `secenekler` okumasına da uygulandı. Testler
  `src/test/scratch/rad_script/`: `ScriptModelTest` 37/37 Win32+Win64, `ScriptLiveTest` PG/MSSQL/FB
  72/72 Win32, PG+MSSQL 48/48 Win64; `CustomFieldLiveTest` 146/146 regresyon temiz. Paket `RadKon`'a eklendi.
- `.agents/rules/component-patterns.md` — kullanıcı kuralı: görsel tasarım DFM'de, kod yalnız veri güdümlü parçaları kurar.
- `src/vendor/tms/rad.script.engine.pas`, `rad.script.hooks.pas`, `rad.script.jobs.pas` + `src/packages/RadScriptTms.dpk/.dproj/.res`
  — **script sistemi 3. aşama (RAD-15):** `TRadScriptEngine` (TMS Scripter sarmalayıcısı: çoklu script + `uses`,
  script kodlu alt program çağrısı, nesne argümanları `NativeInt`, `OnCompileError` satır/sütun, `OnExecHook`
  zaman aşımı, global derleme kilidi), `TRadNotifyHook` (RTTI olay sarmalayıcı, `Before` `False` iptal,
  `TRadHookChain` ile paketler arası ortak iptal), `TRadScriptBinder.Attach` (sınıf zinciri ata önce,
  kütüphaneler, `<Bileşen>_Before/_After`, `<Bileşen>_<Olay>_Before`, `Form_AfterCreate`, var parametreli
  olay reddi, derleme hatası formu açmayı engellemez), `TRadScriptJobs` (eventbus `olay` + worker `zaman`,
  tetikleme başına motor, yeniden giriş yok). `rad.script`: `ERadScriptCompile/Runtime/Timeout`,
  `IRadScriptStore.LibrariesOf`. Öğrenilen: formun kendi sınıfı TMS'ye tanıtılmaz (kalıtım kopuyor).
  Testler `src/test/scratch/rad_script_hooks/` (`HooksTest` 34/34 Win32+Win64, `Probe`/`Probe2` sondaları);
  `ScriptLiveTest` 78/78 Win32 (S23 `LibrariesOf`).
- `src/vendor/tms/rad.script.facade.pas`, `rad.script.commands.pas`, `rad.script.typedhooks.pas`, `rad.script.dev.pas`,
  `rad.script.uni.pas` — **script sistemi 4. aşama (RAD-15):** `TRadScriptContext` + facade nesneleri (`Db.Sorgu(...)
  .Param(...).Deger/Ac/Calistir`, `BaslaIslem/Onayla/GeriAl` kendi bayrağıyla, `Msg` + `HataMetni`, `Kullanici`,
  `Sirket`, `Param`, `Log`, `Mail`), `komut` türü (`TRadScriptCommands.Attach`), var parametreli olay kancaları
  (`TCloseQueryEvent`, `TcxEditValidateEvent`; DevExpress `Properties` olayları çözülür), UniDAC/DevExpress sınıf
  listeleri (`TUniConnection` parola/bağlantı üyeleri gizli). Motor: `AddOwned`, `PackageIds`, `LastErrorText`,
  `RegisterClassHidden`, `ExportReference`, TMS standart kütüphaneleri; **Create/Free/Destroy her sınıftan silindi**.
  Kanca: `TRadHookBase` tabanı + `RegisterHookClass`, `LoadInto` ortak çekirdek. `rad.script`/`Help.uni`:
  `IRadScriptStore.ParamsOf`. Paket `RadScriptTms` 8 birim. Testler `src/test/scratch/rad_script_facade/`
  (`FacadeTest` 24/24 Win32+Win64 PG canlı, `FacadeVclTest` 7/7 Win32); HooksTest 34/34, ScriptLiveTest 78/78.
- `.agents/skills/rad-script/SKILL.md` — script yazma skill'i (kanca adları, facade, yapılmazlar, 5 örnek, host sözleşmesi).
- `docs/script-api.md` — `TRadScriptEngine.ExportReference` ile üretilen API referansı (FacadeTest her koşuda yeniler).
- `src/vendor/tms/rad.scripting.pas` (RadScriptTmsDesign) ve `src/vendor/tms/rad.scripting.kp.pas` (RadScriptTms) — script
  sisteminin **tek giriş birimleri** (yeni workspace kuralı `share/rules/single-entry-facade.md`, Dext.UI deseni): alt
  `rad.script.*` türleri takma adla dışa verilir (enum değerleri `const` ile), `TRadScripting.Kur(TRadScriptingSetup)` store +
  tanım tabloları + bağlam + facade + UniDAC/DevExpress sınıf kayıtlarını tek çağrıda yapar; `Bagla(Form)` (TBaseForm.DoCreate),
  `KomutlariBagla`, `PaketYoneticisi`, `Tasarla`, `Kapat`. KP: `TRadScriptingKp.Kur(setup, Bus, Workers)` görevleri başlatır,
  `Yenile`, `Kapat`. Host artık dokuz birim yerine bir birim ekler. Test `src/test/scratch/rad_script_ide/ScriptingTest.dpr`
  (PG canlı, 7/7). `.specify/spec-template.md`'ye zorunlu "Entry Unit and Setup Call" bölümü eklendi.
- `src/vendor/tms/rad.script.ide.pas`, `rad.script.packages.pas/.dfm`, `rad.script.newscript.pas/.dfm` — **script sistemi
  6. aşama (RAD-15, son): IDE ve paket yöneticisi.** `TRadScriptIde.Open` TMS `TIDEDialog`'u paketin üstünde açar (script =
  sanal dosya: `OnCheckValidFile/OnLoadFile/OnSaveFile/...` DB'ye, diske dosya yok; `pencere` DFM'si `DesignFormResource` +
  `SaveEvents`), IDE scripter'ı `TRadScriptEngine.CreateFor` ile sarılır (`AdoptScript`; aynı sınıflar/form zinciri/facade/
  palet), `Deneme` menüsü (`Calistir(Olay)` deneme olayıyla; form/komut yalnız derlenir). `TRadScriptPackagesForm`
  (cxGrid, DFM): paket/script/parametre/DB adımı/kaynak, `.radpaket` içe/dışa aktarma, IDE'de aç, Tasarla, satır içi düzenleme;
  `TRadScriptNewScriptForm` türe göre iskelet. `TRadScriptEvent.Fill`, `TRadScriptDesigner.RegisterPaletteInto`.
  `RadScriptTmsDesign` 6 birim, requires `TMSScripter_Memo`. Test `src/test/scratch/rad_script_ide/` IdeTest 18/18;
  regresyonlar yeşil. Form kalıbı (`RegisterFormClass`) uygulanmadı (spec'te gerekçe).
- `docs/specs/rad.script.ide.md` — 6. aşama spec'i (onaylandı ve uygulandı; sapma/ölçüm bölümü eklendi): paket yöneticisi formu (DevExpress, DFM),
  TMS `TIDEDialog` gömülü IDE (paket = proje, script = sanal dosya; `OnLoadFile/OnSaveFile` ile DB), `TRadScriptEngine.CreateFor`
  ile IDE scripter'ına aynı sınıf/facade dünyası, `olay/zaman/kutuphane/pencere` için çalıştırma + hata ayıklama, deneme olayı,
  form script'leri için form kalıbı denemesi.
- `src/core/rad.script.override.pas`, `src/vendor/tms/rad.script.design.pas`, `rad.script.design.bar.pas/.dfm`,
  `rad.script.design.tools.pas/.dfm`, `src/packages/RadScriptTmsDesign.dpk/.dproj/.res` — **script sistemi 5. aşama
  (RAD-15): tasarımcı.** `TRadPropSnapshot` (adlı bileşenlerin yayımlanmış özellikleri, fark, `duzen.json`, uygulama;
  VCL'siz), `TRadScriptDesigner.Start/StartWindow` (TMS `TIDEFormDesigner` + `TIDEInspector` + palet; mevcut formda
  seçim var, taşıma/silme yok; Kaydet = fark + `TdxLayoutControl` akışı → paket; Vazgeç; pencere kipinde DFM → `<kod>.dfm`,
  bilinmeyen olay rutini uyarısı, derleme denemesi). Model: `tur = pencere` (`skWindow`, `{$FORM}` + DFM kaynağı zorunlu),
  `TRadScriptResource.PackageId`, `IRadScriptStore.ResourcesNamed`, `LibrariesOf` pencere dahil. Motor: `TRadScriptForm`,
  `ScriptFormClass`/`LoadFormEvents`, `SetFormResource`, form ata zinciri kayıtlı + `RelinkAncestors`, VCL metotları
  (`Show/Hide/Close/ShowModal/Release/SetFocus/BringToFront/Refresh`) elle tanımlı, `TComponent` yıkım üyeleri gizli.
  Binder: `Attach` önce düzen/yerleşim uygular (script yokken de), `RegisterLayoutClass` (`rad.script.dev` TdxLayoutControl
  kaydeder). `RadScriptTms` requires `TMSScripter_VCL`. Testler `src/test/scratch/rad_script_design/` (OverrideTest 21/21
  Win32+Win64, DesignVclTest 35/35 Win32); ScriptModelTest 43, ScriptLiveTest 87 (PG/MS/FB), HooksTest 34, FacadeTest 24,
  FacadeVclTest 7 yeşil. `docs/script-api.md` yeniden üretildi (TComponent…TRadScriptForm zinciri eklendi).
- `docs/specs/rad.script.designer.md` — 5. aşama spec'i (onaylandı ve uygulandı; sapma/ölçüm bölümü eklendi): mevcut formu özelleştirme
  (`<Sınıf>.duzen.json` özellik farkı + `.layout` kaynağı, `Attach`'te uygulanır), `pencere` türü (script'in
  kendi DFM'li formu, TMS `$FORM` + `DesignFormResource`), TMS tasarımcı/inspector/palet ile DFM'de yazılmış
  tasarım pencereleri, ayrı `RadScriptTmsDesign` paketi, `IRadScriptStore.ResourcesNamed`.
- `docs/specs/rad.script.facade.md` — 4. aşama spec'i: `TRadScriptContext`, facade nesneleri (`Db.Sorgu(...).Param(...).Deger`,
  `Msg`, `Kullanici`, `Sirket`, `Param`, `Log`, `Mail`), `komut` türü (`TRadScriptCommands.Attach`), `TCloseQueryEvent`/
  `TcxEditValidateEvent` adaptörleri, UniDAC/DevExpress sınıf listeleri (parola üyeleri gizli), üretilen API referansı ve
  `rad-script` skill'i; 12 EARS ölçütü; kod yazılmadı.
- `docs/specs/rad.script.hooks.md` — 3. aşama spec'i: `TRadScriptEngine` (TMS sarmalayıcısı, sınıf kaydı, zaman aşımı),
  `TRadNotifyHook`/`TRadScriptBinder.Attach` (kanca adı kuralları, zincir, hata akışı), `TRadScriptJobs` (KP olay/zaman),
  15 EARS ölçütü; kod yazılmadı.
- `docs/specs/rad.script.md` — script sisteminin 2. aşama spec'i (paket/script tabloları, `IRadScriptStore`,
  `.radpaket` dışa/içe aktarma, cron, EARS ölçütleri); onaylı kullanım kararları: İngilizce `_Before/_After`
  kancaları, `_After` hatası geri alınmaz. Kod yazılmadı.
- `docs/specs/rad.script-spike.md` + `src/test/scratch/rad_script_spike/` (`SpikeCore`, `SpikeVcl`,
  `spikeform.dfm`) — **script/eklenti sistemi 1. aşama: motor sondası.** Karar TMS Scripter 8.1
  (Delphi 13 Win32+Win64). Ölçüldü: 501 satır 9 ms derleme, 10.000 alt program çağrısı 101 ms,
  `DefineClassByRTTI` ile DevExpress/`TRadQuery` sınıfları (170 metot/135 özellik) 2 ms'de; overload'da
  son bildirilen kazanıyor, varsayılan parametre zorunlu oluyor; `EventBroker` önce/sonra çalışıyor ama
  temiz iptal yok → kendi RTTI sarmalayıcımız (`TRadNotifyHook`, 25 µs/çağrı) iptal edebiliyor;
  DevExpress var-parametreli olay için elle adaptör çalıştı; DFM'den script formu kuruldu;
  `Halt` komut ortasında AV veriyor, başka thread'den `Halt` güvenilmez → zaman aşımı `OnExecHook`
  + istisna; thread başına ayrı scripter 4/4. Wolvox kaynak incelemesi (PascalScript 1.31, RTTI
  `SetMethodProp` kancası, tek `SCRIPT` blob tablosu, `USER_DB_SQL` migrasyonu) karşılaştırma
  ölçüsü olarak rapora işlendi. Kalıcı birim yazılmadı.
- `src/test/scratch/rad_customfield/` (`CustomFieldTest`, `CustomFieldLiveTest`, `FbDdlProbe`) ve
  `src/test/scratch/rad_customfields_frame/` (`CustomFieldsFrameTest`).
- `src/core/rad.sqlfilter.pas` — **`IRadSqlFilter` / `TRadSqlFilter`**: akıcı WHERE + ORDER BY
  üretici. Değerler hiç SQL metnine yazılmaz, hepsi `:p1..` parametresi (ortak sayaç,
  `ParamPrefix`). `Equal/NotEqual/Greater/GreaterEqual/Less/LessEqual`,
  `Like/NotLike(alan, desen, AEscape, ACase)`, `Contains/NotContains/StartsWith/EndsWith`
  (düz metin), `InList/NotInList`, `Between/NotBetween` (tek taraf `>=`/`<=`),
  `IsNull/IsNotNull`, `Raw('… = ?', [..])`, `BeginOr..EndOr` (tek seviye),
  `AddOrderBy(alan, desc)`, `GetWhere/GetConditions/GetOrderBy/GetSql`, `GetDebugSql`
  (değerler gömülü, yalnız log), `Clear`. `WholeDay` (varsayılan açık): saatsiz tarih
  tüm gün sayılır, yarı açık aralıkla (`Equal` → `>= gün AND < gün+1`, `Greater` →
  `>= gün+1`, `LessEqual` → `< gün+1`); `timestamp`/`datetime2` sütunlarında canlı doğrulandı.
  `rfmSkipEmpty` (varsayılan): boş değer/boş liste/yalnız-joker desen koşul üretmez;
  `rfmStrict`: boş değer hata, boş `IN` `1=0`. `Wildcards('*','?')` ile kullanıcı jokeri,
  `ESCAPE '!'` ile `%`/`_` düz karakter, çift joker = düz joker. Harf duyarlılığı filtre
  geneli + çağrı başına (`rcDefault/rcDatabase/rcSensitive/rcInsensitive`): PostgreSQL
  `ILIKE`/`lower()`, MSSQL/MySQL/Firebird `UPPER()`; `rcSensitive` MSSQL/MySQL'de düz
  işleç (collation'a kalır, ölçüldü: `Turkish_CI_AS` duyarsız kalıyor). Lehçeler
  `sdPostgreSQL/sdMSSQL/sdMySQL/sdFirebird`; MSSQL'de `[` de kaçırılır. Beş açık kaynak
  Delphi ORM/builder'ın (dext, Trysil, mORMot2, CQLBr, DMVC) ortak boşlukları — `IN ()`,
  kaçışsız `LIKE`, "boşsa atla" yokluğu — kapatıldı. Spec: `docs/specs/rad.sqlfilter.md`.
- `src/core/Help.uni.pas` — `TUniConnection._SqlDialect` (ProviderName → lehçe),
  `_NewFilter(mode)`, `TCustomDADataSet._ApplyFilter(filtre)` (parametreleri yazar).
- `docs/specs/rad.sqlfilter.md` — kitin ilk doldurulmuş `.specify` spec'i (EARS ölçütleri,
  lehçe tablosu, ölçümler).
- `src/test/scratch/rad_sqlfilter/` — `SqlFilterTest.dpr` (135 doğrulama, bağlantısız,
  Win32+Win64) ve `SqlFilterLiveTest.dpr` (PostgreSQL 18 `testdb` 42, SQL Server
  `rad_filter_test` 40, Win32+Win64; Firebird 5.0.4 `rad_filter_test.fdb` UTF8 42, yalnız
  Win32 — makinede 64-bit `fbclient.dll` yok). Ölçüm: PostgreSQL
  varsayılan collation'da ve Firebird UTF8'de `UPPER/lower('İ')` `'i'` ile eşleşmiyor
  (`Contains('ad','ismail')` 'İsmail'i bulmuyor); SQL Server `Turkish_CI_AS` buluyor. MySQL
  kurulu değil → lehçe belgeye göre, doğrulanmadı.

- `src/component/rad.dev.pas`, `src/packages/Rad.Register.pas` — **`TRadCheckListBox` /
  `TRadDBCheckListBox`**: `AValueItems` ('Ad=Değer'), `EditValue` `'A;AS'`, `AValues`,
  `AValuesIn(alan)`, `CheckWarning`, `RadSetting` (kontrolün kendi property'si; `TcxCheckListBox`
  bir editör değil kap, `Properties` yok). Değer dikişi `CheckCombo`'dan farklı: DX burada
  sanal metod değil olay çağırıyor (`cxCheckListBox.pas:1332-1361`); `AValueItems` doluyken iki
  olay bağlanır, boşalınca bırakılır, kullanıcının kendi olayı varsa dokunulmaz ve
  `CheckWarning` bildirir. 64+ item `cvfInteger` istisnasını tetiklemez. Testler:
  `RadCheckListTest` (29), `RadCheckListLiveTest` (12, PostgreSQL), mutasyon kontrollü.
  `Mark` ile programatik işaretleme DB kaydını düzenleme moduna ALMAZ (stok da almıyor,
  ölçüldü); gerçek fare tıklaması alır.
- `src/component/rad.dev.pas` — **`TRadValueList`**: `TRadCheckComboBoxProperties`'teki
  'Ad=Değer' ayrıştırma, `EditValue` ↔ değer dizisi, `AValuesIn` ve uyarı mantığı ortak bir
  çekirdeğe taşındı; check combo ve check list box ikisi de onu kullanır. `CheckComboTest`
  (35) hiçbir değişiklik olmadan geçti.
- `src/component/rad.dev.pas` — `TRadCheckComboBoxProperties` da `RadSetting` taşır ve gridin
  inplace editörü `TRadCheckComboBox` olur (`GetContainerClass`); `RadFamiliesTest`'e eklendi (55).
- `src/component/rad.dev.pas`, `src/packages/Rad.Register.pas` — **Dört yeni Rad ailesi,
  hepsi `RadSetting` taşır:** `TRadButtonEdit*`, `TRadImageComboBox*`,
  `TRadExtLookupComboBox*`, `TRadPopupEdit*` (her biri `Properties`, `Repository`,
  `Edit`, `DBEdit`). `GetContainerClass` Rad editörünü döndürür, yani gridin inplace
  editörü Rad sınıfı olur ve sütunun kendi `RadSetting`'i `InternalProperties`'e gelir.
  Editörler `RadKon` paletine, repository'ler DX repository listesine kayıtlı. Testler:
  `rad_dev_repolisteners/RadFamiliesTest` (44; ayrıca `RadSettingLiveTest` D01-D04,
  PostgreSQL), mutasyon kontrollü. Not: `Rad.Register.pas` IDE paketinde derlenmedi.
- `src/component/rad.dev.pas` — **`TcxRadSetting` / `TcxRadDataBinding`**: DevExpress'in
  `Automation`'ı gibi tüketiciye özel bir ayar kümesi (`TcxInterfacedPersistent`).
  `Key` (serbest metin), `Tag`, `Master` (editör/grid kolonu; tip ve dairesel
  denetimli), `Control1..4` (düşme korumalı hedefler), `DataBinding` (bağımsız
  `DataSource` + `DataField`, yalnız okuma) ve yalnız çalışma zamanı `Data`.
  `TRadLookupComboBoxProperties` ve `TRadComboBoxProperties` artık `RadSetting`
  taşır; eski `AComponent1..4`, `AMaster`, `ACascadeField`, `ACascadeTag` ona
  yönlenir ve `stored False`'tur (eski DFM'ler okunur, yeni konuma yazılır).
  Değişim olayı ve `Master` kayıt/bildirimi ertelendi: `TODO.md` RAD-05, RAD-06.
  Testler: `rad_dev_repolisteners/RadSettingTest` (39), `rad_dev_livedb/RadSettingLiveTest`
  (23, PostgreSQL), mutasyon kontrollü.
- `src/component/rad.dev.pas` — **`AEditOnPopup`** (`TRadComboBoxProperties`,
  `TRadLookupComboBoxProperties`, varsayılan `False`): DB'ye bağlı editörde açılır
  liste açılırken dataset'i düzenleme moduna alır. `DataSource.AutoEdit = False` iken
  seçim dataset düzenlenmediği için ilk harekette eski değere dönüyordu (ölçüldü,
  PostgreSQL: `ComboEditModeProbe`); `TDataSource.Edit` `AutoEdit`'i gözettiği için
  doğrudan `DataSet.Edit` çağrılır.
- `src/share/k.setting.pas` (`TfrmSetting`) parlatıldı (dosya eklenmedi): arama kutusunda ipucu ve temizle
  düğmesi, geniş satır başlığı, NavBar'da kategori sayaçları (aramada eşleşen sayı), değiştirilen ayar kalın
  (varsayılandakiler normal), açıklama şeridinde değerin kaynağı (`Varsayılan` / `Değiştirildi (varsayılan: …)`)
  ve "↺ Varsayılana dön" düğmesi (`ResetFocused`), `TRadSettingItem.IsDefault`/`SourceText`/`Source`. Arama
  temizlenince son kayıtlı kategoriye değil, kullanıcının seçtiği NavBar öğesine (yoksa hepsine) dönülür.
- `src/component/rad.tms.formtabs.pas` — `TRadFormTabs` (a `TAdvOfficeTabSet`
  descendant): any `TForm`, MDI or not, becomes a tab; windows stay independent,
  so it works across monitors. The tab's close button closes the form
  (`OnCloseQuery`, `OnClose`); the tab goes when the form hides or dies.
  `HideInactive` (off by default) hides inactive forms, `AutoAttach` attaches
  suitable forms when they activate or when a `TRadFormBase` shows
  (`ShowInTabs`), `OnAcceptForm` overrides the policy. Registered in
  `Rad.Register.pas`; still to do in the IDE: add the unit to `RadKon` and
  `TMSVCLUIPackPkg` to its requires. Replaces `src/core/rad.tms.pas` (untracked,
  untouched). Tests: `src/test/scratch/rad_formtabs` (55 assertions, Win32 and
  Win64), mutation-checked; `FormTabsDfmNormal`/`FormTabsDfmMdi` (.pas/.dfm) are
  the DFM-loaded forms for tests 51-55.
- `src/core/Help.vcl.pas` — `TFormFactory.AddListener`/`RemoveListener`
  (multicast; `RegisterEvent` unchanged) and `TRadFormBase.ShowInTabs`
  (default `True`). Tests: `rad_formfactory` 19-22.
- `src/component/Permission.Edit.pas` — **permission templates now cover the
  repetitive Ekle/Sil/Düzenle case end to end.** The template menu already
  existed; three things were missing. (1) A template applies to **every
  selected node** (`OptionsSelection.MultiSelect` is on in edit mode), falling
  back to the focused node when the selection is empty (Ctrl+click can
  deselect it). Codes that already exist are skipped and counted instead of one
  modal message per node; `ApplyTemplate` returns `TRadTemplateResult`
  (Targets/Added/Skipped/Failed) and the menu shows one summary. (2) **"Şablon
  Olarak Kaydet..."** turns the focused node's children into a template
  (nested children supported, a template with the same id is replaced after
  confirmation) via `SaveAsTemplate`. Children are stored by their own id, so
  the template picks up each target's prefix when applied. (3) A record with
  **no `sablon` key** is seeded with a `crud` template (`ekle`, `sil`, `edit`)
  when opened for editing; an existing empty `sablon` array is respected, so
  deleting every template does not bring it back. `_AddNode` lost its modal
  message and gained `out ACreated`. Red before, green after in
  `rad_permission` 38-57; the seed rule was mutation-checked.
- `src/core/help.Dev.pas` — `TSkinRenk` record and global `SkinRenk`: DevExpress skin
  colors (header, content, selection, search highlight) as plain `TColor`s for
  non-DevExpress components. `TSkinRenk.Init` registers once on
  `RootLookAndFeel` (`AddChangeListener`), so skin and palette changes refresh
  the colors and fire `TSkinRenk.OnChanged`. Missing skin colors fall back to
  system colors, never `nil`. Verified with a console program: WXICompact
  Darkness/Light, TheBezier and no-skin all refreshed.
  `SearchHighlightText` was added; `dm.dev` now assigns the focused-editor color
  (`DefaultEditStyle.StyleFocused`) from `SkinRenk` and refreshes it on skin change
  — the hard-coded yellow in `dm.dev.dfm` was removed.
- `TODO.md` — the repository's own list of pending work (`RAD-NN` numbered):
  Argon2id for `THash`, plaintext config password, undefined function results
  and implicit `UTF8String` casts found by the 2026-10-17 ERPPlus build.
- `src/component/Rad.Dev.pas` — **`TRadCheckComboBox` / `TRadDBCheckComboBox` /
  `TRadCheckComboBoxRepository`: a check combo whose items carry values, with
  no event code.** `AValueItems` takes one `Name=Value` line per item
  (`Alıcı=A`, `Satıcı=S`, `Alıcı ve Satıcı=AS`); the stock `Items` is built from
  it and is no longer streamed (`stored False`), so there is one source. The
  edit value is the checked values joined by `AValueDelimiter` (`A;AS`); the
  editor exposes `AValues: TArray<string>` to read and load the selection,
  `AHasValues`, and `AValuesIn('cari_tip')` → `cari_tip in ('A','AS')` with
  quotes doubled. Why it is built this way: `TcxCheckStatesValueFormat` is a
  subrange, so no new format can be added, and the stock `cvfCaptions` is a
  length-prefixed encoding (`cxCheckBox.pas:633`) unfit for SQL; the item class
  is fixed in the properties constructor (`cxCheckComboBox.pas:1168`), so
  values live beside the items rather than in them. The seam is the two
  virtual `Calculate*` methods (`:246-249`), not the published events — if the
  events are assigned they win, as in the stock class, and the audit says so.
  `EditValueFormat` defaults to `cvfStatesString` here, because `cvfInteger`
  raises at 64 items and treats an empty value as a number. Two more things
  measured: the display delimiter is the stock `Delimiter` (`;`, no space),
  and on the DB editor a value assigned in code did not reach the field
  (`CanPostEditorValue` needs the link in editing+modified state,
  `cxDBEdit.pas:1980`), so `AValues` on `TRadDBCheckComboBox` first calls
  `SetEditMode`. `RadChainAudit` reports duplicate values, a value containing
  the delimiter, the event override, and a bound DB field that is not text or
  too short for all values. Known limit: the grid's filter row creates its own
  stock `TcxCheckComboBox` (`:1725-1757`) and does not see the value mode.
- `src/packages/Rad.Register.pas` — registers the two editors and the
  repository item (design-time, not compiled here).
- `src/test/scratch/rad_dev_repolisteners/CheckComboTest.dpr` — 35 assertions:
  value round trip, case-insensitive parsing in item order, unknown values,
  70 items, fixed lists, stock behaviour with empty `AValueItems`, shared
  repository, DFM round trip (`Items` absent), DB field write, and every audit
  message.

- `src/component/rad.db.pas` — **`TRadFieldCascade`**, a non-visual component
  for the data module: when a field is *edited*, it clears the fields that
  depend on it. One line per chain in `AChains` (`'ulke;sehir;ilce'`): editing
  `ulke` clears `sehir` and `ilce`, editing `sehir` clears `ilce`. It listens to
  the dataset itself through a plain `TDataLink`, so it works the same for a
  form editor, a grid, or code. The VCL separates the two cases the rule
  needs: an edited field arrives as `RecordChanged(Field)`, while navigation
  and refreshes arrive as `RecordChanged(nil)` (`Data.DB.pas:10799-10800`,
  `:10839-10847`). A parameterless event such as `TcxDBDataBinding.OnDataChange`
  cannot tell them apart, which is why the component does not use it.
  Navigation, `Cancel`/`Post` refreshes and re-writing the same value clear
  nothing; clearing a master to Null clears its dependants; `ADataSource` is
  nil'ed when the data source is destroyed. It replaces the per-field
  `OnChange` handlers previously recommended for this job.
- `src/packages/Rad.Register.pas` — registers `TRadFieldCascade` on the RadKon
  palette. Not compiled here (design-time unit).
- `src/test/scratch/rad_dev_repolisteners/FieldCascadeTest.dpr` — 18
  assertions on a `TVirtualTable`, including a change made through a DevExpress
  grid's data controller and a DFM round trip of `AChains`.

- `src/component/Rad.Dev.pas` — **combo lists filled by one event, only when
  needed.** `TRadComboBoxProperties` gains `AEditorId` (a list id the component
  never interprets), `AMasterFields` (the record fields the list depends on,
  `'ulke;sehir'`) and `AOnFill`, plus public `ResetItems` and `FillItems`. When
  the dropdown opens, the component reads the `AMasterFields` values from the
  *asking editor's* record — the form editor's record, or the grid row — and
  calls `AOnFill` with them as same-named `TParams`, but only if they differ
  from the last fill; empty `AMasterFields` means a fixed list filled once. With
  the event on a repository item, one handler in the data module fills every
  list in the application, choosing the query by `AEditorId`. The component runs
  no SQL and holds no connection. Design decisions, made with the user: the SQL
  and a connection property were dropped in favour of the single event; an
  editor button is left to the stock `OnButtonClick` (which fires twice if
  written on both the editor and the repository, `cxEdit.pas:4897-4900`). The
  fill runs in a `DoInitPopup` override, not the published `OnInitPopup`,
  which fires twice with a repository item. A missing field raises `ERadDev`
  naming it; a failing handler leaves the list unfilled so the next opening
  retries. `CascadeWarning` and `RadChainAudit` report `AEditorId` /
  `AMasterFields` without `AOnFill`, and master fields missing from a
  consumer's dataset.
- `src/core/help.Dev.pas` — `_DataSet`, `_Field` and so `_DataSetOf` /
  `_FieldOf` now recognise **every** data-aware editor through its
  `TcxDBEditDataBinding` (the same test `GetcxDBEditDataLink` makes,
  `cxDBEdit.pas:1389`). Only `TcxDBButtonEdit` was recognised before, so a
  `TcxDBComboBox` on a form returned nil.
- `src/test/scratch/rad_dev_repolisteners/ComboFillTest.dpr` — headless, 24
  assertions: parameters from the record, no refill for unchanged values,
  refill on change and after `ResetItems`, a fixed list filled once, one event
  serving two items by `AEditorId`, two consumers of one item each getting
  their own record's list, `ERadDev` for a missing field, retry after a failing
  handler, DFM round trip of the new properties, and the audit messages.
- `src/test/scratch/rad_dev_livedb/ComboFillLiveTest.dpr` — against local
  PostgreSQL, 13 assertions: country → city → district by **name** with one
  handler, on a form and in a grid. It also settled the plan's open question:
  in a grid, a value set in one column of a row reaches the record field at
  once, so the next column's list in the same row already follows it.

- `src/test/scratch/rad_dev_repolisteners/DbNavTest.dpr` — `TRadDBLookupComboBox`
  bound to a record dataset: what record navigation does to a cascade, and what
  happens when `AOnLocate` or `ListSource` is assigned after binding. Headless,
  12 assertions, red-first for both fixes below.
- `src/test/scratch/rad_dev_livedb/DbLookupLiveTest.dpr` — the country → city
  setup recommended to users, against local PostgreSQL: limited server-side
  lists, a `secili_id` parameter keeping the shown key's row in a 15-row list,
  the old city cleared in the record field's `OnChange`, navigation leaving the
  record in browse mode. 11 assertions, Win32 and Win64. It also measured an
  ordering fact worth knowing: a DB editor bound **before** its `AOnLocate` is
  assigned resolves its first text with no handler and caches the empty result;
  in a DFM the events load first, so this bites only code that wires up at run
  time.

- `src/test/scratch/rad_dev_repolisteners/DxAuditTest.dpr` — red-first probe
  for the 2026-09-12 DevExpress audit: `Permission.Edit` lock balance, leak and
  error contract, `help.Dev._Host` outside a grid, `dm.dev` phone validation,
  and pattern-column masters in `Rad.Dev`. Runs headless, 21 assertions.

- `src/test/scratch/rad_dev_repolisteners/PullPopupTest.dpr` — the pull's real
  popup path, which needs a visible window because
  `TcxCustomDropDownEdit.DropDown` returns immediately on an invisible one
  (`cxDropDownEdit.pas:3253`). Nine assertions, green on Win32 and Win64. The
  one that matters is the **ordering proof**: the handler re-filters the list
  at the moment it is called, and after the popup opens that filter is still
  standing with two rows instead of six. Placing the pull before `inherited`
  was until now justified only by reading the vendor source; this measures it.
  Also covers `AFilterOnPopup := False` silencing the automatic path, and a
  grid column as master resolving to the focused row's value with `_Host`
  finding the column.
- `src/test/scratch/rad_dev_repolisteners/DestructorTest.dpr` — the RADDEV-001
  regression, measuring the call order deterministically rather than relying
  on a crash.

- `src/test/scratch/rad_dev_repolisteners/PullTest.dpr` —
  46 assertions covering the new pull direction (event fires exactly once with
  the right source/master/value, re-entrancy guard, `DoAssign` carries the pull
  payload, free-notification nils `AMaster`, `PullWarning` reports each silent
  trap). One assertion is red-first: with the old `DoCascade` gate restored it
  fails, proving the invalidation defect below was real. Green on Win32
  and Win64 (35/35).
- `src/test/scratch/rad_dev_repolisteners/build_and_run.bat` and
  `src/test/scratch/rad_dev_livedb/build_and_run.bat` — these two probe
  directories were the only ones in the kit with no build script, which is a
  large part of why their probes rotted unnoticed. Both take a platform
  argument (`Win32` default, `Win64`) and an optional probe name, and both
  honour `%EXTRAU%` for unit paths this repo does not ship.
- `src/packages/Rad.Editor.pas` — `TRadChainAuditEditor`, a design-time
  component editor registered for `TRadLookupComboBox` and
  `TRadDBLookupComboBox`: right-click → "Zinciri denetle...", which runs
  `RadChainAudit` over the form and shows the result. The runtime one-liner
  covers a developer reading logs; this puts the same answer under the hand of
  whoever is laying the form out, which is where the misconfiguration is
  actually created. It changes nothing, so it does not call
  `Designer.Modified`, and it takes its root from `Owner` rather than the
  `IDesigner` interface — plain VCL, no version surprises.
  **Not compiled here:** `DesignEditors.dcu` is not reachable from this
  toolchain, so this unit is verified by reading only; it builds with the
  package in the IDE.

- `src/component/Rad.Dev.pas` — `AMasterField` and `AAutoFilter`, the pull
  direction's two conveniences. `AMasterField` is the free payload `ACascadeField`
  is for push, and doubles as the parameter/field name the automatic mode uses.
  `AAutoFilter` (`afNone` default, `afParam`, `afFilter`) applies the filter in
  the component for the ordinary "field = master's value" case, so a dependent
  lookup needs no `AOnFilter` at all. Decisions worth knowing: the automatic
  filter runs **before** `AOnFilter`, which still fires and can refine it; an
  empty master **closes** the list dataset, because a city list has no meaning
  before a country is chosen, and closing says that without filter-expression
  tricks; `afFilter` formats integers bare and everything else quoted, so a
  decimal or date master needs `AOnFilter` rather than a silently broken
  expression built with a locale decimal separator. Misconfiguration raises
  `ERadDev` at first popup and is reported by `PullWarning` before that.

- `src/component/Rad.Dev.pas` — `RadChainAudit(ARoot: TComponent): string`
  walks a component tree and collects every `ChainWarning` and `PullWarning`
  it finds, reporting each shared `Properties` instance once. The unit had
  grown three diagnostic queries (`ChainWarning`, `PullWarning`, and the
  settings panel's own `Warnings`) with **no caller anywhere** — a mechanism
  built to surface silent misconfiguration that was itself silent. This stays
  a query rather than an automatic warning, for the reason `ChainWarning`
  already documents: a form mid-DFM-load looks misconfigured for a moment, so
  warning on its own would cry wolf. One `{$IFDEF DEBUG}` line in `FormCreate`
  is now enough to see everything.
- `src/component/Rad.Dev.pas` — `ERadDev`, the unit's first exception class.

### Changed

- `src/component/rad.dev.pas` — **`TRadCheckComboBox` / `TRadCheckListBox`: değer artık
  item'ın kendisinde.** `AValueItems` ('Ad=Değer' listesi, `Items`'ı yeniden kuran ve DFM'e
  yazmayan model) kaldırıldı; tasarımcıda yazılan başlıklar siliniyor, ekranda `t`/`f`
  görünüyordu (ERPPlus `dm.erp.dfm` `Stil_CheckCombo_AktifPasif`). Yeni: `TRadCheckComboBoxItem`
  (`TcxCheckComboBoxItem` + published `Value`) ve `TRadCheckComboBoxItems`; properties'teki
  published `Items` **tabanın `Items`'ını gölgeler** (RTTI ve DFM yalnız bizimkini görür,
  sonda ile doğrulandı) ve tabanın koleksiyonuna indeks bazlı tek yön aynalanır (taban
  private alanla sabit sınıfta kurduğu için, `cxCheckComboBox.pas:1168`). `Value` boşsa değer
  = `Description`; hiçbir item'da `Value` yoksa stok davranış. `Items.AddItem(ad, değer)`,
  `IndexOfValue`, `HasValues`. CheckListBox'ta aynı kalıp: `TRadCheckListBoxItem`
  (`Text`, `Value`, `Enabled`, `ImageIndex`, `Tag`; `State` stok item'da kalır, aynalama
  seçimi bozmaz). `TRadValueList` artık sahipten gelen `Count/Names/Values` callback'leriyle
  çalışır. Testler: `CheckComboTest` 43, `RadCheckListTest` 31, `RadFamiliesTest` 55
  (Win32+Win64), `RadCheckListLiveTest` 12. ERPPlus: `k.kullanicisirket.pas` iki çağrı
  `Items.AddItem`'a, `dm.erp.dfm` item'lara `Value` yazıldı. **Kırıcı:** eski `AValueItems`
  içeren DFM okunamaz (beta, kabul edildi); IDE'deki `RadKon.bpl` yeniden kurulmalı.
- `.agents/rules/delphi-conventions.md`, `.agents/rules/component-patterns.md` —
  two new rules: comments stay short and meaningful (history and measurements
  go to CHANGELOG, commit messages or tests); new components are registered in
  `Rad.Register.pas` and design-time code lives in `Rad.Editor.pas`.
- `src/test/scratch/rad_dev_repolisteners/build_and_run.bat`,
  `src/test/scratch/rad_dev_livedb/build_and_run.bat` — honour `%EXTRAI%` as an
  include path. This is what lets the probes build against the **real** JEDI
  JCL source (its `jcl.inc` is not searched on the unit path) instead of
  hand-written stubs; every probe in both directories now builds and passes
  that way on Win32 and Win64, with Dext at revision `c8c980d2`.

- `src/test/scratch/rad_dev_repolisteners/*.dpr`,
  `src/test/scratch/rad_dev_livedb/LiveLookupTest.dpr` — every probe now
  asserts and exits non-zero on failure instead of printing its expectations
  as prose (RADDEV-008). Writing the assertions immediately exposed **three
  dead measurements** that had been passing by printing: `LiveLookupTest` M1
  searched two characters and M5 searched one, both against the default
  `AMinSearchLength` of 3, so no query ever ran; and `RuntimeTest`'s
  zero-delay case has never produced a search, because that path needs a key
  delivered to a real windowed edit and the probe calls `DoEditKeyPress`
  directly. The first two are fixed; the third is now reported as `[ATLA]` —
  a third outcome, counted separately, never silent, never a false green.

- `src/test/scratch/rad_dev_livedb/LiveLookupTest.dpr` — M5b and M6-M9 measure
  the composition against local PostgreSQL: one query per dropdown opening
  with both parameters set, the master parameter surviving the search's own
  reopen, the search text cleared when the master changes, and a 40-row
  country returning the SQL's 15. M5b measures the hazard the header warns
  about — a handler that reassigns `SQL.Text` destroys the master parameter,
  because the collection is rebuilt from the new text.

- `src/component/Rad.Dev.pas` — `AMaster` now rejects anything that is not a
  `TcxCustomEdit` or a `TcxCustomGridTableItem`. The Object Inspector's
  component dropdown offers every component on the form, and `_ValueOf` reads
  only those two kinds — so picking, say, a button handed `AOnFilter` a `Null`
  master value on every call, producing an empty list with no exception and no
  warning. The symptom ("it behaves as if no country is selected") pointed
  nowhere near the cause. It now raises at assignment time, i.e. in the
  designer.

- `src/component/Rad.Dev.pas` — `DoFilter` counts the times it skips because
  the list dataset was busy, and `PullWarning` reports the count. Skipping is
  correct (it breaks recursion) but its consequence was invisible: the dropdown
  opened showing an unfiltered list and nothing said so.

- `src/component/Rad.Dev.pas` — file encoding repaired. It was UTF-8 except for
  three stray cp1254 bytes (`Oluştur`, in the header comment), which made it
  invalid UTF-8 as a whole: `file` reported "Non-ISO extended-ASCII" and any
  UTF-8 tool either failed on those lines or corrupted them. Converted, and a
  BOM added per this kit's `delphi-encoding` rule.

- `src/component/Rad.Dev.pas` — **the cascade's main direction is inverted.**
  A dependent lookup now declares its own master (`AMaster`) and filters its own
  list when its dropdown opens (`AOnFilter`), instead of the source pushing a
  filter into up to four target slots. The dependent knows what it depends on,
  the way a foreign key does; adding one no longer means editing the source, and
  the query runs only when someone actually opens the list — a four-deep chain
  used to fire three queries nobody was looking at.

  Push is kept, deliberately, but reduced to an **invalidation signal**: pure
  pull cannot fix a stale value, because if nobody ever opens the dependent's
  dropdown nothing pulls, and an inconsistent key reaches the database still
  displaying its old text. `AOnCascade` is not deprecated — it still has jobs
  pull cannot do (refreshing a target that has no popup at all).

  The pull fires from a `DoInitPopup` override on `TRadCustomLookupComboBox`,
  before `inherited`. Measured from the vendor source: `DoInitPopup` runs at
  `cxDropDownEdit.pas:3256`, its `OnInitPopup` calls at `:3150`, and
  `ILookupData.DropDown` only at `:3159` — so a filter applied there affects
  *this* opening, and it lands before `Properties.LockDataChanged`
  (`cxLookupEdit.pas:309`) would have suppressed it. The published
  `OnInitPopup` event was rejected for the seam: it belongs to the application,
  and `DoInitPopup` fires it **twice** when a repository item is present
  (`:3150` and `:3152`) — two filter queries per popup, silently.

- `src/component/Rad.Dev.pas` — `FilterNow` added next to `CascadeNow`. Not
  symmetry for its own sake: `TcxCustomDropDownEdit.DropDown` begins with
  `if not IsWindowVisible(Handle) then Exit` (`cxDropDownEdit.pas:3253`), so
  `DoInitPopup` never runs in an invisible window and the pull path would
  otherwise be unmeasurable without a visible form.

- `src/component/Rad.Dev.pas` — `ResetLocateCache` was only clearing the kit's
  own resolved-key cache. DevExpress keeps a second one, `FLookupList`
  (`cxDBLookupEdit.pas:71`), which `GetDisplayLookupText` both reads and writes
  in its `GridMode` branch — and which closing and reopening the list dataset
  does **not** clear; only `CheckLookupList` (`:419-425`) does. A target whose
  list had just been re-filtered therefore kept showing the old text. New
  `ResetDisplayCache` / `ResetCaches` clear both layers, and every place that
  invalidates a target now uses `ResetCaches`.

- `docs/olcum-listesi.md` — Ö-02 largely closed (all six cascade probes now
  compile on Win32 **and** Win64, four of them running green on both), and Ö-11 /
  Ö-12 added for the pull measurements that need a visible window and a live
  database. Also records that today's runs used **stub units** for `JclBase`,
  `JclSysInfo` and `Dext.Types.UUID`, none of which exist on this machine.

### Fixed

- `src/component/rad.dev.pas` — **Paylaşılan `RepositoryItem` varken tüketicinin kendi
  `Control1..4` zinciri yok sayılıyordu.** Kaskad `ActiveProperties` (item'in) yuvalarından
  okunuyordu; başlık yorumu "zincir yuvaları tüketicinin kendi Properties'inde" diyordu,
  kod diyordu ki item'in. Artık tüketicinin kendi `RadSetting.Controls` zinciri doluysa
  o kazanır, boşsa item'inki (eski davranış). `DoCascade`'e `AChain` parametresi eklendi.
  Testler: `RadSettingTest` R18/R19 (düzeltmeden önce kırmızıydı).
- `src/core/rad.config.pas` — **`TRadConfig` is now a `TSynAutoCreateFields`
  (no interface counting), and its open defects are fixed.** (1) The class
  used to be `TInterfacedObject`: `Ayar := TConfigGenel.Create` followed by a
  chained `SetV` freed the object through the temporary interface. (2) A file
  that fails to load no longer gets overwritten with defaults by `Destroy`: the
  save is disabled and `ERadConfig` is raised (empty files still open). (3)
  `Get` has no default arguments and gains `Integer`/`Boolean` overloads; the
  `TDateTime` one is now `GetDateTime` (a float literal was ambiguous between
  `Double` and `TDateTime`, E2251) — **breaking** for `Get(key, <TDateTime>)`
  callers (none in this repo). (4) `SaveIfNeeded` takes the write lock;
  `SetJson` returns `Self`; `TRadConfig.Config` is freed at
  finalization. `Destroy` no longer saves (`SaveIfNeeded` is explicit; ConfigTest 14, 20). `Json` is a snapshot, writes to it are lost (XMLDoc says so).
  `Root` is published, free keys live under `"Root"` in the file. Tests:
  `src/test/scratch/rad_config` (19 assertions, Win32 and Win64).
- `src/core/Help.vcl.pas` — **`TRadFormBase.ShowInTabs` was `False` for every
  form loaded from a DFM.** `TCustomForm.Create` does not call `CreateNew`, and
  the default was set there, so a form made by `Application.CreateForm` or
  `Create` never got it and `TRadFormTabs` skipped it (no tabs in ERPPlus). The
  stored field is now inverted (`FHideFromTabs`), so zero-init means `True` on
  both creation paths; the `CreateNew` override is gone. Tests:
  `rad_formtabs` 51-55.
- `src/component/Permission.Edit.pas` — **`TRadPermission.SaveToField` never
  committed to the database.** It put the dataset in edit mode and filled the
  field, then called `TcxDBDataBinding.UpdateDataSource`, which only runs
  `TDataLink.UpdateRecord` (`cxDB.pas`, `Data.DB.pas`) and does not `Post`, so
  the record stayed in `dsEdit` and the value was lost. It now posts when it
  opened the edit itself, cancels the edit if `Post` raises (no dangling
  `dsEdit`, the original exception propagates), and raises `ERadPermission`
  when the field cannot be edited. A dataset the caller already put in edit
  mode is still left for the caller to post. Red before, green after in
  `rad_permission` 07-09 and 13-15.
- `src/component/Permission.Edit.pas` — **Ctrl+Down inserted the new node
  above the focused one.** The `act_ins` shortcut called the navigator's
  `Insert`, which attaches before the focused node (`cxTL.pas`, `NBDI_INSERT`
  → `tlamInsert`). New `TcxTreeListHack.InsertAfter` adds it directly after the
  focused node at the same level (as the last child when there is no next
  sibling). The action is now captioned "Alta Ekle" in `Permission.Edit.dfm`.
  Red before, green after in `rad_permission` 29-37.
- `src/test/scratch/rad_permission/PermissionTest.dpr` — rewritten for the
  current `DataBinding` API (it targeted the removed `DataSet`/`TreeField`
  properties and UniDAC's `VirtualTable`, so it no longer compiled and could
  not have caught either bug above). Uses FireDAC `TFDMemTable`; 57 assertions,
  Win32 and Win64 (37 for the two fixes, 20 for the template work below).
- `src/component/Rad.Dev.pas` — **a lookup wired up in code after its data was
  bound stayed blank.** The first text is resolved the moment the editor is
  bound; if `AOnLocate` or `ListSource` arrived afterwards, that first answer
  was an empty string, and the kit's text cache kept serving it. Any
  `Properties` change now clears the kit's cache (a `DoChanged` override), and
  `AOnLocate` got a setter that signals the change. Red before, green after in
  `DbNavTest` S01/S03. The grid-painting saving is unaffected — the locate
  handler runs under `LockUpdate`, and a change while locked never reaches
  `DoChanged` (`cxEdit.pas:11128`); `LiveLookupTest` M4 still resolves the same
  key 50 times with zero handler calls.

- `src/component/Rad.Dev.pas` — **on a DB form, moving to another record
  blanked the dependent editor.** A `TRadDBLookupComboBox` re-assigns its
  `EditValue` from the field on every record change (`cxDBEdit.pas:2279`),
  which reaches `DoEditValueChanged` (`cxEdit.pas:5706-5708`) and so the
  cascade — there was no way to tell navigation from an edit. With
  `AClearTargetsOnCascade` the cascade could run *after* the dependent editor
  had already refreshed itself, leaving it empty while the record still held a
  city (measured, `DbNavTest` D01). The DB editor now uses its own data binding
  that marks `DataChanged`; a data-driven change still invalidates the target
  (cache reset and `AOnCascade` still run, because the target's list was
  filtered for the old master) but no longer clears its value. A change made
  in code or by the user clears as before. Nothing was written to the record
  in either version. `DoCascade` gained an optional `AFromData` parameter.
- `src/component/Rad.Dev.pas`, `CHANGELOG.md` — three DevExpress source
  citations re-checked against the installed 26.1.4 and corrected:
  `cxDropDownEdit.pas:3253` (was cited as 3252), `cxGridCustomTableView.pas:3407`
  (was 3406), and `GetFreeNotificator` at `cxEdit.pas:1375` (was 1639).

- **DevExpress audit (2026-09-12), each reproduced red before fixing and green
  after in `src/test/scratch/rad_dev_repolisteners/DxAuditTest.dpr` (new, 21
  assertions, Win32 + Win64).** Behavior was checked against the DevExpress
  documentation MCP and the installed 26.1.3 source.
  - `src/share/dm.dev.pas` / `.dfm` — **every phone number was rejected.**
    `Edit_tel`'s `OnValidate` set `Error := True` unconditionally, and the
    default `ValidationOptions` is `[evoRaiseException]` (`cxEdit.pas:1521`),
    so a valid number raised an exception whose message was the number
    itself. The handler is removed; the mask still rejects an incomplete
    number on its own (measured).
  - `src/component/Permission.Edit.pas` — `Fix` opened its block with
    `BeforeUpdate`, which is a `CheckChanges` hook, not a lock
    (`cxTL.pas:16496`), and closed it with `EndUpdate`. The lock counter went
    to **-1**, so every later balanced Begin/End pair left the tree unlocked.
    Now `BeginUpdate`.
  - `src/component/Permission.Edit.pas` — `TRadPermission` never freed its
    `TcxDBDataBinding` (a `TPersistent` with no owner). Each instance leaked
    the binding and its `TDataLink` — 56,000 bytes over 500 create/free
    cycles — and left the link registered with the `DataSource`. A destructor
    now frees it.
  - `src/component/Permission.Edit.pas` — `SaveToField` with no `DataSource`
    raised an access violation while building its own error message. It now
    raises `ERadPermission` with the unit's existing resourcestrings (they were
    declared but unused), and **an empty dataset is now refused** instead of
    letting `TDataSet.Edit` silently insert a new row. `ReLoad` no longer
    dereferences a nil document.
  - `src/core/help.Dev.pas` — `_GridItem` (and therefore `_Host`,
    `_CaptionOf`, `_DataSet`) raised an access violation for an editor with no
    `Parent`, and for **any** editor on an ordinary `TdxLayoutControl`: it
    treated every layout control as the grid's detached edit form and cast the
    editor's `Tag` to a layout item. It now checks that the editor's form really
    is a `TcxGridCustomDetachedEditForm`. Dead code after `Exit` and a `with`
    were removed.
  - `src/component/Rad.Dev.pas` — `PullWarning` (and so `RadChainAudit`) now
    reports an `AMaster` that is a **detail-level (pattern) column**. Its value
    can never be read — it is always `Unassigned` (measured) — so the list
    always opened against an empty master, silently. Two comments that said a
    column with no focused record yields `Null` were corrected: it yields
    `Unassigned` (`cxGridCustomTableView.pas:13724`). The code already handled
    both.
  - `src/share/Kisayol.Edit.pas` — `TableAct`'s columns were used to index
    `TableGlobal`'s records, which only worked while both views kept the same
    column order. Each view now uses its own columns, update blocks are in
    `try..finally`, the style handler tolerates an empty value, and a `with` was
    removed. **Not compiled.** *Correction (2026-09-13):* this entry first said
    the unit could not compile because `rad.rtl` does not exist in this
    repository. That was wrong — `src/component/rad.rtl.pas` is tracked and in
    the package; only `src/core` had been searched. The real missing piece
    was the JVCL (`JvHotKey`) path. With the machine's JVCL
    (`E:\system\dev\Delphi\component\2026.6.6\jvcl`) the unit now compiles
    and links (one pre-existing hint: the unused global `Kisayol_Edit`). Its
    behaviour at run time has not been exercised.
  - `src/packages/Rad.Editor.pas` — a debugging `ShowMessage` was left on the
    navigator editor's live path, followed by dead code that cast
    `TcxControlNavigator` to the unrelated `TcxGridViewNavigator`. The editor
    now checks the type, applies the change and calls `Modified`. **Not
    compiled:** `DesignEditors.dcu` is unavailable here.
  - `src/share/k.setting.pas` — the frame now detaches its grid, search and
    NavBar handlers before freeing the lookup tables they use. This is a
    defensive change: whether an event actually fires during destruction was
    not measured.

- `src/component/Rad.Dev.pas` — **a repository item deleted while consumers
  were still attached raised an access violation, every time.** The destructor
  freed its consumer list before calling `inherited`, and
  `TcxEditRepositoryItem.Destroy` removes its listeners through a *virtual*
  `RemoveListener` (`cxEdit.pas:6745-6755`, `:260`) — which lands back in the
  override that touches the list just freed. Deleting an item in the designer
  while columns still reference it is enough. The list is now freed after
  `inherited`, and every reader tolerates nil. Reported by Codex as
  RADDEV-001; reproduced before fixing, green after (`DestructorTest.dpr`).

- `src/component/Rad.Dev.pas` — `TRadEditSlots.Get`/`Put` did no bounds
  checking while the package compiles with `{$RANGECHECKS OFF}`
  (`RadKon.dpk:17`), so `Get(0)` read and `Put(5, X)` **wrote** outside the
  array, silently. Measured, then guarded with `ERadDev` (RADDEV-006).

- `src/component/Rad.Dev.pas` — `DoSearch` cleared its caches outside the
  `try/finally`, so a search handler that raised left a stale resolved key
  behind; measured as `AOnLocate` failing to re-fire for a key whose list had
  just changed (RADDEV-004). And `Leave` now sits in its own innermost
  `finally` in both `DoSearch` and `DoFilter`: if `ResetCaches` itself raised
  — it calls into vendor code — the dataset stayed permanently busy and every
  later search and filter was swallowed in silence (RADDEV-003).

- `src/component/Rad.Dev.pas` — the resolved-key and display-text caches are
  now disabled when Properties is owned by a repository item with more than
  one consumer. The kit's own documented pattern (one handler, shared item, a
  type per consumer) makes the same key mean different records for different
  consumers, and the shared cache served the first consumer's answer to the
  second. Per-consumer caching is impossible — the paint path has no consumer
  — so the cache is switched off exactly where identity is ambiguous, and kept
  everywhere else (RADDEV-002).

- `src/test/scratch/rad_dev_repolisteners/RuntimeTest.dpr` — the probe passed a
  `for..in` loop variable straight into `DoEditKeyPress(var Key: Char)` (W1015,
  twice). A key-press handler is allowed to rewrite the key — swallowing it is
  `Key := #0` — so this wrote back into a loop variable the compiler may keep in
  a register. Copies into a local now. Also an unused variable (H2164). The
  probe directory is now diagnostic-free on both platforms.

- `src/component/Rad.Dev.pas` — `RadChainAudit` looked only at each consumer's
  *active* Properties, so it missed a master set on a consumer's **own**
  Properties while a shared `RepositoryItem` was bound. That is precisely the
  layout `ChainWarning` tells you to adopt, and the kit's own `PerConsumerTest`
  measures — the audit could not check the configuration it recommends. It now
  inspects own and active, deduplicating by instance. `PullTest` T13 was
  verified red before the fix.

- `src/component/Rad.Dev.pas` — `DoFilter` cleared its caches *after* the
  try/finally, so a handler that raised part-way through reopening the list left
  the list changed and both caches stale, and the editor went on rendering the
  old text. Moved into `finally`. The same block also broke the unit's own
  `Enter`-immediately-before-`try` discipline (which `DoLocate` and `DoSearch`
  follow); an assignment sat between them.

- `src/component/Rad.Dev.pas` — `AMaster` accepted a circular assignment: an
  editor as its own master, or — with a shared `RepositoryItem` — a master that
  is another consumer of the very Properties being configured, since one
  `AMaster` field serves them all. `FFiltering` stopped it recursing, so it
  produced no crash, just a list silently filtered by its own value. Now raises
  `ERadDev`.

- `src/component/Rad.Dev.pas` — `RadChainAudit`'s header printed an empty name
  for a root created in code; falls back to the class name.

- `src/component/Rad.Dev.pas` — `DoCascade` exited early when no `AOnCascade`
  handler was assigned, which also killed the target invalidation that runs
  alongside it. Harmless while every cascade had a handler; a silent
  data-integrity bug the moment pull makes an unassigned `AOnCascade` the norm —
  the master changed, the target kept its now-invalid key **and** its stale
  display text, and nothing warned. The gate is now "is there any target",
  the event call is conditional, and `PullTest` asserts it (red-first verified).
  Both families fixed; `TRadComboBoxProperties.CascadeOne` additionally never
  invalidated its targets' caches at all.

### Added

- `src/share/k.setting.pas` + `src/share/k.setting.dfm` — the searchable
  settings panel. `TdxNavBar` on the left (group = category, item = sub-group),
  one `TcxVerticalGrid` holding **every** setting on the right, a search box on
  top, and a Delphi-Object-Inspector-style description strip below it. Values
  live in an `IDocDict` with `PathDelim` set to `'.'`, keyed by the full dotted
  path (`fatura.satis.vade_asim_uyar`); the grid row is only the view. A
  setting class is a `TRadOptions` descendant whose published properties are
  the settings and whose nested published `TRadSetting` fields become
  sub-categories — `TSynAutoCreateFields` already creates, owns and serializes
  that tree, so it is not declared a second time anywhere. Registration and
  presentation come from one fluent chain (`AddMenu` / `AddSubMenu` /
  `Register` / `Title` / `Repository` / `Choices` / …); `Register` builds a row
  for every published property on its own, so the chain only names the ones
  that differ from the default. Rows are created once and filtered by
  `Visible`, which is what lets search span categories.
- `src/test/scratch/rad_setting/` — the panel's probe: `SettingTest.dpr`,
  `SettingModel.pas` (the test setting classes, deliberately in their own unit
  rather than the `.dpr`), `build_and_run.bat` (takes `Win32`/`Win64`).
  52 assertions, green on both platforms: key generation, the `default`
  directive read back through RTTI, the JSON actually being a tree, unknown
  keys surviving a load/save round trip, duplicate/missing `index` raising,
  search crossing category boundaries, and the property accessors reaching the
  store in both directions.

- `.agents/skills/rad-code-fix/` — bundled copy of the workspace's own
  `rad-code-fix` skill: `SKILL.md`, `agents/openai.yaml`,
  `references/finding-taxonomy.md`, `references/probe-patterns.md`,
  `references/toolchain-map.md`. Language- and toolchain-agnostic whole-file
  code auditing — it measures a baseline before changing anything, reports
  findings with evidence, applies approved repairs leaf-first from a dependency
  DAG, implements requested enhancements against acceptance criteria, and
  applies a findings report written elsewhere by re-verifying every entry
  against the code as it stands now rather than trusting it. Now part of the workspace's default skill
  bundle.

- `.agents/skills/mormot2-integration/references/verified-api-traps.md` — mORMot2
  APIs that compile cleanly and fail **silently** at runtime, each entry proven
  by a probe rather than a read-through. First entries: `AesPkcs7` does not
  store a GCM authentication tag even when passed `mGcm` (tamper detection
  silently absent — use `TAesGcm.MacAndCrypt`), its password overload derives
  the IV from the password so repeated saves reuse the keystream, `TAesGcm`
  instances are stateful and not thread-safe, and `mormot.crypt.core` needs
  the separately-downloaded `static/` binaries. `SKILL.md` now points at it and
  instructs adding to it whenever a probe uncovers another one.
- `src/core/rad.cipher.pas` — the encryption layer: `IRadCipher` (bytes in,
  bytes out — no base64, envelope or file-format concerns) and
  `TRadAesGcmCipher` over `TAesGcm.MacAndCrypt` with a random IV per call.
  Documented honestly as **at-rest obfuscation** rather than encryption,
  because the design brief embeds the key in the application: it protects the
  file from anyone who sees the file but not the binary, and nothing more.

### Changed

- `.agents/skills/mormot2-integration/references/verified-api-traps.md` — eight
  more measured traps, taking the file from four entries to twelve. Six come
  from the JSON-layer work and were sitting uncommitted: `DocDict`/`DocList`
  accept invalid JSON silently, `DocDict()` erases the real `Kind`,
  `FlattenFromNestedObjects` does not add the counter it promises,
  `AddOrUpdateObject(..., RecursiveUpdate := True)` corrupts the target,
  `TDocVariantData` is not thread-safe and `IDocDict` cannot be subclassed, and
  a nested `IDocDict` dangles after **one** insertion into its parent. Two are
  new, found while building the settings panel: `mormot.core.base` brings
  `RawUtf8` overloads of `LowerCase`, `Pos` and `Trim` that shadow the RTL
  ones, so unqualified calls on `string` silently round-trip through UTF-8 —
  seven occurrences in one unit that never mentions `RawUtf8`, reported only as
  W1057 warnings a hidden-warning build would drop; and `IDocDict.PathDelim`
  defaults to `#0`, so dotted keys are written as one flat key and no JSON tree
  is ever built. Measured both ways; neither raises.

- `src/core/rad.core.pas` - `TAbstractLockable` routes every lock method through
  a now-**virtual** `GetSafe`, so a descendant that shares another object's data
  can redirect to that object's lock. Without it, an object holding a view over
  another object's structure would guard that structure with a second, private
  lock - two locks, one structure, and writers that never see each other.
  Classes that do not share data are unaffected.
- `src/core/help.mormot.pas` - the flatten failure is `EMormotFlatten`, not the
  shorter `EJsonFlatten`. The short name collided with an identically named
  exception in another unit, so `on E: EJsonFlatten` in any unit that used both
  resolved by `uses` order - silently, with no diagnostic.

- `src/core/rad.config.pas` — encryption now has three modes, chosen with a new
  `TRadCryptMode` constructor argument. `rcmFile` (the default) wraps the whole
  document; **`rcmSection` encrypts only sections whose new virtual
  `TRadOptions.Encrypted` class function returns True**, leaving the rest of the
  file readable and the section names visible — an encrypted section's value
  becomes the single string `RADSEC1:aes-gcm-256:<base64url>` (in INI, a one-key
  `enc=` block). The payload is always the section's JSON, so all three file
  formats share one decrypt path. `rcmNone` is forced whenever no cipher is
  supplied, so a file can never claim encryption it is not doing.
- `TRadOptionsFile` now hashes **its own plaintext serialization** on both save
  and load, instead of the file text. Two bugs made this necessary: a
  section-encrypted document contains a marker that changes every save (random
  IV), so it could never hash equal; and hashing the file text meant any
  formatting difference between disk and our serializer triggered a pointless
  write after every load. Both sides now measure the same deterministic thing.
- `tools/verify-kit.ps1` no longer fails on its own documentation. Excluding the
  script by name was not enough — any file describing the placeholder check
  contains the literal marker, so `docs/proje-haritasi.md` and `CHANGELOG.md`
  were reported as holding unfilled placeholders. Prose writes the marker
  backticked; a real placeholder never is, so only the backticked form is
  excluded. A gate that fails on its own docs teaches people to ignore it.
- **The "dependency-free core" claim is gone — it was false.** `.agents/rules/vendor-integration.md`
  now states two tiers: mORMot2 is a **base dependency** that `src/core/` calls
  directly with no adapter, while UniDAC, DevExpress, TMS, FastReport and JEDI
  remain optional and isolated under `src/vendor/`. The old wording contradicted
  every core unit that ships (`rad.core`, `rad.cipher`, `rad.config`,
  `rad.cache`, `rad.utils`, `rad.thread`, `rad.eventbus` all `uses` mORMot), and
  a rule that contradicts the code teaches the next session either to break
  working code enforcing it or to stop trusting the rules. Corrected in the same
  pass across `library-packaging.md`, `component-patterns.md`, the four identity
  files (`AGENTS.md`, `.claude/CLAUDE.md`, `.github/copilot-instructions.md`,
  `.gemini/rules/project-rules.md`), `.kiro/steering/product.md`, `src/README.md`,
  `ACKNOWLEDGMENTS.md` and five vendor skills. Earlier CHANGELOG entries citing
  the old rule are left as-is: they record what was believed at the time.
- `.agents/rules/delphi-conventions.md` gained two compile-verified traps: set
  constructors cannot hold an element above 255 (`in [128, 192, 256]` is
  `E1012`, and the message points at the whole expression rather than the
  offending member), and an identifier shadowing a same-named routine
  case-insensitively (a local `c` hides a procedure `C`, and the compiler
  reports a missing semicolon that is not there).
- `src/core/rad.config.pas` — optional whole-file encryption. Passing an
  `IRadCipher` to the constructor wraps the entire serialized document in a
  single `data.enc` envelope (base64url, plus `alg` and `v`), so section names
  are hidden too and per-section encryption is unnecessary. The file stays
  valid in its own format and keeps its extension. Also drops this unit's
  duplicate `ERadCore` in favour of `rad.core`'s, so one `except on E: ERadCore`
  really does catch the whole tree.

### Removed

- `src/rad.json.pas` - the JSON abstraction layer is withdrawn. It was an
  interface tree (`IJson`/`IJsonArray`) with a runtime provider-registration
  mechanism over a single implementation, and the abstraction earned nothing:
  there was never a second provider, while a caller who forgot the provider
  unit still compiled and failed only at runtime. `rad.config` now uses
  mORMot's `IDocDict` directly.
- `src/core/rad.cache - Kopya.pas` — an 829-line stray copy of
  `src/core/rad.cache.pas` sitting in the same folder. Two units declaring the
  same symbols in one compilation shadow each other by `uses` order, which is
  exactly the defect that had to be removed from `rad.pas` in this same
  release. Recoverable from git history if it turns out to have been wanted.

### Added

- `TSmartCache` (and `ISmartCache`) gained JSON persistence: `SaveJson`,
  `LoadJson`, `SaveToFile`, `LoadFromFile`. The format is a versioned envelope
  that stores an explicit **type tag** per entry, because this cache is
  type-strict on read — writing `Integer 42` and reading it back as `Int64`
  would make `Get<Integer>` silently return the default. Values that cannot
  round-trip (objects, interfaces, records, arrays, sets, non-Boolean enums)
  are skipped and reported through `SaveJson(out ASkipped)` rather than being
  written as garbage; `TObject` in particular is a raw unowned pointer here, so
  persisting it would be meaningless. `LoadJson` parses in full before touching
  the dictionary, so a malformed document leaves the cache unchanged, and
  `SaveToFile` writes to a temp file and moves it over the target
  (`MoveFileEx`/rename) so a crash mid-write cannot destroy the previous state.
  Persistence uses RTL `System.JSON`, not `rad.json` — the cache must not
  require a JSON provider to be registered.
- `rad.json` gained fluent writers (`SetV` overloads plus `SetVar`), fluent
  `Add` on `IJsonArray`, `Get(AKey, ADefault)` readers, ISO-8601
  `GetDateTime`/`SetDateTime`, and object/record conversion
  (`FromObject`/`ToObject`/`FromRecord`/`ToRecord` with the `TJsonRec.Save`/
  `Load` generic wrapper, since Delphi interfaces cannot carry generic methods).
  `TDateTime` deliberately stays out of the overload sets: it shares `Double`'s
  representation and would make numeric literals ambiguous.
- `src/vendor/rad.json.mormot2.pas` — the first implementation of the
  `rad.json` contract, built on mORMot2 `IDocDict`/`IDocList`. Registers itself
  from `initialization`, so adding the unit to `uses` is the whole setup. It
  lives under `src/vendor/` because `vendor-integration.md` keeps the core
  dependency-free: `rad.json` still knows nothing about mORMot.
- `rad.json` gained a real error contract (`EJson` and four descendants),
  provider registration (`RegisterJsonProvider` / `UnregisterJsonProvider` /
  `IsJsonProviderRegistered`) replacing the two global factory variables, and
  `GetDef` overloads on `IJsonArray` plus the missing `Currency` one on `IJson`.
  Its interface GUIDs were regenerated — the previous pair was hand-written and
  one of them was not a valid RFC 4122 variant.
- `GenerateFluentUnit`, `ListFluentRegions` and `PruneFluentRegions` in
  `src/core/rad.utils.pas`. `GenerateFluentUnit` writes a compile-ready unit to
  disk (UTF-8 + BOM) instead of returning a fragment to paste by hand: it
  resolves `uses` from RTTI `QualifiedName`, wraps everything in
  `{$REGION 'RAD-FLUENT:<Class>:TYPES|IMPL'}` markers, and in `fumMergeRegions`
  mode updates only its own regions so one unit can carry several classes
  alongside hand-written code. Re-runs reuse the GUID already in the file, so
  the operation is idempotent. `PruneFluentRegions` removes orphaned regions
  (dry-run by default) — nothing else in the kit could detect them.
- `.agents/rules/delphi-conventions.md` gained two sections, "RTTI blind spots"
  and "Unit name qualification in generated `uses`". Both document defects that
  were found by compiling and running probe programs, not by reading docs, and
  both silently corrupt any RTTI-driven generator/serializer/mapper.

### Fixed

- **`GenerateFluentCode` silently omitted properties, and silently emitted
  wrong method signatures.** Delphi produces no RTTI for enumerations with
  explicitly assigned values (`TAESKeyLength = (kl128 = 128, ...)`), so such a
  published property is invisible at runtime — confirmed by execution on Delphi
  37.0. The generator now accepts the declaring `.pas` path, reconciles the
  source against what RTTI reports, emits the missing members marked
  `// [KAYNAK]`, and refuses to emit a method whose RTTI signature is provably
  wrong (a lost parameter, or a function degraded to `mkProcedure`) instead of
  producing code that fails to compile or drops a return value.
- **Untyped parameters crashed the generator.** `TRttiParameter.ParamType` is
  `nil` for `var Buf`; the old code dereferenced `.Name` unconditionally.
- **Open-array parameters produced a wrong signature.** `pfArray` was ignored,
  so `const A: array of Integer` was emitted as `const A: Integer`.
- **Generated `uses` could not compile against legacy sources.** RTTI reports
  `System.Classes` while an older unit's own `uses` says `Classes`; both in one
  clause is `E2004`. Bare and namespace-qualified forms of the standard RTL
  roots are now collapsed to one entry.
- `src/core/rad.pas` no longer carries a byte-identical duplicate of
  `GenerateFluentCode` (~350 lines). Two units exporting the same function meant
  `uses` order silently decided which one a project got. `rad.utils.pas` is the
  single source; `rad.pas` keeps a pointer comment.

- **Claude Code could not discover any of this kit's skills.** It looks only
  under `.claude/skills/`; `.agents/skills/` is not one of its discovery
  locations, so every skill here was unreachable by trigger matching and only
  worked if the user typed the generated `/<skill-name>` wrapper by hand.
  `tools/generate-ai-configs.ps1` now creates one junction (Windows, no
  elevation needed) / symlink per skill under `.claude/skills/`, pointing back
  at `.agents/skills/`. The links are gitignored and regenerated after a clone,
  so the "symlink degrades on clone" hazard that keeps rules as copies does not
  apply. Verified against `code.claude.com/docs/en/skills`.
- **Cursor ignored every rule in this kit.** `.cursor/rules/` held `.md` files;
  Cursor recognizes only `.mdc` there and silently skips anything else. The
  frontmatter was already correct — only the extension was wrong. The generator
  now writes `.mdc` and sweeps the old `.md` copies instead of leaving both.
  Verified against `cursor.com/docs/rules`.
- **Gemini CLI read nothing.** The AI-tool table pointed it at
  `.gemini/rules/project-rules.md`, but Gemini CLI builds context from the
  `GEMINI.md` hierarchy. Added a root `GEMINI.md` that imports that file rather
  than duplicating it. Verified against `geminicli.com/docs/cli/gemini-md`.
- **`.claude/settings.json` used invented keys.** `allowCommands`/`denyPaths`
  are not Claude Code settings, so the advertised `.env`/`.key` protection and
  the pre-approved generator command never existed. Rewritten to the real
  `permissions.allow`/`permissions.deny` schema.
- Corrected the false claim, repeated across this kit's rules, `AGENTS.md`,
  `docs/ai-ignore-strategy.md`, the READMEs and the generator itself, that
  `.agents/skills/` "is read as a fallback location natively by every supported
  tool." It is not, and that assumption is what left the skills unreachable.
- Fixed the mutually broken links between `prompt-engineer-analyst.md` and
  `design/prompt-patterns.md` in the bundled `rad-prompt-studio`.

### Added

- `.agents/rules/analysis-output.md` — the input-resolution and output-naming
  rule the three bundled `rad-prompt-studio` master prompts reference but which
  was not present in this kit, leaving them unable to resolve a report path.
- `tools/verify-kit.ps1` and `.github/workflows/verify.yml` — a mechanical
  consistency gate (generator drift, Cursor extension, skill-link presence,
  `SKILL.md` frontmatter, `[FILL IN` residue, README image links, `LICENSE`),
  runnable locally as `pwsh tools/verify-kit.ps1` and in CI from one script.

## [0.1.1] - 2026-08-03

### Fixed

- `CONTRIBUTING.md`/`.tr-TR.md` and `SECURITY.md`/`.tr-TR.md` linked to
  `github.com/SecondLife/rad-library` — a typo'd owner name (missing
  trailing `s`) that 404s. The real authenticated owner is `SecondLifes`;
  every link now points there. Root cause was a stale
  `github_username_or_org` value in the workspace's `template-vars.json`,
  already fixed upstream — this propagates that fix to files generated
  before the correction.

## [0.1.0] - 2026-07-24

### Added

- Initial commit-pinned derivation from the approved base kit.
- Delphi 13+ Win32/Win64, VCL/FMX library and component contract.
- Helper, component, test, performance and optional vendor-integration rules.
- FMX, JEDI and mORMot2 guidance; JEDI/mORMot2 remain conditional pending
  local Delphi 13+ compilation.
