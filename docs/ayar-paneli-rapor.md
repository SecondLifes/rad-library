# Ayar Paneli — yapılan iş (2026-08-30)

Sonda: **71/71 yeşil, Win32 + Win64, sızıntı yok.**
Push **edilmedi** (kural: AI commit'ler, push kullanıcının).

**Sonradan eklenen iki düzeltme** — kullanım örneğini yazarken çıktılar:
`ISetting` metotları `protected`ti, yani `FPanel.AddMenu(...)` **derlenmiyordu**;
public yapıldı. Ve `Register` nesneyi sahiplendiği halde tipli referans
dönmüyordu; `Instance(TSatisAyar)` eklendi. İkisi de sondaya bağlandı, sessizce
geri gelemezler.

---

## Verdiğin üç cevap ve nasıl uygulandı

| Karar | Uygulama |
|---|---|
| **Satır + arkada IDocDict** | Değer `IDocDict`'te, `PathDelim = '.'`, anahtar tam noktalı yol. Satır sadece görüntü. |
| **NavBar: Grup = kategori, Öğe = alt grup** | `AddMenu` grup açar, `AddSubMenu` öğe ekler **ve `CreateLink` ile gruba bağlar**. |
| **Fluent zincir (öznitelik yok)** | `rad.atr.pas` yazılmadı. `Register` satırları RTTI'den kendi kurar; zincir sadece varsayılandan farklı olanları söyler. |

Anahtar üretimi senin DFM'deki örneğe birebir oturuyor:
`VadeAsimUyar` → `fatura.satis.vade_asim_uyar`.

---

## Taslakta bulduğum ve düzelttiğim 6 hata

Hepsi ya derlemede ya çalışma zamanında patlardı:

1. `Clear` `Result` atamıyordu; `Register`'da `FList.Add()` argümansızdı.
2. **Ortak erişimciler `private`di.** Delphi'de plain private *aynı birim* içinde
   açıktır — ayar sınıfları başka birimlerde olacağı için torun sınıf kendi
   property'sinin `read GetI` belirtecinde bunları kullanamazdı. Tasarım hiç
   çalışmazdı. `protected` yapıldı.
3. `AddMenu`, NavBar öğesini **hiçbir gruba bağlamıyordu** (`CreateLink` yok) —
   öğe ekranda görünmez, hiçbir hata da çıkmaz.
4. `FValues` hiç boyutlanmıyordu; `GetV` aralık dışına çıkardı.
5. **Constructor depoyu parametre alıyordu.** `TSynAutoCreateFields` iç içe
   alanları *parametresiz sanal* constructor ile yaratır — bu haliyle sadece kök
   nesne bağlanır, bütün alt kategoriler `FDoc = nil` kalırdı. Bağlama artık
   nesne ağacı kurulduktan sonra ayrı bir adım (`Bind`).
6. **Ata sınıftaki `published property Value index 0`** her torun sınıfa miras
   kalır, her birinin kendi index 0'ı ile çakışırdı. Kaldırdım; onun yerine
   published olmayan `ValueAt`/`SetValueAt` var. — *Bu senin yazdığın satırdı,
   bilerek kaldırdım; itiraz edersen geri koyarız ama o zaman torunlar index 0'ı
   kullanamaz.*

Ayrıca `Register` artık **index yoksa veya iki property aynı index'i
paylaşıyorsa istisna atıyor**. İkincisi en sinsisi: bir property satırını
kopyalayıp yapıştırınca iki ayar tek değeri paylaşır ve hiçbir uyarı çıkmaz.

## Yanlış kullandığım/kullanılan 4 DevExpress API'si

Hepsi kurulu kaynaktan doğrulandı, tahminle değil:

- `OnLinkClick` linki **ikinci parametre** olarak veriyor
- `Editing`, `Row.Options`'ta değil `Row.Properties.Options`'ta
- `Value`, olayın verdiği ata türde **protected** (torunda published)
- `Rows.BeginUpdate` protected → erişim sınıfı (kitte `help.Dev.pas` zaten aynı
  deseni `TcxCustomEdit.Properties` için kullanıyor)

Bir de yerel `Refresh`, `TControl.Refresh`'i **aynı imzayla gizliyordu** —
repaint bekleyen her çağrı sessizce oraya düşerdi. `RefreshRows` oldu.

## Ölçülen 2 yeni mORMot tuzağı

Kitin tuzak kaydına işlendi (`verified-api-traps.md`):

- **`mormot.core.base`, RTL'in `LowerCase`, `Pos`, `Trim`'ini gölgeliyor.**
  Niteliksiz çağrılar sessizce UTF-8'e gidip dönüyor — bu tek birimde **7 kez**
  oldu, sadece W1057 uyarısı olarak. Uyarıları kapatan bir yapılandırmada
  tamamen görünmez.
- **`IDocDict.PathDelim` varsayılanı `#0`.** Verilmezse `'a.b.c'` **düz tek
  anahtar** olarak yazılıyor, ağaç hiç kurulmuyor. Ölçüldü:
  `{"a.b.c":7}` vs `{"a":{"b":{"c":7}}}`. Hiçbiri istisna atmıyor.

Bu ikincisi tam da senin senaryonda sessiz veri hatası üretirdi.

## DFM

Tasarım zamanı örnek satırları (`dxNavBar1Group1`, `'ana grup'`, `'sdfs'`,
`'Şirket Para Birimi'` …) **kaldırıldı** — çalışma zamanında gerçek ayarların
yanında görünürlerdi. Panel tamamen kodla kuruluyor; tasarımcıda boş görünmesi
beklenen durum.

---

## Örnek kullanım

> Aşağıdakinin tamamı `src/test/scratch/rad_setting` içinde **Test 14** olarak
> birebir koşuyor — belge ile kodun sessizce ayrışmaması için.

**1 · Ayar sınıfları (kendi biriminde)**

```pascal
unit App.Ayarlar;

interface

uses k.setting;

type
  TSatisAyar = class(TRadSetting)
  published
    property Vade         : Integer index 0 read GetI write SetI default 30;
    property KdvDahil     : Boolean index 1 read GetB write SetB default False;
    property Depo         : string  index 2 read GetS write SetS;
    property VadeAsimUyar : Boolean index 3 read GetB write SetB default True;
  end;

  TAlisAyar = class(TRadSetting)
  published
    property IskontoOrani : Double  index 0 read GetF write SetF;
    property OtomatikOnay : Boolean index 1 read GetB write SetB default False;
  end;

  TGenelAyar = class(TRadSetting)
  published
    property SirketKodu     : string  index 0 read GetS write SetS;
    property SirketAdi      : string  index 1 read GetS write SetS;
    property ParaBirimi     : string  index 2 read GetS write SetS;
    property OndalikBasamak : Integer index 3 read GetI write SetI default 2;
  end;

  // ALT GRUPLAR = iç içe published alanlar.
  // TSynAutoCreateFields bunları kendisi yaratır, yok eder ve JSON'lar.
  TFaturaAyar = class(TRadSetting)
  private
    FAlis  : TAlisAyar;
    FSatis : TSatisAyar;
  published
    property Alis  : TAlisAyar  read FAlis;
    property Satis : TSatisAyar read FSatis;
  end;

implementation
end.
```

`index` **zorunlu** ve sınıf içinde tek — yoksa `Register` istisna atar.
`GetI/GetB/GetS/GetF/GetDt` hazır ortak erişimciler, hepsi depoya gider.

**2 · Kayıt**

```pascal
FPanel := TfrmSetting.Create(Self);
FPanel.Parent := Self;
FPanel.Align  := alClient;

FPanel
  .AddMenu('Fatura')                              // NavBar GRUBU
    .AddSubMenu('Satis')                          // NavBar ÖĞESİ
      .Register(TSatisAyar)
        .Title('Vade',         'Vade (gun)', 'Musteriye taninan odeme suresi')
        .Title('KdvDahil',     'KDV dahil')
        .Title('VadeAsimUyar', 'Vade asiminda uyar')
        .Repository('Depo', dm.riDepo)            // DevExpress lookup
    .AddSubMenu('Alis')
      .Register(TAlisAyar)
        .Title('IskontoOrani', 'Iskonto %')
  .AddMenu('Genel')
    .Register(TGenelAyar)
      .Choices('ParaBirimi', ['TL', 'USD', 'EUR'])
      .ReadOnly('SirketKodu');

FPanel.LoadJson(DbdenAyarJsonuOku);
```

`Register` **her published property için satırı kendi kurar** — zincirde
yalnızca varsayılandan farklı olanları söylersin. Hiç `Title` yazmasan da panel
çalışır, başlıklar property adı olur.

**3 · Koddan okuma/yazma (tipli)**

```pascal
var
  LSatis: TSatisAyar;
begin
  // Register nesneyi kendi yaratıp sahiplenir; tipli referans buradan alınır.
  // İç içe (alt kategori) sınıflar da bulunur.
  LSatis := TSatisAyar(FPanel.Instance(TSatisAyar));

  if LSatis.VadeAsimUyar and (GunSayisi > LSatis.Vade) then
    Uyar;

  LSatis.Depo := 'MERKEZ';   // depoya yazar, ızgara satırını da tazeler
end;
```

**4 · Kaydetme**

```pascal
if FPanel.Modified then
  DbyeYaz(FPanel.SaveJson);
```

Üretilen JSON gerçek ağaç (Test 14 çıktısından):

```json
{"fatura":{"satis":{"vade":75,"kdv_dahil":true,"depo":"ANKARA"},
           "alis":{"otomatik_onay":true}},
 "genel":{"para_birimi":"USD","ondalik_basamak":4}}
```

Anahtar `VadeAsimUyar` → `fatura.satis.vade_asim_uyar` — DFM'deki `lblID`
örneğinin birebir aynısı.

---

## Senin kararını bekleyen 4 şey (`docs/olcum-listesi.md` Ö-06…Ö-09)

1. **Tasarım zamanı** — frame'i bir forma bırakıp IDE'nin sorunsuz açtığını
   görmek. Başsız ölçülemez.
2. **Gerçek etkileşim** — NavBar tıklaması, aramada yazma, bir değeri elle
   düzenleme. DevExpress görünmeyen ızgarada inplace editör açmıyor, o yüzden
   `OnEditValueChanged` yolu canlıda görülmedi (kodda var ve korumalı).
3. **`k.setting` `RadKon.dpk`'ye girsin mi?** Şu an pakette değil. Girerse
   `requires`'a **`dxNavBarRS37`** eklenmesi gerekir — bugün orada yok. Bu,
   kütüphaneyi kullanan herkese yeni bir DevExpress bağımlılığı demek.
   `Permission.Edit` pakette çünkü tasarım zamanı editörü; `k.setting` bir
   uygulama ekranı. **Bilerek eklemedim.**
4. **Kalıcılık** — `LoadJson`/`SaveJson`/`Doc` dikişleri hazır, DB tarafı bağlı
   değil. Şirket/kullanıcı katmanlaması (kullanıcıda yoksa şirketten düşme)
   henüz yok; istersen bir sonraki adım bu.

Ayrıca **açık kalan iki görsel karar** (ilk konuşmadan): katman rozeti
(Şirket/Kullanıcı) kalsın mı, ve **Uygula düğmesi mi anlık kayıt mı**. Şu an
anlık: değişiklik hemen depoya yazılıyor, `Modified` işaretleniyor, yazma anı
sana bırakılmış.

---

## Dokunulmayanlar

Çalışma ağacındaki **47 kalemlik kendi işine dokunmadım** — `Rad.Dev.pas`'ın
"A" öneki dahil (onun regresyonu Ö-02 olarak bekliyor). Sadece kendi
dosyalarımı tam yol vererek stage ettim.
