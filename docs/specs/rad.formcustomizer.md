# Specification: form durumu katılımcıları ve `TRadFormCustomizer`

Durum: **onaylandı** (2026-11-03; sıfırlama: kayıt sil + yeniden aç). Önceki iş: `rad.formstate.md` (store, depolar, editör).
Plan: kullanıcının onayladığı plan (kullanıcıya özel · TMS taşıma · cxRTTIInspector · grid/layout
sağlayıcıları · formu varsayılana döndür · üç düzeltme).

## Bağlam

İki ihtiyaç:

1. Son kullanıcı çalışan formda görsel değişiklik yapabilmeli: kontrolü taşıma/boyutlandırma ve özellik
   düzenleme. Yalnız geliştiricinin izin verdiği bileşen ve özellikleri görür. Değişiklik **kullanıcıya
   özeldir**.
2. `TRadPropertiesStore` tek bileşene bağlı kalmamalı: yeni tasarımlar aynı kayda tek kalıpla veri
   yazabilmeli (customizer, grid düzeni, layout düzeni, ileride başkaları).

Şirket geneli düzen (`TRadScriptDesigner`, `rad.script.designer.md`) yerinde kalır. Bu iş onun **üstüne**
kullanıcı katmanı ekler.

### Ölçülen / kaynakta doğrulanan durum

- `ApplyDoc` `Version` uyuşmazsa `custom`'ı da atlıyor (`rad.formstate.component.pas` ApplyDoc). Sonuç:
  geliştirici sürümü artırınca `TRadActionList` kısayolları da kaybolur. Yorumdaki gerekçe ("eski
  yerleşim artık uymaz") yalnız yerleşim ve özellikler için doğru.
- Store, `IRadStateful` bileşene yalnız kendi alt sözlüğünü verir; ppi gelmez (ApplyCustom).
- Store her kayıtta `Items` yollarının **güncel** değerini yazar (CaptureProps). İzin listesini
  `Items` yapmak her kullanıcıda tüm izinli özellikleri dondururdu; bu yüzden customizer fark saklar.
- Katman sırası bugün ters: store `OnCreate`'te yükler, host `DoCreate` sonunda `TRadScripting.Bagla`
  çağırır, `Attach` → `ApplyOverrides` şirket düzenini kullanıcınınkinin üstüne yazar
  (`rad.script.hooks.pas` Attach; `rad-script` SKILL.md host kalıbı).
- TMS `TAdvFormDesigner`: `OnEditBehaviour` `*Runtime` dışı bir değer döndürürse kontrole `csDesigning`
  açılır (`FormDesigner.pas`:5046). `TRadScriptDesigner` bu olayı vermiyor; canlı formdaki tüm
  kontrollere `csDesigning` açılıyor.
- TMS `TDesignerUndoStack` geri almayı formu DFM'den yeniden yükleyerek yapar (`idemain.pas`:9650):
  canlı ERP formunda kullanılamaz.
- `TcxRTTIInspector`: `FilterPropertyEx` tam yolu verir (`Font.Size`); üst satır (`Font`) reddedilirse
  alt satırlar hiç oluşmaz (cxOI:4109). Satır yolu `Properties.Caption`'dan kurulur (cxOI:3930);
  başlığı değiştirmek yeniden kurulumda odağı bozar. Diyalogla yapılan düzenleme `OnPropertyChanged`
  tetiklemez (cxOI:4251). Tek nesne inceler.
- cxGrid `RestoreFromStream(AStream, AChildrenCreating = True, ...)`: varsayılan, akışta olup formda
  olmayan sütunları **yaratır** (`cxGridCustomView.pas`:2077). `StoreToStream` seçenekleri:
  `gsoUseFilter, gsoUseSummary, gsoUseDataViewState, ...` (:75).

### Kaynak araması (rad-skill-finder kuralı)

- Yerel skill kütüphaneleri (kit, workspace, `~/.agents/skills`, `~/.claude/skills`): "runtime design",
  "object inspector|RTTIInspector", "grab handle|IDesignerHook", "form designer|JvDesign" → ilgili 0 sonuç.
- Web: hazır Claude skill/MCP yok. Açık kaynak aday `havlicekp/form-designer` (yalnız Delphi 10.3'te
  test edilmiş); JVCL `JvDesignSurface` (MPL, `IDesignerHook` ile `csDesigning` açar). Kurulu ve repoda
  kullanılan TMS `TAdvFormDesigner` tercih edildi (kullanıcı kararı).

## Kararlar

1. **İki katılım biçimi, bir kayıt.**
   - *Bileşen katılımcısı*: `IRadStateful` (değişmez). `Items`'ta yolsuz öğe olarak ya da
     `Store.Attach(AStateful, AName)` ile katılır. Bölümü `custom.<ad>`.
   - *Global sağlayıcı*: `IRadStateProvider`, uygulamada bir kez kaydedilir, her store için çağrılır.
     Bölümü `ext.<ad>`.
2. **Sürüm kapısı bölüm başına.** `Store.Version` yalnız `form` ve `props`'u kapılar. `custom.<ad>` ve
   `ext.<ad>` kendi `v` alanını taşır; katılımcı kendi sürümünü bildirir, uyuşmazsa yalnız o bölüm
   atlanır. Eski kayıtlarda `v` yoksa 0 sayılır (geriye uyum).
3. **Formu varsayılana döndür = kaydı sil + formu yeniden aç.** Anında uygulama, host'un `OnCreate`'te
   kodla verdiği değerleri DFM değeriyle ezerdi. Yeniden açılan form DFM → şirket düzeni → host kodu
   sırasını kendiliğinden kurar; her katılımcı için doğru ve ek kod gerektirmez. Customizer içindeki
   **tek kontrol / tek özellik** sıfırlama anında yapılır (oturum başı değeri bilinir).
4. **Customizer yalnız fark saklar**, izinli yol listesiyle uygular (izinsiz anahtar elle eklense de
   uygulanmaz). Taşınabilirlik izinli yollardan türetilir: `Left`/`Top` → taşınır, `Width`/`Height` →
   boyutlanır.
5. **Katman sırası**: DFM → şirket düzeni (`duzen.json`) → kullanıcı farkı → script `Form_AfterCreate`.
   `ApplyOverrides` sonunda `TRadFormCustomizer.Reapply(AForm)`.
6. **TMS bağımlılığı RadKon'a girmez.** Customizer bileşeni ve sağlayıcılar RadKon'da; düzenleme oturumu
   `RadScriptTmsDesign`'da, `initialization`'da kendini customizer'ın sınıf değişkenine kaydeder.
   Oturum kayıtlı değilse `Customize` anlamlı bir hata verir.
7. **RadKon runtime/design ayrımı**: `RadKon` çalışma paketi, `RadKonD` tasarım paketi.

## Birimler

| Birim | Paket | İçerik |
|---|---|---|
| `src/core/rad.formstate.core.pas` | RadKon | + `IRadStateProvider`, bölüm sürümü yardımcıları |
| `src/component/rad.formstate.component.pas` | RadKon | + `Attach/Detach`, sağlayıcı döngüsü, bölüm sürümleri, `ResetSaved`; `TRadStateItem` bildirim genellemesi; `TRadStoredValue.ValueType` setter'ı |
| `src/component/rad.formstate.customizer.pas` | RadKon | `TRadFormCustomizer` |
| `src/component/rad.formstate.dev.pas` | RadKon | `TRadGridStateProvider`, `TRadLayoutStateProvider` |
| `src/component/rad.formstate.pas` | RadKon | giriş birimi: + alias'lar, `RegisterProvider`, `ResetForm` |
| `src/vendor/tms/rad.formstate.customize.session.pas` | RadScriptTmsDesign | düzenleme oturumu (`TAdvFormDesigner` + inspector) |
| `src/vendor/tms/rad.formstate.customize.tools.pas/.dfm` | RadScriptTmsDesign | araç penceresi (DFM) |
| `src/vendor/tms/rad.script.hooks.pas` | RadScriptTms | `ApplyOverrides` sonunda `Reapply` |
| `src/vendor/tms/rad.script.design.pas` | RadScriptTmsDesign | `OnEditBehaviour` düzeltmesi |
| `src/packages/RadKonD.dpk` | — | `Rad.Register`, `Rad.Editor*`; requires `RadKon`, `designide`, `dclcxLibraryRS37` |

## Doküman şeması (eklenenler)

```json
{
  "schema": 1, "version": 3, "ppi": 96, "form": {}, "props": {}, "values": {},
  "custom": {
    "ActionList1": { "v": 0, "...": "..." },
    "Customizer1": { "v": 1, "ppi": 96,
                     "diff": { "btnKaydet": { "Caption": "Kaydet*", "Left": 120 },
                               "edtAd":     { "Font.Size": 11, "Color": 15790320 } } }
  },
  "ext": {
    "cxgrid": { "v": 1, "views": { "tvSatirlar": "<base64>" } },
    "dxlayout": { "v": 1, "controls": { "lytMain": "<base64>" } }
  }
}
```

- `custom.<ad>.v` ve `ext.<ad>.v` store tarafından yazılır/okunur; katılımcı `v`'yi görmez.
- Eski `custom` kayıtları (`v` yok) sürüm 0 kabul edilir.

## API

```pascal
IRadStateProvider = interface
  function Name: RawUtf8;
  function Version: Integer;
  function Wants(AOwner: TComponent): Boolean;
  procedure Save(AOwner: TComponent; const ADoc: IDocDict);
  procedure Load(AOwner: TComponent; const ADoc: IDocDict);
end;

IRadStateVersion = interface      // isteğe bağlı; IRadStateful bileşen sürüm bildirmek isterse
  function StateVersion: Integer;
end;

TRadPropertiesStore
  procedure Attach(const AStateful: IRadStateful; const AName: RawUtf8);
  procedure Detach(const AName: RawUtf8);
  procedure ResetSaved;           // kaydı siler, bu oturumun kapanış kaydını engeller
  class procedure RegisterProvider(const AProvider: IRadStateProvider);

TRadFormCustomizer = class(TComponent, IRadStateful, IRadStateVersion)
published
  property Allowed: TRadStateItems;   // bileşen + nokta yollu özellikler
  property Captions: TStrings;        // 'Font.Size=Yazı boyutu'; boşsa yerleşik Türkçe, o da yoksa yol
  property GridStep: Integer default 8;
  property OnChanged: TNotifyEvent;   // oturum kaydedince
public
  procedure Customize;                // oturumu açar (kayıtlı oturum yoksa ERadFormState)
  procedure ResetPath(AComponent: TComponent; const APath: string);
  procedure ResetAll;
  function IsAllowed(AComponent: TComponent; const APath: string): Boolean;
  function CaptionOf(const APath: string): string;
  class procedure Reapply(AOwner: TComponent); static;   // sahibin tüm customizer'larını yeniden uygular
end;
```

## Davranış

### Store
- **Yükleme**: (1) `values`; (2) sürüm uyuyorsa `form`, `props`; (3) her `custom.<ad>`: katılımcının
  sürümü kayıttakiyle aynıysa `LoadState`; (4) her kayıtlı sağlayıcı: `Wants` ise ve sürüm aynıysa `Load`.
- **Kayıt**: her katılımcının `SaveState`'i ve `Wants` diyen her sağlayıcının `Save`'i; boş bölüm
  yazılmaz.
- Bir katılımcının istisnası diğerlerini durdurmaz: hata `Errors`'a ve loga.
- `ResetSaved`: depodan kaydı siler ve bu oturumun kapanış kaydını engeller.
- `TRadFormState.ResetForm(AForm)`: sahibin bütün store'larında `ResetSaved`, sonra
  `class var TRadFormState.Reopen: TProc<TCustomForm>` (host atar: formu kapatıp aynı parametrelerle
  yeniden açar). Atanmamışsa form kapatılır ve kullanıcıya "form yeniden açıldığında varsayılan
  görünüm gelir" mesajı verilir (resourcestring).

### Customizer
- `Loaded` (çalışma anı): sahibin store'u (ilk bulunan) varsa `Attach(Self, Name)`; yoksa uyarı loglanır
  ve customizer yalnız oturum içinde çalışır.
- `LoadState`: `diff`'i okur, izinli yollarla ve kendi ppi'siyle ölçekleyerek uygular.
- `SaveState`: `{"ppi":..,"diff":..}`.
- `Reapply`: son yüklenen farkı yeniden uygular (şirket düzeninden sonra çağrılır).
- **Oturum**:
  - Açılışta: her izinli yolun değeri yakalanır (oturum başı); oturum boyunca seçilen kontrolün
    değişiklik öncesi değerleri geri alma yığınına itilir.
  - `TAdvFormDesigner` `OnEditBehaviour`: izinli yolu olmayan → `ebProtected` + `pmUnselect`;
    dxLayout içi ya da geometri izni yok → `ebLockedRuntime`; taşınabilir → `ebDefaultRuntime`.
    `MultiSelect := False`, `SnapToGrid := True`, `GridStep`. Boyut izni yoksa `OnCustomizeGrabs` boyut
    tutamaçlarını gizler; `OnMoveSizeControl` izinsiz geometri değişimini geri alır. Delete,
    Ctrl+C/V/X engellenir.
  - Seçim → inspector `InspectedObject`. Inspector `FilterPropertyEx` izinli yolu ve öneklerini kabul
    eder; önek satırları salt okunur; başlık `OnDrawRowHeader` ile Türkçe.
  - Kaydet: fark = eski fark + oturum başına göre değişen izinli yollar (varsayılanla kıyaslanmaz);
    `Store.Save`. Vazgeç: oturum başı değerleri. Geri al: yığından. Varsayılana dön (seçili/tümü):
    anahtarları siler, oturum öncesi varsayılanı uygular, şirket düzenini (varsa) yeniden uygular.
- Araç penceresi DFM'de: üstte seçili bileşenin Türkçe adı, ortada inspector, altta düğmeler; form
  üzerinde yüzer, ana formu örtmez, son konumu kendi store'unda saklanır.

### Sağlayıcılar
- **cxgrid**: sahibin adlı her `TcxCustomGridView`'ı; `StoreToStream(S, [])` (filtre, özet, veri
  durumu yok: sütun sırası, genişlik, görünürlük, sıralama, gruplama); yüklerken
  `RestoreFromStream(S, False, False, [])` — formda olmayan sütun **yaratılmaz**, olan silinmez.
- **dxlayout**: sahibin adlı her `TdxLayoutControl`'ü; `SaveToStream`/`LoadFromStream`. Kullanıcı
  layout'un kendi Customization kipini açtığında değişen düzen saklanır. Şirket `.layout` kaynağı varsa
  o önce uygulanır (binder), kullanıcınınki store yüklemesinde değil `Reapply`'da sonra.
  *Not*: bu sağlayıcının sırası customizer ile aynı sorunu taşır; `Reapply` sağlayıcıları da kapsar.

## Entry Unit and Setup Call

- **Giriş birimi**: `rad.formstate` (değişmez).
- **Re-export**: + `TRadFormCustomizer`, `IRadStateProvider`, `IRadStateVersion`,
  `TRadGridStateProvider`, `TRadLayoutStateProvider`.
- **Kurulum**: mevcut `TRadFormState.Kur(...)`; sağlayıcılar isteğe bağlı tek satır:

```pascal
uses rad.formstate;
TRadFormState.Kur(TRadFormState.DbStore(Conn), Oturum.UserName);
TRadFormState.RegisterProvider(TRadGridStateProvider.Create);
TRadFormState.RegisterProvider(TRadLayoutStateProvider.Create);
...
TRadFormState.Reopen := procedure(F: TCustomForm) begin ... end;  // host: formu yeniden aç
TRadFormState.ResetForm(Self);     // "formu varsayılana döndür" komutu
Customizer1.Customize;             // "formu düzenle" komutu (RadScriptTmsDesign yüklü olmalı)
```

- **Kabul**: host yalnız `rad.formstate` ekleyerek yukarıdakilerin hepsini çağırabilir; test ile kanıtlanır.

## Kabul ölçütleri (EARS)

1. **WHEN** store `Version` artırılmış bir kaydı yükler **THE SYSTEM SHALL** `form`/`props`'u atlayıp
   `values`, `custom` ve `ext` bölümlerini kendi sürümleri uyuyorsa uygulamak.
2. **WHEN** bir katılımcının sürümü kayıttakinden farklıysa **THE SYSTEM SHALL** yalnız o bölümü atlamak.
3. **WHEN** `ResetForm` çağrılır **THE SYSTEM SHALL** kaydı silmek, o oturumun kapanışında kaydetmemek ve
   formu `Reopen` ile yeniden açmak (atanmamışsa kapatıp kullanıcıyı bilgilendirmek).
4. **WHEN** kayıtta izin listesinde olmayan bir yol varsa **THE SYSTEM SHALL** onu uygulamamak.
5. **WHEN** geliştirici DFM'de kullanıcının dokunmadığı bir özelliği değiştirir **THE SYSTEM SHALL** yeni
   değeri göstermek.
6. **WHEN** form farklı ppi'de açılır **THE SYSTEM SHALL** kayıtlı `Left/Top/Width/Height`'ı ölçeklemek.
7. **WHEN** şirket düzeni ve kullanıcı farkı aynı özelliği değiştirir **THE SYSTEM SHALL** kullanıcı
   değerini uygulamak.
8. **WHILE** düzenleme oturumu açıkken **THE SYSTEM SHALL** hiçbir kontrole `csDesigning` açmamak ve
   izinli yolu olmayan kontrolü seçtirmemek.
9. **WHEN** grid düzeni yüklenir **THE SYSTEM SHALL** formda olmayan sütun yaratmamak.
10. **IF** bir katılımcı yüklemede istisna atarsa **THEN THE SYSTEM SHALL** diğer katılımcılara devam
    etmek ve hatayı `Errors`'a yazmak.

## İşlevsel olmayan

- Sağlayıcı döngüsü 300 yollu ölçüm formunda yüklemeye en çok 5 ms
  eklemeli (ölçülecek; bugün ~15 ms Win32).
- cxGrid kayıt boyutu ölçülür ve spec'e yazılır.
- Bütün testler Win32 + Win64; her yeni test önce mutasyonla kırmızıya çevrilir.

## Aşamalar

1. RadKon/RadKonD ayrımı; mevcut testler ve dört paket derlemesi.
2. Katılımcı sistemi, bölüm sürümleri, `ResetSaved`/`ResetForm`, ValueType setter.
3. cxGrid ve dxLayout sağlayıcıları.
4. Customizer çekirdeği, `Reapply` kancası.
5. TMS oturumu ve araç penceresi; ilk iş canlı DevExpress formunda tıklama/sürükleme probu.
   `TRadScriptDesigner` `OnEditBehaviour` düzeltmesi ve test sızıntısı.
6. Tasarım anı: customizer için izin listesi editörü (mevcut ağaç editörü, store'dan bağımsız model),
   README, CHANGELOG, proje haritası.

## Riskler

- TMS sürüklemesi DevExpress'li canlı formda hiç ölçülmedi; tıklama `*Runtime` kipinde kontrole
  ulaşmıyorsa aşama 5 yeniden planlanır.
- Bir yol hem store `Items`'ında hem customizer izin listesinde olursa iki kayıt çakışır: yükleme
  sırasında uyarı loglanır, customizer kazanır (sonra uygulanır).
- RadKonD ayrımı IDE kurulumunu değiştirir: önce eski RadKon kaldırılır, sonra RadKon ve RadKonD.
- Customizer'daki tek özellik sıfırlaması oturum başı değerini uygular; host o özelliği `OnCreate`'te
  kodla değiştiriyorsa oturum başı değeri zaten host'un değeridir, sorun yok.

## Kapsam dışı

- Kontrol ekleme/silme, olay bağlama (şirket tasarımcısının işi).
- Çoklu seçim (inspector tek nesne).
- dxLayout içinde customizer ile taşıma (layout'un kendi kipi kullanılır).
