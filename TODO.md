# TODO — rad-library

Bekleyen bütün işler burada durur. Yeni bir bulgu ya da ertelenen düzeltme
**bu dosyaya** eklenir.

**Kurallar**

- Her maddenin sabit bir numarası var (`RAD-NN`). Kapanan maddenin numarası
  tekrar kullanılmaz; yeni madde en büyük numaradan devam eder
  (sıradaki: **RAD-05**).
- Kapanan madde listeden **ve** ayrıntısından silinir. Kalıcı kayıt
  `git log` + `CHANGELOG.md`'dir.
- Bu liste yalnızca rad-library'ye ait işleri tutar. Bir tüketici projenin
  (ör. ERPPlus) kendi listesindeki madde, buradaki karşılığına numarasıyla
  atıf yapar.

**Kaynak:** 2026-10-17, ERPPlus'ın `radstudio build` ile Win32 Debug derlemesi
(0 hata, 83 uyarı) ve ERPPlus `TODO.md` incelemesi.

## Liste

### 🟠 Yüksek

- [ ] **RAD-01** — `THash`'a Argon2id eklenmeli; `md5` tuzsuz. (`src/core/rad.hash.pas`; ERPPlus YAP-09)
- [ ] **RAD-02** — Yapılandırmadaki parola düz metin saklanıyor; `rad.config` tarafında şifreli saklama ya da hiç saklamama seçeneği gerekiyor. (ERPPlus YAP-11, YAP-27)

### 🟡 Orta

- [ ] **RAD-03** — Dönüş değeri atanmayan fonksiyonlar ve ilklenmemiş değişken (W1035/W1036).
- [ ] **RAD-04** — Örtük `string` ↔ `UTF8String` dönüşümleri (W1057).

---

## Ayrıntılar

#### RAD-01 — Argon2id

`THash.md5` (`src/core/rad.hash.pas`) tuzsuz MD5 üretiyor. ERPPlus'ın
`kullanici.password` kolonu bununla dolduruluyor ve `Rad-DB` şeması bunun zayıf
olduğunu kendisi yazıyor. Yapılacak: `THash.Argon2id` (ya da eşdeğeri) ve mevcut
MD5 kayıtları için ilk girişte yeniden hash'leyen bir geçiş yolu. Geçiş,
tüketen projelerin hepsini etkiler; imza değişikliği CHANGELOG'da duyurulmalı.

#### RAD-02 — Yapılandırmada parola

`Config.Json.Value._RecordSave<TServerOptions>('Server', rc)` parolayı düz metin
yazıyor (kullanan: ERPPlus `src/Share/db.login.pas`). Çözüm `db.login`'e özel
değil, `rad.config`'te olmalı: ya parola hiç yazılmaz ya da Windows DPAPI /
mevcut `rad.cipher` / `rad.AESObj` ile şifrelenir.

#### RAD-03 — Atanmayan dönüş değerleri

Derleyici aşağıdaki yerlerde dönüş değerinin tanımsız kalabileceğini söylüyor.
Her birinde `Result` tüm yollarda atanmalı:

| Dosya:satır | Uyarı |
|---|---|
| `src/component/Permission.Edit.pas:747` | W1035 `TcxTreeListNodeHelper._SetKod` |
| `src/core/Help.DB.pas:769` | W1035 `TDataSetHelper._LoadValueALL` |
| `src/core/Help.uni.pas:396` | W1035 `TUniConnectionHelper._ServerDate` |
| `src/core/Help.uni.pas:623` | W1035 `TUniConnectionHelper._sqlCount` |
| `src/core/Help.uni.pas:994` | W1035 `TDADataSetyHelper._Transaction` |
| `src/core/help.uni.pas:678` | W1036 `sp` ilklenmemiş olabilir |

#### RAD-04 — `UTF8String` dönüşümleri

Derleme, Delphi 13 / Win32 Debug'da aşağıdaki dosyalarda örtük
`string` ↔ `UTF8String` dönüşümü uyarısı veriyor (satırlar o günkü kaynağa göre):
`Permission.Edit.pas` (471, 478, 551, 552, 594, 595, 601, 689, 734, 826, 831),
`rad.db.pas` (1182, 1277, 1280, 1290, 1980), `Help.DB.pas` (328, 330, 342, 344),
`rad.pas` (210, 237), `rad.thread.pas` (728, 739). Uyarı, kodlama kaybı
riski taşıyor; Türkçe karakterli veride veri bozulabilir. Dönüşümler açık
(`UTF8Encode`/`UTF8ToString`) yazılmalı ya da türler `string`'e çevrilmeli.
