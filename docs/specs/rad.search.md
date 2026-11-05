# Specification: Menü ve kayıt araması (`rad.search`)

Durum: **1. aşama uygulandı** (2026-11-05): menü/komut araması, sık kullanılanlar, açılır liste.
2. aşama (cari, stok gibi kayıt kaynakları) Rad-DB kararını bekliyor.

## Kullanım

```pascal
uses rad.search;

LKurulum.Commands := FKomutlar;            // TRadDeskCommands (menü, eylemler)
LKurulum.CommandsCaption := 'Menü';
LKurulum.Usage := <kayıtlı sayaçlar>;
LKurulum.OnUsageChange := SayaclariSakla;
LKurulum.AppCounts := True;                // uygulama Application.OnActionExecute ile sayar
TRadSearch.Kur(LKurulum);
FArama := TRadSearch.Bagla(edtSearch, Images, Self);
```

Yeni bir kaynak (cari, stok...) `IRadSearchProvider` uygular ve `TRadSearch.Motor.Add` ile takılır;
kutuya dokunulmaz. Kaynak kendi yetki filtresini uygular.

## Birimler

| Birim | Katman | İş |
|---|---|---|
| `core/rad.search.match.pas` | RTL | Katlama, kelime ve baş harf, puan |
| `core/rad.search.core.pas` | RTL | `IRadSearchProvider`, motor, kullanım sayaçları, komut kaynağı |
| `component/rad.search.popup.pas` | VCL + DevExpress | Açılır liste ve kutu denetleyicisi |
| `component/rad.search.pas` | Facade | Takma adlar, `Kur`/`Kapat`/`Bagla` |

## Eşleştirme kuralları

Web istemcisi aynı kuralları uygular; değişiklik iki tarafta birlikte yapılır. Test tablosu:
`src/test/unit/rad.search.match.Tests.pas`.

**Katlama:** küçük harf; `I/İ/ı/i`, `ş/s`, `ğ/g`, `ü/u`, `ö/o`, `ç/c`, `â/a`, `î/i`, `û/u` aynı;
`&` silinir. Harf ve rakam dışındaki her karakter kelime ayırıcıdır.

| Puan | Kural | Örnek ("Yurt İçi Satış Faturası") |
|---|---|---|
| 500 | Başlık aranan metinle başlar | `yurt` |
| 400 | Baş harfler aranan metinle başlar (tek terim, en az 2 harf) | `yisf`, `yis` |
| 300 | Her terim bir başlık kelimesinin başı | `sat fat`, `satis` |
| 200 | Başlık aranan metni içerir | `atış` |
| 100 | Her terim başlık ya da yol kelimesinin başı | `finans kasa` (yol: Finans Yönetimi) |

Aynı puanda: çok kullanılan önce, sonra kısa başlık, sonra alfabetik. Atlamalı baş harf
(`ysf`) bilerek yoktur: gürültü getirir.

## Kararlar

| # | Karar | Gerekçe |
|---|---|---|
| 1 | Yol aranabilir, en düşük puanla | Sahip kararı (2026-11-05) |
| 2 | Yalnız açılabilen komutlar listelenir; ara menüler yalnız yolda görünür | Sahip kararı |
| 3 | Kısayol Alt+Q (ERPPlus `actAra`, `GlobalKey = 'menu.ara'`) | Office "Ne yapmak istiyorsunuz?" ile aynı; AltGr+Q (`@`) ile çakışmaz |
| 4 | `TRadDeskNav.Fold` aynı katlamayı kullanır | Sahip kararı: her yerde tek kural |
| 5 | Kullanım sayacı kalıcıdır, saklama uygulamaya aittir | Kütüphane `Config`'e bağlı kalmaz |
| 6 | Önbellek: yalnız katlanmış başlık, kelime ve baş harf dizini (ilk aramada bir kez) | Birkaç yüz öğede tuş başına tarama ms altı; diske yazılan önbellek yetki ve şirket değişince bayat kalır |
| 7 | DevExpress repository item yerine kutuya bağlanan denetleyici | Kaynaklar editöre değil motora aittir; yeni editör sınıfı, kayıt ve tasarım paketi gerektirmez, her `TcxCustomTextEdit` ile çalışır |
| 8 | Liste odak almayan, kendi çizen açılır pencere | Yazarken odak kutuda kalır; renkler kutunun skin'inden |

## Davranış

- Kutu boşken odaklanınca sık kullanılanlar listelenir.
- Ok tuşları, PgUp/PgDn seçer; Enter ya da tık çalıştırır; Esc önce listeyi kapatır, sonra metni siler.
- Çalıştırma `TThread.ForceQueue` ile, tuş olayı bittikten sonra yapılır.
- Liste kutu odağı kaybedince (`OnExit`, `OnFocusChanged`) ve uygulama etkinliğini kaybedince kapanır.

## Açık işler

- **2. aşama, kayıt kaynakları.** PostgreSQL'de katlama ifadesi sorguda yapılırsa indeks kullanılmaz.
  Katlanmış arama kolonu ve indeks için Rad-DB'de tek bir kalıp belirlenmeli. Sorgu ana iş parçacığında,
  `LIMIT` ve yazma bittikten ~300 ms sonra çalışır, ya da ayrı bağlantıyla: karar verilecek.
- Ana form taşınırken liste yerinde kalır (kutu odağını kaybetmez); sonraki tuşta yeniden konumlanır.
- Eşleşen harfler kalın gösterilmiyor.
